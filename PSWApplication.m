#import "PSWApplication.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>
#import "SpringBoard+Backgrounder.h"

#import "PSWDisplayStacks.h"

CHDeclareClass(SBApplicationController);
CHDeclareClass(SBApplicationIcon);
CHDeclareClass(SBIconModel);

CHConstructor {
	CHLoadLateClass(SBApplicationController);
	CHLoadLateClass(SBApplicationIcon);
	CHLoadLateClass(SBIconModel);
}

static NSString *ignoredRelaunchDisplayIdentifier;

@implementation PSWApplication

@synthesize displayIdentifier = _displayIdentifier;
@synthesize application = _application;
@synthesize delegate = _delegate;

+ (NSString *)snapshotPath
{
	return [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/"];
}

+ (void)clearSnapshotCache
{
	NSString *snapshotPath = [self snapshotPath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for (NSString *path in [fileManager contentsOfDirectoryAtPath:snapshotPath error:NULL])
		if ([snapshotPath hasPrefix:@"ProSwitcher-"] && [snapshotPath hasSuffix:@".cache"])
			[fileManager removeItemAtPath:[snapshotPath stringByAppendingPathComponent:snapshotPath] error:NULL];
}

- (id)initWithDisplayIdentifier:(NSString *)displayIdentifier
{
	if ((self = [super init])) {
		_application = [[CHSharedInstance(SBApplicationController) applicationWithDisplayIdentifier:displayIdentifier] retain];
		_displayIdentifier = [displayIdentifier copy];
	}
	return self;
}

- (id)initWithSBApplication:(SBApplication *)application
{
	if ((self = [super init])) {
		_application = [application retain];
		_displayIdentifier = [[application displayIdentifier] copy];
	}
	return self;
}

- (void)dealloc
{
	[_displayIdentifier release];
	CGImageRelease(_snapshotImage);
	[_snapshotData release];
	if (_snapshotFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:_snapshotFilePath error:NULL];
		[_snapshotFilePath release];
	}		
	[super dealloc];
}

- (CGImageRef)snapshot
{
	if (!_snapshotImage) {
		BOOL something = NO;
		_snapshotImage = CGImageRetain([[_application defaultImage:&something] CGImage]);
	}
	return _snapshotImage;
}

- (void)setSnapshot:(CGImageRef)snapshot
{
	if (_snapshotImage != snapshot) {
		CGImageRelease(_snapshotImage);
		_snapshotImage = CGImageRetain(snapshot);
		[_snapshotData release];
		_snapshotData = nil;
		if (_snapshotFilePath) {
			[[NSFileManager defaultManager] removeItemAtPath:_snapshotFilePath error:NULL];
			[_snapshotFilePath release];
			_snapshotFilePath = nil;
		}
		if ([_delegate respondsToSelector:@selector(applicationSnapshotDidChange:)])
			[_delegate applicationSnapshotDidChange:self];
	}
}

- (NSString *)displayName
{
	return [_application displayName];
}

- (void)loadSnapshotFromBuffer:(void *)buffer width:(NSUInteger)width height:(NSUInteger)height stride:(NSUInteger)stride
{
	CGImageRelease(_snapshotImage);
	if (_snapshotFilePath) {
		[[NSFileManager defaultManager] removeItemAtPath:_snapshotFilePath error:NULL];
		[_snapshotFilePath release];
		_snapshotFilePath = nil;
	}		
	[_snapshotData release];
	_snapshotData = [[NSData alloc] initWithBytes:buffer length:(height * stride)];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate((void *)[_snapshotData bytes], width, height, 8, stride, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(colorSpace);
	_snapshotImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	if ([_delegate respondsToSelector:@selector(applicationSnapshotDidChange:)])
		[_delegate applicationSnapshotDidChange:self];
}

- (id)loadSBIcon
{
	return [CHSharedInstance(SBIconModel) iconForDisplayIdentifier:_displayIdentifier];
}

- (void)exit
{
	if ([_displayIdentifier isEqualToString:@"com.apple.mobilephone"] || [_displayIdentifier isEqualToString:@"com.apple.mobilemail"] || [_displayIdentifier isEqualToString:@"com.apple.mobilesafari"] || [_displayIdentifier hasPrefix:@"com.apple.mobileipod"] || [_displayIdentifier isEqualToString:@"com.googlecode.mobileterminal"]) {
		[ignoredRelaunchDisplayIdentifier release];
		ignoredRelaunchDisplayIdentifier = [_displayIdentifier retain];
		[_application kill];
	} else {
		UIApplication *sharedApp = [UIApplication sharedApplication];
		if ([sharedApp respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
			[sharedApp setBackgroundingEnabled:NO forDisplayIdentifier:_displayIdentifier];
		if ([SBWActiveDisplayStack containsDisplay:_application]) {
			[_application setDeactivationSetting:0x2 flag:YES]; // animate
			[SBWActiveDisplayStack popDisplay:_application];
		} else {
			[_application setDeactivationSetting:0x2 flag:NO]; // don't animate
		}
		// Deactivate the application
		[SBWSuspendingDisplayStack pushDisplay:_application];
	}
}

- (void)activate
{
	SBApplication *fromApp = [SBWActiveDisplayStack topApplication];
	NSString *fromIdent = fromApp ? [fromApp displayIdentifier] : @"com.apple.springboard";
	if (![fromIdent isEqualToString:_displayIdentifier]) {
		// App to switch to is not the current app
		// NOTE: Save the identifier for later use
		//deactivatingApp = [fromIdent copy];
		
		if ([fromIdent isEqualToString:@"com.apple.springboard"]) {
			// Switching from SpringBoard; simply activate the target app
			[_application setDisplaySetting:0x4 flag:YES]; // animate
			// Activate the target application
			[SBWPreActivateDisplayStack pushDisplay:_application];
		} else {
			// Switching from another app
			if (![_displayIdentifier isEqualToString:@"com.apple.springboard"]) {
				// Switching to another app; setup app-to-app
				[_application setActivationSetting:0x40 flag:YES]; // animateOthersSuspension
				[_application setActivationSetting:0x20000 flag:YES]; // appToApp
				[_application setDisplaySetting:0x4 flag:YES]; // animate
				
				// Activate the target application (will wait for
				// deactivation of current app)
				[SBWPreActivateDisplayStack pushDisplay:_application];
			}
			
			// Deactivate the current application
			
			// If Backgrounder is installed, enable backgrounding for current application
			UIApplication *sharedApp = [UIApplication sharedApplication];
			if ([sharedApp respondsToSelector:@selector(setBackgroundingEnabled:forDisplayIdentifier:)])
				[sharedApp setBackgroundingEnabled:YES forDisplayIdentifier:fromIdent];
			
			// NOTE: Must set animation flag for deactivation, otherwise
			// application window does not disappear (reason yet unknown)
			[fromApp setDeactivationSetting:0x2 flag:YES]; // animate
			
			// Deactivate by moving from active stack to suspending stack
			[SBWActiveDisplayStack popDisplay:fromApp];
			[SBWSuspendingDisplayStack pushDisplay:fromApp];
		}
	}
}

- (void)writeSnapshotToDisk
{
	if (!_snapshotFilePath) {
		// Generate filename
		CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
		CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid);
		CFRelease(uuid);
		NSString *fileName = [NSString stringWithFormat:@"ProSwitcher-%@.cache", uuidString];
		CFRelease(uuidString);
		_snapshotFilePath = [[PSWApplication snapshotPath] stringByAppendingPathComponent:fileName];
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		size_t width = CGImageGetWidth(_snapshotImage);
		size_t height = CGImageGetHeight(_snapshotImage);
		size_t stride = CGImageGetBytesPerRow(_snapshotImage);
		if (_snapshotData) {
			[_snapshotData writeToFile:_snapshotFilePath atomically:NO];
			[_snapshotData release];
		} else {
			NSMutableData *tempData = [[NSMutableData alloc] init];
			[tempData setLength:(height * stride)];
			CGContextRef tempContext = CGBitmapContextCreate([tempData mutableBytes], width, height, 8, stride, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
			CGContextDrawImage(tempContext, CGRectMake(0.0f, 0.0f, width, height), _snapshotImage);
			CGContextRelease(tempContext);
			[tempData writeToFile:_snapshotFilePath atomically:NO];
			[tempData release];
		}
		_snapshotData = [[NSData alloc] initWithContentsOfMappedFile:_snapshotFilePath];
		CGContextRef context = CGBitmapContextCreate((void *)[_snapshotData bytes], width, height, 8, stride, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
		CGColorSpaceRelease(colorSpace);
		CGImageRelease(_snapshotImage);
		_snapshotImage = CGBitmapContextCreateImage(context);
		CGContextRelease(context);
		if ([_delegate respondsToSelector:@selector(applicationSnapshotDidChange:)])
			[_delegate applicationSnapshotDidChange:self];
	}
}

@end

CHDeclareClass(SBApplication)

CHMethod1(void, SBApplication, _relaunchAfterAbnormalExit, BOOL, something)
{
	if ([[self displayIdentifier] isEqualToString:ignoredRelaunchDisplayIdentifier]) {
		[ignoredRelaunchDisplayIdentifier release];
		ignoredRelaunchDisplayIdentifier = nil;
	} else {
		CHSuper1(SBApplication, _relaunchAfterAbnormalExit, something);
	}
}

CHConstructor {
	CHLoadLateClass(SBApplication);
	CHHook1(SBApplication, _relaunchAfterAbnormalExit);
}

