// Reuse the REAL bridge's initialization, device and queue in this translation
// unit. This bounded extension is deliberately not added to the shipping bridge.
#import "../../native/macos_metal.m"
#import "spatial.h"
#if SP_SCENEKIT
#import <SceneKit/SceneKit.h>
#endif
#include <assert.h>
#include <stddef.h>
@implementation SPFrame
@end
BOOL SPRevisionEqual(SPRevision a, SPRevision b) {
    return a.scene==b.scene && a.camera==b.camera && a.geometry==b.geometry &&
        a.viewport==b.viewport && a.generation==b.generation;
}
matrix_float4x4 SPProjection(SPCamera kind, float aspect, float distance) {
    const float near=.1f, far=100.f;
    matrix_float4x4 m={0};
    if(kind==SPCameraPerspective) {
        float f=1/tanf(M_PI/8); // 45 degree vertical FOV, RH -Z, Metal depth [0,1].
        m.columns[0].x=f/aspect; m.columns[1].y=f;
        m.columns[2]=(vector_float4){0,0,far/(near-far),-1};
        m.columns[3].z=near*far/(near-far);
    } else {
        float h=distance*tanf(M_PI/8);
        m.columns[0].x=1/(h*aspect); m.columns[1].y=1/h;
        m.columns[2].z=1/(near-far); m.columns[3]=(vector_float4){0,0,near/(near-far),1};
    }
    return m;
}
matrix_float4x4 SPViewMatrix(SPView view) {
    vector_float3 target={view.panX,view.panY,0};
    vector_float3 eye=target+(vector_float3){sinf(view.yaw)*cosf(view.pitch),sinf(view.pitch),cosf(view.yaw)*cosf(view.pitch)}*view.distance;
    vector_float3 z=simd_normalize(eye-target), x=simd_normalize(simd_cross((vector_float3){0,1,0},z)), y=simd_cross(z,x);
    return (matrix_float4x4){.columns={{x.x,y.x,z.x,0},{x.y,y.y,z.y,0},{x.z,y.z,z.z,0},{-simd_dot(x,eye),-simd_dot(y,eye),-simd_dot(z,eye),1}}};
}
typedef struct { vector_float4 position, color; } SPVertex;
@interface SPRenderer () {
    id<MTLRenderPipelineState> _pipeline;
    id<MTLDepthStencilState> _depthState;
    id<MTLBuffer> _vertices;
    id<MTLTexture> _color, _depth;
#if SP_SCENEKIT
    SCNRenderer *_sceneRenderer;
    SCNNode *_cameraNode;
#endif
}
@end
@implementation SPRenderer
- (instancetype)initWithBackend:(SPBackend)backend {
    if (!(self=[super init])) return nil;
#if !SP_SCENEKIT
    if(backend==SPBackendSceneKit) return nil;
#endif
    if(backend!=SPBackendBridge && backend!=SPBackendSceneKit) return nil;
    if(!moxi_metal_init(16,16)) return nil;
    _backend=backend;
    _deviceName=moxi_metal_device.name;
    NSError *error=nil;
    NSString *source=@"#include <metal_stdlib>\nusing namespace metal;\nstruct V{float4 p;float4 c;};struct O{float4 p [[position]];float4 c;};vertex O spv(uint i [[vertex_id]],const device V*v [[buffer(0)]],constant float4x4&m [[buffer(1)]]){O o;o.p=m*v[i].p;o.c=v[i].c;return o;}fragment float4 spf(O o [[stage_in]]){return o.c;}";
    id<MTLLibrary> library=[moxi_metal_device newLibraryWithSource:source options:nil error:&error];
    if(!library) { NSLog(@"Spatial shader: %@",error); return nil; }
    MTLRenderPipelineDescriptor *p=[MTLRenderPipelineDescriptor new];
    p.vertexFunction=[library newFunctionWithName:@"spv"];
    p.fragmentFunction=[library newFunctionWithName:@"spf"];
    p.colorAttachments[0].pixelFormat=MTLPixelFormatRGBA8Unorm_sRGB;
    p.depthAttachmentPixelFormat=MTLPixelFormatDepth32Float;
    _pipeline=[moxi_metal_device newRenderPipelineStateWithDescriptor:p error:&error];
    MTLDepthStencilDescriptor *d=[MTLDepthStencilDescriptor new];
    d.depthCompareFunction=MTLCompareFunctionLess; d.depthWriteEnabled=YES;
    _depthState=[moxi_metal_device newDepthStencilStateWithDescriptor:d];
    if(!_pipeline || !_depthState) return nil;
#if SP_SCENEKIT
    if(backend==SPBackendSceneKit) {
        _sceneRenderer=[SCNRenderer rendererWithDevice:moxi_metal_device options:nil];
        _sceneRenderer.scene=[SCNScene scene];
        _sceneRenderer.autoenablesDefaultLighting=NO;
        _sceneRenderer.jitteringEnabled=NO;
        _cameraNode=[SCNNode node]; _cameraNode.camera=[SCNCamera camera];
        _cameraNode.camera.wantsHDR=NO;
        [_sceneRenderer.scene.rootNode addChildNode:_cameraNode];
        _sceneRenderer.pointOfView=_cameraNode;
    }
#endif
    return self;
}
- (BOOL)geometryWithObjects:(NSUInteger)objects repeats:(NSUInteger)repeats reverse:(BOOL)reverse {
    if(objects<1 || objects>SPMaxObjects || repeats<1 || repeats>128) return NO;
    // Front cube is submitted first. Rear geometry must lose the depth test.
    const int indices[36]={4,5,6,4,6,7,1,0,3,1,3,2,0,4,7,0,7,3,5,1,2,5,2,6,3,7,6,3,6,2,0,1,5,0,5,4};
    const vector_float3 corners[8]={{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}};
    _vertexCount=objects*SPVerticesPerCube*repeats;
    NSMutableData *data=[NSMutableData dataWithLength:_vertexCount*sizeof(SPVertex)];
    SPVertex *vertices=data.mutableBytes;
    for(NSUInteger o=0;o<objects;o++) {
        NSUInteger obj=reverse?objects-1-o:o;
        vector_float3 center=obj==0?(vector_float3){-.28,0,.5}:(vector_float3){.3f+(obj%8)*.16f,.18f+(obj/8)*.12f,-.55f-(obj%5)*.1f};
        vector_float4 color=obj==0?(vector_float4){1,.14,.035,1}:(vector_float4){.035,.55,.92,1};
        for(NSUInteger r=0;r<repeats;r++) for(int i=0;i<36;i++) {
            vector_float3 pos=corners[indices[i]]*.65f+center;
            float shade=1.f-(i/6)*.09f;
            vertices[(o*repeats+r)*36+i]=(SPVertex){(vector_float4){pos.x,pos.y,pos.z,1},color*(vector_float4){shade,shade,shade,1}};
        }
    }
    if(_backend==SPBackendBridge) _vertices=[moxi_metal_device newBufferWithBytes:data.bytes length:data.length options:MTLResourceStorageModeShared];
#if SP_SCENEKIT
    else {
        SCNGeometrySource *position=[SCNGeometrySource geometrySourceWithData:data semantic:SCNGeometrySourceSemanticVertex vectorCount:_vertexCount floatComponents:YES componentsPerVector:3 bytesPerComponent:4 dataOffset:offsetof(SPVertex,position) dataStride:sizeof(SPVertex)];
        SCNGeometrySource *color=[SCNGeometrySource geometrySourceWithData:data semantic:SCNGeometrySourceSemanticColor vectorCount:_vertexCount floatComponents:YES componentsPerVector:4 bytesPerComponent:4 dataOffset:offsetof(SPVertex,color) dataStride:sizeof(SPVertex)];
        NSMutableData *indexData=[NSMutableData dataWithLength:_vertexCount*sizeof(uint32_t)];
        for(NSUInteger i=0;i<_vertexCount;i++) ((uint32_t *)indexData.mutableBytes)[i]=(uint32_t)i;
        SCNGeometryElement *element=[SCNGeometryElement geometryElementWithData:indexData primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:_vertexCount/3 bytesPerIndex:4];
        SCNGeometry *geometry=[SCNGeometry geometryWithSources:@[position,color] elements:@[element]];
        SCNMaterial *material=[SCNMaterial material]; material.lightingModelName=SCNLightingModelConstant;
        material.diffuse.contents=NSColor.whiteColor; material.doubleSided=YES;
        material.readsFromDepthBuffer=YES; material.writesToDepthBuffer=YES; geometry.materials=@[material];
        for(SCNNode *node in [_sceneRenderer.scene.rootNode.childNodes copy]) if(node!=_cameraNode) [node removeFromParentNode];
        [_sceneRenderer.scene.rootNode addChildNode:[SCNNode nodeWithGeometry:geometry]];
    }
#endif
    _uploads++; return YES;
}
- (SPFrame *)renderWidth:(NSUInteger)width height:(NSUInteger)height view:(SPView)view revision:(SPRevision)revision {
    if(width<1 || height<1 || width>SPMaxPixels || height>SPMaxPixels || !_vertexCount ||
       (view.kind!=SPCameraPerspective && view.kind!=SPCameraOrthographic) ||
       !isfinite(view.yaw) || !isfinite(view.pitch) || !isfinite(view.distance) ||
       !isfinite(view.panX) || !isfinite(view.panY) || fabsf(view.pitch)>1.4f || view.distance<2 || view.distance>40) return nil;
    double begin=CACurrentMediaTime();
    if(!_color || _color.width!=width || _color.height!=height) {
        MTLTextureDescriptor *t=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm_sRGB width:width height:height mipmapped:NO];
        t.usage=MTLTextureUsageRenderTarget; t.storageMode=MTLStorageModeShared;
        _color=[moxi_metal_device newTextureWithDescriptor:t];
        t.pixelFormat=MTLPixelFormatDepth32Float; t.storageMode=MTLStorageModePrivate;
        _depth=[moxi_metal_device newTextureWithDescriptor:t];
        if(!_color || !_depth) return nil;
    }
    id<MTLCommandBuffer> command=[moxi_metal_queue commandBuffer];
    MTLRenderPassDescriptor *pass=[MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture=_color; pass.colorAttachments[0].loadAction=MTLLoadActionClear;
    pass.colorAttachments[0].storeAction=MTLStoreActionStore;
    pass.colorAttachments[0].clearColor=MTLClearColorMake(.1,.15,.2,.5); // Linear, premultiplied.
    pass.depthAttachment.texture=_depth; pass.depthAttachment.loadAction=MTLLoadActionClear;
    pass.depthAttachment.storeAction=MTLStoreActionDontCare; pass.depthAttachment.clearDepth=1;
    matrix_float4x4 projection=SPProjection(view.kind,(float)width/height,view.distance), camera=SPViewMatrix(view);
    if(_backend==SPBackendBridge) {
        id<MTLRenderCommandEncoder> e=[command renderCommandEncoderWithDescriptor:pass];
        [e setRenderPipelineState:_pipeline]; [e setDepthStencilState:_depthState];
        [e setCullMode:MTLCullModeNone]; [e setVertexBuffer:_vertices offset:0 atIndex:0];
        matrix_float4x4 m=simd_mul(projection,camera); [e setVertexBytes:&m length:sizeof(m) atIndex:1];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:_vertexCount]; [e endEncoding];
    }
