#import "VMMemoryFeedback.h"

#import "VMWatchpointViewController.h"
#import "VMStringMemorySession.h"
#import "../../core/VMDebugEngine.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import "include/VMRVAPatch.h"
#import <objc/runtime.h>
#include <mach/mach.h>

extern "C" kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t,
                                         mach_vm_size_t, boolean_t, vm_prot_t);

#define TR(key) ([[VMLocalization shared] localizedString:key])

#pragma mark - Main ViewController

@interface VMWatchpointViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UISegmentedControl *segControl;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *headerCard;

@property (nonatomic, strong) NSMutableArray<VMWatchHit *> *hits;
@property (nonatomic, assign) BOOL isAttached;

@property (nonatomic, strong) UIView *inspectorOverlay;
@property (nonatomic, strong) NSMutableArray<UIButton *> *inspectorButtons;
@property (nonatomic, strong) UIScrollView *inspectorScrollView;
@property (nonatomic, strong) NSLayoutConstraint *inspectorBottomConstraint;
@property (nonatomic, strong) NSLayoutConstraint *inspectorTableHeight;
@property (nonatomic, assign) CGRect inspectorKeyboardFrame;
@property (nonatomic, assign) pid_t inspectorPid;
@property (nonatomic, assign) mach_port_t inspectorTask;
@end

@implementation VMWatchpointViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = TR(@"WP_Page_Title");
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  self.hits = [NSMutableArray array];

  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle"]
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(showHelp)];

  self.navigationItem.rightBarButtonItem.accessibilityLabel = TR(@"WP_Page_Title");
  [self setupUI];
  [self setupHitCallback];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleProcessDetached)
                                               name:@"VMProcessChangedNotification" object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:)
                                               name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
                                               name:UIKeyboardWillHideNotification object:nil];

  if (self.initialAddress != 0) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      VMDebugEngine *engine = [VMDebugEngine shared];

      mach_port_t currentTask = [VMMemoryEngine shared].targetTask;
      if (engine.isAttached && currentTask != engine.currentTask) {
        [engine detach];
      }

      if (!engine.isAttached) {
        if (currentTask == MACH_PORT_NULL) {
          [self showToast:TR(@"Err_Not_Connected")];
          return;
        }
        if (![engine attach]) {
          [self showToast:TR(@"WP_Attach_Fail")];
          return;
        }
        [self updateUI];
        [self.tableView reloadData];
      }

      [self addWatchForAddress:self.initialAddress];
    });
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [VMDebugEngine shared].hitCallback = nil;
}

- (void)handleProcessDetached {
  VMDebugEngine *engine = [VMDebugEngine shared];
  if (engine.isAttached) {
    [engine detach];
  }
  [self.hits removeAllObjects];
  [self dismissInspector];
  [self updateUI];
  [self.tableView reloadData];
}

#pragma mark - UI Setup

