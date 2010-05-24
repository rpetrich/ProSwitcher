#import <QuartzCore/QuartzCore.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWPageView.h"
#import "PSWApplicationController.h"
#import "PSWSnapshotView.h"


@implementation PSWPageView
@synthesize pageViewDelegate = _pageViewDelegate;
@synthesize tapsToActivate = _tapsToActivate;
@synthesize doubleTapped = _doubleTapped;
@synthesize applications = _applications;

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
		
		_pageControl = [[UIPageControl alloc] initWithFrame:CGRectZero];
		[_pageControl setNumberOfPages:numberOfPages];
		[_pageControl setCurrentPage:0];
		[_pageControl setHidesForSinglePage:YES];
		[_pageControl setUserInteractionEnabled:NO];
		[self addSubview:_pageControl];
		
		[self setClipsToBounds:NO];
		[self setShowsHorizontalScrollIndicator:NO];
		[self setShowsVerticalScrollIndicator:NO];
		[self setScrollsToTop:NO];
		[self setDelegate:self];
		[self setBackgroundColor:[UIColor clearColor]];
		[self setAlwaysBounceVertical:NO];
		[self setAlwaysBounceHorizontal:YES];

		_snapshotViews = [[NSMutableArray alloc] init];
		for (int i = 0; i < numberOfPages; i++) {
			PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:CGRectZero application:[_applications objectAtIndex:i]];
			snapshot.delegate = self;
			[self addSubview:snapshot];
			[_snapshotViews addObject:snapshot];
			[snapshot release];
		}
		if (numberOfPages != 0)
			[[_snapshotViews objectAtIndex:0] setFocused:YES animated:NO];
		
		[self setBackgroundColor:[UIColor clearColor]];
		[self setClipsToBounds:NO];
		[self layoutSubviews];
	}
	return self;
}

