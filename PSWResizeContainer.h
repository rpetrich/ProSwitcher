#import <UIKit/UIKit.h>

@protocol PSWResizeContainerDelegate;

@interface PSWResizeContainer : UIView {
@private
	id<PSWResizeContainerDelegate> _delegate;
}

@property (nonatomic, assign) id<PSWResizeContainerDelegate> delegate;

@end

@protocol PSWResizeContainerDelegate
@required
- (void)shouldLayoutSubviewsForContainer:(PSWResizeContainer *)container;
@end
