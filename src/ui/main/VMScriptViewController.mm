#import "VMScriptViewController.h"
#import "../common/VMFormSheetViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/managers/VMScriptManager.h"
#import "VMScriptToolsViewController.h"
#import "include/VMDataSession.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerManager.h" // 用于获取路径工具
#import <objc/runtime.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMScriptViewController () <UITextViewDelegate>

@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) UILabel *infoLabel;
@property(nonatomic, strong) UITextView *editorView;
@property(nonatomic, strong) UITextView *consoleView;
@property(nonatomic, strong) UIScrollView *shortcutBar; 
@property(nonatomic, strong) UIStackView *shortcutStack;
@property(nonatomic, strong) UIView *bottomBar;
@property(nonatomic, strong) UIButton *btnRun;

@property(nonatomic, strong) UIButton *btnSave;
@property(nonatomic, strong) UIButton *btnUndo;
@property(nonatomic, strong) NSLayoutConstraint *navigationTitleWidthConstraint;
@property(nonatomic, strong) UIStackView *contentStack;
@property(nonatomic, strong) UIStackView *commandStack;
@property(nonatomic, strong) NSLayoutConstraint *contentBottomConstraint;
@property(nonatomic, copy) NSString *savedEditorText;
@property(nonatomic, strong) NSError *lastSaveError;
@property(nonatomic, strong) UIBarButtonItem *draftBackButton;
@property(nonatomic, weak) UIGestureRecognizer *protectedPopGesture;
@property(nonatomic, assign) BOOL savedPopGestureEnabled;
@property(nonatomic, assign) BOOL hasSavedPopGestureState;
@end

@implementation VMScriptViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor =
      [UIColor systemGroupedBackgroundColor]; 
  [self setupUI]; 

  [self setupNavigationTitle];

  self.navigationItem.rightBarButtonItem = nil;

  self.editorView.text = self.scriptModel.scriptContent;
  self.savedEditorText = self.editorView.text ?: @"";

  if (self.scriptModel.isImported) {
    self.editorView.editable = NO;
    self.editorView.textColor = [UIColor systemGrayColor];
    [self.btnSave setTitle:TR(@"Script_Btn_ReadOnly")
                  forState:UIControlStateNormal];
    self.btnSave.enabled = NO;
    self.btnSave.backgroundColor = [UIColor systemGrayColor];
    self.title = [NSString
        stringWithFormat:@"%@ %@", self.title, TR(@"Script_Title_ReadOnly")];
  }

  [self updateHeaderInfo];

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

- (void)updateHeaderInfo {
  NSString *info = [NSString
      stringWithFormat:@"%@ %@ | %@", TR(@"Script_Info_Author"),
                       self.scriptModel.author, self.scriptModel.desc ?: @""];
  self.infoLabel.text = [self hasUnsavedChanges]
      ? [NSString stringWithFormat:@"%@ · %@", TR(@"Str_Unsaved"), info]
      : info;
  self.btnUndo.enabled = !self.scriptModel.isImported && self.editorView.undoManager.canUndo;
  [self updateDraftNavigationProtection];
}

- (BOOL)hasUnsavedChanges {
  return !self.scriptModel.isImported && ![(self.editorView.text ?: @"")
      isEqualToString:(self.savedEditorText ?: @"")];
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
  [self restorePopGestureState];
}

- (void)restorePopGestureState {
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
  if (self.hasSavedPopGestureState) {
    self.protectedPopGesture.enabled = self.savedPopGestureEnabled && !dirty;
  }
}

