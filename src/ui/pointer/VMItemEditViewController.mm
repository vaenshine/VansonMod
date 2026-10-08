#import "VMItemEditViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/helpers/VMKeyboardAvoidance.h"
#import "../../utils/models/VMScriptModel.h"
#import "../main/VMScriptViewController.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerChain.h"
#import "include/VMRVAPatch.h"
#import "include/VMSignatureModel.h"
#include <cmath>

#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMItemEditViewController () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSMutableDictionary<NSString *, UITextField *> *fields;
@property(nonatomic, strong) NSArray<NSDictionary *> *rows;
@property(nonatomic, strong) UISegmentedControl *typeSegment;
@property(nonatomic, strong) UIScrollView *typePicker;
@property(nonatomic, strong) UISegmentedControl *modeSegment;
@property(nonatomic, assign) VMPointerUIMode draftMode;
@end

@implementation VMItemEditViewController

+ (void)presentInController:(UIViewController *)vc model:(id)model onSave:(void (^)(id))onSave {
  VMItemEditViewController *editor = [self new];
  editor.model = model;
  editor.onSave = onSave;
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
  nav.modalPresentationStyle = UIModalPresentationFormSheet;
  if (@available(iOS 15.0, *)) {
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    nav.sheetPresentationController.detents = @[UISheetPresentationControllerDetent.largeDetent];
    nav.sheetPresentationController.prefersGrabberVisible = YES;
  }
  [vc presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  NSString *titleKey = @"Title_Edit_Script_Info";
  if ([self.model isKindOfClass:VMPointerChain.class]) titleKey = @"Title_Edit_Ptr_Info";
  else if ([self.model isKindOfClass:VMRVAPatch.class]) titleKey = @"Title_Edit_RVA_Info";
  else if ([self.model isKindOfClass:VMSignatureModel.class]) titleKey = @"Title_Edit_Sig_Info";
  self.title = TR(titleKey);
  self.view.backgroundColor = [VMUIHelper canvasColor];
  self.view.tintColor = [VMUIHelper accentColor];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Cancel") style:UIBarButtonItemStylePlain target:self action:@selector(onCancel)];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Save") style:UIBarButtonItemStyleDone target:self action:@selector(onSaveBtn)];
  [VMUIHelper styleConfirmationItem:self.navigationItem.rightBarButtonItem];
  [self prepareDraft];
  [self rebuildRows];
  self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
  self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  [VMUIHelper styleTableView:self.tableView];
  self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  [self.view addSubview:self.tableView];
  [VMKeyboardAvoidance installForScrollView:self.tableView];
}

- (UITextField *)draftField:(NSString *)key value:(NSString *)value numeric:(BOOL)numeric editable:(BOOL)editable {
  UITextField *field = [UITextField new];
  field.text = value ?: @"";
  NSDictionary<NSString *, NSString *> *placeholderKeys = @{
    @"note": @"Placeholder_Note", @"author": @"Placeholder_Author",
    @"lockValue": @"Mod_Input_Value_Placeholder", @"uiMin": @"Slider_Min",
    @"uiMax": @"Slider_Max", @"switchOnValue": @"Mod_Input_Value_Placeholder",
    @"switchOffValue": @"Mod_Input_Value_Placeholder", @"resultTitle": @"Item_Title_Placeholder",
    @"offset": @"Offset_Input_Placeholder", @"patchHex": @"RVA_Patch_Hex_Placeholder",
    @"originalHex": @"RVA_Original_Hex_Placeholder"
  };
  if (placeholderKeys[key]) field.placeholder = TR(placeholderKeys[key]);
  if ([key isEqualToString:@"signature"]) field.placeholder = @"AA BB ?? CC";
  if (!numeric && [@[@"lockValue", @"switchOnValue", @"switchOffValue"] containsObject:key])
    field.placeholder = TR(@"Mod_Input_Str");
  field.enabled = editable;
  field.delegate = self;
  field.keyboardType = numeric ? UIKeyboardTypeNumbersAndPunctuation : UIKeyboardTypeDefault;
  field.autocorrectionType = UITextAutocorrectionTypeNo;
  field.autocapitalizationType = UITextAutocapitalizationTypeNone;
  field.returnKeyType = UIReturnKeyDone;
  [VMUIHelper styleTextField:field];
  if (numeric) field.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightRegular]];
  if (!editable) field.textColor = [UIColor secondaryLabelColor];
  self.fields[key] = field;
  return field;
}

