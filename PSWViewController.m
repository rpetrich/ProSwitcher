#import "PSWViewController.h"

#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBAwayController.h>
#import <CaptainHook/CaptainHook.h>

#include <dlfcn.h>

#import "PSWDisplayStacks.h"
#import "PSWPreferences.h"
#import "PSWResources.h"
#import "SpringBoard+Backgrounder.h"
#import "SBUIController+CategoriesSB.h"

// Using zero-link (late binding) until we get a simulator build for libactivator :(
CHDeclareClass(LAActivator);

CHDeclareClass(SBAwayController);
CHDeclareClass(SBStatusBarController);
CHDeclareClass(SBApplication)
CHDeclareClass(SpringBoard);
CHDeclareClass(SBIconListPageControl);
CHDeclareClass(SBUIController);
CHDeclareClass(SBApplicationController);
CHDeclareClass(SBIconModel);
CHDeclareClass(SBIconController);
CHDeclareClass(SBZoomView);
CHDeclareClass(SBSearchView);
#define SBActive ([SBWActiveDisplayStack topApplication] == nil)
#define SBSharedInstance ((SpringBoard *) [UIApplication sharedApplication])


static PSWViewController *mainController;
static NSInteger suppressIconScatter;
static NSUInteger modifyZoomTransformCountDown;

static int restoreIconListFlag = 0;
static int suppressIconListScatter = 0;
static int suppressIconListScroll = 0;


@implementation PSWViewController
@synthesize snapshotPageView;

+ (PSWViewController *)sharedInstance
{
	if (!mainController)
		mainController = [[PSWViewController alloc] init];
	return mainController;
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

- (void)_applyPreferences
{
	UIView *view = [self view];
	view.backgroundColor = GetPreference(PSWDimBackground, BOOL) ? [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8]:[UIColor clearColor];
	
	if (GetPreference(PSWBackgroundStyle, NSInteger) == 1)
		[[view layer] setContents:(id) [PSWGetCachedSpringBoardResource(@"ProSwitcherBackground") CGImage]];
	else
		[[view layer] setContents:nil];
	
	if ([self isActive] && GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:NO];
		
	if (![self isActive] && GetPreference(PSWShowPageControl, BOOL))
		[CHSharedInstance(SBIconController) setPageControlVisible:YES];
	
	CGRect frame;
	frame.origin.x = 0.0f;
	frame.origin.y = [[CHClass(SBStatusBarController) sharedStatusBarController] useDoubleHeightSize]?40.0f:20.0f;
	frame.size.width = 320.0f;
	frame.size.height = (GetPreference(PSWShowDock, BOOL) ? 390.0f : 480.0f) - frame.origin.y;
	[snapshotPageView setFrame:frame];
	[snapshotPageView setBackgroundColor:[UIColor clearColor]];
	
	snapshotPageView.allowsSwipeToClose  = GetPreference(PSWSwipeToClose, BOOL);
	snapshotPageView.showsTitles         = GetPreference(PSWShowApplicationTitle, BOOL);
	snapshotPageView.showsCloseButtons   = GetPreference(PSWShowCloseButton, BOOL);
	snapshotPageView.emptyText           = GetPreference(PSWShowEmptyText, BOOL) ? @"No Apps Running":nil;
	snapshotPageView.roundedCornerRadius = GetPreference(PSWRoundedCornerRadius, float);
	snapshotPageView.tapsToActivate      = GetPreference(PSWTapsToActivate, NSInteger);
	snapshotPageView.snapshotInset       = GetPreference(PSWSnapshotInset, float);
	snapshotPageView.unfocusedAlpha      = GetPreference(PSWUnfocusedAlpha, float);
	snapshotPageView.showsPageControl    = GetPreference(PSWShowPageControl, BOOL);
	snapshotPageView.showsBadges         = GetPreference(PSWShowBadges, BOOL);
	snapshotPageView.ignoredDisplayIdentifiers = GetPreference(PSWShowDefaultApps, BOOL) ? nil : GetPreference(PSWDefaultApps, id);
	snapshotPageView.pagingEnabled       = GetPreference(PSWPagingEnabled, BOOL);
	[snapshotPageView redraw];
}

- (void)_reloadPreferences
{
	[preferences release];
	preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
	[self _applyPreferences];
}

#pragma mark View Controller

- (id)init
{
	if ((self = [super init])) {
		preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
	}	
	return self;
}

- (void)dealloc 
{
	[preferences release];
	[focusedApplication release];
	[snapshotPageView release];
    [super dealloc];
}

- (void)reparentView
{
	// Find appropriate superview and add as subview
	UIView *buttonBar = [CHSharedInstance(SBIconModel) buttonBar];
	UIView *buttonBarParent = [buttonBar superview];
	UIView *targetSuperview = [buttonBarParent superview];
	
	// Reparent always; even when already active
	if (GetPreference(PSWShowDock, BOOL))
		[targetSuperview insertSubview:self.view belowSubview:buttonBarParent];
	else
		[targetSuperview insertSubview:self.view aboveSubview:buttonBarParent];	
}

- (void)loadView 
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 480.0f)];
	
	snapshotPageView = [[PSWSnapshotPageView alloc] initWithFrame:CGRectZero applicationController:[PSWApplicationController sharedInstance]];
	[snapshotPageView setDelegate:self];
	[view addSubview:snapshotPageView];
	
	[self setView:view];
	[self _applyPreferences];
}

