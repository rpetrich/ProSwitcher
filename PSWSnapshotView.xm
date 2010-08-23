#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <SpringBoard/SpringBoard.h>
#import <CaptainHook/CaptainHook.h>

#import "PSWSnapshotView.h"
#import "PSWApplication.h"
#import "PSWResources.h"
#import "PSWPreferences.h"

#define kSwipeThreshold ([self bounds].size.height * (1.0f / 9.0f))
#define kTitleFont [UIFont boldSystemFontOfSize:17.0f]
#define kBadgeFont [UIFont boldSystemFontOfSize:16.0f]

@implementation PSWSnapshotView

@synthesize application = _application;
@synthesize delegate = _delegate;
@synthesize screenView = screen;

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
	wasSwipedUp = NO;
	isInDrag = NO;
}

- (void)snapshot:(UIButton *)theSnapshot didDrag:(UIEvent *)event
{
	if (GetPreference(PSWSwipeToClose, BOOL)) {
		UITouch *touch = [[event allTouches] anyObject];
		CGRect frame = [theSnapshot frame];
		
		NSInteger vert = touchDownPoint.y - [touch locationInView:[self superview]].y;
		if (vert > 0.0f) {
			wasSwipedAway = (vert > kSwipeThreshold);
			wasSwipedUp = YES;
			frame.origin.y = screenY - vert;
			CGFloat alpha = 1.0f - (vert / 300.0f);
			theSnapshot.alpha = (alpha > 0.0f) ? alpha:0.0f;
		} else {
			wasSwipedAway = NO;
			frame.origin.y = screenY;
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
			_iconBadge.alpha = 0.0f;
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
		frame.origin.y = screenY;
		[theSnapshot setFrame:frame];
		
		theSnapshot.alpha = 1.0f;
		_closeButton.alpha = 1.0f;
		_titleView.alpha = 1.0f;
		_iconView.alpha = 1.0f;
		_iconBadge.alpha = 1.0f;
		
		[UIView commitAnimations];
		
		UITouch *touch = [[event allTouches] anyObject];
		if (!wasSwipedUp && ([touch locationInView:[self superview]].y - touchDownPoint.y > kSwipeThreshold)) {
			if ([_delegate respondsToSelector:@selector(snapshotViewDidSwipeOut:)])
				[_delegate snapshotViewDidSwipeOut:self];
		}
	}
}

- (void)layoutSubviews
{
	UIEdgeInsets padding;
	padding.top = 12.0f;
	padding.bottom = 20.0f;
	padding.left = 4.0f;
	padding.right = 4.0f;
	if (GetPreference(PSWShowApplicationTitle, BOOL))
		padding.bottom += 32.0f;
	if (!isZoomed) {
		padding.left += 6.0f;
		padding.right += 6.0f;
		padding.top += 12.0f;
		padding.bottom += 10.0f;
	}
	
	CGSize snapshotSize = [self reloadSnapshot];
#ifdef USE_IOSURFACE
	CGSize imageSize;
	PSWCropInsets snapshotCropInsets = [_application snapshotCropInsets];
	imageSize.width -= snapshotCropInsets.left + snapshotCropInsets.right;
	imageSize.height -= snapshotCropInsets.top + snapshotCropInsets.bottom;
	PSWSnapshotRotation snapshotRotation = [_application snapshotRotation];
	switch (snapshotRotation) {
		case PSWSnapshotRotation90Left:
		case PSWSnapshotRotation90Right:
			imageSize.width = snapshotSize.height;
			imageSize.height = snapshotSize.width;
			break;
		default:
			imageSize.width = snapshotSize.width;
			imageSize.height = snapshotSize.height;
			break;
	}
#else
	CGSize imageSize = snapshotSize;
#endif
	
	CGRect frame = [self frame];
	CGSize boundingSize = UIEdgeInsetsInsetRect(frame, padding).size;
		
	CGFloat ratioW = boundingSize.width  / imageSize.width;
	CGFloat ratioH = boundingSize.height / imageSize.height;
	CGFloat properRatio = (ratioW < ratioH) ? ratioW : ratioH;
	
	CGRect screenBounds;
	screenBounds.origin.x = 0.0f;
	screenBounds.origin.y = 0.0f;
	screenBounds.size.width = properRatio * snapshotSize.width;
	screenBounds.size.height = properRatio * snapshotSize.height;
	[screen setBounds:screenBounds];
		
	CGRect screenFrame;	
	screenFrame.size.width = properRatio * imageSize.width;
	screenFrame.size.height = properRatio * imageSize.height;
	screenFrame.origin.x = (NSInteger) ((frame.size.width - screenFrame.size.width) / 2.0f);
	screenFrame.origin.y = (NSInteger) ((frame.size.height - screenFrame.size.height) / 2.0f);

	if (GetPreference(PSWShowApplicationTitle, BOOL))
		screenFrame.origin.y -= 16.0f;
	
	screenY = screenFrame.origin.y;
	
	CGPoint screenCenter;
	screenCenter.x = screenFrame.origin.x + screenFrame.size.width * 0.5f;
	screenCenter.y = screenFrame.origin.y + screenFrame.size.height * 0.5f;
	[screen setCenter:screenCenter];
	
	// Apply/clear mask
	CALayer *screenLayer = [screen layer];
	if (GetPreference(PSWRoundedCornerRadius, float) == 0.0f) {
		[screenLayer setMask:nil];
	} else {
		CGImageRef maskImage = [PSWGetCachedCornerMaskOfSize(screenFrame.size, GetPreference(PSWRoundedCornerRadius, float)) CGImage];
		CALayer *maskLayer = [screenLayer mask];
		if ([maskLayer contents] != (id)maskImage) {
			if (!maskLayer)
				maskLayer = [CALayer layer];
			CGRect maskFrame;
			maskFrame.origin.x = 0.0f;
			maskFrame.origin.y = 0.0f;
			maskFrame.size = screenFrame.size;
			[maskLayer setFrame:maskFrame];
			[maskLayer setContents:(id)maskImage];
			[screenLayer setMask:maskLayer];
		}
	}
	
	// Apply rotation
#ifdef USE_IOSURFACE
	CGAffineTransform transform;
	switch (snapshotRotation) {
		case PSWSnapshotRotation90Left:
			transform = CGAffineTransformMakeRotation(0.5f * M_PI);
			break;
		case PSWSnapshotRotation90Right:
			transform = CGAffineTransformMakeRotation(-0.5f * M_PI);
			break;
		case PSWSnapshotRotation180:
			transform = CGAffineTransformMakeRotation(M_PI);
			break;
		default:
			transform = CGAffineTransformIdentity;
			break;
	}
	screen.transform = transform;
#endif
	
	// Reposition and resize close button
	CGRect closeButtonFrame;
	closeButtonFrame.size = [PSWImage(@"closebox") size];
	closeButtonFrame.origin.x = (NSInteger)(screenFrame.origin.x - closeButtonFrame.size.width / 2.0f);
	closeButtonFrame.origin.y = (NSInteger)(screenFrame.origin.y - closeButtonFrame.size.height / 2.0f);
	[_closeButton setFrame:closeButtonFrame];
	
	// Reposition and resize title label
	NSString *title = [_application displayName];
	CGSize textSize = [title sizeWithFont:kTitleFont];
	CGRect titleFrame;
	titleFrame.size = textSize;
	titleFrame.origin.x = (NSInteger) ((self.frame.size.width - textSize.width) / 2 + 9.0f);
	titleFrame.origin.y = (NSInteger) (self.frame.size.height - 25.0f - textSize.height);
	[_titleView setFrame:titleFrame];
	
	// Reposition and resize icon
	CGSize iconSize = CGSizeMake(24.0f, 24.0f);
	CGRect iconFrame;
	iconFrame.size = iconSize;
	iconFrame.origin.x = (NSInteger) (titleFrame.origin.x - 9.0f - iconSize.width);
	iconFrame.origin.y = (NSInteger) (self.frame.size.height - 23.0f - iconSize.height);
	[_iconView setFrame:iconFrame];
	
	// Reposition and resize badge
	UIImage *badgeImage = PSWImage(@"badge");
	NSString *badgeText = [_application badgeText];
	if (badgeImage) {
		CGRect badgeFrame;
		badgeFrame.size = [badgeImage size];
		CGFloat minWidth = [badgeText sizeWithFont:kBadgeFont].width + 19.0f;
		
		if (badgeFrame.size.width < minWidth) {
			badgeFrame.size.width = minWidth;
			badgeImage = PSWScaledImage(@"badge", badgeFrame.size);
		}
		
		badgeFrame.origin.x = (NSInteger) (screenFrame.origin.x + screenFrame.size.width - badgeFrame.size.width + (badgeFrame.size.height / 2.0f));
		badgeFrame.origin.y = (NSInteger) (screenFrame.origin.y - (badgeFrame.size.height / 2.0f) + 2.0f);
		[_iconBadge setFrame:badgeFrame];
		[[_iconBadge layer] setContents:(id)[badgeImage CGImage]];
		badgeFrame.origin = CGPointZero;
		badgeFrame.size.height -= 8.0f;
		[_badgeLabel setFrame:badgeFrame];
	}	
	
}

- (id)initWithFrame:(CGRect)frame application:(PSWApplication *)application
{
    if ((self = [super initWithFrame:frame])) {
		_application = [application retain];
		_application.delegate = self;
		self.userInteractionEnabled = YES;
		self.opaque = NO;
		
		// Add Snapshot layer
		screen = [UIButton buttonWithType:UIButtonTypeCustom];
		[screen setClipsToBounds:YES];
		[screen setHidden:NO];
		
		[screen addTarget:self action:@selector(snapshot:touchUpInside:) forControlEvents:UIControlEventTouchUpInside];
		[screen addTarget:self action:@selector(snapshot:didStartDrag:) forControlEvents:UIControlEventTouchDown];
		[screen addTarget:self action:@selector(snapshot:didDrag:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
		[screen addTarget:self action:@selector(snapshot:didEndDrag:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchDragExit | UIControlEventTouchUpOutside | UIControlEventTouchUpInside];
		[self addSubview:screen];
		
		// Add close button
		_closeButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		[_closeButton setBackgroundImage:PSWImage(@"closebox") forState:UIControlStateNormal];
		[_closeButton addTarget:self action:@selector(_closeButtonWasPushed) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:_closeButton];
		[_closeButton setHidden:!GetPreference(PSWShowCloseButton, BOOL)];
		
		// Add icon
		_iconView = [[UIImageView alloc] init];
		[_iconView setImage:[_application themedIcon]];
		[self addSubview:_iconView];
		[_iconView setHidden:!(GetPreference(PSWShowIcon, BOOL) && GetPreference(PSWShowApplicationTitle, BOOL))];
		
		// Add title label
		_titleView = [[UILabel alloc] init];
		_titleView.font = kTitleFont;
		_titleView.backgroundColor = [UIColor clearColor];
		_titleView.textColor = [UIColor whiteColor]; 
		_titleView.text = [_application displayName];
		[self addSubview:_titleView];
		[_titleView setHidden:!GetPreference(PSWShowApplicationTitle, BOOL)];
		
		// Add badge
		_iconBadge = [[UIView alloc] init];
		[self addSubview:_iconBadge];
		[_iconBadge setHidden:!GetPreference(PSWShowBadges, BOOL)];
		
		// Add badge label
		_badgeLabel = [[UILabel alloc] init];
		[_badgeLabel setBackgroundColor:[UIColor clearColor]];
		[_badgeLabel setTextColor:[UIColor whiteColor]];
		[_badgeLabel setFont:kBadgeFont];
		[_badgeLabel setTextAlignment:UITextAlignmentCenter];
		[_iconBadge addSubview:_badgeLabel];
		[_badgeLabel release];
		
		// Setup initial badge
		// XXX: this is a hack
		[self applicationBadgeDidChange:_application];
				
		// Layout and draw!
		[self setNeedsLayout];
		[self layoutIfNeeded];
	}
    return self;
}

- (void)dealloc
{
	_application.delegate = nil;
	[_titleView release];
	[_iconView release];
	[_closeButton release];
	[_iconBadge release];
	[_application release];
	
    [super dealloc];
}

- (CGSize)reloadSnapshot
{
	id snapshot = [_application snapshot];
	CGSize size;
	CALayer *layer = [screen layer];
	[layer setContents:snapshot];
	if (snapshot) {
		CFTypeID snapshotType = CFGetTypeID(snapshot);
		if (snapshotType == CGImageGetTypeID()) {
			size.width = (CGFloat) CGImageGetWidth((CGImageRef)snapshot);
			size.height = (CGFloat) CGImageGetHeight((CGImageRef)snapshot);
#ifdef USE_IOSURFACE
		} else if (snapshotType == IOSurfaceGetTypeID()) {
			size.width = (CGFloat) IOSurfaceGetWidth((IOSurfaceRef)snapshot);
			size.height = (CGFloat) IOSurfaceGetHeight((IOSurfaceRef)snapshot);
#endif
		} else {
			size.width = 320.0f;
			size.height = 480.0f;
		}
	} else {
		size.width = 320.0f;
		size.height = 480.0f;
	}
#ifdef USE_IOSURFACE
	PSWCropInsets cropInsets = [_application snapshotCropInsets];
	CGRect contentsRect;
	contentsRect.origin.x = cropInsets.left / size.width;
	contentsRect.origin.y = cropInsets.top / size.height;
	contentsRect.size.width = 1.0f - contentsRect.origin.x - cropInsets.right / size.width;
	contentsRect.size.height = 1.0f - contentsRect.origin.y - cropInsets.bottom / size.height;
	[layer setContentsRect:contentsRect];
#endif
	return size;
}

#pragma mark Properties

- (void)_closeButtonWasPushed
{
	if ([_delegate respondsToSelector:@selector(snapshotViewClosed:)])
		[_delegate snapshotViewClosed:self];
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
	
	CGFloat alpha = _focused ? 1.0f : 0.0f;
	[_closeButton setAlpha:alpha];
	[_titleView setAlpha:alpha];
	[_iconView setAlpha:alpha];
	[_iconBadge setAlpha:alpha];
	
	if (animated) {
		[UIView commitAnimations];
	}
}
- (void)setFocused:(BOOL)focused
{
	[self setFocused:focused animated:YES];
}

- (BOOL)isZoomed
{
	return isZoomed;
}
- (void)setZoomed:(BOOL)zoomed animated:(BOOL)animated
{
	if (zoomed && !GetPreference(PSWAllowsZoom, BOOL)) return;
	
	if (zoomed != isZoomed) {
		if (animated) {
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:0.33f];
		}
			
		isZoomed = zoomed;
		[self setNeedsLayout];
		[self layoutIfNeeded];
			
		if (animated) {
			[UIView commitAnimations];
		}
	}
}
- (void)setZoomed:(BOOL)zoomed
{
	[self setZoomed:zoomed animated:YES];
}

#pragma mark PSWApplicationDelegate

- (void)applicationSnapshotDidChange:(PSWApplication *)application
{
	[self setNeedsLayout];
	[self layoutIfNeeded];
}

- (void)applicationBadgeDidChange:(PSWApplication *)application
{
	NSString *badgeText = [_application badgeText];
	if ([badgeText length] > 0) {
		[_badgeLabel setText:badgeText];
		if (GetPreference(PSWShowBadges, BOOL)) {
			[_iconBadge setHidden:NO];
		}
	} else {
		[_iconBadge setHidden:YES];
	}
	
	[self setNeedsLayout];
	[self layoutIfNeeded];
}

@end