- (void)prepareDraft {
  self.fields = [NSMutableDictionary dictionary];
  BOOL imported = [[self.model valueForKey:@"isImported"] boolValue];
  [self draftField:@"note" value:[self.model valueForKey:@"note"] numeric:NO editable:YES];
  [self draftField:@"author" value:[self.model valueForKey:@"author"] numeric:NO editable:!imported];
  if ([self.model isKindOfClass:VMPointerChain.class] || [self.model isKindOfClass:VMSignatureModel.class]) {
    self.typeSegment = [[VMScrollableSegmentedControl alloc] initWithItems:@[TR(@"Type_I8"), TR(@"Type_I16"), TR(@"Type_I32"), TR(@"Type_I64"), @"U8", @"U16", @"U32", @"U64", TR(@"Type_F32"), TR(@"Type_F64"), @"Str"]];
    NSInteger type = [[self.model valueForKey:@"lockType"] integerValue];
    self.typeSegment.selectedSegmentIndex = type >= 0 && type <= VMDataTypeString ? type : UISegmentedControlNoSegment;
    self.typeSegment.accessibilityLabel = TR(@"Value_Type");
    [self.typeSegment addTarget:self action:@selector(onTypeChange:) forControlEvents:UIControlEventValueChanged];
    self.typeSegment.translatesAutoresizingMaskIntoConstraints = NO;
    self.typePicker = [VMControlStripScrollView new];
    self.typePicker.showsHorizontalScrollIndicator = NO;
    [self.typePicker addSubview:self.typeSegment];
    [NSLayoutConstraint activateConstraints:@[
      [self.typeSegment.leadingAnchor constraintEqualToAnchor:self.typePicker.contentLayoutGuide.leadingAnchor],
      [self.typeSegment.trailingAnchor constraintEqualToAnchor:self.typePicker.contentLayoutGuide.trailingAnchor],
      [self.typeSegment.topAnchor constraintEqualToAnchor:self.typePicker.contentLayoutGuide.topAnchor],
      [self.typeSegment.bottomAnchor constraintEqualToAnchor:self.typePicker.contentLayoutGuide.bottomAnchor],
      [self.typeSegment.heightAnchor constraintEqualToAnchor:self.typePicker.frameLayoutGuide.heightAnchor],
      [self.typeSegment.widthAnchor constraintGreaterThanOrEqualToConstant:572],
      [self.typeSegment.widthAnchor constraintGreaterThanOrEqualToAnchor:self.typePicker.frameLayoutGuide.widthAnchor]
    ]];
  }
  if ([self.model isKindOfClass:VMPointerChain.class]) {
    VMPointerChain *chain = self.model;
    self.draftMode = chain.uiMode;
    [self draftField:@"lockValue" value:chain.lockValue numeric:chain.lockType != VMDataTypeString editable:YES];
    [self draftField:@"uiMin" value:[NSString stringWithFormat:@"%g", chain.uiMin] numeric:YES editable:YES];
    [self draftField:@"uiMax" value:[NSString stringWithFormat:@"%g", chain.uiMax] numeric:YES editable:YES];
    [self draftField:@"switchOnValue" value:chain.switchOnValue ?: @"1" numeric:chain.lockType != VMDataTypeString editable:YES];
    [self draftField:@"switchOffValue" value:chain.switchOffValue ?: @"0" numeric:chain.lockType != VMDataTypeString editable:YES];
    [self draftField:@"resultTitle" value:chain.resultTitle numeric:NO editable:YES];
    if (chain.isSignatureMode) {
      [self draftField:@"signature" value:chain.signature numeric:NO editable:!imported];
      [self draftField:@"offset" value:[NSString stringWithFormat:@"0x%llX", chain.offsets.firstObject.unsignedLongLongValue] numeric:YES editable:!imported];
    }
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[TR(@"Mode_Switch_Card"), TR(@"Mode_Switch_Slider"), TR(@"Mode_Switch_Toggle")]];
    self.modeSegment.selectedSegmentIndex = self.draftMode == VMPointerUIModeSlider ? 1 : self.draftMode == VMPointerUIModeSwitch ? 2 : 0;
    self.modeSegment.accessibilityLabel = TR(@"Display_Mode");
    [self.modeSegment addTarget:self action:@selector(onModeChange:) forControlEvents:UIControlEventValueChanged];
  } else if ([self.model isKindOfClass:VMRVAPatch.class]) {
    VMRVAPatch *patch = self.model;
    [self draftField:@"patchHex" value:patch.patchHex numeric:YES editable:!imported];
    [self draftField:@"originalHex" value:patch.originalHex numeric:YES editable:!imported];
  } else if ([self.model isKindOfClass:VMSignatureModel.class]) {
    VMSignatureModel *sig = self.model;
    [self draftField:@"signature" value:sig.signature numeric:NO editable:!imported];
    [self draftField:@"offset" value:[NSString stringWithFormat:@"0x%X", sig.offset] numeric:YES editable:!imported];
  }
}

