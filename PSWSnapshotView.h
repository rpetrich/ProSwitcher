#import <UIKit/UIKit.h>

#import "PSWApplication.h"

@class CALayer;
@protocol PSWSnapshotViewDelegate;

@interface PSWSnapshotView : UIView<PSWApplicationDelegate> {
@private
	PSWApplication *_application;
	id<PSWSnapshotViewDelegate> _delegate;

	UIButton *_closeButton;
	UIView *_iconBadge;
	UILabel *_badgeLabel;
	UILabel *_titleView;
	UIImageView *_iconView;
	
	BOOL wasSwipedAway;
	BOOL wasSwipedUp;
	BOOL isInDrag;
	BOOL isZoomed;
	BOOL _focused; 
	CGFloat screenY;
	CGPoint touchDownPoint;
	UIButton *screen;
}

- (id)initWithFrame:(CGRect)frame application:(PSWApplication *)application;

@property (nonatomic, readonly) PSWApplication *application;
@property (nonatomic, assign) id<PSWSnapshotViewDelegate> delegate;
@property (nonatomic, assign, getter=isZoomed) BOOL zoomed;
- (void)setZoomed:(BOOL)zoomed animated:(BOOL)animated;
@property (nonatomic, assign) BOOL focused;
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
@property (nonatomic, readonly) UIView *screenView;

- (CGSize)reloadSnapshot;
- (void)layoutSubviews;

@end

@protocol PSWSnapshotViewDelegate <NSObject>
@optional
- (void)snapshotViewTapped:(PSWSnapshotView *)snapshotView withCount:(NSInteger)tapCount;
- (void)snapshotViewClosed:(PSWSnapshotView *)snapshotView;
- (void)snapshotViewDidSwipeOut:(PSWSnapshotView *)snapshotView;
@end