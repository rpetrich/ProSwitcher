#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>

#import "PSWSurface.h"

#ifdef USE_IOSURFACE
typedef struct PSWCropInsets {
    size_t top, left, bottom, right;
} PSWCropInsets;
typedef enum {
	PSWSnapshotRotationNone = UIInterfaceOrientationPortrait,
	PSWSnapshotRotation180 = UIInterfaceOrientationPortraitUpsideDown,
	PSWSnapshotRotation90Left = UIInterfaceOrientationLandscapeLeft,
	PSWSnapshotRotation90Right = UIInterfaceOrientationLandscapeRight,
} PSWSnapshotRotation;
#endif

@protocol PSWApplicationDelegate;

@interface PSWApplication : NSObject {
@protected
	NSString *_displayIdentifier;
	SBApplication *_application;
	id<PSWApplicationDelegate> _delegate;
#ifdef USE_IOSURFACE
	CGImageRef _snapshotImage;
	NSString *_snapshotFilePath;
	IOSurfaceRef _surface;
	PSWCropInsets _cropInsets;
	PSWSnapshotRotation _snapshotRotation;
#endif
}

+ (NSString *)snapshotPath;
+ (void)clearSnapshotCache;

- (id)initWithDisplayIdentifier:(NSString *)displayIdentifier;
- (id)initWithSBApplication:(SBApplication *)application;

@property (nonatomic, readonly) NSString *displayIdentifier;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) SBApplicationIcon *springBoardIcon;
@property (nonatomic, readonly) UIImage *themedIcon;
@property (nonatomic, readonly) UIImage *unthemedIcon;
@property (nonatomic, readonly) SBApplication *application;
@property (nonatomic, assign) id<PSWApplicationDelegate> delegate;
@property (nonatomic, readonly) BOOL hasNativeBackgrounding;
@property (nonatomic, readonly) SBIconBadge *badgeView;
@property (nonatomic, readonly) NSString *badgeText;

@property (nonatomic, readonly) id snapshot;
#ifdef USE_IOSURFACE
@property (nonatomic, readonly) PSWCropInsets snapshotCropInsets;
@property (nonatomic, readonly) PSWSnapshotRotation snapshotRotation;

- (IOSurfaceRef)loadSnapshotFromSurface:(IOSurfaceRef)surface;
- (IOSurfaceRef)loadSnapshotFromSurface:(IOSurfaceRef)surface cropInsets:(PSWCropInsets)cropInsets;
- (IOSurfaceRef)loadSnapshotFromSurface:(IOSurfaceRef)surface cropInsets:(PSWCropInsets)cropInsets rotation:(PSWSnapshotRotation)rotation;
#endif
- (BOOL)writeSnapshotToDisk;
- (void)exit;
- (void)activate;
- (void)activateWithAnimation:(BOOL)animated;

@end

@protocol PSWApplicationDelegate <NSObject>
@optional
- (void)applicationSnapshotDidChange:(PSWApplication *)application;
- (void)applicationBadgeDidChange:(PSWApplication *)application;
@end