- (void)viewDidUnload
{
	[snapshotPageView removeFromSuperview];
	[snapshotPageView release];
	snapshotPageView = nil;
	[super viewDidUnload];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	[[PSWApplicationController sharedInstance] writeSnapshotsToDisk];
	PSWClearResourceCache();
}

#pragma mark Activation

- (void)saveStatusBarStyle
{
	formerStatusBarStyle = [[UIApplication sharedApplication] statusBarStyle];
}

- (void)restoreStatusBarStyle
{
	[[UIApplication sharedApplication] setStatusBarStyle:formerStatusBarStyle animated:NO];
}

- (void)didFinishDeactivate
{
	[[self view] removeFromSuperview];
	isAnimating = NO;
}

- (void)didFinishActivate
{
	isAnimating = NO;
}

- (void)setupSpringBoard
{
	// Deactivate CategoriesSB
	if ([CHSharedInstance(SBUIController) respondsToSelector:@selector(categoriesSBCloseAll)])
		[CHSharedInstance(SBUIController) categoriesSBCloseAll];
	
	// Deactivate Keyboard
	[[CHSharedInstance(SBUIController) window] endEditing:YES];
	
	// Setup status bar
	[self saveStatusBarStyle];
	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
	
}

- (void)setActive:(BOOL)active animated:(BOOL)animated
{
	if (!active && !isActive)
		return;
	
	if (active) {
		[self reparentView];
		if (!isActive) {
			isActive = active;
			
			[self setupSpringBoard];
			[snapshotPageView setFocusedApplication:focusedApplication];
			
			CALayer *scrollLayer = [snapshotPageView.scrollView layer];
			if (animated) {
				self.view.alpha = 0.0f;
				[scrollLayer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
				
				[UIView beginAnimations:nil context:nil];
				[UIView setAnimationDuration:0.5f];
				[UIView setAnimationDelegate:self];
				[UIView setAnimationDidStopSelector:@selector(didFinishActivate)];
				
				[scrollLayer setTransform:CATransform3DIdentity];
				self.view.alpha = 1.0f;
				[self _applyPreferences];
				
				isAnimating = YES;
				[UIView commitAnimations];
			} else {
				self.view.alpha = 1.0f;
				[self _applyPreferences];
				
				[self didFinishActivate];
			}
		}
	} else {
		isActive = active;
		
		[focusedApplication release];
		focusedApplication = [snapshotPageView.focusedApplication retain];
		
		CALayer *scrollLayer = [snapshotPageView.scrollView layer];
		if (animated) {
			[scrollLayer setTransform:CATransform3DIdentity];
			
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:0.5f];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(didFinishDeactivate)];
			
			[scrollLayer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
			self.view.alpha = 0.0f;
			[self _applyPreferences];
			
			isAnimating = YES;
			[UIView commitAnimations];
		} else {
			self.view.alpha = 0.0f;
			[self _applyPreferences];
			
			[self didFinishDeactivate];
		}
	}
}

- (void)setActive:(BOOL)active
{
	[self setActive:active animated:GetPreference(PSWAnimateActive, BOOL)];
}

#pragma mark libactivator

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	if ([[CHClass(SBAwayController) sharedAwayController] isLocked] || [self isAnimating])
		return;
	
	if (SBActive) {
		BOOL newActive = ![self isActive];
		[self setActive:newActive];
		if (newActive)
			[event setHandled:YES];
	} else {
		PSWApplication *activeApp = [[PSWApplicationController sharedInstance] applicationWithDisplayIdentifier:[[SBWActiveDisplayStack topApplication] displayIdentifier]];
		
		// Chicken or the egg situation here and I'm too sleepy to figure it out :P
		//    ^-- care to explain *what* situation :P?
		//modifyZoomTransformCountDown = 2;
		
		// background running app
		if (![activeApp hasNativeBackgrounding])
			if ([SBSharedInstance respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
				[SBSharedInstance setBackgroundingEnabled:YES forDisplayIdentifier:[activeApp displayIdentifier]];
		[[activeApp application] setDeactivationSetting:0x2 flag:YES]; // animate
		//[activeApp setDeactivationSetting:0x8 value:[NSNumber numberWithDouble:1]]; // disable animations
		
		// Deactivate by moving from active stack to suspending stack
		[SBWActiveDisplayStack popDisplay:[activeApp application]];
		[SBWSuspendingDisplayStack pushDisplay:[activeApp application]];
		
		// Show ProSwitcher
		[self setActive:YES animated:NO];
		[snapshotPageView setFocusedApplication:activeApp animated:NO];
		[event setHandled:YES];
	}	
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[self setActive:NO animated:NO];
}

#pragma mark PSWSnapshotPageView delegate

- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didSelectApplication:(PSWApplication *)application
{
	suppressIconScatter++;
	
	modifyZoomTransformCountDown = 1;
	[application activateWithAnimation:YES];
	
	suppressIconScatter--;
}

- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didCloseApplication:(PSWApplication *)application
{
	restoreIconListFlag++;
	
	[application exit];
	[self reparentView];
	
	restoreIconListFlag--;
}

- (void)snapshotPageViewShouldExit:(PSWSnapshotPageView *)snapshotPageView
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
	[[PSWViewController sharedInstance] _reloadPreferences];
}

