#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>

#ifdef USE_IOSURFACE
#import <IOSurface/IOSurface.h>
typedef struct PSWCropInsets {
    size_t top, left, bottom, right;
} PSWCropInsets;
#endif

@protocol PSWApplicationDelegate;

@interface PSWApplication : NSObject {
@private
	NSString *_displayIdentifier;
	SBApplication *_application;
	id<PSWApplicationDelegate> _delegate;
#ifdef USE_IOSURFACE
	CGImageRef _snapshotImage;
	NSString *_snapshotFilePath;
	IOSurfaceRef _surface;
	PSWCropInsets _cropInsets;
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
@property (nonatomic, readonly) CGImageRef snapshot;
@property (nonatomic, assign) id<PSWApplicationDelegate> delegate;
@property (nonatomic, readonly) BOOL hasNativeBackgrounding;
@property (nonatomic, readonly) SBIconBadge *badgeView;

#ifdef USE_IOSURFACE
- (void)loadSnapshotFromSurface:(IOSurfaceRef)surface;
- (void)loadSnapshotFromSurface:(IOSurfaceRef)surface cropInsets:(PSWCropInsets)cropInsets;
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


