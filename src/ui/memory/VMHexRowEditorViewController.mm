#import "VMHexRowEditorViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#define TR(key) ([[VMLocalization shared] localizedString:key])
@interface VMHexRowEditorViewController () <UITextViewDelegate, UIGestureRecognizerDelegate>
@property(nonatomic, strong) UITextView *hexTextView;
@property(nonatomic, strong) UITextView *asciiTextView;
@property(nonatomic, strong) UILabel *addressDisplayLabel;
@property(nonatomic, strong) UILabel *hexLabel;
@property(nonatomic, strong) UILabel *asciiLabel;

@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UILabel *validationLabel;
@property(nonatomic) pid_t editingPid;
@property(nonatomic) mach_port_t editingTask;
@property(nonatomic) BOOL saving;
@property(nonatomic) BOOL savedPopGestureEnabled;
@property(nonatomic) BOOL hasSavedPopGestureState;
@property(nonatomic, weak) UIGestureRecognizer *protectedPopGesture;
@property(nonatomic, strong) UIBarButtonItem *draftBackButton;
@end
@implementation VMHexRowEditorViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = TR(@"Hex_Title");
  self.editingPid = [VMMemoryEngine shared].targetPid;
  self.editingTask = [VMMemoryEngine shared].targetTask;
  self.view.backgroundColor = [VMUIHelper canvasColor];

  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Save")
                                       style:UIBarButtonItemStyleDone
                                      target:self
                                      action:@selector(save)];
  UIBarButtonItem *saveButton = self.navigationItem.rightBarButtonItem;
  [VMUIHelper styleConfirmationItem:saveButton];
  UIBarButtonItem *reload = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"arrow.clockwise"] style:UIBarButtonItemStylePlain target:self action:@selector(reloadRow)];
  reload.accessibilityLabel = TR(@"Str_Reload");
  self.navigationItem.rightBarButtonItems = @[saveButton, reload];

  [self setupUI];
  [self populateData];



  UIEdgeInsets inset = self.scrollView.contentInset;
  inset.bottom += 16;
  self.scrollView.contentInset = inset;
  self.scrollView.scrollIndicatorInsets = inset;
}

