// Retained tracking-area configuration. Delivery is provided by the view host;
// creating a tracking area alone does not imply pointer events have been sent.
@interface NSTrackingArea : NSObject
@property(nonatomic,readonly) CGRect rect;
@property(nonatomic,readonly) NSUInteger options;
@property(nonatomic,weak,readonly) id owner;
@property(nonatomic,copy,readonly) NSDictionary *userInfo;
@end
@implementation NSTrackingArea
- (id)initWithRect:(CGRect)rect options:(NSUInteger)options owner:(id)owner userInfo:(NSDictionary *)info {
 if ((self=[super init])) {_rect=rect;_options=options;_owner=owner;_userInfo=[info copy];}
 fprintf(stderr,"DE_TRACKING_AREA_CREATED options=%lu rect=%g,%g,%g,%g\n",(unsigned long)options,rect.origin.x,rect.origin.y,rect.size.width,rect.size.height);
 return self;
}
@end
