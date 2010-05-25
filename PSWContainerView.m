
#import "PSWContainerView.h"
#import "PSWPageView.h"

@implementation PSWContainerView

@synthesize pageViewInset = _pageViewInset;
@synthesize pageControl = _pageControl;
@synthesize emptyText = _emptyText;
@synthesize emptyTapClose = _emptyTapClose;
@synthesize autoExit = _autoExit;
@synthesize pageView = _pageView;

- (id)init
{
	if ((self = [super init])) {
		_pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[self addSubview:_pageControl];
		
	}
	
	return self;
}

/*
UIFont *font = [UIFont boldSystemFontOfSize:16.0f];

if (appCount == 0 && _autoExit) {
	if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageViewShouldExit:)])
		[_pageViewDelegate snapshotPageViewShouldExit:self];
} else if ([_emptyText length] != 0 && [_applications count] == 0) {
	if (!_emptyLabel) {
		_emptyLabel = [[UILabel alloc] init];
		_emptyLabel.backgroundColor = [UIColor clearColor];
		_emptyLabel.textAlignment = UITextAlignmentCenter;
		_emptyLabel.font = font;
		_emptyLabel.textColor = [UIColor whiteColor];
		[self addSubview:_emptyLabel];
	} else {
		CGRect bounds = [_emptyLabel bounds];
		bounds.origin.y = (NSInteger)(([self bounds].size.height - bounds.size.height) / 2.0f);
		[_emptyLabel setBounds:bounds];
	}
	_emptyLabel.text = _emptyText;
} else {
	[_emptyLabel removeFromSuperview];
	[_emptyLabel release];
	_emptyLabel = nil;
}

if (_emptyLabel != nil) {
	CGFloat height = [_emptyText sizeWithFont:font].height;
	CGRect bounds = [self bounds];
	bounds.origin.y = (NSInteger)((bounds.size.height - height) / 2.0f);
	bounds.size.height = height;
	[_emptyLabel setFrame:bounds];
}
*/

- (void)dealloc
{
	[_emptyLabel release];
	[_pageControl release];
	
	[super dealloc];
}

- (void)layoutSubviews
{
	[self.pageControl setFrame:UIEdgeInsetsInsetRect([self bounds], [self pageViewInset])];
}

- (void)setFrame:(CGRect)frame
{
	[super setFrame:frame];
	
	[self setNeedsLayout];
}

- (void)shouldExit
{
	[self.pageView shouldExit];
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
	return [self pageView];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if ([self isEmpty] && [self emptyTapClose])
		[self shouldExit];
}

@end
