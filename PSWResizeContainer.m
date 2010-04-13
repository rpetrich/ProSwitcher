#import "PSWResizeContainer.h"

@implementation PSWResizeContainer

@synthesize delegate = _delegate;

- (void)layoutSubviews
{
	[_delegate shouldLayoutSubviewsForContainer:self];
}

@end