- (void)leaveEditor {
  [self.view endEditing:YES];
  if (self.navigationController.topViewController == self && self.navigationController.viewControllers.count > 1) {
    [self.navigationController popViewControllerAnimated:YES];
  } else if (self.presentingViewController || self.navigationController.presentingViewController) {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)requestClose {
  if (![self hasUnsavedChanges]) { [self leaveEditor]; return; }
  [self.view endEditing:YES];
  if (self.presentedViewController) return;
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Str_Unsaved")
      message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Str_Discard") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
    [alert dismissViewControllerAnimated:YES completion:^{ [self leaveEditor]; }];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Save") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [alert dismissViewControllerAnimated:YES completion:^{
      if ([self saveScriptModelToDisk]) [self leaveEditor];
      else [self showSaveError];
    }];
  }]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)editNoteAction {
  if (self.scriptModel.isImported) {
    [self showToast:TR(@"Status_ReadOnly")];
    return;
  }

  VMFormSheetViewController *form = [[VMFormSheetViewController alloc] initWithTitle:TR(@"Title_Edit_Script_Info") submitTitle:TR(@"Btn_Save")];
  UITextField *name = [form addTextFieldWithLabel:TR(@"Script_Name_Label") value:self.scriptModel.note placeholder:TR(@"Script_Name_Placeholder") keyboardType:UIKeyboardTypeDefault];
  UITextView *description = [form addTextViewWithLabel:TR(@"Script_Desc_Label") value:self.scriptModel.desc placeholder:TR(@"Script_Desc_Placeholder") height:100];
  __weak __typeof(self) weakSelf = self;
  form.submitHandler = ^NSString *(VMFormSheetViewController *editor) {
    __typeof(self) strongSelf = weakSelf;
    if (!strongSelf) return TR(@"Err_Write_Permission");
    VMScriptModel *candidate = [strongSelf scriptModelForSaving];
    if (name.text.length) candidate.note = name.text;
    candidate.desc = description.text.length ? description.text : TR(@"Script_Default_Desc");
    if (![strongSelf writeScriptModelToDisk:candidate])
      return strongSelf.lastSaveError.localizedDescription ?: TR(@"Err_Write_Permission");
    strongSelf.scriptModel.note = candidate.note;
    strongSelf.scriptModel.desc = candidate.desc;
    strongSelf.scriptModel.bundleID = candidate.bundleID;
    return nil;
  };
  form.didSubmit = ^{
    [weakSelf updateNavigationTitle:weakSelf.scriptModel.note ?: TR(@"Script_Title_Default")];
    [weakSelf updateHeaderInfo];
  };
  [form presentFrom:self];
}

- (void)dealloc {
  [self restorePopGestureState];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)undoEditor {
  if (self.scriptModel.isImported) return;
  if ([self.editorView.undoManager canUndo]) {
    [self.editorView.undoManager undo];
    [self textViewDidChange:self.editorView];
  }
}

- (void)clearEditor {
  if (self.scriptModel.isImported)
    return; 

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:nil
                                          message:TR(@"Script_Clear_Confirm")
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
                                            [self clearEditorContents];
                                          }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearEditorContents {
  if (self.scriptModel.isImported || self.editorView.text.length == 0) return;
  self.editorView.selectedRange = NSMakeRange(0, self.editorView.text.length);
  [self.editorView insertText:@""];
  [self textViewDidChange:self.editorView];
}

