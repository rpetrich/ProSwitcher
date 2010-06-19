#import "PSWSurface.h"

#ifdef USE_IOSURFACE

#import "PSWResources.h"

static IOSurfaceAcceleratorRef accelerator;

BOOL PSWSurfaceAcceleratorIsAvailable()
{
	return PSWGetHardwareType() >= PSWHardwareTypeiPhone3GS;
}

IOSurfaceRef PSWSurfaceCopyToMainMemory(IOSurfaceRef surface, OSType pixelFormat, NSUInteger bytesPerElement)
{
	if (!surface)
		return NULL;
	// If surface accelerator is not available, just retain the existing surface
	if (!PSWSurfaceAcceleratorIsAvailable())
		return (IOSurfaceRef)CFRetain(surface);
	// Describe new surface
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithUnsignedInteger:IOSurfaceGetWidth(surface)], kIOSurfaceWidth,
		[NSNumber numberWithUnsignedInteger:IOSurfaceGetHeight(surface)], kIOSurfaceHeight,
		[NSNumber numberWithUnsignedInteger:pixelFormat], kIOSurfacePixelFormat,
		[NSNumber numberWithUnsignedInteger:bytesPerElement], kIOSurfaceBytesPerElement,
		[NSNumber numberWithUnsignedInteger:kIOMapInhibitCache], kIOSurfaceCacheMode,
		kCFBooleanTrue, kIOSurfaceIsGlobal,
	nil];
	// Create accelerator
	if (accelerator == NULL) {
		IOSurfaceAcceleratorCreate(kCFAllocatorDefault, 2, &accelerator);
		if (accelerator == NULL)
			return (IOSurfaceRef)CFRetain(surface);
	}
	// Create new surface
	IOSurfaceRef newSurface = IOSurfaceCreate((CFDictionaryRef)dict);
	if (!newSurface)
		return (IOSurfaceRef)CFRetain(surface);
	// Transfer
	IOSurfaceAcceleratorTransferSurface(accelerator, surface, newSurface, NULL, NULL);
	// Flush processor caches
	IOSurfaceFlushProcessorCaches(newSurface);
	return newSurface;
}
#endif
