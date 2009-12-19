#import "PSWSnapshotPageView.h"
#import <QuartzCore/QuartzCore.h>
#import <CaptainHook/CaptainHook.h>

@interface PSWSnapshotPageView ()
- (void)_relayoutViews;
@end

@implementation PSWSnapshotPageView
@synthesize delegate = _delegate;
@synthesize scrollView = _scrollView;
@synthesize tapsToActivate = _tapsToActivate;

#pragma mark Public Methods

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;
{
	if ((self = [super initWithFrame:frame])) {
		_unfocusedAlpha = 1.0f;
		[self setUserInteractionEnabled:YES];
		_applicationController = [applicationController retain];
		[applicationController setDelegate:self];
		_applications = [[applicationController activeApplications] mutableCopy];
		NSUInteger numberOfPages = [_applications count];
		
		_pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 17.0f, frame.size.width, 17.0f)];
		[_pageControl setNumberOfPages:numberOfPages];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[self addSubview:_pageControl];
		
		_scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
		[_scrollView setClipsToBounds:NO];
		[_scrollView setPagingEnabled:YES];
		[_scrollView setShowsHorizontalScrollIndicator:NO];
		[_scrollView setShowsVerticalScrollIndicator:NO];
		[_scrollView setScrollsToTop:NO];
		[_scrollView setDelegate:self];
		[_scrollView setBackgroundColor:[UIColor clearColor]];

		_snapshotViews = [[NSMutableArray alloc] init];
		for (int i = 0; i < numberOfPages; i++) {
			PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:CGRectZero application:[_applications objectAtIndex:i]];
			snapshot.delegate = self;
			[_scrollView addSubview:snapshot];
			[_snapshotViews addObject:snapshot];
			[snapshot release];
		}
		if (numberOfPages != 0)
			[[_snapshotViews objectAtIndex:0] setFocused:YES animated:NO];
		[self addSubview:_scrollView];

		[self setBackgroundColor:[UIColor clearColor]];
		[self setClipsToBounds:NO];
		[self _relayoutViews];
	}
	return self;
}

