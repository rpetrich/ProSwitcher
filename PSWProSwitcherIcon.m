#import "PSWViewController.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

static BOOL isUninstalled = NO;

CHDeclareClass(SBApplicationIcon);
CHDeclareClass(PSWProSwitcherIcon);

#pragma mark SBApplicationIcon

CHMethod0(void, SBApplicationIcon, launch)
{
	if (!isUninstalled)
		[[PSWViewController sharedInstance] setActive:NO animated:NO];
	CHSuper0(SBApplicationIcon, launch);
}

#pragma mark PSWProSwitcherIcon

CHMethod0(void, PSWProSwitcherIcon, launch)
{
	if (!isUninstalled) {
		PSWViewController *vc = [PSWViewController sharedInstance];
		if (!vc.isAnimating)
			vc.active = !vc.active;
	}
}

CHMethod0(void, PSWProSwitcherIcon, completeUninstall)
{
	if (!isUninstalled) {
		[[PSWViewController sharedInstance] setActive:NO animated:NO];
		isUninstalled = YES;
	}
	CHSuper0(PSWProSwitcherIcon, completeUninstall);
}

CHConstructor {
	CHLoadLateClass(SBApplicationIcon);
	CHHook0(SBApplicationIcon, launch);
	CHRegisterClass(PSWProSwitcherIcon, SBApplicationIcon) {
		CHHook0(PSWProSwitcherIcon, launch);
		CHHook0(PSWProSwitcherIcon, completeUninstall);
	}
}
