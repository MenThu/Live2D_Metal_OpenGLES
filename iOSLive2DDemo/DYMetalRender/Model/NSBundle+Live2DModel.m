//
//  NSBundle+Live2DModel.m
//  iOSLive2DDemo
//
//  Created by menthu on 2021/7/1.
//

#import "NSBundle+Live2DModel.h"

@implementation NSBundle (Live2DModel)

+ (NSBundle *)modelResourceForBundleName:(NSString *)bundleName
                               modelName:(NSString *)modelName{
    NSBundle *resourceBundle = [NSBundle bundleWithURL:[[NSBundle mainBundle] URLForResource:bundleName
                                                                               withExtension:@"bundle"]];
    NSString *dir = [[resourceBundle bundlePath] stringByAppendingPathComponent:modelName];
    return [NSBundle bundleWithPath:dir];
}

- (NSString *)moc3FilePath {
    NSString *assetName = [self.bundlePath lastPathComponent];
    NSString *filePath = [self pathForResource:assetName ofType:@"moc3"];
    return filePath;
}

- (NSString *)model3FilePath {
    NSString *assetName = [self.bundlePath lastPathComponent];
    NSString *filePath = [self pathForResource:assetName ofType:@"model3.json"];
    return filePath;
}

- (NSString *)personalFilePath{
    NSString *assetName = [self.bundlePath lastPathComponent];
    NSString *filePath = [self pathForResource:assetName ofType:@"personality.json"];
    return filePath;
}


@end
