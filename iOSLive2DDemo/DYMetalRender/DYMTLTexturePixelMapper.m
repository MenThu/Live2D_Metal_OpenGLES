//
//  DYMTLTexturePixelMapper.m
//  CustomRenderPassSetup-iOS
//
//  Created by menthu on 2021/6/24.
//  Copyright © 2021 Apple. All rights reserved.
//

#import "DYMTLTexturePixelMapper.h"

typedef struct {
    MTLPixelFormat      mtlFormat;
    int                 cvPixelFormat;
} MetalTexturePiexlFormatMapper;

// Table of equivalent formats across CoreVideo, Metal, and OpenGL
static const MetalTexturePiexlFormatMapper AAPLInteropFormatTable[] =
{
    //Metal Pixel Format            Core Video Pixel Format,
    {MTLPixelFormatBGRA8Unorm,      kCVPixelFormatType_32BGRA},
    {MTLPixelFormatBGRA8Unorm_sRGB, kCVPixelFormatType_32BGRA},
    {MTLPixelFormatRGBA8Unorm,      kCVPixelFormatType_32RGBA},
};

static const NSUInteger AAPLNumInteropFormats = sizeof(AAPLInteropFormatTable) / sizeof(MetalTexturePiexlFormatMapper);

const MetalTexturePiexlFormatMapper *const textureFormatInfoFromMetalPixelFormat(MTLPixelFormat pixelFormat)
{
    for(int i = 0; i < AAPLNumInteropFormats; i++) {
        if(pixelFormat == AAPLInteropFormatTable[i].mtlFormat) {
            return &AAPLInteropFormatTable[i];
        }
    }
    return NULL;
}


@interface DYMTLTexturePixelMapper ()
{
    CVMetalTextureCacheRef _metalTextureCache;
    CVMetalTextureRef _metalTexture;
}

@property (nonatomic, assign, readwrite) CVPixelBufferRef pixelBuffer;
@property (nonatomic, strong, readwrite) id<MTLTexture> renderTargetTexture;
@property (nonatomic, assign, readwrite) CGSize currentTextureSize;

@end

@implementation DYMTLTexturePixelMapper

- (nonnull instancetype)initWithMetalDevice:(nonnull id <MTLDevice>)metalevice
                           metalPixelFormat:(MTLPixelFormat)mtlPixelFormat
                                       size:(CGSize)textureSize{
    if (self = [super init]) {
        NSLog(@"Create texture-pixelbuffer-mapper=[%llu][%@]",
              (unsigned long long)mtlPixelFormat,
              NSStringFromCGSize(textureSize));
        self.currentTextureSize = textureSize;
        const MetalTexturePiexlFormatMapper *format = textureFormatInfoFromMetalPixelFormat(mtlPixelFormat);
        NSDictionary* cvBufferProperties = @{
            (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
        };
        CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault,
                                           textureSize.width,
                                           textureSize.height,
                                           format->cvPixelFormat,
                                (__bridge CFDictionaryRef)cvBufferProperties,
                                &_pixelBuffer);
        if (ret != kCVReturnSuccess) {
            NSLog(@"Create Pixel Buffer Failed=[%d]", ret);
            return nil;
        }
        
        // 1. Create a Metal Core Video texture cache from the pixel buffer.
        ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalevice, nil, &_metalTextureCache);
        if (ret != kCVReturnSuccess) {
            NSLog(@"Failed to create Metal texture cache=[%d]", ret);
            return nil;
        }
        
        // 2. Create a CoreVideo pixel buffer backed Metal texture image from the texture cache.
        ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                        _metalTextureCache,
                                                        _pixelBuffer,
                                                        nil,
                                                        format->mtlFormat,
                                                        textureSize.width, textureSize.height,
                                                        0,
                                                        &_metalTexture);
        if (ret != kCVReturnSuccess) {
            NSLog(@"Failed to create CoreVideo Metal texture from image=[%d]", ret);
            return nil;
        }
                
        _renderTargetTexture = CVMetalTextureGetTexture(_metalTexture);
        if (_renderTargetTexture == nil) {
            NSLog(@"Failed to get metal renderTextureTarget");
            return nil;
        }
    }
    return self;
}

- (void)dealloc{
    NSLog(@"[%@:%p] dealloc", NSStringFromClass(self.class), self);
    CVPixelBufferRelease(_pixelBuffer);
    if (_metalTextureCache != NULL) {
        CFRelease(_metalTextureCache);
    }
    CVBufferRelease(_metalTexture);
}

@end
