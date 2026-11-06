/* Included only by macos_window.m: public bounded composition, not image-table
 * injection. Kept separate to make the F02 ownership seam reviewable. */
#import "macos_composition.h"
@interface MoxiComposition : NSObject
@property(nonatomic, weak) MoxiWindowState *owner;
@property(nonatomic) uint64_t ownerID, token, serial;
@property(nonatomic, strong) NSImage *image;
@property(nonatomic) int slot;
@property(nonatomic, strong) NSImage *snapshot;
@end
@implementation MoxiComposition
@end
static MoxiComposition *moxi_compositions[32];
static uint64_t moxi_next_composition = 1;
static BOOL moxi_composition_owner_open(MoxiWindowState *owner) {
  if (!owner || owner->retired)
    return NO;
  __attribute__((cleanup(moxi_restore_context))) MoxiWindowState *previous =
      moxi_active_context;
  moxi_active_context = owner;
  return moxi_window_opened && moxi_canvas != nil;
}
static MoxiComposition *moxi_composition_find(uint64_t owner, uint64_t token) {
  if (![NSThread isMainThread] || !owner || !token)
    return nil;
  for (int i = 0; i < 32; i++) {
    MoxiComposition *r = moxi_compositions[i];
    if (r && !moxi_composition_owner_open(r.owner)) {
      moxi_compositions[i] = nil;
      continue;
    }
    if (r.ownerID == owner && r.token == token)
      return r;
  }
  return nil;
}
uint64_t moxi_composition_acquire(uint64_t owner) {
  if (![NSThread isMainThread] || !owner || !moxi_next_composition)
    return 0;
  __attribute__((cleanup(moxi_restore_context))) MoxiWindowState *previous =
      moxi_active_context;
  if (!moxi_window_select_instance(owner) || !moxi_canvas ||
      !moxi_window_opened)
    return 0;
  (void)moxi_composition_find(owner, UINT64_MAX); // collect retired slots
  for (int i = 0; i < 32; i++)
    if (!moxi_compositions[i]) {
      MoxiComposition *r = [MoxiComposition new];
      r.slot = -1;
      r.owner = moxi_active_context;
      r.ownerID = owner;
      r.token = moxi_next_composition++;
      moxi_compositions[i] = r;
      return r.token;
    }
  return 0;
}
int moxi_composition_publish(uint64_t owner, uint64_t token, uint64_t serial,
                             const uint8_t *rgba, size_t length, int width,
                             int height, int stride) {
  MoxiComposition *r = moxi_composition_find(owner, token);
  if (!r || !rgba || serial <= r.serial || width < 1 || height < 1 ||
      width > 2048 || height > 2048 || stride < width * 4 || stride > 8192 ||
      length != (size_t)stride * height)
    return 0;
  NSBitmapImageRep *b =
      [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                              pixelsWide:width
                                              pixelsHigh:height
                                           bitsPerSample:8
                                         samplesPerPixel:4
                                                hasAlpha:YES
                                                isPlanar:NO
                                          colorSpaceName:NSDeviceRGBColorSpace
                                            bitmapFormat:0
                                             bytesPerRow:width * 4
                                            bitsPerPixel:32];
  if (!b)
    return 0;
  for (int y = 0; y < height; y++)
    memcpy(b.bitmapData + y * width * 4, rgba + y * stride, width * 4);
  b = [b bitmapImageRepByRetaggingWithColorSpace:NSColorSpace.sRGBColorSpace];
  NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
  [image addRepresentation:b];
  r.image = image;
  r.serial = serial;
  return 1;
}
int moxi_composition_compose(uint64_t owner, uint64_t token, int slot, float x,
                             float y, float width, float height) {
  MoxiComposition *r = moxi_composition_find(owner, token);
  if (!r || !r.image || (r.slot >= 0 && r.slot != slot) || slot < 0 ||
      slot >= MOXI_MAX_DRAW_COMMANDS || !isfinite(x) || !isfinite(y) ||
      !isfinite(width) || !isfinite(height) || width <= 0 || height <= 0)
    return 0;
  __attribute__((cleanup(moxi_restore_context))) MoxiWindowState *previous =
      moxi_active_context;
  if (!moxi_window_select_instance(owner))
    return 0;
  moxi_window_set_image_at(slot, -1, "Spatial viewport", x, y, width, height, 0,
                           0, 0, 0, 1, 1, 1, 1, 0);
  moxi_image_resources[slot] = r.image;
  r.slot = slot;
  r.snapshot = r.image;
  return 1;
}
int moxi_composition_release(uint64_t owner, uint64_t token) {
  MoxiComposition *r = moxi_composition_find(owner, token);
  if (!r)
    return 0;
  __attribute__((cleanup(moxi_restore_context))) MoxiWindowState *previous =
      moxi_active_context;
  if (!moxi_window_select_instance(owner))
    return 0;
  // Frames may retain earlier snapshots. Associate slots by resource identity
  // separately from the current image so replacing a snapshot is safe.
  for (int i = 0; i < 32; i++)
    if (moxi_compositions[i] == r)
      moxi_compositions[i] = nil;
  if (r.slot >= 0 && moxi_image_resources[r.slot] == r.snapshot)
    moxi_image_resources[r.slot] = nil;
  [moxi_canvas setNeedsDisplay:YES];
  return 1;
}