- (void)setupUI {

  self.headerCard = [self makeCard];
  [self.view addSubview:self.headerCard];
  self.headerCard.translatesAutoresizingMaskIntoConstraints = NO;

  self.statusLabel = [[UILabel alloc] init];
  self.statusLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightMedium];
  self.statusLabel.textColor = [UIColor secondaryLabelColor];
  self.statusLabel.numberOfLines = 2;
  self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self.headerCard addSubview:self.statusLabel];

  UIButton *attachBtn = [UIButton buttonWithType:UIButtonTypeSystem];
  attachBtn.tag = 100;
  attachBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
  attachBtn.layer.cornerRadius = 8;
  attachBtn.translatesAutoresizingMaskIntoConstraints = NO;
  [attachBtn addTarget:self action:@selector(toggleAttach) forControlEvents:UIControlEventTouchUpInside];
  [self.headerCard addSubview:attachBtn];

  [NSLayoutConstraint activateConstraints:@[
    [self.headerCard.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
    [self.headerCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
    [self.headerCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
    [self.headerCard.heightAnchor constraintEqualToConstant:84],
    [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.headerCard.leadingAnchor constant:14],
    [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.headerCard.centerYAnchor],
    [self.statusLabel.trailingAnchor constraintEqualToAnchor:attachBtn.leadingAnchor constant:-8],
    [attachBtn.trailingAnchor constraintEqualToAnchor:self.headerCard.trailingAnchor constant:-14],
    [attachBtn.centerYAnchor constraintEqualToAnchor:self.headerCard.centerYAnchor],
    [attachBtn.widthAnchor constraintGreaterThanOrEqualToConstant:92],
    [attachBtn.heightAnchor constraintGreaterThanOrEqualToConstant:44],
  ]];

  self.segControl = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"WP_Seg_Slots"), TR(@"WP_Seg_Hits")
  ]];
  self.segControl.selectedSegmentIndex = 0;
  self.segControl.translatesAutoresizingMaskIntoConstraints = NO;
  [self.segControl addTarget:self action:@selector(segChanged) forControlEvents:UIControlEventValueChanged];
  [self.view addSubview:self.segControl];

  UIStackView *btnRow = [[UIStackView alloc] init];
  btnRow.axis = UILayoutConstraintAxisHorizontal;
  btnRow.spacing = 10;
  btnRow.distribution = UIStackViewDistributionFillEqually;
  btnRow.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:btnRow];

  UIButton *addBtn = [self actionButton:TR(@"WP_Add") color:[VMUIHelper accentColor] action:@selector(addWatch)];
  UIButton *clearBtn = [self actionButton:TR(@"WP_Clear") color:[UIColor systemRedColor] action:@selector(clearAll)];
  addBtn.tag = 101;
  clearBtn.tag = 102;
  [btnRow addArrangedSubview:addBtn];
  [btnRow addArrangedSubview:clearBtn];

  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
  self.tableView.showsHorizontalScrollIndicator = NO;
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tableView.backgroundColor = [UIColor clearColor];
  [self.view addSubview:self.tableView];

  [NSLayoutConstraint activateConstraints:@[
    [self.segControl.topAnchor constraintEqualToAnchor:self.headerCard.bottomAnchor constant:12],
    [self.segControl.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
    [self.segControl.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
    [btnRow.topAnchor constraintEqualToAnchor:self.segControl.bottomAnchor constant:10],
    [btnRow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
    [btnRow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
    [btnRow.heightAnchor constraintEqualToConstant:48],
    [self.tableView.topAnchor constraintEqualToAnchor:btnRow.bottomAnchor constant:8],
    [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
  ]];

  [self updateUI];
}

- (UIView *)makeCard {
  UIView *card = [[UIView alloc] init];
  card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
  [VMUIHelper styleCard:card];
  return card;
}

- (UIButton *)actionButton:(NSString *)title color:(UIColor *)color action:(SEL)sel {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  [btn setTitle:title forState:UIControlStateNormal];
  btn.tintColor = color;
  [VMUIHelper styleButton:btn primary:sel != @selector(clearAll)];
  [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  return btn;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
  [super traitCollectionDidChange:previousTraitCollection];
  if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
    for (UIButton *button in self.inspectorButtons)
      button.layer.borderColor = [UIColor.separatorColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
  }
}

#pragma mark - State Management

- (void)setupHitCallback {
  __weak VMWatchpointViewController *ws = self;
  [VMDebugEngine shared].hitCallback = ^(VMWatchHit *hit) {
    VMWatchpointViewController *ss = ws;
    if (!ss) return;
    [ss.hits insertObject:hit atIndex:0];
    if (ss.hits.count > 200) {
      [ss.hits removeObjectsInRange:NSMakeRange(200, ss.hits.count - 200)];
    }
    [ss updateUI];
    if (ss.segControl.selectedSegmentIndex == 1) {
      [ss.tableView reloadData];
    } else {

      [ss.tableView reloadData];
    }
  };
}

- (void)updateUI {
  VMDebugEngine *engine = [VMDebugEngine shared];
  self.isAttached = engine.isAttached;
  UIButton *add = [self.view viewWithTag:101];
  add.enabled = self.isAttached && engine.activeCount < engine.maxSlots;
  add.alpha = add.enabled ? 1 : 0.45;
  UIButton *clear = [self.view viewWithTag:102];
  clear.enabled = engine.activeCount > 0 || self.hits.count > 0;
  clear.alpha = clear.enabled ? 1 : 0.45;
  BOOL empty = self.segControl.selectedSegmentIndex == 1 && self.hits.count == 0;
  self.tableView.backgroundView = empty ? [VMUIHelper emptyStateWithTitle:TR(@"WP_No_Hits_Yet") message:TR(self.isAttached ? @"WP_Add_Msg" : @"WP_Not_Attached") symbol:@"waveform.path"] : nil;

  UIButton *attachBtn = [self.headerCard viewWithTag:100];
  BOOL available = [VMDebugEngine isAvailable];
  attachBtn.enabled = self.isAttached || (available && [VMMemoryEngine shared].targetTask != MACH_PORT_NULL);
  attachBtn.alpha = attachBtn.enabled ? 1 : 0.45;
  if (self.isAttached) {
    [attachBtn setTitle:TR(@"WP_Detach") forState:UIControlStateNormal];
    attachBtn.tintColor = UIColor.systemOrangeColor;
    [VMUIHelper styleButton:attachBtn primary:NO];
    self.statusLabel.text = [NSString stringWithFormat:@"%@ %u/%u  |  %@ %lu",
      TR(@"WP_Active"), engine.activeCount, engine.maxSlots,
      TR(@"WP_Hits_Label"), (unsigned long)self.hits.count];
  } else {
    [attachBtn setTitle:TR(@"WP_Attach") forState:UIControlStateNormal];
    attachBtn.tintColor = [VMUIHelper accentColor];
    [VMUIHelper styleButton:attachBtn primary:YES];
    self.statusLabel.text = TR(available ? @"WP_Status_Idle" : @"Patch_JB_Title");
  }
}

- (void)segChanged {
  [self updateUI];
  [self.tableView reloadData];
}

#pragma mark - Actions

- (void)toggleAttach {
  VMDebugEngine *engine = [VMDebugEngine shared];
  if (engine.isAttached) {
    [engine detach];
    [self.hits removeAllObjects];
    [self updateUI];
    [self.tableView reloadData];
    [self showToast:TR(@"WP_Detached")];
    return;
  }
  if ([VMMemoryEngine shared].targetTask == MACH_PORT_NULL) {
    [self showToast:TR(@"Err_Not_Connected")];
    return;
  }
  if ([engine attach]) {
    [self updateUI];
    [self.tableView reloadData];
    [self showToast:TR(@"WP_Attached")];
  } else {
    [self showToast:TR(@"WP_Attach_Fail")];
  }
}

- (void)addWatch {
  VMDebugEngine *engine = [VMDebugEngine shared];
  if (!engine.isAttached) {
    [self showToast:TR(@"WP_Not_Attached")];
    return;
  }
  if (engine.activeCount >= engine.maxSlots) {
    [self showToast:TR(@"WP_Max_Slots")];
    return;
  }

  UIAlertController *ac = [UIAlertController alertControllerWithTitle:TR(@"WP_Add")
    message:TR(@"WP_Add_Msg") preferredStyle:UIAlertControllerStyleAlert];

  [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = @"0x...";
    tf.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    tf.keyboardType = UIKeyboardTypeASCIICapable;
  }];

  [ac addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [ac addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
    NSString *addrStr = ac.textFields[0].text;
    uint64_t addr = 0;
    if (![VMStringMemorySession parseAddress:addrStr value:&addr] || addr == 0) { [self showToast:TR(@"WP_Err_Addr")]; return; }

    int slot = [engine addWatchpoint:addr type:VMWatchTypeWrite size:VMWatchSizeByte4];
    if (slot >= 0) {
      [self showToast:[NSString stringWithFormat:@"%@ [%d] 0x%llX", TR(@"WP_Added"), slot, addr]];
      [self updateUI];
      [self.tableView reloadData];
    } else {
      [self showToast:TR(@"WP_Add_Fail")];
    }
  }]];
  [self presentViewController:ac animated:YES completion:nil];
}

- (void)addWatchForAddress:(uint64_t)addr {
  VMDebugEngine *engine = [VMDebugEngine shared];
  if (!engine.isAttached) return;
  if (engine.activeCount >= engine.maxSlots) {
    [self showToast:TR(@"WP_Max_Slots")];
    return;
  }
  int slot = [engine addWatchpoint:addr type:VMWatchTypeWrite size:VMWatchSizeByte4];
  if (slot >= 0) {
    [self showToast:[NSString stringWithFormat:@"%@ [%d] 0x%llX", TR(@"WP_Added"), slot, addr]];
    [self updateUI];
    [self.tableView reloadData];
  }
}

- (void)clearAll {
  UIAlertController *ac = [UIAlertController alertControllerWithTitle:TR(@"WP_Clear")
    message:TR(@"WP_Clear_Msg") preferredStyle:UIAlertControllerStyleAlert];
  [ac addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [ac addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
    [[VMDebugEngine shared] removeAllWatchpoints];
    [self.hits removeAllObjects];
    [self updateUI];
    [self.tableView reloadData];
    [self showToast:TR(@"WP_Cleared")];
  }]];
  [self presentViewController:ac animated:YES completion:nil];
}

- (void)removeSlot:(UIButton *)sender {
  NSNumber *idx = objc_getAssociatedObject(sender, "slotIdx");
  if (!idx) return;
  [[VMDebugEngine shared] removeWatchpoint:[idx unsignedIntValue]];
  [self updateUI];
  [self.tableView reloadData];
  [self showToast:TR(@"WP_Removed")];
}

- (void)showHelp {
  UIAlertController *ac = [UIAlertController alertControllerWithTitle:TR(@"WP_Page_Title")
    message:TR(@"WP_Help_Msg") preferredStyle:UIAlertControllerStyleAlert];
  [ac addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
  [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
  if (tv == self.tableView) {
    if (self.segControl.selectedSegmentIndex == 0) return [VMDebugEngine shared].maxSlots;
    return self.hits.count;
  }

  NSArray *lines = objc_getAssociatedObject(tv, "dasmLines");
  return lines ? (NSInteger)lines.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {

  if (tv != self.tableView) return [self dasmCellForTable:tv indexPath:ip];

  if (self.segControl.selectedSegmentIndex == 0) return [self slotCellForIndex:ip];
  return [self hitCellForIndex:ip];
}

- (UITableViewCell *)slotCellForIndex:(NSIndexPath *)ip {
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Slot"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Slot"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightBold];
    cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
    del.tag = 200;
    [del setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    del.tintColor = [UIColor systemRedColor];
    del.accessibilityLabel = TR(@"Act_Delete");
    [del addTarget:self action:@selector(removeSlot:) forControlEvents:UIControlEventTouchUpInside];
    del.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:del];
    [NSLayoutConstraint activateConstraints:@[
      [del.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
      [del.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
      [del.widthAnchor constraintEqualToConstant:44],
      [del.heightAnchor constraintEqualToConstant:44],
    ]];
  }

  uint32_t idx = (uint32_t)ip.row;
  VMDebugEngine *engine = [VMDebugEngine shared];
  BOOL active = [engine isSlotActive:idx];
  UIButton *del = [cell.contentView viewWithTag:200];

  if (active) {
    uint64_t addr = [engine slotAddress:idx];
    NSArray *hits = [engine hitsForSlot:idx];
    cell.textLabel.text = [NSString stringWithFormat:@"[%u] 0x%llX", idx, addr];
    cell.textLabel.textColor = [VMUIHelper accentColor];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %lu", TR(@"WP_Hits_Label"), (unsigned long)hits.count];
    del.hidden = NO;
  } else {
    cell.textLabel.text = [NSString stringWithFormat:@"[%u] %@", idx, TR(@"WP_Empty")];
    cell.textLabel.textColor = [UIColor tertiaryLabelColor];
    cell.detailTextLabel.text = @"--";
    del.hidden = YES;
  }
  objc_setAssociatedObject(del, "slotIdx", @(idx), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  return cell;
}

- (UITableViewCell *)hitCellForIndex:(NSIndexPath *)ip {
  UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Hit"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Hit"];
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightBold];
    cell.textLabel.textColor = [VMUIHelper accentColor];
    cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  }
  if (ip.row < (NSInteger)self.hits.count) {
    VMWatchHit *hit = self.hits[ip.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ + 0x%llX", hit.imageName, hit.offset];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"PC: 0x%llX | Val: %llu (0x%llX)\nAddr: 0x%llX | Slot: %u",
      hit.pc, hit.newValue, hit.newValue, hit.address, hit.slotIndex];
  }
  return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
  if (tv != self.tableView) {

    [self dasmTableDidSelect:tv indexPath:ip];
    return;
  }

  if (self.segControl.selectedSegmentIndex == 0) {

    [tv deselectRowAtIndexPath:ip animated:YES];
    uint32_t slotIdx = (uint32_t)ip.row;
    if (![[VMDebugEngine shared] isSlotActive:slotIdx]) return;

    NSInteger hitRow = -1;
    for (NSInteger i = 0; i < (NSInteger)self.hits.count; i++) {
      if (self.hits[i].slotIndex == slotIdx) { hitRow = i; break; }
    }
    if (hitRow < 0) {
      [self showToast:TR(@"WP_No_Hits_Yet")];
      return;
    }

    self.segControl.selectedSegmentIndex = 1;
    [self.tableView reloadData];
    [self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:hitRow inSection:0]
                          atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    return;
  }

  if (ip.row >= (NSInteger)self.hits.count) return;
  [tv deselectRowAtIndexPath:ip animated:YES];
  [self showInspectorForHit:self.hits[ip.row]];
}

- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
  if (tv != self.tableView) return 64;
  return (self.segControl.selectedSegmentIndex == 0) ? 64 : 84;
}

#pragma mark - Disassembly Inspector

- (void)showInspectorForHit:(VMWatchHit *)hit {
  if (self.inspectorOverlay) [self.inspectorOverlay removeFromSuperview];
  self.inspectorPid = [VMMemoryEngine shared].targetPid;
  self.inspectorTask = [VMMemoryEngine shared].targetTask;
  NSArray<NSDictionary *> *lines = [[VMDebugEngine shared] disassembleFunctionAt:hit.pc moduleName:hit.imageName];
  UIView *overlay = [UIView new];
  overlay.translatesAutoresizingMaskIntoConstraints = NO;
  overlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.42];
  overlay.accessibilityViewIsModal = YES;
  self.inspectorOverlay = overlay;
  self.inspectorButtons = [NSMutableArray array];
  [self.view addSubview:overlay];
  UIView *panel = [UIView new];
  panel.translatesAutoresizingMaskIntoConstraints = NO;
  [VMUIHelper styleCard:panel];
  panel.tag = 500;
  panel.clipsToBounds = YES;
  [overlay addSubview:panel];
  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
  self.inspectorBottomConstraint = [panel.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12];
  NSLayoutConstraint *preferredWidth = [panel.widthAnchor constraintEqualToAnchor:safe.widthAnchor constant:-24];
  preferredWidth.priority = UILayoutPriorityDefaultHigh;
  [NSLayoutConstraint activateConstraints:@[
    [overlay.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [overlay.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    [overlay.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [panel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:12],
    self.inspectorBottomConstraint,
    [panel.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],
    preferredWidth,
    [panel.widthAnchor constraintLessThanOrEqualToConstant:700],
    [panel.widthAnchor constraintLessThanOrEqualToAnchor:safe.widthAnchor constant:-24]
  ]];
  UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
  [close setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
  close.accessibilityLabel = TR(@"Common_Done");
  close.tintColor = [UIColor secondaryLabelColor];
  [close addTarget:self action:@selector(dismissInspector) forControlEvents:UIControlEventTouchUpInside];
  [close.widthAnchor constraintEqualToConstant:44].active = YES;
  [close.heightAnchor constraintEqualToConstant:44].active = YES;
  UILabel *title = [UILabel new];
  title.text = TR(@"WP_Inspector_Title");
  title.font = [VMUIHelper scaledFontOfSize:18 weight:UIFontWeightSemibold];
  title.numberOfLines = 0;
  UIStackView *heading = [[UIStackView alloc] initWithArrangedSubviews:@[title, close]];
  heading.alignment = UIStackViewAlignmentCenter;
  heading.spacing = 12;
  heading.translatesAutoresizingMaskIntoConstraints = NO;
  [panel addSubview:heading];
  UIScrollView *scroll = [UIScrollView new];
  scroll.showsHorizontalScrollIndicator = NO;
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
  self.inspectorScrollView = scroll;
  [panel addSubview:scroll];
  UIStackView *body = [UIStackView new];
  body.axis = UILayoutConstraintAxisVertical;
  body.spacing = 12;
  body.translatesAutoresizingMaskIntoConstraints = NO;
  [scroll addSubview:body];
  [NSLayoutConstraint activateConstraints:@[
    [heading.topAnchor constraintEqualToAnchor:panel.topAnchor constant:8],
    [heading.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
    [heading.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-12],
    [scroll.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:4],
    [scroll.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor],
    [scroll.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor],
    [scroll.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor],
    [body.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:4],
    [body.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-16],
    [body.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
    [body.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
    [body.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
  ]];
  UILabel *info = [UILabel new];
  info.numberOfLines = 0;
  info.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  info.textColor = [UIColor secondaryLabelColor];
  info.text = [NSString stringWithFormat:@"%@ + 0x%llX\nPC 0x%llX · %@ %llu (0x%llX)\n0x%llX", hit.imageName, hit.offset, hit.pc, TR(@"Common_Val"), hit.newValue, hit.newValue, hit.address];
  [body addArrangedSubview:info];
  UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
  table.showsHorizontalScrollIndicator = NO;
  table.tag = 501;
  table.delegate = self;
  table.dataSource = self;
  table.backgroundColor = [VMUIHelper canvasColor];
  table.layer.cornerRadius = 12;
  table.clipsToBounds = YES;
  table.tableFooterView = [UIView new];
  table.separatorInset = UIEdgeInsetsMake(0, 12, 0, 12);
  objc_setAssociatedObject(table, "dasmLines", lines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(table, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [body addArrangedSubview:table];
  self.inspectorTableHeight = [table.heightAnchor constraintEqualToConstant:280];
  self.inspectorTableHeight.active = YES;
  UIView *toolbar = [UIView new];
  toolbar.tag = 502;
  [VMUIHelper styleCard:toolbar];
  toolbar.backgroundColor = [VMUIHelper canvasColor];
  [body addArrangedSubview:toolbar];
  UIStackView *editing = [UIStackView new];
  editing.axis = UILayoutConstraintAxisVertical;
  editing.spacing = 10;
  editing.translatesAutoresizingMaskIntoConstraints = NO;
  [toolbar addSubview:editing];
  [NSLayoutConstraint activateConstraints:@[
    [editing.topAnchor constraintEqualToAnchor:toolbar.topAnchor constant:12],
    [editing.bottomAnchor constraintEqualToAnchor:toolbar.bottomAnchor constant:-12],
    [editing.leadingAnchor constraintEqualToAnchor:toolbar.leadingAnchor constant:12],
    [editing.trailingAnchor constraintEqualToAnchor:toolbar.trailingAnchor constant:-12]
  ]];
  UILabel *selection = [UILabel new];
  selection.tag = 503;
  selection.numberOfLines = 0;
  selection.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
  selection.textColor = [UIColor secondaryLabelColor];
  selection.text = TR(@"WP_Tap_Instruction");
  [editing addArrangedSubview:selection];
  UITextField *field = [UITextField new];
  field.tag = 504;
  field.placeholder = @"HEX · 1F2003D5";
  field.accessibilityLabel = TR(@"WP_Custom_Patch");
  [VMUIHelper styleTextField:field];
  field.keyboardType = UIKeyboardTypeASCIICapable;
  field.autocorrectionType = UITextAutocorrectionTypeNo;
  field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
  field.enabled = NO;
  UIToolbar *keyboard = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
  keyboard.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], [[UIBarButtonItem alloc] initWithTitle:TR(@"Common_Done") style:UIBarButtonItemStyleDone target:field action:@selector(resignFirstResponder)]];
  [VMUIHelper styleConfirmationItem:keyboard.items.lastObject];
  field.inputAccessoryView = keyboard;
  [editing addArrangedSubview:field];
  NSArray *presets = @[@"NOP", @"RET", @"MOV W0,#0", @"MOV W0,#1"];
  UIStackView *presetRow = [UIStackView new];
  presetRow.distribution = UIStackViewDistributionFillEqually;
  presetRow.spacing = 6;
  for (NSUInteger i = 0; i < presets.count; i++) {
    UIButton *button = [self bottomBarButton:presets[i] frame:CGRectZero];
    button.tag = 510 + i;
    button.titleLabel.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightSemibold];
    button.titleLabel.numberOfLines = 2;
    button.titleLabel.textAlignment = NSTextAlignmentCenter;
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    button.enabled = NO;
    button.alpha = 0.45;
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    [button addTarget:self action:@selector(onQuickAction:) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(button, "toolbar", toolbar, OBJC_ASSOCIATION_ASSIGN);
    [presetRow addArrangedSubview:button];
  }
  [editing addArrangedSubview:presetRow];
  UIButton *copyHex = [self bottomBarButton:TR(@"WP_Copy_Hex") frame:CGRectZero];
  copyHex.tag = 514;
  [copyHex addTarget:self action:@selector(onQuickAction:) forControlEvents:UIControlEventTouchUpInside];
  objc_setAssociatedObject(copyHex, "toolbar", toolbar, OBJC_ASSOCIATION_ASSIGN);
  UIButton *apply = [self bottomBarButton:TR(@"Btn_Apply") frame:CGRectZero];
  apply.tag = 505;
  [VMUIHelper styleButton:apply primary:YES];
  [apply addTarget:self action:@selector(onApplyPatch:) forControlEvents:UIControlEventTouchUpInside];
  objc_setAssociatedObject(apply, "toolbar", toolbar, OBJC_ASSOCIATION_ASSIGN);
  copyHex.enabled = apply.enabled = NO;
  copyHex.alpha = apply.alpha = 0.45;
  UIStackView *actionRow = [[UIStackView alloc] initWithArrangedSubviews:@[copyHex, apply]];
  actionRow.distribution = UIStackViewDistributionFillEqually;
  actionRow.spacing = 10;
  [actionRow.heightAnchor constraintEqualToConstant:48].active = YES;
  [editing addArrangedSubview:actionRow];
  objc_setAssociatedObject(toolbar, "dasmTable", table, OBJC_ASSOCIATION_ASSIGN);
  objc_setAssociatedObject(toolbar, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(toolbar, "panel", panel, OBJC_ASSOCIATION_ASSIGN);
  NSArray *titles = @[TR(@"WP_Copy_Disasm"), TR(@"WP_Copy_Offset"), TR(@"WP_Send_RVA"), @"ARM Converter"];
  NSArray *actions = @[NSStringFromSelector(@selector(onCopyAllDisasm:)), NSStringFromSelector(@selector(onCopyOffset:)), NSStringFromSelector(@selector(onSendToRVA:)), NSStringFromSelector(@selector(onOpenARMConverter))];
  for (NSUInteger row = 0; row < 2; row++) {
    UIStackView *buttons = [UIStackView new];
    buttons.spacing = 10;
    buttons.distribution = UIStackViewDistributionFillEqually;
    for (NSUInteger col = 0; col < 2; col++) {
      NSUInteger i = row * 2 + col;
      UIButton *button = [self bottomBarButton:titles[i] frame:CGRectZero];
      button.tag = 520 + i;
      [button addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside];
      objc_setAssociatedObject(button, "dasmHit", hit, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      if (i == 0) objc_setAssociatedObject(button, "dasmLines", lines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      [buttons addArrangedSubview:button];
    }
    [buttons.heightAnchor constraintEqualToConstant:48].active = YES;
    [body addArrangedSubview:buttons];
  }
  [self.view layoutIfNeeded];
  [self layoutInspector];
  for (NSUInteger i = 0; i < lines.count; i++) {
    if ([lines[i][@"isPC"] boolValue]) {
      [table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
      break;
    }
  }
  UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, title);
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self layoutInspector];
}

- (void)layoutInspector {
  if (!self.inspectorOverlay || !self.view.window) return;
  CGRect keyboard = [self.view convertRect:self.inspectorKeyboardFrame fromCoordinateSpace:self.view.window.screen.coordinateSpace];
  CGRect overlap = CGRectIntersection(self.view.bounds, keyboard);
  CGFloat inset = CGRectIsNull(overlap) || CGRectIsEmpty(overlap) || CGRectGetMaxY(overlap) < CGRectGetMaxY(self.view.bounds) - 1 ? 0 : MAX(0, overlap.size.height - self.view.safeAreaInsets.bottom);
  self.inspectorBottomConstraint.constant = -12 - inset;
  self.inspectorTableHeight.constant = MIN(360, MAX(144, self.view.safeAreaLayoutGuide.layoutFrame.size.height * 0.40));
}

- (BOOL)accessibilityPerformEscape {
  if (!self.inspectorOverlay) return NO;
  [self dismissInspector];
  return YES;
}

- (UIButton *)bottomBarButton:(NSString *)title frame:(CGRect)frame {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  btn.frame = frame;
  [btn setTitle:title forState:UIControlStateNormal];
  btn.titleLabel.font = [VMUIHelper scaledFontOfSize:14 weight:UIFontWeightMedium];
  btn.titleLabel.adjustsFontSizeToFitWidth = YES;
  btn.titleLabel.minimumScaleFactor = 0.85;
  btn.layer.cornerRadius = 10;
  btn.layer.borderWidth = 0.5;
  btn.layer.borderColor = [UIColor.separatorColor resolvedColorWithTraitCollection:self.traitCollection].CGColor;
  btn.backgroundColor = [UIColor secondarySystemBackgroundColor];
  [self.inspectorButtons addObject:btn];
  return btn;
}

- (void)dismissInspector {
  UIView *overlay = self.inspectorOverlay;
  if (!overlay) return;

  [overlay endEditing:YES];
  [UIView animateWithDuration:0.2 animations:^{
    overlay.alpha = 0;
  } completion:^(BOOL f) {
    [overlay removeFromSuperview];
    self.inspectorOverlay = nil;
    self.inspectorButtons = nil;
    self.inspectorScrollView = nil;
    self.inspectorKeyboardFrame = CGRectZero;
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, self.segControl);
  }];
}

#pragma mark - Keyboard Avoidance

- (void)keyboardWillShow:(NSNotification *)note {
  self.inspectorKeyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  [self layoutInspector];
  [UIView animateWithDuration:[note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue] animations:^{
    [self.view layoutIfNeeded];
  } completion:^(BOOL finished) {
    UIView *toolbar = [self.inspectorOverlay viewWithTag:502];
    if (toolbar) [self.inspectorScrollView scrollRectToVisible:[toolbar convertRect:toolbar.bounds toView:self.inspectorScrollView] animated:YES];
  }];
}

- (void)keyboardWillHide:(NSNotification *)note {
  self.inspectorKeyboardFrame = CGRectZero;
  [self layoutInspector];
  [UIView animateWithDuration:[note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue] animations:^{ [self.view layoutIfNeeded]; }];
}

- (void)onSelLabelTapped:(UITapGestureRecognizer *)tap {
  UILabel *selLabel = (UILabel *)tap.view;
  UIView *toolbar = selLabel.superview;
  if (!toolbar) return;
  NSString *selHex = objc_getAssociatedObject(toolbar, "selHex");
  if (!selHex.length) return;
  UITextField *pf = [toolbar viewWithTag:504];
  pf.text = selHex;
}

#pragma mark - Disasm Table Cells

- (UITableViewCell *)dasmCellForTable:(UITableView *)tv indexPath:(NSIndexPath *)ip {
  UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"Dasm"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Dasm"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
  }
  NSArray<NSDictionary *> *lines = objc_getAssociatedObject(tv, "dasmLines");
  if (ip.row < (NSInteger)lines.count) {
    NSDictionary *l = lines[ip.row];
    BOOL isPC = [l[@"isPC"] boolValue];
    NSNumber *selIdx = objc_getAssociatedObject(tv, "selIdx");
    BOOL isSel = (selIdx && [selIdx integerValue] == ip.row);
    NSString *marker = isPC ? @">" : (isSel ? @"*" : @" ");
    cell.textLabel.text = [NSString stringWithFormat:@"%@ 0x%llX · %@", marker, [l[@"offset"] unsignedLongLongValue], l[@"hex"]];
    cell.detailTextLabel.text = l[@"mnemonic"];
    cell.detailTextLabel.textColor = [UIColor labelColor];
    cell.accessibilityTraits = UIAccessibilityTraitButton | (isSel ? UIAccessibilityTraitSelected : 0);
    if (isSel) {
      cell.backgroundColor = [[VMUIHelper accentColor] colorWithAlphaComponent:0.12];
      cell.textLabel.textColor = [UIColor labelColor];
    } else if (isPC) {
      cell.backgroundColor = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.1];
      cell.textLabel.textColor = [UIColor labelColor];
    } else {
      cell.backgroundColor = [UIColor clearColor];
      cell.textLabel.textColor = [UIColor secondaryLabelColor];
    }
  }
  return cell;
}

- (void)dasmTableDidSelect:(UITableView *)tv indexPath:(NSIndexPath *)ip {
  NSArray<NSDictionary *> *lines = objc_getAssociatedObject(tv, "dasmLines");
  if (!lines || ip.row >= (NSInteger)lines.count) return;

  objc_setAssociatedObject(tv, "selIdx", @(ip.row), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [tv reloadData];

  NSDictionary *line = lines[ip.row];

  UIView *panel = [self.inspectorOverlay viewWithTag:500];
  UIView *toolbar = [panel viewWithTag:502];
  if (!toolbar) return;

  objc_setAssociatedObject(toolbar, "selOffset", line[@"offset"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(toolbar, "selHex", line[@"hex"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(toolbar, "selLine", line, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  UILabel *selLabel = [toolbar viewWithTag:503];
  selLabel.text = [NSString stringWithFormat:@"* 0x%llX  %@  %@",
    [line[@"offset"] unsignedLongLongValue], line[@"hex"], line[@"mnemonic"]];
  selLabel.textColor = [UIColor labelColor];

  UITextField *pf = [toolbar viewWithTag:504];
  pf.enabled = YES;
  UIButton *ab = (UIButton *)[toolbar viewWithTag:505];
  ab.enabled = YES; ab.alpha = 1.0;
  for (NSInteger i = 510; i <= 514; i++) {
    UIButton *q = (UIButton *)[toolbar viewWithTag:i];
    q.enabled = YES; q.alpha = 1.0;
  }
}

#pragma mark - Toolbar Actions

- (void)onApplyPatch:(UIButton *)sender {
  UIView *toolbar = objc_getAssociatedObject(sender, "toolbar");
  if (!toolbar) return;
  UITextField *pf = [toolbar viewWithTag:504];
  NSString *input = [pf.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if (!input.length) return;

  NSNumber *offNum = objc_getAssociatedObject(toolbar, "selOffset");
  VMWatchHit *hit = objc_getAssociatedObject(toolbar, "dasmHit");
  if (!offNum || !hit) return;

  NSString *hex = input;
  NSString *upper = [input uppercaseString];
  if ([upper isEqualToString:@"NOP"]) hex = @"1F2003D5";
  else if ([upper isEqualToString:@"RET"]) hex = @"C0035FD6";

  if (![self patchAtOffset:[offNum unsignedLongLongValue] hex:hex moduleName:hit.imageName]) return;
  pf.text = @"";
  [pf resignFirstResponder];

  [self refreshDisasmInPanel:[self.inspectorOverlay viewWithTag:500] hit:hit];
}

- (void)onQuickAction:(UIButton *)sender {
  UIView *toolbar = objc_getAssociatedObject(sender, "toolbar");
  if (!toolbar) return;
  NSNumber *offNum = objc_getAssociatedObject(toolbar, "selOffset");
  NSString *selHex = objc_getAssociatedObject(toolbar, "selHex");
  VMWatchHit *hit = objc_getAssociatedObject(toolbar, "dasmHit");
  if (!offNum || !hit) return;

  UITextField *pf = [toolbar viewWithTag:504];

  switch (sender.tag) {
    case 510: pf.text = @"1F2003D5"; break;
    case 511: pf.text = @"C0035FD6"; break;
    case 512: pf.text = @"00008052"; break;
    case 513: pf.text = @"20008052"; break;
    case 514: {
      if (selHex) {
        [UIPasteboard generalPasteboard].string = selHex;
        [self showToast:[NSString stringWithFormat:@"%@ %@", TR(@"Msg_Copy_Success"), selHex]];
      }
      break;
    }
  }
}

#pragma mark - Cross-Process Patching

- (BOOL)patchAtOffset:(uint64_t)offset hex:(NSString *)hexStr moduleName:(NSString *)moduleName {
  mach_port_t task = [VMMemoryEngine shared].targetTask;
  if (task != self.inspectorTask || [VMMemoryEngine shared].targetPid != self.inspectorPid) { [self showToast:TR(@"Str_Target_Changed")]; return NO; }
  if (task == MACH_PORT_NULL) {
    [self showToast:TR(@"Err_Not_Connected")];
    return NO;
  }

  uint64_t base = [[VMMemoryEngine shared] findModuleBaseAddress:moduleName];
  if (base == 0) {
    [self showToast:TR(@"WP_Err_Module")];
    return NO;
  }
  uint64_t absAddr = base + offset;

  NSString *clean = [[hexStr stringByReplacingOccurrencesOfString:@" " withString:@""]
                      uppercaseString];
  if (clean.length == 0 || clean.length % 2 != 0) {
    [self showToast:TR(@"Patch_Hex_Err")];
    return NO;
  }

  NSMutableData *data = [NSMutableData dataWithCapacity:clean.length / 2];
  for (NSUInteger i = 0; i < clean.length; i += 2) {
    unsigned int byte;
    NSString *byteStr = [clean substringWithRange:NSMakeRange(i, 2)];
    NSScanner *scanner = [NSScanner scannerWithString:byteStr];
    if (![scanner scanHexInt:&byte] || !scanner.isAtEnd) {
      [self showToast:TR(@"Patch_Hex_Err")];
      return NO;
    }
    uint8_t b = (uint8_t)byte;
    [data appendBytes:&b length:1];
  }

  mach_vm_size_t patchLen = data.length;
  kern_return_t kr = mach_vm_protect(task, absAddr, patchLen, FALSE,
                                     VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
  if (kr != KERN_SUCCESS) {
    kr = mach_vm_protect(task, absAddr, patchLen, FALSE,
                         VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
  }

  kr = vm_write(task, (vm_address_t)absAddr, (vm_offset_t)data.bytes, (mach_msg_type_number_t)patchLen);
  if (kr == KERN_SUCCESS) {

    mach_vm_protect(task, absAddr, patchLen, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
    [self showToast:TR(@"WP_Patched")];
    return YES;
  } else {
    [self showToast:TR(@"WP_Patch_Fail")];
    return NO;
  }
}

- (void)refreshDisasmInPanel:(UIView *)panel hit:(VMWatchHit *)hit {
  if (!panel) return;
  UITableView *dasmTable = [panel viewWithTag:501];
  if (!dasmTable) return;

  NSArray<NSDictionary *> *newLines = [[VMDebugEngine shared] disassembleFunctionAt:hit.pc
                                                                          moduleName:hit.imageName];
  objc_setAssociatedObject(dasmTable, "dasmLines", newLines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  NSNumber *selIdx = objc_getAssociatedObject(dasmTable, "selIdx");
  [dasmTable reloadData];

  if (selIdx && [selIdx integerValue] < (NSInteger)newLines.count) {
    [dasmTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:[selIdx integerValue] inSection:0]
                     atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
  }

  UIView *toolbar = [panel viewWithTag:502];
  if (toolbar && selIdx) {
    NSInteger idx = [selIdx integerValue];
    if (idx < (NSInteger)newLines.count) {
      NSDictionary *line = newLines[idx];
      objc_setAssociatedObject(toolbar, "selOffset", line[@"offset"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      objc_setAssociatedObject(toolbar, "selHex", line[@"hex"], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      objc_setAssociatedObject(toolbar, "selLine", line, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

      UILabel *selLabel = [toolbar viewWithTag:503];
      selLabel.text = [NSString stringWithFormat:@"* 0x%llX  %@  %@",
        [line[@"offset"] unsignedLongLongValue], line[@"hex"], line[@"mnemonic"]];
    }
  }

  UIButton *copyAll = [panel viewWithTag:520];
  if (copyAll) objc_setAssociatedObject(copyAll, "dasmLines", newLines, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Bottom Bar Actions

- (void)onCopyAllDisasm:(UIButton *)sender {
  NSArray<NSDictionary *> *lines = objc_getAssociatedObject(sender, "dasmLines");
  VMWatchHit *hit = objc_getAssociatedObject(sender, "dasmHit");
  if (!lines.count) {
    [self showToast:TR(@"Msg_Nothing_Copy")];
    return;
  }

  NSMutableString *text = [NSMutableString string];
  [text appendFormat:@"// %@ + 0x%llX  PC: 0x%llX\n", hit.imageName, hit.offset, hit.pc];
  for (NSDictionary *l in lines) {
    BOOL isPC = [l[@"isPC"] boolValue];
    [text appendFormat:@"%@ %08llX  %@  %@\n",
      isPC ? @">" : @" ",
      [l[@"offset"] unsignedLongLongValue],
      l[@"hex"], l[@"mnemonic"]];
  }
  [UIPasteboard generalPasteboard].string = text;
  [self showToast:TR(@"Msg_Copy_Success")];
}

- (void)onCopyOffset:(UIButton *)sender {
  VMWatchHit *hit = objc_getAssociatedObject(sender, "dasmHit");
  if (!hit) return;
  NSString *offStr = [NSString stringWithFormat:@"0x%llX", hit.offset];
  [UIPasteboard generalPasteboard].string = offStr;
  [self showToast:[NSString stringWithFormat:@"%@ %@", TR(@"Msg_Copy_Success"), offStr]];
}

- (void)onSendToRVA:(UIButton *)sender {
  VMWatchHit *hit = objc_getAssociatedObject(sender, "dasmHit");
  if (!hit) return;

  UIView *panel = [self.inspectorOverlay viewWithTag:500];
  UIView *toolbar = panel ? [panel viewWithTag:502] : nil;
  NSString *selHex = toolbar ? objc_getAssociatedObject(toolbar, "selHex") : nil;
  NSNumber *selOffset = toolbar ? objc_getAssociatedObject(toolbar, "selOffset") : nil;

  uint64_t offset = selOffset ? [selOffset unsignedLongLongValue] : hit.offset;

  [self sendToRVAWithOffset:offset moduleName:hit.imageName hex:selHex];
}

#pragma mark - Send to RVA (Save Dialog)

- (void)onOpenARMConverter {
  NSURL *url = [NSURL URLWithString:@"https://armconverter.com"];
  [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)sendToRVAWithOffset:(uint64_t)offset moduleName:(NSString *)moduleName hex:(NSString *)hex {
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  NSString *currentBid = engine.currentBundleID;

  uint64_t base = [engine findModuleBaseAddress:moduleName];
  NSString *detectedOrigHex = nil;
  if (base > 0) {
    NSString *cleanHex = [[[hex stringByReplacingOccurrencesOfString:@" " withString:@""] uppercaseString]
                           stringByReplacingOccurrencesOfString:@"0X" withString:@""];
    NSUInteger byteLen = cleanHex.length / 2;
    if (byteLen > 0) {
      uint64_t absAddr = base + offset;
      NSData *origData = [engine readRawMemory:absAddr length:byteLen];
      if (origData && origData.length == byteLen) {
        detectedOrigHex = [engine hexStringFromData:origData];
      }
    }
  }

  VMRVAPatch *existingPatch = nil;
  for (VMRVAPatch *p in engine.rvaPatches) {
    BOOL bidMatch = (!p.bundleID || [p.bundleID isEqualToString:currentBid]);
    if (bidMatch && [p.moduleName isEqualToString:moduleName] && p.offset == offset) {
      existingPatch = p;
      break;
    }
  }
  if (existingPatch && existingPatch.isOn && existingPatch.originalHex.length > 0) {
    detectedOrigHex = existingPatch.originalHex;
  }


  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Title_Save_Patch")
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];

  NSString *defaultNote = existingPatch ? existingPatch.note
      : [NSString stringWithFormat:@"%@ + 0x%llX", moduleName, offset];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = defaultNote;
    tf.placeholder = TR(@"Placeholder_Note");
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
    l.text = TR(@"Lock_Label_Note");
    l.font = [UIFont systemFontOfSize:12];
    tf.leftView = l;
    tf.leftViewMode = UITextFieldViewModeAlways;
  }];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = hex ?: @"";
    tf.placeholder = TR(@"RVA_Patch_Hex_Placeholder");
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
    l.text = TR(@"RVA_Modify_Label");
    l.font = [UIFont systemFontOfSize:12];
    l.textColor = [UIColor systemGreenColor];
    tf.leftView = l;
    tf.leftViewMode = UITextFieldViewModeAlways;
  }];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = detectedOrigHex ?: @"";
    tf.placeholder = TR(@"RVA_Original_Hex_Placeholder");
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
    l.text = TR(@"RVA_Origin_Label");
    l.font = [UIFont systemFontOfSize:12];
    l.textColor = [UIColor systemRedColor];
    tf.leftView = l;
    tf.leftViewMode = UITextFieldViewModeAlways;
  }];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = existingPatch.author ?: TR(@"Placeholder_Author_Default");
    tf.placeholder = TR(@"Placeholder_Author");
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
    l.text = TR(@"Label_Author");
    l.font = [UIFont systemFontOfSize:12];
    tf.leftView = l;
    tf.leftViewMode = UITextFieldViewModeAlways;

  }];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm")
    style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
      NSString *note = alert.textFields[0].text.length > 0 ? alert.textFields[0].text : defaultNote;
      NSString *finalPatchHex = alert.textFields[1].text;
      NSString *finalOrigHex = alert.textFields[2].text;
      NSString *author = alert.textFields[3].text.length > 0 ? alert.textFields[3].text : TR(@"Placeholder_Author_Default");

      if (finalPatchHex.length == 0 || finalOrigHex.length == 0) return;

      NSString *appName = nil;
      NSString *appVersion = nil;
      if (currentBid.length > 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id proxy = [NSClassFromString(@"LSApplicationProxy")
            performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:")
                 withObject:currentBid];
        if (proxy) {
          appName = [proxy performSelector:NSSelectorFromString(@"localizedName")];
          appVersion = [proxy performSelector:NSSelectorFromString(@"shortVersionString")];
        }
#pragma clang diagnostic pop
      }

      VMRVAPatch *currentExisting = nil;
      NSInteger currentIndex = NSNotFound;
      for (NSInteger i = 0; i < (NSInteger)engine.rvaPatches.count; i++) {
        VMRVAPatch *p = engine.rvaPatches[i];
        BOOL bidMatch = (!p.bundleID || [p.bundleID isEqualToString:currentBid]);
        if (bidMatch && [p.moduleName isEqualToString:moduleName] && p.offset == offset) {
          currentExisting = p;
          currentIndex = i;
          break;
        }
      }

      if (currentExisting && currentIndex != NSNotFound) {

        VMRVAPatch *patch = [[VMRVAPatch alloc] init];
        patch.moduleName = moduleName;
        patch.offset = offset;
        patch.patchHex = finalPatchHex;
        patch.originalHex = finalOrigHex;
        patch.note = note;
        patch.author = author;
        patch.isImported = currentExisting.isImported;
        patch.bundleID = currentBid;
        patch.isOn = currentExisting.isOn;
        patch.createdAt = currentExisting.createdAt;
        patch.appName = appName;
        patch.appVersion = appVersion;
        [engine.rvaPatches replaceObjectAtIndex:currentIndex withObject:patch];
      } else {

        VMRVAPatch *patch = [[VMRVAPatch alloc] init];
        patch.moduleName = moduleName;
        patch.offset = offset;
        patch.patchHex = finalPatchHex;
        patch.originalHex = finalOrigHex;
        patch.isOn = NO;
        patch.note = note;
        patch.author = author;
        patch.isImported = NO;
        patch.bundleID = currentBid;
        patch.createdAt = [[NSDate date] timeIntervalSince1970] + 0.001;
        patch.appName = appName;
        patch.appVersion = appVersion;
        [engine.rvaPatches addObject:patch];
      }

      [engine saveRVAPatches];
      [self showToast:TR(@"Alert_Success")];
  }]];

  void (^presentBlock)(void) = ^{
    [self presentViewController:alert animated:YES completion:nil];
  };
  if (self.presentedViewController) {
    [self.presentedViewController dismissViewControllerAnimated:NO completion:presentBlock];
  } else {
    presentBlock();
  }
}

#pragma mark - Toast

- (void)showToast:(NSString *)msg {
    VMMemoryShowFeedback(self, msg);
}

@end
