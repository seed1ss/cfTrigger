#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>

@interface ESPView : UIView
@property (nonatomic, strong) CADisplayLink *link;
@end

@implementation ESPView
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
        [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}
- (void)tick {
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextClearRect(ctx, rect);
    
    // Рисуем простой тестовый квадрат в центре
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
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = [UIColor clearColor];
        window.rootViewController = [UIViewController new];
        
        ESPView *esp = [[ESPView alloc] initWithFrame:window.bounds];
        [window.rootViewController.view addSubview:esp];
        [window makeKeyAndVisible];
    });
}