- (void)dealloc
{
	[_applicationController setDelegate:nil];
	[_applicationController release];
	[_emptyText release];
	[_emptyLabel release];
	[_pageControl release];
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
	NSInteger currentPage = [_pageControl currentPage];
	if (_snapshotViews.count > 0 && (!self.doubleTapped || currentPage == 0 || currentPage == [_applications count] - 1)) {
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
	
	CGRect bounds = [self frame];
	bounds.origin.x = 0.0f;
	bounds.origin.y = 0.0f;
	
	NSUInteger appCount = [_applications count];
	
	[self.layer setTransform:CATransform3DIdentity];
	
	CGRect scrollViewFrame;
	scrollViewFrame.origin.x = _snapshotInset;
	scrollViewFrame.origin.y = 0.0;
	scrollViewFrame.size.width = bounds.size.width - (_snapshotInset + _snapshotInset);
	scrollViewFrame.size.height = bounds.size.height - 17.0f;
	[self setContentSize:CGSizeMake(scrollViewFrame.size.width * appCount, scrollViewFrame.size.height)];
	//[self setFrame:scrollViewFrame];
	
	[_pageControl setFrame:CGRectMake(0.0f, self.frame.size.height - 19.0f, self.frame.size.width, 19.0f)];
	[_pageControl setNumberOfPages:[_applications count]];
	
	_pageControl.hidden = !_showsPageControl;
	[self zoomActiveWithAnimation:NO];
	PSWApplication *focusedApplication = [self focusedApplication];
	scrollViewFrame.origin.x = 0;
	for (PSWSnapshotView *view in _snapshotViews) {
		[view setFrame:scrollViewFrame];
		scrollViewFrame.origin.x += scrollViewFrame.size.width;
		if (focusedApplication != [view application])
			[view setAlpha:_unfocusedAlpha];
		[view reloadSnapshot];
	}
	
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
}

- (PSWSnapshotView *)focusedSnapshotView
{
	if ([_applications count])
		return [_snapshotViews objectAtIndex:[_pageControl currentPage]];
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
		CGRect frame = [self bounds];
		PSWSnapshotView *snapshot = [[PSWSnapshotView alloc] initWithFrame:frame application:application];
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

- (BOOL)autoExit
{
	return _autoExit;
}
- (void)setAutoExit:(BOOL)autoExit
{
	if (_autoExit != autoExit) {
		_autoExit = autoExit;
		[self layoutSubviews];
	}
}

- (BOOL)emptyTapClose
{
	return _emptyTapClose;
}
- (void)setEmptyTapClose:(BOOL)emptyTapClose
{
	if (_emptyTapClose != emptyTapClose) {
		_emptyTapClose = emptyTapClose;
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
			[self layoutSubviews];
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
		frame.origin.x = 0.0f;
		frame.origin.y = frame.size.height - 17.0f;
		frame.size.height = 17.0f;
		[_pageControl setFrame:frame];
		[self layoutSubviews];
	}
}

- (BOOL)showsPageControl
{
	return _showsPageControl;
}
- (void)setShowsPageControl:(BOOL)showsPageControl
{
	_showsPageControl = showsPageControl;
	[self layoutSubviews];
}

- (NSArray *)ignoredDisplayIdentifiers
{
	return _ignoredDisplayIdentifiers;
}
- (void)setIgnoredDisplayIdentifiers:(NSArray *)ignoredDisplayIdentifiers
{
	if (_ignoredDisplayIdentifiers != ignoredDisplayIdentifiers) {
		PSWApplicationController *ac = [PSWApplicationController sharedInstance];
		for (NSString *displayIdentifier in _ignoredDisplayIdentifiers)
			if (![ignoredDisplayIdentifiers containsObject:displayIdentifier]) {
				if ([displayIdentifier isEqualToString:@"com.apple.springboard"])
					[self addViewForApplication:[ac applicationWithDisplayIdentifier:displayIdentifier] atPosition:0];
				else
					[self addViewForApplication:[ac applicationWithDisplayIdentifier:displayIdentifier]];
			}
		[_ignoredDisplayIdentifiers release];
		_ignoredDisplayIdentifiers = [ignoredDisplayIdentifiers copy];
		for (NSString *displayIdentifier in _ignoredDisplayIdentifiers)
			[self removeViewForApplication:[ac applicationWithDisplayIdentifier:displayIdentifier] animated:NO];
	}
}

- (BOOL)isPagingEnabled
{
	return [self isPagingEnabled];
}
- (void)setPagingEnabled:(BOOL)pagingEnabled
{
	[self setPagingEnabled:pagingEnabled];
}

#pragma mark UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	CGFloat pageWidth = [scrollView bounds].size.width;
	NSInteger curPage = floor(([scrollView contentOffset].x - pageWidth / 2) / pageWidth) + 1.0f;
	NSInteger oldPage = [_pageControl currentPage];
	
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
		
		[_pageControl setCurrentPage:curPage];
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
	if ([_pageViewDelegate respondsToSelector:@selector(snapshotPageViewShouldExit:)])
		[_pageViewDelegate snapshotPageViewShouldExit:self];
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

- (void)tapPreviousAndContinue
{
	CGPoint offset = [self contentOffset];
	offset.x -= [self bounds].size.width;
	if (offset.x < 0.0f)
		offset.x = 0.0f;
	[self setContentOffset:offset animated:YES];
	[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.5f];
	_shouldScrollOnUp = NO;
}

- (void)tapNextAndContinue
{
	CGFloat width = [self bounds].size.width;
	CGFloat maxOffset = [self contentSize].width - width;
	if (maxOffset > 0) {
		CGPoint offset = [self contentOffset];
		offset.x += width;
		if (offset.x > maxOffset)
			offset.x = maxOffset;
		[self setContentOffset:offset animated:YES];
		[self performSelector:@selector(tapNextAndContinue) withObject:nil afterDelay:0.5f];
	}
	_shouldScrollOnUp = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{	
	if ([_applications count] == 0 && [_pageViewDelegate respondsToSelector:@selector(snapshotPageViewShouldExit:)]) {
		[_pageViewDelegate snapshotPageViewShouldExit:self];	
	}
	
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:[self superview]];
	CGPoint offset = [self frame].origin;

	point.x -= offset.x;
	if (point.x <= 0.0f) {
		[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.1f];
	} else if (point.x > [self bounds].size.width) {
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
	UITouch *touch = [touches anyObject];
	NSInteger tapCount = [touch tapCount];
	CGPoint point = [touch locationInView:[self superview]];
	point.x -= [self frame].origin.x;
	_doubleTapped = NO;
	if (tapCount == 2) {
		_doubleTapped = YES;
		if (point.x <= 0.0f) {
			[self setContentOffset:CGPointZero animated:YES];
		} else {
			CGSize size = [self bounds].size;
			if (point.x > size.width) {
				CGPoint offset;
				CGSize contentSize = [self contentSize];
				offset.x = (size.width < contentSize.width) ? contentSize.width - size.width : 0.0f;
				offset.y = (size.height < contentSize.height) ? contentSize.height - size.height : 0.0f;
				[self setContentOffset:offset animated:YES];
			}
		}
	} else if(_shouldScrollOnUp) {
		if (point.x <= 0.0f) {
			[self tapPreviousAndContinue];
		} else if (point.x > [self bounds].size.width) {
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
