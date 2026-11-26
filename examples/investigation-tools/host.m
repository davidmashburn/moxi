// Reuse I20's actual AppKit callback injection and content-view screenshots.
#import "../application-operations/host.m"

int investigation_save(const char *path, const char *text) {
    NSError *error = nil;
    return [@(text) writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:&error] ? 1 : 0;
}

// Test adapters enter through the canvas' normal NSTextInputClient/key callbacks.
void investigation_text(const char *text) {
    if (strlen(text)) {
        [moxi_canvas insertText:@(text) replacementRange:NSMakeRange(NSNotFound, 0)];
    } else {
        // AppKit sends deletion rather than insertText: for an empty replacement.
        [moxi_canvas doCommandBySelector:@selector(deleteBackward:)];
    }
}

void investigation_select_all(void) {
    [moxi_canvas selectAll:nil];
}

void investigation_resize(float width, float height) {
    [moxi_window setContentSize:NSMakeSize(width, height)];
}

int investigation_replay_mode(void) {
    const char *mode = getenv("MOXI_I10_REPLAY");
    if (!mode) return 0;
    if (!strcmp(mode, "create")) return 1;
    if (!strcmp(mode, "reopen")) return 2;
    if (!strcmp(mode, "invalid")) return 3;
    if (!strcmp(mode, "write-failure")) return 4;
    abort();
}
