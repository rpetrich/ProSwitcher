#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBAwayController.h>
#import <CaptainHook/CaptainHook.h>

#include <dlfcn.h>

#import "PSWController.h"
#import "PSWDisplayStacks.h"
#import "PSWPreferences.h"
#import "PSWResources.h"
#import "SpringBoard+Backgrounder.h"
#import "SBUIController+CategoriesSB.h"
#import "PSWProSwitcherIcon.h"
#import "PSWContainerView.h"
#import "PSWPageView.h"

// Using late binding until we get a simulator build for libactivator :(
CHDeclareClass(LAActivator);
CHDeclareClass(LAEvent);

CHDeclareClass(SBAwayController);
CHDeclareClass(SBStatusBarController);
CHDeclareClass(SBApplication);
CHDeclareClass(SBDisplayStack);
CHDeclareClass(SpringBoard);
CHDeclareClass(SBIconListPageControl);
CHDeclareClass(SBUIController);
CHDeclareClass(SBApplicationController);
CHDeclareClass(SBIconModel);
CHDeclareClass(SBIconController);
CHDeclareClass(SBZoomView);
CHDeclareClass(SBStatusBar);
CHDeclareClass(SBSearchView);
CHDeclareClass(SBVoiceControlAlert);
CHDeclareClass(SBApplicationIcon);

#define SBActive ([SBWActiveDisplayStack topApplication] == nil)
#define SBSharedInstance ((SpringBoard *) [UIApplication sharedApplication])

static NSUInteger disallowIconListScatter;
static NSUInteger disallowRestoreIconList;
static NSUInteger disallowIconListScroll;
static NSUInteger modifyZoomTransformCountDown;
static NSUInteger ignoreZoomSetAlphaCountDown;

static NSString *displayIdentifierToSuppressBackgroundingOn;

void PSWSuppressBackgroundingOnDisplayIdentifer(NSString *displayIdentifier)
{
	[displayIdentifierToSuppressBackgroundingOn release];
	displayIdentifierToSuppressBackgroundingOn = [displayIdentifier copy];
}

@interface PSWController () <PSWPageViewDelegate, LAListener>
- (void)reparentView;
- (void)reloadPreferences;
- (void)applyPreferences;
- (void)fixPageControl;
@end

static PSWController *sharedController;	

@implementation PSWController
@synthesize snapshotPageView, containerView;

+ (PSWController *)sharedController
{
	return sharedController;
}

#pragma mark stuff

