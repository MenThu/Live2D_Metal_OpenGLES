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
#import "DYLive2DModel.h"

@interface DYMetalController ()

@property (nonatomic, weak) DYMetalView *dyMetalView;
@property (nonatomic, strong) DYLive2DModel *model;


@end

@implementation DYMetalController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Metal For Live2D Render";
    self.view.backgroundColor = UIColor.blackColor;
    
//    @"Shanbao";
//    @"nainiu";
//    @"Rice";
//    @"Mark";
//    @"Hiyori"
    
    self.model = [[DYLive2DModel alloc] initWithBundleName:@"Live2DResource" jsonFileName:@"Hiyori"];
    
    DYMetalView *dyMetalView = [[DYMetalView alloc] initWithFrame:CGRectZero];
    dyMetalView.backgroundColor = UIColor.orangeColor;
    dyMetalView.renderFPS = 60.f;
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
