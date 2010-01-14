#import "PSWPageScrollView.h"

@implementation PSWPageScrollView


- (void)dealloc {
    [super dealloc];
}

#pragma mark Touch Gestures

- (void)tapPreviousAndContinue
{
	CGPoint offset = [self contentOffset];
	offset.x -= [self bounds].size.width;
	if (offset.x < 0.0f)
		offset.x = 0.0f;
	[self setContentOffset:offset animated:YES];
	[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.5f];
}

- (void)tapNextAndContinue
{
	CGFloat width = [self bounds].size.width;
	CGFloat maxOffset = [self contentSize].width - width;
	if (maxOffset > 0) {
		CGPoint offset = [self contentOffset];
		offset.x += width;
		if (offset.x > maxOffset)
			offset.x = maxOffset;
		[self setContentOffset:offset animated:YES];
		[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.5f];
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	NSInteger tapCount = [touch tapCount];
	CGPoint point = [touch locationInView:[self superview]];
	CGPoint offset = [self frame].origin;
	point.x -= offset.x;
	point.y -= offset.y;
	if (point.x <= 0.0f) {
		if (tapCount == 2) {
			[self setContentOffset:CGPointZero animated:YES];
		} else {
			[self tapPreviousAndContinue];
		}
	} else {
		CGSize size = [self bounds].size;
		if (point.x > size.width) {
			if (tapCount == 2) {
				CGPoint offset;
				CGSize contentSize = [self contentSize];
				offset.x = (size.width < contentSize.width) ? contentSize.width - size.width : 0.0f;
				offset.y = (size.height < contentSize.height) ? contentSize.height - size.height : 0.0f;
				[self setContentOffset:offset animated:YES];
			} else {
				[self tapNextAndContinue];
			}
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
}

@end
