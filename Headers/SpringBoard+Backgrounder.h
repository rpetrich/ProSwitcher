#import <SpringBoard/SpringBoard.h>

@interface UIApplication (Backgrounder)
- (void)setBackgroundingEnabled:(BOOL)backgroundingEnabled forDisplayIdentifier:(NSString *)displayIdentifier;
@end
