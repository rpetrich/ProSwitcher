#import <QuartzCore/QuartzCore.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWPageView.h"
#import "PSWApplicationController.h"
#import "PSWSnapshotView.h"


@implementation PSWPageView
@synthesize pageViewDelegate = _pageViewDelegate;
@synthesize tapsToActivate = _tapsToActivate;
@synthesize applications = _applications;

#pragma mark Public Methods

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;
{
	if ((self = [super initWithFrame:frame])) {
		_unfocusedAlpha = 1.0f;
		
		_applicationController = [applicationController retain];
		[applicationController setDelegate:self];
		_applications = [[applicationController activeApplications] mutableCopy];
		
		[self setClipsToBounds:NO];
		[self setShowsHorizontalScrollIndicator:NO];
		[self setShowsVerticalScrollIndicator:NO];
		[self setScrollsToTop:NO];
		[self setDelegate:self];
		[self setAlwaysBounceVertical:NO];
		[self setAlwaysBounceHorizontal:YES];
		[self setScrollEnabled:YES];
		[self setUserInteractionEnabled:YES];

		_snapshotViews = [[NSMutableArray alloc] init];
		for (int i = 0; i < [self.applications count]; i++) {
			PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:CGRectZero application:[_applications objectAtIndex:i]];
			snapshot.delegate = self;
			[self addSubview:snapshot];
			[_snapshotViews addObject:snapshot];
			[snapshot release];
		}
		
		if ([self.applications count] != 0)
			[[_snapshotViews objectAtIndex:0] setFocused:YES animated:NO];
		
		[self layoutSubviews];
		
		[self noteApplicationCountChanged];
	}
	return self;
}

- (void)dealloc
{
	[_applicationController setDelegate:nil];
	[_applicationController release];
	[_snapshotViews release];
	[_applications release];
	[_ignoredDisplayIdentifiers release];
	
	[super dealloc];
}

- (NSArray *)snapshotViews
{
	return [[_snapshotViews copy] autorelease];
}

#pragma mark Private Methods

- (void)unZoom
{
	for (PSWSnapshotView *view in _snapshotViews)
		[view setZoomed:NO];
}

- (void)zoomActiveWithAnimation:(BOOL)animated
{
	PSWSnapshotView *activeView;
	NSInteger currentPage = [self currentPage];
	if (_snapshotViews.count > 0 && (currentPage == 0 || currentPage == [_applications count] - 1)) {
		activeView = [_snapshotViews objectAtIndex:currentPage];
	} else {
		activeView = nil;
	}
	for (PSWSnapshotView *view in _snapshotViews)
		[view setZoomed:activeView == view animated:animated];
}

- (void)layoutSubviews
{
	for (PSWSnapshotView *view in _snapshotViews)
		[view layoutSubviews];
	
	[self.layer setTransform:CATransform3DIdentity];
	
	[self zoomActiveWithAnimation:NO];
	
	PSWApplication *focusedApplication = [self focusedApplication];
	CGRect frame = [self bounds];
	for (PSWSnapshotView *view in _snapshotViews) {
		[view setFrame:frame];
		
		if ([view application] != focusedApplication)
			[view setAlpha:_unfocusedAlpha];
			
		[view reloadSnapshot];
		
		frame.origin.x += frame.size.width;
	}
}

- (PSWSnapshotView *)focusedSnapshotView
{
	if ([_applications count])
		return [_snapshotViews objectAtIndex:[self currentPage]];
	return nil;
}

- (void)addViewForApplication:(PSWApplication *)application
{
	[self addViewForApplication:application atPosition:[_applications count]];
}

- (void)addViewForApplication:(PSWApplication *)application atPosition:(NSUInteger)position
{
	if (application && ![_applications containsObject:application]) {
		[_applications insertObject:application atIndex:position];
		
		PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:[self bounds] application:application];
		snapshot.delegate = self;
		snapshot.showsTitle = _showsTitles;
		snapshot.showsBadge = _showsBadges;
		snapshot.allowsZoom = _allowsZoom;
		snapshot.showsCloseButton = _showsCloseButtons;
		snapshot.allowsSwipeToClose = _allowsSwipeToClose;
		snapshot.roundedCornerRadius = _roundedCornerRadius;
		
		if ([_snapshotViews count] == 0)
			[snapshot setFocused:YES animated:NO];
		else
			[snapshot setAlpha:_unfocusedAlpha];
		
		[self addSubview:snapshot];
		[_snapshotViews insertObject:snapshot atIndex:position];
		[snapshot release];
		
		[self noteApplicationCountChanged];
		[self layoutSubviews];
	}
}

- (void)didRemoveSnapshotView:(NSString *)animationID finished:(NSNumber *)finished context:(PSWSnapshotView *)context
{
	[context removeFromSuperview];
}

