#import "PSWViewController.h"

#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

#include <dlfcn.h>

#import "PSWDisplayStacks.h"
#import "PSWResources.h"

// Using Zero-link until we get a simulator build for libactivator :(
CHDeclareClass(LAActivator);

CHDeclareClass(SBIconListPageControl);
CHDeclareClass(SBUIController);
CHDeclareClass(SBApplicationController);
CHDeclareClass(SBIconModel);
CHDeclareClass(SBIconController);

static PSWViewController *mainController;
static NSInteger suppressIconScatter;

#define PSWPreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.collab.proswitcher.plist"]
#define PSWPreferencesChangedNotification "com.collab.proswitcher.preferencechanged"

#define idForKeyWithDefault(dict, key, default)	 ([(dict) objectForKey:(key)]?:(default))
#define floatForKeyWithDefault(dict, key, default)   ({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result floatValue]:(default); })
#define NSIntegerForKeyWithDefault(dict, key, default) (NSInteger)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result integerValue]:(default); })
#define BOOLForKeyWithDefault(dict, key, default)    (BOOL)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result boolValue]:(default); })

@implementation PSWViewController

#define GetPreference(name, type) type ## ForKeyWithDefault(preferences, @#name, name)

// Defaults
#define PSWShowDock             YES
#define PSWAnimateActive        YES
#define PSWDimBackground        YES
#define PSWShowPageControl      YES
#define PSWBackgroundStyle      0
#define PSWSwipeToClose         YES
#define PSWShowApplicationTitle YES
#define PSWShowCloseButton      YES
#define PSWShowEmptyText        YES
#define PSWRoundedCornerRadius  0.0f
#define PSWTapsToActivate       2
#define PSWSnapshotInset        40.0f

+ (PSWViewController *)sharedInstance
{
	if (!mainController)
		mainController = [[PSWViewController alloc] init];
	return mainController;
}

- (void)didFinishDeactivate
{
	[[UIApplication sharedApplication] setStatusBarStyle:formerStatusBarStyle animated:NO];
	[[self view] removeFromSuperview];
	isAnimating = NO;
}

- (void)didFinishActivate
{
	isAnimating = NO;
}

- (BOOL)isActive
{
	return isActive;
}

- (void)setActive:(BOOL)active animated:(BOOL)animated
{
	if (active) {
		if (isActive)
			return;
		UIApplication *app = [UIApplication sharedApplication];
		formerStatusBarStyle = [app statusBarStyle];
		[app setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
		isActive = YES;

		snapshotPageView.focusedApplication = focusedApplication;
		UIView *view = [self view];
		UIWindow *rootWindow = [CHSharedInstance(SBUIController) window];
		[rootWindow addSubview:view];
		// Find appropriate superview and add as subview
		UIView *buttonBar = [CHSharedInstance(SBIconModel) buttonBar];
		UIView *buttonBarParent = [buttonBar superview];
		UIView *superview = [buttonBarParent superview];
		if (GetPreference(PSWShowDock, BOOL))
			[superview insertSubview:view belowSubview:buttonBarParent];
		else
			[superview insertSubview:view aboveSubview:buttonBarParent];
		if (animated) {
			view.alpha = 0.0f;
			CALayer *layer = [snapshotPageView.scrollView layer];
			[layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:0.5f];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(didFinishActivate)];
			[layer setTransform:CATransform3DIdentity];
			[view setAlpha:1.0f];
			[UIView commitAnimations];
			isAnimating = YES;
		}
	} else {
		if (!isActive)
			return;
		isActive = NO;
		
		[focusedApplication release];
		focusedApplication = [snapshotPageView.focusedApplication retain];
		SBIconListPageControl *pageControl = CHIvar(CHSharedInstance(SBIconController), _pageControl, SBIconListPageControl *);
		UIView *view = [self view];
		if (animated) {
			CALayer *layer = [snapshotPageView.scrollView layer];
			[layer setTransform:CATransform3DIdentity];
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:0.5f];
			[UIView setAnimationDelegate:self];
			[UIView setAnimationDidStopSelector:@selector(didFinishDeactivate)];
			[layer setTransform:CATransform3DMakeScale(2.0f, 2.0f, 1.0f)];
			[view setAlpha:0.0f];
			[pageControl setAlpha:1.0f];
			[UIView commitAnimations];
			isAnimating = YES;
		} else {
			[[UIApplication sharedApplication] setStatusBarStyle:formerStatusBarStyle animated:NO];
			[pageControl setAlpha:1.0f];
			[view removeFromSuperview];
		}
	}
}

