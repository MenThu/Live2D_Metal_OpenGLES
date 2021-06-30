//
//  DYMetalView.m
//  iOSLive2DDemo
//
//  Created by menthu on 2021/6/29.
//

#import "DYMetalView.h"
#import "DYMetalRender.h"
#import "L2DUserModel.h"

static NSInteger DEFAULT_RENDER_FPS = 30;

@interface DYMetalView ()

@property (nonatomic, nonnull, readwrite) CAMetalLayer *metalLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) L2DUserModel *live2DModel;
@property (nonatomic, strong) DYMetalRender *metalRender;

@end

@implementation DYMetalView

#pragma mark - LifeCycle
+ (Class)layerClass{
    return CAMetalLayer.class;
}

- (instancetype)init{
    if (self = [super init]) {
        [self configView];
    }
    return self;
}

- (void)layoutSubviews{
    [super layoutSubviews];
    [self reSizeLayerIfNeed];
}

#pragma mark - Private
- (void)configView{
    CAMetalLayer *metalLayer = (CAMetalLayer *)self.layer;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    self.metalLayer = metalLayer;
    [self createDisplayLink];
}

- (void)createDisplayLink{
    if (self.displayLink == nil) {
        return;
    }
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderLive2DModel)];
    self.displayLink.preferredFramesPerSecond = DEFAULT_RENDER_FPS;
    self.displayLink.paused = YES;
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)createMetalRender:(L2DUserModel *)model{
    if (self.metalRender == nil) {
        DYMetalRender *metalRender = [[DYMetalRender alloc] init];
        self.metalRender = metalRender;
    }
    [self.metalRender loadLive2DModel:model];
}

- (void)reSizeLayerIfNeed{
    CGSize newSize = self.bounds.size;
    CGFloat scaleFactor = self.window.screen.nativeScale;
    newSize.width *= scaleFactor;
    newSize.height *= scaleFactor;
    if (CGSizeEqualToSize(newSize, CGSizeZero) ||
        CGSizeEqualToSize(newSize, _metalLayer.drawableSize)) {
        return;
    }
    NSLog(@"DrawableSize Change=[%@]", NSStringFromCGSize(newSize));
    
    _metalLayer.drawableSize = newSize;
}

- (void)renderLive2DModel{
    
}

#pragma mark - Public
- (void)loadLive2DModel:(L2DUserModel *)model{
    self.live2DModel = model;
}

- (void)startRender{
    if (self.displayLink.paused == YES) {
        self.displayLink.paused = NO;
    }
}

- (void)stopRender{
    if (self.displayLink.paused == NO) {
        self.displayLink.paused = YES;
    }
}

- (void)setRenderFPS:(NSUInteger)renderFPS{
    if (_renderFPS == renderFPS) {
        return;
    }
    _renderFPS = renderFPS;
    self.displayLink.preferredFramesPerSecond = renderFPS;
}

@end
