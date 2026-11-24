
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>

static BOOL g_enabled = YES;
static float g_delay = 0.050;
static BOOL g_shouldFire = NO;
static CGFloat g_fireXPercent = 0.85;
static CGFloat g_fireYPercent = 0.85;

BOOL checkCenterPixel(UIImage *img) {
    if (!img) return NO;
    CGImageRef cg = img.CGImage;
    if (!cg) return NO;
    size_t w = CGImageGetWidth(cg);
    size_t h = CGImageGetHeight(cg);
    size_t cx = w / 2;
    size_t cy = h / 2;
    CGRect rect = CGRectMake(cx - 5, cy - 5, 10, 10);
    CGImageRef crop = CGImageCreateWithImageInRect(cg, rect);
    if (!crop) return NO;
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(crop));
    if (!data) { CGImageRelease(crop); return NO; }
    const UInt8 *buf = CFDataGetBytePtr(data);
    BOOL found = NO;
    for (int i = 0; i < 10 * 10 * 4; i += 4) {
        UInt8 r = buf[i];
        UInt8 g = buf[i+1];
        UInt8 b = buf[i+2];
        if (r > 180 && g < 100 && b < 100) { found = YES; break; }
    }
    CFRelease(data);
    CGImageRelease(crop);
    return found;
}

void simulateFireTouch() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        CGPoint p = CGPointMake(window.bounds.size.width * g_fireXPercent, window.bounds.size.height * g_fireYPercent);
        UITouch *touch = [[UITouch alloc] init];
        [touch setValue:[NSNumber numberWithInt:UITouchPhaseBegan] forKey:@"phase"];
        [touch setValue:window forKey:@"window"];
        [touch setValue:[NSNumber numberWithFloat:p.x] forKey:@"locationInWindowX"];
        [touch setValue:[NSNumber numberWithFloat:p.y] forKey:@"locationInWindowY"];
        UIEvent *event = [[UIEvent alloc] init];
        [event setValue:[NSSet setWithObject:touch] forKey:@"allTouches"];
        [[UIApplication sharedApplication] sendEvent:event];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [touch setValue:[NSNumber numberWithInt:UITouchPhaseEnded] forKey:@"phase"];
            [[UIApplication sharedApplication] sendEvent:event];
        });
    });
}

void triggerLoop() {
    while (YES) {
        if (!g_enabled) { usleep(100000); continue; }
        @autoreleasepool {
            UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 1.0);
            [[UIApplication sharedApplication].keyWindow drawViewHierarchyInRect:[UIScreen mainScreen].bounds afterScreenUpdates:NO];
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            if (checkCenterPixel(img)) {
                if (!g_shouldFire) {
                    g_shouldFire = YES;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(g_delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (g_shouldFire) simulateFireTouch();
                    });
                }
            } else { g_shouldFire = NO; }
        }
        usleep(10000);
    }
}

%ctor {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        triggerLoop();
    });
}
