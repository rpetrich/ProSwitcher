#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

UIImage *PSWGetCachedImageResource(NSString *name, NSBundle *bundle);
UIImage *PSWGetCachedCornerMaskOfSize(CGSize size, CGFloat cornerRadius);
void PSWClearResourceCache();

#define PSWGetCachedSpringBoardResource(name) PSWGetCachedImageResource(name, [NSBundle mainBundle])
#define PSWImage(name) PSWGetCachedImageResource(name, [NSBundle bundleWithPath:@"/Applications/ProSwitcher.app"])
