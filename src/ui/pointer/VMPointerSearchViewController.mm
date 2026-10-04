#import "../pointer/VMPointerSearchViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/helpers/VMKeyboardAvoidance.h"
#import "../main/VMLockListViewController.h"
#import "../memory/VMModuleListViewController.h"
#import "../pointer/VMPointerSessionListViewController.h"
#import "../pointer/VMPointerVerifierViewController.h"
#import "VMSavedPointersViewController.h"
#import "include/VMDataSession.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerChain.h"
#import "include/VMPointerManager.h"
#import <UIKit/UIKit.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMPointerSearchViewController () <
    UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) UIStackView *configStack;
@property(nonatomic, strong) UITableView *tableView;

@property(nonatomic, strong) UITextField *targetField; 
@property(nonatomic, strong) UITextField *moduleField; 

@property(nonatomic, strong) UITextField *depthField;  
@property(nonatomic, strong) UITextField *offsetField; 
@property(nonatomic, strong) UITextField *limitField;  

@property(nonatomic, strong) UIButton *startBtn;
@property(nonatomic, strong) UIActivityIndicatorView *loadingSpinner;

@property(nonatomic, assign) BOOL isScanning;
@property(nonatomic, strong) NSDate *searchStartTime;
@property(nonatomic, strong) VMModuleInfo *selectedModule;
@property(nonatomic, strong) UIView *loadingOverlay;
@property(nonatomic, strong) UILabel *loadingLabel;
@property(nonatomic, strong) UILabel *statsLabel;
@property(nonatomic, strong) UIView *statsContainer;

@end

@implementation VMPointerSearchViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  if (self.level <= 1) {
    self.title = TR(@"Tab_Ptr_Analysis");
  } else {
    self.title = [NSString
        stringWithFormat:@"%@ Lv.%ld", TR(@"Act_Search_Ptr"), (long)self.level];
  }

  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  self.navigationItem.leftBarButtonItem = nil;

  UIBarButtonItem *saveBtn = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"square.and.arrow.down"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(directSaveStaticPointers)];
  saveBtn.accessibilityLabel = TR(@"Btn_Save");
  self.navigationItem.rightBarButtonItem = saveBtn;

  [self setupUI];

  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];

}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [[VMMemoryEngine shared] switchContext:@"ptr"];
  [self updateStatsLabel];
  [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  if (self.isMovingFromParentViewController) {
    [[VMMemoryEngine shared] restorePreviousSession];
  }
}

#pragma mark - UI Setup (重构版)

