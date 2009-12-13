#import "PSWSnapshotView.h"

#import <SpringBoard/SpringBoard.h>

#import "PSWApplication.h"
#import "PSWResources.h"

#define kSwipeThreshold 40.0f

@implementation PSWSnapshotView

@synthesize application = _application;
@synthesize delegate = _delegate;
@synthesize allowsSwipeToClose = _allowsSwipeToClose;

- (void)snapshot:(UIButton *)snapshot touchUpInside:(UIEvent *)event
{
	if ([_delegate respondsToSelector:@selector(snapshotViewTapped:withCount:)]) {
		UITouch *touch = [[event allTouches] anyObject];
		[_delegate snapshotViewTapped:self withCount:[touch tapCount]];
	}
}

- (void)snapshot:(UIButton *)theSnapshot didStartDrag:(UIEvent *)event
{
	UITouch *touch = [[event allTouches] anyObject];
	touchDownPoint = [touch locationInView:[self superview]];
	wasSwipedAway = NO;
	isInDrag = NO;
}

- (void)snapshot:(UIButton *)theSnapshot didDrag:(UIEvent *)event
{
	if (_allowsSwipeToClose) {
		UITouch *touch = [[event allTouches] anyObject];
		CGRect frame = [theSnapshot frame];
		
		NSInteger vert = touchDownPoint.y - [touch locationInView:[self superview]].y;
		if (vert > 0.0f) {
			wasSwipedAway = (vert > kSwipeThreshold);
			frame.origin.y = imageViewY - vert;
			CGFloat alpha = 1.0f - (vert / 300.0f);
			theSnapshot.alpha = (alpha > 0.0f) ? alpha:0.0f;
		} else {
			wasSwipedAway = NO;
			frame.origin.y = imageViewY;
			theSnapshot.alpha = 1.0f;
		}		
		[theSnapshot setFrame:frame];
		if (!isInDrag) {
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.33f];
			[UIView setAnimationBeginsFromCurrentState:YES];
			_closeButton.alpha = 0.0f;
			_titleView.alpha = 0.0f;
			_iconView.alpha = 0.0f;
			[UIView commitAnimations];
			isInDrag = YES;
		}
	}
}

- (void)snapshot:(UIButton *)theSnapshot didEndDrag:(UIEvent *)event
{
	if (wasSwipedAway) {
		wasSwipedAway = NO;
		if ([_delegate respondsToSelector:@selector(snapshotViewClosed:)])
			[_delegate snapshotViewClosed:self];
	} else {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.33f];
		CGRect frame = [theSnapshot frame];
		frame.origin.y = imageViewY;
		[theSnapshot setFrame:frame];
		theSnapshot.alpha = 1.0f;
		_closeButton.alpha = 1.0f;
		_titleView.alpha = 1.0f;
		_iconView.alpha = 1.0f;
		[UIView commitAnimations];
		UITouch *touch = [[event allTouches] anyObject];
		if ([touch locationInView:[self superview]].y - touchDownPoint.y > kSwipeThreshold) {
			if ([_delegate respondsToSelector:@selector(snapshotViewDidSwipeOut:)])
				[_delegate snapshotViewDidSwipeOut:self];
		}
	}
}