- (void)setupUI {
  self.view.backgroundColor = [VMUIHelper canvasColor];
  self.hidesBottomBarWhenPushed = YES;
  UILayoutGuide *g = self.view.safeAreaLayoutGuide;
  self.contentStack = [[UIStackView alloc] init];
  self.contentStack.axis = UILayoutConstraintAxisVertical;
  self.contentStack.spacing = 12;
  self.contentStack.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.contentStack];
  self.contentBottomConstraint = [self.contentStack.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-16];
  [NSLayoutConstraint activateConstraints:@[
    [self.contentStack.topAnchor constraintEqualToAnchor:g.topAnchor constant:12],
    [self.contentStack.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
    [self.contentStack.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
    self.contentBottomConstraint
  ]];

  self.headerView = [UIView new];
  self.infoLabel = [UILabel new];
  self.infoLabel.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
  self.infoLabel.adjustsFontForContentSizeCategory = YES;
  self.infoLabel.textColor = UIColor.secondaryLabelColor;
  self.infoLabel.numberOfLines = 2;
  UIButton *undo = [UIButton buttonWithType:UIButtonTypeSystem];
  self.btnUndo = undo;
  undo.enabled = NO;
  [undo setImage:[UIImage systemImageNamed:@"arrow.uturn.backward"] forState:UIControlStateNormal];
  undo.accessibilityLabel = TR(@"Undo_Last_Modify");
  [undo addTarget:self action:@selector(undoEditor) forControlEvents:UIControlEventTouchUpInside];
  UIButton *clear = [UIButton buttonWithType:UIButtonTypeSystem];
  [clear setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
  clear.tintColor = UIColor.systemRedColor;
  clear.accessibilityLabel = TR(@"Timeline_Clear");
  clear.enabled = !self.scriptModel.isImported;
  [clear addTarget:self action:@selector(clearEditor) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *metadata = [[UIStackView alloc] initWithArrangedSubviews:@[self.infoLabel, undo, clear]];
  metadata.spacing = 8;
  metadata.alignment = UIStackViewAlignmentCenter;
  metadata.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerView addSubview:metadata];
  [NSLayoutConstraint activateConstraints:@[
    [metadata.topAnchor constraintEqualToAnchor:self.headerView.topAnchor],
    [metadata.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor],
    [metadata.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor],
    [metadata.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor],
    [undo.widthAnchor constraintEqualToConstant:44],
    [clear.widthAnchor constraintEqualToConstant:44]
  ]];
  for (UIButton *control in @[undo, clear]) {
    NSLayoutConstraint *height = [control.heightAnchor constraintEqualToConstant:44];
    height.priority = 999;
    height.active = YES;
  }
  [self.contentStack addArrangedSubview:self.headerView];

  self.editorView = [UITextView new];
  self.editorView.showsHorizontalScrollIndicator = NO;
  [VMUIHelper styleCard:self.editorView];
  self.editorView.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
      scaledFontForFont:[UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular]];
  self.editorView.adjustsFontForContentSizeCategory = YES;
  self.editorView.textContainerInset = UIEdgeInsetsMake(16, 12, 16, 12);
  self.editorView.autocapitalizationType = UITextAutocapitalizationTypeNone;
  self.editorView.autocorrectionType = UITextAutocorrectionTypeNo;
  self.editorView.smartQuotesType = UITextSmartQuotesTypeNo;
  self.editorView.smartDashesType = UITextSmartDashesTypeNo;
  self.editorView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  self.editorView.accessibilityLabel = TR(@"Script_Btn_EditCode");
  self.editorView.delegate = self;
  [self.editorView setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
  [self.contentStack addArrangedSubview:self.editorView];
  NSLayoutConstraint *editorMinimum = [self.editorView.heightAnchor constraintGreaterThanOrEqualToConstant:80];
  editorMinimum.priority = UILayoutPriorityDefaultHigh;
  editorMinimum.active = YES;
  UIToolbar *keyboardTools = [UIToolbar new];
  [keyboardTools sizeToFit];
  keyboardTools.items = @[
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
    [[UIBarButtonItem alloc] initWithTitle:TR(@"Common_Done") style:UIBarButtonItemStyleDone target:self action:@selector(dismissKeyboard)]
  ];
  [VMUIHelper styleConfirmationItem:keyboardTools.items.lastObject];
  self.editorView.inputAccessoryView = keyboardTools;

  UIButton *shortcut = [UIButton buttonWithType:UIButtonTypeSystem];
  [shortcut setTitle:TR(@"Script_Btn_Shortcut") forState:UIControlStateNormal];
  [shortcut addTarget:self action:@selector(onShortcutAction) forControlEvents:UIControlEventTouchUpInside];
  UIButton *examples = [UIButton buttonWithType:UIButtonTypeSystem];
  [examples setTitle:TR(@"Script_Btn_Template") forState:UIControlStateNormal];
  [examples addTarget:self action:@selector(onExampleAction) forControlEvents:UIControlEventTouchUpInside];
  self.commandStack = [[UIStackView alloc] initWithArrangedSubviews:@[shortcut, examples]];
  self.commandStack.spacing = 12;
  self.commandStack.distribution = UIStackViewDistributionFillEqually;
  shortcut.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:shortcut primary:NO];
  examples.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:examples primary:NO];
  [self.contentStack addArrangedSubview:self.commandStack];

  self.btnRun = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.btnRun setTitle:TR(@"Script_Btn_Run") forState:UIControlStateNormal];
  self.btnRun.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:self.btnRun primary:YES];
  [self.btnRun addTarget:self action:@selector(runScript) forControlEvents:UIControlEventTouchUpInside];
  self.btnSave = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.btnSave setTitle:TR(@"Script_Btn_Save") forState:UIControlStateNormal];
  self.btnSave.tintColor = [VMUIHelper accentColor];
  [VMUIHelper styleButton:self.btnSave primary:NO];
  [self.btnSave addTarget:self action:@selector(saveScript) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *actions = [[UIStackView alloc] initWithArrangedSubviews:@[self.btnRun, self.btnSave]];
  actions.spacing = 12;
  actions.distribution = UIStackViewDistributionFillEqually;
  [self.contentStack addArrangedSubview:actions];

  self.consoleView = [UITextView new];
  self.consoleView.showsHorizontalScrollIndicator = NO;
  [VMUIHelper styleCard:self.consoleView];
  self.consoleView.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleFootnote]
      scaledFontForFont:[UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular]];
  self.consoleView.adjustsFontForContentSizeCategory = YES;
  self.consoleView.textColor = UIColor.secondaryLabelColor;
  self.consoleView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
  self.consoleView.editable = NO;
  self.consoleView.accessibilityLabel = TR(@"Script_Console_Ready");
  self.consoleView.text = [NSString stringWithFormat:@"> %@", TR(@"Script_Console_Ready")];
  [self.contentStack addArrangedSubview:self.consoleView];
  NSLayoutConstraint *consoleHeight = [self.consoleView.heightAnchor constraintEqualToAnchor:g.heightAnchor multiplier:0.22];
  consoleHeight.priority = UILayoutPriorityDefaultHigh;
  consoleHeight.active = YES;
}