- (void)setupUI {
  self.view.tintColor = [VMUIHelper accentColor];
  self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
  self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  [VMUIHelper styleTableView:self.tableView];
  [self.view addSubview:self.tableView];
  [VMKeyboardAvoidance installForScrollView:self.tableView];

  UIView *wrapper = [UIView new];
  UIStackView *layout = [UIStackView new];
  layout.axis = UILayoutConstraintAxisVertical;
  layout.spacing = 16;
  layout.translatesAutoresizingMaskIntoConstraints = NO;
  [wrapper addSubview:layout];
  self.headerView = [UIView new];
  [VMUIHelper styleCard:self.headerView];
  UIStackView *form = [UIStackView new];
  form.axis = UILayoutConstraintAxisVertical;
  form.spacing = 12;
  form.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerView addSubview:form];
  [form addArrangedSubview:[self createSectionTitle:TR(@"RVA_Section_Target")]];
  self.targetField = [self createTextField:TR(@"Ptr_Target_Label") placeholder:TR(@"Placeholder_Hex_Short")];
  self.targetField.text = self.targetAddress > 0 ? [NSString stringWithFormat:@"%llX", self.targetAddress] : @"";
  self.targetField.delegate = self;
  [form addArrangedSubview:self.targetField];
  [form addArrangedSubview:[self createSectionTitle:TR(@"Patch_Base")]];
  self.moduleField = [self createTextField:TR(@"Patch_Base") placeholder:TR(@"Placeholder_Auto_Search")];
  self.moduleField.text = TR(@"Placeholder_Auto_Search");
  self.moduleField.delegate = self;
  [self addSelectButtonToField:self.moduleField];
  [form addArrangedSubview:self.moduleField];
  [form addArrangedSubview:[self createSectionTitle:TR(@"Ptr_Auto_Config_Title")]];
  self.depthField = [self createConfigField:TR(@"Placeholder_Depth") val:@"7" pad:UIKeyboardTypeNumberPad];
  self.offsetField = [self createConfigField:TR(@"Placeholder_Max_Offset") val:@"2000" pad:UIKeyboardTypeASCIICapable];
  self.limitField = [self createConfigField:TR(@"Placeholder_Limit") val:@"500000" pad:UIKeyboardTypeNumberPad];
  for (UITextField *field in @[self.depthField, self.offsetField, self.limitField]) field.delegate = self;
  self.configStack = [UIStackView new];
  self.configStack.axis = UILayoutConstraintAxisHorizontal;
  self.configStack.distribution = UIStackViewDistributionFillEqually;
  self.configStack.spacing = 12;
  [self.configStack addArrangedSubview:[self wrapConfigField:self.depthField title:TR(@"Placeholder_Depth")]];
  [self.configStack addArrangedSubview:[self wrapConfigField:self.offsetField title:TR(@"Placeholder_Max_Offset")]];
  [self.configStack addArrangedSubview:[self wrapConfigField:self.limitField title:TR(@"Placeholder_Limit")]];
  [form addArrangedSubview:self.configStack];
  self.startBtn = [VMUIHelper createButtonWithTitle:TR(@"Ptr_Btn_Auto_Search") color:[VMUIHelper accentColor] target:self action:@selector(handleStartAction)];
  [VMUIHelper styleButton:self.startBtn primary:YES];
  [self.startBtn.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [form addArrangedSubview:self.startBtn];
  [layout addArrangedSubview:self.headerView];

  self.statsContainer = [UIView new];
  [VMUIHelper styleCard:self.statsContainer];
  self.statsContainer.backgroundColor = [[VMUIHelper accentColor] colorWithAlphaComponent:0.08];
  self.statsLabel = [UILabel new];
  self.statsLabel.font = [VMUIHelper scaledFontOfSize:14 weight:UIFontWeightSemibold];
  self.statsLabel.adjustsFontForContentSizeCategory = YES;
  self.statsLabel.numberOfLines = 0;
  self.statsLabel.textColor = [VMUIHelper accentColor];
  self.statsLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self.statsContainer addSubview:self.statsLabel];
  [layout addArrangedSubview:self.statsContainer];
  [NSLayoutConstraint activateConstraints:@[
    [layout.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:16],
    [layout.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-16],
    [layout.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:16],
    [layout.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-16],
    [form.leadingAnchor constraintEqualToAnchor:self.headerView.leadingAnchor constant:16],
    [form.trailingAnchor constraintEqualToAnchor:self.headerView.trailingAnchor constant:-16],
    [form.topAnchor constraintEqualToAnchor:self.headerView.topAnchor constant:16],
    [form.bottomAnchor constraintEqualToAnchor:self.headerView.bottomAnchor constant:-16],
    [self.statsLabel.leadingAnchor constraintEqualToAnchor:self.statsContainer.leadingAnchor constant:16],
    [self.statsLabel.trailingAnchor constraintEqualToAnchor:self.statsContainer.trailingAnchor constant:-16],
    [self.statsLabel.topAnchor constraintEqualToAnchor:self.statsContainer.topAnchor constant:12],
    [self.statsLabel.bottomAnchor constraintEqualToAnchor:self.statsContainer.bottomAnchor constant:-12]
  ]];
  self.tableView.tableHeaderView = wrapper;
  [self updateStatsLabel];
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (void)updateStatsLabel {
  NSUInteger count = [VMMemoryEngine shared].resultCount;
  self.statsLabel.text =
      [NSString stringWithFormat:@"%@: %lu", TR(@"Mod_Results_Count"),
                                 (unsigned long)count];
}

- (void)updateStatsLabelWithLevel:(NSInteger)level count:(NSUInteger)count {
  self.statsLabel.text = [NSString
      stringWithFormat:@"Lv.%ld | %@: %lu", (long)level,
                       TR(@"Mod_Results_Count"), (unsigned long)count];
}

- (UILabel *)createSectionTitle:(NSString *)text {
  UILabel *label = [UILabel new];
  label.text = text;
  label.numberOfLines = 0;
  label.font = [VMUIHelper scaledFontOfSize:14 weight:UIFontWeightSemibold];
  label.adjustsFontForContentSizeCategory = YES;
  label.textColor = [UIColor secondaryLabelColor];
  return label;
}

