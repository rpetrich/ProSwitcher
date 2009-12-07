#import "PSWSnapshotPageView.h"
#import <QuartzCore/QuartzCore.h>
#import <CaptainHook/CaptainHook.h>

@implementation PSWSnapshotPageView
@synthesize delegate = _delegate;
@synthesize scrollView = _scrollView;
@synthesize tapsToActivate = _tapsToActivate;

#pragma mark Public Methods

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;
{
	if ((self = [super initWithFrame:frame])) 
	{	
		_applicationController = [applicationController retain];
		[applicationController setDelegate:self];
		_applications = [[applicationController activeApplications] mutableCopy];
		NSUInteger numberOfPages = [_applications count];
		
		_pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, frame.size.height - 27.0f, frame.size.width, 27.0f)];
		[_pageControl setNumberOfPages:numberOfPages];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[self addSubview:_pageControl];
		
		_scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, frame.size.width, frame.size.height)];
		[_scrollView setPagingEnabled:YES];
		[_scrollView setContentSize:CGSizeMake(frame.size.width * numberOfPages + 1.0f, frame.size.height)];
		[_scrollView setShowsHorizontalScrollIndicator:NO];
		[_scrollView setShowsVerticalScrollIndicator:NO];
		[_scrollView setScrollsToTop:NO];
		[_scrollView setDelegate:self];
		[_scrollView setBackgroundColor:[UIColor clearColor]];

		_snapshotViews = [[NSMutableArray alloc] init];
		CGRect pageFrame;
		pageFrame.origin.x = 0.0f;
		pageFrame.origin.y = 0.0f;
		pageFrame.size.height = frame.size.height;
		pageFrame.size.width = frame.size.width;
		for (int i = 0; i < numberOfPages; i++) {
			PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:pageFrame application:[_applications objectAtIndex:i]];
			snapshot.delegate = self;
			snapshot.showsTitle = _showsTitles;
			snapshot.showsCloseButton = _showsCloseButtons;
			snapshot.allowsSwipeToClose = _allowsSwipeToClose;
			[_scrollView addSubview:snapshot];
			[_snapshotViews addObject:snapshot];
			[snapshot release];
			pageFrame.origin.x += frame.size.width;
		}
		[self addSubview:_scrollView];

		[self setBackgroundColor:[UIColor clearColor]];
	}
	return self;
}

- (void)dealloc
{
	[_applicationController setDelegate:nil];
	[_applicationController release];
	[_emptyLabel release]; // this will be nil if it is set to NO
	[_scrollView release];
	[_pageControl release];
	[_snapshotViews release];
	[_applications release];
	[super dealloc];
}

- (NSArray *)snapshotViews
{
	return [[_snapshotViews copy] autorelease];
}

#pragma mark Private Methods

- (void)_toggleEmptyText
{
	if (_showsEmptyText == YES && [_applications count] == 0) {
		UIFont *emptyFont = [UIFont boldSystemFontOfSize:16.0];
		NSString *emptyText = @"No Apps Running";
		CGSize emptySize = [emptyText sizeWithFont:emptyFont];
		CGRect emptyPosition;
		emptyPosition.size = emptySize;
		emptyPosition.origin.x = (self.frame.size.width - emptySize.width) / 2.0;
		emptyPosition.origin.y = (self.frame.size.height - emptySize.height) / 2.0;
		_emptyLabel = [[UILabel alloc] initWithFrame:emptyPosition];
		_emptyLabel.text = emptyText;
		_emptyLabel.font = emptyFont;
		_emptyLabel.backgroundColor = [UIColor clearColor];
		_emptyLabel.textColor = [UIColor whiteColor];
		[self addSubview:_emptyLabel];
	} else {
		[_emptyLabel removeFromSuperview];
		[_emptyLabel release];
		_emptyLabel = nil;
	}
}

- (void)_relayoutViews
{
	NSInteger newCount = [_applications count];
	[_pageControl setNumberOfPages:newCount];
	CGRect bounds = [self bounds];
	[_scrollView setContentSize:CGSizeMake(bounds.size.width * newCount + 1.0f, bounds.size.height)];
	CGRect pageFrame;
	pageFrame.origin.x = 0.0f;
	pageFrame.origin.y = 0.0f;
	pageFrame.size.height = bounds.size.height;
	pageFrame.size.width = bounds.size.width;
	for (PSWSnapshotView *view in _snapshotViews) {
		[view setFrame:pageFrame];
		pageFrame.origin.x += bounds.size.width;
	}
	
	[self _toggleEmptyText];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat pageWidth = [scrollView bounds].size.width;
    NSInteger page = floor(([scrollView contentOffset].x - pageWidth / 2) / pageWidth) + 1.0f;
	if ([_pageControl currentPage] != page) {
		[_pageControl setCurrentPage:page];
		if ([_delegate respondsToSelector:@selector(snapshotPageView:didFocusApplication:)])
			[_delegate snapshotPageView:self didFocusApplication:[self focusedApplication]];		
	}
}

#pragma mark PSWSnapshotViewDelegate