- (void)setupUI {
  self.view.backgroundColor = [VMUIHelper canvasColor];

  self.scrollView = [[UIScrollView alloc] init];
  self.scrollView.showsHorizontalScrollIndicator = NO;
  self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
  self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  [self.view addSubview:self.scrollView];

  UIStackView *stackView = [[UIStackView alloc] init];
  stackView.axis = UILayoutConstraintAxisVertical;
  stackView.spacing = 16;
  stackView.alignment = UIStackViewAlignmentFill;
  stackView.distribution = UIStackViewDistributionFill;
  stackView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.scrollView addSubview:stackView];

  UILayoutGuide *g = self.view.safeAreaLayoutGuide;

  [NSLayoutConstraint activateConstraints:@[
    [self.scrollView.topAnchor constraintEqualToAnchor:g.topAnchor],
    [self.scrollView.bottomAnchor constraintEqualToAnchor:g.bottomAnchor],
    [self.scrollView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
    [self.scrollView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],

    [stackView.topAnchor
        constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor
                       constant:20],
    [stackView.bottomAnchor
        constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor
                       constant:-20],
    [stackView.leadingAnchor
        constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor
                       constant:16],
    [stackView.trailingAnchor
        constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor
                       constant:-16],

    [stackView.widthAnchor
        constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor
                       constant:-32]
  ]];

  self.addressDisplayLabel = [[UILabel alloc] init];
  self.addressDisplayLabel.textAlignment = NSTextAlignmentNatural;
  self.addressDisplayLabel.numberOfLines = 0;
  self.addressDisplayLabel.font =
      [UIFont monospacedSystemFontOfSize:16 weight:UIFontWeightSemibold];
  self.addressDisplayLabel.textColor = [UIColor labelColor];
  self.addressDisplayLabel.text =
      [NSString stringWithFormat:TR(@"Status_Editing_Addr"), self.address];
  [stackView addArrangedSubview:self.addressDisplayLabel];

  self.hexLabel = [[UILabel alloc] init];
  self.hexLabel.text = TR(@"Hex_Header_Edit");
  self.hexLabel.font = [UIFont boldSystemFontOfSize:14];
  self.hexLabel.textColor = [UIColor systemGrayColor];
  [stackView addArrangedSubview:self.hexLabel];

  self.hexTextView = [[UITextView alloc] init];
  self.hexTextView.showsHorizontalScrollIndicator = NO;
  self.hexTextView.font =
      [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightRegular];
  self.hexTextView.layer.cornerRadius = 16;
  self.hexTextView.layer.cornerCurve = kCACornerCurveContinuous;
  self.hexTextView.textContainerInset = UIEdgeInsetsMake(16, 12, 16, 12);
  self.hexTextView.autocorrectionType = UITextAutocorrectionTypeNo;
  self.hexTextView.smartQuotesType = UITextSmartQuotesTypeNo;
  self.hexTextView.smartDashesType = UITextSmartDashesTypeNo;
  self.hexTextView.accessibilityLabel = TR(@"Hex_Header_Edit");
  self.hexTextView.backgroundColor =
      [UIColor secondarySystemGroupedBackgroundColor];
  self.hexTextView.textColor = UIColor.labelColor;
  self.hexTextView.delegate = self;
  self.hexTextView.keyboardType = UIKeyboardTypeASCIICapable;
  self.hexTextView.autocapitalizationType =
      UITextAutocapitalizationTypeAllCharacters;
  [self.hexTextView.heightAnchor constraintEqualToConstant:144].active = YES;
  [stackView addArrangedSubview:self.hexTextView];
  UIToolbar *keyboardToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
  keyboardToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  keyboardToolbar.items = @[
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
    [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Hide_Keyboard") style:UIBarButtonItemStyleDone target:self action:@selector(hideKeyboard)]
  ];
  [VMUIHelper styleConfirmationItem:keyboardToolbar.items.lastObject];
  self.hexTextView.inputAccessoryView = keyboardToolbar;

  self.validationLabel = [UILabel new];
  self.validationLabel.numberOfLines = 0;
  self.validationLabel.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightMedium];
  self.validationLabel.adjustsFontForContentSizeCategory = YES;
  [stackView addArrangedSubview:self.validationLabel];

  self.asciiLabel = [[UILabel alloc] init];
  self.asciiLabel.text = TR(@"Hex_Header_Ascii");
  self.asciiLabel.font = [UIFont boldSystemFontOfSize:14];
  self.asciiLabel.textColor = [UIColor systemGrayColor];
  [stackView addArrangedSubview:self.asciiLabel];

  self.asciiTextView = [[UITextView alloc] init];
  self.asciiTextView.showsHorizontalScrollIndicator = NO;
  self.asciiTextView.font =
      [UIFont monospacedSystemFontOfSize:18 weight:UIFontWeightRegular];
  self.asciiTextView.layer.cornerRadius = 16;
  self.asciiTextView.layer.cornerCurve = kCACornerCurveContinuous;
  self.asciiTextView.textContainerInset = UIEdgeInsetsMake(16, 12, 16, 12);
  self.asciiTextView.accessibilityLabel = TR(@"Hex_Header_Ascii");
  self.asciiTextView.backgroundColor =
      [UIColor secondarySystemGroupedBackgroundColor];
  self.asciiTextView.editable = NO;
  self.asciiTextView.textColor = [VMUIHelper accentColor];
  [self.asciiTextView.heightAnchor constraintEqualToConstant:100].active = YES;
  [stackView addArrangedSubview:self.asciiTextView];

  UITapGestureRecognizer *tap =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(hideKeyboard)];
  tap.delegate = self;
  tap.cancelsTouchesInView = NO;
  [self.view addGestureRecognizer:tap];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(keyboardWillShow:)
             name:UIKeyboardWillChangeFrameNotification
           object:nil];
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(keyboardWillHide:)
             name:UIKeyboardWillHideNotification
           object:nil];
}

