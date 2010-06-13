#import "PSWProSwitcherIcon.h"

#import "PSWController.h"
#import "PSWPreferences.h"

#import "SpringBoard+OS32.h"

#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

static BOOL isUninstalled = NO;

CHDeclareClass(SBIconModel);
CHDeclareClass(SBApplicationIcon);
CHDeclareClass(PSWProSwitcherIcon);

void PSWUpdateIconVisibility()
{
	SBIconModel *iconModel = CHSharedInstance(SBIconModel);
	[iconModel setVisibilityOfIconsWithVisibleTags:[CHIvar(iconModel, _visibleIconTags, NSSet *) allObjects]  hiddenTags:[CHIvar(iconModel, _hiddenIconTags, NSSet *) allObjects]];
	if (GetPreference(PSWShowIcon, BOOL)) {
		SBIcon *icon = [iconModel iconForDisplayIdentifier:@"com.collab.proswitcher"];
		if ([iconModel iconListContainingIcon:icon] == nil) {
			[icon setShowsImages:YES];
			for (SBIconList *iconList in [iconModel iconLists]) {
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_2
				if ([iconList respondsToSelector:@selector(firstFreeSlotIndex:)] && [iconList respondsToSelector:@selector(placeIcon:atIndex:animate:moveNow:)]) {
#endif
					int index;
					if ([iconList firstFreeSlotIndex:&index]) {
						[iconList placeIcon:icon atIndex:index animate:NO moveNow:YES];
						return;
					}
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_2
				} else {
					int x, y;
					if ([iconList firstFreeSlotX:&x Y:&y]) {
						[iconList placeIcon:icon atX:x Y:y animate:NO moveNow:YES];
						return;
					}
				}
#endif
			}
			SBIconList *emptyList = [iconModel addEmptyIconList];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_2
			if ([emptyList respondsToSelector:@selector(placeIcon:atIndex:animate:moveNow:)])
#endif
				[emptyList placeIcon:icon atIndex:0 animate:NO moveNow:YES];
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_3_2
			else
				[emptyList placeIcon:icon atX:0 Y:0 animate:NO moveNow:YES];
#endif
		}
	}
}

#pragma mark SBIconModel
CHOptimizedMethod(2, self, void, SBIconModel, setVisibilityOfIconsWithVisibleTags, NSArray *, visibleTags, hiddenTags, NSArray *, hiddenTags)
{
	PSWPreparePreferences();
	if (GetPreference(PSWShowIcon, BOOL))
		visibleTags = [visibleTags arrayByAddingObject:@"com.collab.proswitcher"];
	else
		hiddenTags = [hiddenTags arrayByAddingObject:@"com.collab.proswitcher"];
	CHSuper(2, SBIconModel, setVisibilityOfIconsWithVisibleTags, visibleTags, hiddenTags, hiddenTags);
}

#pragma mark SBApplicationIcon

CHOptimizedMethod(0, self, void, SBApplicationIcon, launch)
{
	if (!isUninstalled)
		[[PSWController sharedController] setActive:NO animated:NO];
	CHSuper(0, SBApplicationIcon, launch);
}

#pragma mark PSWProSwitcherIcon

CHOptimizedMethod(0, super, void, PSWProSwitcherIcon, launch)
{
	if (!isUninstalled) {
		PSWController *vc = [PSWController sharedController];
		if (!vc.isAnimating)
			vc.active = !vc.active;
	}
}

CHOptimizedMethod(0, super, void, PSWProSwitcherIcon, completeUninstall)
{
	if (!isUninstalled) {
		[[PSWController sharedController] setActive:NO animated:NO];
		isUninstalled = YES;
	}
	CHSuper(0, PSWProSwitcherIcon, completeUninstall);
}


CHConstructor
{
	CHLoadLateClass(SBIconModel);
	CHHook2(SBIconModel, setVisibilityOfIconsWithVisibleTags, hiddenTags);
	CHLoadLateClass(SBApplicationIcon);
	CHHook0(SBApplicationIcon, launch);
	CHRegisterClass(PSWProSwitcherIcon, SBApplicationIcon) {
		CHHook0(PSWProSwitcherIcon, launch);
		CHHook0(PSWProSwitcherIcon, completeUninstall);
	}
}
