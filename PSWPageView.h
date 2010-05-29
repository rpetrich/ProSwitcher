#import <UIKit/UIKit.h>

#import "PSWApplicationController.h"
#import "PSWSnapshotView.h"
#import "PSWContainerView.h"

@protocol PSWPageViewDelegate;

@interface PSWPageView : UIScrollView <UIScrollViewDelegate, PSWSnapshotViewDelegate, PSWApplicationControllerDelegate> {
@private
	PSWApplicationController *_applicationController;
	NSMutableArray *_applications;
	NSMutableArray *_snapshotViews;

	NSArray *_ignoredDisplayIdentifiers;
	
	id<PSWPageViewDelegate> _pageViewDelegate;
	
	BOOL _showsTitles;
	BOOL _showsCloseButtons;
	BOOL _showsBadges;
	BOOL _allowsZoom;
	BOOL _allowsSwipeToClose;
	BOOL _themedIcons;

	CGFloat _roundedCornerRadius;
	NSInteger _tapsToActivate;
	NSInteger _currentPage;
	CGFloat _snapshotInset;
	CGFloat _unfocusedAlpha;
}

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;

@property (nonatomic, assign) id<PSWPageViewDelegate> pageViewDelegate;
@property (nonatomic, readonly) NSArray *snapshotViews;
@property (nonatomic, assign) PSWApplication *focusedApplication;
- (void)setFocusedApplication:(PSWApplication *)application animated:(BOOL)animated;
@property (nonatomic, readonly) PSWSnapshotView *focusedSnapshotView;
@property (nonatomic, copy) NSArray *ignoredDisplayIdentifiers;

@property (nonatomic, readonly) NSArray *applications;
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
@property (nonatomic, assign) NSInteger currentPage;


- (NSInteger)indexOfApplication:(PSWApplication *)application;
- (void)noteApplicationCountChanged;
- (void)updateContentSize;
- (void)shouldExit;

- (void)moveToStart;
- (void)moveToEnd;
- (void)moveNext;
- (void)movePrevious;

// Allow temporarily adding/removing views
- (void)addViewForApplication:(PSWApplication *)application;
- (void)addViewForApplication:(PSWApplication *)application atPosition:(NSUInteger)position;
- (void)removeViewForApplication:(PSWApplication *)application animated:(BOOL)animated;
- (void)removeViewForApplication:(PSWApplication *)application;

@end

@protocol PSWPageViewDelegate <NSObject>
@optional
- (void)snapshotPageView:(PSWPageView *)snapshotPageView didSelectApplication:(PSWApplication *)application;
- (void)snapshotPageView:(PSWPageView *)snapshotPageView didCloseApplication:(PSWApplication *)application;
- (void)snapshotPageView:(PSWPageView *)snapshotPageView didFocusApplication:(PSWApplication *)application;
- (void)snapshotPageView:(PSWPageView *)snapshotPageView didChangeToPage:(int)page;
- (void)snapshotPageView:(PSWPageView *)snapshotPageView pageCountDidChange:(int)pageCount;
- (void)snapshotPageViewShouldExit:(PSWPageView *)snapshotPageView;
@end