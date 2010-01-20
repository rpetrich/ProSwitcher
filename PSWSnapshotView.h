#import <UIKit/UIKit.h>

#import "PSWApplication.h"

@class CALayer;
@protocol PSWSnapshotViewDelegate;

@interface PSWSnapshotView : UIView<PSWApplicationDelegate> {
@private
	PSWApplication *_application;
	id<PSWSnapshotViewDelegate> _delegate;
	BOOL _allowsSwipeToClose;
	BOOL _showsCloseButton;
	BOOL _showsTitle;
	BOOL _themedIcon;
	BOOL _showsBadge;
	BOOL _focused; 
	BOOL _allowsZoom;
	UIButton *_closeButton;
	UIView *_iconBadge;
	UILabel *_titleView;
	UIImageView *_iconView;
	
	BOOL wasSwipedAway;
	BOOL wasSwipedUp;
	BOOL isInDrag;
	BOOL isZoomed;
	CGPoint touchDownPoint;
	UIButton *screen;
	CGFloat screenY;
	CGFloat _roundedCornerRadius;
}

- (id)initWithFrame:(CGRect)frame application:(PSWApplication *)application;

@property (nonatomic, readonly) PSWApplication *application;
@property (nonatomic, assign) id<PSWSnapshotViewDelegate> delegate;
@property (nonatomic, assign) BOOL showsTitle;
@property (nonatomic, assign) BOOL showsBadge;
@property (nonatomic, assign) BOOL allowsZoom;
@property (nonatomic, assign, getter=isZoomed) BOOL zoomed;
- (void)setZoomed:(BOOL)zoomed animated:(BOOL)animated;
@property (nonatomic, assign) BOOL themedIcon;
@property (nonatomic, assign) BOOL showsCloseButton;
@property (nonatomic, assign) BOOL allowsSwipeToClose;
@property (nonatomic, assign) CGFloat roundedCornerRadius;
@property (nonatomic, assign) BOOL focused;
- (void)setFocused:(BOOL)focused animated:(BOOL)animated;
@property (nonatomic, readonly) UIView *screenView;

- (void)redraw;
- (void)reloadSnapshot;

@end

@protocol PSWSnapshotViewDelegate <NSObject>
@optional
- (void)snapshotViewTapped:(PSWSnapshotView *)snapshotView withCount:(NSInteger)tapCount;
- (void)snapshotViewClosed:(PSWSnapshotView *)snapshotView;
- (void)snapshotViewDidSwipeOut:(PSWSnapshotView *)snapshotView;
@end