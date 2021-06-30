//
//  MetalLive2DViewController.m
//  iOSLive2DDemo
//
//  Created by VanJay on 2021/3/13.
//

#import "MetalLive2DViewController.h"
#import "KGMetalLive2DView.h"

@interface MetalLive2DViewController () <MetalRenderDelegate>
/// 渲染线程
@property (nonatomic, strong) dispatch_queue_t renderQueue;
/// 展示 live2d 的 View
@property (nonatomic, strong) KGMetalLive2DView *live2DView;
/// 是否已经加载资源
@property (nonatomic, assign) BOOL hasLoadResource;
@end

@implementation MetalLive2DViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        // Metal 可异步渲染
        _renderQueue = dispatch_queue_create("com.virtualsingler.render.home", DISPATCH_QUEUE_CONCURRENT);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Live2D Metal Render";
    self.view.backgroundColor = UIColor.orangeColor;

    [self.view addSubview:self.live2DView];
    self.live2DView.backgroundColor = UIColor.clearColor;
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

    self.live2DView.frame = self.view.bounds;
    if (!self.hasLoadResource) {
        
        
        NSString *dirName = @"Live2DResources/Shanbao/";
        NSString *mocJsonName = @"Shanbao.model3.json";
        
//        NSString *dirName = @"Live2DResources/test1.20/";
//        NSString *mocJsonName = @"test1.20.model3.json";
        
//        NSString *dirName = @"Live2DResources/Haru/";
//        NSString *mocJsonName = @"Haru.model3.json";
        
        [self.live2DView loadLive2DModelWithDir:dirName mocJsonName:mocJsonName];
        self.hasLoadResource = YES;
    }
}

#pragma mark - MetalRenderDelegate
- (void)rendererUpdateWithRender:(L2DMetalRender *)renderer duration:(NSTimeInterval)duration {
}

#pragma mark - lazy load
- (KGMetalLive2DView *)live2DView {
    if (!_live2DView) {
        _live2DView = [[KGMetalLive2DView alloc] init];
        _live2DView.delegate = self;
    }
    return _live2DView;
}

@end
