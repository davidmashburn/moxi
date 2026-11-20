/* A single-flight, session-local draft compiler. Only poll loads the module,
 * on the host thread; the worker never touches AppKit or the live scene. */
typedef NS_ENUM(int, MoxiLiveBuildPhase) {
    MoxiLiveBuildIdle = 0,
    MoxiLiveBuildRunning = 1,
    MoxiLiveBuildSucceeded = 2,
    MoxiLiveBuildFailed = 3,
};

@interface MoxiLiveEditor : NSObject
@property(nonatomic, copy) NSString *directory;
@property(nonatomic, copy) NSString *repository;
@property(nonatomic, copy) NSString *output;
@property(nonatomic, copy) NSString *diagnostics;
@property(nonatomic, weak) MoxiWindowState *owner;
@property(nonatomic) MoxiLiveBuildPhase phase;
@property(nonatomic) NSUInteger revision;
@property(nonatomic) BOOL disposed;
@end
@implementation MoxiLiveEditor
@end

uint64_t moxi_dev_editor_create(void) {
    @autoreleasepool {
        char scratch[PATH_MAX];
        snprintf(scratch, sizeof(scratch), "%smoxi-editor-XXXXXX", NSTemporaryDirectory().fileSystemRepresentation);
        if (mkdtemp(scratch) == NULL) return 0;
        MoxiLiveEditor *editor = [[MoxiLiveEditor alloc] init];
        editor.directory = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:scratch length:strlen(scratch)];
        editor.repository = [[NSFileManager defaultManager] currentDirectoryPath];
        editor.diagnostics = @"";
        MoxiWindowState *owner = moxi_current_context();
        editor.owner = owner;
        return (uint64_t)CFBridgingRetain(editor);
    }
}

int moxi_dev_editor_start(uint64_t handle, const char *source) {
    @autoreleasepool {
        MoxiLiveEditor *editor = (__bridge MoxiLiveEditor *)(void *)handle;
        if (editor == nil || source == NULL) return 0;
        @synchronized(editor) {
            if (editor.disposed || editor.phase == MoxiLiveBuildRunning) return 0;
            editor.revision++;
            editor.diagnostics = @"";
            NSString *stem = [NSString stringWithFormat:@"draft-%lu", (unsigned long)editor.revision];
            NSString *draft = [editor.directory stringByAppendingPathComponent:[stem stringByAppendingString:@".mojo"]];
            editor.output = [editor.directory stringByAppendingPathComponent:[stem stringByAppendingString:@".dylib"]];
            NSString *log = [editor.directory stringByAppendingPathComponent:[stem stringByAppendingString:@".log"]];
            NSString *text = [NSString stringWithUTF8String:source];
            NSError *error = nil;
            if (text == nil || ![text writeToFile:draft atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
                editor.diagnostics = error.localizedDescription ?: @"Cannot write draft source.";
                editor.phase = MoxiLiveBuildFailed;
                return 0;
            }
            editor.phase = MoxiLiveBuildRunning;
            NSString *output = editor.output;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                @autoreleasepool {
                    NSFileManager *files = [NSFileManager defaultManager];
                    [files createFileAtPath:log contents:nil attributes:nil];
                    NSFileHandle *capture = [NSFileHandle fileHandleForWritingAtPath:log];
                    NSTask *process = [[NSTask alloc] init];
                    process.executableURL = [NSURL fileURLWithPath:@"/usr/bin/env"];
                    process.arguments = @[@"mojo", @"build", @"--emit", @"shared-lib",
                        @"-I", [editor.repository stringByAppendingPathComponent:@"src"], draft,
                        @"-Xlinker", @"-undefined", @"-Xlinker", @"dynamic_lookup", @"-o", output];
                    process.currentDirectoryURL = [NSURL fileURLWithPath:editor.repository isDirectory:YES];
                    process.standardOutput = capture;
                    process.standardError = capture;
                    NSError *launchError = nil;
                    BOOL launched = capture != nil && [process launchAndReturnError:&launchError];
                    if (launched) [process waitUntilExit];
                    [capture closeFile];
                    // A file avoids pipe backpressure with verbose compiler output.
                    NSFileHandle *reader = [NSFileHandle fileHandleForReadingAtPath:log];
                    NSData *data = [reader readDataOfLength:32769];
                    [reader closeFile];
                    BOOL truncated = data.length > 32768;
                    NSUInteger length = MIN(data.length, (NSUInteger)32768);
                    NSString *diagnostics = nil;
                    // A bounded log may end in the middle of a UTF-8 code point.
                    for (NSUInteger trim = 0; trim < 4 && trim <= length; trim++) {
                        diagnostics = [[NSString alloc] initWithBytes:data.bytes length:length - trim encoding:NSUTF8StringEncoding];
                        if (diagnostics != nil) break;
                    }
                    diagnostics = diagnostics ?: @"Compiler output is not valid UTF-8.";
                    if (truncated) diagnostics = [diagnostics stringByAppendingString:@"\n[Compiler output truncated at 32 KiB.]\n"];
                    if (!launched) diagnostics = launchError.localizedDescription ?: @"Cannot launch Mojo compiler.";
                    BOOL succeeded = launched && process.terminationStatus == 0 && [files fileExistsAtPath:output];
                    @synchronized(editor) {
                        editor.diagnostics = diagnostics;
                        editor.phase = succeeded ? MoxiLiveBuildSucceeded : MoxiLiveBuildFailed;
                        [files removeItemAtPath:draft error:NULL];
                        [files removeItemAtPath:log error:NULL];
                        if (editor.disposed) [files removeItemAtPath:editor.directory error:NULL];
                    }
                    // Wake the host even when a native text editor owns focus.
                    // Context selection and AppKit stay on the main thread.
                    dispatch_async(dispatch_get_main_queue(), ^{
                        MoxiWindowState *owner = editor.owner;
                        if (owner == nil || owner->retired) return;
                        __attribute__((cleanup(moxi_restore_context)))
                        MoxiWindowState *previousContext = moxi_active_context;
                        moxi_active_context = owner;
                        if (moxi_window_opened) moxi_wake_event_wait();
                    });
                }
            });
            return 1;
        }
    }
}

