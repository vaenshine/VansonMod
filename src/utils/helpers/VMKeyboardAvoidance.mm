#import "VMKeyboardAvoidance.h"
#import <objc/runtime.h>

@interface VMKeyboardAvoidance ()
@property(nonatomic, weak) UIScrollView *scrollView;
@property(nonatomic, assign) UIEdgeInsets originalContentInset;
@property(nonatomic, assign) UIEdgeInsets originalIndicatorInset;
@property(nonatomic, assign) BOOL avoidingKeyboard;
@property(nonatomic, assign) CGRect keyboardFrame;
@property(nonatomic, assign) BOOL hasKeyboardFrame;
@end

@implementation VMKeyboardAvoidance

+ (void)installForScrollView:(UIScrollView *)scrollView {
  static char associationKey;
  if (!scrollView || objc_getAssociatedObject(scrollView, &associationKey)) return;
  VMKeyboardAvoidance *avoidance = [self new];
  avoidance.scrollView = scrollView;
  NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
  [center addObserver:avoidance selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
  [center addObserver:avoidance selector:@selector(keyboardHidden:) name:UIKeyboardWillHideNotification object:nil];
  [center addObserver:avoidance selector:@selector(editingBegan:) name:UITextFieldTextDidBeginEditingNotification object:nil];
  [center addObserver:avoidance selector:@selector(editingBegan:) name:UITextViewTextDidBeginEditingNotification object:nil];
  objc_setAssociatedObject(scrollView, &associationKey, avoidance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (UIView *)firstResponderInView:(UIView *)view {
  if (view.isFirstResponder) return view;
  for (UIView *child in view.subviews) {
    UIView *responder = [self firstResponderInView:child];
    if (responder) return responder;
  }
  return nil;
}

- (void)keyboardChanged:(NSNotification *)notification {
  self.keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  self.hasKeyboardFrame = YES;
  [self updateWithUserInfo:notification.userInfo];
}

- (void)keyboardHidden:(NSNotification *)notification {
  self.hasKeyboardFrame = NO;
  [self updateWithUserInfo:notification.userInfo];
}

- (void)editingBegan:(NSNotification *)notification {
  if ([notification.object isKindOfClass:UIView.class] && [notification.object isDescendantOfView:self.scrollView]) {
    [self updateWithUserInfo:nil];
  }
}

- (void)updateWithUserInfo:(NSDictionary *)userInfo {
  UIScrollView *scrollView = self.scrollView;
  UIWindow *window = scrollView.window;
  BOOL visible = window != nil;
  for (UIView *view = scrollView; view; view = view.superview) {
    if (view.hidden || view.alpha < 0.01) visible = NO;
  }
  UIView *responder = visible ? [self firstResponderInView:scrollView] : nil;
  CGFloat overlap = 0;
  if (responder && self.hasKeyboardFrame) {
    CGRect inWindow = [window convertRect:self.keyboardFrame fromCoordinateSpace:window.screen.coordinateSpace];
    CGRect keyboard = [scrollView convertRect:inWindow fromView:window];
    CGRect intersection = CGRectIntersection(scrollView.bounds, keyboard);
    // A floating keyboard does not cover the bottom edge of the form.
    if (!CGRectIsNull(intersection) && CGRectGetMaxY(keyboard) >= CGRectGetMaxY(scrollView.bounds) - 1) {
      overlap = CGRectGetHeight(intersection);
    }
  }
  if (overlap <= 0 && !self.avoidingKeyboard) return;
  if (!self.avoidingKeyboard) {
    self.originalContentInset = scrollView.contentInset;
    self.originalIndicatorInset = scrollView.verticalScrollIndicatorInsets;
  }
  CGFloat automaticBottomInset = MAX(0, scrollView.adjustedContentInset.bottom - scrollView.contentInset.bottom);
  UIEdgeInsets content = self.originalContentInset;
  UIEdgeInsets indicator = self.originalIndicatorInset;
  content.bottom += MAX(0, overlap - automaticBottomInset);
  indicator.bottom += MAX(0, overlap - automaticBottomInset);
  self.avoidingKeyboard = overlap > 0;
  NSTimeInterval duration = userInfo ? [userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue] : 0.2;
  UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction;
  if (userInfo) options |= [userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16;
  [UIView animateWithDuration:duration delay:0 options:options animations:^{
    scrollView.contentInset = content;
    scrollView.verticalScrollIndicatorInsets = indicator;
    if (responder && overlap > 0) {
      CGRect field = [responder convertRect:responder.bounds toView:scrollView];
      [scrollView scrollRectToVisible:CGRectInset(field, 0, -12) animated:NO];
    }
  } completion:nil];
}

@end
