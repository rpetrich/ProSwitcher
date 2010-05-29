

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
static BOOL hasFinishedLaunching;

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
@end

@implementation PSWController
@synthesize snapshotPageView, containerView;

+ (PSWController *)sharedInstance
{
	static PSWController *mainController = nil;
	
	if (mainController == nil && hasFinishedLaunching) {
		mainController = [[PSWController alloc] init];
	}
		
	return mainController;
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
	// FIXME: refactor all this page control hiding into a new method
	if ([self isActive] && GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:NO];
	
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
	containerView.emptyText           = GetPreference(PSWEmptyStyle, NSInteger) == PSWEmptyStyleText ? @"No Apps Running" : nil;
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
	if ([CHSharedInstance(SBIconController) isEditing])
		return;
	
	// Always reparent view
	[self reparentView];
	
	// Don't double-activate
	if (isActive)
		return;
	isActive = YES;
		
	// Deactivate CategoriesSB
	if ([CHSharedInstance(SBUIController) respondsToSelector:@selector(categoriesSBCloseAll)])
		[CHSharedInstance(SBUIController) categoriesSBCloseAll];
	
	// Deactivate Keyboard
	[[CHSharedInstance(SBUIController) window] endEditing:YES];
	
	// Setup status bar
	[self saveStatusBarStyle];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
		
	// Restore focused application
	[snapshotPageView setFocusedApplication:focusedApplication];
	
	if (animated) {
		[snapshotPageView.layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
		
		// Animate activation
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5f];
		[snapshotPageView.layer setTransform:CATransform3DIdentity];
	}
	
	if (GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:NO];
	
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
		// Animate deactivation
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
		[self setActive:newActive];
		if (newActive)
			[event setHandled:YES];
	} else {
		SBApplication *application = [SBWActiveDisplayStack topApplication];
		NSString *displayIdentifier = [application displayIdentifier];
		// Top application will be nil when app is loading; do nothing
		if ([displayIdentifier length]) {
			PSWApplication *activeApp = [[PSWApplicationController sharedInstance] applicationWithDisplayIdentifier:displayIdentifier];
			[self setActive:YES animated:NO];
			
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
			[self reparentView];
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
	[[PSWController sharedInstance] reloadPreferences];
	PSWUpdateIconVisibility();
}

#pragma mark SBUIController
CHMethod3(void, SBUIController, animateApplicationActivation, SBApplication *, application, animateDefaultImage, BOOL, animateDefaultImage, scatterIcons, BOOL, scatterIcons)
{
	CHSuper3(SBUIController, animateApplicationActivation, application, animateDefaultImage, animateDefaultImage, scatterIcons, scatterIcons && !disallowIconListScatter);
}

CHMethod1(void, SBUIController, restoreIconList, BOOL, animated)
{
	if (disallowRestoreIconList == 0)
		CHSuper1(SBUIController, restoreIconList, animated && disallowIconListScatter == 0);
	
	[[PSWController sharedInstance] reparentView];
}

CHMethod0(void, SBUIController, finishLaunching)
{
	NSLog(@"Welcome to ProSwitcher.");
	NSLog(@"\"If debugging is the process of removing software bugs, then programming must be the process of putting them in.\" -- Edsger Dijkstra");
	
	NSMutableDictionary* plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath] ?: [[NSMutableDictionary alloc] init];
	if (![[plistDict objectForKey:@"PSWAlert"] boolValue]) {
		// Tutorial
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Welcome to ProSwitcher" message:@"To change settings or to setup gestures, go to the Settings app.\n\n(c) 2009 Ryan Petrich and Grant Paul\nLGPL Licensed" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Continue", nil] autorelease];
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

	hasFinishedLaunching = YES;
	
	if (GetPreference(PSWBecomeHomeScreen, NSInteger) != PSWBecomeHomeScreenDisabled)
		[[PSWController sharedInstance] setActive:YES animated:NO];
	
	CHSuper0(SBUIController, finishLaunching);
}


#pragma mark SBDisplayStack
CHMethod1(void, SBDisplayStack, pushDisplay, SBDisplay*, display)
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
					
					CHSuper1(SBDisplayStack, pushDisplay, display);
					[[PSWController sharedInstance] setActive:YES animated:NO];
					[[[PSWController sharedInstance] snapshotPageView] setFocusedApplication:suspendingApp animated:NO];
					
					disallowIconListScatter--;
					return;
				}
			}
		}
	} else if (self == SBWPreActivateDisplayStack) {
		if (CHIsClass(display, SBApplication)) {
			[[PSWController sharedInstance] performSelector:@selector(_deactivateFromAppActivate) withObject:nil afterDelay:0.5f];
		}
	}	
	CHSuper1(SBDisplayStack, pushDisplay, display);
}

#pragma mark SpringBoard
CHMethod0(void, SpringBoard, _handleMenuButtonEvent)
{
	if ([[PSWController sharedInstance] isActive]) {
		// Deactivate and suppress SpringBoard list scrolling
		[[PSWController sharedInstance] setActive:NO];
		
		disallowIconListScroll++;
		CHSuper0(SpringBoard, _handleMenuButtonEvent);
		disallowIconListScroll--;
		
		return;
	}
	
	CHSuper0(SpringBoard, _handleMenuButtonEvent);
}

CHMethod1(void, SpringBoard, noteInterfaceOrientationChanged, UIInterfaceOrientation, interfaceOrientation)
{
	CHSuper1(SpringBoard, noteInterfaceOrientationChanged, interfaceOrientation);
	
	//[[PSWController sharedInstance] updateForOrientation:interfaceOrientation];
}

