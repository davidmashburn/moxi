// Experiment-local contract. No public Moxi API or global ownership changes.
#import <Cocoa/Cocoa.h>
#import <simd/simd.h>
#include <stdint.h>
typedef NS_ENUM(int, SPBackend) { SPBackendBridge, SPBackendSceneKit };
typedef NS_ENUM(int, SPCamera) { SPCameraPerspective, SPCameraOrthographic };
typedef struct { uint64_t scene, camera, geometry, viewport, generation; } SPRevision;
typedef struct { SPCamera kind; float yaw, pitch, distance, panX, panY; } SPView;
typedef struct { double encode_ms, wait_ms, gpu_ms, readback_ms, frame_ms, transfer_ms, alpha_ms; } SPTiming;
enum { SPMaxPixels = 2048, SPMaxObjects = 256, SPVerticesPerCube = 36 };
@interface SPFrame : NSObject
@property NSBitmapImageRep *bitmap;
@property SPRevision revision;
@property SPTiming timing;
@end
@interface SPRenderer : NSObject
@property(readonly) SPBackend backend;
@property(readonly) NSUInteger submissions;
@property(readonly) NSUInteger uploads;
@property(readonly) NSUInteger vertexCount;
@property(readonly) NSString *deviceName;
- (instancetype)initWithBackend:(SPBackend)backend;
- (BOOL)geometryWithObjects:(NSUInteger)objects repeats:(NSUInteger)repeats reverse:(BOOL)reverse;
- (SPFrame *)renderWidth:(NSUInteger)width height:(NSUInteger)height view:(SPView)view revision:(SPRevision)revision;
@end
BOOL SPRevisionEqual(SPRevision a, SPRevision b);
matrix_float4x4 SPProjection(SPCamera kind, float aspect, float distance);
matrix_float4x4 SPViewMatrix(SPView view);
