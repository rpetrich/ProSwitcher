#import <UIKit/UIKit.h>
#import "PSWSnapshotView.h"
#import "PSWApplicationController.h"

@protocol PSWSnapshotPageViewDelegate;

@interface PSWSnapshotPageView : UIView <UIScrollViewDelegate, PSWSnapshotViewDelegate, PSWApplicationControllerDelegate> {
@private
	PSWApplicationController *_applicationController;
	NSMutableArray *_applications;
	NSMutableArray *_snapshotViews;
	UIScrollView *_scrollView;
	UIPageControl *_pageControl;
	UILabel *_emptyLabel;
	NSString *_emptyText;

	id<PSWSnapshotPageViewDelegate> _delegate;
	
	BOOL _showsTitles;
	BOOL _showsCloseButtons;
	BOOL _allowsSwipeToClose;
	CGFloat _roundedCornerRadius;
	NSInteger _tapsToActivate;
}

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;

@property (nonatomic, assign) id<PSWSnapshotPageViewDelegate> delegate;
@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, readonly) NSArray *snapshotViews;
@property (nonatomic, assign) PSWApplication *focusedApplication;
- (void)setFocusedApplication:(PSWApplication *)application animated:(BOOL)animated;

@property (nonatomic, assign) NSString *emptyText;
@property (nonatomic, assign) BOOL showsTitles;
@property (nonatomic, assign) BOOL showsCloseButtons;
@property (nonatomic, assign) BOOL allowsSwipeToClose;
@property (nonatomic, assign) CGFloat roundedCornerRadius;
@property (nonatomic, assign) NSInteger tapsToActivate;

- (NSInteger)indexOfApplication:(PSWApplication *)application;

@end

@protocol PSWSnapshotPageViewDelegate <NSObject>
@optional
- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didSelectApplication:(PSWApplication *)application;
- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didCloseApplication:(PSWApplication *)application;
- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didFocusApplication:(PSWApplication *)application;
- (void)snapshotPageViewShouldExit:(PSWSnapshotPageView *)snapshotPageView;
@end