- (void)dealloc
{
	[_applicationController setDelegate:nil];
	[_applicationController release];
	[_emptyText release];
	[_emptyLabel release];
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

- (void)_applyEmptyText
{
	if ([_emptyText length] != 0 && [_applications count] == 0) {
		if (!_emptyLabel) {
			UIFont *font = [UIFont boldSystemFontOfSize:16.0f];
			CGFloat height = [_emptyText sizeWithFont:font].height;
			CGRect bounds = [self bounds];
			bounds.origin.x = 0.0f;
			bounds.origin.y = (NSInteger)((bounds.size.height - height) / 2.0f);
			bounds.size.height = height;
			_emptyLabel = [[UILabel alloc] initWithFrame:bounds];
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
}

- (void)_relayoutViews
{
	CGRect bounds = [self frame];
	bounds.origin.x = 0.0f;
	bounds.origin.y = 0.0f;
	
	CGRect scrollViewFrame;
	scrollViewFrame.origin.x = _snapshotInset;
	scrollViewFrame.origin.y = 0.0;
	scrollViewFrame.size.width = bounds.size.width - (_snapshotInset + _snapshotInset);
	scrollViewFrame.size.height = bounds.size.height - 17.0f;
	[_scrollView.layer setTransform:CATransform3DIdentity];
	[_scrollView setFrame:scrollViewFrame];
	
	NSInteger appCount = [_applications count];
	[_pageControl setNumberOfPages:appCount];
	[_scrollView setContentSize:CGSizeMake(scrollViewFrame.size.width * appCount + 1.0f, scrollViewFrame.size.height)];
	scrollViewFrame.origin.x = 0.0f;
	PSWApplication *focusedApplication = [self focusedApplication];
	for (PSWSnapshotView *view in _snapshotViews) {
		[view setFrame:scrollViewFrame];
		scrollViewFrame.origin.x += scrollViewFrame.size.width;
		if (focusedApplication != [view application])
			[view setAlpha:_unfocusedAlpha];
	}
	
	[self _applyEmptyText];
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
	NSInteger oldIndex = [_pageControl currentPage];
	if (index != NSNotFound && index != oldIndex) {
		[_scrollView setContentOffset:CGPointMake(_scrollView.bounds.size.width * index, 0.0f) animated:animated];
		if (!animated)
			[self scrollViewDidScroll:_scrollView];
	}
}

- (PSWSnapshotView *)_focusedSnapshotView
{
	if ([_applications count])
		return [_snapshotViews objectAtIndex:[_pageControl currentPage]];
	return nil;
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

- (CGFloat)snapshotPageInset
{
	return _snapshotInset;
}
- (void)setSnapshotPageInset:(CGFloat)snapshotInset
{
	if (_snapshotInset != snapshotInset) {
		_snapshotInset = snapshotInset;
		[self _relayoutViews];
	}
}

- (NSString *)emptyText
{
	return _emptyText;
}
- (void)setEmptyText:(NSString *)emptyText
{
	if (_emptyText != emptyText) {
		if (![_emptyText isEqualToString:_emptyText]) {
			[_emptyText autorelease];
			_emptyText = [emptyText copy];
			[self _applyEmptyText];
		}
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
			[view setRoundedCornerRadius:_roundedCornerRadius];
	}
}

- (CGFloat)snapshotInset
{
	return _snapshotInset;
}
- (void)setSnapshotInset:(CGFloat)snapshotInset
{
	if (_snapshotInset != snapshotInset) {
		_snapshotInset = snapshotInset;
		[self _relayoutViews];
	}
}

- (CGFloat)unfocusedAlpha
{
	return _unfocusedAlpha;
}
- (void)setUnfocusedAlpha:(CGFloat)unfocusedAlpha
{
	if (_unfocusedAlpha != unfocusedAlpha) {
		_unfocusedAlpha = unfocusedAlpha;
		[self _relayoutViews];
	}
}

- (NSInteger)indexOfApplication:(PSWApplication *)application
{
	return [_applications indexOfObject:application];
}

- (void)setFrame:(CGRect)frame
{
	if (!CGRectEqualToRect([self frame], frame)) {
		[super setFrame:frame];
		frame.origin.x = 0.0f;
		frame.origin.y = frame.size.height - 17.0f;
		frame.size.height = 17.0f;
		[_pageControl setFrame:frame];
		[self _relayoutViews];
	}
}

- (BOOL)showsPageControl
{
	return _pageControl.hidden;
}

- (void)setShowsPageControl:(BOOL)showsPageControl
{
	_pageControl.hidden = showsPageControl;
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	CGFloat pageWidth = [scrollView bounds].size.width;
	NSInteger page = floor(([scrollView contentOffset].x - pageWidth / 2) / pageWidth) + 1.0f;
	NSInteger oldPage = [_pageControl currentPage];
	if (oldPage != page && page < [_snapshotViews count]) {
		PSWSnapshotView *oldView = [_snapshotViews objectAtIndex:oldPage];
		PSWSnapshotView *newView = [_snapshotViews objectAtIndex:page];
		[oldView setFocused:NO];
		[newView setFocused:YES];
		if (_unfocusedAlpha != 1.0f) {
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.33f];
			[oldView setAlpha:_unfocusedAlpha];
			[newView setAlpha:1.0f];
			[UIView commitAnimations];
		}
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
	PSWApplication *tappedApp = [snapshot application];
	if (tappedApp == [self focusedApplication]) {
		if (tapCount == _tapsToActivate) {
			if ([_delegate respondsToSelector:@selector(snapshotPageView:didSelectApplication:)])
				[_delegate snapshotPageView:self didSelectApplication:[self focusedApplication]];	
		}
	} else {
		[self setFocusedApplication:tappedApp];
	}
}

- (void)snapshotViewDidSwipeOut:(PSWSnapshotView *)snapshot
{
	if ([_delegate respondsToSelector:@selector(snapshotPageViewShouldExit:)])
		[_delegate snapshotPageViewShouldExit:self];
}

#pragma mark PSWApplicationControllerDelegate

- (void)applicationController:(PSWApplicationController *)ac applicationDidLaunch:(PSWApplication *)application
{
	if (![_applications containsObject:application]) {
		[_applications addObject:application];
		CGRect frame = [_scrollView bounds];
		PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:frame application:application];
		snapshot.delegate = self;
		snapshot.showsTitle = _showsTitles;
		snapshot.showsCloseButton = _showsCloseButtons;
		snapshot.allowsSwipeToClose = _allowsSwipeToClose;
		snapshot.roundedCornerRadius = _roundedCornerRadius;
		if ([_snapshotViews count] == 0)
			[snapshot setFocused:YES animated:NO];
		else
			[snapshot setAlpha:_unfocusedAlpha];
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
		[UIView setAnimationDuration:0.33f];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(didRemoveSnapshot:finished:context:)];
		CGRect frame = snapshot.frame;
		frame.origin.y -= frame.size.height;
		snapshot.frame = frame;
		snapshot.alpha = 0.0f;
		[self _relayoutViews];
		PSWSnapshotView *focusedView = [self _focusedSnapshotView];
		[focusedView setFocused:YES];
		[focusedView setAlpha:1.0f];
		[UIView commitAnimations];
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSInteger currentPage = [_pageControl currentPage];
	UITouch *touch = [touches anyObject];
	NSInteger tapCount = [touch tapCount];
	CGPoint point = [touch locationInView:self];
	if (point.x < [self bounds].size.width / 2.0f) {
		if (tapCount == 2)
			[self setFocusedApplication:[_applications objectAtIndex:0]];
		else if (currentPage > 0)
			[self setFocusedApplication:[_applications objectAtIndex:currentPage - 1]];
	} else {
		if (tapCount == 2)
			[self setFocusedApplication:[_applications lastObject]];
		else if (currentPage < [_applications count] - 1)
			[self setFocusedApplication:[_applications objectAtIndex:currentPage + 1]];
	}
	[super touchesEnded:touches	withEvent:event];
}

@end
