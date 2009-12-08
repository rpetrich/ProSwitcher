#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>

@protocol PSWApplicationDelegate;

@interface PSWApplication : NSObject {
@private
	NSString *_displayIdentifier;
	SBApplication *_application;
	NSData *_snapshotData;
	CGImageRef _snapshotImage;
	NSString *_snapshotFilePath;
	id<PSWApplicationDelegate> _delegate;
}

+ (NSString *)snapshotPath;
+ (void)clearSnapshotCache;

- (id)initWithDisplayIdentifier:(NSString *)displayIdentifier;
- (id)initWithSBApplication:(SBApplication *)application;

@property (nonatomic, readonly) NSString *displayIdentifier;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) SBIcon *springBoardIcon;
@property (nonatomic, readonly) SBApplication *application;
@property (nonatomic, assign) CGImageRef snapshot;
@property (nonatomic, assign) id<PSWApplicationDelegate> delegate;

- (void)loadSnapshotFromBuffer:(void *)buffer width:(NSUInteger)width height:(NSUInteger)height stride:(NSUInteger)stride;
- (void)writeSnapshotToDisk;
- (void)exit;
- (void)activate;

@end

@protocol PSWApplicationDelegate <NSObject>
@optional
- (void)applicationSnapshotDidChange:(PSWApplication *)application;
@end


