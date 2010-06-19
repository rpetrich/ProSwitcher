#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

UIImage *PSWGetCachedImageResource(NSString *name, NSBundle *bundle);
UIImage *PSWGetScaledCachedImageResource(NSString *name, NSBundle *bundle, CGSize size);

UIImage *PSWImage(NSString *name);
UIImage *PSWScaledImage(NSString *name, CGSize size);

void PSWClearResourceCache();

UIImage *PSWGetCachedCornerMaskOfSize(CGSize size, CGFloat cornerRadius);

#define PSWGetCachedSpringBoardResource(name) PSWGetCachedImageResource(name, [NSBundle mainBundle])

NSString *PSWLocalize(NSString *text);

typedef enum {
	PSWHardwareTypeUnknown,
	PSWHardwareTypeiPhoneOriginal,
	PSWHardwareTypeiPodTouch1G,
	PSWHardwareTypeiPhone3G,
	PSWHardwareTypeiPodTouch2G,
	PSWHardwareTypeiPhone3GS,
	PSWHardwareTypeiPodTouch3G,
	PSWHardwareTypeiPad1G,
} PSWHardwareType;
// For convenience: newer models > older models

PSWHardwareType PSWGetHardwareType();
