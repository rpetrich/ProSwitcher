#import "PSWApplication.h"

#include <unistd.h>

#import <SpringBoard/SpringBoard.h>
#import <QuartzCore/QuartzCore.h>
#import <CaptainHook/CaptainHook.h>
#import "SpringBoard+Backgrounder.h"

#import "PSWSpringBoardApplication.h"
#import "PSWResources.h"
#import "PSWDisplayStacks.h"
#import "PSWApplicationController.h"
#import "PSWViewController.h"

CHDeclareClass(SpringBoard);
CHDeclareClass(SBUIController);

static CGImageRef springBoardSnapshot = nil;
static PSWSpringBoardApplication *sba = nil;

@implementation PSWSpringBoardApplication
@synthesize displayName = _displayName;

+ (id) sharedInstance
{
	if (sba == nil)
		sba = [[self alloc] init];
	return sba;
}

- (id) init
{
	if ((self = [super init])) {
		_application = nil;
		_displayIdentifier = [[NSString alloc] initWithString:@"com.apple.springboard"];
		_displayName = @"SpringBoard";
		sba = self;
	}
	return self;
}

- (id)initWithDisplayIdentifier:(NSString *)displayIdentifier
{
	return [self init];
}

- (id)initWithSBApplication:(SBApplication *)application
{
	return [self init];
}

- (CGImageRef)snapshot
{	
	return springBoardSnapshot;
}

- (BOOL)writeSnapshotToDisk
{
	return NO;
}

- (SBApplicationIcon *)springBoardIcon
{
	return nil;
}

- (NSString *)displayIdentifier
{
	return _displayIdentifier;
}

- (UIImage *)themedIcon
{
	return PSWImage(@"springboard");
}

- (UIImage *)unthemedIcon
{
	return [self themedIcon];
}

- (BOOL)hasNativeBackgrounding
{
	return YES;
}

- (void)exit
{
	[CHSharedInstance(SpringBoard) relaunchSpringBoard];
}

- (void)activateWithAnimation:(BOOL)animation
{
	[[PSWViewController sharedInstance] setActive:NO animated:animation];
}

- (void)activate
{
	[self activateWithAnimation:YES];
}

- (SBIconBadge *)badgeView
{
	return nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%s %p %@>", class_getName([self class]), self, _displayIdentifier];
}

@end

#pragma mark SBUIController
CHMethod0(void, SBUIController, finishLaunching)
{
	UIView *sbView = [self contentView];
	UIGraphicsBeginImageContext(sbView.bounds.size);
	[sbView.layer renderInContext:UIGraphicsGetCurrentContext()];
	UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	springBoardSnapshot = CGImageRetain([viewImage CGImage]);
	
	CHSuper0(SBUIController, finishLaunching);
}

CHConstructor {
	CHLoadLateClass(SpringBoard);
	CHLoadLateClass(SBUIController);
	CHHook0(SBUIController, finishLaunching);
}

