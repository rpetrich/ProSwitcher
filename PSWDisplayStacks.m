#import "PSWDisplayStacks.h"

#import <CaptainHook/CaptainHook.h>

static NSMutableArray *displayStacks;

SBDisplayStack *PSWGetDisplayStack(NSInteger index)
{
	return [displayStacks objectAtIndex:index];
}

CHDeclareClass(SBDisplayStack);

CHMethod0(id, SBDisplayStack, init)
{
	if ((self = CHSuper0(SBDisplayStack, init))) {
		if (displayStacks)
			[displayStacks addObject:self];
		else
			displayStacks = [[NSMutableArray alloc] initWithObjects:self, nil];
	}
	return self;
}

CHMethod0(void, SBDisplayStack, dealloc)
{
	[displayStacks removeObject:self];
	CHSuper0(SBDisplayStack, dealloc);
}

CHConstructor
{
	CHLoadLateClass(SBDisplayStack);
	CHHook0(SBDisplayStack, init);
	CHHook0(SBDisplayStack, dealloc);
}