- (void)removeViewForApplication:(PSWApplication *)application animated:(BOOL)animated
{
	if (!application)
		return;
		
	NSInteger index = [_applications indexOfObject:application];
	if (index != NSNotFound) {
		[_applications removeObject:application];
		PSWSnapshotView *snapshot = [_snapshotViews objectAtIndex:index];
		snapshot.delegate = nil;
		[_snapshotViews removeObjectAtIndex:index];
		
		if (animated) {
			[UIView beginAnimations:nil context:snapshot];
			[UIView setAnimationDuration:0.33f];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(didRemoveSnapshot:finished:context:)];
		}
		
		CGRect frame = snapshot.frame;
		frame.origin.y -= frame.size.height;
		snapshot.frame = frame;
		snapshot.alpha = 0.0f;
		
		[self noteApplicationCountChanged];
		[self layoutSubviews];
		
		PSWSnapshotView *focusedView = [self focusedSnapshotView];
		[focusedView setFocused:YES];
		[focusedView setAlpha:1.0f];
		
		if (animated) {
			[UIView commitAnimations];
		} else {
			[self didRemoveSnapshotView:nil finished:nil context:snapshot];
		}
	}
}

- (void)removeViewForApplication:(PSWApplication *)application
{
	[self removeViewForApplication:application animated:YES];
}

#pragma mark Properties

- (PSWApplication *)focusedApplication
{
	if ([_applications count])
		return [_applications objectAtIndex:[self currentPage]];
	return nil;
}

- (void)setFocusedApplication:(PSWApplication *)application
{
	[self setFocusedApplication:application animated:YES];
}

- (void)setFocusedApplication:(PSWApplication *)application animated:(BOOL)animated
{
	NSInteger index = [self indexOfApplication:application];
	NSInteger oldIndex = [self currentPage];
	if (index != NSNotFound && index != oldIndex) {
		[self setContentOffset:CGPointMake(self.bounds.size.width * index, 0.0f) animated:animated];
		if (!animated)
			[self scrollViewDidScroll:self];
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

- (BOOL)themedIcons
{
	return _themedIcons;
}
- (void)setThemedIcons:(BOOL)themedIcons
{
	_themedIcons = themedIcons;
	for (PSWSnapshotView *view in _snapshotViews)
		[view setThemedIcon:themedIcons];
}

- (BOOL)showsCloseButtons
{
	return _showsCloseButtons;
}
- (void)setShowsCloseButtons:(BOOL)showsCloseButtons
{
	_showsCloseButtons = showsCloseButtons;
	for (PSWSnapshotView *view in _snapshotViews)
		[view setShowsCloseButton:_showsCloseButtons];
}

- (BOOL)showsBadges
{
	return _showsBadges;
}
- (void)setShowsBadges:(BOOL)showsBadges
{
	_showsBadges = showsBadges;
	for (PSWSnapshotView *view in _snapshotViews)
		[view setShowsBadge:showsBadges];
}

- (BOOL)allowsSwipeToClose
{
	return _allowsSwipeToClose;
}
- (void)setAllowsSwipeToClose:(BOOL)allowsSwipeToClose
{
	if (_allowsSwipeToClose != allowsSwipeToClose) {
		_allowsSwipeToClose = allowsSwipeToClose;
		
		for (PSWSnapshotView *view in _snapshotViews)
			[view setAllowsSwipeToClose:allowsSwipeToClose];
	}
}

- (BOOL)allowsZoom
{
	return _allowsZoom;
}
- (void)setAllowsZoom:(BOOL)allowsZoom
{
	if (_allowsZoom != allowsZoom) {
		_allowsZoom = allowsZoom;
		
		for (PSWSnapshotView *view in _snapshotViews)
			[view setAllowsZoom:allowsZoom];
			
		if (!_allowsZoom)
			[self unZoom];
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
		[self layoutSubviews];
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
		[self layoutSubviews];
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
		[self layoutSubviews];
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
		[self layoutSubviews];
	}
}

- (NSArray *)ignoredDisplayIdentifiers
{
	return _ignoredDisplayIdentifiers;
}
- (void)setIgnoredDisplayIdentifiers:(NSArray *)ignoredDisplayIdentifiers
{
	if (_ignoredDisplayIdentifiers != ignoredDisplayIdentifiers) {
		PSWApplicationController *ac = [PSWApplicationController sharedInstance];
		for (NSString *displayIdentifier in _ignoredDisplayIdentifiers) {
			if (![ignoredDisplayIdentifiers containsObject:displayIdentifier]) {
				if ([displayIdentifier isEqualToString:@"com.apple.springboard"])
					[self addViewForApplication:[ac applicationWithDisplayIdentifier:displayIdentifier] atPosition:0];
				else
					[self addViewForApplication:[ac applicationWithDisplayIdentifier:displayIdentifier]];
			}
		}
		
		[_ignoredDisplayIdentifiers release];
		_ignoredDisplayIdentifiers = [ignoredDisplayIdentifiers copy];
		for (NSString *displayIdentifier in _ignoredDisplayIdentifiers)
			[self removeViewForApplication:[ac applicationWithDisplayIdentifier:displayIdentifier] animated:NO];
	}
}

- (NSInteger)currentPage
{
	return _currentPage;
}

- (void)setCurrentPage:(NSInteger)page
{
	_currentPage = page;
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	CGFloat pageWidth = [scrollView bounds].size.width;
	NSInteger curPage = floor(([scrollView contentOffset].x - pageWidth / 2) / pageWidth) + 1.0f;
	NSInteger oldPage = [self currentPage];
	
	NSUInteger appCount = [_applications count];
	if (oldPage != curPage && curPage < appCount && curPage >= 0) {
		PSWSnapshotView *oldView = (oldPage < appCount) ? [_snapshotViews objectAtIndex:oldPage] : nil;
		PSWSnapshotView *newView = [_snapshotViews objectAtIndex:curPage];
		
		[oldView setFocused:NO ];
		[newView setFocused:YES];
		
		if (_unfocusedAlpha != 1.0f) {
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.33f];
			
			[oldView setAlpha:_unfocusedAlpha];
			[newView setAlpha:1.0f           ];
			
			[UIView commitAnimations];
		}
		
		[self setCurrentPage:curPage];
		[self zoomActiveWithAnimation:YES];
		
		if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageView:didFocusApplication:)])
			[_pageViewDelegate snapshotPageView:self didFocusApplication:[self focusedApplication]];
	}
}

