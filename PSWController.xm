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

%class SBAwayController;
%class SBStatusBarController;
%class SBApplication;
%class SBDisplayStack;
%class SpringBoard;
%class SBIconListPageControl;
%class SBUIController;
%class SBApplicationController;
%class SBIconModel;
%class SBIconController;
%class SBZoomView;
%class SBStatusBar;
%class SBSearchView;
%class SBVoiceControlAlert;
%class SBApplicationIcon;

static Class $LAActivator;
static Class $LAEvent;

NSDictionary *preferences;

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
		PSWPreparePreferences();
	
		containerView = [[PSWContainerView alloc] init];
		snapshotPageView = [[PSWPageView alloc] initWithFrame:CGRectZero applicationController:[PSWApplicationController sharedInstance]];

		[containerView addSubview:snapshotPageView];
		[containerView setAlpha:0.0f];
		[containerView setHidden:YES];
		
		[containerView setPageView:snapshotPageView];
		[snapshotPageView setPageViewDelegate:self];
	
		[containerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
				
		LAActivator *la = [$LAActivator sharedInstance];
		if ([la respondsToSelector:@selector(hasSeenListenerWithName:)] && [la respondsToSelector:@selector(assignEvent:toListenerWithName:)])
			if (![la hasSeenListenerWithName:@"com.collab.proswitcher"])
				[la assignEvent:[$LAEvent eventWithName:@"libactivator.menu.hold.short"] toListenerWithName:@"com.collab.proswitcher"];
		[la registerListener:self forName:@"com.collab.proswitcher"];
		
		[self applyIgnored];
		[self applyInsets];
		[self applyPreferences];
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
	
	if (!isAnimating)
	 	[view setHidden:!isActive];
		
	// Find appropriate superview and add as subview
	UIView *buttonBar = PSWDockView;
	if ([buttonBar window]) {
		UIView *buttonBarParent = [buttonBar superview];
		UIView *targetSuperview = [buttonBarParent superview];
		[view setFrame:[targetSuperview bounds]];
		
		if (GetPreference(PSWShowDock, BOOL))
			[targetSuperview insertSubview:view belowSubview:buttonBarParent];
		else
			[targetSuperview insertSubview:view aboveSubview:buttonBarParent];
	} else {
		UIView *contentView = [[$SBUIController sharedInstance] contentView];
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

- (void)applyIgnored 
{
	NSMutableArray *ignored = [NSMutableArray array];
	
	// Hide SpringBoard card if disabled.
	if (!GetPreference(PSWSpringBoardCard, BOOL)) {
		[ignored addObject:@"com.apple.springboard"];
	}
	
	// Hide Phone card if disabled.
	if (GetPreference(PSWHidePhone, BOOL)) {
		[ignored addObject:@"com.apple.mobilephone"];
	}
	
	// Hide dock icons if disabled
	if (!GetPreference(PSWShowDockApps, BOOL)) {
		for (SBIcon *icon in [PSWDockModel icons]) {
			[ignored addObject:[icon respondsToSelector:@selector(displayIdentifier)] ? [icon displayIdentifier]:
							   [icon respondsToSelector:@selector(application)] ? [[icon application] displayIdentifier] : nil];
		}
	}

	snapshotPageView.ignoredDisplayIdentifiers = ignored;
}

- (void)applyInsets 
{
	/* The container view is responsible for background, page control, and [tap|auto] exit. */
	
	UIEdgeInsets scrollViewInsets;
	scrollViewInsets.left = scrollViewInsets.right = 0;
	scrollViewInsets.top = [[$SBStatusBarController sharedStatusBarController] useDoubleHeightSize] ? 40.0f : 20.0f;
	scrollViewInsets.bottom = PSWDockHeight;
	[containerView setPageViewEdgeInsets:scrollViewInsets];
	
	PSWProportionalInsets cardInsets;
	cardInsets.left = cardInsets.right = PSWSnapshotProportionalInset;
	cardInsets.top = 0.0f;
	cardInsets.bottom = 0.025f;
	[containerView setPageViewInsets:cardInsets];
}

- (void)applyPreferences
{	
	if (GetPreference(PSWDimBackground, BOOL))
		[containerView setBackgroundColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8]];
	else
		[containerView setBackgroundColor:[UIColor clearColor]];

	if (GetPreference(PSWBackgroundStyle, NSInteger) == PSWBackgroundStyleImage)
		[[containerView layer] setContents:(id) [PSWImage(@"Background") CGImage]];
	else
		[[containerView layer] setContents:nil];
		
	containerView.emptyTapClose       = YES; 
	containerView.emptyText           = @"No Apps Running";
	containerView.autoExit            = NO;
}

- (void)fixPageControl
{
	if ([self isActive] && GetPreference(PSWShowPageControl, BOOL))
		[[$SBIconController sharedInstance] setPageControlVisible:NO];
}

- (void)didReceiveMemoryWarning
{
	[[PSWApplicationController sharedInstance] writeSnapshotsToDisk];
	PSWClearResourceCache();
}

#pragma mark Activate

- (void)didFinishActivate
{
	isAnimating = NO;
	[snapshotPageView layoutSubviews];
}

- (void)activateWithAnimation:(BOOL)animated
{
	// Don't double-activate
	if (isActive)
		return;
	isActive = YES;
	
	// Don't activate when in editing mode
	SBIconController *iconController = [$SBIconController sharedInstance];
	if ([iconController isEditing])
		return;
	
	// Always reparent view
	[self reparentView];
	
	SBUIController *uiController = [$SBUIController sharedInstance];
		
	// Deactivate CategoriesSB
	if ([uiController respondsToSelector:@selector(categoriesSBCloseAll)])
		[uiController categoriesSBCloseAll];
		
	// Close folders
	if ([iconController respondsToSelector:@selector(closeFolderAnimated:)])
		[iconController closeFolderAnimated:NO];
	
	// Deactivate Keyboard
	[[uiController window] endEditing:YES];
	
	// Restore focused application
	[snapshotPageView setFocusedApplication:focusedApplication];
	
	[containerView setHidden:NO];
	
	if (animated) {
		[containerView setAlpha:0.0f];
		[snapshotPageView.layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5f];
	}
	
	if (GetPreference(PSWShowPageControl, BOOL))
		[iconController setPageControlVisible:NO];
	
	// Show ProSwitcher
	[containerView setAlpha:1.0f];
	[snapshotPageView.layer setTransform:CATransform3DIdentity];
			
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
		
	[snapshotPageView.layer setTransform:CATransform3DIdentity];
	if (animated) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5f];
		[snapshotPageView.layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
	}
	
	// Show SpringBoard's page control
	if (GetPreference(PSWShowPageControl, BOOL))
		[[$SBIconController sharedInstance] setPageControlVisible:YES];
		
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
	if ([[$SBAwayController sharedAwayController] isLocked] || [self isAnimating])
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
	[(SpringBoard *) [UIApplication sharedApplication] relaunchSpringBoard];
}

