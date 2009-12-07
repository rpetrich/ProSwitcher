#import <UIKit/UIKit.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWViewController.h"

static BOOL isUninstalled = NO;

CHDeclareClass(SBApplicationIcon);
CHDeclareClass(PSWPreSwitcherIcon);
CHDeclareClass(SpringBoard);
CHDeclareClass(SBIconController);


CHMethod0(void, SBApplicationIcon, launch)
{
	if (!isUninstalled)
		[[PSWViewController sharedInstance] setActive:NO animated:NO];
	CHSuper0(SBApplicationIcon, launch);
}

CHMethod0(void, PSWPreSwitcherIcon, launch)
{
	if (!isUninstalled) {
		PSWViewController *vc = [PSWViewController sharedInstance];
		if (!vc.isAnimating)
			vc.active = !vc.active;
	}
}

CHMethod0(void, PSWPreSwitcherIcon, completeUninstall)
{
	if (!isUninstalled) {
		[[PSWViewController sharedInstance] setActive:NO animated:NO];
		isUninstalled = YES;
	}
	CHSuper0(PSWPreSwitcherIcon, completeUninstall);
}

static BOOL shouldSuppressIconListScroll;

CHMethod0(void, SpringBoard, _handleMenuButtonEvent)
{
	[[PSWViewController sharedInstance] setActive:NO];
	shouldSuppressIconListScroll = YES;
	CHSuper0(SpringBoard, _handleMenuButtonEvent);
	shouldSuppressIconListScroll = NO;
}

CHMethod2(void, SBIconController, scrollToIconListAtIndex, NSInteger, index, animate, BOOL, animate)
{
	if (!shouldSuppressIconListScroll)
		CHSuper2(SBIconController, scrollToIconListAtIndex, index, animate, animate);
}

CHConstructor {
	CHLoadLateClass(SBApplicationIcon);
	CHHook0(SBApplicationIcon, launch);
	CHRegisterClass(PSWPreSwitcherIcon, SBApplicationIcon) {
		CHHook0(PSWPreSwitcherIcon, launch);
		CHHook0(PSWPreSwitcherIcon, completeUninstall);
	}
	CHLoadLateClass(SpringBoard);
	CHHook0(SpringBoard, _handleMenuButtonEvent);
	CHLoadLateClass(SBIconController);
	CHHook2(SBIconController, scrollToIconListAtIndex, animate);
}