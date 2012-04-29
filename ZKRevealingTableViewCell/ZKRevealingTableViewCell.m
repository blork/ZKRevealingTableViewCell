//
//  ZKRevealingTableViewCell.m
//  ZKRevealingTableViewCell
//
//  Created by Alex Zielenski on 4/29/12.
//  Copyright (c) 2012 Alex Zielenski. All rights reserved.
//

#import "ZKRevealingTableViewCell.h"
#import <QuartzCore/QuartzCore.h>

@interface ZKRevealingTableViewCell () {
	BOOL _revealing;
	ZKRevealingTableViewCellDirection _direction;
}

@property (nonatomic, retain) UIPanGestureRecognizer   *_panGesture;
@property (nonatomic, assign) CGFloat _initialTouchPositionX;
@property (nonatomic, assign) CGFloat _initialHorizontalCenter;
@property (nonatomic, assign) ZKRevealingTableViewCellDirection _lastDirection;

- (void)_slideInContentViewFromDirection:(ZKRevealingTableViewCellDirection)direction offsetMultiplier:(CGFloat)multiplier;
- (void)_slideOutContentViewInDirection:(ZKRevealingTableViewCellDirection)direction;

- (void)_pan:(UIPanGestureRecognizer *)panGesture;

- (void)_setRevealing:(BOOL)revealing;

- (CGFloat)_originalCenter;
- (CGFloat)_bounceMultiplier;

- (BOOL)_shouldDragLeft;
- (BOOL)_shouldDragRight;
- (BOOL)_shouldReveal;

@end

@implementation ZKRevealingTableViewCell

#pragma mark - Private Properties

@synthesize _panGesture;
@synthesize _initialTouchPositionX;
@synthesize _initialHorizontalCenter;
@synthesize _lastDirection;

#pragma mark - Public Properties

@dynamic revealing;
@synthesize direction    = _direction;
@synthesize delegate     = _delegate;
@synthesize shouldBounce = _shouldBounce;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.direction = ZKRevealingTableViewCellDirectionBoth;
		self.shouldBounce = YES;
		
		self._panGesture = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_pan:)] autorelease];
		self._panGesture.delegate = self;
		
		[self addGestureRecognizer:self._panGesture];
		
		self.contentView.backgroundColor = [UIColor whiteColor];
		
		UIView *backgroundView         = [[[UIView alloc] initWithFrame:self.contentView.frame] autorelease];
		backgroundView.backgroundColor = [UIColor greenColor];
		self.backgroundView            = backgroundView;
    }
    return self;
}

- (void)dealloc
{
	self._panGesture = nil;
	[super dealloc];
}

#pragma mark - Accessors

- (BOOL)isRevealing
{
	return _revealing;
}

- (void)setRevealing:(BOOL)revealing
{
	// Don't change the value if its already that value.
	// Reveal unless the delegate says no
	if (revealing == _revealing || 
		(revealing && self._shouldReveal))
		return;
	
	[self _setRevealing:revealing];
	
	if (self.isRevealing)
		[self _slideOutContentViewInDirection:self._lastDirection];
	else
		[self _slideInContentViewFromDirection:self._lastDirection offsetMultiplier:self._bounceMultiplier];
}

- (void)_setRevealing:(BOOL)revealing
{
	[self willChangeValueForKey:@"isRevealing"];
	_revealing = revealing;
	[self didChangeValueForKey:@"isRevealing"];
	
	if (self.isRevealing)
		[self.delegate cellDidReveal:self];
}

- (BOOL)_shouldReveal
{
	return ([self.delegate cellShouldReveal:self] || ![self.delegate respondsToSelector:@selector(cellShouldReveal:)]);
}

#pragma mark - Handing Touch

