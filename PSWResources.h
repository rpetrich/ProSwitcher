#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

UIImage *PSWGetCachedImageResource(NSString *name, NSBundle *bundle);
void PSWClearResourceCache();

#define PSWGetCachedSpringBoardResource(name) PSWGetCachedImageResource(name, [NSBundle mainBundle])
