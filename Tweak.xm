// Tweak.xm — CounterFlame ESP (Overlay)
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>

// --- НАСТРОЙКИ ---
static BOOL g_espEnabled = YES;
static uintptr_t g_unityBase = 0;

// --- ПИКСЕЛЬНЫЙ ПОИСК ---
// (Рисует рамки, если видит красный контур)
void drawPixelESP(UIView *view) {
    UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 1.0);
    [[UIApplication sharedApplication].keyWindow drawViewHierarchyInRect:[UIScreen mainScreen].bounds afterScreenUpdates:NO];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (!img) return;
    CGImageRef cg = img.CGImage;
    if (!cg) return;
    
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    // Сканируем сетку экрана на красные пиксели
    for (size_t y = 0; y < h; y += 20) {
        for (size_t x = 0; x < w; x += 20) {
            CGRect rect = CGRectMake(x, y, 20, 20);
            CGImageRef crop = CGImageCreateWithImageInRect(cg, rect);
            if (!crop) continue;
            
            CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(crop));
            if (data) {
                const UInt8 *buf = CFDataGetBytePtr(data);
                for (int i = 0; i < 20 * 20 * 4; i += 4) {
                    if (buf[i] > 180 && buf[i+1] < 100 && buf[i+2] < 100) {
                        // Нашли красный — рисуем рамку через основной поток
                        dispatch_async(dispatch_get_main_queue(), ^{
                            CGContextRef ctx = UIGraphicsGetCurrentContext();
                            if (ctx) {
                                CGContextSetStrokeColorWithColor(ctx, [UIColor redColor].CGColor);
                                CGContextSetLineWidth(ctx, 2.0);
                                CGContextStrokeRect(ctx, rect);
                            }
                        });
                        break;
                    }
                }
                CFRelease(data);
            }
            CGImageRelease(crop);
        }
    }
}

@interface ESPView : UIView
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation ESPView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}
- (void)update {
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    if (!g_espEnabled) return;
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextClearRect(ctx, rect);
    
    // Вызываем пиксельный поиск
    drawPixelESP(self);
}
@end

%ctor {
    // Создаем оверлей
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = [UIColor clearColor];
        window.rootViewController = [UIViewController new];
        
        ESPView *esp = [[ESPView alloc] initWithFrame:window.bounds];
        [window.rootViewController.view addSubview:esp];
        [window makeKeyAndVisible];
    });
}
