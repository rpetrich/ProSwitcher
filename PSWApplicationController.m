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

static IOSurfaceAcceleratorRef accelerator;

static IOSurfaceRef CreateSurfaceCopyInMainMemory(IOSurfaceRef surface)
{
	if (!surface)
		return NULL;
	// Describe new surface
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedInteger:IOSurfaceGetWidth(surface)], kIOSurfaceWidth,
		[NSNumber numberWithUnsignedInteger:IOSurfaceGetHeight(surface)], kIOSurfaceHeight,
		[NSNumber numberWithUnsignedInteger:(NSUInteger)'L565'], kIOSurfacePixelFormat,
		[NSNumber numberWithUnsignedInteger:2], kIOSurfaceBytesPerElement,
		[NSNumber numberWithUnsignedInteger:kIOMapInhibitCache], kIOSurfaceCacheMode,
		kCFBooleanTrue, kIOSurfaceIsGlobal,
	nil];
	// Create accelerator
	if (accelerator == NULL) {
		IOSurfaceAcceleratorCreate(kCFAllocatorDefault, 2, &accelerator);
		if (accelerator == NULL)
			return (IOSurfaceRef)CFRetain(surface);
	}
	// Create new surface
	IOSurfaceRef newSurface = IOSurfaceCreate((CFDictionaryRef)dict);
	if (!newSurface)
		return (IOSurfaceRef)CFRetain(surface);
	// Transfer
	IOSurfaceAcceleratorTransferSurface(accelerator, surface, newSurface, NULL, NULL);
	return newSurface;
}

#pragma mark SBZoomView

// 3.0-3.1
CHOptimizedMethod2(self, id, SBZoomView, initWithSnapshotFrame, CGRect, snapshotFrame, ioSurface, IOSurfaceRef, surface)
{
	surface = CreateSurfaceCopyInMainMemory(surface);
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
	if (surface)
		CFRelease(surface);
	return self;
}

// 3.2
CHOptimizedMethod3(self, id, SBZoomView, initWithSnapshotFrame, CGRect, snapshotFrame, ioSurface, IOSurfaceRef, surface, transform, CGAffineTransform, transform)
{
	surface = CreateSurfaceCopyInMainMemory(surface);
	if ((self = CHSuper3(SBZoomView, initWithSnapshotFrame, snapshotFrame, ioSurface, surface, transform, transform))) {
		PSWApplication *application = [[PSWApplicationController sharedInstance] applicationWithDisplayIdentifier:[currentZoomApp displayIdentifier]];
		PSWCropInsets insets;
		insets.top = 0;
		insets.left = 0;
		insets.bottom = 0;
		insets.right = 0;
		PSWSnapshotRotation rotation;
		switch (CHIvar(CHSharedInstance(SBUIController), _orientation, UIInterfaceOrientation)) {
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
		[application loadSnapshotFromSurface:surface cropInsets:insets rotation:rotation];
	}
	if (surface)
		CFRelease(surface);
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
	CHHook3(SBZoomView, initWithSnapshotFrame, ioSurface, transform);
#endif
}