#pragma mark SBApplication
CHMethod0(void, SBApplication, activate)
{
	[[PSWViewController sharedInstance] performSelector:@selector(_deactivateFromAppActivate) withObject:nil afterDelay:0.5f];
	CHSuper0(SBApplication, activate);
}

#pragma mark SBUIController
CHMethod3(void, SBUIController, animateApplicationActivation, SBApplication *, application, animateDefaultImage, BOOL, animateDefaultImage, scatterIcons, BOOL, scatterIcons)
{
	CHSuper3(SBUIController, animateApplicationActivation, application, animateDefaultImage, animateDefaultImage, scatterIcons, scatterIcons && suppressIconScatter == 0);
}
CHMethod1(void, SBUIController, restoreIconList, BOOL, blah)
{
	if(restoreIconListFlag > 0)
		return;
	
	return CHSuper1(SBUIController, restoreIconList, blah);
}

#pragma mark SpringBoard
CHMethod0(void, SpringBoard, _handleMenuButtonEvent)
{
	if ([[PSWViewController sharedInstance] isActive]) {
		// Deactivate and suppress SpringBoard list scrolling
		[[PSWViewController sharedInstance] setActive:NO];
		
		suppressIconListScroll++;
		CHSuper0(SpringBoard, _handleMenuButtonEvent);
		suppressIconListScroll--;
		
		return;
	}
	
	CHSuper0(SpringBoard, _handleMenuButtonEvent);
}

#pragma mark SBIconController
CHMethod2(void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (suppressIconListScroll > 0)
		return;
		
	CHSuper2(SBIconController, scrollToIconListAtIndex, index, animate, animate);
}
CHMethod1(void, SBIconController, setIsEditing, BOOL, isEditing)
{
	// Disable ProSwitcher when editing
	if (isEditing)
		[[PSWViewController sharedInstance] setActive:NO];
	
	CHSuper1(SBIconController, setIsEditing, isEditing);
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
			[self setAlpha:1.0f];
			PSWSnapshotView *ssv = [[[PSWViewController sharedInstance] snapshotPageView] focusedSnapshotView];
			UIWindow *window = [ssv window];
			UIView *screenView = [ssv screenView];
			CGRect translatedDestRect = [screenView convertRect:[screenView bounds] toView:window];
			CHSuper1(SBZoomView, setTransform, TransformRectToRect([self frame], translatedDestRect));
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

#pragma mark SBSearchView
CHMethod2(void, SBSearchView, setShowsKeyboard, BOOL, visible, animated, BOOL, animated)
{
	// Disable search view's keyboard when ProSwitcher is active
	CHSuper2(SBSearchView, setShowsKeyboard, visible && ![[PSWViewController sharedInstance] isActive], animated, animated);
}


CHConstructor
{
	CHAutoreleasePoolForScope();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferenceChangedCallback, CFSTR(PSWPreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CHLoadLateClass(SBAwayController);
	CHLoadLateClass(SBStatusBarController);
	CHLoadLateClass(SBApplication);
	CHHook0(SBApplication, activate);
	CHLoadLateClass(SBIconListPageControl);
	CHLoadLateClass(SBUIController);
	CHHook1(SBUIController, restoreIconList);
	CHHook3(SBUIController, animateApplicationActivation, animateDefaultImage, scatterIcons);
	CHLoadLateClass(SBApplicationController);
	CHLoadLateClass(SBIconModel);
	CHLoadLateClass(SpringBoard);
	CHHook0(SpringBoard, _handleMenuButtonEvent);
	CHLoadLateClass(SBIconController);
	CHHook2(SBIconController, scrollToIconListAtIndex, animate);
	CHHook1(SBIconController, setIsEditing);
	CHLoadLateClass(SBZoomView);
	CHHook1(SBZoomView, setTransform);
	CHLoadLateClass(SBSearchView);
	CHHook2(SBSearchView, setShowsKeyboard, animated);

	// Using late-binding until we get a simulator build for libactivator :(
	dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
	CHLoadLateClass(LAActivator);
	[CHSharedInstance(LAActivator) registerListener:[PSWViewController sharedInstance] forName:@"com.collab.proswitcher"];
}
