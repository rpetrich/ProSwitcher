#import <SpringBoard/SpringBoard.h>
#import <QuartzCore/QuartzCore.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_3_2
@interface SBIcon (OS30)
- (UIImage *)icon;
- (UIImage *)smallIcon;
@end
#else
@interface SBIcon (OS32)
- (UIImage *)getIconImage:(int)sizeIndex;
@end

@interface SBIconList (OS32)
- (BOOL)firstFreeSlotIndex:(NSInteger *)outIndex;
- (void)placeIcon:(SBIcon *)icon atIndex:(NSInteger)index animate:(BOOL)animate moveNow:(BOOL)moveNow;
@end
#endif