- (void)dismissKeyboard {
  [self.view endEditing:YES];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  // Keep the editable title inside the space left by the native back button.
  self.navigationTitleWidthConstraint.constant = MAX(80, MIN(260, self.view.bounds.size.width - 144));
}

- (void)textViewDidChange:(UITextView *)textView {
  if (textView != self.editorView) return;
  [self updateHeaderInfo];
}

- (void)onShortcutAction {
  VMScriptShortcutViewController *vc =
      [[VMScriptShortcutViewController alloc] init];
  vc.didSelectShortcut = ^(NSString *_Nonnull code) {
    if (code.length > 0) {
      [self smartInsertCode:code];
    }
  };

  UINavigationController *nav =
      [[UINavigationController alloc] initWithRootViewController:vc];

  if (@available(iOS 15.0, *)) {
    if (nav.sheetPresentationController) {
      nav.sheetPresentationController.detents = @[
        [UISheetPresentationControllerDetent mediumDetent],
        [UISheetPresentationControllerDetent largeDetent]
      ];
      nav.sheetPresentationController.prefersGrabberVisible = YES;
    }
  }

  [self presentViewController:nav animated:YES completion:nil];
}

- (void)onExampleAction {
  VMScriptExampleViewController *vc =
      [[VMScriptExampleViewController alloc] init];
  vc.didSelectShortcut = ^(NSString *_Nonnull code) {
    if (code.length > 0) {
      [self smartInsertCode:code];
    }
  };
  UINavigationController *nav =
      [[UINavigationController alloc] initWithRootViewController:vc];

  if (@available(iOS 15.0, *)) {
    if (nav.sheetPresentationController) {
      nav.sheetPresentationController.detents = @[
        [UISheetPresentationControllerDetent mediumDetent],
        [UISheetPresentationControllerDetent largeDetent]
      ];
      nav.sheetPresentationController.prefersGrabberVisible = YES;
    }
  }

  [self presentViewController:nav animated:YES completion:nil];
}

- (void)runScript {
  [self.view endEditing:YES];
  NSString *code = self.editorView.text;

  if (code.length == 0)
    return;

  self.btnRun.enabled = NO;
  self.btnRun.alpha = 1.0;
  self.consoleView.text =
      [NSString stringWithFormat:@"> %@\n", TR(@"Script_Console_Running")];

  [[VMScriptManager shared] runScript:code
                           completion:^(NSString *log) {
                             self.consoleView.text = log;
                             self.btnRun.enabled = YES;
                             self.btnRun.alpha = 1.0;

                             if (log.length > 0) {
                               NSRange range = NSMakeRange(log.length - 1, 1);
                               [self.consoleView scrollRangeToVisible:range];
                             }
                           }];
}

- (void)saveScript {
  if (self.scriptModel.isImported) return;
  if ([self saveScriptModelToDisk]) {
    [self showToast:TR(@"Msg_Save_Success")];
  } else {
    [self showSaveError];
  }
}

