#import "../pointer/VMPointerVerifierViewController.h"
#import "../../utils/helpers/VMShareHelper.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/helpers/VMKeyboardAvoidance.h"
#import "../common/VMFormSheetViewController.h"
#import "../main/VMAppSelectViewController.h"
#import "../main/VMLockListViewController.h"
#import "../memory/VMHexEditorViewController.h"
#import "../memory/VMMemoryActionSheet.h"
#import "../memory/VMMemoryBrowserViewController.h"
#import "include/VMDataSession.h"
#import "include/VMLocalization.h"
#import "include/VMLockManager.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerChain.h"
#import "include/VMPointerManager.h"
#import <libkern/OSAtomic.h>
#include <stdatomic.h>
#include <sys/sysctl.h>
extern "C" int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
#define TR(key) ([[VMLocalization shared] localizedString:key])
@interface VMPointerVerifierViewController () <
    UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property(nonatomic, strong) UIView *headerContainer;
@property(nonatomic, strong) UIView *statsContainer;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIImageView *statusIcon;
@property(nonatomic, strong) UILabel *appNameLabel;
@property(nonatomic, strong) UILabel *bundleIdLabel;
@property(nonatomic, strong) UITextField *inputField;
@property(nonatomic, strong) UISegmentedControl *typeSegment;
@property(nonatomic, strong) UIButton *verifyButton;
@property(nonatomic, strong) UISwitch *filterSwitch;
@property(nonatomic, strong) UILabel *filterLabel;
@property(nonatomic, strong) UILabel *statsLabel;
@property(nonatomic, strong) NSMutableArray<VMPointerChain *> *allChains;
@property(nonatomic, strong) NSArray<VMPointerChain *> *displayChains;
@property(nonatomic, assign) BOOL showValidOnly;
@property(nonatomic, assign) BOOL hasVerifiedOnce;
@property(nonatomic, strong) UIView *loadingOverlay;
@property(nonatomic, copy) NSString *fileBundleID;
@property(nonatomic, copy) NSString *fileAppName;

@property(nonatomic, assign) NSUInteger currentPage;
@property(nonatomic, assign) NSUInteger pageSize;
@property(nonatomic, assign) BOOL isLoadingMore;
@property(nonatomic, strong) NSArray<VMPointerChain *> *pagedDisplayChains;

@end
@implementation VMPointerVerifierViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = TR(@"Ptr_Verifier_Title_Short");
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  self.showValidOnly = NO;
  self.hasVerifiedOnce = NO;
  
  self.currentPage = 0;
  self.pageSize = 100;  
  self.isLoadingMore = NO;

  [self setupUI];

  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];

  [self startAsyncLoad];

  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
      initWithTarget:self
              action:@selector(dismissKeyboard)];
  tap.cancelsTouchesInView = NO;
  [self.view addGestureRecognizer:tap];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self checkProcessStatus];

  [self checkAndReconnectIfNeeded];
}

- (void)checkAndReconnectIfNeeded {
  if (!self.fileBundleID || self.fileBundleID.length == 0) {
    if (!self.allChains || self.allChains.count == 0) {
      [self startAsyncLoad];
    }
    return;
  }

  VMMemoryEngine *eng = [VMMemoryEngine shared];
  BOOL isTaskValid = (eng.targetTask != MACH_PORT_NULL);
  BOOL isPidAlive = (eng.targetPid > 0 && kill(eng.targetPid, 0) == 0);
  BOOL isBidMatch = YES;
  if (eng.currentBundleID) {
    isBidMatch = [eng.currentBundleID isEqualToString:self.fileBundleID];
  }

  if (isTaskValid && isPidAlive && isBidMatch) {
    return;
  }

  if ([self tryAutoAttach]) {
    [self checkProcessStatus];
  }
}