- (id)init
{
	if ((self = [super init])) {
		preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
	
		containerView = [[PSWContainerView alloc] init];
		snapshotPageView = [[PSWPageView alloc] initWithFrame:CGRectZero applicationController:[PSWApplicationController sharedInstance]];

		[containerView addSubview:snapshotPageView];
		[containerView setAlpha:0.0f];
		
		[containerView setPageView:snapshotPageView];
		[snapshotPageView setPageViewDelegate:self];
	
		[containerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
		[self reparentView];
		[self reloadPreferences];
		
		if (GetPreference(PSWBecomeHomeScreen, NSInteger) == PSWBecomeHomeScreenDisabled) {
			isActive = YES;
			[self setActive:NO animated:NO];
		} else {
			[self setActive:YES animated:NO];
		}
		
		LAActivator *la = CHSharedInstance(LAActivator);
		if ([la respondsToSelector:@selector(hasSeenListenerWithName:)] && [la respondsToSelector:@selector(assignEvent:toListenerWithName:)])
			if (![la hasSeenListenerWithName:@"com.collab.proswitcher"])
				[la assignEvent:[CHClass(LAEvent) eventWithName:@"libactivator.menu.hold.short"] toListenerWithName:@"com.collab.proswitcher"];
		[la registerListener:self forName:@"com.collab.proswitcher"];
	}
	
	return self;
}

- (void)dealloc 
{
	[preferences release];
	[focusedApplication release];
	[snapshotPageView release];
	[containerView release];
	
    [super dealloc];
}

- (void)reparentView
{	
	UIView *view = containerView;
		
	// Find appropriate superview and add as subview
	UIView *buttonBar = [CHSharedInstance(SBIconModel) buttonBar];
	if ([buttonBar window]) {
		UIView *buttonBarParent = [buttonBar superview];
		UIView *targetSuperview = [buttonBarParent superview];
		[view setFrame:[targetSuperview bounds]];
		
		if (GetPreference(PSWShowDock, BOOL))
			[targetSuperview insertSubview:view belowSubview:buttonBarParent];
		else
			[targetSuperview insertSubview:view aboveSubview:buttonBarParent];
	} else {
		UIView *contentView = [CHSharedInstance(SBUIController) contentView];
		UIView *targetSuperview = [contentView superview];
		[targetSuperview insertSubview:view aboveSubview:contentView];
	}
}

- (BOOL)isActive
{
	return isActive;
}

- (BOOL)isAnimating
{
	return isAnimating;
}

#pragma mark Preferences

- (void)applyPreferences
{
	[self fixPageControl];
	
	/* The container view is responsible for background, page control, and [tap|auto] exit. */
	
	UIEdgeInsets scrollViewInsets;
	scrollViewInsets.left = scrollViewInsets.right = GetPreference(PSWSnapshotInset, float);
	scrollViewInsets.top = [[CHClass(SBStatusBarController) sharedStatusBarController] useDoubleHeightSize] ? 40.0f : 20.0f;
	scrollViewInsets.bottom = GetPreference(PSWShowDock, BOOL) ? PSWDockHeight : 0;
	if (PSWPad) {
		// If we are on an iPad, we want slightly...smaller cards.
		scrollViewInsets.top += 40.0f;
		scrollViewInsets.bottom += 40.0f;
	}
	[containerView setPageViewInsets:scrollViewInsets];
	
	if (GetPreference(PSWDimBackground, BOOL))
		[containerView setBackgroundColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8]];
	else
		[containerView setBackgroundColor:[UIColor clearColor]];
	
	if (GetPreference(PSWBackgroundStyle, NSInteger) == PSWBackgroundStyleImage)
		[[containerView layer] setContents:(id) [PSWImage(@"Background") CGImage]];
	else
		[[containerView layer] setContents:nil];
		
	containerView.showsPageControl    = GetPreference(PSWShowPageControl, BOOL);
	containerView.emptyTapClose       = GetPreference(PSWEmptyTapClose, BOOL);
	containerView.emptyText           = GetPreference(PSWEmptyStyle, NSInteger) == PSWEmptyStyleText ? PSWLocalize(@"NO_APPS_RUNNING") : nil;
	containerView.autoExit            = GetPreference(PSWEmptyStyle, NSInteger) == PSWEmptyStyleExit ? YES : NO;
	
	/* The page view is responsible for everything else, basically. */

	snapshotPageView.backgroundColor 	 = [UIColor clearColor];
	snapshotPageView.allowsSwipeToClose  = GetPreference(PSWSwipeToClose, BOOL);
	snapshotPageView.showsTitles         = GetPreference(PSWShowApplicationTitle, BOOL);
	snapshotPageView.showsCloseButtons   = GetPreference(PSWShowCloseButton, BOOL);
	snapshotPageView.roundedCornerRadius = GetPreference(PSWRoundedCornerRadius, float);
	snapshotPageView.tapsToActivate      = GetPreference(PSWTapsToActivate, NSInteger);
	snapshotPageView.unfocusedAlpha      = GetPreference(PSWUnfocusedAlpha, float);
	snapshotPageView.pagingEnabled       = GetPreference(PSWPagingEnabled, BOOL);
	snapshotPageView.showsBadges         = GetPreference(PSWShowBadges, BOOL);
	snapshotPageView.themedIcons         = GetPreference(PSWThemedIcons, BOOL);
	snapshotPageView.allowsZoom          = GetPreference(PSWAllowsZoom, BOOL);

	// Load ignored display identifiers.
	NSMutableArray *ignored = GetPreference(PSWShowDefaultApps, BOOL) ? [NSMutableArray array] : [[GetPreference(PSWDefaultApps, id) mutableCopy] autorelease];
	
	// Hide SpringBoard card if disabled.
	if (!GetPreference(PSWSpringBoardCard, BOOL)) {
		[ignored addObject:@"com.apple.springboard"];
	}
	
	// Hide dock icons if disabled
	if (!GetPreference(PSWShowDockApps, BOOL)) {
		for (SBIcon *icon in [[CHSharedInstance(SBIconModel) buttonBar] icons]) {
			[ignored addObject:[icon displayIdentifier]];
		}
	}

	snapshotPageView.ignoredDisplayIdentifiers = ignored;
}

