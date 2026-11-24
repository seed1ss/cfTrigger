#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Координаты кнопки стрельбы (лево-верх)
static CGFloat g_fireXPercent = 0.15;
static CGFloat g_fireYPercent = 0.15;
static UIWindow *g_overlayWindow = nil;

@interface ESPView : UIView
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation ESPView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    }
    return self;
}
- (void)tick {
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return;
    CGContextClearRect(ctx, rect);
    
    // Рисуем тестовый красный квадрат по центру экрана
    CGContextSetStrokeColorWithColor(ctx, [UIColor redColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextStrokeRect(ctx, CGRectMake(rect.size.width/2 - 50, rect.size.height/2 - 50, 100, 100));
    
    // Рисуем текст
    UIFont *font = [UIFont boldSystemFontOfSize:24];
    NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor greenColor]};
    [@"ESP READY" drawAtPoint:CGPointMake(rect.size.width/2 - 60, rect.size.height/2 + 60) withAttributes:attrs];
}
@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        g_overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        g_overlayWindow.backgroundColor = [UIColor clearColor];
        g_overlayWindow.userInteractionEnabled = NO;
        
        UIViewController *vc = [UIViewController new];
        vc.view.userInteractionEnabled = NO;
        g_overlayWindow.rootViewController = vc;
        
        ESPView *esp = [[ESPView alloc] initWithFrame:g_overlayWindow.bounds];
        [vc.view addSubview:esp];
        
        g_overlayWindow.hidden = NO;
    });
}