#pragma mark - UI Layout (3分容器)
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
  self.headerContainer = [UIView new];
  [VMUIHelper styleCard:self.headerContainer];
  UIStackView *form = [UIStackView new];
  form.axis = UILayoutConstraintAxisVertical;
  form.spacing = 14;
  form.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerContainer addSubview:form];
  UIStackView *status = [UIStackView new];
  status.axis = UILayoutConstraintAxisHorizontal;
  status.alignment = UIStackViewAlignmentTop;
  status.spacing = 12;
  self.statusIcon = [UIImageView new];
  self.statusIcon.contentMode = UIViewContentModeScaleAspectFit;
  [self.statusIcon.widthAnchor constraintEqualToConstant:28].active = YES;
  [self.statusIcon.heightAnchor constraintEqualToConstant:28].active = YES;
  [status addArrangedSubview:self.statusIcon];
  UIStackView *identity = [UIStackView new];
  identity.axis = UILayoutConstraintAxisVertical;
  identity.spacing = 4;
  self.appNameLabel = [UILabel new];
  self.appNameLabel.font = [VMUIHelper scaledFontOfSize:17 weight:UIFontWeightSemibold];
  self.appNameLabel.adjustsFontForContentSizeCategory = YES;
  self.appNameLabel.numberOfLines = 0;
  self.bundleIdLabel = [UILabel new];
  self.bundleIdLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleCaption1] scaledFontForFont:[UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular]];
  self.bundleIdLabel.adjustsFontForContentSizeCategory = YES;
  self.bundleIdLabel.textColor = [UIColor secondaryLabelColor];
  self.bundleIdLabel.numberOfLines = 0;
  self.bundleIdLabel.lineBreakMode = NSLineBreakByCharWrapping;
  [self.bundleIdLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [identity addArrangedSubview:self.appNameLabel];
  [identity addArrangedSubview:self.bundleIdLabel];
  [status addArrangedSubview:identity];
  [form addArrangedSubview:status];
  self.inputField = [UITextField new];
  self.inputField.placeholder = TR(@"Ptr_Saved_Placeholder");
  self.inputField.accessibilityLabel = TR(@"Ptr_Saved_Placeholder");
  self.inputField.keyboardType = UIKeyboardTypeASCIICapable;
  self.inputField.delegate = self;
  self.inputField.returnKeyType = UIReturnKeyDone;
  [VMUIHelper styleTextField:self.inputField];
  [self.inputField.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [self addDoneButtonTo:self.inputField];
  [form addArrangedSubview:self.inputField];
  self.typeSegment = [[UISegmentedControl alloc] initWithItems:@[TR(@"Type_I8"), TR(@"Type_I16"), TR(@"Type_I32"), TR(@"Type_I64"), TR(@"Type_F32"), TR(@"Type_F64")]];
  self.typeSegment.selectedSegmentIndex = 2;
  self.typeSegment.accessibilityLabel = TR(@"Value_Type");
  [self.typeSegment.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [form addArrangedSubview:self.typeSegment];
  UILabel *hint = [UILabel new];
  hint.text = TR(@"Verifier_Auto_Reconnect_Hint");
  hint.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
  hint.adjustsFontForContentSizeCategory = YES;
  hint.numberOfLines = 0;
  hint.textColor = [UIColor secondaryLabelColor];
  [form addArrangedSubview:hint];
  self.verifyButton = [VMUIHelper createButtonWithTitle:TR(@"Verifier_Btn_Verify") color:[VMUIHelper accentColor] target:self action:@selector(runVerification)];
  [VMUIHelper styleButton:self.verifyButton primary:YES];
  [self.verifyButton.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  UIButton *save = [VMUIHelper createButtonWithTitle:TR(@"Verifier_Btn_Save") color:[VMUIHelper accentColor] target:self action:@selector(manualSaveAction)];
  [VMUIHelper styleButton:save primary:NO];
  [save.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [form addArrangedSubview:self.verifyButton];
  [form addArrangedSubview:save];
  [layout addArrangedSubview:self.headerContainer];
  self.statsContainer = [UIView new];
  [VMUIHelper styleCard:self.statsContainer];
  UIStackView *summary = [UIStackView new];
  summary.axis = UILayoutConstraintAxisVertical;
  summary.spacing = 12;
  summary.translatesAutoresizingMaskIntoConstraints = NO;
  [self.statsContainer addSubview:summary];
  self.statsLabel = [UILabel new];
  self.statsLabel.font = [VMUIHelper scaledFontOfSize:14 weight:UIFontWeightSemibold];
  self.statsLabel.adjustsFontForContentSizeCategory = YES;
  self.statsLabel.numberOfLines = 0;
  self.statsLabel.textColor = [VMUIHelper accentColor];
  [summary addArrangedSubview:self.statsLabel];
  UIStackView *filter = [UIStackView new];
  filter.axis = UILayoutConstraintAxisHorizontal;
  filter.alignment = UIStackViewAlignmentCenter;
  filter.spacing = 12;
  self.filterLabel = [UILabel new];
  self.filterLabel.text = TR(@"Verifier_Filter_Valid");
  self.filterLabel.font = [VMUIHelper scaledFontOfSize:14 weight:UIFontWeightRegular];
  self.filterLabel.adjustsFontForContentSizeCategory = YES;
  self.filterLabel.numberOfLines = 0;
  self.filterSwitch = [UISwitch new];
  self.filterSwitch.onTintColor = [VMUIHelper accentColor];
  self.filterSwitch.accessibilityLabel = self.filterLabel.text;
  [self.filterSwitch addTarget:self action:@selector(toggleFilter) forControlEvents:UIControlEventValueChanged];
  [filter addArrangedSubview:self.filterLabel];
  [filter addArrangedSubview:self.filterSwitch];
  [filter.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  [summary addArrangedSubview:filter];
  [layout addArrangedSubview:self.statsContainer];
  [NSLayoutConstraint activateConstraints:@[
    [layout.topAnchor constraintEqualToAnchor:wrapper.topAnchor constant:16],
    [layout.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor constant:-16],
    [layout.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:16],
    [layout.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor constant:-16],
    [form.topAnchor constraintEqualToAnchor:self.headerContainer.topAnchor constant:16],
    [form.bottomAnchor constraintEqualToAnchor:self.headerContainer.bottomAnchor constant:-16],
    [form.leadingAnchor constraintEqualToAnchor:self.headerContainer.leadingAnchor constant:16],
    [form.trailingAnchor constraintEqualToAnchor:self.headerContainer.trailingAnchor constant:-16],
    [summary.topAnchor constraintEqualToAnchor:self.statsContainer.topAnchor constant:16],
    [summary.bottomAnchor constraintEqualToAnchor:self.statsContainer.bottomAnchor constant:-16],
    [summary.leadingAnchor constraintEqualToAnchor:self.statsContainer.leadingAnchor constant:16],
    [summary.trailingAnchor constraintEqualToAnchor:self.statsContainer.trailingAnchor constant:-16]
  ]];
  self.tableView.tableHeaderView = wrapper;
  [self updateStatusUI];
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (void)updateTableHeaderHeight:(UIView *)header {
  if (self.tableView.tableHeaderView != header) self.tableView.tableHeaderView = header;
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

#pragma mark - Logic: 状态监测
- (void)checkProcessStatus {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  pid_t pid = eng.targetPid;

  BOOL isAlive = (pid > 0 && kill(pid, 0) == 0);

  if (eng.targetTask != MACH_PORT_NULL && !isAlive) {
    eng.targetTask = MACH_PORT_NULL;
    eng.targetPid = 0;
  }

  [self updateStatusUI];
}

- (void)updateStatusUI {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  BOOL connected = (eng.targetTask != MACH_PORT_NULL && eng.targetPid > 0);

  NSString *appName = eng.currentProcessName ?: @"Unknown";
  
  NSString *bundleID = connected ? eng.currentBundleID : (self.fileBundleID.length ? self.fileBundleID : eng.currentBundleID);

  if (connected) {
    self.appNameLabel.text = [NSString
        stringWithFormat:@"%@ - %@", appName, TR(@"Status_Connected")];
    self.appNameLabel.textColor = [UIColor labelColor];
    self.statusIcon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
    self.statusIcon.tintColor = [UIColor systemGreenColor];
  } else {
    
    NSString *displayAppName = self.fileAppName ?: appName;
    self.appNameLabel.text =
        [NSString stringWithFormat:@"%@ - %@", displayAppName,
                                   TR(@"Status_Disconnected")];
    self.appNameLabel.textColor = [UIColor systemRedColor];
    self.statusIcon.image = [UIImage systemImageNamed:@"xmark.circle.fill"];
    self.statusIcon.tintColor = [UIColor systemRedColor];
  }
  self.bundleIdLabel.text = bundleID.length ? bundleID : @"Bundle ID: —";
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (void)openAppSelector {
  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"VMReqProcessRefresh"
                    object:nil];

  if (self.tabBarController) {
    for (UIViewController *controller in self.tabBarController.viewControllers) {
      if ([controller isKindOfClass:UINavigationController.class] &&
          [((UINavigationController *)controller).viewControllers.firstObject isKindOfClass:VMAppSelectViewController.class]) {
        self.tabBarController.selectedViewController = controller;
        break;
      }
    }
  }
}

#pragma mark - Logic: 验证与筛选
- (void)startAsyncLoad {
  if (self.loadingOverlay)
    [self.loadingOverlay removeFromSuperview];

  self.loadingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
  self.loadingOverlay.backgroundColor =
      [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.3];
  self.loadingOverlay.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  spinner.translatesAutoresizingMaskIntoConstraints = NO;
  [spinner startAnimating];
  [self.loadingOverlay addSubview:spinner];

  [NSLayoutConstraint activateConstraints:@[
    [spinner.centerXAnchor
        constraintEqualToAnchor:self.loadingOverlay.centerXAnchor],
    [spinner.centerYAnchor
        constraintEqualToAnchor:self.loadingOverlay.centerYAnchor]
  ]];

  [self.view addSubview:self.loadingOverlay];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    [self loadChainsInternal];

    dispatch_async(dispatch_get_main_queue(), ^{
      [self.loadingOverlay removeFromSuperview];
      self.loadingOverlay = nil;

      [self updateStatsLabel];
      [self.tableView reloadData];
    });
  });
}

- (void)loadChainsInternal {
  
  NSError *error;
  NSData *data = [NSData dataWithContentsOfFile:self.filePath
                                        options:NSDataReadingMappedIfSafe
                                          error:&error];

  if (data) {
    
    VMDataSession *session = [VMDataSession fromVerifierData:data];
    if (session && session.dataItems) {
      self.allChains = [session.dataItems mutableCopy];
      self.displayChains = self.allChains;
      self.fileBundleID = session.bundleID;
      
      self.currentPage = 0;
      [self updatePagedDisplayChains];

      dispatch_async(dispatch_get_main_queue(), ^{
        if (session.appName) {
          self.fileAppName = session.appName;
          self.appNameLabel.text = session.appName;
        }
        if (session.bundleID) {
          self.fileBundleID = session.bundleID;
          self.bundleIdLabel.text = session.bundleID;
        }
      });
    }
  }
}

- (void)updateStatsLabel {
  unsigned long total = self.allChains.count;
  unsigned long showing = self.displayChains.count;
  self.statsLabel.text =
      [NSString stringWithFormat:@"%@: %lu / %lu", TR(@"Verifier_Res_Header"),
                                 showing, total];
}

- (void)toggleFilter {
  self.showValidOnly = self.filterSwitch.isOn;
  [self updateDisplayList];
}

- (void)updateDisplayList {
  if (self.showValidOnly) {
    NSPredicate *pred =
        [NSPredicate predicateWithFormat:@"isRuntimeValid == YES"];
    self.displayChains = [self.allChains filteredArrayUsingPredicate:pred];
  } else {
    self.displayChains = self.allChains;
  }
  
  self.currentPage = 0;
  [self updatePagedDisplayChains];
  
  [self updateStatsLabel];
  [self.tableView reloadData];
}

- (void)updatePagedDisplayChains {
  NSUInteger endIndex = MIN((self.currentPage + 1) * self.pageSize, self.displayChains.count);
  if (endIndex > 0) {
    self.pagedDisplayChains = [self.displayChains subarrayWithRange:NSMakeRange(0, endIndex)];
  } else {
    self.pagedDisplayChains = @[];
  }
}

- (void)loadMoreIfNeeded {
  if (self.isLoadingMore) return;
  
  NSUInteger totalPages = (self.displayChains.count + self.pageSize - 1) / self.pageSize;
  if (self.currentPage + 1 >= totalPages) return;
  
  self.isLoadingMore = YES;
  self.currentPage++;
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [self updatePagedDisplayChains];
    [self.tableView reloadData];
    self.isLoadingMore = NO;
  });
}

- (BOOL)tryAutoAttach {
  NSString *targetBid = self.fileBundleID;

  if (!targetBid) {
    return NO;
  }

  int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t size;
  if (sysctl(mib, 4, NULL, &size, NULL, 0) == -1)
    return NO;
  struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
  if (sysctl(mib, 4, procs, &size, NULL, 0) == -1) {
    free(procs);
    return NO;
  }

  int count = size / sizeof(struct kinfo_proc);
  pid_t foundPid = 0;

  for (int i = 0; i < count; i++) {
    pid_t pid = procs[i].kp_proc.p_pid;
    if (pid <= 0)
      continue;

    char pathBuffer[4096];
    memset(pathBuffer, 0, sizeof(pathBuffer));
    proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];

    if ([fullPath containsString:@".app"]) {
      NSString *appDir = [fullPath stringByDeletingLastPathComponent];
      while (![appDir.pathExtension isEqualToString:@"app"] &&
             ![appDir isEqualToString:@"/"]) {
        appDir = [appDir stringByDeletingLastPathComponent];
      }

      NSString *plistPath =
          [appDir stringByAppendingPathComponent:@"Info.plist"];
      NSDictionary *info =
          [NSDictionary dictionaryWithContentsOfFile:plistPath];

      if (info && [info[@"CFBundleIdentifier"]
                      caseInsensitiveCompare:targetBid] == NSOrderedSame) {
        foundPid = pid;
        break;
      }
    }
  }
  free(procs);

  if (foundPid > 0) {
    BOOL success = [[VMMemoryEngine shared] attachToPid:foundPid];
    if (success) {
      [VMMemoryEngine shared].currentBundleID = targetBid;
      [[VMMemoryEngine shared] loadRemoteModules];

      [self checkProcessStatus];
      return YES;
    }
  }

  return NO;
}

- (void)runVerification {
  [self.inputField resignFirstResponder];

  VMMemoryEngine *eng = [VMMemoryEngine shared];
  BOOL isAlive = (eng.targetPid > 0 && kill(eng.targetPid, 0) == 0);

  if (eng.targetTask == MACH_PORT_NULL || !isAlive) {
    if ([self tryAutoAttach]) {
      [self runVerification];
    } else {
      UIAlertController *alert = [UIAlertController
          alertControllerWithTitle:TR(@"Err_Not_Connected")
                           message:TR(@"Verifier_Reconnect_Msg")
                    preferredStyle:UIAlertControllerStyleAlert];

      [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                                style:UIAlertActionStyleCancel
                                              handler:nil]];
      [alert addAction:[UIAlertAction
                           actionWithTitle:TR(@"Btn_OK")
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action) {
                                     if ([self tryAutoAttach]) {
                                       [self runVerification];
                                     } else {
                                       [self showToast:TR(@"Msg_Attach_Fail")];
                                     }
                                   }]];

      [self presentViewController:alert animated:YES completion:nil];
    }
    return;
  }

  NSString *input = self.inputField.text;
  if (!input || input.length == 0) {
    [self showToast:TR(@"Ptr_Saved_Enter_Target")];
    return;
  }
  
  static const VMDataType typeMap[] = {VMDataTypeInt8,  VMDataTypeInt16,
                                       VMDataTypeInt32, VMDataTypeInt64,
                                       VMDataTypeFloat, VMDataTypeDouble};
  NSInteger typeIdx = self.typeSegment.selectedSegmentIndex;
  VMDataType selectedType =
      (typeIdx >= 0 && typeIdx < 6) ? typeMap[typeIdx] : VMDataTypeInt32;
  self.verifyButton.enabled = NO;
  [self.verifyButton setTitle:TR(@"Ptr_Calculating")
                     forState:UIControlStateNormal];
  NSArray *modules = [[VMMemoryEngine shared] loadRemoteModules];
  [self executeVerificationWithInput:input
                             modules:modules
                            dataType:selectedType];
}