- (UITextField *)createTextField:(NSString *)label placeholder:(NSString *)placeholder {
  UITextField *field = [UITextField new];
  field.placeholder = placeholder;
  field.accessibilityLabel = label;
  field.keyboardType = UIKeyboardTypeASCIICapable;
  field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
  field.autocorrectionType = UITextAutocorrectionTypeNo;
  [VMUIHelper styleTextField:field];
  [field.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  field.font = [UIFont monospacedSystemFontOfSize:15 weight:UIFontWeightMedium];
  [self addDoneButtonTo:field];
  return field;
}

- (UITextField *)createConfigField:(NSString *)placeholder val:(NSString *)value pad:(UIKeyboardType)keyboard {
  UITextField *field = [self createTextField:placeholder placeholder:placeholder];
  field.text = value;
  field.keyboardType = keyboard;
  field.textAlignment = NSTextAlignmentCenter;
  return field;
}

- (UIView *)wrapConfigField:(UITextField *)field title:(NSString *)title {
  UIStackView *stack = [UIStackView new];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 6;
  [stack addArrangedSubview:[self createSectionTitle:title]];
  [stack addArrangedSubview:field];
  return stack;
}

- (void)updateTableHeaderHeight:(UIView *)header {
  if (self.tableView.tableHeaderView != header) self.tableView.tableHeaderView = header;
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  BOOL expanded = self.tableView.bounds.size.width < 375 || UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
  UILayoutConstraintAxis axis = expanded ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  if (self.configStack.axis != axis) self.configStack.axis = axis;
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

#pragma mark - Actions

- (void)handleStartAction {
  [self.view endEditing:YES];

  NSString *addrTxt = [self.targetField.text
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  self.targetAddress = strtoull([addrTxt UTF8String], NULL, 16);
  if (self.targetAddress == 0) {
    [self showToast:TR(@"Ptr_Error_Invalid_Target")];
    return;
  }

  int depth = [self.depthField.text intValue];
  if (depth <= 0)
    depth = 7; 

  NSString *offStr =
      [self.offsetField.text stringByReplacingOccurrencesOfString:@"0x"
                                                       withString:@""];
  uint32_t offset = (uint32_t)strtoull([offStr UTF8String], NULL, 16);
  if (offset == 0)
    offset = 0x2000;

  int limit = [self.limitField.text intValue];
  if (limit <= 0)
    limit = 0; 

  self.searchStartTime = [NSDate date];

  [self executeAutoSearch:depth offset:offset limit:limit];
}

- (void)executeAutoSearch:(int)depth offset:(uint32_t)offset limit:(int)limit {
  self.isScanning = YES;
  self.startBtn.enabled = NO;
  self.startBtn.alpha = 0.5;

  [self showLoadingOverlayWithText:TR(@"Ptr_Preparing")];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    [[VMMemoryEngine shared] takeGlobalSnapshotObjC];

    dispatch_async(dispatch_get_main_queue(), ^{
      [self updateLoadingText:
                [NSString
                    stringWithFormat:TR(@"Ptr_Auto_Initializing_Fmt"), depth]];

      uint64_t heapStart = 0x100000000;
      uint64_t heapEnd = 0x800000000;  
      uint64_t baseStart = 0;
      uint64_t baseEnd = 0;

      if (self.selectedModule) {
        baseStart = self.selectedModule.loadAddress;
        baseEnd = baseStart + self.selectedModule.size;
      } else {
        baseStart = heapStart;
        baseEnd = heapEnd;
      }

      [[VMMemoryEngine shared] autoSearchPointerChainObjCEx:self.targetAddress
          heapStart:heapStart
          heapEnd:heapEnd
          baseStart:baseStart
          baseEnd:baseEnd
          maxLevels:depth
          maxPerLevel:(limit > 0 ? limit : 500000)
          maxOffset:offset
          selectedModule:self.selectedModule
          progressBlock:^(NSInteger level, NSUInteger count) {
            dispatch_async(dispatch_get_main_queue(), ^{
              [self updateStatsLabelWithLevel:level count:count];
              NSString *text =
                  [NSString stringWithFormat:TR(@"Ptr_Auto_Search_Msg_Fmt"),
                                             (long)level, (unsigned long)count];
              [self updateLoadingText:text];
            });
          }
          completion:^(NSArray<VMPointerChain *> *chains) {
            
            [[VMMemoryEngine shared] clearSnapshot];

            dispatch_async(dispatch_get_main_queue(), ^{
              [self hideLoadingOverlay];
              self.isScanning = NO;
              self.startBtn.enabled = YES;
              self.startBtn.alpha = 1.0;

              if (chains.count > 0) {
                
                NSUInteger staticCount = 0;
                NSUInteger dynamicCount = 0;
                for (VMPointerChain *c in chains) {
                  if (c.chainType == VMPointerChainTypeDynamic) {
                    dynamicCount++;
                  } else {
                    staticCount++;
                  }
                }

                [self showSaveDialogForChains:chains
                                  staticCount:staticCount
                                 dynamicCount:dynamicCount];
              } else {
                [self showAutoSearchResults:@[] savedCount:0 filePath:nil];
              }
            });
          }];
    });
  });
}

- (void)showSaveDialogForChains:(NSArray<VMPointerChain *> *)chains
                    staticCount:(NSUInteger)staticCount
                   dynamicCount:(NSUInteger)dynamicCount {
  
  NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
  [fmt setDateFormat:@"yyMMdd_HHmmss"];
  NSString *countStr =
      [NSString stringWithFormat:@"(%lu Pts)", (unsigned long)chains.count];
  NSString *defaultName =
      [NSString stringWithFormat:@"Verify_%@_%@",
                                 [fmt stringFromDate:[NSDate date]], countStr];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Verifier_Btn_Save")
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = defaultName;
    tf.placeholder = TR(@"Verifier_File_Name");
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
  }];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [alert
      addAction:[UIAlertAction
                    actionWithTitle:TR(@"Btn_Confirm")
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                              NSString *inputName =
                                  alert.textFields.firstObject.text;
                              
                              if (inputName.length == 0)
                                inputName = defaultName;

                              NSString *bid =

                                  [[VMMemoryEngine shared] currentBundleID]
                                      ?: TR(@"App_Unknown");
                              NSString *safeBid = [bid
                                  stringByReplacingOccurrencesOfString:@"/"
                                                            withString:@"_"];

                              NSString *appFolder =
                                  [[[VMPointerManager shared] verifierFolder]
                                      stringByAppendingPathComponent:safeBid];
                              NSFileManager *fm =
                                  [NSFileManager defaultManager];
                              if (![fm fileExistsAtPath:appFolder]) {
                                [fm createDirectoryAtPath:appFolder
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:nil];
                              }

                              NSString *fullPath = [[VMPointerManager shared]
                                  generateUniquePathInFolder:appFolder
                                                    baseName:inputName
                                                   extension:@"vmvapt"];

                              VMDataSession *session =
                                  [VMDataSession sessionWithData:chains
                                                        bundleID:bid
                                                        dataType:@"pointer"];
                              
                              NSData *data = (chains.count > 1000)
                                  ? [session toVerifierBinaryData]
                                  : [session toVerifierJSONData];

                              if ([data writeToFile:fullPath atomically:YES]) {
                                
                                [self showAutoSearchResults:chains
                                                 savedCount:chains.count
                                                   filePath:fullPath];
                              } else {
                                [self showToast:TR(@"Err_File_Write")];
                              }
                            }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAutoSearchResults:(NSArray *)paths
                   savedCount:(NSUInteger)savedCount
                     filePath:(NSString *)path {
  
  NSTimeInterval duration =
      [[NSDate date] timeIntervalSinceDate:self.searchStartTime];
  NSString *title = [NSString stringWithFormat:TR(@"Ptr_Auto_Result_Title"),
                                               (unsigned long)paths.count];
  NSString *msg =
      [NSString stringWithFormat:@"%@: %.2fs", TR(@"Lab_Time"), duration];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  if (path && path.length > 0) {
    [alert
        addAction:[UIAlertAction
                      actionWithTitle:TR(@"Btn_Go_Verify")
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *action) {
                                UITabBarController *tabBar = self.tabBarController;
                                for (UIViewController *controller in tabBar.viewControllers) {
                                  if (![controller isKindOfClass:UINavigationController.class]) continue;
                                  UINavigationController *nav = (UINavigationController *)controller;
                                  VMLockListViewController *root = (id)nav.viewControllers.firstObject;
                                  if (![root isKindOfClass:VMLockListViewController.class]) continue;
                                  root.defaultTabIndex = 5;
                                  root.autoOpenVerifierPath = path;
                                  [nav popToRootViewControllerAnimated:NO];
                                  tabBar.selectedViewController = nav;
                                  if ([root respondsToSelector:@selector(tabChanged)]) [root performSelector:@selector(tabChanged)];
                                  break;
                                }
                              }]];
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showPathDetails:(NSDictionary *)info {
  NSArray *path = info[@"path"];
  NSString *base = info[@"base"];
  NSMutableString *str =
      [NSMutableString stringWithFormat:TR(@"Ptr_Detail_Base_Fmt"), base];

  for (int i = 0; i < path.count; i++) {
    [str appendFormat:@"Lv.%d: 0x%llX\n", i, [path[i] unsignedLongLongValue]];
  }

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Title_Chain_Detail")
                                          message:str
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Copy")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action) {
                                            [[UIPasteboard generalPasteboard]
                                                setString:str];
                                          }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - TableView Delegate
- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return [VMMemoryEngine shared].resultCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cid = @"cell";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:cid];
  }

  VMScanResultItem *item =
      [[VMMemoryEngine shared] getResultItemAtIndex:indexPath.row
                                           dataType:VMDataTypeInt64];
  if (item) {
    cell.textLabel.text = [NSString stringWithFormat:@"0x%llX", item.address];

    long long ptrVal = [item.valueStr longLongValue];
    long long offset = (long long)self.targetAddress - ptrVal;

    NSString *symbol =
        [[VMMemoryEngine shared] symbolicateAddress:item.address];
    NSString *modName = symbol ? symbol : TR(@"Ptr_Heap_Symbol");

    cell.detailTextLabel.text =
        [NSString stringWithFormat:TR(@"Ptr_Result_Offset"), offset, modName];

    if (symbol) {
      cell.detailTextLabel.textColor = [UIColor systemGreenColor];
    } else {
      cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
  }
  return cell;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  
  if (textField == self.depthField || textField == self.offsetField ||
      textField == self.limitField) {
    [textField resignFirstResponder];
    [self handleStartAction]; 
    return YES;
  }
  [textField resignFirstResponder];
  return YES;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  VMScanResultItem *item =
      [[VMMemoryEngine shared] getResultItemAtIndex:indexPath.row
                                           dataType:VMDataTypeInt64];
  if (!item)
    return;
  [[VMMemoryEngine shared] backupCurrentSession];
  VMPointerSearchViewController *nextVC =
      [[VMPointerSearchViewController alloc] init];
  nextVC.level = self.level + 1;
  nextVC.targetAddress = item.address;
  [self.navigationController pushViewController:nextVC animated:YES];
}

