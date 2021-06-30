//
//  DYMetalView.h
//  iOSLive2DDemo
//
//  Created by menthu on 2021/6/29.
//

#import <UIKit/UIKit.h>
#import "DYMetalRenderProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface DYMetalView : UIView <DYMetalRenderProtocol>

/// 默认为30pfs
@property (nonatomic, assign) NSUInteger renderFPS;

/// 开始渲染
- (void)startRender;

/// 停止渲染
- (void)stopRender;

@end

NS_ASSUME_NONNULL_END
