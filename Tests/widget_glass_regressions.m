// Exercise production archive rewriting without loading private frameworks.
#import <Foundation/Foundation.h>
#import "../widget/WidgetGlassBackground.m"
@interface CHSWidgetDescriptor : NSObject <NSSecureCoding, NSMutableCopying>
@property(copy) NSString *kind;
@property BOOL backgroundRemovable;
@property BOOL transparent;
@property BOOL supportsVibrantContent;
@property NSInteger preferredBackgroundStyle;
@end
@implementation CHSWidgetDescriptor
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:self.kind forKey:@"kind"];
    [c encodeBool:self.backgroundRemovable forKey:@"removable"];
    [c encodeBool:self.transparent forKey:@"transparent"];
    [c encodeBool:self.supportsVibrantContent forKey:@"vibrant"];
    [c encodeInteger:self.preferredBackgroundStyle forKey:@"style"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) {
        self.kind = [c decodeObjectOfClass:NSString.class forKey:@"kind"];
        self.backgroundRemovable = [c decodeBoolForKey:@"removable"];
        self.transparent = [c decodeBoolForKey:@"transparent"];
        self.supportsVibrantContent = [c decodeBoolForKey:@"vibrant"];
        self.preferredBackgroundStyle = [c decodeIntegerForKey:@"style"];
    }
    return self;
}
- (id)mutableCopyWithZone:(NSZone *)zone {
    CHSWidgetDescriptor *copy = [[self.class alloc] init];
    copy.kind = self.kind;
    copy.backgroundRemovable = self.backgroundRemovable;
    copy.transparent = self.transparent;
    copy.supportsVibrantContent = self.supportsVibrantContent;
    copy.preferredBackgroundStyle = self.preferredBackgroundStyle;
    return copy;
}
@end
@interface ABTestResult : NSObject <NSSecureCoding>
@property(copy) NSArray *widgets;
@property(copy) NSString *futureField;
@property BOOL failDecode;
@end
@implementation ABTestResult
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:self.widgets forKey:@"widgets"];
    [c encodeObject:self.futureField forKey:@"future"];
    [c encodeBool:self.failDecode forKey:@"fail"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ([c decodeBoolForKey:@"fail"]) {
        @throw [NSException exceptionWithName:@"ExpectedTestFailure" reason:nil userInfo:nil];
    }
    if ((self = [super init])) {
        self.widgets = [c decodeObjectOfClasses:[NSSet setWithObjects:NSArray.class, CHSWidgetDescriptor.class, nil] forKey:@"widgets"];
        self.futureField = [c decodeObjectOfClass:NSString.class forKey:@"future"];
    }
    return self;
}
@end
int main(void) { @autoreleasepool {
    NSMutableArray *widgets = [NSMutableArray new];
    for (NSString *kind in @[@"widget.battery", @"widget.battery.part2", @"widget.battery.part3", @"widget.battery.part4", @"widget.battery.background", @"widget.battery.part2.background", @"widget.battery.part3.background", @"widget.battery.part4.background", @"unrelated.widget"]) {
        CHSWidgetDescriptor *d = [CHSWidgetDescriptor new]; d.kind = kind; [widgets addObject:d];
    }
    ABTestResult *source = [ABTestResult new]; source.widgets = widgets; source.futureField = @"preserved";
    ABTestResult *patched = ABGlassPatch(source);
    NSCAssert(patched != source, @"Expected reconstructed result");
    NSCAssert([patched.futureField isEqual:source.futureField], @"Preserve unknown fields");
    for (NSUInteger i = 0; i < widgets.count; i++) {
        CHSWidgetDescriptor *d = patched.widgets[i];
        NSCAssert(d.transparent == (i < 4), @"Only battery kinds change");
        NSCAssert(d.preferredBackgroundStyle == (i < 4 ? 2 : 0), @"Material style");
        NSCAssert(d.supportsVibrantContent == (i < 4), @"Vibrant content");
        NSCAssert(![widgets[i] transparent], @"Do not mutate original descriptors");
    }
    source.failDecode = YES;
    NSCAssert(ABGlassPatch(source) == source, @"Decode failure must preserve original");
    source.failDecode = NO; source.widgets = @[widgets.lastObject];
    NSCAssert(ABGlassPatch(source) == source, @"No target descriptors must preserve original");
    NSCAssert(ABGlassPatch(nil) == nil, @"Nil result");
    puts("PASS: four glass kinds, four background kinds, unrelated kind, original immutability, unknown fields, decode fallback, nil result");
} }
