#import <SpringBoard/SpringBoard.h>

@interface SBIcon (OS32)
- (UIImage *)getIconImage:(int)sizeIndex;
@end

@interface SBIconList (OS32)
- (BOOL)firstFreeSlotIndex:(NSInteger *)outIndex;
- (void)placeIcon:(SBIcon *)icon atIndex:(NSInteger)index animate:(BOOL)animate moveNow:(BOOL)moveNow;
@end
