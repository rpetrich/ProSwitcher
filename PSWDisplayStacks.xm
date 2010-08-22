#import "PSWDisplayStacks.h"

#import <CaptainHook/CaptainHook.h>

static NSMutableArray *displayStacks;

SBDisplayStack *PSWGetDisplayStack(NSInteger index)
{
	return [displayStacks objectAtIndex:index];
}

%class SBDisplayStack;

%hook SBDisplayStack 

- (id)init
{
	if ((self = %orig)) {
		[displayStacks addObject:self];
	}
	return self;
}

- (void)dealloc
{
	[displayStacks removeObject:self];
	%orig;
}

%end

__attribute__((constructor)) static void displaystack_init()
{
	displayStacks = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	%init;
}
