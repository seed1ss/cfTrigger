#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static CGFloat fx = 0.15, fy = 0.15;

BOOL checkCenterPixel(UIImage *img) {
    if (!img) return NO;
    CGImageRef cg = img.CGImage;
    if (!cg) return NO;
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    CGRect rect = CGRectMake(w/2 - 5, h/2 - 5, 10, 10);
    CGImageRef crop = CGImageCreateWithImageInRect(cg, rect);
    if (!crop) return NO;
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(crop));
    if (!data) { CGImageRelease(crop); return NO; }
    const UInt8 *buf = CFDataGetBytePtr(data);
    BOOL found = NO;
    for (int i = 0; i < 400; i += 4) {
        if (buf[i] > 180 && buf[i+1] < 100 && buf[i+2] < 100) { found = YES; break; }
    }
    CFRelease(data); CGImageRelease(crop);
    return found;
}

void triggerLoop() {
    while (YES) {
        @autoreleasepool {
            UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 1.0);
            [[UIApplication sharedApplication].keyWindow drawViewHierarchyInRect:[UIScreen mainScreen].bounds afterScreenUpdates:NO];
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            if (checkCenterPixel(img)) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIWindow *w = [UIApplication sharedApplication].keyWindow;
                    CGPoint p = CGPointMake(w.bounds.size.width * fx, w.bounds.size.height * fy);
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
                usleep(50000);
            }
        }
        usleep(10000);
    }
}

%ctor { dispatch_async(dispatch_get_global_queue(0, 0), ^{ triggerLoop(); }); }
