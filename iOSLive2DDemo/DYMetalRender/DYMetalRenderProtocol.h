//
//  DYMetalRenderProtocol.h
//  iOSLive2DDemo
//
//  Created by menthu on 2021/6/29.
//

#ifndef DYMetalRenderProtocol_h
#define DYMetalRenderProtocol_h

@class L2DUserModel;

@protocol DYMetalRenderProtocol <NSObject>

/// 加载模型
/// @param model live2D模型数据
- (void)loadLive2DModel:(L2DUserModel *)model;

@end

#endif /* DYMetalRenderProtocol_h */
