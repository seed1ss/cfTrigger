#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>

// --- ОФСЕТЫ ИЗ ТВОЕГО ДАМПА ---
#define OFFSET_GET_PLAYER 0x90
#define OFFSET_HEALTH 0x18
// RVA методов (переведем в абсолютные адреса при загрузке)
#define RVA_PLAYER_UPDATE 0x28fccd4
#define RVA_TRY_GET_POS 0x28f5da0

// Координаты кнопки выстрела (лево-верх)
static CGFloat g_fireXPercent = 0.15;
static CGFloat g_fireYPercent = 0.15;

// Базовый адрес UnityFramework
static uintptr_t g_unityBase = 0;

// Функция для чтения памяти
template<typename T> T readMem(uintptr_t addr) {
    T val = 0;
    if (addr) vm_read_overwrite(mach_task_self(), addr, sizeof(T), (vm_address_t)&val, nullptr);
    return val;
}

// Получить позицию игрока (через Transform)
// В Unity Transform лежит по фиксированному офсету (обычно 0x38 для il2cpp)
bool getPlayerPosition(uintptr_t playerObj, float &x, float &y, float &z) {
    uintptr_t transform = readMem<uintptr_t>(playerObj + 0x38); // Стандартный офсет Transform в Unity
    if (!transform) return false;
    
    // Внутренняя структура Transform для получения позиции (обычно 0x90)
    uintptr_t matrix = readMem<uintptr_t>(transform + 0x38); 
    if (!matrix) return false;
    
    x = readMem<float>(matrix + 0x80);
    y = readMem<float>(matrix + 0x84);
    z = readMem<float>(matrix + 0x88);
    return true;
}

// Захват экрана
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
        @autoreleasepool {
            UIGraphicsBeginImageContextWithOptions([UIScreen mainScreen].bounds.size, NO, 1.0);
            [[UIApplication sharedApplication].keyWindow drawViewHierarchyInRect:[UIScreen mainScreen].bounds afterScreenUpdates:NO];
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            if (checkCenterPixel(img)) {
                dispatch_async(dispatch_get_main_queue(), ^{ simulateFireTouch(); });
                usleep(50000); // Задержка между выстрелами
            }
        }
        usleep(10000);
    }
}

%ctor {
    // Получаем базовый адрес UnityFramework
    g_unityBase = (uintptr_t)dlopen("Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        triggerLoop();
    });
}
