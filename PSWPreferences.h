#import <Foundation/Foundation.h>
#include <sys/types.h>
#include <sys/stat.h>

#define idForKeyWithDefault(dict, key, default)	 ([(dict) objectForKey:(key)]?:(default))
#define floatForKeyWithDefault(dict, key, default)   ({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result floatValue]:(default); })
#define NSIntegerForKeyWithDefault(dict, key, default) (NSInteger)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result integerValue]:(default); })
#define BOOLForKeyWithDefault(dict, key, default)    (BOOL)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result boolValue]:(default); })

#define PSWPreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.collab.proswitcher.plist"]
#define PSWPreferencesChangedNotification "com.collab.proswitcher.preferencechanged"

#define GetPreference(name, type) type ## ForKeyWithDefault(preferences, @#name, (name))

// Defaults
#define PSWSingleHomeTap		NO
#define PSWShowDock             YES
#define PSWShowBadges			YES
#define PSWAnimateActive        YES
#define PSWAllowsZoom			NO
#define PSWSpringBoardCard		NO
#define PSWDimBackground        YES
#define PSWShowPageControl      YES
#define PSWThemedIcons			YES
#define PSWBackgroundStyle      0
#define PSWSwipeToClose         YES
#define PSWShowApplicationTitle YES
#define PSWShowCloseButton      YES
#define PSWShowEmptyText        YES
#define PSWRoundedCornerRadius  0.0f
#define PSWTapsToActivate       1
#define PSWSnapshotInset        40.0f
#define PSWUnfocusedAlpha       1.0f
#define PSWShowDefaultApps      YES
#define PSWPagingEnabled        YES
#define PSWDefaultApps          [NSArray arrayWithObjects:@"com.apple.mobileipod-MediaPlayer", @"com.apple.mobilephone", @"com.apple.mobilemail", @"com.apple.mobilesafari", nil]


__attribute__((always_inline))
static inline void PSWWriteBinaryPropertyList(NSDictionary *dict, NSString *fileName)
{
	NSError *error = nil;
	NSData *data = [NSPropertyListSerialization dataFromPropertyList:dict format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error];
	if (error)
		[dict writeToFile:fileName atomically:YES];
	else
		[data writeToFile:fileName atomically:YES];
}
