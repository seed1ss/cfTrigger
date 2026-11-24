#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>

// Офсеты из твоего дампа
#define OFFSET_GET_PLAYER 0x90
#define OFFSET_HEALTH 0x18

static uintptr_t g_unityBase = 0;
static task_t g_task = MACH_PORT_NULL;
static uintptr_t g_localPlayer = 0;

template<typename T> T readMem(uintptr_t addr) {
    T val = 0;
    if (addr && g_task) vm_read_overwrite(g_task, addr, sizeof(T), (vm_address_t)&val, nullptr);
    return val;
}

@interface ESPView : UIView
@end

@implementation ESPView
- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextClearRect(ctx, rect);
    if (!g_task || !g_localPlayer) return;
    
    // Читаем здоровье локального игрока (для проверки)
    int hp = readMem<int>(g_localPlayer + OFFSET_HEALTH);
    if (hp > 0 && hp <= 1000) {
        // Если нашли игрока, рисуем индикатор, что чтение памяти работает
        CGContextSetFillColorWithColor(ctx, [UIColor greenColor].CGColor);
        CGContextFillRect(ctx, CGRectMake(50, 50, 100, 50));
        UIFont *font = [UIFont boldSystemFontOfSize:20];
        [@"MEMORY ACTIVE" drawAtPoint:CGPointMake(55, 65) withAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:[UIColor whiteColor]}];
    }
}
- (void)update {
    [self setNeedsDisplay];
}
@end

%ctor {
    // Инициализация порта для чтения памяти
    g_task = mach_task_self();
    
    // Запуск оверлея
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = [UIColor clearColor];
        window.rootViewController = [UIViewController new];
        ESPView *esp = [[ESPView alloc] initWithFrame:window.bounds];
        esp.backgroundColor = [UIColor clearColor];
        [window.rootViewController.view addSubview:esp];
        [window makeKeyAndVisible];
        
        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:esp selector:@selector(update)];
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}
