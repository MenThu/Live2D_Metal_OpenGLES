//
//  DYMetalRender.m
//  iOSLive2DDemo
//
//  Created by menthu on 2021/6/29.
//

#import "DYMetalRender.h"
#import "DYMTLTexturePixelMapper.h"
#import "L2DBufferIndex.h"
#import "L2DUserModel.h"
#import "L2DMetalDrawable.h"
#import "DYShaderTypes.h"

@interface DYMetalRender ()

@property (nonatomic, strong, readwrite) DYMTLTexturePixelMapper *texturePixelMapper;
@property (nonatomic, weak) id <MTLDevice> currentDevice;
@property (nonatomic, assign) MTLPixelFormat currentPixelFormat;
@property (nonatomic, strong) MTLRenderPassDescriptor *clearMaskRenderPassDescriptor;
@property (nonatomic, strong) MTLRenderPassDescriptor *renderToTextureRenderPassDescriptor;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineStateBlendingAdditive;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineStateBlendingMultiplicative;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineStateBlendingNormal;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineStateMasking;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineStateUploadTexture;
@property (nonatomic, weak) L2DUserModel *live2DModel;
@property (nonatomic, strong) id<MTLBuffer> transformBuffer;
@property (nonatomic, strong) NSMutableArray <L2DMetalDrawable *> *drawables;
@property (nonatomic, copy) NSArray <L2DMetalDrawable *> *drawableSorted;
@property (nonatomic, strong) NSMutableArray<id<MTLTexture>> *textures;

@end

@implementation DYMetalRender


#pragma mark - LifeCycle
- (instancetype)initWithDevice:(id<MTLDevice>)device
                   pixelFormat:(MTLPixelFormat)pixelFormat{
    if (self = [super init]) {
        _origin = CGPointZero;
        _scale = 1.0;
        _transform = matrix_identity_float4x4;
        _drawables = [NSMutableArray array];
        _drawableSorted = [NSMutableArray array];
        _textures = [NSMutableArray array];
        self.currentDevice = device;
        self.currentPixelFormat = pixelFormat;
        [self createPipelineStatesWithView:device];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"[%@] dealloc - %p", NSStringFromClass(self.class), self);
}

