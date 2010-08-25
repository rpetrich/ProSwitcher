
#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>

@class PSWPageView;

typedef struct {
	CGFloat top, left, right, bottom;
} PSWProportionalInsets;

CGRect PSWProportionalInsetsInsetRect(CGRect rect, PSWProportionalInsets insets);

@interface PSWContainerView : UIView {
@private
	PSWPageView *_pageView;
	PSWProportionalInsets _pageViewInsets;
	UIEdgeInsets _pageViewEdgeInsets;
	
	BOOL _isEmpty;
	
	BOOL _showsPageControl;
	UIPageControl *_pageControl;
	
	UILabel *_emptyLabel;
	NSString *_emptyText;
	BOOL _autoExit;
	BOOL _emptyTapClose;
	
	BOOL _shouldScrollOnUp;
	BOOL _doubleTapped;
}

- (void)setPageControlCount:(NSInteger)count;

@property (nonatomic, assign) PSWProportionalInsets pageViewInsets;
@property (nonatomic, assign) UIEdgeInsets pageViewEdgeInsets;
@property (nonatomic, retain) PSWPageView *pageView;

@property (nonatomic, retain) UIPageControl *pageControl;
@property (nonatomic, assign) NSInteger pageControlPage;

@property (nonatomic, assign) BOOL isEmpty;
@property (nonatomic, copy) NSString *emptyText;
@property (nonatomic, assign) BOOL emptyTapClose;
@property (nonatomic, assign) BOOL autoExit;

@property (nonatomic, readwrite) BOOL doubleTapped;

@end