- (void)fixPageControl
{
	if ([self isActive] && GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:NO];
}

- (void)reloadPreferences
{
	PSWPreparePreferences();
	[self applyPreferences];
}

- (void)didReceiveMemoryWarning
{
	[[PSWApplicationController sharedInstance] writeSnapshotsToDisk];
	PSWClearResourceCache();
}

#pragma mark Status Bar

- (void)saveStatusBarStyle
{
	formerStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
}

- (void)restoreStatusBarStyle
{
	[[UIApplication sharedApplication] setStatusBarStyle:formerStatusBarStyle animated:NO];
}

#pragma mark Activate

- (void)didFinishActivate
{
	isAnimating = NO;
	[snapshotPageView layoutSubviews];
}

- (void)activateWithAnimation:(BOOL)animated
{
	// Don't activate when in editing mode
	SBIconController *iconController = CHSharedInstance(SBIconController);
	if ([iconController isEditing])
		return;
	
	// Always reparent view
	[self reparentView];
	
	// Don't double-activate
	if (isActive)
		return;
	isActive = YES;
	
	SBUIController *uiController = CHSharedInstance(SBUIController);
		
	// Deactivate CategoriesSB
	if ([uiController respondsToSelector:@selector(categoriesSBCloseAll)])
		[uiController categoriesSBCloseAll];
	
	// Deactivate Keyboard
	[[uiController window] endEditing:YES];
	
	// Setup status bar
	[self saveStatusBarStyle];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
		
	// Restore focused application
	[snapshotPageView setFocusedApplication:focusedApplication];
	
	[containerView setHidden:NO];
	
	if (animated) {
		[containerView setAlpha:0.0f];
		[snapshotPageView.layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5f];
		[snapshotPageView.layer setTransform:CATransform3DIdentity];
	}
	
	if (GetPreference(PSWShowPageControl, BOOL))
		[iconController setPageControlVisible:NO];
	
	// Show ProSwitcher
	[containerView setAlpha:1.0f];
			
	if (animated) {
		isAnimating = YES;
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(didFinishActivate)];
		[UIView commitAnimations];
	} else {
		[self didFinishActivate];
	}
}

#pragma mark Deactivate

- (void)didFinishDeactivate
{
	[containerView removeFromSuperview];
	[containerView setHidden:YES];
	[snapshotPageView.layer setTransform:CATransform3DIdentity];
	isAnimating = NO;
}

- (void)deactivateWithAnimation:(BOOL)animated
{
	// Don't double-deactivate
	if (!isActive)
		return;
	isActive = NO;
	
	// Save (new) focused applciation
	[focusedApplication release];
	focusedApplication = [[snapshotPageView focusedApplication] retain];
		
	if (animated) {
		[snapshotPageView.layer setTransform:CATransform3DIdentity];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5f];
		[snapshotPageView.layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
	}
	
	// Show SpringBoard's page control
	if (GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:YES];
		
	[containerView setAlpha:0.0f];
			
	if (animated) {
		isAnimating = YES;
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(didFinishDeactivate)];
		[UIView commitAnimations];
	} else {
		[self didFinishDeactivate];
	}
}

- (void)setActive:(BOOL)active animated:(BOOL)animated
{
	if (active) {
		[self activateWithAnimation:animated];
	} else {
		[self deactivateWithAnimation:animated];
	}
}

- (void)setActive:(BOOL)active
{
	[self setActive:active animated:GetPreference(PSWAnimateActive, BOOL)];
}

