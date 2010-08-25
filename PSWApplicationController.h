#import <Foundation/Foundation.h>

@class PSWApplication;
@protocol PSWApplicationControllerDelegate;

__attribute__((visibility("hidden")))
@interface PSWApplicationController : NSObject {
@private
	NSMutableDictionary *_activeApplications;
	NSMutableArray *_activeApplicationsOrder;
	id<PSWApplicationControllerDelegate> _delegate;
}

+ (PSWApplicationController *)sharedInstance;

@property (nonatomic, readonly) NSArray *activeApplications;
@property (nonatomic, assign) id<PSWApplicationControllerDelegate> delegate;

- (PSWApplication *)applicationWithDisplayIdentifier:(NSString *)displayIdentifier;
- (void)writeSnapshotsToDisk;

@end

@protocol PSWApplicationControllerDelegate <NSObject>
@optional
- (void)applicationController:(PSWApplicationController *)ac applicationDidLaunch:(PSWApplication *)application;
- (void)applicationController:(PSWApplicationController *)ac applicationDidExit:(PSWApplication *)application;
@end

