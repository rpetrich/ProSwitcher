#import "PSWViewController.h"

#import <QuartzCore/QuartzCore.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWDisplayStacks.h"
#import "PSWResources.h"

CHDeclareClass(SBIconListPageControl)
CHDeclareClass(SBUIController)
CHDeclareClass(SBApplicationController)

static PSWViewController *mainController;
static SBIconListPageControl *pageControl;
static NSInteger suppressIconScatter;

#define PSWPreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.collab.proswitcher.plist"]
#define PSWPreferencesChangedNotification "com.collab.proswitcher.preferencechanged"

#define ObjectForKeyWithDefault(dict, key, default)	 ([(dict) objectForKey:(key)]?:(default))
#define FloatForKeyWithDefault(dict, key, default)   ({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result floatValue]:(default); })
#define IntegerForKeyWithDefault(dict, key, default) (NSInteger)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result integerValue]:(default); })
#define BoolForKeyWithDefault(dict, key, default)    (BOOL)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result boolValue]:(default); })

static UIView *FindViewOfClassInViewHeirarchy(UIView *superview, Class class)
{
	for (UIView *view in superview.subviews) {
		if ([view isKindOfClass:class])
			return view;
		else {
			UIView *result = FindViewOfClassInViewHeirarchy(view, class);
			if (result)
				return result;
		}
	}
	return nil;
}

@implementation PSWViewController

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
	if (active && !isActive) {
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
	[self setActive:active animated:BoolForKeyWithDefault(preferences, @"PSWAnimateActive", YES)];
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
	self.view.backgroundColor =
	BoolForKeyWithDefault(preferences, @"PSWDimBackground", YES)
	?[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.8]
	:[UIColor clearColor];
	
	if (BoolForKeyWithDefault(preferences, @"PSWShowPageControl", YES)) {
		UIWindow *rootWindow = [CHSharedInstance(SBUIController) window];
		if (!pageControl)
			pageControl = [(SBIconListPageControl *)FindViewOfClassInViewHeirarchy(rootWindow, CHClass(SBIconListPageControl)) retain];
		[pageControl setAlpha:0.0f];
	}
	
	if (IntegerForKeyWithDefault(preferences, @"PSWBackgroundStyle", 0) == 1)
		[[snapshotPageView layer] setContents:(id)[PSWGetCachedSpringBoardResource(@"ProSwitcherBackground") CGImage]];
	
	snapshotPageView.allowsSwipeToClose  = BoolForKeyWithDefault(preferences, @"PSWSwipeToClose", YES);
	snapshotPageView.showsTitles         = BoolForKeyWithDefault(preferences, @"PSWShowApplicationTitle", YES);
	snapshotPageView.showsCloseButtons   = BoolForKeyWithDefault(preferences, @"PSWShowCloseButton", YES);
	snapshotPageView.emptyText           = BoolForKeyWithDefault(preferences, @"PSWShowEmptyText", YES) ? @"No Apps Running":nil;
	snapshotPageView.roundedCornerRadius = FloatForKeyWithDefault(preferences, @"PSWRoundedCornerRadius", 0.0f);
	snapshotPageView.tapsToActivate      = IntegerForKeyWithDefault(preferences, @"PSWTapsToActivate", 2);
}

- (void)_reloadPreferences
{
	[preferences release];
	preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
	[self _applyPreferences];
}

- (void)loadView 
{
	UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 20.0f, 320.0f, 370.0f)];
	
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
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, PreferenceChangedCallback, CFSTR(PSWPreferencesChangedNotification), NULL, CFNotificationSuspensionBehaviorCoalesce);
	CHLoadLateClass(SBApplication);
	CHHook0(SBApplication, activate);
	CHLoadLateClass(SBIconListPageControl);
	CHLoadLateClass(SBUIController);
	CHHook3(SBUIController, animateApplicationActivation, animateDefaultImage, scatterIcons);
	CHLoadLateClass(SBApplicationController);
}