#pragma mark libactivator delegate

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	if ([[CHClass(SBAwayController) sharedAwayController] isLocked] || [self isAnimating])
		return;
	
	if (SBActive) {
		// SpringBoard is active, just activate
		BOOL newActive = ![self isActive];
		[self setActive:newActive animated:YES];
		if (newActive)
			[event setHandled:YES];
	} else {
		SBApplication *application = [SBWActiveDisplayStack topApplication];
		NSString *displayIdentifier = [application displayIdentifier];
		// Top application will be nil when app is loading; do nothing
		if ([displayIdentifier length]) {
			PSWApplication *activeApp = [[PSWApplicationController sharedInstance] applicationWithDisplayIdentifier:displayIdentifier];
			
			modifyZoomTransformCountDown = 2;
			ignoreZoomSetAlphaCountDown = 2;
			disallowIconListScatter++;
			
			// Background
			if (![activeApp hasNativeBackgrounding]) {
				if ([SBSharedInstance respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
					[SBSharedInstance setBackgroundingEnabled:YES forDisplayIdentifier:displayIdentifier];
			}
			
			// Deactivate application (animated)
			[[activeApp application] setDeactivationSetting:0x2 flag:YES];
			//[activeApp setDeactivationSetting:0x8 value:[NSNumber numberWithDouble:1]]; // disable animations
			[SBWActiveDisplayStack popDisplay:application];
			[SBWSuspendingDisplayStack pushDisplay:application];
			
			// Show ProSwitcher
			[self setActive:YES animated:NO];
			[snapshotPageView setFocusedApplication:activeApp animated:NO];
			[event setHandled:YES];
			
			disallowIconListScatter--;
		}
	}
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[self setActive:NO animated:NO];
}

- (void)activator:(LAActivator *)activator otherListenerDidHandleEvent:(LAEvent *)event
{
	[self setActive:NO animated:NO];
}

- (void)activator:(LAActivator *)activator receiveDeactivateEvent:(LAEvent *)event
{
	if ([self isActive]) {
		[self setActive:NO animated:YES];
		[event setHandled:YES];
	}
}

#pragma mark PSWPageView delegate

- (void)snapshotPageView:(PSWPageView *)snapshotPageView didChangeToPage:(int)page
{
	[containerView setPageControlPage:page];
}

- (void)snapshotPageView:(PSWPageView *)snapshotPageView pageCountDidChange:(int)pageCount
{
	[containerView setPageControlCount:pageCount];
}

- (void)snapshotPageView:(PSWPageView *)sspv didSelectApplication:(PSWApplication *)app
{
	disallowIconListScatter++;
	modifyZoomTransformCountDown = 1;
	ignoreZoomSetAlphaCountDown = 1;
	[app activateWithAnimation:YES];
	disallowIconListScatter--;
}

- (void)snapshotPageView:(PSWPageView *)sspv didCloseApplication:(PSWApplication *)app
{
	disallowRestoreIconList++;
	[app exit];
	[self reparentView]; // Fix layout
	[snapshotPageView removeViewForApplication:app];
	disallowRestoreIconList--;
}

- (void)snapshotPageViewShouldExit:(PSWPageView *)sspv
{
	[self setActive:NO];
}

- (void)_deactivateFromAppActivate
{
	[self setActive:NO animated:NO];
}

@end

#pragma mark Preference Changed Notification
static void PreferenceChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[sharedController reloadPreferences];
	PSWUpdateIconVisibility();
}

#pragma mark SBUIController
CHOptimizedMethod(3, self, void, SBUIController, animateApplicationActivation, SBApplication *, application, animateDefaultImage, BOOL, animateDefaultImage, scatterIcons, BOOL, scatterIcons)
{
	CHSuper(3, SBUIController, animateApplicationActivation, application, animateDefaultImage, animateDefaultImage, scatterIcons, scatterIcons && !disallowIconListScatter);
}

// 3.0-3.1
CHOptimizedMethod(1, self, void, SBUIController, restoreIconList, BOOL, animated)
{
	if (disallowRestoreIconList == 0)
		CHSuper(1, SBUIController, restoreIconList, animated && disallowIconListScatter == 0);
	
	[sharedController reparentView];
}

// 3.2
CHOptimizedMethod(1, self, void, SBUIController, restoreIconListAnimated, BOOL, animated)
{
	if (disallowRestoreIconList == 0)
		CHSuper(1, SBUIController, restoreIconListAnimated, animated && disallowIconListScatter == 0);
	
	[sharedController reparentView];
}
// 3.2
CHOptimizedMethod(2, self, void, SBUIController, restoreIconListAnimated, BOOL, animated, animateWallpaper, BOOL, animateWallpaper)
{
	if (disallowRestoreIconList == 0)
		CHSuper(2, SBUIController, restoreIconListAnimated, animated && disallowIconListScatter == 0, animateWallpaper, animateWallpaper && disallowIconListScatter == 0);
	
	[sharedController reparentView];
}