#pragma mark - TableView
- (CGFloat)tableView:(UITableView *)tableView
    heightForHeaderInSection:(NSInteger)section {
  return CGFLOAT_MIN;
}

- (UIView *)tableView:(UITableView *)tableView
    viewForHeaderInSection:(NSInteger)section {
  return nil;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  
  return self.pagedDisplayChains.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cid = @"res";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:cid];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:14];
    cell.detailTextLabel.font = [UIFont fontWithName:@"Menlo" size:11];
  }

  if (indexPath.row >= self.pagedDisplayChains.count) {
    return cell;
  }
  
  VMPointerChain *chain = self.pagedDisplayChains[indexPath.row];
  BOOL isDynamic = (chain.chainType == VMPointerChainTypeDynamic);

  NSString *idxStr =
      [NSString stringWithFormat:@"[%ld] ", (long)(indexPath.row + 1)];

  if (chain.runtimeValue && chain.isRuntimeValid) {
    cell.textLabel.text =
        [NSString stringWithFormat:@"%@%@", idxStr, chain.runtimeValue];
    
    if (isDynamic) {
      cell.textLabel.textColor = [UIColor systemOrangeColor];
      cell.tintColor = [UIColor systemOrangeColor];
      cell.backgroundColor =
          [[UIColor systemOrangeColor] colorWithAlphaComponent:0.08];
    } else {
      cell.textLabel.textColor = [UIColor systemGreenColor];
      cell.tintColor = [UIColor systemGreenColor];
      cell.backgroundColor = [UIColor clearColor];
    }
    cell.accessoryType = UITableViewCellAccessoryDetailButton;
  } else {
    cell.textLabel.text = [NSString
        stringWithFormat:@"%@%@", idxStr, chain.runtimeValue ?: @"--"];
    cell.textLabel.textColor = [UIColor systemRedColor];
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.backgroundColor = [UIColor clearColor];
  }

  NSString *displayStr = [chain displayString];
  if (isDynamic) {
    displayStr = [NSString stringWithFormat:@"%@ (%@)", displayStr,
                                            TR(@"Ptr_Dynamic_Session_Only")];
  }
  cell.detailTextLabel.text = displayStr;
  cell.detailTextLabel.textColor = [UIColor labelColor];
  
  if (indexPath.row >= self.pagedDisplayChains.count - 20) {
    [self loadMoreIfNeeded];
  }

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (indexPath.row >= self.pagedDisplayChains.count) {
    return;
  }
  
  VMPointerChain *chain = self.pagedDisplayChains[indexPath.row];
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:TR(@"Pop_Options")
                       message:[chain displayString]
                preferredStyle:UIAlertControllerStyleActionSheet];

  uint64_t finalAddr = 0;
  uint64_t modBase = 0;
  if ([chain.moduleName isEqualToString:@"virtual"]) {
    modBase = [VMMemoryEngine shared].mainModuleAddress;
  } else {
    modBase = [[VMMemoryEngine shared] findModuleBaseAddress:chain.moduleName];
  }
  if (modBase > 0) {
    finalAddr = [[VMMemoryEngine shared]
        resolvePointerChain:(modBase + chain.baseOffset)
                    offsets:chain.offsets];
  }

  if (finalAddr > 0) {
    [alert addAction:[UIAlertAction
                         actionWithTitle:TR(@"Mod_Menu_Value")
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                   VMMemoryBrowserViewController *browser =
                                       [VMMemoryBrowserViewController new];
                                   browser.address = finalAddr;
                                   browser.type = VMDataTypeInt32;
                                   [self.navigationController
                                       pushViewController:browser
                                                 animated:YES];
                                 }]];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Menu_Hex")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
                                              VMHexEditorViewController *hex =
                                                  [VMHexEditorViewController
                                                      new];
                                              hex.address = finalAddr;
                                              [self.navigationController
                                                  pushViewController:hex
                                                            animated:YES];
                                            }]];
  }

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Menu_Lock_Top")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *a) {
                                            [self showAddToLockAlert:chain];
                                          }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Ptr_Action_Copy_Export")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [[UIPasteboard generalPasteboard]
                                                setString:[chain exportString]];
                                            [self showToast:TR(@"Msg_Copied")];
                                          }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    alert.popoverPresentationController.sourceView = tableView;
    alert.popoverPresentationController.sourceRect =
        [tableView rectForRowAtIndexPath:indexPath];
  }
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAddToLockAlert:(VMPointerChain *)chain {
  NSString *defaultNote = [NSString stringWithFormat:TR(@"Ptr_Lock_Def_Note_Fmt"),
      [VMMemoryEngine shared].currentProcessName ?: @"Game",
      (unsigned long)(chain.offsets.count + (chain.moduleName ? 1 : 0))];
  NSString *bundleID = self.fileBundleID.length ? self.fileBundleID : [VMMemoryEngine shared].currentBundleID;
  VMFormSheetViewController *form = [[VMFormSheetViewController alloc] initWithTitle:TR(@"Lock_Add_Ptr_Title") submitTitle:TR(@"Btn_Save")];
  form.message = [chain displayString];
  UITextField *noteField = [form addTextFieldWithLabel:TR(@"Lab_Note_Colon") value:defaultNote placeholder:TR(@"Placeholder_Note") keyboardType:UIKeyboardTypeDefault];
  UITextField *valueField = [form addTextFieldWithLabel:TR(@"Lab_Value_Colon") value:chain.runtimeValue ?: @"0" placeholder:TR(@"Mod_Input_Value_Placeholder") keyboardType:UIKeyboardTypeNumbersAndPunctuation];
  [form addSectionWithTitle:TR(@"Value_Type")];
  UISegmentedControl *types = [[UISegmentedControl alloc] initWithItems:@[TR(@"Type_I8"), TR(@"Type_I16"), TR(@"Type_I32"), TR(@"Type_I64"), @"U8", @"U16", @"U32", @"U64", TR(@"Type_F32"), TR(@"Type_F64"), @"Str"]];
  static const VMDataType verificationTypes[] = {VMDataTypeInt8, VMDataTypeInt16, VMDataTypeInt32, VMDataTypeInt64, VMDataTypeFloat, VMDataTypeDouble};
  NSInteger selection = self.typeSegment.selectedSegmentIndex;
  types.selectedSegmentIndex = selection >= 0 && selection < 6 ? verificationTypes[selection] : VMDataTypeInt32;
  types.accessibilityLabel = TR(@"Value_Type");
  types.translatesAutoresizingMaskIntoConstraints = NO;
  UIScrollView *typeScroll = [UIScrollView new];
  typeScroll.showsHorizontalScrollIndicator = NO;
  [typeScroll addSubview:types];
  [NSLayoutConstraint activateConstraints:@[
    [typeScroll.heightAnchor constraintEqualToConstant:44],
    [types.leadingAnchor constraintEqualToAnchor:typeScroll.contentLayoutGuide.leadingAnchor],
    [types.trailingAnchor constraintEqualToAnchor:typeScroll.contentLayoutGuide.trailingAnchor],
    [types.topAnchor constraintEqualToAnchor:typeScroll.contentLayoutGuide.topAnchor],
    [types.bottomAnchor constraintEqualToAnchor:typeScroll.contentLayoutGuide.bottomAnchor],
    [types.heightAnchor constraintEqualToAnchor:typeScroll.frameLayoutGuide.heightAnchor],
    [types.widthAnchor constraintGreaterThanOrEqualToConstant:572],
    [types.widthAnchor constraintGreaterThanOrEqualToAnchor:typeScroll.frameLayoutGuide.widthAnchor]
  ]];
  [types addAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
    UISegmentedControl *control = action.sender;
    valueField.keyboardType = control.selectedSegmentIndex == VMDataTypeString ? UIKeyboardTypeDefault : UIKeyboardTypeNumbersAndPunctuation;
    if (valueField.isFirstResponder) [valueField reloadInputViews];
  }] forControlEvents:UIControlEventValueChanged];
  [form addView:typeScroll];
  UITextField *authorField = [form addTextFieldWithLabel:TR(@"Label_Author") value:TR(@"Placeholder_Author_Default") placeholder:TR(@"Placeholder_Author") keyboardType:UIKeyboardTypeDefault];
  __weak VMPointerVerifierViewController *weakSelf = self;
  form.submitHandler = ^NSString *(VMFormSheetViewController *sheet) {
    if (!bundleID.length) return TR(@"Err_Not_Connected_Msg");
    VMPointerChain *saved = [VMPointerChain fromDictionary:[chain toDictionary]];
    saved.note = noteField.text.length ? noteField.text : defaultNote;
    saved.author = authorField.text.length ? authorField.text : @"VansonMod";
    saved.isImported = NO;
    saved.lockEnabled = NO;
    saved.lockType = types.selectedSegmentIndex;
    saved.lockValue = valueField.text.length ? valueField.text : (chain.runtimeValue ?: @"0");
    saved.bundleID = bundleID;
    saved.runtimeValue = chain.runtimeValue;
    saved.cachedRuntimeAddress = chain.cachedRuntimeAddress;
    saved.isRuntimeValid = chain.isRuntimeValid;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id proxy = [NSClassFromString(@"LSApplicationProxy") performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:") withObject:bundleID];
    if (proxy) {
      saved.appName = [proxy performSelector:NSSelectorFromString(@"localizedName")];
      saved.appVersion = [proxy performSelector:NSSelectorFromString(@"shortVersionString")];
    }
#pragma clang diagnostic pop
    [[VMLockManager shared] addPointerToLock:saved];
    return nil;
  };
  form.didSubmit = ^{
    VMPointerVerifierViewController *self = weakSelf;
    if (!self) return;
    UIAlertController *share = [UIAlertController alertControllerWithTitle:TR(@"Share_Title") message:TR(@"Share_Msg") preferredStyle:UIAlertControllerStyleAlert];
    [share addAction:[UIAlertAction actionWithTitle:TR(@"Share_Go_Locks") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      for (UIViewController *controller in self.tabBarController.viewControllers) {
        if (controller.tabBarItem.tag != 3 || ![controller isKindOfClass:UINavigationController.class]) continue;
        self.tabBarController.selectedViewController = controller;
        UINavigationController *nav = (UINavigationController *)controller;
        [nav popToRootViewControllerAnimated:NO];
        if ([nav.topViewController isKindOfClass:VMLockListViewController.class]) {
          id lockVC = nav.topViewController;
          [lockVC setValue:@2 forKey:@"defaultTabIndex"];
          if ([lockVC respondsToSelector:@selector(tabChanged)]) [lockVC performSelector:@selector(tabChanged)];
        }
        break;
      }
    }]];
    [share addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:share animated:YES completion:nil];
  };
  [form presentFrom:self];
  dispatch_async(dispatch_get_main_queue(), ^{
    [typeScroll layoutIfNeeded];
    CGFloat width = types.bounds.size.width / types.numberOfSegments;
    [typeScroll scrollRectToVisible:CGRectMake(width * types.selectedSegmentIndex, 0, width, 44) animated:NO];
  });
}

