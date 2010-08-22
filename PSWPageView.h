#import <UIKit/UIKit.h>

#import "PSWApplicationController.h"
#import "PSWSnapshotView.h"
#import "PSWContainerView.h"
#import "PSWPreferences.h"

@protocol PSWPageViewDelegate;

@interface PSWPageView : UIScrollView <UIScrollViewDelegate, PSWSnapshotViewDelegate, PSWApplicationControllerDelegate> {
@private
	PSWApplicationController *_applicationController;
	NSMutableArray *_applications;
	NSMutableArray *_snapshotViews;
	
	NSArray *_ignoredDisplayIdentifiers;
	id<PSWPageViewDelegate> _pageViewDelegate;
	NSInteger _currentPage;
}

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;

@property (nonatomic, assign) id<PSWPageViewDelegate> pageViewDelegate;
@property (nonatomic, readonly) NSArray *snapshotViews;
@property (nonatomic, assign) PSWApplication *focusedApplication;
- (void)setFocusedApplication:(PSWApplication *)application animated:(BOOL)animated;
@property (nonatomic, readonly) PSWSnapshotView *focusedSnapshotView;
@property (nonatomic, copy) NSArray *ignoredDisplayIdentifiers;
@property (nonatomic, readonly) NSArray *applications;
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