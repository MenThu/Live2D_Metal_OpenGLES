//
//  DYMTLTexturePixelMapper.h
//  CustomRenderPassSetup-iOS
//
//  Created by menthu on 2021/6/24.
//  Copyright © 2021 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DYMTLTexturePixelMapper : NSObject

- (nonnull instancetype)initWithMetalDevice:(nonnull id<MTLDevice>)metalevice
                           metalPixelFormat:(MTLPixelFormat)mtlPixelFormat
                                       size:(CGSize)size;

@property (nonatomic, assign, readonly) CVPixelBufferRef pixelBuffer;
@property (nonatomic, strong, readonly) id<MTLTexture> renderTargetTexture;
@property (nonatomic, assign, readonly) CGSize currentTextureSize;

@end

NS_ASSUME_NONNULL_END
