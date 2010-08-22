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
#import "PSWController.h"

%class SpringBoard;
%class SBUIController;

static CGImageRef springBoardSnapshot = nil;
static PSWSpringBoardApplication *sharedSpringBoardApplication = nil;

@implementation PSWSpringBoardApplication

+ (id)sharedInstance
{
	if (!sharedSpringBoardApplication)
		sharedSpringBoardApplication = [[self alloc] init];
	return sharedSpringBoardApplication;
}

- (id)init
{
	return [super initWithDisplayIdentifier:@"com.apple.springboard"];
}

- (id)snapshot
{	
	return (id)springBoardSnapshot;
}

- (BOOL)writeSnapshotToDisk
{
	return NO;
}

- (SBApplicationIcon *)springBoardIcon
{
	return nil;
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
	[(SpringBoard *) [UIApplication sharedApplication] relaunchSpringBoard];
}

- (void)activateWithAnimation:(BOOL)animation
{
	[[PSWController sharedController] setActive:NO animated:animation];
}

- (SBIconBadge *)badgeView
{
	return nil;
}

- (NSString *)badgeText
{
	return nil;
}

- (NSString *)displayName
{
	return @"SpringBoard";
}

@end

%hook SBUIController
- (void)finishLaunching
{
	UIImage *springBoardImage = PSWImage(@"springboardsnapshot");
	if (springBoardImage) {
		springBoardSnapshot = CGImageRetain([springBoardImage CGImage]);
	} else {
		UIView *sbView = [self contentView];
		CGRect bounds = sbView.bounds;
		bounds.size.height -= 22.0f;
		UIGraphicsBeginImageContext(bounds.size);
		[[UIColor blackColor] set];
		UIRectFill(bounds);
		CGContextRef c = UIGraphicsGetCurrentContext();
		CGContextTranslateCTM(c, 0.0f, -22.0f);
		[sbView.layer renderInContext:c];
		UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
		UIGraphicsEndImageContext();
		springBoardSnapshot = CGImageRetain([viewImage CGImage]);
	}
	
	%orig;
}
%end

