// macOS material background support inspired by pookjw/ClearAndBlurredWidgets.
// Private runtime integration for this custom build; unsupported runtimes fall back.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
@interface ABGlassArchiveDelegate : NSObject <NSKeyedArchiverDelegate>
@property(nonatomic) NSUInteger changes;
@end
@implementation ABGlassArchiveDelegate
- (id)archiver:(NSKeyedArchiver *)archiver willEncodeObject:(id)object {
    Class descriptor = NSClassFromString(@"CHSWidgetDescriptor");
    if (!descriptor || ![object isKindOfClass:descriptor]) return object;
    SEL kindSelector = NSSelectorFromString(@"kind");
    if (![object respondsToSelector:kindSelector]) return object;
    NSString *kind = ((id (*)(id, SEL))objc_msgSend)(object, kindSelector);
    if (![@[@"widget.battery", @"widget.battery.part2", @"widget.battery.part3",
             @"widget.battery.part4"] containsObject:kind]) return object;
    // Style 2 requests the host material, verified as Liquid Glass on macOS 27.
    NSInteger style = 2;
    id copy = [object mutableCopy];
    NSArray *names = @[@"setBackgroundRemovable:", @"setTransparent:",
                       @"setSupportsVibrantContent:", @"setPreferredBackgroundStyle:"];
    for (NSString *name in names) {
        NSMethodSignature *signature = [copy methodSignatureForSelector:NSSelectorFromString(name)];
        const char *argument = signature.numberOfArguments == 3 ? [signature getArgumentTypeAtIndex:2] : "";
        BOOL integerStyle = [name isEqualToString:@"setPreferredBackgroundStyle:"];
        if (!signature || strcmp(signature.methodReturnType, @encode(void)) != 0 ||
            strcmp(argument, integerStyle ? @encode(NSInteger) : @encode(BOOL)) != 0) {
            @throw [NSException exceptionWithName:@"ABGlassUnsupported" reason:name userInfo:nil];
        }
    }
    ((void (*)(id, SEL, BOOL))objc_msgSend)(copy, NSSelectorFromString(names[0]), YES);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(copy, NSSelectorFromString(names[1]), YES);
    ((void (*)(id, SEL, BOOL))objc_msgSend)(copy, NSSelectorFromString(names[2]), YES);
    ((void (*)(id, SEL, NSInteger))objc_msgSend)(copy, NSSelectorFromString(names[3]), style);
    self.changes++;
    return copy;
}
@end

static id ABGlassPatch(id result) {
    // Re-encode the original object rather than hard-coding its archive fields.
    // Strong ARC ownership keeps archive bytes alive through reconstruction.
    @try {
        if (!result || ![result respondsToSelector:@selector(encodeWithCoder:)] ||
            ![result conformsToProtocol:@protocol(NSSecureCoding)]) return result;
        ABGlassArchiveDelegate *delegate = [ABGlassArchiveDelegate new];
        NSKeyedArchiver *archive = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
        archive.delegate = delegate;
        [result encodeWithCoder:archive];
        [archive finishEncoding];
        if (!delegate.changes) return result;
        NSData *data = archive.encodedData;
        NSError *error = nil;
        NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
        if (!reader || error) return result;
        reader.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
        id rebuilt = [[[result class] alloc] initWithCoder:reader];
        [reader finishDecoding];
        if (!rebuilt || reader.error) return result;
        NSLog(@"[ABWidgetGlass] Patched %lu battery descriptors", (unsigned long)delegate.changes);
        return rebuilt;
    } @catch (NSException *exception) {
        NSLog(@"[ABWidgetGlass] Keeping original descriptors: %@", exception.name);
        return result;
    }
}
static void (*ABOriginalDescriptors)(id, SEL, void (^)(id));
static void ABGetDescriptors(id object, SEL selector, void (^completion)(id)) {
    ABOriginalDescriptors(object, selector, ^(id result) {
        completion(ABGlassPatch(result));
    });
}
@interface ABGlassInstaller : NSObject @end
@implementation ABGlassInstaller
+ (void)load {
    // Install after framework loading. Only this extension process is affected.
    if (@available(macOS 26.0, *)) {} else { return; }
    dispatch_async(dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject");
        Method method = class_getInstanceMethod(cls, NSSelectorFromString(@"getAllCurrentDescriptorsWithCompletion:"));
        NSMethodSignature *signature = method ? [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)] : nil;
        if (!signature || signature.numberOfArguments != 3 ||
            strcmp(signature.methodReturnType, @encode(void)) != 0 ||
            strcmp([signature getArgumentTypeAtIndex:2], "@?") != 0) {
            NSLog(@"[ABWidgetGlass] Unsupported runtime; hook disabled");
            return;
        }
        ABOriginalDescriptors = (void *)method_getImplementation(method);
        method_setImplementation(method, (IMP)ABGetDescriptors);
        NSLog(@"[ABWidgetGlass] Installed material background support");
    });
}
@end