CHOptimizedMethod(0, self, void, SBUIController, finishLaunching)
{
	NSLog(@"Welcome to ProSwitcher.");
	NSLog(@"\"If debugging is the process of removing software bugs, then programming must be the process of putting them in.\" -- Edsger Dijkstra");
	
	NSMutableDictionary* plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath] ?: [[NSMutableDictionary alloc] init];
	if (![[plistDict objectForKey:@"PSWAlert"] boolValue]) {
		// Tutorial
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:PSWLocalize(@"WELCOME_TITLE") message:PSWLocalize(@"WELCOME_MESSAGE") delegate:nil cancelButtonTitle:nil otherButtonTitles:PSWLocalize(@"WELCOME_CONTINUE_BUTTON"), nil] autorelease];
		[alert show];
		[plistDict setObject:[NSNumber numberWithBool:YES] forKey:@"PSWAlert"];
		PSWWriteBinaryPropertyList(plistDict, PSWPreferencesFilePath);
		
		// Analytics
		NSURL *analyticsURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://xuzz.net/cydia/proswitcherstats.php?udid=%@", [[UIDevice currentDevice] uniqueIdentifier]]];
		NSURLRequest *request = [NSURLRequest requestWithURL:analyticsURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
		// Fire off a request to the server, yes this leaks but whatever its just one object for the entire lifetime of ProSwitcher
		[[NSURLConnection alloc] initWithRequest:request delegate:nil startImmediately:YES];
	}
	[plistDict release];
	
	CHSuper(0, SBUIController, finishLaunching);

	sharedController = [[PSWController alloc] init];
	
	if (GetPreference(PSWBecomeHomeScreen, NSInteger) != PSWBecomeHomeScreenDisabled)
		[sharedController setActive:YES animated:NO];
}


