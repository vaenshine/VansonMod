#import "VMStringEditorViewController.h"
#import "include/VMLocalization.h"
#define STRING_TEXT(key) [[VMLocalization shared] localizedString:key]

@interface VMStringEditorViewController () <UITextViewDelegate, UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) UITextView *textView;
@property(nonatomic, strong) UILabel *detailLabel;
@property(nonatomic, strong) UILabel *countLabel;
@property(nonatomic, strong) UITableView *contextTable;
@property(nonatomic, strong) UIStackView *headerStack;
@property(nonatomic, copy) NSArray<VMStringMemoryRecord *> *contextRecords;
@property(nonatomic, strong) NSLayoutConstraint *textBottomConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerTopConstraint;
@property(nonatomic, strong) NSLayoutConstraint *textTopConstraint;
@property(nonatomic, strong) NSLayoutConstraint *contextHeightConstraint;
@property(nonatomic, strong) UIBarButtonItem *saveButton;
@property(nonatomic, strong) UIBarButtonItem *undoButton;
@property(nonatomic) CGRect keyboardScreenFrame;
@property(nonatomic) BOOL finishing;
@property(nonatomic) BOOL hasShownContext;
@end

@implementation VMStringEditorViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = STRING_TEXT(@"Browser_Str_Edit");
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
      initWithTitle:STRING_TEXT(@"Btn_Cancel") style:UIBarButtonItemStylePlain
      target:self action:@selector(cancelEditing)];
  self.saveButton = [[UIBarButtonItem alloc]
      initWithTitle:STRING_TEXT(@"Btn_Save") style:UIBarButtonItemStyleDone
      target:self action:@selector(confirmEditing)];
  self.undoButton = [[UIBarButtonItem alloc]
      initWithTitle:STRING_TEXT(@"Str_Undo_Button")
      style:UIBarButtonItemStylePlain target:self action:@selector(undoEditing)];
  self.undoButton.accessibilityLabel = STRING_TEXT(@"Undo_Last_Modify");
  UIBarButtonItem *reload = [[UIBarButtonItem alloc]
      initWithTitle:STRING_TEXT(@"Str_Reload_Button")
      style:UIBarButtonItemStylePlain target:self action:@selector(reloadSelection)];
  reload.accessibilityLabel = STRING_TEXT(@"Str_Reload");
  self.navigationItem.rightBarButtonItems = @[self.saveButton, self.undoButton, reload];

  self.headerStack = [[UIStackView alloc] init];
  self.headerStack.axis = UILayoutConstraintAxisVertical;
  self.headerStack.spacing = 4;
  self.headerStack.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.headerStack];

  self.detailLabel = [[UILabel alloc] init];
  self.detailLabel.numberOfLines = 2;
  self.detailLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  self.detailLabel.textColor = UIColor.secondaryLabelColor;
  self.detailLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerStack addArrangedSubview:self.detailLabel];

  UIStackView *tools = [[UIStackView alloc] init];
  tools.axis = UILayoutConstraintAxisHorizontal;
  tools.distribution = UIStackViewDistributionFillEqually;
  tools.spacing = 8;
  tools.translatesAutoresizingMaskIntoConstraints = NO;
  NSArray *titles = @[STRING_TEXT(@"Str_Load_Before"), STRING_TEXT(@"Str_Select_Range"), STRING_TEXT(@"Str_Load_After")];
  NSArray *selectors = @[NSStringFromSelector(@selector(loadBefore)), NSStringFromSelector(@selector(selectRange)), NSStringFromSelector(@selector(loadAfter))];
  for (NSUInteger i = 0; i < titles.count; i++) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:titles[i] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:13];
    [button addTarget:self action:NSSelectorFromString(selectors[i]) forControlEvents:UIControlEventTouchUpInside];
    [tools addArrangedSubview:button];
  }
  [self.headerStack addArrangedSubview:tools];
  NSLayoutConstraint *toolsHeight = [tools.heightAnchor constraintEqualToConstant:36];
  toolsHeight.priority = UILayoutPriorityDefaultHigh;
  toolsHeight.active = YES;

  self.contextTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  self.contextTable.dataSource = self;
  self.contextTable.delegate = self;
  self.contextTable.rowHeight = 56;
  self.contextTable.estimatedRowHeight = 0;
  self.contextTable.tableFooterView = [UIView new];
  self.contextTable.accessibilityLabel = STRING_TEXT(@"Str_Context");
  self.contextTable.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerStack addArrangedSubview:self.contextTable];

  self.countLabel = [[UILabel alloc] init];
  self.countLabel.numberOfLines = 2;
  self.countLabel.font = [UIFont systemFontOfSize:12];
  self.countLabel.textColor = UIColor.secondaryLabelColor;
  self.countLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerStack addArrangedSubview:self.countLabel];

  self.textView = [[UITextView alloc] init];
  self.textView.delegate = self;
  self.textView.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
  self.textView.backgroundColor = UIColor.secondarySystemBackgroundColor;
  self.textView.textColor = UIColor.labelColor;
  self.textView.textContainerInset = UIEdgeInsetsMake(12, 8, 12, 8);
  self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
  self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
  self.textView.smartQuotesType = UITextSmartQuotesTypeNo;
  self.textView.smartDashesType = UITextSmartDashesTypeNo;
  self.textView.scrollEnabled = YES;
  self.textView.alwaysBounceVertical = YES;
  self.textView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  UIToolbar *keyboardToolbar = [[UIToolbar alloc]
      initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
  keyboardToolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
  UIBarButtonItem *hideKeyboard = [[UIBarButtonItem alloc]
      initWithTitle:STRING_TEXT(@"Btn_Hide_Keyboard") style:UIBarButtonItemStyleDone
      target:self action:@selector(hideKeyboard)];
  keyboardToolbar.items = @[flexibleSpace, hideKeyboard];
  self.textView.inputAccessoryView = keyboardToolbar;
  self.textView.accessibilityLabel = self.title;
  self.textView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:self.textView];

  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
  self.textBottomConstraint = [self.textView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12];
  self.headerTopConstraint = [self.headerStack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8];
  self.textTopConstraint = [self.textView.topAnchor constraintEqualToAnchor:self.headerStack.bottomAnchor constant:4];
  self.contextHeightConstraint = [self.contextTable.heightAnchor constraintEqualToConstant:168];
  self.contextHeightConstraint.priority = UILayoutPriorityDefaultHigh;
  [NSLayoutConstraint activateConstraints:@[
    self.headerTopConstraint,
    [self.headerStack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
    [self.headerStack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
    self.contextHeightConstraint,
    [self.contextTable.heightAnchor constraintGreaterThanOrEqualToConstant:0],
    self.textTopConstraint,
    [self.textView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:12],
    [self.textView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-12],
    [self.textView.heightAnchor constraintGreaterThanOrEqualToConstant:0],
    self.textBottomConstraint
  ]];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:)
      name:UIKeyboardWillChangeFrameNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:)
      name:UIKeyboardWillHideNotification object:nil];

  NSString *error = nil;
  if ([self.session openStringAtAddress:self.initialAddress error:&error]) {
    [self.session loadMoreBefore:YES error:NULL];
    [self.session loadMoreBefore:NO error:NULL];
  }
  [self updateSelection];
  if (error) dispatch_async(dispatch_get_main_queue(), ^{ [self showMessage:error]; });
}

