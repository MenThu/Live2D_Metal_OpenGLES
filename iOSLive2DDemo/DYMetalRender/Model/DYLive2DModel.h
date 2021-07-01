//
//  DYLive2DModel.h
//  iOSLive2DDemo
//
//  Created by menthu on 2021/7/1.
//

#import <Foundation/Foundation.h>
#import "L2DRawArray.h"
#import "L2DModelDefine.h"

NS_ASSUME_NONNULL_BEGIN

@interface DYLive2DModel : NSObject

- (instancetype)initWithBundleName:(NSString *)bundleName jsonFileName:(NSString *)modelJsonName;

- (int)drawableCount;
- (RawIntArray *)renderOrders;
- (bool)isRenderOrderDidChangedForDrawable:(int)index;
- (RawFloatArray *)vertexPositionsForDrawable:(int)index;
- (RawFloatArray *)vertexTextureCoordinateForDrawable:(int)index;
- (RawUShortArray *)vertexIndicesForDrawable:(int)index;
- (int)textureIndexForDrawable:(int)index;
- (RawIntArray *)masksForDrawable:(int)index;
- (L2DBlendMode)blendingModeForDrawable:(int)index;
- (bool)cullingModeForDrawable:(int)index;
- (float)opacityForDrawable:(int)index;
- (bool)visibilityForDrawable:(int)index;
- (NSArray<NSData *> *)textureDataArray;
- (void)update;
- (void)updateWithDeltaTime:(NSTimeInterval)dt;
- (bool)isOpacityDidChangedForDrawable:(int)index;
- (bool)isVertexPositionDidChangedForDrawable:(int)index;

@end

NS_ASSUME_NONNULL_END
