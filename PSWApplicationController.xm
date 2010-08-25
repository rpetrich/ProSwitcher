#import "PSWApplicationController.h"

#import <SpringBoard/SpringBoard.h>

#import "PSWApplication.h"
#import "PSWSpringBoardApplication.h"
#import "PSWSurface.h"

#ifdef USE_IOSURFACE
#import <IOSurface/IOSurface.h>
%class SBUIController;
%class SBZoomView;
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
		PSWSpringBoardApplication *springBoardApp = [[[PSWSpringBoardApplication alloc] init] autorelease];
		[_activeApplications setObject:springBoardApp forKey:@"com.apple.springboard"];
		_activeApplicationsOrder = [[NSMutableArray alloc] initWithObjects:springBoardApp, nil];
		[PSWApplication clearSnapshotCache];
	}
	return self;
}

- (void)dealloc
{
	[_activeApplicationsOrder release];
	[_activeApplications release];
	[super dealloc];
}

- (NSArray *)activeApplications
{
	return [[_activeApplicationsOrder copy] autorelease];
}

- (PSWApplication *)applicationWithDisplayIdentifier:(NSString *)displayIdentifier
{
	return [_activeApplications objectForKey:displayIdentifier];
}

- (void)writeSnapshotsToDisk
{
	for (PSWApplication *application in _activeApplicationsOrder)
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
		[_activeApplicationsOrder addObject:app];
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
		[_activeApplicationsOrder removeObject:app];
		if ([_delegate respondsToSelector:@selector(applicationController:applicationDidExit:)])
			[_delegate applicationController:self applicationDidExit:app];
		[app release];
	}
}

@end

%hook SBApplication

- (void)launchSucceeded:(BOOL)flag
{
	[[PSWApplicationController sharedInstance] _applicationDidLaunch:self];
	%orig;
}

- (void)exitedCommon
{
	[[PSWApplicationController sharedInstance] _applicationDidExit:self];
	%orig;
}

%end

#ifdef USE_IOSURFACE

static SBApplication *currentZoomApp;
static UIWindow *currentZoomStatusWindow;

%hook SBUIController

- (void)showZoomLayerWithIOSurfaceSnapshotOfApp:(SBApplication *)application includeStatusWindow:(UIWindow *)statusWindow
{
	currentZoomApp = application;
	currentZoomStatusWindow = statusWindow;
	%orig;
	currentZoomStatusWindow = nil;
	currentZoomApp = nil;
}

%end

%hook SBZoomView

// 3.0-3.1
- (id)initWithSnapshotFrame:(CGRect)snapshotFrame ioSurface:(IOSurfaceRef)surface
{
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
	surface = [application loadSnapshotFromSurface:surface cropInsets:insets];
	return %orig;
}

// 3.2
- (id)initWithSnapshotFrame:(CGRect)snapshotFrame ioSurface:(IOSurfaceRef)surface transform:(CGAffineTransform)transform
{
	PSWApplication *application = [[PSWApplicationController sharedInstance] applicationWithDisplayIdentifier:[currentZoomApp displayIdentifier]];
	PSWCropInsets insets;
	insets.top = 0;
	insets.left = 0;
	insets.bottom = 0;
	insets.right = 0;
	PSWSnapshotRotation rotation;
	switch (MSHookIvar<UIInterfaceOrientation>([$SBUIController sharedInstance], "_orientation")) {
		case UIInterfaceOrientationPortrait:
			rotation = PSWSnapshotRotation90Left;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			rotation = PSWSnapshotRotation90Right;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			rotation = PSWSnapshotRotation180;
			break;
		case UIInterfaceOrientationLandscapeRight:
		default:
			rotation = PSWSnapshotRotationNone;
			break;
	}
	surface = [application loadSnapshotFromSurface:surface cropInsets:insets rotation:rotation];
	return %orig;
}

%end

#endif