- (void)directSaveStaticPointers {
  NSMutableArray *chains = [NSMutableArray array];
  NSUInteger count = [VMMemoryEngine shared].resultCount;
  NSString *currentBundleID = [VMMemoryEngine shared].currentBundleID;

  for (NSUInteger i = 0; i < count; i++) {
    VMScanResultItem *item =
        [[VMMemoryEngine shared] getResultItemAtIndex:i
                                             dataType:VMDataTypeInt64];
    VMModuleMatch *match =
        [[VMMemoryEngine shared] findModuleForAddress:item.address];
    if (match) {
      VMPointerChain *c = [VMPointerChain new];
      c.moduleName = match.moduleName;
      c.baseOffset = match.offset;
      c.lastKnownValue = self.targetAddress;
      c.bundleID = [[VMMemoryEngine shared] currentBundleID];
      long long ptrVal = [item.valueStr longLongValue];
      c.offsets = @[ @(self.targetAddress - ptrVal) ];
      c.note = [NSString
          stringWithFormat:TR(@"Ptr_Static_Note_Fmt"), (long)self.level];

      if (currentBundleID && currentBundleID.length > 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id proxy = [NSClassFromString(@"LSApplicationProxy")
            performSelector:NSSelectorFromString(
                                @"applicationProxyForIdentifier:")
                 withObject:currentBundleID];
        if (proxy) {
          c.appName =
              [proxy performSelector:NSSelectorFromString(@"localizedName")];
          NSString *ver = [proxy
              performSelector:NSSelectorFromString(@"shortVersionString")];
          if (!ver)
            ver =
                [proxy performSelector:NSSelectorFromString(@"bundleVersion")];
          c.appVersion = ver;
        }
#pragma clang diagnostic pop
      }

      [chains addObject:c];
    }
  }

  if (chains.count > 0) {
    [[VMPointerManager shared] saveChainsToVerifierFile:chains
                                               bundleID:currentBundleID];
    [self showToast:[NSString stringWithFormat:TR(@"Ptr_Static_Saved_Msg_Fmt"),
                                               (unsigned long)chains.count]];
  } else {
    [self showToast:TR(@"Ptr_Static_No_Found")];
  }
}

