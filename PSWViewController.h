#import <UIKit/UIKit.h>
#import "PSWSnapshotPageView.h"

@interface PSWViewController : UIViewController<PSWSnapshotPageViewDelegate> {
@private
	PSWSnapshotPageView *snapshotPageView;
	PSWApplication *focusedApplication;
	BOOL isActive;
	BOOL isAnimating;
	NSDictionary *preferences;
}
+ (PSWViewController *)sharedInstance;

@property (nonatomic, assign, getter=isActive) BOOL active;
- (void)setActive:(BOOL)active animated:(BOOL)animated;
@property (nonatomic, readonly) BOOL isAnimating;

@end
