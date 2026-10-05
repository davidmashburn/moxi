/* Restore every original pasteboard item's data after the service check. */
#import <Cocoa/Cocoa.h>
#include <assert.h>
#include <stdio.h>

extern void moxi_clipboard_set(const char *text);
extern int moxi_clipboard_read_snapshot(void);
extern int moxi_clipboard_codepoint_at(int index);

int main(void) {
    @autoreleasepool {
        NSPasteboard *board = [NSPasteboard generalPasteboard];
        NSMutableArray<NSPasteboardItem *> *saved = [NSMutableArray array];
        for (NSPasteboardItem *item in board.pasteboardItems) {
            NSPasteboardItem *copy = [[NSPasteboardItem alloc] init];
            for (NSPasteboardType type in item.types) {
                NSData *data = [item dataForType:type];
                if (data != nil) [copy setData:data forType:type];
            }
            [saved addObject:copy];
        }
        BOOL passed = NO;
        @try {
            moxi_clipboard_set("A🙂日");
            passed = moxi_clipboard_read_snapshot() == 3 &&
                moxi_clipboard_codepoint_at(0) == 'A' &&
                moxi_clipboard_codepoint_at(1) == 0x1f642 &&
                moxi_clipboard_codepoint_at(2) == 0x65e5 &&
                moxi_clipboard_codepoint_at(-1) == -1 &&
                moxi_clipboard_codepoint_at(3) == -1;
            moxi_clipboard_set("changed");
            passed = passed && moxi_clipboard_codepoint_at(1) == 0x1f642 &&
                moxi_clipboard_read_snapshot() == 7;
            moxi_clipboard_set("");
            passed = passed && moxi_clipboard_read_snapshot() == 0 &&
                moxi_clipboard_codepoint_at(0) == -1;
        } @finally {
            [board clearContents];
            if (saved.count > 0) assert([board writeObjects:saved]);
        }
        assert(passed);
        puts("AppKit clipboard Unicode, empty content and stable snapshot: pass (original restored)");
    }
    return 0;
}
