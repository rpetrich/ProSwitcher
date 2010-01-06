#import <UIKit/UIKit.h>
#import "libactivator.h"
#import "PSWSnapshotPageView.h"

void PSWSuppressBackgroundingOnDisplayIdentifer(NSString *displayIdentifier);

@interface PSWViewController : UIViewController<PSWSnapshotPageViewDelegate, LAListener> {
@private
	PSWSnapshotPageView *snapshotPageView;
	PSWApplication *focusedApplication;
	BOOL isActive;
	BOOL isAnimating;
	UIStatusBarStyle formerStatusBarStyle;
}
+ (PSWViewController *)sharedInstance;

@property (nonatomic, assign, getter=isActive) BOOL active;
- (void)setActive:(BOOL)active animated:(BOOL)animated;
@property (nonatomic, readonly) BOOL isAnimating;
@property (nonatomic, readonly) PSWSnapshotPageView *snapshotPageView;

@end
