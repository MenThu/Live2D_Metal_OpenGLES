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

@property (nonatomic, strong) MTLRenderPassDescriptor *renderPassDescriptor;
@property (nonatomic, nonnull, readwrite) CAMetalLayer *metalLayer;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, weak) L2DUserModel *live2DModel;
@property (nonatomic, strong) DYMetalRender *metalRender;
@property (nonatomic, strong) id <MTLDevice> currentDevice;
@property (nonatomic, strong) id <MTLCommandQueue> commandQueue;
@property (nonatomic, assign) MTLViewport viewPort;

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

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
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
    
    self.metalLayer.drawableSize = newSize;
    self.metalRender.drawableSize = newSize;
    [self updateMTKViewPort];
}

- (void)updateMTKViewPort {
    CGSize size = self.metalLayer.drawableSize;
    NSLog(@"metalLayer drawable size=[%@]", NSStringFromCGSize(size));
    MTLViewport viewport = {};
    viewport.znear = 0.0;
    viewport.zfar = 1.0;
    if (size.width > size.height) {
        viewport.originX = 0.0;
        viewport.originY = (size.height - size.width) * 0.5;
        viewport.width = size.width;
        viewport.height = size.width;
    } else {
        viewport.originX = (size.width - size.height) * 0.5;
        viewport.originY = 0.0;
        viewport.width = size.height;
        viewport.height = size.height;
    }
    // 调整显示大小
    self.viewPort = viewport;
}

- (void)renderLive2DModel{
    //驱动模型变化
    NSTimeInterval time = 1.0 / (NSTimeInterval)(self.displayLink.preferredFramesPerSecond);
    [self.metalRender update:time];
    
    id <CAMetalDrawable> currentDrawable = [self.metalLayer nextDrawable];
    if (currentDrawable == nil) {
        NSLog(@"Not Available Drawable, Skip this round");
        return;
    }
    self.renderPassDescriptor.colorAttachments[0].texture = currentDrawable.texture;
    
    id <MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    if (commandBuffer == nil) {
        NSLog(@"Create CommandBuffer Failed, Skip this round");
        return;
    }
    
    [self.metalRender renderWithinViewPort:self.viewPort
                             commandBuffer:commandBuffer
                            passDescriptor:self.renderPassDescriptor];
    
    
    [commandBuffer presentDrawable:currentDrawable];
    [commandBuffer commit];
}

#pragma mark - Public
- (void)loadLive2DModel:(L2DUserModel *)model{
    self.live2DModel = model;
    [self.metalRender loadLive2DModel:model];
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

- (void)releaseResource{
    self.displayLink.paused = YES;
    [self.displayLink invalidate];
    self.metalRender = nil;
}

#pragma mark - Getter
- (CADisplayLink *)displayLink{
    if (_displayLink == nil) {
        CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(renderLive2DModel)];
        displayLink.preferredFramesPerSecond = DEFAULT_RENDER_FPS;
        displayLink.paused = YES;
        [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        _displayLink = displayLink;
    }
    return _displayLink;
}

- (DYMetalRender *)metalRender{
    if (_metalRender == nil) {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            NSLog(@"Create Device Error");
            return nil;
        }
        self.currentDevice = device;
        
        id <MTLCommandQueue> commandQueue = [device newCommandQueue];
        if (!device) {
            NSLog(@"Create commandQueue Error");
            return nil;
        }
        self.commandQueue = commandQueue;
        
        DYMetalRender *metalRender = [[DYMetalRender alloc] initWithDevice:device
                                                               pixelFormat:self.metalLayer.pixelFormat];
        metalRender.clearColor = self.renderPassDescriptor.colorAttachments[0].clearColor;
        _metalRender = metalRender;
    }
    return _metalRender;
}

- (MTLRenderPassDescriptor *)renderPassDescriptor{
    if (_renderPassDescriptor == nil) {
        MTLClearColor clearColor = MTLClearColorMake(1, 1, 1, 1);
        MTLRenderPassDescriptor *renderPassDescriptor = [[MTLRenderPassDescriptor alloc] init];
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPassDescriptor.colorAttachments[0].clearColor = clearColor;
        _renderPassDescriptor = renderPassDescriptor;
    }
    return _renderPassDescriptor;
}

#pragma mark - Setter
- (void)setBackgroundColor:(UIColor *)backgroundColor{
    [super setBackgroundColor:backgroundColor];
    
    CGFloat red = 1, green = 1, blue = 1, alpha = 1;
    
    CGColorRef color = backgroundColor.CGColor;

    CGColorSpaceRef colorSpaceRef = CGColorGetColorSpace(color);
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpaceRef);
    const CGFloat *colorComponents = CGColorGetComponents(color);
    size_t colorComponentCount = CGColorGetNumberOfComponents(color);

    switch (colorSpaceModel) {
        case kCGColorSpaceModelMonochrome:
        {
            assert(colorComponentCount == 2);
            red = colorComponents[0];
            green = red;
            blue = red;
            alpha = colorComponents[1];
        }
            break;

        case kCGColorSpaceModelRGB:
        {
            assert(colorComponentCount == 4);
            red = colorComponents[0];
            green = colorComponents[1];
            blue = colorComponents[2];
            alpha = colorComponents[3];
        }
            break;

        default:
            break;
    }
    MTLClearColor clearColor = MTLClearColorMake(red, green, blue, alpha);
    self.metalRender.clearColor = clearColor;
    self.renderPassDescriptor.colorAttachments[0].clearColor = clearColor;
}

- (void)setRenderFPS:(NSUInteger)renderFPS{
    if (_renderFPS == renderFPS) {
        return;
    }
    _renderFPS = renderFPS;
    self.displayLink.preferredFramesPerSecond = renderFPS;
}

@end
