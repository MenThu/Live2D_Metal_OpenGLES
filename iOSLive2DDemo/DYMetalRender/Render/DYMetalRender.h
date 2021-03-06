//
//  DYMetalRender.h
//  iOSLive2DDemo
//
//  Created by menthu on 2021/6/29.
//

#import <Foundation/Foundation.h>
#import "DYMetalRenderProtocol.h"
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@class DYMTLTexturePixelMapper;
@class DYLive2DModel;

@interface DYMetalRender : NSObject <DYMetalRenderProtocol>

/// 通过CVMetal框架，制作一对有内存映射的texture与pixel，方便对metal渲染时，能够同步拿到更新后的Pixel的数据
@property (nonatomic, strong, readonly) DYMTLTexturePixelMapper *texturePixelMapper;

/// 绘画区域的大小
@property (nonatomic, assign) CGSize drawableSize;


@property (nonatomic, assign) CGPoint origin;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, assign) matrix_float4x4 transform;

/// 清空背景所用的颜色
@property (nonatomic, assign) MTLClearColor clearColor;

/// 初始化DYMetalRender
/// @param device  代表GPU硬件的对象，一般由MTLCreateSystemDefaultDevice生成
/// @param pixelFormat 最终呈现内容的物体的像素格式
- (instancetype)initWithDevice:(id<MTLDevice>)device
                   pixelFormat:(MTLPixelFormat)pixelFormat;


/// 加载Live2D模型
/// @param model 封装了Live2D模型的OC对象
- (void)loadLive2DModel:(DYLive2DModel *)model;

/// 在制定窗口下渲染live2D模型，内部会渲染到texturePixelMapper的metal纹理上，如果有编码或者其它需要，可以直接访问texturePixelMapper.pixelbuffer获取到画面CPU的数据
/// @param viewPort 视口，与承载内容的CAMetalLayer一样大小
/// @param commandBuffer 渲染命令
/// @param passDescriptor 渲染结果的目的地
- (void)renderWithinViewPort:(MTLViewport)viewPort
               commandBuffer:(id<MTLCommandBuffer>)commandBuffer
              passDescriptor:(MTLRenderPassDescriptor *)passDescriptor;

/// 刷新
/// @param time 间隔时间
- (void)update:(NSTimeInterval)time;

@end

NS_ASSUME_NONNULL_END
