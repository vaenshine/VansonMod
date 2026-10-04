#import "VMFormSheetViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/helpers/VMKeyboardAvoidance.h"
#import "include/VMLocalization.h"
#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMFormTextView : UITextView
@property(nonatomic, copy) NSString *placeholder;
@property(nonatomic, strong) UILabel *placeholderLabel;
@end

@implementation VMFormTextView
- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer {
  if ((self = [super initWithFrame:frame textContainer:textContainer])) {
    _placeholderLabel = [UILabel new];
    _placeholderLabel.numberOfLines = 0;
    _placeholderLabel.textColor = UIColor.placeholderTextColor;
    _placeholderLabel.userInteractionEnabled = NO;
    _placeholderLabel.isAccessibilityElement = NO;
    [self addSubview:_placeholderLabel];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshPlaceholder)
        name:UITextViewTextDidChangeNotification object:self];
  }
  return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
- (void)setPlaceholder:(NSString *)placeholder {
  _placeholder = [placeholder copy];
  self.placeholderLabel.text = placeholder;
  [self refreshPlaceholder];
}
- (void)setText:(NSString *)text {
  [super setText:text];
  [self refreshPlaceholder];
}
- (void)setAttributedText:(NSAttributedString *)text {
  [super setAttributedText:text];
  [self refreshPlaceholder];
}
- (void)refreshPlaceholder {
  self.placeholderLabel.hidden = self.text.length > 0 || self.placeholder.length == 0;
  self.accessibilityHint = self.text.length == 0 ? self.placeholder : nil;
  [self setNeedsLayout];
}
- (void)layoutSubviews {
  [super layoutSubviews];
  self.placeholderLabel.font = self.font;
  self.placeholderLabel.textAlignment = self.textAlignment;
  CGFloat padding = self.textContainer.lineFragmentPadding;
  CGFloat width = MAX(0, self.bounds.size.width - self.textContainerInset.left - self.textContainerInset.right - 2 * padding);
  CGFloat height = [self.placeholderLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
  self.placeholderLabel.frame = CGRectMake(self.textContainerInset.left + padding, self.textContainerInset.top,
      width, MIN(height, MAX(0, self.bounds.size.height - self.textContainerInset.top - self.textContainerInset.bottom)));
}
@end

@interface VMFormSheetViewController () <UITextFieldDelegate>
@property(nonatomic, copy) NSString *submitTitle;
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIStackView *stack;
@property(nonatomic, strong) UILabel *messageLabel;
@property(nonatomic, strong) UILabel *errorLabel;
@property(nonatomic, strong) NSMutableArray<UITextField *> *fields;
@property(nonatomic) BOOL submitting;
@end

@implementation VMFormSheetViewController
- (instancetype)initWithTitle:(NSString *)title submitTitle:(NSString *)submitTitle {
  if ((self = [super init])) {
    self.title = title;
    _submitTitle = [submitTitle copy];
    _fields = [NSMutableArray array];
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [VMUIHelper canvasColor];
  self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(cancel)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.submitTitle style:UIBarButtonItemStyleDone target:self action:@selector(submit)];
  [VMUIHelper styleConfirmationItem:self.navigationItem.rightBarButtonItem];
  self.scrollView = [UIScrollView new];
  self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  self.scrollView.alwaysBounceVertical = YES;
  self.scrollView.showsHorizontalScrollIndicator = NO;
  self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  [self.view addSubview:self.scrollView];
  self.stack = [UIStackView new];
  self.stack.axis = UILayoutConstraintAxisVertical;
  self.stack.spacing = 14;
  self.stack.translatesAutoresizingMaskIntoConstraints = NO;
  [self.scrollView addSubview:self.stack];
  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
    [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    [self.scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
    [self.scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
    [self.stack.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor constant:16],
    [self.stack.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor constant:-24],
    [self.stack.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor constant:16],
    [self.stack.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor constant:-16],
    [self.stack.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor constant:-32]
  ]];
  self.messageLabel = [self labelWithText:self.message];
  self.messageLabel.hidden = self.message.length == 0;
  [self.stack addArrangedSubview:self.messageLabel];
  self.errorLabel = [self labelWithText:nil];
  self.errorLabel.textColor = UIColor.systemRedColor;
  self.errorLabel.hidden = YES;
  [self.stack addArrangedSubview:self.errorLabel];
  [VMKeyboardAvoidance installForScrollView:self.scrollView];
}

- (UILabel *)labelWithText:(NSString *)text {
  UILabel *label = [UILabel new];
  label.text = text;
  label.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightMedium];
  label.adjustsFontForContentSizeCategory = YES;
  label.textColor = UIColor.secondaryLabelColor;
  label.numberOfLines = 0;
  return label;
}

- (void)setMessage:(NSString *)message {
  _message = [message copy];
  self.messageLabel.text = message;
  self.messageLabel.hidden = message.length == 0;
}

- (UIToolbar *)keyboardToolbar {
  UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
  toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  toolbar.items = @[
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
    [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Hide_Keyboard") style:UIBarButtonItemStyleDone target:self action:@selector(hideKeyboard)]
  ];
  [VMUIHelper styleConfirmationItem:toolbar.items.lastObject];
  return toolbar;
}

- (void)addLabeledView:(UIView *)view label:(NSString *)label {
  [self loadViewIfNeeded];
  UIStackView *group = [[UIStackView alloc] initWithArrangedSubviews:@[[self labelWithText:label], view]];
  group.axis = UILayoutConstraintAxisVertical;
  group.spacing = 6;
  [self.stack addArrangedSubview:group];
}

- (UITextField *)addTextFieldWithLabel:(NSString *)label value:(NSString *)value placeholder:(NSString *)placeholder keyboardType:(UIKeyboardType)keyboardType {
  UITextField *field = [UITextField new];
  [VMUIHelper styleTextField:field];
  field.text = value;
  field.placeholder = placeholder;
  field.keyboardType = keyboardType;
  field.autocorrectionType = UITextAutocorrectionTypeNo;
  field.autocapitalizationType = UITextAutocapitalizationTypeNone;
  field.smartQuotesType = UITextSmartQuotesTypeNo;
  field.smartDashesType = UITextSmartDashesTypeNo;
  field.returnKeyType = UIReturnKeyNext;
  field.delegate = self;
  field.inputAccessoryView = [self keyboardToolbar];
  field.accessibilityLabel = label;
  [field.heightAnchor constraintGreaterThanOrEqualToConstant:46].active = YES;
  [self addLabeledView:field label:label];
  [self.fields addObject:field];
  return field;
}

- (UITextView *)addTextViewWithLabel:(NSString *)label value:(NSString *)value height:(CGFloat)height {
  return [self addTextViewWithLabel:label value:value placeholder:nil height:height];
}

- (UITextView *)addTextViewWithLabel:(NSString *)label value:(NSString *)value placeholder:(NSString *)placeholder height:(CGFloat)height {
  VMFormTextView *text = [VMFormTextView new];
  text.text = value ?: @"";
  text.placeholder = placeholder;
  text.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular]];
  text.adjustsFontForContentSizeCategory = YES;
  text.backgroundColor = [VMUIHelper cardColor];
  text.textColor = UIColor.labelColor;
  text.layer.cornerRadius = 12;
  text.layer.cornerCurve = kCACornerCurveContinuous;
  text.textContainerInset = UIEdgeInsetsMake(12, 10, 12, 10);
  text.autocorrectionType = UITextAutocorrectionTypeNo;
  text.autocapitalizationType = UITextAutocapitalizationTypeNone;
  text.smartQuotesType = UITextSmartQuotesTypeNo;
  text.smartDashesType = UITextSmartDashesTypeNo;
  text.showsHorizontalScrollIndicator = NO;
  text.inputAccessoryView = [self keyboardToolbar];
  text.accessibilityLabel = label;
  [text.heightAnchor constraintEqualToConstant:MAX(88, height)].active = YES;
  [self addLabeledView:text label:label];
  return text;
}

