
#import "PSWContainerView.h"
#import "PSWPageView.h"

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
		
		_pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[self addSubview:_pageControl];
		
		_emptyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		[_emptyLabel setBackgroundColor:[UIColor clearColor]];
		[_emptyLabel setTextAlignment:UITextAlignmentCenter];
		[_emptyLabel setFont:[UIFont boldSystemFontOfSize:16.0f]];
		[_emptyLabel setTextColor:[UIColor whiteColor]];
		[self addSubview:_emptyLabel];
	}
	
	return self;
}

- (void)dealloc
{
	[_emptyLabel release];
	[_pageControl release];
	
	[super dealloc];
}

- (void)layoutSubviews
{
	[self.pageView setFrame:UIEdgeInsetsInsetRect([self bounds], [self pageViewInsets])];
	
	CGFloat height = [_emptyText sizeWithFont:_emptyLabel.font].height;
	CGRect bounds = [self bounds];
	bounds.origin.y = (NSInteger) ((bounds.size.height - height) / 2.0f);
	bounds.size.height = height;
	[_emptyLabel setFrame:bounds];
}

- (void)setFrame:(CGRect)frame
{
	[super setFrame:frame];
	
	[self layoutSubviews];
}

- (void)shouldExit
{
	[self.pageView shouldExit];
}

- (UIEdgeInsets)pageViewInsets
{
	return _pageViewInsets;
}
- (void)setPageViewInsets:(UIEdgeInsets)pageViewInsets
{
	_pageViewInsets = pageViewInsets;
	[self layoutSubviews];
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
}

- (NSString *)emptyText
{
	return _emptyText;
}
- (void)setEmptyText:(NSString *)emptyText
{
	if (emptyText != _emptyText) {
		_emptyText = [emptyText retain];
		[_emptyLabel setText:_emptyText];
		[self layoutSubviews];
	}
}

- (BOOL)showsPageControl
{
	return [self.pageControl isHidden];
}

- (void)setShowsPageControl:(BOOL)showsPageControl
{
	[self.pageControl setHidden:!showsPageControl];
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
    UIView *child = nil;
    if ((child = [super hitTest:point withEvent:event]) == self)
        child = self.pageView; 

    return child;
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