- (void)updateSelection {
  self.textView.text = self.session.originalText ?: @"";
  self.textView.editable = self.session.originalBytes.length > 0;
  [self updateCount];
  [self reloadContext];
  [self scrollToSelection];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (!self.hasShownContext) {
    self.hasShownContext = YES;
    [self scrollToSelection];
  }
}

- (void)scrollToSelection {
  [self.contextTable layoutIfNeeded];
  if (self.contextTable.bounds.size.height <= 0) return;
  for (NSUInteger i = 0; i < self.contextRecords.count; i++) {
    VMStringMemoryRecord *record = self.contextRecords[i];
    if (self.session.address >= record.address &&
        self.session.address - record.address < record.bytes.length) {
      [self.contextTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]
          atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
      break;
    }
  }
}

- (void)updateCount {
  VMStringMemorySession *s = self.session;
  self.detailLabel.text = s.originalBytes.length ? [NSString stringWithFormat:@"0x%llX – 0x%llX\n%@",
      (unsigned long long)s.address, (unsigned long long)(s.address + s.originalBytes.length - 1),
      STRING_TEXT(s.rangeMode ? @"Str_Range_Mode" : @"Str_Single_Mode")] : STRING_TEXT(@"Str_Read_Failed");
  NSData *bytes = s.rangeMode ? [VMStringMemorySession dataForEscapedText:self.textView.text] :
      [self.textView.text dataUsingEncoding:NSUTF8StringEncoding];
  NSString *error = nil;
  BOOL valid = s.originalBytes.length && [s dataForDraft:self.textView.text error:&error] != nil;
  NSString *rule = STRING_TEXT(s.rangeMode ? @"Str_Escape_Help" :
      s.terminated ? @"Str_Shorter_Allowed" : @"Str_Equal_Length");
  self.countLabel.text = [NSString stringWithFormat:STRING_TEXT(@"Str_Count_Fmt"),
      (unsigned long)s.byteLimit, (unsigned long)bytes.length, rule];
  self.countLabel.textColor = valid ? UIColor.secondaryLabelColor : UIColor.systemRedColor;
  self.saveButton.enabled = valid;
  self.undoButton.enabled = s.canUndo;
}