- (void)addDoneButtonTo:(UITextField *)textField {
  CGFloat width = [UIScreen mainScreen].bounds.size.width;
  UIToolbar *toolbar =
      [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
  toolbar.barStyle = UIBarStyleDefault;
  toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

  UIBarButtonItem *flex = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                           target:nil
                           action:nil];

  UIBarButtonItem *done =
      [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_OK")
                                       style:UIBarButtonItemStyleDone
                                      target:self
                                      action:@selector(dismissKeyboard)];
  [VMUIHelper styleConfirmationItem:done];

  toolbar.items = @[ flex, done ];
  textField.inputAccessoryView = toolbar;
}

- (void)dismissKeyboard {
  [self.view endEditing:YES];
}

- (void)executeVerificationWithInput:(NSString *)input
                             modules:(NSArray *)modules
                            dataType:(VMDataType)type {
  NSArray *targetList =
      self.showValidOnly ? self.displayChains : self.allChains;
  NSUInteger totalCount = targetList.count;

  if (totalCount == 0) {
    self.verifyButton.enabled = YES;
    [self.verifyButton setTitle:TR(@"Verifier_Btn_ReVerify")
                       forState:UIControlStateNormal];
    return;
  }

  VMMemoryEngine *engine = [VMMemoryEngine shared];
  BOOL isHexInput = [input hasPrefix:@"0x"];
  uint64_t targetHex = 0;
  if (isHexInput) {
    targetHex = strtoull([input UTF8String], NULL, 16);
  }
  double targetDouble = [input doubleValue];
  BOOL isFloatSearch = (type == VMDataTypeFloat || type == VMDataTypeDouble);

  __block atomic_int successCount = 0;
  
  NSMutableDictionary<NSString *, NSNumber *> *moduleBaseMap = [NSMutableDictionary dictionary];
  for (VMModuleInfo *mod in modules) {
    if (mod.name && mod.loadAddress > 0) {
      moduleBaseMap[mod.name] = @(mod.loadAddress);
    }
  }
  
  moduleBaseMap[@"virtual"] = @(engine.mainModuleAddress);

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    
    NSUInteger chunkSize = 500;  
    NSUInteger chunkCount = (totalCount + chunkSize - 1) / chunkSize;
    
    dispatch_apply(
        chunkCount, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
        ^(size_t chunkIdx) {
          @autoreleasepool {
            NSUInteger startIdx = chunkIdx * chunkSize;
            NSUInteger endIdx = MIN(startIdx + chunkSize, totalCount);
            
            for (NSUInteger i = startIdx; i < endIdx; i++) {
              id item = targetList[i];

              BOOL isValid = NO;
              NSString *currentVal = @"--";

              BOOL isSignatureVerification = NO;
              NSString *signature = nil;
              NSString *moduleName = nil;
              long long sigOffset = 0;

              if ([item isKindOfClass:[VMSignatureModel class]]) {
                
                VMSignatureModel *sig = (VMSignatureModel *)item;
                isSignatureVerification = YES;
                signature = sig.signature;
                moduleName = sig.moduleName;
                sigOffset = sig.offset;
              } else if ([item isKindOfClass:[VMPointerChain class]]) {
                VMPointerChain *chain = (VMPointerChain *)item;
                if (chain.isSignatureMode) {
                  
                  isSignatureVerification = YES;
                  signature = chain.signature;
                  moduleName = chain.moduleName;
                  if (chain.offsets.count > 0) {
                    sigOffset = [chain.offsets[0] longLongValue];
                  }
                }
              }

              if (isSignatureVerification && signature.length > 0) {
                
                __block uint64_t foundAddr = 0;

                dispatch_semaphore_t sema = dispatch_semaphore_create(0);

                void (^handleResult)(NSArray *) = ^(NSArray *results) {
                  if (results.count > 0) {
                    VMScanResultItem *firstResult = results[0];
                    foundAddr = firstResult.address + sigOffset;
                  }
                  dispatch_semaphore_signal(sema);
                };

                if (moduleName && moduleName.length > 0) {
                  [engine fastScanSignature:signature
                                   inModule:moduleName
                                 completion:handleResult];
                } else {
                  [engine scanSignature:signature
                             rangeStart:0
                               rangeEnd:0
                             completion:handleResult];
                }

                dispatch_semaphore_wait(
                    sema, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));

                if (foundAddr > 0) {
                  currentVal = [engine readAddress:foundAddr type:type];

                  if (isHexInput) {
                    if (foundAddr == targetHex)
                      isValid = YES;
                  } else if (isFloatSearch) {
                    double val = [currentVal doubleValue];
                    if (fabs(val - targetDouble) < engine.floatTolerance)
                      isValid = YES;
                  } else {
                    if ([currentVal isEqualToString:input])
                      isValid = YES;
                  }
                }

                if ([item isKindOfClass:[VMSignatureModel class]]) {
                  VMSignatureModel *sig = (VMSignatureModel *)item;
                  sig.runtimeValue = currentVal;
                  sig.isRuntimeValid = isValid;
                } else if ([item isKindOfClass:[VMPointerChain class]]) {
                  VMPointerChain *chain = (VMPointerChain *)item;
                  chain.runtimeValue = currentVal;
                  chain.isRuntimeValid = isValid;
                }

              } else if ([item isKindOfClass:[VMPointerChain class]]) {
                
                VMPointerChain *chain = (VMPointerChain *)item;

                NSNumber *baseNum = moduleBaseMap[chain.moduleName];
                uint64_t modBase = baseNum ? [baseNum unsignedLongLongValue] : 0;

                if (modBase > 0) {
                  uint64_t start = modBase + chain.baseOffset;
                  uint64_t finalAddr = [engine resolvePointerChain:start
                                                           offsets:chain.offsets];

                  if (finalAddr > 0) {
                    currentVal = [engine readAddress:finalAddr type:type];

                    if (isHexInput) {
                      if (finalAddr == targetHex)
                        isValid = YES;
                    } else if (isFloatSearch) {
                      double val = [currentVal doubleValue];
                      if (fabs(val - targetDouble) < engine.floatTolerance)
                        isValid = YES;
                    } else {
                      if ([currentVal isEqualToString:input])
                        isValid = YES;
                    }
                  }
                }

                chain.runtimeValue = currentVal;
                chain.isRuntimeValid = isValid;
              }

              if (isValid) {
                
                atomic_fetch_add_explicit(&successCount, 1, memory_order_relaxed);
              }
            }
          }
        });

    dispatch_async(dispatch_get_main_queue(), ^{
      self.verifyButton.enabled = YES;
      [self.verifyButton setTitle:TR(@"Verifier_Btn_ReVerify")
                         forState:UIControlStateNormal];
      self.hasVerifiedOnce = YES;

      NSMutableArray<VMPointerChain *> *failedDynamicChains =
          [NSMutableArray array];
      for (VMPointerChain *chain in self.allChains) {
        if (chain.chainType == VMPointerChainTypeDynamic &&
            !chain.isRuntimeValid) {
          [failedDynamicChains addObject:chain];
        }
      }

      if (successCount > 0) {
        self.filterSwitch.on = YES;
        self.showValidOnly = YES;
        [self
            showToast:[NSString stringWithFormat:TR(@"Ptr_Saved_Found_Valid"),
                                                 (unsigned long)successCount]];
      } else {
        self.filterSwitch.on = NO;
        self.showValidOnly = NO;
        [self showToast:TR(@"Ptr_Verify_No_Match_Hint")];
      }

      [self updateDisplayList];

      if (failedDynamicChains.count > 0) {
        [self promptBacktrackForDynamicChains:failedDynamicChains];
      }
    });
  });
}

