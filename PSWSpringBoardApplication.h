#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>

#import "PSWApplication.h"

@interface PSWSpringBoardApplication : PSWApplication {
@private
	NSString *_displayName;
}

+ (id)sharedInstance;
- (id)init;

@end