- (BOOL)saveScriptModelToDisk {
  if (self.scriptModel.isImported) return NO;
  VMScriptModel *candidate = [self scriptModelForSaving];
  candidate.scriptContent = self.editorView.text ?: @"";
  if (![self writeScriptModelToDisk:candidate]) return NO;
  self.scriptModel.scriptContent = candidate.scriptContent;
  self.scriptModel.bundleID = candidate.bundleID;
  self.savedEditorText = candidate.scriptContent;
  [self updateHeaderInfo];
  return YES;
}

- (VMScriptModel *)scriptModelForSaving {
  VMScriptModel *candidate = [VMScriptModel fromDictionary:[self.scriptModel toDictionary]];
  candidate.appName = self.scriptModel.appName;
  return candidate;
}

- (void)showSaveError {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Error")
      message:self.lastSaveError.localizedDescription ?: TR(@"Err_Write_Permission")
      preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)writeScriptModelToDisk:(VMScriptModel *)model {
  self.lastSaveError = nil;
  NSString *doc = [NSSearchPathForDirectoriesInDomains(
      NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
  if (!doc.length || !model.fileName.length) {
    self.lastSaveError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteInvalidFileNameError userInfo:nil];
    return NO;
  }
  NSString *bid = model.bundleID;
  if (!bid || bid.length == 0) {
    bid = [[VMMemoryEngine shared] currentBundleID] ?: TR(@"App_Unknown");
    model.bundleID = bid;
  }

  NSString *dir = [[doc stringByAppendingPathComponent:@"VansonMod/Script"]
      stringByAppendingPathComponent:bid];

  if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error]) {
      self.lastSaveError = error;
      return NO;
    }
  }

  NSString *path =
      [dir stringByAppendingPathComponent:model.fileName];

  VMDataSession *s = [VMDataSession sessionWithData:@[ model ]
                                           bundleID:bid
                                           dataType:@"script"];
  NSData *data = [s toJSONData];
  NSError *error = nil;
  BOOL success = [data writeToFile:path options:NSDataWritingAtomic error:&error];
  self.lastSaveError = error;
  return success;
}

- (void)setupNavigationTitle {
  UIView *titleView = [[UIView alloc] init];

  UILabel *lbl = [[UILabel alloc] init];
  lbl.text = self.scriptModel.note ?: TR(@"Script_Title_Default");
  lbl.font = [UIFont boldSystemFontOfSize:17];
  lbl.textColor = [UIColor labelColor];
  lbl.lineBreakMode = NSLineBreakByTruncatingTail;
  [lbl setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  lbl.translatesAutoresizingMaskIntoConstraints = NO;
  [titleView addSubview:lbl];
  objc_setAssociatedObject(self, "navTitleLabel", lbl,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  UIImageView *icon = nil;
  if (!self.scriptModel.isImported) {
    icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"pencil"]];
    icon.tintColor = [VMUIHelper accentColor];
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [titleView addSubview:icon];
  }

  if (icon) {
    [NSLayoutConstraint activateConstraints:@[
      [lbl.topAnchor constraintEqualToAnchor:titleView.topAnchor],
      [lbl.bottomAnchor constraintEqualToAnchor:titleView.bottomAnchor],
      [lbl.leadingAnchor constraintEqualToAnchor:titleView.leadingAnchor],
      [lbl.heightAnchor constraintEqualToConstant:44],
      [icon.leadingAnchor constraintEqualToAnchor:lbl.trailingAnchor constant:6],
      [icon.centerYAnchor constraintEqualToAnchor:lbl.centerYAnchor],
      [icon.trailingAnchor constraintEqualToAnchor:titleView.trailingAnchor],
      [icon.widthAnchor constraintEqualToConstant:16],
      [icon.heightAnchor constraintEqualToConstant:16]
    ]];
  } else {
    [NSLayoutConstraint activateConstraints:@[
      [lbl.topAnchor constraintEqualToAnchor:titleView.topAnchor],
      [lbl.bottomAnchor constraintEqualToAnchor:titleView.bottomAnchor],
      [lbl.leadingAnchor constraintEqualToAnchor:titleView.leadingAnchor],
      [lbl.trailingAnchor constraintEqualToAnchor:titleView.trailingAnchor],
      [lbl.heightAnchor constraintEqualToConstant:44]
    ]];
  }

  if (!self.scriptModel.isImported) {
    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(editNoteAction)];
    [titleView addGestureRecognizer:tap];
    titleView.isAccessibilityElement = YES;
    titleView.accessibilityTraits = UIAccessibilityTraitButton;
    titleView.accessibilityLabel = [NSString stringWithFormat:@"%@ · %@", lbl.text, TR(@"Title_Edit_Script_Info")];
  }

  self.navigationTitleWidthConstraint = [titleView.widthAnchor constraintLessThanOrEqualToConstant:260];
  self.navigationTitleWidthConstraint.active = YES;
  self.navigationItem.titleView = titleView;
}

