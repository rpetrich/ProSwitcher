#import <QuartzCore/QuartzCore.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWPageView.h"
#import "PSWApplicationController.h"
#import "PSWSnapshotView.h"


@interface PSWPageView ()
- (void)layoutPages;
@end

@implementation PSWPageView
@synthesize pageViewDelegate = _pageViewDelegate;
@synthesize applications = _applications;

#pragma mark Public Methods

- (id)initWithFrame:(CGRect)frame applicationController:(PSWApplicationController *)applicationController;
{
	if ((self = [super initWithFrame:frame])) {		
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
		[self setPagingEnabled:YES];

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
		
		[self layoutPages];
		
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
	PSWSnapshotView *activeView = [self focusedSnapshotView];
	for (PSWSnapshotView *view in _snapshotViews)
		[view setZoomed:(activeView == view) animated:animated];
}

- (void)layoutPages
{
	[self zoomActiveWithAnimation:NO];
	
	PSWApplication *focusedApplication = [self focusedApplication];
	CGRect frame;
	frame.origin.x = 0.0f;
	frame.origin.y = 0.0f;
	frame.size = [self bounds].size;
	
	for (PSWSnapshotView *view in _snapshotViews) {
		[view setFrame:frame];
		
		if ([view application] != focusedApplication)
			[view setAlpha:GetPreference(PSWUnfocusedAlpha, BOOL)];
			
		frame.origin.x += frame.size.width;
	}
}

- (PSWSnapshotView *)focusedSnapshotView
{
	NSUInteger currentPage = [self currentPage];
	if ([_applications count] > currentPage)
		return [_snapshotViews objectAtIndex:currentPage];
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
		
		if ([_snapshotViews count] == 0)
			[snapshot setFocused:YES animated:NO];
		else
			[snapshot setAlpha:GetPreference(PSWUnfocusedAlpha, BOOL)];
		
		[self addSubview:snapshot];
		[_snapshotViews insertObject:snapshot atIndex:position];
		[snapshot release];
		
		[self noteApplicationCountChanged];
		[self layoutPages];
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
		[self layoutPages];
		
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
	NSUInteger currentPage = [self currentPage];
	if ([_applications count] > currentPage)
		return [_applications objectAtIndex:currentPage];
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

- (NSInteger)indexOfApplication:(PSWApplication *)application
{
	return [_applications indexOfObject:application];
}

- (void)setFrame:(CGRect)frame
{
	if (!CGRectEqualToRect([self frame], frame)) {
		[super setFrame:frame];
		[self updateContentSize];
		[self layoutPages];
	}
}

- (void)setBounds:(CGRect)bounds
{
	if (!CGRectEqualToRect([self bounds], bounds)) {
		[super setBounds:bounds];
		[self updateContentSize];
		[self layoutPages];
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
	
	if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageView:didChangeToPage:)])
		[_pageViewDelegate snapshotPageView:self didChangeToPage:page];
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
		
		if (GetPreference(PSWUnfocusedAlpha, BOOL) != 1.0f) {
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.33f];
			
			[oldView setAlpha:GetPreference(PSWUnfocusedAlpha, BOOL)];
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
		if (tapCount == GetPreference(PSWTapsToActivate, NSInteger)) {
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
	CGSize size = [self bounds].size;
	[self setContentSize:CGSizeMake(size.width * [_applications count], size.height - 1.0f)];
}

- (void)shouldExit
{
	if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageViewShouldExit:)])
		[_pageViewDelegate snapshotPageViewShouldExit:self];
}

- (void)noteApplicationCountChanged
{
	[self updateContentSize];
	
	if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageView:pageCountDidChange:)])
		[_pageViewDelegate snapshotPageView:self pageCountDidChange:[_applications count]];
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

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesBegan:touches withEvent:event];
	[self.nextResponder touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesMoved:touches withEvent:event];
	[self.nextResponder touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesEnded:touches withEvent:event];
	[self.nextResponder touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[super touchesCancelled:touches withEvent:event];
	[self.nextResponder touchesCancelled:touches withEvent:event];
}

@end
