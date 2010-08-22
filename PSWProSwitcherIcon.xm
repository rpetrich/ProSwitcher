#import "PSWProSwitcherIcon.h"

#import "PSWController.h"
#import "PSWPreferences.h"

#import "SpringBoard+OS32.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

CHDeclareClass(SBIconModel);
CHDeclareClass(SBApplicationIcon);
CHDeclareClass(PSWProSwitcherIcon);

#pragma mark SBApplicationIcon

CHMethod0(void, SBApplicationIcon, launch)
{
	[[PSWController sharedController] setActive:NO animated:NO];
	CHSuper0(SBApplicationIcon, launch);
}

#pragma mark PSWProSwitcherIcon

CHMethod0(void, PSWProSwitcherIcon, launch)
{
	PSWController *vc = [PSWController sharedController];
	if (!vc.isAnimating)
		vc.active = !vc.active;
}

CHConstructor {
	CHLoadLateClass(SBIconModel);
	CHLoadLateClass(SBApplicationIcon);
	CHHook0(SBApplicationIcon, launch);
	CHRegisterClass(PSWProSwitcherIcon, SBApplicationIcon) {
		CHHook0(PSWProSwitcherIcon, launch);
	}
}
