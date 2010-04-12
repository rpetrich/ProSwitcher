#import <SpringBoard/SpringBoard.h>

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_3_2
@interface SBIcon (OS30)
- (UIImage *)icon;
- (UIImage *)smallIcon;
@end
#else
@interface SBIcon (OS32)
- (UIImage *)getIconImage:(int)sizeIndex;
@end
#endif
