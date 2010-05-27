
#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>

@class PSWPageView;

@interface PSWContainerView : UIView {
	PSWPageView *_pageView;
	UIEdgeInsets _pageViewInsets;
	
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


@property (nonatomic, assign) UIEdgeInsets pageViewInsets;
@property (nonatomic, retain) PSWPageView *pageView;

@property (nonatomic, retain) UIPageControl *pageControl;
@property (nonatomic, assign) BOOL showsPageControl;
@property (nonatomic, assign) NSInteger pageControlPage;

@property (nonatomic, readonly) BOOL isEmpty;
@property (nonatomic, assign) NSString *emptyText;
@property (nonatomic, assign) BOOL emptyTapClose;
@property (nonatomic, assign) BOOL autoExit;

@property (nonatomic, readwrite) BOOL doubleTapped;


@end