- (void)_pan:(UIPanGestureRecognizer *)recognizer
{		
	CGPoint translation           = [recognizer translationInView:self];
	CGPoint currentTouchPoint     = [recognizer locationInView:self];
	CGPoint velocity              = [recognizer velocityInView:self];
	
	CGFloat originalCenter        = self._originalCenter;
	CGFloat currentTouchPositionX = currentTouchPoint.x;
	CGFloat panAmount             = self._initialTouchPositionX - currentTouchPositionX;
	CGFloat newCenterPosition     = self._initialHorizontalCenter - panAmount;
	CGFloat centerX               = self.contentView.center.x;

	if (recognizer.state == UIGestureRecognizerStateBegan) {
		
		// Set a baseline for the panning
		self._initialTouchPositionX = currentTouchPositionX;
		self._initialHorizontalCenter = self.contentView.center.x;
		
	} else if (recognizer.state == UIGestureRecognizerStateChanged) {
		
		// If the pan amount is negative, then the last direction is left, and vice versa.
		if (newCenterPosition - centerX < 0)
			self._lastDirection = ZKRevealingTableViewCellDirectionLeft;
		else
			self._lastDirection = ZKRevealingTableViewCellDirectionRight;
		
		// Don't let you drag past a certain point depending on direction
		if ((newCenterPosition < originalCenter && !self._shouldDragLeft) || (newCenterPosition > originalCenter && !self._shouldDragRight))
			newCenterPosition = originalCenter;
		
		// Let's not go waaay out of bounds
		if (newCenterPosition > self.bounds.size.width + originalCenter)
			newCenterPosition = self.bounds.size.width + originalCenter;
		
		else if (newCenterPosition < -originalCenter)
			newCenterPosition = -originalCenter;
		
		CGPoint center = self.contentView.center;
		center.x = newCenterPosition;
		
		self.contentView.layer.position = center;
		
	} else if (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled) {
				
		// Swiping left, velocity is below 0.
		// Swiping right, it is above 0
		// If the velocity is above 250 at any point in the pan, push it to the acceptable side
		// Otherwise, if we are 60 points in, push to the other side
		// If we are < 60 points in, bounce back
		
#define kMinimumVelocity 250.0
#define kMinimumPan      60.0
		
		CGFloat velocityX = velocity.x;
		
		BOOL push = (velocityX < -kMinimumVelocity);
		push |= (velocityX > kMinimumVelocity);
		push |= ((self._lastDirection == ZKRevealingTableViewCellDirectionLeft && translation.x < -kMinimumPan) || (self._lastDirection == ZKRevealingTableViewCellDirectionRight && translation.x > kMinimumPan));
		push &= self._shouldReveal;
		push &= ((self._lastDirection == ZKRevealingTableViewCellDirectionRight && self._shouldDragRight) || (self._lastDirection == ZKRevealingTableViewCellDirectionLeft && self._shouldDragLeft)); 
		
		if (velocityX > 0 && self._lastDirection == ZKRevealingTableViewCellDirectionLeft)
			push = NO;
		
		else if (velocityX < 0 && self._lastDirection == ZKRevealingTableViewCellDirectionRight)
			push = NO;
		
		if (push && !self.revealing) {
			
			[self _slideOutContentViewInDirection:self._lastDirection];
			
			[self _setRevealing:YES];
		} else {
			
			[self _slideInContentViewFromDirection:self._lastDirection offsetMultiplier:self._bounceMultiplier];
			
			[self _setRevealing:NO];
		}
	}
}

- (BOOL)_shouldDragLeft
{
	return (self.direction == ZKRevealingTableViewCellDirectionBoth || self.direction == ZKRevealingTableViewCellDirectionLeft);
}

- (BOOL)_shouldDragRight
{
	return (self.direction == ZKRevealingTableViewCellDirectionBoth || self.direction == ZKRevealingTableViewCellDirectionRight);
}

- (CGFloat)_originalCenter
{
	return ceil(self.bounds.size.width / 2);
}

- (CGFloat)_bounceMultiplier
{
	return MIN(ABS(self._originalCenter - self.contentView.center.x) / kMinimumPan, 1.0);
}

#pragma mark - Sliding
#define kBOUNCE_DISTANCE 15.0
void LR_offsetView(UIView *view, CGFloat offsetX, CGFloat offsetY)
{
	view.frame = CGRectOffset(view.frame, offsetX, offsetY);
}

- (void)_slideInContentViewFromDirection:(ZKRevealingTableViewCellDirection)direction offsetMultiplier:(CGFloat)multiplier
{
	CGFloat bounceDistance;
	
	switch (direction) {
		case ZKRevealingTableViewCellDirectionLeft:
			bounceDistance = kBOUNCE_DISTANCE * multiplier;
			break;
		case ZKRevealingTableViewCellDirectionRight:
			bounceDistance = -kBOUNCE_DISTANCE * multiplier;
			break;
		default:
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Unhandled gesture direction" userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:direction] forKey:@"direction"]];
			break;
	}
	
	[UIView animateWithDuration:0.1
						  delay:0 
						options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionAllowUserInteraction 
					 animations:^{ self.contentView.center = CGPointMake(self._originalCenter, self.contentView.center.y); } 
					 completion:^(BOOL f) {
						 
						 if (self.shouldBounce) {
						 
							 [UIView animateWithDuration:0.1 delay:0 
												 options:UIViewAnimationCurveLinear
											  animations:^{ LR_offsetView(self.contentView, bounceDistance, 0); } 
											  completion:^(BOOL f) {                     
												  
												  [UIView animateWithDuration:0.1 delay:0 
																	  options:UIViewAnimationCurveLinear
																   animations:^{ LR_offsetView(self.contentView, -bounceDistance, 0); } 
																   completion:NULL];
											  }
							  ]; 
							 
						 }
					 }];
}

- (void)_slideOutContentViewInDirection:(ZKRevealingTableViewCellDirection)direction;
{
	CGFloat x;
	
	switch (direction) {
		case ZKRevealingTableViewCellDirectionLeft:
			x = - self._originalCenter;
			break;
		case ZKRevealingTableViewCellDirectionRight:
			x = self.contentView.frame.size.width + self._originalCenter;
			break;
		default:
			@throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Unhandled gesture direction" userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInteger:direction] forKey:@"direction"]];
			break;
	}
	
	[UIView animateWithDuration:0.2 
						  delay:0 
						options:UIViewAnimationOptionCurveEaseOut 
					 animations:^{ self.contentView.center = CGPointMake(x, self.contentView.center.y); } 
					 completion:NULL];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
	UIScrollView *superview = (UIScrollView *)self.superview;
	UIPanGestureRecognizer *gest = superview.panGestureRecognizer;
	
	return (gest.state != UIGestureRecognizerStateBegan && gest.state != UIGestureRecognizerStateChanged && [gest translationInView:superview].y <= 5.0);
}

@end