- (void)populateData {
  if (!self.originalData)
    return;
  NSMutableString *hexStr = [NSMutableString string];
  const uint8_t *bytes = (const uint8_t *)self.originalData.bytes;
  for (int i = 0; i < self.originalData.length; i++) {
    [hexStr appendFormat:@"%02X ", bytes[i]];
  }
  self.hexTextView.text = hexStr;
  [self updateASCII];
}

- (void)textViewDidChange:(UITextView *)textView {
  if (textView == self.hexTextView) {
    [self updateASCII];
  }
}

- (NSData *)draftData {
  NSString *clean = [[self.hexTextView.text componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] componentsJoinedByString:@""];
  NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
  if (clean.length == 0 || clean.length % 2 || [clean rangeOfCharacterFromSet:hex.invertedSet].location != NSNotFound) return nil;
  return [[VMMemoryEngine shared] dataFromHexString:clean];
}

- (void)updateASCII {
  NSData *data = [self draftData];
  NSMutableString *ascii = [NSMutableString string];
  const uint8_t *bytes = (const uint8_t *)data.bytes;
  for (NSUInteger i = 0; i < data.length; i++) [ascii appendFormat:@"%c", bytes[i] >= 0x20 && bytes[i] <= 0x7e ? bytes[i] : '.'];
  self.asciiTextView.text = ascii;
  BOOL valid = data && data.length == self.originalData.length;
  self.navigationItem.rightBarButtonItem.enabled = valid && !self.saving;
  [self updateDraftNavigationProtection];
  self.validationLabel.textColor = valid ? [UIColor secondaryLabelColor] : [UIColor systemRedColor];
  self.validationLabel.text = data ? [NSString stringWithFormat:@"%lu / %lu B · %@", (unsigned long)data.length, (unsigned long)self.originalData.length, TR(@"Str_Equal_Length")] : TR(@"Patch_Hex_Err");
}

- (BOOL)hasUnsavedChanges {
  return ![[self draftData] isEqualToData:self.originalData];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  UIGestureRecognizer *gesture = self.navigationController.interactivePopGestureRecognizer;
  if (!self.hasSavedPopGestureState && gesture) {
    self.protectedPopGesture = gesture;
    self.savedPopGestureEnabled = gesture.enabled;
    self.hasSavedPopGestureState = YES;
  }
  [self updateDraftNavigationProtection];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  if (self.hasSavedPopGestureState) {
    self.protectedPopGesture.enabled = self.savedPopGestureEnabled;
    self.hasSavedPopGestureState = NO;
    self.protectedPopGesture = nil;
  }
}

- (void)updateDraftNavigationProtection {
  BOOL dirty = [self hasUnsavedChanges];
  if (dirty && !self.draftBackButton) {
    self.draftBackButton = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"chevron.backward"]
        style:UIBarButtonItemStylePlain target:self action:@selector(requestClose)];
    self.draftBackButton.accessibilityLabel = TR(@"Btn_Cancel");
  }
  self.navigationItem.leftBarButtonItem = dirty ? self.draftBackButton : nil;
  self.draftBackButton.enabled = !self.saving;
  if (self.hasSavedPopGestureState)
    self.protectedPopGesture.enabled = self.savedPopGestureEnabled && !dirty && !self.saving;
}