#pragma mark - Helper UI Methods

- (void)showLoadingOverlayWithText:(NSString *)text {
  if (!self.loadingOverlay) {
    self.loadingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.loadingOverlay.backgroundColor =
        [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.6];
    self.loadingOverlay.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 120)];
    box.center = self.loadingOverlay.center;
    box.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    box.layer.cornerRadius = 12;
    box.layer.shadowColor = [UIColor blackColor].CGColor;
    box.layer.shadowOpacity = 0.2;
    box.layer.shadowOffset = CGSizeMake(0, 4);
    box.layer.shadowRadius = 8;

    box.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                           UIViewAutoresizingFlexibleRightMargin |
                           UIViewAutoresizingFlexibleTopMargin |
                           UIViewAutoresizingFlexibleBottomMargin;

    [self.loadingOverlay addSubview:box];

    UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spin.center = CGPointMake(90, 50);
    [spin startAnimating];
    [box addSubview:spin];

    self.loadingLabel =
        [[UILabel alloc] initWithFrame:CGRectMake(10, 80, 160, 40)];
    self.loadingLabel.textAlignment = NSTextAlignmentCenter;
    self.loadingLabel.font = [UIFont systemFontOfSize:12
                                               weight:UIFontWeightMedium];
    self.loadingLabel.textColor = [UIColor labelColor];
    self.loadingLabel.numberOfLines = 0;
    self.loadingLabel.lineBreakMode = NSLineBreakByWordWrapping;
    [box addSubview:self.loadingLabel];
  }
  self.loadingLabel.text = text;
  [self.view addSubview:self.loadingOverlay];
}