- (void)textViewDidChange:(UITextView *)textView { [self updateCount]; }

- (void)reloadContext {
  self.contextRecords = self.session.records;
  [self.contextTable reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.contextRecords.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"StringContext"];
  if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"StringContext"];
  VMStringMemoryRecord *record = self.contextRecords[path.row];
  cell.textLabel.text = [record.text stringByReplacingOccurrencesOfString:@"\n" withString:@" ↵ "];
  cell.textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
  cell.detailTextLabel.text = [NSString stringWithFormat:@"0x%llX · %lu B%@",
      (unsigned long long)record.address, (unsigned long)(record.bytes.length - (record.terminated ? 1 : 0)),
      record.terminated ? @" · \\0" : @""];
  cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
  BOOL selected = self.session.address >= record.address &&
      self.session.address - record.address < record.bytes.length;
  cell.backgroundColor = selected ? [UIColor.systemOrangeColor colorWithAlphaComponent:0.12] : UIColor.systemBackgroundColor;
  cell.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
  VMStringMemoryRecord *record = self.contextRecords[path.row];
  [self resolveDraft:^{
    NSString *error = nil;
    if ([self.session openStringAtAddress:record.address error:&error]) [self updateSelection];
    else [self showMessage:error];
  }];
}

- (void)loadBefore { [self loadContextBefore:YES]; }
- (void)loadAfter { [self loadContextBefore:NO]; }

- (void)loadContextBefore:(BOOL)before {
  NSIndexPath *first = self.contextTable.indexPathsForVisibleRows.firstObject;
  VMStringMemoryRecord *anchor = first && first.row < self.contextRecords.count ? self.contextRecords[first.row] : nil;
  CGFloat offset = first ? self.contextTable.contentOffset.y - first.row * 56 : 0;
  NSString *error = nil;
  if (![self.session loadMoreBefore:before error:&error]) { [self showMessage:error]; return; }
  [self reloadContext];
  [self.contextTable layoutIfNeeded];
  if (anchor) {
    for (NSUInteger i = 0; i < self.contextRecords.count; i++) {
      VMStringMemoryRecord *record = self.contextRecords[i];
      if (anchor.address >= record.address && anchor.address - record.address < record.bytes.length) {
        CGFloat maxY = MAX(0, self.contextTable.contentSize.height - self.contextTable.bounds.size.height);
        self.contextTable.contentOffset = CGPointMake(0, MIN(maxY, MAX(0, i * 56 + offset)));
        break;
      }
    }
  }
}

