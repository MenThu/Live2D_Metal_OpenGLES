//
//  DYMetalController.m
//  CustomRenderPassSetup-iOS
//
//  Created by menthu on 2021/6/24.
//  Copyright © 2021 Apple. All rights reserved.
//

#import "DYMetalController.h"
#import "DYMetalView.h"
#import "L2DUserModel.h"

@interface DYMetalController ()

@property (nonatomic, weak) DYMetalView *dyMetalView;
@property (nonatomic, strong) L2DUserModel *model;

@end

@implementation DYMetalController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    
    NSString *dirName = nil;
    NSString *mocJsonName = nil;
    
    dirName = @"Live2DResources/Shanbao/";
    mocJsonName = @"Shanbao.model3.json";
    
//        dirName = @"Live2DResources/test1.20/";
//        mocJsonName = @"test1.20.model3.json";
    
        dirName = @"Live2DResources/Rice/";
        mocJsonName = @"Rice.model3.json";

    
//        dirName = @"Live2DResources/Mark/";
//        mocJsonName = @"Mark.model3.json";
    
    self.model = [[L2DUserModel alloc] initWithJsonDir:dirName mocJsonName:mocJsonName];
    
    DYMetalView *dyMetalView = [[DYMetalView alloc] initWithFrame:CGRectZero];
    dyMetalView.backgroundColor = UIColor.orangeColor;
    dyMetalView.renderFPS = 40.f;
    [self.view addSubview:(_dyMetalView = dyMetalView)];
    [dyMetalView loadLive2DModel:self.model];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
}

- (void)dealloc{
    [self.dyMetalView releaseResource];
    [self.dyMetalView removeFromSuperview];
    self.dyMetalView = nil;
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    self.dyMetalView.frame = self.view.bounds;
    [self.dyMetalView startRender];
}

- (void)applicationDidEnterBackground {
    [self.dyMetalView stopRender];
}

- (void)applicationWillEnterForeground{
    [self.dyMetalView startRender];
}


@end