#pragma mark - ConfigMetal
- (void)createBuffersWithView:(id<MTLDevice>)device {
    if (!device) {
        return;
    }
    L2DUserModel *model = self.live2DModel;
    if (!model) {
        return;
    }

    matrix_float4x4 transform = self.transform;
    self.transformBuffer = [device newBufferWithBytes:&(transform) length:sizeof(matrix_float4x4) options:MTLResourceCPUCacheModeDefaultCache];

    int drawableCount = model.drawableCount;
    [self.drawables removeAllObjects];

    for (int i = 0; i < drawableCount; i++) {
        @autoreleasepool {
            L2DMetalDrawable *drawable = [[L2DMetalDrawable alloc] init];
            drawable.drawableIndex = i;

            RawFloatArray *vertexPositions = [model vertexPositionsForDrawable:i];
            if (vertexPositions) {
                drawable.vertexCount = vertexPositions.count;
                if (drawable.vertexCount > 0) {
                    drawable.vertexPositionBuffer = [device newBufferWithBytes:vertexPositions.floats length:(2 * vertexPositions.count * sizeof(float)) options:MTLResourceCPUCacheModeDefaultCache];
                }
            }

            RawFloatArray *vertexTextureCoords = [model vertexTextureCoordinateForDrawable:i];
            if (vertexTextureCoords) {
                if (drawable.vertexCount > 0) {
                    drawable.vertexTextureCoordinateBuffer = [device newBufferWithBytes:vertexTextureCoords.floats length:(2 * vertexTextureCoords.count * sizeof(float)) options:MTLResourceCPUCacheModeDefaultCache];
                }
            }

            RawUShortArray *vertexIndices = [model vertexIndicesForDrawable:i];
            if (vertexIndices) {
                drawable.indexCount = vertexIndices.count;
                if (drawable.indexCount > 0) {
                    drawable.vertexIndexBuffer = [device newBufferWithBytes:vertexIndices.ushorts length:(vertexIndices.count * sizeof(ushort)) options:MTLResourceCPUCacheModeDefaultCache];
                }
            }

            // Textures.
            drawable.textureIndex = [model textureIndexForDrawable:i];

            // Mask.
            RawIntArray *masks = [model masksForDrawable:i];
            if (masks) {
                drawable.maskCount = masks.count;
                drawable.masks = [masks intArray];
            }

            // Render mode.
            drawable.blendMode = [model blendingModeForDrawable:i];
            drawable.cullingMode = [model cullingModeForDrawable:i];

            // Opacity.
            drawable.opacity = [model opacityForDrawable:i];
            
            float opacity = drawable.opacity;
            float *list = (float *)&opacity;
            drawable.opacityBuffer = [device newBufferWithBytes:list length:sizeof(float) options:MTLResourceCPUCacheModeDefaultCache];

            drawable.visibility = [model visibilityForDrawable:i];

            [self.drawables addObject:drawable];
        }
    }
    // Sort drawables.
    NSArray<NSNumber *> *renderOrders = model.renderOrders.intArray;
    self.drawableSorted = [self.drawables sortedArrayUsingComparator:^NSComparisonResult(L2DMetalDrawable *obj1, L2DMetalDrawable *obj2) {
        NSComparisonResult result = NSOrderedAscending;
        int obj1Value = renderOrders[obj1.drawableIndex].intValue;
        int obj2Value = renderOrders[obj2.drawableIndex].intValue;
        if (obj1Value > obj2Value) {
            result = NSOrderedDescending;
        } else if (obj1Value == obj2Value) {
            result = NSOrderedSame;
        }
        return result;
    }];
}

- (void)createTexturesWithView:(id<MTLDevice>)device {
    if (!device) {
        return;
    }
    L2DUserModel *model = self.live2DModel;
    if (!model) {
        return;
    }
    if (model.textureURLs) {
        MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:device];
        [self.textures removeAllObjects];
        for (NSURL *url in model.textureURLs) {
            @autoreleasepool {
                id<MTLTexture> texture = [loader newTextureWithContentsOfURL:url
                                                                     options:@{MTKTextureLoaderOptionTextureStorageMode: @(MTLStorageModePrivate),
                                                                               MTKTextureLoaderOptionTextureUsage: @(MTLTextureUsageShaderRead),
                                                                               MTKTextureLoaderOptionSRGB: @(false)}
                                                                       error:nil];
                [self.textures addObject:texture];
            }
        }
    }
    [self configDrawableMaskTextureIfNeed];
}