- (void)presentEditorAlert:(UIAlertController *)alert {
  if (self.finishing) return;
  if (self.presentedViewController) {
    if (self.presentedViewController.isBeingDismissed) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 10), dispatch_get_main_queue(), ^{
        [self presentEditorAlert:alert];
      });
    }
    return;
  }
  [self.view endEditing:YES];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMessage:(NSString *)key {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:self.title
      message:STRING_TEXT(key ?: @"Str_Read_Failed") preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
  [self presentEditorAlert:alert];
}

- (void)resolveDraft:(void (^)(void))action {
  if (!self.session.originalBytes.length || [self.textView.text isEqualToString:self.session.originalText]) { action(); return; }
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:STRING_TEXT(@"Str_Unsaved")
      message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Str_Discard") style:UIAlertActionStyleDestructive
      handler:^(UIAlertAction *a) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), action);
      }]];
  [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Btn_Save") style:UIAlertActionStyleDefault
      handler:^(UIAlertAction *a) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), ^{
          [self saveWithCompletion:action];
        });
      }]];
  [self presentEditorAlert:alert];
}

- (void)selectRange {
  [self resolveDraft:^{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:STRING_TEXT(@"Str_Select_Range")
        message:STRING_TEXT(@"Str_Range_Help") preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
      field.placeholder = STRING_TEXT(@"Str_Start");
      field.text = [NSString stringWithFormat:@"0x%llX", (unsigned long long)self.session.address];
      field.keyboardType = UIKeyboardTypeASCIICapable;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
      field.placeholder = STRING_TEXT(@"Str_End");
      field.text = [NSString stringWithFormat:@"0x%llX",
          (unsigned long long)(self.session.address + MAX((NSUInteger)1, self.session.originalBytes.length) - 1)];
      field.keyboardType = UIKeyboardTypeASCIICapable;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Btn_OK") style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
          uint64_t start = 0, end = 0;
          NSString *error = nil;
          if (![VMStringMemorySession parseAddress:alert.textFields[0].text value:&start] ||
              ![VMStringMemorySession parseAddress:alert.textFields[1].text value:&end]) error = @"Str_Invalid_Range";
          else if ([self.session openRangeFrom:start through:end error:&error]) [self updateSelection];
          if (error) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), ^{ [self showMessage:error]; });
        }]];
    dispatch_async(dispatch_get_main_queue(), ^{ [self presentEditorAlert:alert]; });
  }];
}

- (void)reloadSelection {
  [self resolveDraft:^{
    NSString *error = nil;
    VMStringMemorySession *s = self.session;
    BOOL ok = s.rangeMode ? [s openRangeFrom:s.address through:s.address + s.originalBytes.length - 1 error:&error] :
        [s openStringAtAddress:s.address ?: self.initialAddress error:&error];
    if (ok) {
      [s resetContext];
      [s loadMoreBefore:YES error:NULL];
      [s loadMoreBefore:NO error:NULL];
      [self updateSelection];
    } else [self showMessage:error];
  }];
}

- (void)confirmEditing { [self saveWithCompletion:nil]; }

