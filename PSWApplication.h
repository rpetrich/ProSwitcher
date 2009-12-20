#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>
#import <SpringBoard/SBApplication.h>
#import <SpringBoard/SBApplicationIcon.h>

#ifdef USE_IOSURFACE
#import <IOSurface/IOSurface.h>
#endif

@protocol PSWApplicationDelegate;

@interface PSWApplication : NSObject {
@private
	NSString *_displayIdentifier;
	SBApplication *_application;
	NSData *_snapshotData;
	CGImageRef _snapshotImage;
	NSString *_snapshotFilePath;
#ifdef USE_IOSURFACE
	IOSurfaceRef _surface;
#endif
	id<PSWApplicationDelegate> _delegate;
}

+ (NSString *)snapshotPath;
+ (void)clearSnapshotCache;

- (id)initWithDisplayIdentifier:(NSString *)displayIdentifier;
- (id)initWithSBApplication:(SBApplication *)application;

@property (nonatomic, readonly) NSString *displayIdentifier;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) SBApplicationIcon *springBoardIcon;
@property (nonatomic, readonly) SBApplication *application;
@property (nonatomic, assign) CGImageRef snapshot;
@property (nonatomic, assign) id<PSWApplicationDelegate> delegate;
@property (nonatomic, readonly) BOOL hasNativeBackgrounding;

//- (void)loadSnapshotFromBuffer:(void *)buffer width:(NSUInteger)width height:(NSUInteger)height stride:(NSUInteger)stride;
#ifdef USE_IOSURFACE
- (void)loadSnapshotFromSurface:(IOSurfaceRef)surface;
#endif
- (BOOL)writeSnapshotToDisk;
- (void)exit;
- (void)activate;
- (void)activateWithAnimation:(BOOL)animated;

@end

@protocol PSWApplicationDelegate <NSObject>
@optional
- (void)applicationSnapshotDidChange:(PSWApplication *)application;
@end


