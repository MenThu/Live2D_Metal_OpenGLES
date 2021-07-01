//
//  NSBundle+Live2DModel.h
//  iOSLive2DDemo
//
//  Created by menthu on 2021/7/1.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSBundle (Live2DModel)

/// 加载数据模型
+ (NSBundle *)modelResourceForBundleName:(NSString *)bundleName
                               modelName:(NSString *)modelName;

- (NSString *)model3FilePath;
- (NSString *)personalFilePath;

@end

NS_ASSUME_NONNULL_END
