#import <IOSurface/IOSurface.h>
#import <TargetConditionals.h>
#import <Foundation/Foundation.h>

#if !TARGET_IPHONE_SIMULATOR
#ifndef IOSURFACE_API_FALLBACK
#define USE_IOSURFACE
#endif
#endif

#ifdef USE_IOSURFACE
BOOL PSWSurfaceAcceleratorIsAvailable();
IOSurfaceRef PSWSurfaceCopyToMainMemory(IOSurfaceRef surface, OSType pixelFormat, NSUInteger bytesPerElement);
#endif
