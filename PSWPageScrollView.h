#import <UIKit/UIKit.h>

@class PSWSnapshotPageView;
@interface PSWPageScrollView : UIScrollView {
@private
	BOOL _shouldScrollOnUp;
	BOOL _doubleTapped;
	PSWSnapshotPageView *_pageView;
}

@property (nonatomic, readwrite) BOOL doubleTapped;
@property (nonatomic, assign) PSWSnapshotPageView *pageView;

- (id)initWithFrame:(CGRect)frame pageView:(PSWSnapshotPageView *)pageView;

@end
