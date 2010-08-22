#import "PSWProSwitcherIcon.h"

#import "PSWController.h"
#import "PSWPreferences.h"

#import "SpringBoard+OS32.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

%class SBIconModel;
%class SBApplicationIcon;
CHDeclareClass(PSWProSwitcherIcon);

%hook SBApplicationIcon

- (void)launch
{
	[[PSWController sharedController] setActive:NO animated:NO];
	%orig;
}

%end

%subclass PSWProSwitcherIcon : SBApplicationIcon
- (void)launch
{
	PSWController *vc = [PSWController sharedController];
	if (!vc.isAnimating)
		vc.active = !vc.active;
}
%end
