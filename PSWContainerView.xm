
#import "PSWContainerView.h"
#import "PSWPageView.h"
#import "PSWPreferences.h"

%class SBIconModel;
%class SBIconController;

CGRect PSWProportionalInsetsInsetRect(CGRect rect, PSWProportionalInsets insets)
{
	UIEdgeInsets realInsets;
	realInsets.top = rect.size.height * insets.top;
	realInsets.bottom = rect.size.height * insets.bottom;
	realInsets.left = rect.size.width * insets.left;
	realInsets.right = rect.size.height * insets.right;
	return UIEdgeInsetsInsetRect(rect, realInsets); 
}

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
		[_pageControl setHidden:GetPreference(PSWShowPageControl, BOOL)];
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
	SBIconListPageControl *pageControl = MSHookIvar<SBIconListPageControl *>([$SBIconController sharedInstance], "_pageControl");
	frame = [self convertRect:[pageControl frame] fromView:[pageControl superview]];
	[_pageControl setFrame:frame];
	
	PSWApplication *focusedApplication = [_pageView focusedApplication];
	frame.origin.x = 0.0f;
	frame.origin.y = 0.0f;
	frame.size = size;
	[_pageView setFrame:UIEdgeInsetsInsetRect(frame, _pageViewEdgeInsets)];
	[_pageView setFocusedApplication:focusedApplication];
}

- (void)shouldExit
{
	[self.pageView shouldExit];
}

- (void)_applyInsets
{
	CGRect edge = UIEdgeInsetsInsetRect([self bounds], _pageViewEdgeInsets);
	CGRect proportional = PSWProportionalInsetsInsetRect(edge, _pageViewInsets);
	[_pageView setFrame:proportional];
}

- (UIEdgeInsets)pageViewEdgeInsets
{
	return _pageViewEdgeInsets;
}
- (void)setPageViewEdgeInsets:(UIEdgeInsets)pageViewEdgeInsets
{
	_pageViewEdgeInsets = pageViewEdgeInsets;
	[self _applyInsets];
}

- (PSWProportionalInsets)pageViewInsets
{
	return _pageViewInsets;
}
- (void)setPageViewInsets:(PSWProportionalInsets)pageViewInsets
{
	_pageViewInsets = pageViewInsets;
	[self _applyInsets];
}

- (void)setPageView:(PSWPageView *)pageView
{
	if (_pageView != pageView) {
		[_pageView release];
		_pageView = [pageView retain];
		
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

- (void)setPageControlCount:(NSInteger)count
{
	[self.pageControl setNumberOfPages:count];
	
	[self setIsEmpty:!count];
}

- (NSInteger)pageControlPage
{
	return [self.pageControl currentPage];
}

- (void)setPageControlPage:(NSInteger)page
{
	[self.pageControl setCurrentPage:page];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	UIView *result = [super hitTest:point withEvent:event];
	if (![self isEmpty] && (result == self))
		result = _pageView;
	return result;
}

- (void)tapPreviousAndContinue
{
	[self.pageView movePrevious];
	_shouldScrollOnUp = NO;
}

- (void)tapNextAndContinue
{
	[self.pageView moveNext];
	_shouldScrollOnUp = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:self];
	CGPoint offset = [self.pageView frame].origin;

	point.x -= offset.x;
	
	if (point.x <= 0.0f) {
		[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.1f];
	} else if (point.x > [self.pageView bounds].size.width) {
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
	CGPoint offset = [self.pageView frame].origin;

	point.x -= offset.x;

	_doubleTapped = NO;
	if (tapCount == 2) {
		_doubleTapped = YES;
		
		if (point.x <= 0.0f) {
			[self.pageView moveToStart];
		} else {
			[self.pageView moveToEnd];
		}
	} else if (_shouldScrollOnUp) {
		if (point.x <= 0.0f) {
			[self tapPreviousAndContinue];
		} else if (point.x > [self.pageView bounds].size.width) {
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

