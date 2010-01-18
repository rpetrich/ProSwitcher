#import "PSWPageScrollView.h"

@implementation PSWPageScrollView

@synthesize doubleTapped = _doubleTapped;

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
	_shouldScrollOnUp = NO;
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
		[self performSelector:@selector(tapNextAndContinue) withObject:nil afterDelay:0.5f];
	}
	_shouldScrollOnUp = NO;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	CGPoint point = [touch locationInView:[self superview]];
	CGPoint offset = [self frame].origin;
	point.x -= offset.x;
	if (point.x <= 0.0f) {
		[self performSelector:@selector(tapPreviousAndContinue) withObject:nil afterDelay:0.1f];
	} else if (point.x > [self bounds].size.width) {
		[self performSelector:@selector(tapNextAndContinue) withObject:nil afterDelay:0.1f];
	}
	_shouldScrollOnUp = YES;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
	_shouldScrollOnUp = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	NSInteger tapCount = [touch tapCount];
	CGPoint point = [touch locationInView:[self superview]];
	point.x -= [self frame].origin.x;
	_doubleTapped = NO;
	if (tapCount == 2) {
		_doubleTapped = YES;
		if (point.x <= 0.0f) {
			[self setContentOffset:CGPointZero animated:YES];
		} else {
			CGSize size = [self bounds].size;
			if (point.x > size.width) {
				CGPoint offset;
				CGSize contentSize = [self contentSize];
				offset.x = (size.width < contentSize.width) ? contentSize.width - size.width : 0.0f;
				offset.y = (size.height < contentSize.height) ? contentSize.height - size.height : 0.0f;
				[self setContentOffset:offset animated:YES];
			}
		}
	} else if(_shouldScrollOnUp) {
		if (point.x <= 0.0f) {
			[self tapPreviousAndContinue];
		} else if (point.x > [self bounds].size.width) {
			[self tapNextAndContinue];
		}
	}
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapPreviousAndContinue) object:nil];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapNextAndContinue) object:nil];
	_shouldScrollOnUp = NO;
}

@end