- (void)updateLoadingText:(NSString *)text {
  self.loadingLabel.text = text;
}

- (void)hideLoadingOverlay {
  [self.loadingOverlay removeFromSuperview];
  self.loadingOverlay = nil;
}

- (void)addDoneButtonTo:(UITextField *)tf {
  UIToolbar *tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
  UIBarButtonItem *done = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                           target:tf
                           action:@selector(resignFirstResponder)];
  [VMUIHelper styleConfirmationItem:done];
  tb.items = @[
    [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                             target:nil
                             action:nil],
    done
  ];
  tf.inputAccessoryView = tb;
}

- (void)addSelectButtonToField:(UITextField *)field {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button setImage:[UIImage systemImageNamed:@"chevron.down.circle.fill"] forState:UIControlStateNormal];
  button.tintColor = [VMUIHelper accentColor];
  button.accessibilityLabel = TR(@"Btn_Select_Fwk");
  button.frame = CGRectMake(0, 0, 44, 44);
  [button addTarget:self action:@selector(openModuleListSelector) forControlEvents:UIControlEventTouchUpInside];
  field.rightView = button;
  field.rightViewMode = UITextFieldViewModeAlways;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
  if (textField == self.moduleField) {
    [self openModuleListSelector];
    return NO;
  }
  return YES;
}

- (void)openModuleListSelector {
  VMModuleListViewController *listVC =
      [[VMModuleListViewController alloc] init];
  __weak VMPointerSearchViewController *weakSelf = self;
  listVC.selectionHandler = ^(VMModuleInfo *_Nullable selectedModule) {
    dispatch_async(dispatch_get_main_queue(), ^{
      weakSelf.selectedModule = selectedModule;
      if (selectedModule) {
        weakSelf.moduleField.text = selectedModule.name;
        weakSelf.moduleField.textColor = [UIColor labelColor];
      } else {
        weakSelf.moduleField.text = TR(@"Placeholder_Auto_Search");
        weakSelf.moduleField.textColor = [UIColor systemGrayColor];
      }
    });
  };
  [self.navigationController pushViewController:listVC animated:YES];
}

- (void)showToast:(NSString *)msg {
  UIAlertController *ac =
      [UIAlertController alertControllerWithTitle:nil
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:ac animated:YES completion:nil];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [ac dismissViewControllerAnimated:YES completion:nil];
                 });
}

@end
