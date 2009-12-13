#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWApplication.h"

@protocol PSWSnapshotViewDelegate;

@interface PSWSnapshotView : UIView<PSWApplicationDelegate> {
@private
	PSWApplication *_application;
	id<PSWSnapshotViewDelegate> _delegate;
	BOOL _allowsSwipeToClose;
	BOOL _showsCloseButton;
	BOOL _showsTitle;
	UIButton *_closeButton;
	UILabel *_titleView;
	UIImageView *_iconView;
	
	BOOL wasSwipedAway;
	BOOL isInDrag;
	CGPoint touchDownPoint;
	UIButton *screen;
	
	CGFloat imageViewX;
	CGFloat imageViewY;
	CGFloat imageViewH;
	CGFloat imageViewW;
}
- (id)initWithFrame:(CGRect)frame application:(PSWApplication *)application;

@property (nonatomic, readonly) PSWApplication *application;
@property (nonatomic, assign) id<PSWSnapshotViewDelegate> delegate;
@property (nonatomic, assign) BOOL showsTitle;
@property (nonatomic, assign) BOOL showsCloseButton;
@property (nonatomic, assign) BOOL allowsSwipeToClose;
@property (nonatomic, assign) CGFloat roundedCornerRadius;

@end

@protocol PSWSnapshotViewDelegate <NSObject>
@optional
- (void)snapshotViewTapped:(PSWSnapshotView *)snapshotView withCount:(NSInteger)tapCount;
- (void)snapshotViewClosed:(PSWSnapshotView *)snapshotView;
- (void)snapshotViewDidSwipeOut:(PSWSnapshotView *)snapshotView;
@end