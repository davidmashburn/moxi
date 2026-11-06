#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include "storage.h"

static const NSUInteger MMMaxBytes = 8388608, MMMaxTopics = 10000, MMMaxDepth = 256, MMMaxText = 65536;
@interface MMResult : NSObject
@property BOOL ok;
@property NSArray<NSString *> *fields;
@end
@implementation MMResult
@end
static uint64_t result(BOOL ok, NSString *payload, NSString *report, NSString *digest) {
    MMResult *r = [MMResult new]; r.ok = ok; r.fields = @[payload ?: @"", report ?: @"", digest ?: @""];
    return (uint64_t)CFBridgingRetain(r);
}
static uint64_t fail(NSString *message) { return result(NO,@"",message,@""); }
static NSString *sha(NSData *data) {
    if (!data) return @"absent";
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    NSMutableString *s = [NSMutableString string];
    for (int i=0;i<CC_SHA256_DIGEST_LENGTH;i++) [s appendFormat:@"%02x", bytes[i]];
    return s;
}
static NSData *readBounded(NSString *path, NSString **error, BOOL absentOK) {
    int fd = open(path.fileSystemRepresentation, O_RDONLY|O_NOFOLLOW|O_NONBLOCK);
    if (fd < 0) { if (!(absentOK && errno == ENOENT)) *error = @"Cannot read regular local file"; return nil; }
    struct stat st;
    if (fstat(fd,&st) || !S_ISREG(st.st_mode) || st.st_size > (off_t)MMMaxBytes || st.st_size < 0) {
        close(fd); *error = @"File type/byte limit rejected"; return nil;
    }
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)st.st_size];
    NSUInteger n = 0;
    while (n < data.length) {
        ssize_t count = read(fd,(char *)data.mutableBytes+n,data.length-n);
        if (count <= 0) { close(fd); *error = @"File changed or read failed"; return nil; }
        n += (NSUInteger)count;
    }
    char extra; ssize_t tail = read(fd,&extra,1); close(fd);
    if (tail != 0) { *error = @"File grew while reading"; return nil; }
    return data;
}
static NSString *utf8(NSData *data, NSString **error) {
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s || [s rangeOfString:[NSString stringWithFormat:@"%C",(unichar)0]].location != NSNotFound) *error = @"UTF-8 required; NUL rejected";
    return s;
}
static BOOL atomicWrite(NSString *path, NSData *data, NSString **error) {
    if (data.length > MMMaxBytes) { *error = @"Output byte limit"; return NO; }
    NSString *template = [path stringByAppendingString:@".tmp.XXXXXX"];
    char *name = strdup(template.fileSystemRepresentation);
    int fd = mkstemp(name);
    if (fd < 0) { free(name); *error = @"Cannot create temporary sibling"; return NO; }
    BOOL ok = fchmod(fd,0600) == 0;
    NSUInteger offset = 0;
    while (ok && offset < data.length) {
        ssize_t n = write(fd,(char *)data.bytes+offset,data.length-offset);
        if (n <= 0) ok = NO; else offset += (NSUInteger)n;
    }
    if (ok && fsync(fd)) ok = NO;
    if (close(fd)) ok = NO;
    if (ok && rename(name,path.fileSystemRepresentation)) ok = NO;
    if (!ok) { unlink(name); *error = @"Atomic save failed; previous file retained"; }
    free(name);
    if (ok) {
        int dir = open(path.stringByDeletingLastPathComponent.fileSystemRepresentation,O_RDONLY);
        if (dir >= 0) { if (fsync(dir)) *error = @"Saved, directory durability could not be confirmed"; close(dir); }
        else *error = @"Saved, directory durability could not be confirmed";
    }
    return ok;
}
uint64_t moxi_mm_read(const char *path) {
    @autoreleasepool {
        NSString *error = nil; NSData *data = readBounded(@(path),&error,NO);
        NSString *text = data ? utf8(data,&error) : nil;
        return error ? fail(error) : result(YES,text,@"Loaded local file",sha(data));
    }
}
uint64_t moxi_mm_write(const char *path, const char *text, const char *expected, int recovery) {
    @autoreleasepool {
        NSString *file = @(path), *error = nil;
        NSString *lockPath = [file stringByAppendingString:@".lock"];
        int lock = open(lockPath.fileSystemRepresentation,O_CREAT|O_RDWR|O_NOFOLLOW|O_NONBLOCK,0600);
        if (lock < 0 || flock(lock,LOCK_EX|LOCK_NB)) { if (lock >= 0) close(lock); return fail(@"File is busy or lock unavailable"); }
        NSData *prior = readBounded(file,&error,YES);
        NSString *digest = sha(prior);
        if (!error && ![digest isEqualToString:@(expected)]) error = @"External file change: reopen or save to another path";
        NSString *payload = @(text);
        NSString *target = recovery ? [file stringByAppendingString:@".recovery"] : file;
        if (recovery) payload = [NSString stringWithFormat:@"MOXI-RECOVERY\t1\t%@\n%@",digest,payload];
        NSData *data = [payload dataUsingEncoding:NSUTF8StringEncoding];
        BOOL ok = !error && atomicWrite(target,data,&error);
        flock(lock,LOCK_UN); close(lock); // Keep lock inode stable for concurrent cooperating writers.
        return ok ? result(YES,@"",error ?: (recovery ? @"Recovery snapshot written; saved file unchanged" : @"Atomically saved"),recovery ? digest : sha(data)) : fail(error);
    }
}
uint64_t moxi_mm_recover(const char *path) {
    @autoreleasepool {
        NSString *error = nil, *file = @(path);
        NSData *base = readBounded(file,&error,YES);
        if (error) return fail(error);
        NSData *recovery = readBounded([file stringByAppendingString:@".recovery"],&error,NO);
        NSString *text = recovery ? utf8(recovery,&error) : nil;
        if (error) return fail(error);
        NSString *prefix = [NSString stringWithFormat:@"MOXI-RECOVERY\t1\t%@\n",sha(base)];
        if (![text hasPrefix:prefix]) return fail(@"Recovery is interrupted, malformed or belongs to a different saved revision");
        return result(YES,[text substringFromIndex:prefix.length],@"Recovered in memory; saved file remains unchanged",sha(base));
    }
}