%hook SBUIController
- (void)animateApplicationActivation:(SBApplication *)application animateDefaultImage:(BOOL)animateDefaultImage scatterIcons:(BOOL)scatterIcons
{
	%orig(application, animateDefaultImage, scatterIcons && !disallowIconListScatter);
}

// 3.0-3.1
- (void)restoreIconList:(BOOL)animated
{
	if (disallowRestoreIconList == 0)
		%orig(animated && disallowIconListScatter == 0);
	
	[sharedController reparentView];
}

// 3.2
- (void)restoreIconListAnimated:(BOOL)animated
{
	if (disallowRestoreIconList == 0)
		%orig(animated && disallowIconListScatter == 0);
	
	[sharedController reparentView];
}
// 3.2
- (void)restoreIconListAnimated:(BOOL)animated animateWallpaper:(BOOL)animateWallpaper 
{
	if (disallowRestoreIconList == 0)
		%orig(animated && disallowIconListScatter == 0, animateWallpaper && disallowIconListScatter == 0);
	
	[sharedController reparentView];
}

// 4.0
- (void)restoreIconListAnimated:(BOOL)animated animateWallpaper:(BOOL)animateWallpaper keepSwitcher:(BOOL)switcher
{
	if (disallowRestoreIconList == 0)
		%orig(animated && disallowIconListScatter == 0, animateWallpaper && disallowIconListScatter == 0, switcher);
	
	[sharedController reparentView];
}

- (void)finishLaunching
{
	NSLog(@"Welcome to ProSwitcher.");
	NSLog(@"\"If debugging is the process of removing software bugs, then programming must be the process of putting them in.\" -- Edsger Dijkstra");
	NSLog(@"Help us get the bugs out: send us an email if something isn't working right.");
	
	NSMutableDictionary* plistDict = [[NSMutableDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath] ?: [[NSMutableDictionary alloc] init];
	if (![[plistDict objectForKey:@"PSWAlert"] boolValue]) {
		// Tutorial
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:PSWLocalize(@"WELCOME_TITLE") message:PSWLocalize(@"WELCOME_MESSAGE") delegate:nil cancelButtonTitle:nil otherButtonTitles:PSWLocalize(@"WELCOME_CONTINUE_BUTTON"), nil] autorelease];
		[alert show];
		[plistDict setObject:[NSNumber numberWithBool:YES] forKey:@"PSWAlert"];
		PSWWriteBinaryPropertyList(plistDict, PSWPreferencesFilePath);
	}
	[plistDict release];
	
	%orig;

	sharedController = [[PSWController alloc] init];
	
	if (GetPreference(PSWBecomeHomeScreen, NSInteger) != PSWBecomeHomeScreenDisabled)
		[sharedController setActive:YES animated:NO];
}