/*CHMethod0(void, SpringBoard, invokeProSwitcher)
{
	[[PSWController sharedInstance] activator:nil abortEvent:nil];
}*/

#pragma mark SBIconController
CHMethod2(void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (disallowIconListScroll == 0)
		CHSuper2(SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

CHMethod1(void, SBIconController, setIsEditing, BOOL, isEditing)
{
	// Disable ProSwitcher when editing
	if (isEditing)
		[[PSWController sharedInstance] setActive:NO];
	
	CHSuper1(SBIconController, setIsEditing, isEditing);
}

CHMethod1(void, SBIconController, setPageControlVisible, BOOL, visible)
{
	if ([[PSWController sharedInstance] isActive] && GetPreference(PSWShowPageControl, BOOL)) {
		CHSuper1(SBIconController, setPageControlVisible, NO);
		return;
	}
	
	CHSuper1(SBIconController, setPageControlVisible, visible);
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

CHMethod1(void, SBZoomView, setTransform, CGAffineTransform, transform)
{
	switch (modifyZoomTransformCountDown) {
		case 1: {
			modifyZoomTransformCountDown = 0;

			PSWSnapshotView *ssv = [[[PSWController sharedInstance] snapshotPageView] focusedSnapshotView];
			if ([[[ssv application] displayIdentifier] isEqualToString:@"com.apple.springboard"]) {
				CHSuper1(SBZoomView, setTransform, transform);
			} else {
				UIView *screenView = [ssv screenView];
				CGRect translatedDestRect = [screenView convertRect:[screenView bounds] toView:[[PSWController sharedInstance] containerView]];
				CHSuper1(SBZoomView, setTransform, TransformRectToRect([self frame], translatedDestRect));
			}
			
			break;
		}
		case 0:
			CHSuper1(SBZoomView, setTransform, transform);
			break;
		default:
			modifyZoomTransformCountDown--;
			CHSuper1(SBZoomView, setTransform, transform);
			break;
	}
}

/*CHMethod1(void, SBZoomView, setAlpha, CGFloat, alpha)
{
	if (ignoreZoomSetAlphaCountDown)
		ignoreZoomSetAlphaCountDown--;
	else
		CHSuper1(SBZoomView, setAlpha, alpha);
}*/

#pragma mark SBStatusBar

CHMethod0(CGAffineTransform, SBStatusBar, distantStatusWindowTransform)
{
	if (disallowIconListScatter)
		return CGAffineTransformMakeTranslation(0.0f, -[self frame].size.height);
	else
		return CHSuper0(SBStatusBar, distantStatusWindowTransform);
}

#pragma mark SBSearchView

CHMethod2(void, SBSearchView, setShowsKeyboard, BOOL, visible, animated, BOOL, animated)
{
	// Disable search view's keyboard when ProSwitcher is active
	CHSuper2(SBSearchView, setShowsKeyboard, visible && ![[PSWController sharedInstance] isActive], animated, animated);
}

#pragma mark SBVoiceControlAlert

CHMethod0(void, SBVoiceControlAlert, deactivate)
{
	CHSuper0(SBVoiceControlAlert, deactivate);
	
	// Fix display when coming back from VoiceControl
	if ([[PSWController sharedInstance] isActive])
		[[PSWController sharedInstance] setActive:NO animated:NO];
}

#pragma mark SBIconListPageControl

CHMethod0(id, SBIconListPageControl, init)
{
	self = CHSuper0(SBIconListPageControl, init);
	
	if ([[PSWController sharedInstance] isActive] && GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:NO];
	
	return self;
}

#ifdef DEBUG
CHMethod0(void, SpringBoard, handleMenuDoubleTap)
{
	if (![[PSWController sharedInstance] isAnimating])
		[[PSWController sharedInstance] setActive:[[PSWController sharedInstance] isActive]];
}
#endif

CHConstructor
{
	CHAutoreleasePoolForScope();
	
	// SpringBoard only!
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
	CHHook1(SBUIController, restoreIconList);
	CHHook3(SBUIController, animateApplicationActivation, animateDefaultImage, scatterIcons);
	CHHook0(SBUIController, finishLaunching);

	CHLoadLateClass(SBDisplayStack);
	CHHook1(SBDisplayStack, pushDisplay);
	
	CHLoadLateClass(SpringBoard);
	CHLoadLateClass(SBIconController);	
	CHHook1(SBIconController, setIsEditing);
	CHHook1(SBIconController, setPageControlVisible);
	CHHook1(SpringBoard, noteInterfaceOrientationChanged);
	
	CHLoadLateClass(SBZoomView);
	CHHook1(SBZoomView, setTransform);
	//CHHook1(SBZoomView, setAlpha);
	
	CHLoadLateClass(SBStatusBar);
	CHHook0(SBStatusBar, distantStatusWindowTransform);
	
	CHLoadLateClass(SBSearchView);
	CHHook2(SBSearchView, setShowsKeyboard, animated);
	
	CHLoadLateClass(SBVoiceControlAlert);
	CHHook0(SBVoiceControlAlert, deactivate);
	
	// Using late-binding until we get a simulator build for libactivator :(
	dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
	CHLoadLateClass(LAActivator);
	CHLoadLateClass(LAEvent);
	if (![CHSharedInstance(LAActivator) respondsToSelector:@selector(sendDeactivateEventToListeners:)]) {
		CHHook0(SpringBoard, _handleMenuButtonEvent);		
		CHHook2(SBIconController, scrollToIconListAtIndex, animate);
	}
	
	#ifdef DEBUG
	// When we have no other way to activate it, here's an easy workaround
	CHHook0(SpringBoard, handleMenuDoubleTap);
	#endif /* DEBUG */
}
