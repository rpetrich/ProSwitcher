#import "PSWDisplayStacks.h"

#import <CaptainHook/CaptainHook.h>

static NSMutableArray *displayStacks;

SBDisplayStack *PSWGetDisplayStack(NSInteger index)
{
	return [displayStacks objectAtIndex:index];
}

CHDeclareClass(SBDisplayStack);

CHOptimizedMethod(0, self, id, SBDisplayStack, init)
{
	if ((self = CHSuper0(SBDisplayStack, init))) {
		[displayStacks addObject:self];
	}
	return self;
}

CHOptimizedMethod(0, self, void, SBDisplayStack, dealloc)
{
	[displayStacks removeObject:self];
	CHSuper0(SBDisplayStack, dealloc);
}

CHConstructor
{
	displayStacks = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	CHLoadLateClass(SBDisplayStack);
	CHHook0(SBDisplayStack, init);
	CHHook0(SBDisplayStack, dealloc);
}