- (void)finishVerificationWithSuccessCount:(NSUInteger)successCount {
  self.verifyButton.enabled = YES;
  self.hasVerifiedOnce = YES;
  [self.verifyButton setTitle:TR(@"Verifier_Btn_ReVerify")
                     forState:UIControlStateNormal];

  if (successCount > 0) {
    self.filterSwitch.on = YES;
    self.showValidOnly = YES;
    [self showToast:[NSString stringWithFormat:TR(@"Ptr_Saved_Found_Valid"),
                                               (unsigned long)successCount]];
  } else {
    self.filterSwitch.on = NO;
    self.showValidOnly = NO;
    [self showToast:TR(@"Ptr_Verify_No_Match_Hint")];
  }

  [self updateDisplayList];
}

- (void)silentSaveValidChains {
  NSPredicate *pred =
      [NSPredicate predicateWithFormat:@"isRuntimeValid == YES"];
  NSArray *validChains = [self.allChains filteredArrayUsingPredicate:pred];

  static NSUInteger lastValidCount = 0;

  if (validChains.count > 0) {
    
    if (lastValidCount > 0 && validChains.count < lastValidCount) {
      NSUInteger decrease = lastValidCount - validChains.count;
      if (decrease > 100) {
        
        return;
      }
    }

    lastValidCount = validChains.count;

    NSString *bid = self.fileBundleID;
    if (!bid || bid.length == 0) {
      bid = [[VMMemoryEngine shared] currentBundleID];
    }
    [[VMPointerManager shared] saveChainsToVerifierFile:validChains
                                               bundleID:bid];
  } else {
    
    lastValidCount = 0;
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  [self runVerification];
  return YES;
}

- (void)showToast:(NSString *)msg {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:nil
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:alert animated:YES completion:nil];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
      });
}