- (NSDictionary *)row:(NSString *)title field:(NSString *)key {
  self.fields[key].accessibilityLabel = title;
  return @{@"title": title, @"control": self.fields[key]};
}

- (void)rebuildRows {
  BOOL imported = [[self.model valueForKey:@"isImported"] boolValue];
  NSMutableArray *rows = [NSMutableArray arrayWithObject:[self row:TR(@"Lab_Note_Colon") field:@"note"]];
  if (self.typeSegment) [rows addObject:@{@"title": TR(@"Value_Type"), @"control": self.typePicker}];
  if ([self.model isKindOfClass:VMPointerChain.class]) {
    VMPointerChain *chain = self.model;
    if (chain.isSignatureMode) {
      [rows addObject:[self row:TR(@"Sig_Label_Sig") field:@"signature"]];
      [rows addObject:[self row:TR(@"Sig_Label_Offset") field:@"offset"]];
    } else {
      [rows addObject:@{@"title": TR(@"Ptr_Label_Chain"), @"text": [chain displayString] ?: @"", @"action": @"copy"}];
    }
    [rows addObject:[self row:TR(@"Lock_Label_Value") field:@"lockValue"]];
    [rows addObject:@{@"title": TR(@"Display_Mode"), @"control": self.modeSegment}];
    if (self.draftMode == VMPointerUIModeSlider) {
      [rows addObject:[self row:TR(@"Slider_Min") field:@"uiMin"]];
      [rows addObject:[self row:TR(@"Slider_Max") field:@"uiMax"]];
    } else if (self.draftMode == VMPointerUIModeSwitch) {
      [rows addObject:[self row:TR(@"Toggle_On_Value") field:@"switchOnValue"]];
      [rows addObject:[self row:TR(@"Toggle_Off_Value") field:@"switchOffValue"]];
      [rows addObject:[self row:TR(@"Item_Title") field:@"resultTitle"]];
    }
  } else if ([self.model isKindOfClass:VMRVAPatch.class]) {
    [rows addObject:@{@"title": TR(@"RVA_Label_Loc"), @"text": [self.model displayString] ?: @"", @"action": @"copy"}];
    [rows addObject:[self row:TR(@"Toggle_On_Value") field:@"patchHex"]];
    [rows addObject:[self row:TR(@"Toggle_Off_Value") field:@"originalHex"]];
  } else if ([self.model isKindOfClass:VMSignatureModel.class]) {
    [rows addObject:[self row:TR(@"Sig_Label_Sig") field:@"signature"]];
    [rows addObject:[self row:TR(@"Sig_Label_Offset") field:@"offset"]];
  } else if ([self.model isKindOfClass:VMScriptModel.class]) {
    [rows addObject:@{@"title": TR(@"Lab_BundleId"), @"text": [self.model bundleID] ?: @"—", @"action": @"copy"}];
  }
  if (!imported) [rows addObject:[self row:TR(@"Label_Author") field:@"author"]];
  if ([self.model isKindOfClass:VMScriptModel.class] && !imported) {
    [rows addObject:@{@"title": TR(@"Script_Btn_EditCode"), @"action": @"script"}];
  }
  self.rows = rows;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (self.typeSegment.selectedSegmentIndex >= 0) {
    CGFloat width = self.typeSegment.bounds.size.width / self.typeSegment.numberOfSegments;
    [self.typePicker scrollRectToVisible:CGRectMake(width * self.typeSegment.selectedSegmentIndex, 0, width, 44) animated:NO];
  }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.rows.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSDictionary *row = self.rows[indexPath.row];
  UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
  cell.selectionStyle = row[@"action"] ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
  cell.backgroundColor = [VMUIHelper cardColor];
  UIStackView *stack = [UIStackView new];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 8;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  UILabel *title = [UILabel new];
  title.text = row[@"title"];
  title.font = [VMUIHelper scaledFontOfSize:14 weight:UIFontWeightSemibold];
  title.adjustsFontForContentSizeCategory = YES;
  title.numberOfLines = 0;
  title.textColor = [UIColor secondaryLabelColor];
  [stack addArrangedSubview:title];
  UIView *control = row[@"control"];
  if (control) {
    [control removeFromSuperview];
    [stack addArrangedSubview:control];
    BOOL hasMinimumHeight = NO;
    for (NSLayoutConstraint *constraint in control.constraints) {
      if (constraint.firstAttribute == NSLayoutAttributeHeight && constraint.constant >= 44) hasMinimumHeight = YES;
    }
    if (!hasMinimumHeight) [control.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  } else if (row[@"text"]) {
    UILabel *value = [UILabel new];
    value.text = row[@"text"];
    value.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular]];
    value.adjustsFontForContentSizeCategory = YES;
    value.numberOfLines = 0;
    value.lineBreakMode = NSLineBreakByCharWrapping;
    [stack addArrangedSubview:value];
    cell.accessibilityHint = TR(@"Btn_Copy");
  }
  if ([row[@"action"] isEqual:@"script"]) {
    title.textColor = [VMUIHelper accentColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  }
  [cell.contentView addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:14],
    [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-14],
    [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
    [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16]
  ]];
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NSDictionary *row = self.rows[indexPath.row];
  if ([row[@"action"] isEqual:@"copy"]) {
    UIPasteboard.generalPasteboard.string = row[@"text"];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, TR(@"Msg_Copied"));
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
  } else if ([row[@"action"] isEqual:@"script"]) {
    VMScriptViewController *editor = [VMScriptViewController new];
    editor.scriptModel = self.model;
    [self.navigationController pushViewController:editor animated:YES];
  } else if ([row[@"control"] isKindOfClass:UITextField.class]) {
    UITextField *field = row[@"control"];
    if (field.enabled) [field becomeFirstResponder];
    else UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, TR(@"Edit_ReadOnly_Hint"));
  }
}

