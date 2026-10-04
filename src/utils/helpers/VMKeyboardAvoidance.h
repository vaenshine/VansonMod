#import <UIKit/UIKit.h>

/// Keeps form fields above the keyboard and preserves the scroll view's insets.
@interface VMKeyboardAvoidance : NSObject
+ (void)installForScrollView:(UIScrollView *)scrollView;
@end