- (void)updateNavigationTitle:(NSString *)title {
  UILabel *lbl = objc_getAssociatedObject(self, "navTitleLabel");
  if (lbl) {
    lbl.text = title;
    if (!self.scriptModel.isImported) {
      self.navigationItem.titleView.accessibilityLabel = [NSString stringWithFormat:@"%@ · %@", title, TR(@"Title_Edit_Script_Info")];
    }
    
    [self.navigationItem.titleView sizeToFit];
  }
}

- (void)showToast:(NSString *)msg {
  UIAlertController *ac =
      [UIAlertController alertControllerWithTitle:nil
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:ac animated:YES completion:nil];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [ac dismissViewControllerAnimated:YES completion:nil];
      });
}

#pragma mark - Keyboard

- (void)keyboardWillShow:(NSNotification *)notification {
  NSDictionary *info = notification.userInfo;
  CGRect screenFrame = [info[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGRect frame = [self.view convertRect:screenFrame fromView:nil];
  CGRect intersection = CGRectIntersection(self.view.bounds, frame);
  BOOL docked = !CGRectIsNull(intersection) && CGRectGetMaxY(frame) >= CGRectGetMaxY(self.view.bounds) - 1;
  CGFloat overlap = docked ? MAX(0, CGRectGetHeight(intersection) - self.view.safeAreaInsets.bottom) : 0;
  self.contentBottomConstraint.constant = -16 - overlap;
  BOOL editing = overlap > 0;
  self.headerView.hidden = editing;
  self.consoleView.hidden = editing;
  self.commandStack.hidden = editing;
  NSTimeInterval duration = [info[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  UIViewAnimationOptions options = (UIViewAnimationOptions)([info[UIKeyboardAnimationCurveUserInfoKey] integerValue] << 16);
  [UIView animateWithDuration:duration delay:0 options:options animations:^{ [self.view layoutIfNeeded]; } completion:nil];
}

- (void)keyboardWillHide:(NSNotification *)notification {
  self.contentBottomConstraint.constant = -16;
  self.headerView.hidden = NO;
  self.consoleView.hidden = NO;
  self.commandStack.hidden = NO;
  [UIView animateWithDuration:[notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue]
      animations:^{ [self.view layoutIfNeeded]; }];
}

- (void)smartInsertCode:(NSString *)code {
  if (self.scriptModel.isImported) {
    [self showToast:TR(@"Status_ReadOnly")];
    return;
  }
  NSString *text = self.editorView.text ?: @"";
  NSRange selectedRange = self.editorView.selectedRange;
  NSUInteger cursorPos = selectedRange.location;
  
  NSMutableString *insertText = [NSMutableString string];
  
  BOOL needPrefixNewline = NO;
  if (cursorPos > 0 && cursorPos <= text.length) {
    unichar prevChar = [text characterAtIndex:cursorPos - 1];
    
    needPrefixNewline = (prevChar != '\n');
  }
  
  BOOL needSuffixNewline = NO;
  if (cursorPos < text.length) {
    unichar nextChar = [text characterAtIndex:cursorPos];
    
    needSuffixNewline = (nextChar != '\n');
  } else {
    
    needSuffixNewline = YES;
  }
  
  if (needPrefixNewline) {
    [insertText appendString:@"\n"];
  }
  [insertText appendString:code];
  if (needSuffixNewline) {
    [insertText appendString:@"\n"];
  }
  
  [self.editorView insertText:insertText];
  [self textViewDidChange:self.editorView];
}

@end