- (void)addSectionWithTitle:(NSString *)title {
  [self loadViewIfNeeded];
  UILabel *label = [self labelWithText:title];
  label.font = [VMUIHelper scaledFontOfSize:16 weight:UIFontWeightSemibold];
  label.textColor = UIColor.labelColor;
  [self.stack addArrangedSubview:label];
}

- (void)addView:(UIView *)view {
  [self loadViewIfNeeded];
  if ([view isKindOfClass:UIScrollView.class]) ((UIScrollView *)view).showsHorizontalScrollIndicator = NO;
  [self.stack addArrangedSubview:view];
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
  NSUInteger index = [self.fields indexOfObjectIdenticalTo:field];
  if (index != NSNotFound && index + 1 < self.fields.count) [self.fields[index + 1] becomeFirstResponder];
  else [field resignFirstResponder];
  return YES;
}

- (void)hideKeyboard { [self.view endEditing:YES]; }

- (void)cancel {
  if (self.submitting) return;
  [self.view endEditing:YES];
  [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)submit {
  if (self.submitting) return;
  [self.view endEditing:YES];
  self.submitting = YES;
  self.navigationItem.rightBarButtonItem.enabled = NO;
  NSString *error = self.submitHandler ? self.submitHandler(self) : nil;
  if (error.length) {
    self.submitting = NO;
    self.navigationItem.rightBarButtonItem.enabled = YES;
    self.errorLabel.text = error;
    self.errorLabel.hidden = NO;
    [self.view layoutIfNeeded];
    [self.scrollView setContentOffset:CGPointMake(0, -self.scrollView.adjustedContentInset.top) animated:YES];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, error);
    return;
  }
  void (^completion)(void) = [self.didSubmit copy];
  [self.navigationController dismissViewControllerAnimated:YES completion:completion];
}

- (void)presentFrom:(UIViewController *)presenter {
  UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:self];
  [VMUIHelper applyNavigationAppearance:navigation];
  navigation.modalPresentationStyle = UIModalPresentationPageSheet;
  navigation.modalInPresentation = YES;
  navigation.preferredContentSize = CGSizeMake(540, 640);
  if (@available(iOS 15.0, *)) {
    [self loadViewIfNeeded];
    CGFloat fittingWidth = MIN(508, MAX(248, presenter.view.bounds.size.width - 32));
    CGSize content = [self.stack systemLayoutSizeFittingSize:CGSizeMake(fittingWidth, UILayoutFittingCompressedSize.height)
        withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    navigation.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
    navigation.sheetPresentationController.selectedDetentIdentifier = content.height + 80 > presenter.view.bounds.size.height * 0.5
        ? UISheetPresentationControllerDetentIdentifierLarge : UISheetPresentationControllerDetentIdentifierMedium;
    navigation.sheetPresentationController.prefersGrabberVisible = YES;
    navigation.sheetPresentationController.preferredCornerRadius = 20;
  }
  [presenter presentViewController:navigation animated:YES completion:nil];
}
@end