- (void)manualSaveAction {
  NSPredicate *pred =
      [NSPredicate predicateWithFormat:@"isRuntimeValid == YES"];
  NSArray *validChains = [self.allChains filteredArrayUsingPredicate:pred];

  if (validChains.count == 0) {
    [self showToast:TR(@"Mod_No_Result")];
    return;
  }

  NSString *bid = self.fileBundleID ?: [[VMMemoryEngine shared] currentBundleID] ?: @"UnknownApp";

  NSString *parentDir = [self.filePath stringByDeletingLastPathComponent];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (!parentDir || ![fm fileExistsAtPath:parentDir]) {
    parentDir = [[[VMPointerManager shared] verifierFolder]
        stringByAppendingPathComponent:bid];
    if (![fm fileExistsAtPath:parentDir]) {
      [fm createDirectoryAtPath:parentDir
          withIntermediateDirectories:YES
                           attributes:nil
                                error:nil];
    }
  }

  NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
  [fmt setDateFormat:@"yyMMdd_HHmmss"];
  NSString *countStr = [NSString
      stringWithFormat:@"(%lu Pts)", (unsigned long)validChains.count];
  NSString *defaultBaseName =
      [NSString stringWithFormat:@"Verify_%@_%@",
                                 [fmt stringFromDate:[NSDate date]], countStr];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Verifier_Btn_Save")
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = defaultBaseName;
    tf.placeholder = TR(@"Verifier_File_Name");
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
  }];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [alert addAction:
             [UIAlertAction
                 actionWithTitle:TR(@"Btn_Confirm")
                           style:UIAlertActionStyleDefault
                         handler:^(UIAlertAction *action) {
                           NSString *inputName =
                               alert.textFields.firstObject.text;
                           if (inputName.length == 0)
                             inputName = defaultBaseName;

                           NSString *fullPath = [[VMPointerManager shared]
                               generateUniquePathInFolder:parentDir
                                                 baseName:inputName
                                                extension:@"vmvapt"];

                           VMDataSession *session =
                               [VMDataSession sessionWithData:validChains
                                                     bundleID:bid
                                                     dataType:@"pointer"];
                           NSData *data = [session toVerifierJSONData];

                           if ([data writeToFile:fullPath atomically:YES]) {
                             NSString *msg = [NSString
                                 stringWithFormat:@"%@\n%@", TR(@"Msg_Saved"),
                                                  [fullPath lastPathComponent]];
                             [self showToast:msg];

                             UIImpactFeedbackGenerator *gen =
                                 [[UIImpactFeedbackGenerator alloc]
                                     initWithStyle:UIImpactFeedbackStyleMedium];
                             [gen impactOccurred];
                           } else {
                             [self showToast:TR(@"Err_File_Write")];
                           }
                         }]];

  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Auto Backtrack (动态指针自动追溯)