- (void)leaveEditor {
  [self.view endEditing:YES];
  if (self.navigationController.topViewController == self && self.navigationController.viewControllers.count > 1)
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)requestClose {
  if (self.saving || self.presentedViewController) return;
  if (![self hasUnsavedChanges]) { [self leaveEditor]; return; }
  [self.view endEditing:YES];
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Str_Unsaved") message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Str_Discard") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    [alert dismissViewControllerAnimated:YES completion:^{ [self leaveEditor]; }];
  }]];
  UIAlertAction *save = [UIAlertAction actionWithTitle:TR(@"Btn_Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [alert dismissViewControllerAnimated:YES completion:^{ [self save]; }];
  }];
  save.enabled = [self draftData].length == self.originalData.length && self.originalData.length > 0;
  [alert addAction:save];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)hideKeyboard { [self.view endEditing:YES]; }

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
  for (UIView *view = touch.view; view; view = view.superview) {
    if ([view isKindOfClass:UITextView.class] || [view isKindOfClass:UIControl.class]) return NO;
  }
  return YES;
}

- (void)showEditorError:(NSString *)message {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Error") message:message preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)reloadRow {
  if (self.saving) return;
  void (^reload)(void) = ^{
    VMMemoryEngine *engine = [VMMemoryEngine shared];
    if (self.editingPid != engine.targetPid || self.editingTask != engine.targetTask) { [self showEditorError:TR(@"Str_Target_Changed")]; return; }
    NSData *data = [engine readRawMemory:self.address length:self.originalData.length];
    if (data.length != self.originalData.length) { [self showEditorError:TR(@"Str_Read_Failed")]; return; }
    self.originalData = data;
    [self populateData];
  };
  if ([[self draftData] isEqualToData:self.originalData]) { reload(); return; }
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Str_Unsaved") message:TR(@"Str_Reload") preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Str_Discard") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), reload);
  }]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)save {
  if (self.saving || self.presentedViewController) return;
  NSData *data = [self draftData];
  if (!data || data.length != self.originalData.length) { [self updateASCII]; return; }
  if ([data isEqualToData:self.originalData]) { [self leaveEditor]; return; }
  if (!self.delegate) { [self showEditorError:TR(@"Err_Write_Permission")]; return; }
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  if (self.editingPid != engine.targetPid || self.editingTask != engine.targetTask) {
    [self showEditorError:TR(@"Str_Target_Changed")];
    return;
  }
  NSData *current = [engine readRawMemory:self.address length:self.originalData.length];
  if (![current isEqualToData:self.originalData]) {
    [self showEditorError:TR(@"Str_Conflict")];
    return;
  }
  [self.view endEditing:YES];
  self.saving = YES;
  [self updateASCII];
  __weak __typeof(self) weakSelf = self;
  [self.delegate rowEditorDidSaveData:data atAddress:self.address completion:^(BOOL success, NSString *errorKey) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), ^{
      __typeof(self) strongSelf = weakSelf;
      if (!strongSelf) return;
      strongSelf.saving = NO;
      if (success) strongSelf.originalData = data;
      [strongSelf updateASCII];
      if (success) [strongSelf leaveEditor];
      else if (errorKey.length) [strongSelf showEditorError:TR(errorKey)];
    });
  }];
}

- (void)keyboardWillShow:(NSNotification *)notification {
  NSDictionary *info = [notification userInfo];
  CGRect keyboard = [self.view convertRect:[info[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromCoordinateSpace:self.view.window.screen.coordinateSpace];
  CGRect overlap = CGRectIntersection(self.scrollView.frame, keyboard);
  CGFloat height = CGRectIsNull(overlap) || CGRectIsEmpty(overlap) ||
      CGRectGetMaxY(overlap) < CGRectGetMaxY(self.scrollView.frame) - 1 ? 0 : overlap.size.height;

  if (self.scrollView) {
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, height + 16, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
  }
}

- (void)keyboardWillHide:(NSNotification *)notification {
  if (self.scrollView) {

    UIEdgeInsets inset = UIEdgeInsetsMake(0.0, 0.0, 16.0, 0.0);
    self.scrollView.contentInset = inset;
    self.scrollView.scrollIndicatorInsets = inset;
  }
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
