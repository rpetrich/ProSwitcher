#import "PSWResources.h"

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

void PSWClearResourceCache()
{
	[imageCache release];
	imageCache = nil;
}