- (void)createPipelineStatesWithView:(id<MTLDevice>)device {
    if (!device) {
        return;
    }

    NSError *error;

    // Library for shaders.
    id<MTLLibrary> library = [device newDefaultLibraryWithBundle:[NSBundle mainBundle] error:&error];

    if (!library || error) {
        return;
    }

    MTLRenderPipelineDescriptor *pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexFunction = [library newFunctionWithName:@"basic_vertex"];
    pipelineDesc.fragmentFunction = [library newFunctionWithName:@"basic_fragment"];

    // Vertex descriptor.
    MTLVertexDescriptor *vertexDesc = [[MTLVertexDescriptor alloc] init];

    // Vertex attributes.
    vertexDesc.attributes[L2DAttributeIndexPosition].bufferIndex = L2DBufferIndexPosition;
    vertexDesc.attributes[L2DAttributeIndexPosition].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[L2DAttributeIndexPosition].offset = 0;

    vertexDesc.attributes[L2DAttributeIndexUV].bufferIndex = L2DBufferIndexUV;
    vertexDesc.attributes[L2DAttributeIndexUV].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[L2DAttributeIndexUV].offset = 0;

    vertexDesc.attributes[L2DAttributeIndexOpacity].bufferIndex = L2DBufferIndexOpacity;
    vertexDesc.attributes[L2DAttributeIndexOpacity].format = MTLVertexFormatFloat;
    vertexDesc.attributes[L2DAttributeIndexOpacity].offset = 0;

    // Buffer layouts.
    vertexDesc.layouts[L2DBufferIndexPosition].stride = sizeof(float) * 2;

    vertexDesc.layouts[L2DBufferIndexUV].stride = sizeof(float) * 2;

    vertexDesc.layouts[L2DBufferIndexOpacity].stride = sizeof(float);
    vertexDesc.layouts[L2DBufferIndexOpacity].stepFunction = MTLVertexStepFunctionConstant;
    vertexDesc.layouts[L2DBufferIndexOpacity].stepRate = 0;

    pipelineDesc.vertexDescriptor = vertexDesc;

    // Color attachments.
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;

    // Blending.
    pipelineDesc.colorAttachments[0].blendingEnabled = true;

    pipelineDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    pipelineDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    self.pipelineStateBlendingNormal = [device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];

    // Additive Blending.
    pipelineDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;

    pipelineDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;

    self.pipelineStateBlendingAdditive = [device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];

    // Multiplicative Blending.
    pipelineDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorDestinationColor;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    pipelineDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorZero;
    pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;

    self.pipelineStateBlendingMultiplicative = [device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];

    // Masking.
    pipelineDesc.vertexFunction = [library newFunctionWithName:@"basic_vertex"];
    pipelineDesc.fragmentFunction = [library newFunctionWithName:@"mask_fragment"];

    pipelineDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    pipelineDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;

    self.pipelineStateMasking = [device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
    
    
    //上传纹理的RenderPipeline
    MTLRenderPipelineDescriptor *pipelineUploadTextureDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineUploadTextureDesc.sampleCount = 1;
    pipelineUploadTextureDesc.label = @"Upload Texture 2 Outside RenderPassDescriptor Render Pipeline";
    pipelineUploadTextureDesc.vertexFunction = [library newFunctionWithName:@"textureVertexShader"];
    pipelineUploadTextureDesc.fragmentFunction = [library newFunctionWithName:@"textureFragmentShader"];
    pipelineUploadTextureDesc.colorAttachments[0].pixelFormat = self.currentPixelFormat;
    if (@available(iOS 11.0, *)) {
        pipelineUploadTextureDesc.vertexBuffers[DYVertexInputIndexVertices].mutability = MTLMutabilityImmutable;
    }
    id <MTLRenderPipelineState> pipelineStateUploadTexture =
    [device newRenderPipelineStateWithDescriptor:pipelineUploadTextureDesc
                                           error:&error];
    if (pipelineStateUploadTexture == nil || error) {
        NSLog(@"Failed to create pipeline state to render to screen: %@", error);
        return;
    }
    self.pipelineStateUploadTexture = pipelineStateUploadTexture;
}

- (void)configTexturePixelMapperIfNeed{
    CGSize drawableSize = self.drawableSize;
    if (CGSizeEqualToSize(drawableSize, CGSizeZero)) {
        return;
    }
    if (_renderToTextureRenderPassDescriptor == nil) {
        _renderToTextureRenderPassDescriptor = [MTLRenderPassDescriptor new];
        _renderToTextureRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _renderToTextureRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        _renderToTextureRenderPassDescriptor.colorAttachments[0].clearColor = self.clearColor;
    }
    if (_clearMaskRenderPassDescriptor == nil) {
        _clearMaskRenderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        _clearMaskRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        _clearMaskRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        //渲染mask的renderpass的clearColor必须设置为透明色，否则在做闭眼动作时，眼皮遮不住眼睛
        _clearMaskRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    }
    
    if (self.texturePixelMapper == nil ||
        CGSizeEqualToSize(self.texturePixelMapper.currentTextureSize, drawableSize) == NO) {
        self.texturePixelMapper = [[DYMTLTexturePixelMapper alloc] initWithMetalDevice:self.currentDevice
                                                                      metalPixelFormat:self.currentPixelFormat
                                                                                  size:drawableSize];
    }
}

- (void)configDrawableMaskTextureIfNeed{
    CGSize size = self.drawableSize;
    if (CGSizeEqualToSize(size, CGSizeZero)) {
        return;
    }
    id <MTLDevice> device = self.currentDevice;
    for (L2DMetalDrawable *drawable in self.drawables) {
        @autoreleasepool {
            if (drawable.maskCount > 0) {
                MTLTextureDescriptor *maskTextureDesc = [[MTLTextureDescriptor alloc] init];
                maskTextureDesc.pixelFormat = self.currentPixelFormat;
                maskTextureDesc.storageMode = MTLStorageModePrivate;
                maskTextureDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
                maskTextureDesc.width = (int)size.width;
                maskTextureDesc.height = (int)size.height;
                drawable.maskTexture = [device newTextureWithDescriptor:maskTextureDesc];
            }
        }
    }
}

#pragma mark - Public
- (void)loadLive2DModel:(L2DUserModel *)model{
    _live2DModel = model;
    id <MTLDevice> device = self.currentDevice;
    if (device && model) {
        [self createBuffersWithView:device];
        [self createTexturesWithView:device];
    }
}

- (void)update:(NSTimeInterval)time {
    [self.live2DModel updateWithDeltaTime:time];
    [self.live2DModel update];
    [self updateDrawables];
}

- (void)renderWithinViewPort:(MTLViewport)viewPort
               commandBuffer:(id<MTLCommandBuffer>)commandBuffer
              passDescriptor:(MTLRenderPassDescriptor *)passDescriptor{
    [self renderMasksWithViewPort:viewPort commandBuffer:commandBuffer];
    [self renderDrawablesWithViewPort:viewPort
                        commandBuffer:commandBuffer
                       passDescriptor:passDescriptor];
}

#pragma mark - Render
- (void)updateDrawables {
    L2DUserModel *model = self.live2DModel;
    if (!model) {
        return;
    }
    BOOL needSorting = false;
    for (L2DMetalDrawable *drawable in self.drawables) {
        @autoreleasepool {
            int index = drawable.drawableIndex;
            if ([model isOpacityDidChangedForDrawable:index]) {
                drawable.opacity = [model opacityForDrawable:index];
                if (drawable.opacityBuffer.contents) {
                    float opacity = drawable.opacity;
                    float *list = (float *)&opacity;
                    memcpy(drawable.opacityBuffer.contents, list, sizeof(float));
                }
            }

            drawable.visibility = [model visibilityForDrawable:index];

            if ([model isRenderOrderDidChangedForDrawable:index]) {
                needSorting = true;
            }

            if ([model isVertexPositionDidChangedForDrawable:index]) {
                RawFloatArray *vertexPositions = [model vertexPositionsForDrawable:index];
                if (vertexPositions) {
                    if (drawable.vertexPositionBuffer.contents) {
                        memcpy(drawable.vertexPositionBuffer.contents, vertexPositions.floats, 2 * drawable.vertexCount * sizeof(float));
                    }
                }
            }
        }
    }
    if (needSorting) {
        NSArray<NSNumber *> *renderOrders = model.renderOrders.intArray;
        self.drawableSorted = [self.drawables sortedArrayUsingComparator:^NSComparisonResult(L2DMetalDrawable *obj1, L2DMetalDrawable *obj2) {
            NSComparisonResult result = NSOrderedAscending;
            int obj1Value = renderOrders[obj1.drawableIndex].intValue;
            int obj2Value = renderOrders[obj2.drawableIndex].intValue;
            if (obj1Value > obj2Value) {
                result = NSOrderedDescending;
            } else if (obj1Value == obj2Value) {
                result = NSOrderedSame;
            }
            return result;
        }];
    }
}

- (void)renderMasksWithViewPort:(MTLViewport)viewPort commandBuffer:(id<MTLCommandBuffer>)commandBuffer {
    MTLRenderPassDescriptor *passDesc = self.clearMaskRenderPassDescriptor;
    for (L2DMetalDrawable *drawable in self.drawables) {
        @autoreleasepool {
            if (drawable.maskCount > 0 && drawable.maskTexture) {
                passDesc.colorAttachments[0].texture = drawable.maskTexture;
                id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDesc];
                if (!encoder) {
                    return;
                }
                [encoder setRenderPipelineState:self.pipelineStateBlendingNormal];
                [encoder setViewport:viewPort];

                for (NSNumber *index in drawable.masks) {
                    L2DMetalDrawable *mask = self.drawables[index.intValue];
                    // Bind vertex buffers.
                    [encoder setVertexBuffer:self.transformBuffer
                                      offset:0
                                     atIndex:L2DBufferIndexTransform];
                    [encoder setVertexBuffer:mask.vertexPositionBuffer
                                      offset:0
                                     atIndex:L2DBufferIndexPosition];
                    [encoder setVertexBuffer:mask.vertexTextureCoordinateBuffer
                                      offset:0
                                     atIndex:L2DBufferIndexUV];
                    [encoder setVertexBuffer:mask.opacityBuffer
                                      offset:0
                                     atIndex:L2DBufferIndexOpacity];

                    // Bind uniform texture.
                    if (self.textures.count > drawable.textureIndex) {
                        [encoder setFragmentTexture:self.textures[mask.textureIndex]
                                            atIndex:L2DTextureIndexUniform];
                    }
                    if (mask.vertexIndexBuffer) {
                        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                            indexCount:mask.indexCount
                                             indexType:MTLIndexTypeUInt16
                                           indexBuffer:mask.vertexIndexBuffer
                                     indexBufferOffset:0];
                    }
                }
                [encoder endEncoding];
            }
        }
    }
}