int moxi_dev_editor_poll(uint64_t handle) {
    MoxiLiveEditor *editor = (__bridge MoxiLiveEditor *)(void *)handle;
    if (editor == nil) return MoxiLiveBuildIdle;
    @synchronized(editor) {
        MoxiLiveBuildPhase result = editor.phase;
        if (result == MoxiLiveBuildSucceeded) {
            if (!moxi_dev_load_live_script(editor.output.fileSystemRepresentation)) {
                const char *detail = dlerror();
                editor.diagnostics = [NSString stringWithFormat:@"Cannot load moxi_live_frame: %s", detail ?: "missing C ABI export"];
                result = MoxiLiveBuildFailed;
            }
        }
        if (result == MoxiLiveBuildSucceeded || result == MoxiLiveBuildFailed) {
            // dlopen owns the loaded image; unlink every generation immediately.
            [[NSFileManager defaultManager] removeItemAtPath:editor.output error:NULL];
            editor.phase = MoxiLiveBuildIdle;
        }
        return result;
    }
}

int moxi_dev_editor_diagnostics_count(uint64_t handle) {
    MoxiLiveEditor *editor = (__bridge MoxiLiveEditor *)(void *)handle;
    return (int)[editor.diagnostics length];
}
int moxi_dev_editor_diagnostics_utf16_at(uint64_t handle, int index) {
    MoxiLiveEditor *editor = (__bridge MoxiLiveEditor *)(void *)handle;
    if (index < 0 || (NSUInteger)index >= [editor.diagnostics length]) return -1;
    return [editor.diagnostics characterAtIndex:(NSUInteger)index];
}
void moxi_dev_editor_destroy(uint64_t handle) {
    MoxiLiveEditor *editor = CFBridgingRelease((void *)handle);
    if (editor == nil) return;
    @synchronized(editor) {
        editor.disposed = YES;
        if (editor.phase != MoxiLiveBuildRunning)
            [[NSFileManager defaultManager] removeItemAtPath:editor.directory error:NULL];
    }
}