#pragma mark SBDisplayStack
CHOptimizedMethod(1, self, void, SBDisplayStack, pushDisplay, SBDisplay *, display)
{
	SBApplication *application;
	NSString *displayIdentifier;
	if (CHIsClass(display, SBApplication)) {
		application = (SBApplication *) display;
		displayIdentifier = [application displayIdentifier];
	} else {
		application = nil;
		displayIdentifier = nil;
	}
	
	if (self == SBWSuspendingDisplayStack && GetPreference(PSWBecomeHomeScreen, NSInteger) != PSWBecomeHomeScreenDisabled) {
		if (application) {
			if ([displayIdentifier isEqualToString:displayIdentifierToSuppressBackgroundingOn]) {
				[displayIdentifierToSuppressBackgroundingOn release];
				displayIdentifierToSuppressBackgroundingOn = nil;
			} else {
				PSWApplication *suspendingApp = [[PSWApplicationController sharedInstance] applicationWithDisplayIdentifier:displayIdentifier];
				if (suspendingApp) {
					if (GetPreference(PSWBecomeHomeScreen, NSInteger) == PSWBecomeHomeScreenBackground) {
						// Background
						if (![suspendingApp hasNativeBackgrounding]) {
							if ([SBSharedInstance respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
								[SBSharedInstance setBackgroundingEnabled:YES forDisplayIdentifier:displayIdentifier];
						}
					}
					modifyZoomTransformCountDown = 2;
					ignoreZoomSetAlphaCountDown = 2;
					
					disallowIconListScatter++;
					
					CHSuper(1, SBDisplayStack, pushDisplay, display);
					[sharedController setActive:YES animated:NO];
					[[sharedController snapshotPageView] setFocusedApplication:suspendingApp animated:NO];
					
					disallowIconListScatter--;
					return;
				}
			}
		}
	} else if (self == SBWPreActivateDisplayStack) {
		if (CHIsClass(display, SBApplication)) {
			[sharedController performSelector:@selector(_deactivateFromAppActivate) withObject:nil afterDelay:0.5f];
		}
	}	
	CHSuper(1, SBDisplayStack, pushDisplay, display);
}

#pragma mark SpringBoard
CHOptimizedMethod(0, self, void, SpringBoard, _handleMenuButtonEvent)
{
	if ([sharedController isActive]) {
		// Deactivate and suppress SpringBoard list scrolling
		[sharedController setActive:NO];
		
		disallowIconListScroll++;
		CHSuper(0, SpringBoard, _handleMenuButtonEvent);
		disallowIconListScroll--;
		
		return;
	}
	
	CHSuper(0, SpringBoard, _handleMenuButtonEvent);
}

#pragma mark SBIconController
CHOptimizedMethod(2, self, void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (disallowIconListScroll == 0)
		CHSuper(2, SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

CHOptimizedMethod(1, self, void, SBIconController, setIsEditing, BOOL, isEditing)
{
	// Disable ProSwitcher when editing
	if (isEditing)
		[sharedController setActive:NO];
	
	CHSuper(1, SBIconController, setIsEditing, isEditing);
}

CHOptimizedMethod(1, self, void, SBIconController, setPageControlVisible, BOOL, visible)
{
	if ([sharedController isActive] && GetPreference(PSWShowPageControl, BOOL))
		visible = NO;	
	CHSuper(1, SBIconController, setPageControlVisible, visible);
}

#pragma mark SBZoomView
__attribute__((always_inline))
static CGAffineTransform TransformRectToRect(CGRect sourceRect, CGRect targetRect)
{
	return CGAffineTransformScale(
		CGAffineTransformMakeTranslation(
			targetRect.origin.x - sourceRect.origin.x + (targetRect.size.width - sourceRect.size.width) / 2,
			targetRect.origin.y - sourceRect.origin.y + (targetRect.size.height - sourceRect.size.height) / 2),
		targetRect.size.width / sourceRect.size.width,
		targetRect.size.height / sourceRect.size.height);
}

CHOptimizedMethod(1, super, void, SBZoomView, setTransform, CGAffineTransform, transform)
{
	switch (modifyZoomTransformCountDown) {
		case 1: {
			modifyZoomTransformCountDown = 0;

			PSWPageView *pageView = [sharedController snapshotPageView];
			PSWSnapshotView *ssv = [pageView focusedSnapshotView];
			if (ssv && ![[[ssv application] displayIdentifier] isEqualToString:@"com.apple.springboard"]) {
				UIView *containerView = [sharedController containerView];
				[containerView layoutIfNeeded];
				[pageView layoutIfNeeded];
				UIView *screenView = [ssv screenView];
				CGRect convertedRect = [[screenView superview] convertRect:[screenView frame] toView:[containerView superview]];
				CGRect rotatedRect;
				UIInterfaceOrientation *orientationRef = CHIvarRef(CHSharedInstance(SBUIController), _orientation, UIInterfaceOrientation);
				if (orientationRef) {
					UIInterfaceOrientation orientation = *orientationRef;
					CGSize screenSize = [[UIScreen mainScreen] bounds].size;
					switch (orientation) {
						case UIInterfaceOrientationLandscapeLeft:
							rotatedRect.origin.x = convertedRect.origin.y;
							rotatedRect.origin.y = screenSize.height - convertedRect.origin.x - convertedRect.size.width;
							rotatedRect.size.height = convertedRect.size.width;
							rotatedRect.size.width = convertedRect.size.height;
							break;
						case UIInterfaceOrientationLandscapeRight:
							rotatedRect.origin.x = screenSize.width - convertedRect.origin.y - convertedRect.size.height;
							rotatedRect.origin.y = convertedRect.origin.x;
							rotatedRect.size.height = convertedRect.size.width;
							rotatedRect.size.width = convertedRect.size.height;
							break;
						case UIInterfaceOrientationPortraitUpsideDown:
							rotatedRect.origin.x = screenSize.width - convertedRect.origin.x - convertedRect.size.width;
							rotatedRect.origin.y = screenSize.height - convertedRect.origin.y - convertedRect.size.height;
							rotatedRect.size = convertedRect.size;
							break;
						case UIInterfaceOrientationPortrait:
						default:
							rotatedRect = convertedRect;
							break;
					}
				} else {
					rotatedRect = convertedRect;
				}
				transform = TransformRectToRect([self frame], rotatedRect);
			}
		}
		case 0:
			CHSuper(1, SBZoomView, setTransform, transform);
			break;
		default:
			modifyZoomTransformCountDown--;
			CHSuper(1, SBZoomView, setTransform, transform);
			break;
	}
}

/*CHOptimizedMethod(1, super, void, SBZoomView, setAlpha, CGFloat, alpha)
{
	if (ignoreZoomSetAlphaCountDown)
		ignoreZoomSetAlphaCountDown--;
	else
		CHSuper(1, SBZoomView, setAlpha, alpha);
}*/

#pragma mark SBStatusBar

CHOptimizedMethod(0, self, CGAffineTransform, SBStatusBar, distantStatusWindowTransform)
{
	if (disallowIconListScatter)
		return CGAffineTransformMakeTranslation(0.0f, -[self frame].size.height);
	else
		return CHSuper(0, SBStatusBar, distantStatusWindowTransform);
}

#pragma mark SBSearchView

CHOptimizedMethod(2, self, void, SBSearchView, setShowsKeyboard, BOOL, visible, animated, BOOL, animated)
{
	// Disable search view's keyboard when ProSwitcher is active
	CHSuper(2, SBSearchView, setShowsKeyboard, visible && ![sharedController isActive], animated, animated);
}

#pragma mark SBVoiceControlAlert

CHOptimizedMethod(0, super, void, SBVoiceControlAlert, deactivate)
{
	CHSuper(0, SBVoiceControlAlert, deactivate);
	
	// Fix display when coming back from VoiceControl
	if ([sharedController isActive])
		[sharedController setActive:NO animated:NO];
}

#pragma mark SBIconListPageControl

CHOptimizedMethod(0, super, id, SBIconListPageControl, init)
{
	self = CHSuper(0, SBIconListPageControl, init);
	
	if ([sharedController isActive] && GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:NO];
	
	return self;
}

#ifdef SIMULATOR_DEBUG
CHOptimizedMethod(0, self, void, SpringBoard, handleMenuDoubleTap)
{
	if (![sharedController isAnimating])
		[sharedController setActive:[sharedController isActive]];
}
#endif

CHConstructor
{
	CHAutoreleasePoolForScope();
	
	// SpringBoard only.
	if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"])
		return;
	
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferenceChangedCallback, CFSTR(PSWPreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);

	CHLoadLateClass(SBAwayController);
	CHLoadLateClass(SBApplication);
	CHLoadLateClass(SBStatusBarController);
	CHLoadLateClass(SBApplicationIcon);
	CHLoadLateClass(SBApplicationController);
	CHLoadLateClass(SBIconModel);
	
	CHLoadLateClass(SBIconListPageControl);
	CHHook0(SBIconListPageControl, init);
	
	CHLoadLateClass(SBUIController);
	CHHook(1, SBUIController, restoreIconList);
	CHHook(1, SBUIController, restoreIconListAnimated);
	CHHook(2, SBUIController, restoreIconListAnimated, animateWallpaper);
	CHHook(3, SBUIController, animateApplicationActivation, animateDefaultImage, scatterIcons);
	CHHook(0, SBUIController, finishLaunching);

	CHLoadLateClass(SBDisplayStack);
	CHHook(1, SBDisplayStack, pushDisplay);
	
	CHLoadLateClass(SpringBoard);
	CHLoadLateClass(SBIconController);	
	CHHook(1, SBIconController, setIsEditing);
	CHHook(1, SBIconController, setPageControlVisible);
	
	CHLoadLateClass(SBZoomView);
	CHHook(1, SBZoomView, setTransform);
	//CHHook(1, SBZoomView, setAlpha);
	
	CHLoadLateClass(SBStatusBar);
	CHHook(0, SBStatusBar, distantStatusWindowTransform);
	
	CHLoadLateClass(SBSearchView);
	CHHook(2, SBSearchView, setShowsKeyboard, animated);
	
	CHLoadLateClass(SBVoiceControlAlert);
	CHHook(0, SBVoiceControlAlert, deactivate);
	
	// Using late-binding until we get a simulator build for libactivator :(
	dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
	CHLoadLateClass(LAActivator);
	CHLoadLateClass(LAEvent);
	if (![CHSharedInstance(LAActivator) respondsToSelector:@selector(sendDeactivateEventToListeners:)]) {
		CHHook(0, SpringBoard, _handleMenuButtonEvent);		
		CHHook(2, SBIconController, scrollToIconListAtIndex, animate);
	}

#ifdef SIMULATOR_DEBUG	
	// When we have no other way to activate it, here's an easy workaround
	CHHook(0, SpringBoard, handleMenuDoubleTap);
#endif
}