- (void)snapshotViewClosed:(PSWSnapshotView *)snapshot
{
	if ([_delegate respondsToSelector:@selector(snapshotPageView:didCloseApplication:)])
		[_delegate snapshotPageView:self didCloseApplication:[snapshot application]];
}

- (void)snapshotViewTapped:(PSWSnapshotView *)snapshot withCount:(NSInteger)tapCount
{
	if (tapCount == _tapsToActivate) {
		if ([_delegate respondsToSelector:@selector(snapshotPageView:didSelectApplication:)])
			[_delegate snapshotPageView:self didSelectApplication:[snapshot application]];
	}
}

#pragma mark Properties

- (PSWApplication *)focusedApplication
{
	if ([_applications count])
		return [_applications objectAtIndex:[_pageControl currentPage]];
	return nil;
}

- (void)setFocusedApplication:(PSWApplication *)application
{
	[self setFocusedApplication:application animated:YES];
}

- (void)setFocusedApplication:(PSWApplication *)application animated:(BOOL)animated
{
	NSInteger index = [self indexOfApplication:application];
	if (index != NSNotFound && index != [_pageControl currentPage]) {
		CGRect bounds = [self bounds];
		[_pageControl setCurrentPage:index];
		[_scrollView setContentOffset:CGPointMake(bounds.size.width * index, 0.0f) animated:animated];
		if ([_delegate respondsToSelector:@selector(snapshotPageView:didFocusApplication:)])
			[_delegate snapshotPageView:self didFocusApplication:application];
	}
}

- (BOOL)showsTitles
{
	return _showsTitles;
}
- (void)setShowsTitles:(BOOL)showsTitles
{
	if (_showsTitles != showsTitles) {
		_showsTitles = showsTitles;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setShowsTitle:showsTitles];
	}
}

- (BOOL)showsCloseButtons
{
	return _showsCloseButtons;
}
- (void)setShowsCloseButtons:(BOOL)showsCloseButtons
{
	if (_showsCloseButtons != showsCloseButtons) {
		_showsCloseButtons = showsCloseButtons;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setShowsCloseButton:showsCloseButtons];
	}
}

- (BOOL)allowsSwipeToClose
{
	return _showsCloseButtons;
}
- (void)setAllowsSwipeToClose:(BOOL)allowsSwipeToClose
{
	if (_allowsSwipeToClose != allowsSwipeToClose) {
		_allowsSwipeToClose = allowsSwipeToClose;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setAllowsSwipeToClose:allowsSwipeToClose];
	}
}

- (BOOL)showsEmptyText
{
	return _showsCloseButtons;
}
- (void)setShowsEmptyText:(BOOL)showsEmptyText
{
	if (_showsEmptyText != showsEmptyText) {
		_showsEmptyText = showsEmptyText;
		[self _toggleEmptyText];
	}
}

- (CGFloat)roundedCornerRadius
{
	return _roundedCornerRadius;
}
- (void)setRoundedCornerRadius:(CGFloat)roundedCornerRadius
{
	if (_roundedCornerRadius != roundedCornerRadius) {
		_roundedCornerRadius = roundedCornerRadius;
		for (PSWSnapshotView *view in _snapshotViews)
			[view setRoundedCornerRadius:roundedCornerRadius];
	}
}

- (NSInteger)indexOfApplication:(PSWApplication *)application
{
	return [_applications indexOfObject:application];
}


#pragma mark PSWApplicationControllerDelegate

- (void)applicationController:(PSWApplicationController *)ac applicationDidLaunch:(PSWApplication *)application
{
	if (![_applications containsObject:application]) {
		[_applications addObject:application];
		PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:[self bounds] application:application];
		snapshot.delegate = self;
		snapshot.showsTitle = _showsTitles;
		snapshot.showsCloseButton = _showsCloseButtons;
		snapshot.allowsSwipeToClose = _allowsSwipeToClose;
		[_scrollView addSubview:snapshot];
		[_snapshotViews addObject:snapshot];
		[snapshot release];
		[self _relayoutViews];
	}
}

- (void)didRemoveSnapshotView:(NSString *)animationID finished:(NSNumber *)finished context:(PSWSnapshotView *)context
{
	[context removeFromSuperview];
	self.userInteractionEnabled = YES;
}

- (void)applicationController:(PSWApplicationController *)ac applicationDidExit:(PSWApplication *)application
{
	NSInteger index = [_applications indexOfObject:application];
	if (index != NSNotFound) {
		[_applications removeObject:application];
		PSWSnapshotView *snapshot = [_snapshotViews objectAtIndex:index];
		snapshot.delegate = nil;
		[_snapshotViews removeObjectAtIndex:index];
		[UIView beginAnimations:nil context:snapshot];
		[UIView setAnimationDuration:0.5f];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(didRemoveSnapshot:finished:context:)];
		CGRect frame = snapshot.frame;
		frame.origin.y -= frame.size.height;
		snapshot.frame = frame;
		snapshot.alpha = 0.0f;
		[self _relayoutViews];
		[UIView commitAnimations];
	}
}

@end
