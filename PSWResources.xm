#import "PSWResources.h"

#import <CoreGraphics/CoreGraphics.h>

#include <sys/types.h>
#include <sys/sysctl.h>

static NSMutableDictionary *imageCache;
static NSBundle *sharedBundle;
static NSBundle *localizationBundle;

@interface UIScreen (OS40)
- (CGFloat)scale;
@end

@interface UIImage (OS40)
+ (UIImage *)imageWithCGImage:(CGImageRef)imageRef scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
@end

static inline void PSWSetCachedImageForKey(UIImage *image, NSString *key)
{
	if (imageCache)
		[imageCache setObject:image forKey:key];
	else
		imageCache = [[NSMutableDictionary alloc] initWithObjectsAndKeys:image, key, nil];
}

UIImage *PSWGetCachedImageResource(NSString *name, NSBundle *bundle)
{
	NSString *key = [NSString stringWithFormat:@"%@#%@", [bundle bundlePath], name];
	UIImage *result = [imageCache objectForKey:key];
	if (result)
		return result;
	if ([UIScreen instancesRespondToSelector:@selector(scale)]) {
		CGFloat scale = [[UIScreen mainScreen] scale];
		if (scale != 1.0f) {
			NSString *scaledName = [NSString stringWithFormat:@"%@@%.0fx", name, scale];
			result = [UIImage imageWithContentsOfFile:[bundle pathForResource:scaledName ofType:@"png"]];
			if (result) {
				PSWSetCachedImageForKey(result, key);
				return result;
			}
		}
	}
	result = [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
	if (result)
		PSWSetCachedImageForKey(result, key);
	return result;
}

UIImage *PSWGetScaledCachedImageResource(NSString *name, NSBundle *bundle, CGSize size)
{
	// Search for cached image
	NSString *key = [NSString stringWithFormat:@"%@#%@#%@", [bundle bundlePath], name, NSStringFromCGSize(size)];
	UIImage *image = [imageCache objectForKey:key];
	if (image)
		return image;
	// Get unscaled image and check if is already the right size
	image = PSWGetCachedImageResource(name, bundle);
	if (!image)
		return image;
	CGSize unscaledSize = [image size];
	if (unscaledSize.width == size.width && unscaledSize.height == size.height)
		return image;
	CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f;
	size_t scaledWidth = scale * size.width;
	size_t scaledHeight = scale * size.height;
	// Create a bitmap context that mimics the format of the source context
	CGImageRef cgImage = [image CGImage];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, scaledWidth, scaledHeight, 8, 4 * scaledWidth, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(colorSpace);
	// Setup transformation
	CGContextSetInterpolationQuality(context, kCGInterpolationNone);
	CGContextTranslateCTM(context, 0.0f, size.height * scale); 
	CGContextScaleCTM(context, scale, -scale);
	// Draw stretchable image
	UIGraphicsPushContext(context);
	[[image stretchableImageWithLeftCapWidth:((NSInteger)unscaledSize.width)/2 topCapHeight:((NSInteger)unscaledSize.height)/2] drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
	UIGraphicsPopContext();
	// Create CGImage
	CGContextFlush(context);
	cgImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	// Create UIImage
	if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)])
		image = [UIImage imageWithCGImage:cgImage scale:scale orientation:UIImageOrientationUp];
	else
		image = [UIImage imageWithCGImage:cgImage];
	CGImageRelease(cgImage);
	// Update cache
	PSWSetCachedImageForKey(image, key);
	return image;
}

UIImage *PSWImage(NSString *name)
{
	return PSWGetCachedImageResource(name, sharedBundle);
}

UIImage *PSWScaledImage(NSString *name, CGSize size)
{
	return PSWGetScaledCachedImageResource(name, sharedBundle, size);
}