#if SP_SCENEKIT
    else {
        // Adapt the shared camera parameters to SceneKit's camera boundary.
        [SCNTransaction begin]; [SCNTransaction setDisableActions:YES];
        SCNCamera *scnCamera=_cameraNode.camera;
        scnCamera.wantsHDR=NO; scnCamera.zNear=.1; scnCamera.zFar=100;
        scnCamera.fieldOfView=45; scnCamera.projectionDirection=SCNCameraProjectionDirectionVertical;
        scnCamera.usesOrthographicProjection=view.kind==SPCameraOrthographic;
        scnCamera.orthographicScale=view.distance*tanf(M_PI/8);
        _cameraNode.camera=scnCamera;
        _cameraNode.simdTransform=simd_inverse(camera);
        [SCNTransaction commit]; [SCNTransaction flush];
        [_sceneRenderer renderAtTime:CACurrentMediaTime() viewport:CGRectMake(0,0,width,height) commandBuffer:command passDescriptor:pass];
    }
#endif
    double encoded=CACurrentMediaTime(); [command commit]; [command waitUntilCompleted];
    double completed=CACurrentMediaTime();
    if(command.status!=MTLCommandBufferStatusCompleted) { NSLog(@"GPU failure %@",command.error); return nil; }
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:width pixelsHigh:height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bitmapFormat:0 bytesPerRow:width*4 bitsPerPixel:32];
    double transferStart=CACurrentMediaTime();
    [_color getBytes:bitmap.bitmapData bytesPerRow:width*4 fromRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0];
    double transferEnd=CACurrentMediaTime();
    // GPU target stores sRGB-encoded premultiplied LINEAR RGB. Convert to encoded
    // premultiplied RGB for AppKit; unpremultiply in linear space before encoding.
    uint8_t *bytes=bitmap.bitmapData;
    for(NSUInteger i=0;i<width*height;i++) {
        float a=bytes[i*4+3]/255.f;
        if(a>0 && a<1) for(int c=0;c<3;c++) {
            float s=bytes[i*4+c]/255.f, linear=s<=.04045f?s/12.92f:powf((s+.055f)/1.055f,2.4f);
            float straight=fminf(1,linear/a), encoded=straight<=.0031308f?12.92f*straight:1.055f*powf(straight,1/2.4f)-.055f;
            bytes[i*4+c]=(uint8_t)lrintf(encoded*a*255);
        }
    }
    bitmap=[bitmap bitmapImageRepByRetaggingWithColorSpace:NSColorSpace.sRGBColorSpace];
    double read=CACurrentMediaTime(); _submissions++;
    SPFrame *frame=[SPFrame new]; frame.bitmap=bitmap; frame.revision=revision;
    frame.timing=(SPTiming){(encoded-begin)*1000,(completed-encoded)*1000,
        command.GPUEndTime>command.GPUStartTime?(command.GPUEndTime-command.GPUStartTime)*1000:NAN,
        (read-completed)*1000,(read-begin)*1000,(transferEnd-transferStart)*1000,(read-transferEnd)*1000};
    return frame;
}
@end