- (void)renderDrawablesWithViewPort:(MTLViewport)viewPort
                      commandBuffer:(id<MTLCommandBuffer>)commandBuffer
                     passDescriptor:(MTLRenderPassDescriptor *)passDescriptor {

    {//渲染到纹理
        id<MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:self.renderToTextureRenderPassDescriptor];
        if (!encoder) {
            return;
        }
        [encoder setViewport:viewPort];
        [encoder setVertexBuffer:self.transformBuffer
                          offset:0
                         atIndex:L2DBufferIndexTransform];
        for (L2DMetalDrawable *drawable in self.drawableSorted) {
            @autoreleasepool {
                // Bind vertex buffer.
                [encoder setVertexBuffer:drawable.vertexPositionBuffer
                                  offset:0
                                 atIndex:L2DBufferIndexPosition];
                [encoder setVertexBuffer:drawable.vertexTextureCoordinateBuffer
                                  offset:0
                                 atIndex:L2DBufferIndexUV];
                [encoder setVertexBuffer:drawable.opacityBuffer
                                  offset:0
                                 atIndex:L2DBufferIndexOpacity];
                
                if (drawable.cullingMode) {
                    [encoder setCullMode:MTLCullModeBack];
                } else {
                    [encoder setCullMode:MTLCullModeNone];
                }
                
                if (drawable.maskCount > 0) {
                    // Bind mask.
                    [encoder setRenderPipelineState:self.pipelineStateMasking];
                    [encoder setFragmentTexture:drawable.maskTexture atIndex:L2DTextureIndexMask];
                } else {
                    switch (drawable.blendMode) {
                        case L2DBlendModeAdditive:
                            [encoder setRenderPipelineState:self.pipelineStateBlendingAdditive];
                            break;
                        case L2DBlendModeMultiplicative:
                            [encoder setRenderPipelineState:self.pipelineStateBlendingMultiplicative];
                            break;
                        case L2DBlendModeNormal:
                            [encoder setRenderPipelineState:self.pipelineStateBlendingNormal];
                            break;
                        default:
                            [encoder setRenderPipelineState:self.pipelineStateBlendingNormal];
                            break;
                    }
                }
                
                if (drawable.visibility) {
                    // Bind uniform texture.
                    if (self.textures.count > drawable.textureIndex) {
                        [encoder setFragmentTexture:self.textures[drawable.textureIndex] atIndex:L2DTextureIndexUniform];
                    }
                    if (drawable.vertexIndexBuffer) {
                        [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                            indexCount:drawable.indexCount
                                             indexType:MTLIndexTypeUInt16
                                           indexBuffer:drawable.vertexIndexBuffer
                                     indexBufferOffset:0];
                    }
                }
            }
        }
        [encoder endEncoding];
    }
    
    {//将纹理内容渲染到passDescriptor.colorAttachments[0].texture上
        static const DYTextureVertex quadVertices[] = {
            // Positions,   Texture coordinates
            {{1, -1},       {1.0, 1.0}},
            {{-1, -1},      {0.0, 1.0}},
            {{-1, 1},       {0.0, 0.0}},

            {{1, -1},       {1.0, 1.0}},
            {{-1, 1},       {0.0, 0.0}},
            {{1, 1},        {1.0, 0.0}},
        };
        
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
        if (renderEncoder == nil) {
            NSLog(@"create render for metallay failed");
            return;
        }
        [renderEncoder setRenderPipelineState:self.pipelineStateUploadTexture];
        [renderEncoder setVertexBytes:&quadVertices length:sizeof(quadVertices) atIndex:DYVertexInputIndexVertices];

        // menthuguan add 这里先注释掉窗口变换相关的代码
        //        [renderEncoder setVertexBytes:&_aspectRatio
        //                               length:sizeof(_aspectRatio)
        //                              atIndex:AAPLVertexInputIndexAspectRatio];

        // Set the offscreen texture as the source texture.
        [renderEncoder setFragmentTexture:self.texturePixelMapper.renderTargetTexture atIndex:DYTextureInputIndexColor];
        // Draw quad with rendered texture.
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [renderEncoder endEncoding];
    }
}

