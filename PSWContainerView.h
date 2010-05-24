
#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>

@class PSWPageView;

@interface PSWContainerView : UIView {
	PSWPageView *_pageView;
	CGFloat _dockHeight;
	CGFloat _statusBarHeight;
}

- (void)layoutSubviews;

@property (nonatomic, assign) CGFloat statusBarHeight;
@property (nonatomic, assign) CGFloat dockHeight;
@property (nonatomic, retain) PSWPageView *pageView;

@end