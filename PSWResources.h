#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

UIImage *PSWGetCachedImageResource(NSString *name, NSBundle *bundle);
UIImage *PSWGetScaledCachedImageResource(NSString *name, NSBundle *bundle, CGSize size);

UIImage *PSWImage(NSString *name);
UIImage *PSWScaledImage(NSString *name, CGSize size);

void PSWClearResourceCache();

UIImage *PSWGetCachedCornerMaskOfSize(CGSize size, CGFloat cornerRadius);

#define PSWGetCachedSpringBoardResource(name) PSWGetCachedImageResource(name, [NSBundle mainBundle])

