#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <QuartzCore/QuartzCore.h>
#import <dlfcn.h>

// --- КООРДИНАТЫ КНОПКИ СТРЕЛЬБЫ ---
static CGFloat g_fireXPercent = 0.15;
static CGFloat g_fireYPercent = 0.15;

// Базовый адрес
static uintptr_t g_unityBase = 0;

// Функции il2cpp (будем искать динамически)
typedef void* (*il2cpp_domain_get_t)();
typedef void* (*il2cpp_domain_assembly_open_t)(void*, const char*);
typedef void* (*il2cpp_assembly_get_image_t)(void*);
typedef void* (*il2cpp_class_from_name_t)(void*, const char*, const char*);
typedef void* (*il2cpp_class_get_fields_t)(void*, void**);
typedef const char* (*il2cpp_field_get_name_t)(void*);
typedef size_t (*il2cpp_field_get_offset_t)(void*);

void* playerClass = nullptr;
size_t offset_Transform = 0;
size_t offset_Health = 0;

// Поиск класса Player через il2cpp
void FindPlayerClass() {
    void* handle = dlopen("Frameworks/UnityFramework.framework/UnityFramework", RTLD_LAZY);
    if (!handle) return;
    
    auto p_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    auto p_assembly_open = (il2cpp_domain_assembly_open_t)dlsym(handle, "il2cpp_domain_assembly_open");
    auto p_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    auto p_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    auto p_class_get_fields = (il2cpp_class_get_fields_t)dlsym(handle, "il2cpp_class_get_fields");
    auto p_field_get_name = (il2cpp_field_get_name_t)dlsym(handle, "il2cpp_field_get_name");
    auto p_field_get_offset = (il2cpp_field_get_offset_t)dlsym(handle, "il2cpp_field_get_offset");
    
    if (!p_domain_get) return;
    
    void* domain = p_domain_get();
    void* assembly = p_assembly_open(domain, "Assembly-CSharp");
    if (!assembly) return;
    
    void* image = p_get_image(assembly);
    
    // Ищем PlayerController (или Player, BotController)
    const char* classNames[] = {"PlayerController", "Player", "PlayerNetwork"};
    for (int i = 0; i < 3; i++) {
        playerClass = p_class_from_name(image, "", classNames[i]);
        if (playerClass) {
            void* iter = nullptr;
            void* field = p_class_get_fields(playerClass, &iter);
            while (field) {
                const char* name = p_field_get_name(field);
                size_t off = p_field_get_offset(field);
                
                if (strcmp(name, "transform") == 0 || strcmp(name, "Transform") == 0) offset_Transform = off;
                if (strcmp(name, "health") == 0 || strcmp(name, "Health") == 0) offset_Health = off;
                
                field = p_class_get_fields(playerClass, &iter);
            }
            break;
        }
    }
}

// Симуляция нажатия
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

// Проверка пикселя
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
                simulateFireTouch();
                usleep(50000);
            }
        }
        usleep(10000);
    }
}

%ctor {
    // Ищем класс при загрузке
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        FindPlayerClass();
    });
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        triggerLoop();
    });
}
