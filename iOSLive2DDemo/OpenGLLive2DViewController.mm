//
//  OpenGLLive2DViewController.m
//  iOSLive2DDemo
//
//  Created by VanJay on 2021/3/13.
//

#import "OpenGLLive2DViewController.h"
#import "KGOpenGLLive2DView.h"

@interface OpenGLLive2DViewController () <OpenGLRenderDelegate>
/// 展示 live2d 的 View
@property (nonatomic, strong) KGOpenGLLive2DView *live2DView;
/// 是否已经加载资源
@property (nonatomic, assign) BOOL hasLoadResource;
@end

@implementation OpenGLLive2DViewController
- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Live2D OpenGLES Render";
    self.view.backgroundColor = UIColor.yellowColor;

    [self.view addSubview:self.live2DView];
    self.live2DView.backgroundColor = UIColor.redColor;
    self.live2DView.preferredFramesPerSecond = 30;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if (!self.live2DView.paused) {
        self.live2DView.paused = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (self.live2DView.paused) {
        self.live2DView.paused = NO;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (self.live2DView.paused) {
        self.live2DView.paused = NO;
    }
}

- (void)dealloc {

    self.live2DView.delegate = nil;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

//    self.live2DView.frame = CGRectMake(0, 200, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame) * 1 - 300);
    self.live2DView.frame = self.view.bounds;
    
    
    NSString *dirName = nil;
    NSString *mocJsonName = nil;
    
//    dirName = @"Live2DResources/Shanbao/";
//    mocJsonName = @"Shanbao.model3.json";
    
//        dirName = @"Live2DResources/test1.20/";
//        mocJsonName = @"test1.20.model3.json";
    
//        dirName = @"Live2DResources/Rice/";
//        mocJsonName = @"Rice.model3.json";
    
    dirName = @"Live2DResources/nainiu/";
    mocJsonName = @"nainiu.model3.json";

    if (!self.hasLoadResource) {
        
        
        [self.live2DView loadLive2DModelWithDir:dirName mocJsonName:mocJsonName];
        self.hasLoadResource = YES;
    }
}

#pragma mark - OpenGLRenderDelegate
- (void)rendererUpdateWithRender:(L2DOpenGLRender *)renderer duration:(NSTimeInterval)duration {
}

#pragma mark - lazy load
- (KGOpenGLLive2DView *)live2DView {
    if (!_live2DView) {
        _live2DView = [[KGOpenGLLive2DView alloc] init];
        _live2DView.delegate = self;
    }
    return _live2DView;
}
@end
