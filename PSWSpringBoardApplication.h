#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>

#import "PSWApplication.h"

@interface PSWSpringBoardApplication : PSWApplication {
@protected
	NSString *_displayName;
}

@property (nonatomic, readonly) NSString *displayIdentifier;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) UIImage *themedIcon;
@property (nonatomic, readonly) UIImage *unthemedIcon;
@property (nonatomic, readonly) CGImageRef snapshot;
@property (nonatomic, readonly) BOOL hasNativeBackgrounding;
@property (nonatomic, readonly) SBIconBadge *badgeView;

- (void)exit;
- (void)activate;
- (void)activateWithAnimation:(BOOL)animated;

@end

