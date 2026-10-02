#import <Cocoa/Cocoa.h>

// AppKit retains this immutable payload with its draw slot. No link dependency
// on the optional CoreText provider is introduced into ordinary native apps.
@protocol MoxiParagraphDrawing
- (void)drawAt:(NSPoint)origin color:(NSColor *)color;
@end