static NSString *escape(NSString *s) {
    return [[[[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"] stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"] stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
}
@interface MMImporter : NSObject <NSXMLParserDelegate>
@property NSMutableArray<NSMutableDictionary *> *nodes;
@property NSMutableArray<NSNumber *> *stack;
@property NSMutableArray<NSString *> *elements;
@property NSMutableArray<NSDictionary *> *arrows;
@property NSMutableDictionary<NSString *,NSNumber *> *ids;
@property NSMutableSet<NSString *> *losses;
@property NSString *error;
@property NSUInteger depth, nodeDepth, roots;
@property BOOL sawMap;
@property NSUInteger skippedDepth;
@end
@implementation MMImporter
- (instancetype)init {
    if ((self=[super init])) { _nodes=[NSMutableArray new]; _stack=[NSMutableArray new]; _elements=[NSMutableArray new]; _arrows=[NSMutableArray new]; _ids=[NSMutableDictionary new]; _losses=[NSMutableSet new]; }
    return self;
}
- (void)reject:(NSXMLParser *)parser reason:(NSString *)reason { self.error=reason; [parser abortParsing]; }
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name namespaceURI:(NSString *)uri qualifiedName:(NSString *)q attributes:(NSDictionary<NSString *,NSString *> *)a {
    (void)uri; (void)q;
    NSString *parentElement=self.elements.lastObject;
    [self.elements addObject:name];
    self.depth++;
    if (self.depth > MMMaxDepth * 2 || a.count > 100 || self.nodes.count > MMMaxTopics) { [self reject:parser reason:@"Import resource limit"]; return; }
    for (NSString *key in a) if ([a[key] lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > MMMaxText) { [self reject:parser reason:@"Attribute text limit"]; return; }
    if (self.skippedDepth) return;
    if ([name isEqual:@"map"]) {
        if (self.sawMap || self.depth != 1) { [self reject:parser reason:@"One map document required"]; return; }
        self.sawMap=YES;
        if (![a[@"version"] isEqual:@"freeplane 1.13.3"] && ![a[@"version"] isEqual:@"1.0.1"] && ![a[@"version"] isEqual:@"freeplane 1.9.8"]) [self.losses addObject:@"Unrecognized map version: imported bounded structural subset only"];
        for (NSString *key in a) if (![key isEqual:@"version"]) [self.losses addObject:[@"Map attribute omitted: " stringByAppendingString:key]];
    } else if ([name isEqual:@"node"]) {
        if (![parentElement isEqual:@"node"] && ![parentElement isEqual:@"map"]) { [self reject:parser reason:@"Topic must be a direct map or topic child"]; return; }
        if (!self.sawMap || self.stack.count > MMMaxDepth || self.nodes.count >= MMMaxTopics) { [self reject:parser reason:@"Topic/depth limit"]; return; }
        if (!self.stack.count && ++self.roots != 1) { [self reject:parser reason:@"Multiple roots"]; return; }
        NSString *sourceID = a[@"ID"];
        if (sourceID && self.ids[sourceID]) { [self reject:parser reason:@"Duplicate source ID"]; return; }
        NSNumber *id = @(self.nodes.count + 1);
        if (sourceID) self.ids[sourceID]=id;
        if (a[@"POSITION"] && ![a[@"POSITION"] isEqual:@"left"] && ![a[@"POSITION"] isEqual:@"right"]) [self.losses addObject:@"Unsupported POSITION normalized to right"];
        if (a[@"FOLDED"] && ![a[@"FOLDED"] isEqual:@"true"] && ![a[@"FOLDED"] isEqual:@"false"]) [self.losses addObject:@"Unsupported FOLDED value normalized to expanded"];
        NSString *link = a[@"LINK"] ?: @"";
        if (link.length && ![link hasPrefix:@"https://"] && ![link hasPrefix:@"http://"] && ![link hasPrefix:@"mailto:"] && ![link hasPrefix:@"#"]) { link=@""; [self.losses addObject:@"Unsafe/local/executable hyperlink omitted (links are never launched)"]; }
        NSMutableDictionary *node=[@{@"id":id,@"parent":self.stack.lastObject ?: @(-1),@"text":a[@"TEXT"] ?: @"",@"side":[a[@"POSITION"] isEqual:@"left"] ? @(-1) : @(1),@"folded":[a[@"FOLDED"] isEqual:@"true"] ? @1 : @0,@"note":@"",@"link":link,@"icons":@""} mutableCopy];
        [self.nodes addObject:node]; [self.stack addObject:id];
        NSSet *supported=[NSSet setWithArray:@[@"ID",@"TEXT",@"POSITION",@"FOLDED",@"LINK"]];
        for (NSString *key in a) if (![supported containsObject:key]) [self.losses addObject:[@"Node attribute omitted: " stringByAppendingString:key]];
    } else if ([name isEqual:@"arrowlink"] && [parentElement isEqual:@"node"]) {
        if (self.arrows.count >= MMMaxTopics*2) { [self reject:parser reason:@"Crosslink limit"]; return; }
        [self.arrows addObject:@{@"source":self.stack.lastObject,@"target":a[@"DESTINATION"] ?: @"",@"label":a[@"MIDDLE_LABEL"] ?: @""}];
        for (NSString *key in a) if (![@[@"DESTINATION",@"MIDDLE_LABEL"] containsObject:key]) [self.losses addObject:[@"Connector attribute omitted: " stringByAppendingString:key]];
    } else if ([name isEqual:@"icon"] && [parentElement isEqual:@"node"]) {
        NSMutableDictionary *node=self.nodes[self.stack.lastObject.unsignedIntegerValue-1];
        NSString *icons=[node[@"icons"] stringByAppendingFormat:@"%@%@",[node[@"icons"] length] ? @"," : @"",a[@"BUILTIN"] ?: @""];
        if (icons.length > MMMaxText) { [self reject:parser reason:@"Icon limit"]; return; }
        node[@"icons"]=icons;
        [self.losses addObject:@"Icons retained as inert names; original artwork not imported"];
        for (NSString *key in a) if (![key isEqual:@"BUILTIN"]) [self.losses addObject:[@"Icon attribute omitted: " stringByAppendingString:key]];
    } else {
        self.skippedDepth=self.depth;
        [self.losses addObject:[@"Element omitted, never executed: " stringByAppendingString:name]];
    }
    if (self.losses.count > 128) { [self reject:parser reason:@"Unsupported feature report limit"]; }
}
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name namespaceURI:(NSString *)uri qualifiedName:(NSString *)q {
    (void)parser; (void)uri; (void)q;
    if (self.skippedDepth == self.depth) self.skippedDepth=0;
    else if (!self.skippedDepth && [name isEqual:@"node"] && self.stack.count) [self.stack removeLastObject];
    if (self.depth) self.depth--;
    if (self.elements.count) [self.elements removeLastObject];
}
- (NSData *)parser:(NSXMLParser *)parser resolveExternalEntityName:(NSString *)name systemID:(NSString *)systemID { (void)name; (void)systemID; [self reject:parser reason:@"External entity forbidden"]; return nil; }
- (void)parser:(NSXMLParser *)parser foundInternalEntityDeclarationWithName:(NSString *)name value:(NSString *)value { (void)name; (void)value; [self reject:parser reason:@"Entity declarations forbidden"]; }
@end
uint64_t moxi_mm_import(const char *path) {
    @autoreleasepool {
        NSString *error=nil; NSData *data=readBounded(@(path),&error,NO);
        NSString *text=data ? utf8(data,&error) : nil;
        if (error) return fail(error);
        NSString *upper=text.uppercaseString;
        if ([upper containsString:@"<!DOCTYPE"] || [upper containsString:@"<!ENTITY"]) return fail(@"DTD/entity declarations forbidden");
        NSXMLParser *parser=[[NSXMLParser alloc] initWithData:data];
        MMImporter *importer=[MMImporter new]; parser.delegate=importer;
        parser.shouldResolveExternalEntities=NO;
        if (![parser parse] || importer.error || importer.roots != 1) return fail(importer.error ?: @"Malformed XML or missing root");
        NSMutableString *output=[NSMutableString stringWithFormat:@"MOXI-MINDMAP\t1\t1\t%lu\t0\n",importer.nodes.count+1];
        for (NSDictionary *n in importer.nodes) [output appendFormat:@"T\t%@\t%@\t%@\t0\t0\t%@\t%@\t%@\t%@\t\t%@\n",n[@"id"],n[@"parent"],n[@"side"],n[@"folded"],escape(n[@"text"]),escape(n[@"note"]),escape(n[@"link"]),escape(n[@"icons"])];
        NSUInteger edge=0;
        for (NSDictionary *a in importer.arrows) {
            NSNumber *target=importer.ids[a[@"target"]];
            if (!target || [target isEqual:a[@"source"]]) { [importer.losses addObject:@"Dangling/self connector omitted"]; continue; }
            [output appendFormat:@"L\t%lu\t%@\t%@\t%@\n",++edge,a[@"source"],target,escape(a[@"label"])];
        }
        NSArray *losses=[importer.losses.allObjects sortedArrayUsingSelector:@selector(compare:)];
        NSString *report=[NSString stringWithFormat:@"Imported %lu topics, %lu connectors. Source unchanged.\n%@",importer.nodes.count,edge,losses.count ? [losses componentsJoinedByString:@"\n"] : @"No unsupported features encountered in the supported subset."];
        return result(YES,output,report,sha(data));
    }
}
static NSString *recoveryDirectory(void) {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/MoxiMindmap/Recovery"];
}
uint64_t moxi_mm_draft_path(void) {
    @autoreleasepool {
        NSError *error=nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:recoveryDirectory() withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error]) return fail(@"Cannot create private draft recovery directory");
        return result(YES,[recoveryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".moxi"]],@"",@"absent");
    }
}
uint64_t moxi_mm_choose(int save) {
    @autoreleasepool {
        NSSavePanel *panel = save == 1 ? [NSSavePanel savePanel] : [NSOpenPanel openPanel];
        if (save != 1) { ((NSOpenPanel *)panel).canChooseDirectories=NO; ((NSOpenPanel *)panel).allowsMultipleSelection=NO; }
        panel.title = save == 1 ? @"Save Moxi mind map" : @"Open local mind map or .mm";
        if (save == 2) panel.directoryURL = [NSURL fileURLWithPath:recoveryDirectory()];
        if ([panel runModal] != NSModalResponseOK) return fail(@"File choice cancelled");
        return result(YES,panel.URL.path,@"",@"");
    }
}
int moxi_mm_result_ok(uint64_t h) { return ((__bridge MMResult *)(void *)h).ok; }
int moxi_mm_result_length(uint64_t h,int f) { MMResult *r=(__bridge MMResult *)(void *)h; return f>=0 && f<3 ? (int)r.fields[f].length : -1; }
int moxi_mm_result_codepoint(uint64_t h,int f,int offset) {
    MMResult *r=(__bridge MMResult *)(void *)h; if (f<0||f>=3||offset<0||(NSUInteger)offset>=r.fields[f].length) return -1;
    NSString *s=r.fields[f]; unichar high=[s characterAtIndex:offset];
    if (CFStringIsSurrogateHighCharacter(high) && (NSUInteger)(offset+1)<s.length) return (int)CFStringGetLongCharacterForSurrogatePair(high,[s characterAtIndex:offset+1]);
    return high;
}
void moxi_mm_result_free(uint64_t h) { if(h) CFBridgingRelease((void *)h); }

int moxi_mm_reduced_motion(void) {
    return NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion ? 1 : 0;
}
