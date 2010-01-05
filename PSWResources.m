#import "PSWResources.h"

#import <CoreGraphics/CoreGraphics.h>

static NSMutableDictionary *imageCache;

UIImage *PSWGetCachedImageResource(NSString *name, NSBundle *bundle)
{
	NSString *key = [NSString stringWithFormat:@"%@#%@", [bundle bundlePath], name];
	UIImage *result = [imageCache objectForKey:key];
	if (!result) {
		if (!imageCache)
			imageCache = [[NSMutableDictionary alloc] init];
		result = [UIImage imageWithContentsOfFile:[bundle pathForResource:name ofType:@"png"]];
		if (result)
			if (imageCache)
				[imageCache setObject:result forKey:key];
			else
				imageCache = [[NSMutableDictionary alloc] initWithObjectsAndKeys:result, key, nil];
	}
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
	// Create a bitmap context that mimics the format of the source context
	CGImageRef cgImage = [image CGImage];
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(NULL, (size_t)size.width, (size_t)size.height, 8, 4 * (size_t)size.width, colorSpace, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(colorSpace);
	// Setup transformation
	CGContextSetInterpolationQuality(context, kCGInterpolationNone);
	CGContextTranslateCTM(context, 0.0f, size.height); 
	CGContextScaleCTM(context, 1.0f, -1.0f);
	// Draw stretchable image
	UIGraphicsPushContext(context);
	[[image stretchableImageWithLeftCapWidth:((NSInteger)unscaledSize.width)/2 topCapHeight:((NSInteger)unscaledSize.height)/2] drawInRect:CGRectMake(0.0f, 0.0f, size.width, size.height)];
	UIGraphicsPopContext();
	// Create CGImage
	CGContextFlush(context);
	cgImage = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	// Create UIImage
	image = [UIImage imageWithCGImage:cgImage];
	CGImageRelease(cgImage);
	// Update cache
	[imageCache setObject:image forKey:key];
	return image;
}

UIImage *PSWImage(NSString *name)
{
	return PSWGetCachedImageResource(name, [NSBundle bundleWithPath:@"/Applications/ProSwitcher.app"]);
}

UIImage *PSWScaledImage(NSString *name, CGSize size)
{
	return PSWGetScaledCachedImageResource(name, [NSBundle bundleWithPath:@"/Applications/ProSwitcher.app"], size);
}


static void ClipContextRounded(CGContextRef c, CGSize size, CGFloat cornerRadius)
{
	CGSize half;
	half.width = size.width / 2.0f;
	half.height = size.height / 2.0f;
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
		UIGraphicsBeginImageContext(size);
		CGContextRef c = UIGraphicsGetCurrentContext();
		// TODO: figure out why sometimes this fails so hard
		if (!c)
			return nil;
		if (cornerRadius != 0.0f)
			ClipContextRounded(c, size, cornerRadius);
		[[UIColor whiteColor] set];
		UIRectFill(CGRectMake(0.0f, 0.0f, size.width, size.height));
		result = UIGraphicsGetImageFromCurrentImageContext();
		if (imageCache)
			[imageCache setObject:result forKey:key];
		else
			imageCache = [[NSMutableDictionary alloc] initWithObjectsAndKeys:result, key, nil];
		UIGraphicsEndImageContext();
	}
	return result;
}

void PSWClearResourceCache()
{
	[imageCache release];
	imageCache = nil;
}