%end

%hook SBDisplayStack

- (void)pushDisplay:(SBDisplay *)display
{
	SBApplication *application;
	NSString *displayIdentifier;
	if ([display isKindOfClass:$SBApplication]) {
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
					
					%orig;
					[sharedController setActive:YES animated:NO];
					[[sharedController snapshotPageView] setFocusedApplication:suspendingApp animated:NO];
					
					disallowIconListScatter--;
					return;
				}
			}
		}
	} else if (self == SBWPreActivateDisplayStack) {
		if ([display isKindOfClass:$SBApplication]) {
			[sharedController performSelector:@selector(_deactivateFromAppActivate) withObject:nil afterDelay:0.5f];
		}
	}	
	
	%orig;
}

%end

%hook SpringBoard
- (void)_handleMenuButtonEvent
{
	if ([sharedController isActive]) {
		// Deactivate and suppress SpringBoard list scrolling
		[sharedController setActive:NO];
		
		disallowIconListScroll++;
		%orig;
		disallowIconListScroll--;
		
		return;
	}
	
	%orig;
}

%end

%hook SBIconController

- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate
{
	if (disallowIconListScroll == 0)
		%orig;
}

- (void)setIsEditing:(BOOL)editing
{
	// Disable ProSwitcher when editing
	if (editing)
		[sharedController setActive:NO];
	
	%orig;
}

- (void)setPageControlVisible:(BOOL)visible
{
	if ([sharedController isActive] && GetPreference(PSWShowPageControl, BOOL))
		visible = NO;	
	%orig;
}

%end

%hook SBZoomView
static CGAffineTransform TransformRectToRect(CGRect sourceRect, CGRect targetRect)
{
	return CGAffineTransformScale(
		CGAffineTransformMakeTranslation(
			targetRect.origin.x - sourceRect.origin.x + (targetRect.size.width - sourceRect.size.width) / 2,
			targetRect.origin.y - sourceRect.origin.y + (targetRect.size.height - sourceRect.size.height) / 2),
		targetRect.size.width / sourceRect.size.width,
		targetRect.size.height / sourceRect.size.height);
}

- (void)setTransform:(CGAffineTransform)transform
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
				UIInterfaceOrientation *orientationRef = CHIvarRef([$SBUIController sharedInstance], _orientation, UIInterfaceOrientation);
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
			%orig;
			break;
		default:
			modifyZoomTransformCountDown--;
			%orig;
			break;
	}
}

/*- (void)setAlpha:(CGFloat)alpha
{
	if (ignoreZoomSetAlphaCountDown)
		ignoreZoomSetAlphaCountDown--;
	else
		%orig;
}*/

%end

%hook SBStatusBar

- (CGAffineTransform)distantStatusWindowTransform
{
	if (disallowIconListScatter)
		return CGAffineTransformMakeTranslation(0.0f, -[self frame].size.height);
	else
		return %orig;
}

%end

%hook SBSearchView

- (void)setShowsKeyboard:(BOOL)visible animated:(BOOL)animated
{
	// Disable search view's keyboard when ProSwitcher is active
	%orig(visible && ![sharedController isActive], animated);
}

%end

%hook SBVoiceControlAlert

- (void)deactivate
{
	%orig;
	
	// Fix display when coming back from VoiceControl
	if ([sharedController isActive])
		[sharedController setActive:NO animated:NO];
}

%end

%hook SBIconListPageControl

- (id)init
{
	self = %orig;
	
	if ([sharedController isActive] && GetPreference(PSWShowPageControl, BOOL))
		[[$SBIconController sharedInstance] setPageControlVisible:NO];
	
	return self;
}

%end

__attribute__((constructor)) static void proswitcher_init()
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	// SpringBoard only.
	if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"])
		return;
	
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferenceChangedCallback, CFSTR(PSWPreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);

	// Using late-binding until we get a simulator build for libactivator :(
	dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
	$LAActivator = objc_getClass("LAActivator");
	$LAEvent = objc_getClass("LAEvent");

	[pool release];
}
