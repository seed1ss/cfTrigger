#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void simulateFire() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *w = [UIApplication sharedApplication].keyWindow;
        if (!w) return;
        CGPoint p = CGPointMake(w.bounds.size.width * 0.15, w.bounds.size.height * 0.15);
        UITouch *t = [[UITouch alloc] init];
        [t setValue:[NSNumber numberWithInt:UITouchPhaseBegan] forKey:@"phase"];
        [t setValue:w forKey:@"window"];
        [t setValue:[NSNumber numberWithFloat:p.x] forKey:@"locationInWindowX"];
        [t setValue:[NSNumber numberWithFloat:p.y] forKey:@"locationInWindowY"];
        UIEvent *e = [[UIEvent alloc] init];
        [e setValue:[NSSet setWithObject:t] forKey:@"allTouches"];
        [[UIApplication sharedApplication] sendEvent:e];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.02 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [t setValue:[NSNumber numberWithInt:UITouchPhaseEnded] forKey:@"phase"];
            [[UIApplication sharedApplication] sendEvent:e];
        });
    });
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        while (YES) {
            simulateFire();
            [NSThread sleepForTimeInterval:0.05]; // Стреляет каждые 50 мс
        }
    });
}