- (void)onModeChange:(UISegmentedControl *)sender {
  self.draftMode = sender.selectedSegmentIndex == 1 ? VMPointerUIModeSlider : sender.selectedSegmentIndex == 2 ? VMPointerUIModeSwitch : VMPointerUIModeInput;
  [self.view endEditing:YES];
  [self rebuildRows];
  [self.tableView reloadData];
}

- (void)onTypeChange:(UISegmentedControl *)sender {
  UIKeyboardType keyboard = sender.selectedSegmentIndex == VMDataTypeString ? UIKeyboardTypeDefault : UIKeyboardTypeNumbersAndPunctuation;
  for (NSString *key in @[@"lockValue", @"switchOnValue", @"switchOffValue"]) {
    UITextField *field = self.fields[key];
    field.keyboardType = keyboard;
    field.placeholder = TR(self.typeSegment.selectedSegmentIndex == VMDataTypeString ? @"Mod_Input_Str" : @"Mod_Input_Value_Placeholder");
    if (field.isFirstResponder) [field reloadInputViews];
  }
}

- (void)showError:(NSString *)message {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Warn") message:message preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)readHexOffset:(unsigned long long *)value {
  NSString *text = [self.fields[@"offset"].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if ([text.lowercaseString hasPrefix:@"0x"]) text = [text substringFromIndex:2];
  NSScanner *scanner = [NSScanner scannerWithString:text ?: @""];
  scanner.charactersToBeSkipped = nil;
  return text.length > 0 && [scanner scanHexLongLong:value] && scanner.isAtEnd;
}

- (void)onSaveBtn {
  [self.view endEditing:YES];
  BOOL imported = [[self.model valueForKey:@"isImported"] boolValue];
  unsigned long long offset = 0;
  if (!imported && self.fields[@"offset"] && ![self readHexOffset:&offset]) {
    [self showError:TR(@"Patch_Hex_Err")]; return;
  }
  if ([self.model isKindOfClass:VMPointerChain.class] && self.draftMode == VMPointerUIModeSlider) {
    double minimum = 0, maximum = 0;
    NSScanner *minScanner = [NSScanner scannerWithString:self.fields[@"uiMin"].text];
    NSScanner *maxScanner = [NSScanner scannerWithString:self.fields[@"uiMax"].text];
    if (![minScanner scanDouble:&minimum] || !minScanner.isAtEnd || ![maxScanner scanDouble:&maximum] || !maxScanner.isAtEnd || !std::isfinite(minimum) || !std::isfinite(maximum) || minimum >= maximum) {
      [self showError:TR(@"Slider_Err_Min_Less_Max")]; return;
    }
  }
  [self.model setValue:self.fields[@"note"].text forKey:@"note"];
  if (!imported) [self.model setValue:self.fields[@"author"].text forKey:@"author"];
  if (self.typeSegment.selectedSegmentIndex != UISegmentedControlNoSegment && self.typeSegment) {
    [self.model setValue:@(self.typeSegment.selectedSegmentIndex) forKey:@"lockType"];
  }
  if ([self.model isKindOfClass:VMPointerChain.class]) {
    VMPointerChain *chain = self.model;
    chain.lockValue = self.fields[@"lockValue"].text;
    chain.uiMode = self.draftMode;
    chain.type = self.draftMode == VMPointerUIModeSlider ? @"slider" : self.draftMode == VMPointerUIModeSwitch ? @"switch" : @"card";
    if (self.draftMode == VMPointerUIModeSlider) {
      chain.uiMin = self.fields[@"uiMin"].text.floatValue;
      chain.uiMax = self.fields[@"uiMax"].text.floatValue;
    } else if (self.draftMode == VMPointerUIModeSwitch) {
      chain.switchOnValue = self.fields[@"switchOnValue"].text;
      chain.switchOffValue = self.fields[@"switchOffValue"].text;
      chain.resultTitle = self.fields[@"resultTitle"].text;
    }
    if (!imported && chain.isSignatureMode) {
      chain.signature = self.fields[@"signature"].text;
      chain.offsets = @[@(offset)];
    }
  } else if ([self.model isKindOfClass:VMRVAPatch.class] && !imported) {
    VMRVAPatch *patch = self.model;
    patch.patchHex = self.fields[@"patchHex"].text;
    patch.originalHex = self.fields[@"originalHex"].text;
  } else if ([self.model isKindOfClass:VMSignatureModel.class] && !imported) {
    VMSignatureModel *sig = self.model;
    sig.signature = self.fields[@"signature"].text;
    sig.offset = (int)offset;
  }
  if (self.onSave) self.onSave(self.model);
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }
- (void)onCancel { [self dismissViewControllerAnimated:YES completion:nil]; }
@end