#pragma mark - setter
- (void)setScale:(CGFloat)scale {
    _scale = scale;

    simd_float4x4 translationMatrix = {
        simd_make_float4(self.scale, 0.0, 0.0, self.origin.x),
        simd_make_float4(0.0, self.scale, 0.0, self.origin.y),
        simd_make_float4(0.0, 0.0, 1.0, 0.0),
        simd_make_float4(self.origin.x, self.origin.y, 0.0, 1.0)};
    self.transform = translationMatrix;
}

- (void)setOrigin:(CGPoint)origin {
    _origin = origin;

    simd_float4x4 translationMatrix = simd_matrix_from_rows(
        simd_make_float4(self.scale, 0.0, 0.0, self.origin.x),
        simd_make_float4(0.0, self.scale, 0.0, self.origin.y),
        simd_make_float4(0.0, 0.0, 1.0, 0.0),
        simd_make_float4(self.origin.x, self.origin.y, 0.0, 1.0));
    self.transform = translationMatrix;
}

- (void)setTransform:(matrix_float4x4)transform {
    _transform = transform;

    id<MTLBuffer> buffer = self.transformBuffer;
    if (!buffer) {
        return;
    }
    memcpy(buffer.contents, &transform, sizeof(matrix_float4x4));
    self.transformBuffer = buffer;
}

- (void)setDrawableSize:(CGSize)drawableSize{
    if (CGSizeEqualToSize(self.drawableSize, drawableSize) ||
        CGSizeEqualToSize(drawableSize, CGSizeZero)) {
        return;
    }
    _drawableSize = drawableSize;
    [self configTexturePixelMapperIfNeed];
    [self configDrawableMaskTextureIfNeed];
}

- (void)setTexturePixelMapper:(DYMTLTexturePixelMapper *)texturePixelMapper{
    _texturePixelMapper = texturePixelMapper;
    _renderToTextureRenderPassDescriptor.colorAttachments[0].texture = texturePixelMapper.renderTargetTexture;
}

@end