- (void)_relayoutViews
{
	BOOL closeButtonNeedsReposition = NO;
	CGImageRef snapshot = [_application snapshot];
	CGFloat snapshotWidth = (CGFloat) CGImageGetWidth(snapshot);
	CGFloat snapshotHeight = (CGFloat) CGImageGetHeight(snapshot);
	
	CGRect frame = [self frame];
	CGSize box = CGSizeMake(frame.size.width - 30, frame.size.height - 70);
	CGSize img = CGSizeMake(snapshotWidth, snapshotHeight);
	
	CGFloat ratioW = box.width  / img.width ;
	CGFloat ratioH = box.height / img.height;
	
	if (ratioW < ratioH) {
		imageViewW = ratioW * snapshotWidth;
		imageViewH = ratioW * snapshotHeight;
	} else {
		imageViewW = ratioH * snapshotWidth;
		imageViewH = ratioH * snapshotHeight;
	}
	
	imageViewY = (frame.size.height - imageViewH) / 2.0f;
	imageViewX = (frame.size.width - imageViewW) / 2.0f;
	
	if (_showsTitle)
		imageViewY -= 20;
	
	[screen setFrame:CGRectMake(imageViewX, imageViewY, imageViewW, imageViewH)];
	
	if (_showsTitle && !_titleView) {
		closeButtonNeedsReposition = YES;
		
		// Prepare to add label and icon
		CGRect bounds = [self bounds];
		CGFloat center = bounds.size.width / 2.0f;
		UIFont *titleFont = [UIFont boldSystemFontOfSize:17.0f];
		NSString *appTitle = [_application displayName];
		CGSize metrics = [appTitle sizeWithFont:titleFont];
		CGFloat baseX = (NSInteger)(center - (metrics.width / 2.0f));
		
		// Add label
		_titleView = [[UILabel alloc] initWithFrame:CGRectMake(baseX + 18, imageViewY + imageViewH + 10, 200, 30)];
		_titleView.font = titleFont;
		_titleView.backgroundColor = [UIColor clearColor];
		_titleView.textColor = [UIColor whiteColor]; 
		_titleView.text = appTitle;
		[self addSubview:_titleView];
		
		// Add small icon
		UIImage *smallIcon = [_application.springBoardIcon smallIcon];
		_iconView = [[UIImageView alloc] initWithFrame:CGRectMake(baseX - 18, imageViewY + imageViewH + 13, 24, 24)];
		[_iconView setImage:smallIcon];
		[self addSubview:_iconView];
	} else if (_titleView && !_showsTitle) {
		[_titleView removeFromSuperview];
		[_titleView release];
		_titleView = nil;
		[_iconView removeFromSuperview];
		[_iconView release];
		_iconView = nil;
	}
	
	if (!_closeButton && _showsCloseButton) {
		_closeButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		closeButtonNeedsReposition = YES;
		UIImage *closeImage = PSWGetCachedSpringBoardResource(@"closebox");
		[_closeButton setBackgroundImage:closeImage forState:UIControlStateNormal];
		[_closeButton addTarget:self action:@selector(_closeButtonWasPushed) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:_closeButton];
	} else if (_closeButton && !_showsCloseButton) {
		[_closeButton removeFromSuperview];
		[_closeButton release];
		_closeButton = nil;
	}
	
	if (closeButtonNeedsReposition && _closeButton)
	{
		UIImage *closeImage = PSWGetCachedSpringBoardResource(@"closebox");
		CGSize closeImageSize = [closeImage size];
		CGFloat offsetX = (NSInteger)(closeImageSize.width / 2.0f);
		CGFloat offsetY = (NSInteger)(closeImageSize.height / 2.0f);
		[_closeButton setFrame:CGRectMake(imageViewX - offsetX, imageViewY - offsetY, closeImageSize.width, closeImageSize.height)];
	}
	
	CGFloat alpha = _focused?1.0f:0.0f;
	[_closeButton setAlpha:alpha];
	[_titleView setAlpha:alpha];
	[_iconView setAlpha:alpha];
}

- (id)initWithFrame:(CGRect)frame application:(PSWApplication *)application
{
    if (self = [super initWithFrame:frame]) {
		_application = [application retain];
		_application.delegate = self;
		self.userInteractionEnabled = YES;
		self.opaque = NO;
		
		// Add Snapshot layer
		screen = [UIButton buttonWithType:UIButtonTypeCustom];
		CGImageRef snapshot = [application snapshot];
		[screen setClipsToBounds:YES];
		CALayer *layer = [screen layer];
		[layer setContents:(id)snapshot];
		screen.hidden = NO;
		
		[screen addTarget:self action:@selector(snapshot:touchUpInside:) forControlEvents:UIControlEventTouchUpInside];
		[screen addTarget:self action:@selector(snapshot:didStartDrag:) forControlEvents:UIControlEventTouchDown];
		[screen addTarget:self action:@selector(snapshot:didDrag:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
		[screen addTarget:self action:@selector(snapshot:didEndDrag:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside | UIControlEventTouchUpInside];
		[self addSubview:screen];
		
		[self _relayoutViews];
	}
    return self;
}

- (void)dealloc
{
	_application.delegate = nil;
	[_titleView release];
	[_iconView release];
	[_closeButton release];
	[_application release];
    [super dealloc];
}

#pragma mark Properties

- (void)_closeButtonWasPushed
{
	if ([_delegate respondsToSelector:@selector(snapshotViewClosed:)])
		[_delegate snapshotViewClosed:self];
}

- (BOOL)showsCloseButton
{
	return _closeButton != nil;
}

- (void)setShowsCloseButton:(BOOL)showsCloseButton
{
	if (_showsCloseButton != showsCloseButton) {
		_showsCloseButton = showsCloseButton;
		[self _relayoutViews];
	}
}

- (BOOL)showsTitle
{
	return _titleView != nil;
}

- (void)setShowsTitle:(BOOL)showsTitle
{
	if (_showsTitle != showsTitle) {
		_showsTitle = showsTitle;
		[self _relayoutViews];
	}
}

- (void)setRoundedCornerRadius:(CGFloat)roundedCornerRadius
{
	screen.layer.cornerRadius = roundedCornerRadius;
}

- (CGFloat)roundedCornerRadius
{
	return screen.layer.cornerRadius;	
}

- (BOOL)focused
{
	return _focused;
}
- (void)setFocused:(BOOL)focused animated:(BOOL)animated
{
	_focused = focused;
	if (animated) {
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.33f];
	}
	CGFloat alpha = _focused?1.0f:0.0f;
	[_closeButton setAlpha:alpha];
	[_titleView setAlpha:alpha];
	[_iconView setAlpha:alpha];
	if (animated) {
		[UIView commitAnimations];
	}
}
- (void)setFocused:(BOOL)focused
{
	[self setFocused:focused animated:YES];
}

#pragma mark PSWApplicationDelegate

- (void)applicationSnapshotDidChange:(PSWApplication *)application
{
	[[screen layer] setContents:(id)[application snapshot]];
}

@end