- (void)promptBacktrackForDynamicChains:
    (NSArray<VMPointerChain *> *)failedChains {
  NSString *msg = [NSString stringWithFormat:TR(@"Ptr_Backtrack_Prompt_Fmt"),
                                             (unsigned long)failedChains.count];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Ptr_Backtrack_Title")
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Ptr_Backtrack_Start")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                 [self performAutoBacktrack:failedChains];
                               }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)performAutoBacktrack:(NSArray<VMPointerChain *> *)dynamicChains {
  
  [self showLoadingOverlay];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    
    [[VMMemoryEngine shared] takeGlobalSnapshotObjC];

    __block NSUInteger upgradedCount = 0;
    NSUInteger totalCount = MIN(dynamicChains.count, 50); 

    for (NSUInteger i = 0; i < totalCount; i++) {
      VMPointerChain *dynamicChain = dynamicChains[i];
      uint64_t heapBase = dynamicChain.heapBaseAddress;

      if (heapBase == 0) {
        continue;
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        [self updateLoadingText:
                  [NSString stringWithFormat:@"%@ %lu/%lu",
                                             TR(@"Ptr_Backtrack_Progress"),
                                             (unsigned long)(i + 1),
                                             (unsigned long)totalCount]];
      });

      dispatch_semaphore_t sem = dispatch_semaphore_create(0);
      __block VMPointerChain *foundStaticChain = nil;

      [[VMMemoryEngine shared]
          autoSearchPointerChainObjCEx:heapBase
                             heapStart:0x100000000
                               heapEnd:0x800000000
                             baseStart:0x100000000
                               baseEnd:0x800000000
                             maxLevels:5
                           maxPerLevel:100000
                             maxOffset:0x2000
                        selectedModule:nil
                         progressBlock:nil
                            completion:^(NSArray<VMPointerChain *> *chains) {
                              
                              for (VMPointerChain *chain in chains) {
                                if (chain.chainType == VMPointerChainTypeStatic) {
                                  foundStaticChain = chain;
                                  break;
                                }
                              }
                              dispatch_semaphore_signal(sem);
                            }];

      dispatch_semaphore_wait(
          sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));

      if (foundStaticChain) {
        
        NSMutableArray *mergedOffsets =
            [NSMutableArray arrayWithArray:foundStaticChain.offsets];
        [mergedOffsets addObjectsFromArray:dynamicChain.offsets];

        @synchronized(self.allChains) {
          NSUInteger idx = [self.allChains indexOfObject:dynamicChain];
          if (idx != NSNotFound) {
            VMPointerChain *upgradedChain = [[VMPointerChain alloc] init];
            upgradedChain.moduleName = foundStaticChain.moduleName;
            upgradedChain.baseOffset = foundStaticChain.baseOffset;
            upgradedChain.offsets = mergedOffsets;
            upgradedChain.chainType = VMPointerChainTypeStatic;
            upgradedChain.lastKnownValue = dynamicChain.lastKnownValue;
            upgradedChain.bundleID = dynamicChain.bundleID;
            upgradedChain.appName = dynamicChain.appName;
            upgradedChain.appVersion = dynamicChain.appVersion;
            upgradedChain.note = [NSString
                stringWithFormat:@"%@ (Upgraded)", dynamicChain.note ?: @""];

            [self.allChains replaceObjectAtIndex:idx withObject:upgradedChain];
            upgradedCount++;
          }
        }
      }
    }

    [[VMMemoryEngine shared] clearSnapshot];

    dispatch_async(dispatch_get_main_queue(), ^{
      [self hideLoadingOverlay];

      if (upgradedCount > 0) {
        [self showToast:[NSString
                            stringWithFormat:TR(@"Ptr_Backtrack_Success_Fmt"),
                                             (unsigned long)upgradedCount]];
        [self updateDisplayList];

        [self promptSaveAfterUpgrade];
      } else {
        [self showToast:TR(@"Ptr_Backtrack_No_Result")];
      }
    });
  });
}

