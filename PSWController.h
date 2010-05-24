#import <UIKit/UIKit.h>
#import "libactivator.h"

void PSWSuppressBackgroundingOnDisplayIdentifer(NSString *displayIdentifier);

@class PSWPageView, PSWContainerView, PSWApplication;

@interface PSWController : NSObject {
@private
	PSWPageView *snapshotPageView;
	PSWContainerView *containerView;
	
	PSWApplication *focusedApplication;
	BOOL isActive;
	BOOL isAnimating;
	UIStatusBarStyle formerStatusBarStyle;
}

+ (PSWController *)sharedInstance;

@property (nonatomic, assign, getter=isActive) BOOL active;
- (void)setActive:(BOOL)active animated:(BOOL)animated;

@property (nonatomic, readonly) BOOL isAnimating;
@property (nonatomic, readonly) PSWPageView *snapshotPageView;
@property (nonatomic, readonly) PSWContainerView *containerView;

@end
