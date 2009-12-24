#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>

#import "PSWApplication.h"

@interface PSWSpringBoardApplication : PSWApplication {
}

+ (id)sharedInstance;
- (id)init;

@end

