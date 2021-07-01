//
//  DYMetalView.h
//  iOSLive2DDemo
//
//  Created by menthu on 2021/6/29.
//

#import <UIKit/UIKit.h>
#import "DYMetalRenderProtocol.h"

@class DYLive2DModel;

NS_ASSUME_NONNULL_BEGIN

@interface DYMetalView : UIView <DYMetalRenderProtocol>

/// 默认为30pfs
@property (nonatomic, assign) NSUInteger renderFPS;

/// 加载模型
/// @param model live2D模型数据
- (void)loadLive2DModel:(DYLive2DModel *)model;

/// 开始渲染
- (void)startRender;

/// 停止渲染
- (void)stopRender;

/// 释放资源
- (void)releaseResource;

@end

NS_ASSUME_NONNULL_END
