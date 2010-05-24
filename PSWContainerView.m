
#import "PSWContainerView.h"
#import "PSWPageView.h"

@implementation PSWContainerView

@synthesize pageView = _pageView;
@synthesize dockHeight = _dockHeight;
@synthesize statusBarHeight = _statusBarHeight;

- (void)layoutSubviews
{
	CGRect frame = [self bounds];
	frame.origin.y = self.statusBarHeight;
	frame.size.height -= self.dockHeight + frame.origin.y;
	[self.pageView setFrame:frame];
}

- (void)setFrame:(CGRect)frame
{
	[super setFrame:frame];
	[self layoutSubviews];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	return [self pageView];
	
	/*if ([[self.pageView applications] count]) {
		UIView *child = nil;
		
		[self.pageView setDoubleTapped:NO];
		
		if ((child = [super hitTest:point withEvent:event]) == self)
			return self;
		else 
			return child;
	} else {
		return [super hitTest:point withEvent:event];
	}*/
}

@end
