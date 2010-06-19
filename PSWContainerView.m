
#import "PSWContainerView.h"
#import "PSWPageView.h"
#import "PSWPreferences.h"

CHDeclareClass(SBIconModel);
CHDeclareClass(SBIconController);

@implementation PSWContainerView

@synthesize pageControl = _pageControl;
@synthesize emptyTapClose = _emptyTapClose;
@synthesize autoExit = _autoExit;
@synthesize pageView = _pageView;
@synthesize doubleTapped = _doubleTapped;

- (id)init
{
	if ((self = [super init])) {
		[self setUserInteractionEnabled:YES];
		
		_pageControl = [[UIPageControl alloc] init];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[self addSubview:_pageControl];
		
		_emptyLabel = [[UILabel alloc] init];
		[_emptyLabel setBackgroundColor:[UIColor clearColor]];
		[_emptyLabel setTextAlignment:UITextAlignmentCenter];
		[_emptyLabel setFont:[UIFont boldSystemFontOfSize:16.0f]];
		[_emptyLabel setTextColor:[UIColor whiteColor]];
		[self addSubview:_emptyLabel];
		[_emptyLabel setHidden:YES];
		
		[self setIsEmpty:YES];
		[self setNeedsLayout];
		[self layoutIfNeeded];
	}
	
	return self;
}

- (void)dealloc
{
	[_emptyLabel release];
	[_pageControl release];
	[_pageView release];
	
	[super dealloc];
}

- (void)layoutSubviews
{
	CGRect frame;
	frame.size = [_emptyText sizeWithFont:_emptyLabel.font];
	CGSize size = [self bounds].size;
	frame.origin.x = (NSInteger) (size.width - frame.size.width) / 2;
	frame.origin.y = (NSInteger) (size.height - frame.size.height) / 2;
	[_emptyLabel setFrame:frame];
	
	// Fix page control positioning by retrieving it from the SpringBoard page control
	SBIconListPageControl *pageControl = CHIvar(CHSharedInstance(SBIconController), _pageControl, SBIconListPageControl *);
	frame = [self convertRect:[pageControl frame] fromView:[pageControl superview]];
	[_pageControl setFrame:frame];
	
	PSWApplication *focusedApplication = [_pageView focusedApplication];
	frame.origin.x = 0.0f;
	frame.origin.y = 0.0f;
	frame.size = size;
	[_pageView setFrame:UIEdgeInsetsInsetRect(frame, _pageViewInsets)];
	[_pageView setFocusedApplication:focusedApplication];
}

- (void)shouldExit
{
	[_pageView shouldExit];
}

- (UIEdgeInsets)pageViewInsets
{
	return _pageViewInsets;
}

- (void)setPageViewInsets:(UIEdgeInsets)pageViewInsets
{
	_pageViewInsets = pageViewInsets;
	[self setNeedsLayout];
}

- (void)setPageView:(PSWPageView *)pageView
{
	if (_pageView != pageView) {
		[_pageView removeFromSuperview];
		[_pageView release];
		_pageView = [pageView retain];
		[self addSubview:_pageView];
		[self setNeedsLayout];
	}
}

- (BOOL)isEmpty
{
	return _isEmpty;
}

- (void)setIsEmpty:(BOOL)isEmpty
{
	_isEmpty = isEmpty;
	
	if ([self autoExit] && [self isEmpty])
		[self shouldExit];
		
	[_emptyLabel setHidden:!_isEmpty];
}

- (NSString *)emptyText
{
	return _emptyText;
}
- (void)setEmptyText:(NSString *)emptyText
{
	if (emptyText != _emptyText) {
		[_emptyText autorelease];
		_emptyText = [emptyText copy];
		[_emptyLabel setText:_emptyText];
		
		[self setNeedsLayout];
	}
}

- (BOOL)showsPageControl
{
	return [_pageControl isHidden];
}

- (void)setShowsPageControl:(BOOL)showsPageControl
{
	[_pageControl setHidden:!showsPageControl];
}

- (void)setPageControlCount:(NSInteger)count
{
	[_pageControl setNumberOfPages:count];
	
	[self setIsEmpty:!count];
}

- (NSInteger)pageControlPage
{
	return [_pageControl currentPage];
}

- (void)setPageControlPage:(NSInteger)page
{
	[_pageControl setCurrentPage:page];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	if ([self isEmpty])
		return self;
	
    UIView *child = nil;
    if ((child = [super hitTest:point withEvent:event]) == self)
        child = _pageView; 

    return child;
}

- (void)tapPreviousAndContinue
{
	[_pageView movePrevious];
	_shouldScrollOnUp = NO;
}

- (void)tapNextAndContinue
{
	[_pageView moveNext];
	_shouldScrollOnUp = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	CGPoint offset = [_pageView frame].origin;

	point.x -= offset.x;
	
	if (point.x <= 0.0f) {
		[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.1f];
	} else if (point.x > [_pageView bounds].size.width) {
		[self performSelector:@selector(tapNextAndContinue) withObject:nil afterDelay:0.1f];
	}
	
	_shouldScrollOnUp = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
	
	_shouldScrollOnUp = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self isEmpty] && [self emptyTapClose])
		[self shouldExit];
	
	UITouch *touch = [touches anyObject];
	NSInteger tapCount = [touch tapCount];
	CGPoint point = [touch locationInView:self];
	CGPoint offset = [_pageView frame].origin;

	point.x -= offset.x;

	_doubleTapped = NO;
	if (tapCount == 2) {
		_doubleTapped = YES;
		
		if (point.x <= 0.0f) {
			[_pageView moveToStart];
		} else {
			[_pageView moveToEnd];
		}
	} else if (_shouldScrollOnUp) {
		if (point.x <= 0.0f) {
			[self tapPreviousAndContinue];
		} else if (point.x > [_pageView bounds].size.width) {
			[self tapNextAndContinue];
		}
	}
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
	_shouldScrollOnUp = NO;
}

@end

CHConstructor
{
	CHLoadLateClass(SBIconModel);
	CHLoadLateClass(SBIconController);
}
