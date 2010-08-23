#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <sys/types.h>
#include <sys/stat.h>

#define idForKeyWithDefault(dict, key, default)	 ([(dict) objectForKey:(key)]?:(default))
#define floatForKeyWithDefault(dict, key, default)   ({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result floatValue]:(default); })
#define NSIntegerForKeyWithDefault(dict, key, default) (NSInteger)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result integerValue]:(default); })
#define BOOLForKeyWithDefault(dict, key, default)    (BOOL)({ id _result = [(dict) objectForKey:(key)]; (_result)?[_result boolValue]:(default); })

#define PSWPreferencesFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Preferences/com.collab.proswitcher.plist"]
#define PSWPreferencesChangedNotification "com.collab.proswitcher.preferencechanged"

#define GetPreference(name, type) type ## ForKeyWithDefault(preferences, @#name, (name))

// Constants
#define PSWBecomeHomeScreenDisabled   0
#define PSWBecomeHomeScreenEnabled    1
#define PSWBecomeHomeScreenBackground 2

#define PSWBackgroundStyleDefault 0
#define PSWBackgroundStyleImage   1

#define PSWEmptyStyleText  0
#define PSWEmptyStyleBlank 1
#define PSWEmptyStyleExit  2

// Defaults
#define PSWBecomeHomeScreen     PSWBecomeHomeScreenDisabled
#define PSWShowDock             YES
#define PSWShowBadges           YES
#define PSWAnimateActive        YES
#define PSWAllowsZoom           NO
#define PSWSpringBoardCard      NO
#define PSWDimBackground        YES
#define PSWShowPageControl      YES
#define PSWThemedIcons          YES
#define PSWBackgroundStyle      PSWBackgroundStyleDefault
#define PSWSwipeToClose         YES
#define PSWShowApplicationTitle YES
#define PSWShowCloseButton      YES
#define PSWEmptyStyle           PSWEmptyStyleText
#define PSWEmptyTapClose        YES
#define PSWRoundedCornerRadius  0.0f
#define PSWTapsToActivate       1
#define PSWSnapshotInset        (PSWPad ? 80.0f : 40.0f) // Legacy
#define PSWSnapshotProportionalInset        0.12f
#define PSWUnfocusedAlpha       1.0f
#define PSWShowDefaultApps      YES
#define PSWPagingEnabled        YES
#define PSWDefaultApps          [NSArray arrayWithObjects:@"com.apple.mobileipod-MediaPlayer", @"com.apple.mobilephone", @"com.apple.mobilemail", @"com.apple.mobilesafari", nil]
#define PSWShowDockApps         YES
#define PSWShowIcon             YES
#define PSWHidePhone			YES

#define PSWPad ([[UIScreen mainScreen] applicationFrame].size.width > 480.0f)
#define PSWScreenHeight ([[UIScreen mainScreen] applicationFrame].size.height)
#define PSWScreenWidth ([[UIScreen mainScreen] applicationFrame].size.width)
#define PSWDockModel ([[$SBIconModel sharedInstance] respondsToSelector:@selector(buttonBar)] ? [[$SBIconModel sharedInstance] buttonBar] : [[[$SBIconModel sharedInstance] rootFolder] dockModel])
#define PSWDockView ([[$SBIconModel sharedInstance] respondsToSelector:@selector(buttonBar)] ? [[$SBIconModel sharedInstance] buttonBar] : [[$SBIconController sharedInstance] dock])
#define PSWDockHeight ([PSWDockView frame].size.height)
#define PSWListWithIcon(icon) 


__attribute__((always_inline))
static inline void PSWWriteBinaryPropertyList(NSDictionary *dict, NSString *fileName)
{
	CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)fileName, kCFURLPOSIXPathStyle, NO);
    CFWriteStreamRef stream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, url);
	CFRelease(url);
    CFWriteStreamOpen(stream);
    CFPropertyListWriteToStream((CFPropertyListRef)dict, stream, kCFPropertyListBinaryFormat_v1_0, NULL);
    CFWriteStreamClose(stream);
}

extern NSDictionary *preferences;

__attribute__((always_inline))
static inline void PSWPreparePreferences()
{
	[preferences release];
	preferences = [[NSDictionary alloc] initWithContentsOfFile:PSWPreferencesFilePath];
}

