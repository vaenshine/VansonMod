#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A scrollable native editor with persistent field labels and inline validation.
@interface VMFormSheetViewController : UIViewController
@property(nonatomic, copy, nullable) NSString *message;
/// Return a localized error to keep the form open, or nil after saving succeeds.
@property(nonatomic, copy, nullable) NSString * _Nullable (^submitHandler)(VMFormSheetViewController *form);
/// Called after the successfully submitted sheet has finished dismissing.
@property(nonatomic, copy, nullable) void (^didSubmit)(void);
- (instancetype)initWithTitle:(NSString *)title submitTitle:(NSString *)submitTitle;
- (UITextField *)addTextFieldWithLabel:(NSString *)label
                               value:(nullable NSString *)value
                         placeholder:(nullable NSString *)placeholder
                        keyboardType:(UIKeyboardType)keyboardType;
- (UITextView *)addTextViewWithLabel:(NSString *)label
                             value:(nullable NSString *)value
                            height:(CGFloat)height;
- (UITextView *)addTextViewWithLabel:(NSString *)label
                             value:(nullable NSString *)value
                       placeholder:(nullable NSString *)placeholder
                            height:(CGFloat)height;
- (void)addSectionWithTitle:(NSString *)title;
- (void)addView:(UIView *)view;
- (void)presentFrom:(UIViewController *)presenter;
@end

NS_ASSUME_NONNULL_END
