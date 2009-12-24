#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

SBDisplayStack *PSWGetDisplayStack(NSInteger index);

#define SBWPreActivateDisplayStack        PSWGetDisplayStack(0)
#define SBWActiveDisplayStack             PSWGetDisplayStack(1)
#define SBWSuspendingDisplayStack         PSWGetDisplayStack(2)
#define SBWSuspendedEventOnlyDisplayStack PSWGetDisplayStack(3)