#pragma mark PSWSnapshotViewDelegate

- (void)snapshotViewClosed:(PSWSnapshotView *)snapshot
{
	if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageView:didCloseApplication:)])
		[_pageViewDelegate snapshotPageView:self didCloseApplication:[snapshot application]];
}

- (void)snapshotViewTapped:(PSWSnapshotView *)snapshot withCount:(NSInteger)tapCount
{
	PSWApplication *tappedApp = [snapshot application];
	if (tappedApp == [self focusedApplication]) {
		if (tapCount == _tapsToActivate) {
			if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageView:didSelectApplication:)])
				[_pageViewDelegate snapshotPageView:self didSelectApplication:[self focusedApplication]];	
		}
	} else {
		[self setFocusedApplication:tappedApp];
	}
}

- (void)snapshotViewDidSwipeOut:(PSWSnapshotView *)snapshot
{
	[self shouldExit];
}

- (void)updateContentSize
{
	[self setContentSize:CGSizeMake(self.frame.size.width * [self.applications count], self.frame.size.height)];
}

- (void)shouldExit
{
	[_pageViewDelegate respondsToSelector:@selector(snapshotPageViewShouldExit:)];
	[_pageViewDelegate snapshotPageViewShouldExit:self];
}

- (void)noteApplicationCountChanged
{
	//[self.containerView setPageControlCount:[self.applications count]];
	[self updateContentSize];
}

#pragma mark PSWApplicationControllerDelegate

- (void)applicationController:(PSWApplicationController *)ac applicationDidLaunch:(PSWApplication *)application
{
	if (![_ignoredDisplayIdentifiers containsObject:[application displayIdentifier]])
		[self addViewForApplication:application];
}

- (void)applicationController:(PSWApplicationController *)ac applicationDidExit:(PSWApplication *)application
{
	[self removeViewForApplication:application];
}

#pragma mark Touch Gestures

- (void)movePrevious
{
	CGPoint offset = [self contentOffset];
	offset.x -= [self bounds].size.width;
	if (offset.x < 0.0f)
		offset.x = 0.0f;
	[self setContentOffset:offset animated:YES];
}

- (void)moveNext
{
	CGFloat width = [self bounds].size.width;
	CGFloat maxOffset = [self contentSize].width - width;
	if (maxOffset > 0) {
		CGPoint offset = [self contentOffset];
		offset.x += width;
		if (offset.x > maxOffset)
			offset.x = maxOffset;
		[self setContentOffset:offset animated:YES];
	}
}

- (void)moveToStart
{
	[self setContentOffset:CGPointZero animated:YES];
}

- (void)moveToEnd
{
	CGSize size = [self bounds].size;
	CGSize contentSize = [self contentSize];
	
	CGPoint offset = CGPointMake(contentSize.width - size.width, 0);
	[self setContentOffset:offset animated:YES];
}

@end