- (void)saveWithCompletion:(void (^)(void))completion {
  NSString *draft = [self.textView.text copy] ?: @"";
  NSString *error = nil;
  if (![self.session dataForDraft:draft error:&error]) { [self showMessage:error]; return; }
  void (^commit)(void) = ^{
    if (self.finishing) return;
    NSString *writeError = nil;
    if ([self.session commitDraft:draft error:&writeError]) {
      [self updateSelection];
      if (self.didChangeMemory) self.didChangeMemory();
      if (completion) completion();
      else [self showMessage:@"Str_Saved"];
    } else {
      [self updateCount];
      [self showMessage:writeError];
    }
  };
  if (!self.session.rangeMode) { commit(); return; }
  NSString *oldText = self.session.originalText;
  NSString *(^shorten)(NSString *) = ^NSString *(NSString *s) {
    return s.length > 96 ? [[s substringToIndex:96] stringByAppendingString:@"…"] : s;
  };
  NSString *preview = [NSString stringWithFormat:STRING_TEXT(@"Str_Range_Preview"),
      (unsigned long long)self.session.address,
      (unsigned long long)(self.session.address + self.session.originalBytes.length - 1),
      (unsigned long)self.session.byteLimit, shorten(oldText), shorten(draft)];
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:STRING_TEXT(@"Str_Select_Range")
      message:preview preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:STRING_TEXT(@"Btn_Save") style:UIAlertActionStyleDestructive
      handler:^(UIAlertAction *a) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 3), dispatch_get_main_queue(), commit);
      }]];
  [self presentEditorAlert:alert];
}

- (void)undoEditing {
  [self resolveDraft:^{
    NSString *error = nil;
    if ([self.session undo:&error]) {
      [self updateSelection];
      if (self.didChangeMemory) self.didChangeMemory();
    } else [self showMessage:error];
  }];
}

- (void)cancelEditing {
  [self resolveDraft:^{
    if (self.finishing) return;
    self.finishing = YES;
    [self.view endEditing:YES];
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
  }];
}

- (void)hideKeyboard { [self.textView resignFirstResponder]; }

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updateKeyboardInset];
}

- (void)updateKeyboardInset {
  if (!self.view.window) return;
  CGRect keyboard = [self.view convertRect:self.keyboardScreenFrame fromCoordinateSpace:self.view.window.screen.coordinateSpace];
  CGRect overlap = CGRectIntersection(self.view.bounds, keyboard);
  CGFloat inset = 0;
  if (!CGRectIsNull(overlap) && !CGRectIsEmpty(overlap) &&
      CGRectGetMaxY(overlap) >= CGRectGetMaxY(self.view.bounds) - 1 &&
      CGRectGetWidth(overlap) >= CGRectGetWidth(self.view.bounds) - 1) {
    inset = MAX(0, CGRectGetHeight(overlap) - self.view.safeAreaInsets.bottom);
  }
  CGFloat available = self.view.bounds.size.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom - inset;
  BOOL compact = available < 250;
  self.textBottomConstraint.constant = -(compact ? 2 : 12) - inset;
  self.headerTopConstraint.constant = compact ? 2 : 8;
  self.textTopConstraint.constant = compact ? 2 : 4;
  UIEdgeInsets textInsets = UIEdgeInsetsMake(compact ? 4 : 12, 8, compact ? 4 : 12, 8);
  if (!UIEdgeInsetsEqualToEdgeInsets(self.textView.textContainerInset, textInsets))
    self.textView.textContainerInset = textInsets;
  for (UIView *view in self.headerStack.arrangedSubviews) view.hidden = compact;
  self.contextHeightConstraint.constant = compact ? 0 : MIN(168, MAX(56, available - 180));
}

- (void)keyboardChanged:(NSNotification *)notification {
  self.keyboardScreenFrame = [notification.name isEqualToString:UIKeyboardWillHideNotification]
      ? CGRectZero : [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  [self updateKeyboardInset];
  NSTimeInterval duration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState |
      ([notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue] << 16);
  [UIView animateWithDuration:duration delay:0 options:options animations:^{
    [self.view layoutIfNeeded];
  } completion:nil];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
@end