static void ClipContextRounded(CGContextRef c, CGSize size, CGFloat cornerRadius)
{
	CGSize half;
	half.width = size.width * 0.5f;
	half.height = size.height * 0.5f;
	CGContextMoveToPoint(c, size.width, half.height);
	CGContextAddArcToPoint(c, size.width, size.height, half.width, size.height, cornerRadius);
	CGContextAddArcToPoint(c, 0.0f, size.height, 0.0f, half.height, cornerRadius);
	CGContextAddArcToPoint(c, 0.0f, 0.0f, half.width, 0.0f, cornerRadius);
	CGContextAddArcToPoint(c, size.width, 0.0f, size.width, half.height, cornerRadius);
	CGContextClosePath(c);
	CGContextClip(c);
}

UIImage *PSWGetCachedCornerMaskOfSize(CGSize size, CGFloat cornerRadius)
{
	if (size.width < 1.0f || size.height < 1.0f)
		return nil;
	NSString *key = [NSString stringWithFormat:@"%fx%f-%f", size.width, size.height, cornerRadius];
	UIImage *result = [imageCache objectForKey:key];
	if (!result) {
		CGContextRef c;
		CGFloat scale = [UIScreen instancesRespondToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f;
		// Only iPad supports using mask images as layer masks (older models require full images, then use only the alpha channel)
		if (PSWGetHardwareType() >= PSWHardwareTypeiPad1G)
			c = CGBitmapContextCreate(NULL, (size_t)size.width * scale, (size_t)size.height * scale, 8, (size_t)size.width * scale, NULL, kCGImageAlphaOnly);
		else {
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			c = CGBitmapContextCreate(NULL, (size_t)size.width * scale, (size_t)size.height * scale, 8, (size_t)size.width * scale * 4, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
			CGColorSpaceRelease(colorSpace);
		}
		CGRect rect;
		rect.origin.x = 0.0f;
		rect.origin.y = 0.0f;
		rect.size.width = size.width * scale;
		rect.size.height = size.height * scale;
		if (cornerRadius > 0.0f)
			ClipContextRounded(c, rect.size, cornerRadius * scale);
		CGContextSetRGBFillColor(c, 1.0f, 1.0f, 1.0f, 1.0f);
		CGContextFillRect(c, rect);
		CGImageRef image = CGBitmapContextCreateImage(c);
		CGContextRelease(c);
		if ([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)])
			result = [UIImage imageWithCGImage:image scale:scale orientation:UIImageOrientationUp];
		else
			result = [UIImage imageWithCGImage:image];
		CGImageRelease(image);
		PSWSetCachedImageForKey(result, key);
	}
	return result;
}

void PSWClearResourceCache()
{
	[imageCache release];
	imageCache = nil;
}

NSString *PSWLocalize(NSString *text)
{
	return [localizationBundle localizedStringForKey:text value:nil table:nil];
}

PSWHardwareType PSWGetHardwareType()
{
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char machine[size];
	if (strcmp(machine, "iPhone1,1") == 0)
		return PSWHardwareTypeiPhoneOriginal;
	if (strcmp(machine, "iPod1,1") == 0)
		return PSWHardwareTypeiPodTouch1G;
	if (strcmp(machine, "iPhone1,2") == 0)
		return PSWHardwareTypeiPhone3G;
	if (strcmp(machine, "iPod2,1") == 0)
		return PSWHardwareTypeiPodTouch2G;
	if (strcmp(machine, "iPhone2,1") == 0)
		return PSWHardwareTypeiPhone3GS;
	if (strcmp(machine, "iPod3,1") == 0)
		return PSWHardwareTypeiPodTouch3G;
	if (strcmp(machine, "iPad1,1") == 0)
		return PSWHardwareTypeiPad1G;
	if (strcmp(machine, "iPhone3,1") == 0)
		return PSWHardwareTypeiPhone4;
	return PSWHardwareTypeUnknown;
}

__attribute__((constructor)) static void resources_init()
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	
	sharedBundle = [[NSBundle bundleWithPath:@"/Applications/ProSwitcher.app"] retain];
	localizationBundle = [[NSBundle bundleWithPath:@"/Library/PreferenceLoader/Preferences/ProSwitcher"] retain];
	
	[pool release];
}