#import "PSWApplicationController.h"

#import <CaptainHook/CaptainHook.h>
#import <SpringBoard/SpringBoard.h>

#import "PSWApplication.h"
#import "PSWSpringBoardApplication.h"

CHDeclareClass(SBApplication);

#ifdef USE_IOSURFACE
#import <IOSurface/IOSurface.h>
CHDeclareClass(SBUIController)
CHDeclareClass(SBZoomView)
#endif

static PSWApplicationController *sharedApplicationController;

@implementation PSWApplicationController

@synthesize delegate = _delegate;

#pragma mark Public Methods

+ (PSWApplicationController *)sharedInstance
{
	if (!sharedApplicationController)
		sharedApplicationController = [[PSWApplicationController alloc] init];		
	return sharedApplicationController;
}

- (id)init
{
	if ((self = [super init])) {
		_activeApplications = [[NSMutableDictionary alloc] init];
		[_activeApplications setObject:[[PSWSpringBoardApplication alloc] init] forKey:@"com.apple.springboard"];
		[PSWApplication clearSnapshotCache];
	}
	return self;
}

- (void)dealloc
{
	[_activeApplications release];
	[super dealloc];
}

- (NSArray *)activeApplications
{
	return [_activeApplications allValues];
}

- (PSWApplication *)applicationWithDisplayIdentifier:(NSString *)displayIdentifier
{
	return [_activeApplications objectForKey:displayIdentifier];
}

- (void)writeSnapshotsToDisk
{
	for (PSWApplication *application in [_activeApplications allValues])
		[application writeSnapshotToDisk];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s %p activeApplications=%@ delegate=%@>", class_getName([self class]), self, [self activeApplications], _delegate];
}

#pragma mark Private Methods

- (void)_applicationDidLaunch:(SBApplication *)application
{
	NSString *displayIdentifier = [application displayIdentifier];
	if (![_activeApplications objectForKey:displayIdentifier]) {
		PSWApplication *app = [[PSWApplication alloc] initWithDisplayIdentifier:displayIdentifier];
		[_activeApplications setObject:app forKey:displayIdentifier];
		if ([_delegate respondsToSelector:@selector(applicationController:applicationDidLaunch:)])
			[_delegate applicationController:self applicationDidLaunch:app];
		[app release];
	}
}

- (void)_applicationDidExit:(SBApplication *)application
{
	NSString *displayIdentifier = [application displayIdentifier];
	PSWApplication *app = [_activeApplications objectForKey:displayIdentifier];
	if (app) {
		[app retain];
		[_activeApplications removeObjectForKey:displayIdentifier];
		if ([_delegate respondsToSelector:@selector(applicationController:applicationDidExit:)])
			[_delegate applicationController:self applicationDidExit:app];
		[app release];
	}
}

@end

#pragma mark SBApplication

CHMethod1(void, SBApplication, launchSucceeded, BOOL, flag)
{
	[[PSWApplicationController sharedInstance] _applicationDidLaunch:self];
    CHSuper1(SBApplication, launchSucceeded, flag);
}

CHMethod0(void, SBApplication, exitedCommon)
{
	[[PSWApplicationController sharedInstance] _applicationDidExit:self];
	CHSuper0(SBApplication, exitedCommon);
}

#ifdef USE_IOSURFACE

#pragma mark SBUIController

static SBApplication *currentZoomApp;
static UIWindow *currentZoomStatusWindow;

CHMethod2(void, SBUIController, showZoomLayerWithIOSurfaceSnapshotOfApp, SBApplication *, application, includeStatusWindow, UIWindow *, statusWindow)
{
	currentZoomApp = application;
	currentZoomStatusWindow = statusWindow;
	CHSuper2(SBUIController, showZoomLayerWithIOSurfaceSnapshotOfApp, application, includeStatusWindow, statusWindow);
	currentZoomStatusWindow = nil;
	currentZoomApp = nil;
}

#pragma mark SBZoomView

CHMethod2(id, SBZoomView, initWithSnapshotFrame, CGRect, snapshotFrame, ioSurface, IOSurfaceRef, surface)
{
	if ((self = CHSuper2(SBZoomView, initWithSnapshotFrame, snapshotFrame, ioSurface, surface))) {
		PSWApplication *application = [[PSWApplicationController sharedInstance] applicationWithDisplayIdentifier:[currentZoomApp displayIdentifier]];
		PSWCropInsets insets;
		insets.top = 0;
		insets.left = 0;
		insets.bottom = 0;
		insets.right = 0;
		if (currentZoomStatusWindow) {
			CGRect frame = [currentZoomStatusWindow frame];
			CGSize screenSize = [[UIScreen mainScreen] bounds].size;
			if (frame.origin.y + frame.size.height < screenSize.height / 2.0f)
				insets.top = frame.size.height;
			else if (frame.origin.x + frame.size.width < screenSize.width / 2.0f)
				insets.left = frame.size.width;
			else if (frame.size.width > frame.size.height)
				insets.bottom = frame.size.height;
			else
				insets.right = frame.size.width;
		}
		[application loadSnapshotFromSurface:surface cropInsets:insets];
	}
	return self;
}

#endif

CHConstructor {
	CHLoadLateClass(SBApplication);
	CHHook1(SBApplication, launchSucceeded);
	CHHook0(SBApplication, exitedCommon);
	
#ifdef USE_IOSURFACE
	CHLoadLateClass(SBUIController);
	CHHook2(SBUIController, showZoomLayerWithIOSurfaceSnapshotOfApp, includeStatusWindow);
	
	CHLoadLateClass(SBZoomView);
	CHHook2(SBZoomView, initWithSnapshotFrame, ioSurface);
#endif
}


