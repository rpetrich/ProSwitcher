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
	NSArray *_ignoredDisplayIdentifiers;
	
	id<PSWSnapshotPageViewDelegate> _delegate;
	
	BOOL _showsTitles;
	BOOL _showsCloseButtons;
	BOOL _showsBadges;
	BOOL _allowsZoom;
	BOOL _allowsSwipeToClose;
	BOOL _themedIcons;
	BOOL _scrollingToSide;
	CGFloat _roundedCornerRadius;
	NSInteger _tapsToActivate;
	CGFloat _snapshotInset;
	CGFloat _unfocusedAlpha;
}

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;

@property (nonatomic, assign) id<PSWSnapshotPageViewDelegate> delegate;
@property (nonatomic, readonly) UIScrollView *scrollView;
@property (nonatomic, readonly) NSArray *snapshotViews;
@property (nonatomic, assign) PSWApplication *focusedApplication;
- (void)setFocusedApplication:(PSWApplication *)application animated:(BOOL)animated;
@property (nonatomic, readonly) PSWSnapshotView *focusedSnapshotView;
@property (nonatomic, copy) NSArray *ignoredDisplayIdentifiers;

@property (nonatomic, assign) NSString *emptyText;
@property (nonatomic, assign) BOOL showsTitles;
@property (nonatomic, assign) BOOL showsBadges;
@property (nonatomic, assign) BOOL showsCloseButtons;
@property (nonatomic, assign) BOOL allowsSwipeToClose;
@property (nonatomic, assign) BOOL themedIcons;
@property (nonatomic, assign) BOOL allowsZoom;
@property (nonatomic, assign) CGFloat roundedCornerRadius;
@property (nonatomic, assign) NSInteger tapsToActivate;
@property (nonatomic, assign) CGFloat snapshotInset;
@property (nonatomic, assign) CGFloat unfocusedAlpha;
@property (nonatomic, assign) BOOL showsPageControl;
@property (nonatomic, assign, getter=isPagingEnabled) BOOL pagingEnabled;

- (NSInteger)indexOfApplication:(PSWApplication *)application;
- (void)redraw;

// Allow temporarily adding/removing views
- (void)addViewForApplication:(PSWApplication *)application;
- (void)removeViewForApplication:(PSWApplication *)application;

@end

@protocol PSWSnapshotPageViewDelegate <NSObject>
@optional
- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didSelectApplication:(PSWApplication *)application;
- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didCloseApplication:(PSWApplication *)application;
- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didFocusApplication:(PSWApplication *)application;
- (void)snapshotPageViewShouldExit:(PSWSnapshotPageView *)snapshotPageView;
@end