- (void)promptSaveAfterUpgrade {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:TR(@"Ptr_Backtrack_Save_Title")
                       message:TR(@"Ptr_Backtrack_Save_Msg")
                preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Verifier_Btn_Save")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action) {
                                            [self saveCurrentChains];
                                          }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveCurrentChains {
  NSString *bid = self.fileBundleID ?: [[VMMemoryEngine shared] currentBundleID] ?: @"Unknown";
  VMDataSession *session = [VMDataSession sessionWithData:self.allChains
                                                 bundleID:bid
                                                 dataType:@"pointer"];
  NSData *data = [session toVerifierJSONData];

  if (self.filePath && [data writeToFile:self.filePath atomically:YES]) {
    [self showToast:TR(@"Msg_Save_Success")];
  } else {
    [self showToast:TR(@"Err_File_Write")];
  }
}

- (void)showLoadingOverlay {
  if (self.loadingOverlay)
    return;

  self.loadingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
  self.loadingOverlay.backgroundColor =
      [[UIColor blackColor] colorWithAlphaComponent:0.5];
  self.loadingOverlay.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  spinner.center = CGPointMake(self.loadingOverlay.bounds.size.width / 2,
                               self.loadingOverlay.bounds.size.height / 2 - 30);
  spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                             UIViewAutoresizingFlexibleRightMargin |
                             UIViewAutoresizingFlexibleTopMargin |
                             UIViewAutoresizingFlexibleBottomMargin;
  [spinner startAnimating];
  [self.loadingOverlay addSubview:spinner];

  UILabel *label = [[UILabel alloc] init];
  label.text = TR(@"Ptr_Backtrack_Progress");
  label.textColor = [UIColor whiteColor];
  label.textAlignment = NSTextAlignmentCenter;
  label.tag = 100;
  label.frame = CGRectMake(0, spinner.center.y + 40,
                           self.loadingOverlay.bounds.size.width, 30);
  label.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                           UIViewAutoresizingFlexibleTopMargin |
                           UIViewAutoresizingFlexibleBottomMargin;
  [self.loadingOverlay addSubview:label];

  [self.view addSubview:self.loadingOverlay];
}

- (void)updateLoadingText:(NSString *)text {
  UILabel *label = [self.loadingOverlay viewWithTag:100];
  label.text = text;
}

- (void)hideLoadingOverlay {
  [self.loadingOverlay removeFromSuperview];
  self.loadingOverlay = nil;
}

@end