- (void)setActive:(BOOL)active
{
	[self setActive:active animated:GetPreference(PSWAnimateActive, BOOL)];
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	if (![self isAnimating])
		[self setActive:![self isActive]];
	[event setHandled:YES];
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event
{
	[self setActive:NO];
}

- (BOOL)isAnimating
{
	return isAnimating;
}

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

- (void)_applyPreferences
{
	self.view.backgroundColor = GetPreference(PSWDimBackground, BOOL) ? [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8]:[UIColor clearColor];
	
	if (GetPreference(PSWShowPageControl, BOOL)) {
		SBIconListPageControl *pageControl = CHIvar(CHSharedInstance(SBIconController), _pageControl, SBIconListPageControl *);
		[pageControl setAlpha:0.0f];
	}

	CGRect frame;
	frame.origin.x = 0.0f;
	frame.origin.y = 0.0f;
	frame.size.width = 320.0f;
	frame.size.height = GetPreference(PSWShowDock, BOOL) ? 370.0f : 460.0f;
	[snapshotPageView setFrame:frame];
	
	if (GetPreference(PSWBackgroundStyle, NSInteger) == 1)
		[[snapshotPageView layer] setContents:(id)[PSWGetCachedSpringBoardResource(@"ProSwitcherBackground") CGImage]];
	else
		[[snapshotPageView layer] setContents:nil];
	
	snapshotPageView.allowsSwipeToClose  = GetPreference(PSWSwipeToClose, BOOL);
	snapshotPageView.showsTitles         = GetPreference(PSWShowApplicationTitle, BOOL);
	snapshotPageView.showsCloseButtons   = GetPreference(PSWShowCloseButton, BOOL);
	snapshotPageView.emptyText           = GetPreference(PSWShowEmptyText, BOOL) ? @"No Apps Running":nil;
	snapshotPageView.roundedCornerRadius = GetPreference(PSWRoundedCornerRadius, float);
	snapshotPageView.tapsToActivate      = GetPreference(PSWTapsToActivate, NSInteger);
	snapshotPageView.snapshotInset       = GetPreference(PSWSnapshotInset, float);
}

- (void)_reloadPreferences
{
	[preferences release];
	preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
	[self _applyPreferences];
}

- (void)loadView 
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 20.0f, 320.0f, 460.0f)];
	
	snapshotPageView = [[PSWSnapshotPageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 370.0f) applicationController:[PSWApplicationController sharedInstance]];
	[snapshotPageView setDelegate:self];
	[view addSubview:snapshotPageView];
	
	[self setView:view];
	[self _applyPreferences];
}

- (void)viewDidUnload
{
	[[PSWApplicationController sharedInstance] writeSnapshotsToDisk];
	PSWClearResourceCache();
	[snapshotPageView removeFromSuperview];
	[snapshotPageView release];
	snapshotPageView = nil;
	[super viewDidUnload];
}

- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didSelectApplication:(PSWApplication *)application
{
	suppressIconScatter++;
	[application activate];
	suppressIconScatter--;
}

- (void)snapshotPageView:(PSWSnapshotPageView *)snapshotPageView didCloseApplication:(PSWApplication *)application
{
	[application exit];
}

- (void)snapshotPageViewShouldExit:(PSWSnapshotPageView *)snapshotPageView
{
	[self setActive:NO];
}

@end

CHDeclareClass(SBApplication)

CHMethod0(void, SBApplication, activate)
{
	[[PSWViewController sharedInstance] setActive:NO];
	CHSuper0(SBApplication, activate);
}

CHMethod3(void, SBUIController, animateApplicationActivation, SBApplication *, application, animateDefaultImage, BOOL, animateDefaultImage, scatterIcons, BOOL, scatterIcons)
{
	CHSuper3(SBUIController, animateApplicationActivation, application, animateDefaultImage, animateDefaultImage, scatterIcons, scatterIcons && suppressIconScatter == 0);
}

static void PreferenceChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	[[PSWViewController sharedInstance] _reloadPreferences];
}

CHConstructor
{
	CHAutoreleasePoolForScope();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferenceChangedCallback, CFSTR(PSWPreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CHLoadLateClass(SBApplication);
	CHHook0(SBApplication, activate);
	CHLoadLateClass(SBIconListPageControl);
	CHLoadLateClass(SBUIController);
	CHHook3(SBUIController, animateApplicationActivation, animateDefaultImage, scatterIcons);
	CHLoadLateClass(SBApplicationController);
	CHLoadLateClass(SBIconModel);
	CHLoadLateClass(SBIconController);
	
	// Using Zero-link until we get a simulator build for libactivator :(
	// note to self: Zero-link means late-binding
	dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
	CHLoadLateClass(LAActivator);
	[CHSharedInstance(LAActivator) registerListener:[PSWViewController sharedInstance] forName:@"com.collab.proswitcher"];
}
