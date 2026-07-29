#import "../main/VMModifierViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../main/VMLockListViewController.h"
#import "../memory/VMHexEditorViewController.h"
#import "../memory/VMMemoryActionSheet.h"
#import "../memory/VMMemoryBrowserViewController.h"
#import "../pointer/VMPointerSearchViewController.h"
#import "include/VMFavoriteManager.h"
#import "include/VMIconHelper.h"
#import "include/VMLocalization.h"
#import "include/VMLockEngine.h"
#import "include/VMLockManager.h"
#import "include/VMMemoryEngine.h"
#include <sys/sysctl.h>
extern "C" int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
#define TR(key) ([[VMLocalization shared] localizedString:key])
@interface VMModifierViewController () <
    UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property(nonatomic, strong) UIStackView *headerStackView;
@property(nonatomic, strong) UIView *controlPanel;
@property(nonatomic, strong) UIView *toolbarContainer;
@property(nonatomic, strong) UIView *filterPanelView;
@property(nonatomic, strong) UIButton *btnFilterToggle;
@property(nonatomic, strong) UITextField *tfFilter1;
@property(nonatomic, strong) UITextField *tfFilter2;
@property(nonatomic, strong) UISegmentedControl *segFilterMode;
@property(nonatomic, strong) UIStackView *toolbarStackView;
@property(nonatomic, strong) UIButton *btnCloseBatch;
@property(nonatomic, strong) UITextField *inputField;
@property(nonatomic, strong) UIButton *searchBtn;
@property(nonatomic, strong) UIButton *nearbyBtn;
@property(nonatomic, strong) UIButton *resetBtn;
@property(nonatomic, strong) UISegmentedControl *dataTypeSegment;
@property(nonatomic, strong) UISegmentedControl *searchModeSegment;
@property(nonatomic, strong) UISegmentedControl *fuzzySegRow1;
@property(nonatomic, strong) UISegmentedControl *fuzzySegRow2;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UILabel *fuzzyHintLabel;
@property(nonatomic, assign) BOOL isNextScan;
@property(nonatomic, assign) BOOL shouldAutoFocusInput;
@property(nonatomic, assign) BOOL isMultiSelectMode;
@property(nonatomic, assign) BOOL isGlobalSelectAll;
@property(nonatomic, strong) NSMutableArray<VMScanResultItem *> *selectedItems;
@property(nonatomic, strong) NSMutableArray<VMScanResultItem *> *pinnedResults;
@property(nonatomic, assign) int lastAttachedPID;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *visitedMemSet;
@property(nonatomic, strong) NSMutableSet<NSNumber *> *visitedHexSet;
@property(nonatomic, strong) UIButton *btnNearby;
@property(nonatomic, strong) UIButton *btnReset;
@property(nonatomic, strong) UIButton *btnFilter;
@property(nonatomic, strong) UIButton *btnBatch;
@property(nonatomic, strong) UIButton *btnRefresh;
@property(nonatomic, strong) UIVisualEffectView *floatingBatchBar;
@property(nonatomic, strong) NSLayoutConstraint *batchBarBottomConstraint;
@property(nonatomic, strong)
    UIStackView *batchStackView; 
@property(nonatomic, assign) BOOL isScanning;

@property(nonatomic, strong) UIVisualEffectView *floatingToolBar;
@property(nonatomic, strong) NSLayoutConstraint *toolBarTopConstraint;
@property(nonatomic, strong) UIStackView *toolRowInHeader; 
@property(nonatomic, assign) BOOL isToolBarVisible;
@property(nonatomic, strong) UIStackView *headerMainStack;
@property(nonatomic, strong)
    NSMutableDictionary<NSNumber *, NSString *> *inputHistory;
@property(nonatomic, assign) NSInteger previousModeIndex;
@property(nonatomic, strong) UIActivityIndicatorView *btnSpinner;
@property(nonatomic, assign) BOOL isFuzzyLocked; 
@property(nonatomic, assign) NSInteger fuzzySearchCount; 
@end
@implementation VMModifierViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.navigationItem.title = TR(@"Tab_Mod");
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

  self.pinnedResults = [NSMutableArray array];

  self.lastAttachedPID = [VMMemoryEngine shared].targetPid;

  self.visitedMemSet = [NSMutableSet set];
  self.visitedHexSet = [NSMutableSet set];

  self.isScanning = NO;

  self.inputHistory = [NSMutableDictionary dictionary];
  self.previousModeIndex = self.searchModeSegment.selectedSegmentIndex;

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(handleReset)
             name:@"VMProcessChangedNotification"
           object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(onDidViewMemory:)
                                               name:@"VM_DidViewMemory"
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(onDidViewHex:)
                                               name:@"VM_DidViewHex"
                                             object:nil];

  UIBarButtonItem *jumpBtn = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"arrow.turn.down.right"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(showJumpMenu)];
  self.navigationItem.rightBarButtonItems = @[ jumpBtn ];
  [self restoreTimelineNavigationButton];

  self.selectedItems = [NSMutableArray array];
  [self setupUI];
  [self modeChanged];

  [self updateButtonStates];

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(handleReset)
             name:@"VMProcessChangedNotification"
           object:nil];

  if (self.isPointerSearchMode) {
    NSUInteger depth = [VMMemoryEngine shared].sessionStack.count;
    self.title = [NSString
        stringWithFormat:TR(@"Ptr_Search_Lv_Title"), (unsigned long)depth];

    self.navigationItem.leftBarButtonItems = nil;

    self.dataTypeSegment.selectedSegmentIndex = 3;
    self.dataTypeSegment.enabled = NO;
  }
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)restoreTimelineNavigationButton {
  if (self.isPointerSearchMode) {
    self.navigationItem.leftBarButtonItem = nil;
    return;
  }

  UIImage *timelineImage =
      [VMIconHelper compatibleSystemImageNamed:@"clock.arrow.circlepath"];
  UIBarButtonItem *timelineBtn = nil;
  if (timelineImage) {
    timelineBtn = [[UIBarButtonItem alloc] initWithImage:timelineImage
                                                   style:UIBarButtonItemStylePlain
                                                  target:self
                                                  action:@selector(showTimelineSheet)];
  } else {
    timelineBtn = [[UIBarButtonItem alloc] initWithTitle:TR(@"Timeline_Nav_Button")
                                                   style:UIBarButtonItemStylePlain
                                                  target:self
                                                  action:@selector(showTimelineSheet)];
  }
  self.navigationItem.leftBarButtonItem = timelineBtn;
}

- (void)onDidViewMemory:(NSNotification *)note {
  NSNumber *addr = note.object;
  [self.visitedMemSet addObject:addr];
  [self.tableView reloadData];
}

- (void)onDidViewHex:(NSNotification *)note {
  NSNumber *addr = note.object;
  [self.visitedHexSet addObject:addr];
  [self.tableView reloadData];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updateTableHeaderHeight:self.tableView.tableHeaderView];

  [self updateBatchBarStyle];
  
  [self.view bringSubviewToFront:self.floatingToolBar];
  [self.view bringSubviewToFront:self.floatingBatchBar];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  if (self.initialSearchVal) {
    self.searchModeSegment.selectedSegmentIndex = self.initialSearchMode;
    [self modeChanged];

    self.dataTypeSegment.selectedSegmentIndex = 3;
    [self dataTypeChanged];

    self.inputField.text = self.initialSearchVal;

    [[VMMemoryEngine shared] clearSession];

    [self handleSearch];

    self.initialSearchVal = nil;
  }

  if (self.shouldAutoFocusInput) {
    if (!self.inputField.hidden && self.inputField.enabled) {
      [self.inputField becomeFirstResponder];
    }
    self.shouldAutoFocusInput = NO;
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [[VMMemoryEngine shared] switchContext:@"mod"];
  int currentPid = [VMMemoryEngine shared].targetPid;

  if (currentPid != self.lastAttachedPID) {

    [self handleReset];
    self.lastAttachedPID = currentPid;
  }

  if (!self.isPointerSearchMode) {
    [self.tableView reloadData];
    [self updateResultInfo];
    [self updateEmptyState];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  if (self.isMovingFromParentViewController) {
    if (self.isPointerSearchMode) {
      [[VMMemoryEngine shared] restorePreviousSession];
    }
  }
}

- (void)setupUI {
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  self.tableView = [[UITableView alloc] initWithFrame:CGRectZero
                                                style:UITableViewStylePlain];
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  self.tableView.backgroundColor = [UIColor clearColor];

  self.tableView.allowsMultipleSelectionDuringEditing = YES;

  if (@available(iOS 15.0, *)) {
    self.tableView.sectionHeaderTopPadding = 0;
  }

  [self.view addSubview:self.tableView];

  UIBlurEffect *blur =
      [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
  self.floatingBatchBar = [[UIVisualEffectView alloc] initWithEffect:blur];
  self.floatingBatchBar.translatesAutoresizingMaskIntoConstraints = NO;
  self.floatingBatchBar.layer.cornerRadius = 12;
  self.floatingBatchBar.clipsToBounds = YES;
  self.floatingBatchBar.hidden = YES;
  self.floatingBatchBar.alpha = 0;

  self.floatingBatchBar.userInteractionEnabled = YES;
  [self.view addSubview:self.floatingBatchBar];
  [self.view bringSubviewToFront:self.floatingBatchBar];

  [self setupFloatingToolBar];

  [self setupFloatingBatchContent];
  UILayoutGuide *g = self.view.safeAreaLayoutGuide;

  [NSLayoutConstraint activateConstraints:@[
    [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [self.tableView.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor],
    [self.tableView.leadingAnchor constraintEqualToAnchor:g.leadingAnchor],
    [self.tableView.trailingAnchor constraintEqualToAnchor:g.trailingAnchor],

    [self.floatingBatchBar.leadingAnchor constraintEqualToAnchor:g.leadingAnchor
                                                        constant:20],
    [self.floatingBatchBar.trailingAnchor
        constraintEqualToAnchor:g.trailingAnchor
                       constant:-20],
    [self.floatingBatchBar.heightAnchor constraintEqualToConstant:60]
  ]];

  self.batchBarBottomConstraint =
      [self.floatingBatchBar.bottomAnchor constraintEqualToAnchor:g.bottomAnchor
                                                         constant:150];
  self.batchBarBottomConstraint.active = YES;
  UIView *header = [self buildModernHeader];
  [self updateTableHeaderHeight:header];

  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];

  [self updateButtonStates];
}

- (UIView *)buildModernHeader {
  UIView *wrapper = [[UIView alloc]
      initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 300)];
  wrapper.backgroundColor = [UIColor clearColor];

  self.headerMainStack = [[UIStackView alloc] init];
  self.headerMainStack.axis = UILayoutConstraintAxisVertical;
  self.headerMainStack.spacing = 12;
  self.headerMainStack.translatesAutoresizingMaskIntoConstraints = NO;
  [wrapper addSubview:self.headerMainStack];

  [NSLayoutConstraint activateConstraints:@[
    [self.headerMainStack.topAnchor constraintEqualToAnchor:wrapper.topAnchor
                                                   constant:12],
    [self.headerMainStack.leadingAnchor
        constraintEqualToAnchor:wrapper.leadingAnchor
                       constant:12],
    [self.headerMainStack.trailingAnchor
        constraintEqualToAnchor:wrapper.trailingAnchor
                       constant:-12],
    [self.headerMainStack.bottomAnchor
        constraintEqualToAnchor:wrapper.bottomAnchor
                       constant:-12]
  ]];

  self.searchModeSegment = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Mod_Mode_Exact"), TR(@"Mod_Mode_Fuzzy"), TR(@"Mod_Mode_Group")
  ]];
  self.searchModeSegment.selectedSegmentIndex = 0;
  [self.searchModeSegment addTarget:self
                             action:@selector(modeChanged)
                   forControlEvents:UIControlEventValueChanged];
  [self.searchModeSegment.heightAnchor constraintEqualToConstant:32].active =
      YES;
  [self.headerMainStack addArrangedSubview:self.searchModeSegment];
  
  UIStackView *searchRow = [[UIStackView alloc] init];
  searchRow.spacing = 6;
  [searchRow.heightAnchor constraintEqualToConstant:40].active = YES;

  self.inputField = [[UITextField alloc] init];
  self.inputField.borderStyle = UITextBorderStyleRoundedRect;
  self.inputField.placeholder = TR(@"Mod_Input_Value_Placeholder");
  self.inputField.backgroundColor =
      [UIColor secondarySystemGroupedBackgroundColor];
  self.inputField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
  self.inputField.delegate = self;
  self.inputField.returnKeyType = UIReturnKeySearch;
  [self addDoneButtonTo:self.inputField];

  self.searchBtn = [self createTextOnlyBtn:TR(@"Common_Search")
                                     color:[UIColor systemBlueColor]
                                       sel:@selector(handleSearch)];
  [self.searchBtn.widthAnchor constraintEqualToConstant:70].active = YES;

  [searchRow addArrangedSubview:self.inputField];
  [searchRow addArrangedSubview:self.searchBtn];
  [self.headerMainStack addArrangedSubview:searchRow];

  self.dataTypeSegment = [[UISegmentedControl alloc]
      initWithItems:@[ @"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str" ]];
  self.dataTypeSegment.selectedSegmentIndex = 2; 
  [self.dataTypeSegment addTarget:self
                           action:@selector(dataTypeChanged)
                 forControlEvents:UIControlEventValueChanged];
  [self.dataTypeSegment.heightAnchor constraintEqualToConstant:32].active = YES;
  
  [self.dataTypeSegment setTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:11]} forState:UIControlStateNormal];
  [self.headerMainStack addArrangedSubview:self.dataTypeSegment];

  self.fuzzySegRow1 = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Fuz_Increased"), TR(@"Fuz_Decreased"), TR(@"Fuz_Unchanged"),
    TR(@"Fuz_Changed")
  ]];
  self.fuzzySegRow1.hidden = YES;
  [self.fuzzySegRow1 addTarget:self
                        action:@selector(fuzzyRow1Selected:)
              forControlEvents:UIControlEventValueChanged];
  [self.headerMainStack addArrangedSubview:self.fuzzySegRow1];

  self.fuzzySegRow2 = [[UISegmentedControl alloc]
      initWithItems:@[ TR(@"Fuz_Inc_Val"), TR(@"Fuz_Dec_Val") ]];
  self.fuzzySegRow2.hidden = YES;
  [self.fuzzySegRow2 addTarget:self
                        action:@selector(fuzzyRow2Selected:)
              forControlEvents:UIControlEventValueChanged];
  [self.headerMainStack addArrangedSubview:self.fuzzySegRow2];

  self.fuzzyHintLabel = [[UILabel alloc] init];
  self.fuzzyHintLabel.font = [UIFont systemFontOfSize:11];
  self.fuzzyHintLabel.textColor = [UIColor systemGrayColor];
  self.fuzzyHintLabel.textAlignment = NSTextAlignmentCenter;
  self.fuzzyHintLabel.hidden = YES;
  [self.headerMainStack addArrangedSubview:self.fuzzyHintLabel];

  UIStackView *toolRow = [[UIStackView alloc] init];
  toolRow.axis = UILayoutConstraintAxisHorizontal;
  toolRow.distribution = UIStackViewDistributionFillEqually;
  toolRow.spacing = 6;
  [toolRow.heightAnchor constraintEqualToConstant:36].active = YES;
  toolRow.tag = 1001; 
  self.toolRowInHeader = toolRow; 

  self.btnRefresh = [self createTextOnlyBtn:TR(@"Mod_Results_Refreshed")
                                      color:[UIColor systemTealColor]
                                        sel:@selector(doRefreshValues)];

  self.btnNearby = [self createTextOnlyBtn:TR(@"Nearby_Btn")
                                     color:[UIColor systemPurpleColor]
                                       sel:@selector(handleNearbySearch)];
  self.btnFilter = [self createTextOnlyBtn:TR(@"Filter_Btn")
                                     color:[UIColor systemOrangeColor]
                                       sel:@selector(toggleFilterPanel)];
  self.btnBatch = [self createTextOnlyBtn:TR(@"Btn_Batch_Select")
                                    color:[UIColor systemGreenColor]
                                      sel:@selector(toggleBatchMode)];
  self.btnReset = [self createTextOnlyBtn:TR(@"Mod_Reset")
                                    color:[UIColor systemRedColor]
                                      sel:@selector(handleReset)];

  [toolRow addArrangedSubview:self.btnRefresh];
  [toolRow addArrangedSubview:self.btnNearby];
  [toolRow addArrangedSubview:self.btnFilter];
  [toolRow addArrangedSubview:self.btnBatch];
  [toolRow addArrangedSubview:self.btnReset];
  [self.headerMainStack addArrangedSubview:toolRow];

  self.filterPanelView = [self buildFilterPanel];
  self.filterPanelView.hidden = YES;
  [self.headerMainStack addArrangedSubview:self.filterPanelView];

  self.statusLabel = [[UILabel alloc] init];
  self.statusLabel.text = TR(@"Mod_Status_Ready");
  self.statusLabel.font = [UIFont systemFontOfSize:12
                                            weight:UIFontWeightMedium];
  self.statusLabel.textColor = [UIColor secondaryLabelColor];
  self.statusLabel.textAlignment = NSTextAlignmentCenter;
  [self.headerMainStack addArrangedSubview:self.statusLabel];

  return wrapper;
}

- (UIButton *)createTextOnlyBtn:(NSString *)title
                          color:(UIColor *)color
                            sel:(SEL)sel {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];

  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *conf =
        [UIButtonConfiguration filledButtonConfiguration];
    conf.baseBackgroundColor = [color colorWithAlphaComponent:0.15];
    conf.baseForegroundColor = color;
    conf.title = title;
    conf.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    conf.contentInsets = NSDirectionalEdgeInsetsMake(0, 4, 0, 4);

    conf.titleTextAttributesTransformer =
        ^NSDictionary<NSAttributedStringKey, id> *_Nonnull(
            NSDictionary<NSAttributedStringKey, id> *_Nonnull incoming) {
      NSMutableDictionary *outgoing = [incoming mutableCopy];
      outgoing[NSFontAttributeName] =
          [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
      return outgoing;
    };
    btn.configuration = conf;
  } else {
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:color forState:UIControlStateNormal];
    btn.backgroundColor = [color colorWithAlphaComponent:0.15];
    btn.layer.cornerRadius = 8;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  }

  [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  return btn;
}

- (UIView *)buildFilterPanel {
  UIView *panel = [[UIView alloc] init];
  panel.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
  panel.layer.cornerRadius = 10;
  panel.clipsToBounds = YES;

  self.segFilterMode = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Filter_Less"), TR(@"Filter_Greater"), TR(@"Filter_Between")
  ]];
  self.segFilterMode.translatesAutoresizingMaskIntoConstraints = NO;
  self.segFilterMode.selectedSegmentIndex = 2;
  [self.segFilterMode addTarget:self
                         action:@selector(filterModeChanged)
               forControlEvents:UIControlEventValueChanged];
  [panel addSubview:self.segFilterMode];

  UIStackView *inputRow = [[UIStackView alloc] init];
  inputRow.axis = UILayoutConstraintAxisHorizontal;
  inputRow.spacing = 8;
  inputRow.translatesAutoresizingMaskIntoConstraints = NO;
  [panel addSubview:inputRow];

  self.tfFilter1 = [self createSmallTF:TR(@"Filter_Input_Min")];
  self.tfFilter2 = [self createSmallTF:TR(@"Filter_Input_Max")];
  UIButton *btnApply = [UIButton buttonWithType:UIButtonTypeSystem];
  [btnApply setTitle:TR(@"Filter_Apply") forState:UIControlStateNormal];
  btnApply.backgroundColor = [UIColor systemOrangeColor];
  [btnApply setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  btnApply.layer.cornerRadius = 6;
  [btnApply.widthAnchor constraintEqualToConstant:70].active = YES;
  [btnApply addTarget:self
                action:@selector(applyFilter)
      forControlEvents:UIControlEventTouchUpInside];

  [inputRow addArrangedSubview:self.tfFilter1];
  [inputRow addArrangedSubview:self.tfFilter2];
  [inputRow addArrangedSubview:btnApply];
  [self.tfFilter1.widthAnchor
      constraintEqualToAnchor:self.tfFilter2.widthAnchor]
      .active = YES;

  [NSLayoutConstraint activateConstraints:@[
    [panel.heightAnchor constraintEqualToConstant:90],
    [self.segFilterMode.topAnchor constraintEqualToAnchor:panel.topAnchor
                                                 constant:8],
    [self.segFilterMode.leadingAnchor
        constraintEqualToAnchor:panel.leadingAnchor
                       constant:8],
    [self.segFilterMode.trailingAnchor
        constraintEqualToAnchor:panel.trailingAnchor
                       constant:-8],
    [inputRow.topAnchor constraintEqualToAnchor:self.segFilterMode.bottomAnchor
                                       constant:8],
    [inputRow.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor
                                           constant:8],
    [inputRow.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor
                                            constant:-8],
    [inputRow.heightAnchor constraintEqualToConstant:32]
  ]];

  [self filterModeChanged];
  return panel;
}

- (void)setupFloatingToolBar {
  UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
  self.floatingToolBar = [[UIVisualEffectView alloc] initWithEffect:blur];
  self.floatingToolBar.translatesAutoresizingMaskIntoConstraints = NO;
  self.floatingToolBar.layer.cornerRadius = 10;
  self.floatingToolBar.clipsToBounds = YES;
  self.floatingToolBar.hidden = YES;
  self.floatingToolBar.alpha = 0;
  self.floatingToolBar.userInteractionEnabled = YES;
  
  [self.view addSubview:self.floatingToolBar];
  [self.view bringSubviewToFront:self.floatingToolBar];
  
  UILayoutGuide *g = self.view.safeAreaLayoutGuide;
  
  [NSLayoutConstraint activateConstraints:@[
    [self.floatingToolBar.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:12],
    [self.floatingToolBar.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-12],
    [self.floatingToolBar.heightAnchor constraintEqualToConstant:44]
  ]];
  
  self.toolBarTopConstraint = [self.floatingToolBar.topAnchor constraintEqualToAnchor:g.topAnchor constant:-60];
  self.toolBarTopConstraint.active = YES;
  
  [self setupFloatingToolBarContent];
  
  self.isToolBarVisible = NO;
}

- (void)setupFloatingToolBarContent {
  UIView *contentView = self.floatingToolBar.contentView;
  
  UIStackView *stack = [[UIStackView alloc] init];
  stack.axis = UILayoutConstraintAxisHorizontal;
  stack.distribution = UIStackViewDistributionFillEqually;
  stack.spacing = 6;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  [contentView addSubview:stack];
  
  [NSLayoutConstraint activateConstraints:@[
    [stack.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:4],
    [stack.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-4],
    [stack.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:8],
    [stack.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-8]
  ]];
  
  UIButton *btnRefresh = [self createFloatingToolBtn:TR(@"Mod_Results_Refreshed")
                                               color:[UIColor systemTealColor]
                                                 sel:@selector(doRefreshValues)];
  UIButton *btnNearby = [self createFloatingToolBtn:TR(@"Nearby_Btn")
                                              color:[UIColor systemPurpleColor]
                                                sel:@selector(handleNearbySearch)];
  UIButton *btnFilter = [self createFloatingToolBtn:TR(@"Filter_Btn")
                                              color:[UIColor systemOrangeColor]
                                                sel:@selector(toggleFilterPanel)];
  UIButton *btnBatch = [self createFloatingToolBtn:TR(@"Btn_Batch_Select")
                                             color:[UIColor systemGreenColor]
                                               sel:@selector(toggleBatchMode)];
  UIButton *btnReset = [self createFloatingToolBtn:TR(@"Mod_Reset")
                                             color:[UIColor systemRedColor]
                                               sel:@selector(handleReset)];
  
  btnRefresh.tag = 2001;
  btnNearby.tag = 2002;
  btnFilter.tag = 2003;
  btnBatch.tag = 2004;
  btnReset.tag = 2005;
  
  [stack addArrangedSubview:btnRefresh];
  [stack addArrangedSubview:btnNearby];
  [stack addArrangedSubview:btnFilter];
  [stack addArrangedSubview:btnBatch];
  [stack addArrangedSubview:btnReset];
}

- (UIButton *)createFloatingToolBtn:(NSString *)title
                              color:(UIColor *)color
                                sel:(SEL)sel {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  
  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *conf = [UIButtonConfiguration filledButtonConfiguration];
    conf.baseBackgroundColor = [color colorWithAlphaComponent:0.15];
    conf.baseForegroundColor = color;
    conf.title = title;
    conf.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    conf.contentInsets = NSDirectionalEdgeInsetsMake(0, 2, 0, 2);
    
    conf.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *_Nonnull(
        NSDictionary<NSAttributedStringKey, id> *_Nonnull incoming) {
      NSMutableDictionary *outgoing = [incoming mutableCopy];
      outgoing[NSFontAttributeName] = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
      return outgoing;
    };
    btn.configuration = conf;
  } else {
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:color forState:UIControlStateNormal];
    btn.backgroundColor = [color colorWithAlphaComponent:0.15];
    btn.layer.cornerRadius = 6;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
  }
  
  [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  return btn;
}

- (void)setupFloatingBatchContent {
  UIView *contentView = self.floatingBatchBar.contentView;

  self.batchStackView = [[UIStackView alloc] init];
  self.batchStackView.axis = UILayoutConstraintAxisHorizontal;
  self.batchStackView.alignment = UIStackViewAlignmentCenter;
  
  self.batchStackView.distribution = UIStackViewDistributionFill;
  self.batchStackView.translatesAutoresizingMaskIntoConstraints = NO;
  [contentView addSubview:self.batchStackView];

  [self.batchStackView.centerYAnchor
      constraintEqualToAnchor:contentView.centerYAnchor]
      .active = YES;
  [self.batchStackView.heightAnchor
      constraintEqualToAnchor:contentView.heightAnchor]
      .active = YES;

  [self.batchStackView.leadingAnchor
      constraintEqualToAnchor:contentView.leadingAnchor
                     constant:15]
      .active = YES;
  [self.batchStackView.trailingAnchor
      constraintEqualToAnchor:contentView.trailingAnchor
                     constant:-15]
      .active = YES;

  UIButton *btnAll = [self createIconOnlyBtn:@"checkmark.circle"
                                       color:[UIColor systemBlueColor]
                                         sel:@selector(batchSelectAll)];
  btnAll.tag = 101;

  UIButton *btnRange =
      [self createIconOnlyBtn:@"rectangle.dashed"
                        color:[UIColor systemPurpleColor]
                          sel:@selector(batchRangeSelectAction)];
  
  UIButton *btnCopyAddr = [self createIconOnlyBtn:@"doc.on.doc"
                                            color:[UIColor systemGrayColor]
                                              sel:@selector(batchCopyAddressAction)];
  
  UIButton *btnLock = [self createIconOnlyBtn:@"lock.fill"
                                        color:[UIColor systemGreenColor]
                                          sel:@selector(batchLockAction)];
  UIButton *btnFav = [self createIconOnlyBtn:@"star.fill"
                                       color:[UIColor systemOrangeColor]
                                         sel:@selector(batchFavAction)];
  UIButton *btnMod = [self createIconOnlyBtn:@"pencil"
                                       color:[UIColor systemIndigoColor]
                                         sel:@selector(batchModifyAction)];
  UIButton *btnDel =
      [self createIconOnlyBtn:@"trash.fill"
                        color:[UIColor systemRedColor]
                          sel:@selector(batchDeleteResultsAction)];

  [self.batchStackView addArrangedSubview:btnAll];
  [self.batchStackView addArrangedSubview:btnRange];
  [self.batchStackView addArrangedSubview:btnCopyAddr];
  [self.batchStackView addArrangedSubview:btnLock];
  [self.batchStackView addArrangedSubview:btnFav];
  [self.batchStackView addArrangedSubview:btnMod];
  [self.batchStackView addArrangedSubview:btnDel];
}

- (UIButton *)createIconOnlyBtn:(NSString *)iconName
                          color:(UIColor *)color
                            sel:(SEL)sel {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];

  UIImage *iconImage = [VMIconHelper compatibleSystemImageNamed:iconName];

  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *conf =
        [UIButtonConfiguration plainButtonConfiguration];
    conf.baseForegroundColor = color;

    conf.image = iconImage;

    UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration
        configurationWithPointSize:26
                            weight:UIImageSymbolWeightSemibold
                             scale:UIImageSymbolScaleMedium];
    conf.preferredSymbolConfigurationForImage = sym;

    conf.contentInsets = NSDirectionalEdgeInsetsMake(10, 10, 10, 10);

    btn.configuration = conf;
  } else {
    UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration
        configurationWithPointSize:26
                            weight:UIImageSymbolWeightSemibold];
    UIImage *configuredImage =
        [iconImage imageByApplyingSymbolConfiguration:sym];
    [btn setImage:configuredImage forState:UIControlStateNormal];
    btn.tintColor = color;
    btn.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
  }

  [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  return btn;
}

- (void)updateButtonStates {
  NSUInteger resultCount = [VMMemoryEngine shared].resultCount;
  BOOL hasResults = (resultCount > 0);

  BOOL canOperate = hasResults && !self.isScanning;

  self.btnRefresh.enabled = canOperate;
  self.btnRefresh.alpha = canOperate ? 1.0 : 0.5;

  self.btnNearby.enabled = canOperate;
  self.btnFilter.enabled = canOperate;
  self.btnBatch.enabled = canOperate;

  self.btnNearby.alpha = canOperate ? 1.0 : 0.5;
  self.btnFilter.alpha = canOperate ? 1.0 : 0.5;
  self.btnBatch.alpha = canOperate ? 1.0 : 0.5;

  self.btnReset.enabled =
      !self.isScanning && (hasResults || self.inputField.text.length > 0 || self.isFuzzyLocked);
  self.btnReset.alpha = self.btnReset.enabled ? 1.0 : 0.5;
  
  if (self.isToolBarVisible) {
    [self syncFloatingToolBarState];
  }
}

- (void)updateTableHeaderHeight:(UIView *)header {
  if (!header)
    return;

  CGFloat width = self.tableView.bounds.size.width;
  if (width <= 0)
    width = [UIScreen mainScreen].bounds.size.width;

  for (NSLayoutConstraint *c in header.constraints) {
    if (c.firstAttribute == NSLayoutAttributeWidth) {
      [header removeConstraint:c];
    }
  }

  NSLayoutConstraint *widthConstraint =
      [header.widthAnchor constraintEqualToConstant:width];
  widthConstraint.active = YES;

  [header setNeedsLayout];
  [header layoutIfNeeded];

  CGSize size =
      [header systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];

  widthConstraint.active = NO;

  CGRect frame = header.frame;
  frame.size.height = size.height;
  if (size.height == 0)
    frame.size.height = 100;
  header.frame = frame;

  self.tableView.tableHeaderView = header;
}

- (UIButton *)createButton:(NSString *)title
                     color:(UIColor *)color
                    action:(SEL)action {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  [btn setTitle:title forState:UIControlStateNormal];
  [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  btn.backgroundColor = color;
  btn.layer.cornerRadius = 8;
  btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
  [btn addTarget:self
                action:action
      forControlEvents:UIControlEventTouchUpInside];
  return btn;
}

- (void)modeChanged {
  [self.view endEditing:YES];

  NSInteger newMode = self.searchModeSegment.selectedSegmentIndex;

  if (self.inputField.text) {
    self.inputHistory[@(self.previousModeIndex)] = self.inputField.text;
  }

  NSString *cachedText = self.inputHistory[@(newMode)];
  self.inputField.text = cachedText ?: @"";

  self.previousModeIndex = newMode;
  
  BOOL isFuzzy = (newMode == 1);
  if (isFuzzy) {
    if (self.isNextScan) {
      self.fuzzySegRow1.hidden = NO;
      self.fuzzySegRow2.hidden = NO;
      self.fuzzyHintLabel.hidden = NO;
      [self fuzzyTypeChanged];
    } else {
      self.inputField.hidden = YES;
      self.fuzzySegRow1.hidden = YES;
      self.fuzzySegRow2.hidden = YES;
      self.fuzzyHintLabel.hidden = YES;
    }
  } else {
    self.inputField.hidden = NO;
    self.fuzzySegRow1.hidden = YES;
    self.fuzzySegRow2.hidden = YES;
    self.fuzzyHintLabel.hidden = YES;
    if (newMode == 2) {
      self.inputField.placeholder = TR(@"Mod_Hint_Group");
      self.inputField.keyboardType = UIKeyboardTypeASCIICapable;
    } else if (self.dataTypeSegment.selectedSegmentIndex == VMDataTypeString) {
      self.inputField.placeholder = TR(@"Mod_Input_Str");
      self.inputField.keyboardType = UIKeyboardTypeDefault;
    } else {
      self.inputField.placeholder = TR(@"Mod_Input_Value_Placeholder");
      self.inputField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    }
  }
  [self updateGroupHelpButtonState:(newMode == 2)];
  BOOL allowString = (newMode == 0);
  [self.dataTypeSegment setEnabled:allowString forSegmentAtIndex:VMDataTypeString];
  if (!allowString && self.dataTypeSegment.selectedSegmentIndex == VMDataTypeString) {
    self.dataTypeSegment.selectedSegmentIndex = VMDataTypeInt32;
  }
  [self.inputField reloadInputViews];

  [self updateTableHeaderHeight:self.tableView.tableHeaderView];
}

- (void)fuzzyTypeChanged {
  NSString *hintKey = @"";
  BOOL needsInput = NO;
  NSString *placeholderText = TR(@"Mod_Input_Value_Placeholder");
  if (self.fuzzySegRow1.selectedSegmentIndex != UISegmentedControlNoSegment) {
    NSInteger idx = self.fuzzySegRow1.selectedSegmentIndex;
    switch (idx) {
    case 0:
      hintKey = @"Fuz_Hint_Inc";
      break;
    case 1:
      hintKey = @"Fuz_Hint_Dec";
      break;
    case 2:
      hintKey = @"Fuz_Hint_Unc";
      break;
    case 3:
      hintKey = @"Fuz_Hint_Chg";
      break;
    }
    needsInput = NO;
  } else if (self.fuzzySegRow2.selectedSegmentIndex !=
             UISegmentedControlNoSegment) {
    NSInteger idx = self.fuzzySegRow2.selectedSegmentIndex;
    switch (idx) {
    case 0:
      hintKey = @"Fuz_Hint_Inc_Val";
      placeholderText = TR(@"Mod_Input_Val_Inc");
      needsInput = YES;
      break;
    case 1:
      hintKey = @"Fuz_Hint_Dec_Val";
      placeholderText = TR(@"Mod_Input_Val_Dec");
      needsInput = YES;
      break;
    }
  }
  self.fuzzyHintLabel.text = TR(hintKey);
  self.inputField.hidden = !needsInput;
  if (needsInput) {
    self.inputField.placeholder = placeholderText;
  }

  [self updateTableHeaderHeight:self.tableView.tableHeaderView];
}

- (void)fuzzyRow1Selected:(UISegmentedControl *)sender {
  self.fuzzySegRow2.selectedSegmentIndex = UISegmentedControlNoSegment;
  [self fuzzyTypeChanged];
  if ([self shouldPromptFuzzyRepeatForRow1]) {
    VMFilterMode filterMode = [self filterModeForFuzzyRow1Index:sender.selectedSegmentIndex];
    [self showFuzzyRepeatPickerForFilterMode:filterMode];
  }
}

- (void)fuzzyRow2Selected:(UISegmentedControl *)sender {
  self.fuzzySegRow1.selectedSegmentIndex = UISegmentedControlNoSegment;
  [self fuzzyTypeChanged];
}

- (BOOL)shouldPromptFuzzyRepeatForRow1 {
  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"fuzzyRepeatCustomEnabled"])
    return NO;
  if (self.searchModeSegment.selectedSegmentIndex != VMSearchModeFuzzy)
    return NO;
  if (!self.isNextScan || self.isScanning)
    return NO;
  if (self.fuzzySegRow1.selectedSegmentIndex == UISegmentedControlNoSegment)
    return NO;
  return YES;
}

- (VMFilterMode)filterModeForFuzzyRow1Index:(NSInteger)idx {
  if (idx == 0) return VMFilterModeIncreased;
  if (idx == 1) return VMFilterModeDecreased;
  if (idx == 2) return VMFilterModeUnchanged;
  return VMFilterModeChanged;
}

- (void)showFuzzyRepeatPickerForFilterMode:(VMFilterMode)filterMode {
  UIAlertController *sheet =
      [UIAlertController alertControllerWithTitle:TR(@"Fuz_Repeat_Title")
                                          message:TR(@"Fuz_Repeat_Message")
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  NSArray<NSNumber *> *counts = @[ @5, @10, @20, @30 ];
  for (NSNumber *num in counts) {
    [sheet addAction:[UIAlertAction
                         actionWithTitle:[NSString stringWithFormat:@"%@", num]
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                   [self executeFuzzyRepeatWithFilterMode:filterMode
                                                                    total:num.integerValue];
                                 }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Fuz_Repeat_Custom_Count")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self showFuzzyRepeatCustomInput:filterMode];
                                          }]];
  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction *a) {
                                            self.fuzzySegRow1.selectedSegmentIndex =
                                                UISegmentedControlNoSegment;
                                            [self fuzzyTypeChanged];
                                          }]];
  if (sheet.popoverPresentationController) {
    sheet.popoverPresentationController.sourceView = self.fuzzySegRow1;
    sheet.popoverPresentationController.sourceRect = self.fuzzySegRow1.bounds;
  }
  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showFuzzyRepeatCustomInput:(VMFilterMode)filterMode {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Fuz_Repeat_Custom_Count")
                                          message:TR(@"Fuz_Repeat_Message")
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Fuz_Repeat_Custom_Placeholder");
    tf.keyboardType = UIKeyboardTypeNumberPad;
    tf.text = @"5";
  }];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:^(UIAlertAction *a) {
                                            self.fuzzySegRow1.selectedSegmentIndex =
                                                UISegmentedControlNoSegment;
                                            [self fuzzyTypeChanged];
                                          }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            NSInteger total = alert.textFields.firstObject.text.integerValue;
                                            if (total < 1) total = 1;
                                            if (total > 100) total = 100;
                                            [self executeFuzzyRepeatWithFilterMode:filterMode
                                                                             total:total];
                                          }]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)beginFuzzyRepeatUIWithTotal:(NSInteger)total {
  self.isScanning = YES;
  self.view.userInteractionEnabled = NO;
  [self updateButtonStates];
  [self.searchBtn setTitle:@"" forState:UIControlStateNormal];
  self.searchBtn.enabled = NO;
  if (!self.btnSpinner) {
    self.btnSpinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.btnSpinner.color = [UIColor systemBlueColor];
  }
  self.btnSpinner.center = CGPointMake(self.searchBtn.bounds.size.width / 2,
                                       self.searchBtn.bounds.size.height / 2);
  [self.searchBtn addSubview:self.btnSpinner];
  [self.btnSpinner startAnimating];
  self.statusLabel.text = [NSString stringWithFormat:TR(@"Fuz_Repeat_Running"), 0L, (long)total];
}

- (void)endFuzzyRepeatUIWithCompleted:(NSInteger)completed
                                total:(NSInteger)total
                                count:(NSUInteger)count
                              success:(BOOL)success {
  [self.btnSpinner stopAnimating];
  [self.btnSpinner removeFromSuperview];
  self.searchBtn.enabled = YES;
  [self.searchBtn setTitle:TR(@"Mod_Search_Next") forState:UIControlStateNormal];
  self.isScanning = NO;
  self.view.userInteractionEnabled = YES;
  self.fuzzySegRow1.selectedSegmentIndex = UISegmentedControlNoSegment;
  [self updateButtonStates];
  [self.tableView reloadData];
  [self updateResultInfo];
  [self updateEmptyState];
  self.btnNearby.hidden = NO;
  self.fuzzySegRow1.hidden = NO;
  self.fuzzySegRow2.hidden = NO;
  self.fuzzyHintLabel.hidden = NO;
  BOOL enableUnchanged = (count <= 20000000);
  [self.fuzzySegRow1 setEnabled:enableUnchanged forSegmentAtIndex:2];
  [self fuzzyTypeChanged];
  [self updateTableHeaderHeight:self.tableView.tableHeaderView];

  NSString *msg = [NSString stringWithFormat:TR(@"Fuz_Repeat_Done"),
                                             (long)completed, (long)total];
  self.statusLabel.text = msg;
  [self showWeakToast:msg];
  UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
  [gen notificationOccurred:success ? UINotificationFeedbackTypeSuccess
                                    : UINotificationFeedbackTypeError];
}

- (void)executeFuzzyRepeatWithFilterMode:(VMFilterMode)filterMode total:(NSInteger)total {
  if (total < 1) total = 1;
  [self beginFuzzyRepeatUIWithTotal:total];
  [self runFuzzyRepeatStepWithFilterMode:filterMode
                                   total:total
                               completed:0
                               lastCount:[VMMemoryEngine shared].resultCount];
}

- (void)runFuzzyRepeatStepWithFilterMode:(VMFilterMode)filterMode
                                   total:(NSInteger)total
                               completed:(NSInteger)completed
                               lastCount:(NSUInteger)lastCount {
  if (completed >= total || lastCount == 0) {
    [self endFuzzyRepeatUIWithCompleted:completed
                                  total:total
                                  count:lastCount
                                success:(completed > 0 && lastCount > 0)];
    return;
  }

  NSUInteger currentCount = [VMMemoryEngine shared].resultCount;
  if (filterMode == VMFilterModeUnchanged && currentCount > 20000000) {
    [self endFuzzyRepeatUIWithCompleted:completed
                                  total:total
                                  count:currentCount
                                success:NO];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:TR(@"Alert_Warning")
                         message:TR(@"Fuzzy_Unchanged_Too_Many")
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    return;
  }

  self.statusLabel.text = [NSString stringWithFormat:TR(@"Fuz_Repeat_Running"),
                                                     (long)(completed + 1),
                                                     (long)total];
  VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
  [[VMMemoryEngine shared] fastFuzzyFilterWithMode:filterMode
                                         dataType:type
                                       completion:^(NSUInteger count, NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
      NSInteger nextCompleted = completed + 1;
      if (count > 0) {
        NSString *detail = [NSString stringWithFormat:@"%@ x%ld",
                                                       [self timelineTypeName:type],
                                                       (long)nextCompleted];
        [self captureTimelineTitle:[self timelineFilterTitle:filterMode]
                            detail:detail
                              type:type];
      }
      self.fuzzySearchCount++;
      if (self.fuzzySearchCount >= 2) {
        self.isFuzzyLocked = NO;
        [self.searchModeSegment setEnabled:YES forSegmentAtIndex:0];
        [self.searchModeSegment setEnabled:YES forSegmentAtIndex:2];
      }
      [self runFuzzyRepeatStepWithFilterMode:filterMode
                                       total:total
                                   completed:nextCompleted
                                   lastCount:count];
    });
  }];
}

- (void)setupToolbarAndFilter {
  self.toolbarContainer = [[UIView alloc] init];
  self.toolbarContainer.backgroundColor =
      [UIColor secondarySystemGroupedBackgroundColor];
  self.toolbarContainer.layer.cornerRadius = 12;
  self.toolbarContainer.layer.borderWidth = 0.5;
  if (@available(iOS 13.0, *)) {
    self.toolbarContainer.layer.borderColor = [UIColor separatorColor].CGColor;
  } else {
    self.toolbarContainer.layer.borderColor = [UIColor lightGrayColor].CGColor;
  }

  [self.headerStackView addArrangedSubview:self.toolbarContainer];

  UIStackView *mainToolbarStack = [[UIStackView alloc] init];
  mainToolbarStack.axis = UILayoutConstraintAxisVertical;
  mainToolbarStack.spacing = 8;
  mainToolbarStack.alignment = UIStackViewAlignmentFill;
  mainToolbarStack.translatesAutoresizingMaskIntoConstraints = NO;
  [self.toolbarContainer addSubview:mainToolbarStack];

  [NSLayoutConstraint activateConstraints:@[
    [mainToolbarStack.topAnchor
        constraintEqualToAnchor:self.toolbarContainer.topAnchor
                       constant:12],
    [mainToolbarStack.bottomAnchor
        constraintEqualToAnchor:self.toolbarContainer.bottomAnchor
                       constant:-12],
    [mainToolbarStack.leadingAnchor
        constraintEqualToAnchor:self.toolbarContainer.leadingAnchor
                       constant:12],
    [mainToolbarStack.trailingAnchor
        constraintEqualToAnchor:self.toolbarContainer.trailingAnchor
                       constant:-12]
  ]];

  UIView *row1 = [[UIView alloc] init];
  self.statusLabel = [[UILabel alloc] init];
  self.statusLabel.text = TR(@"Mod_Status_Ready");
  self.statusLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
  self.statusLabel.textColor = [UIColor labelColor];
  self.statusLabel.textAlignment = NSTextAlignmentCenter;
  self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [row1 addSubview:self.statusLabel];

  self.btnCloseBatch = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.btnCloseBatch setImage:[UIImage systemImageNamed:@"xmark.circle.fill"]
                      forState:UIControlStateNormal];
  self.btnCloseBatch.tintColor = [UIColor systemGrayColor];
  self.btnCloseBatch.hidden = YES;
  self.btnCloseBatch.translatesAutoresizingMaskIntoConstraints = NO;
  [self.btnCloseBatch addTarget:self
                         action:@selector(exitBatchMode)
               forControlEvents:UIControlEventTouchUpInside];
  [row1 addSubview:self.btnCloseBatch];

  [NSLayoutConstraint activateConstraints:@[
    [self.statusLabel.topAnchor constraintEqualToAnchor:row1.topAnchor],
    [self.statusLabel.bottomAnchor constraintEqualToAnchor:row1.bottomAnchor],
    [self.statusLabel.centerXAnchor constraintEqualToAnchor:row1.centerXAnchor],
    [self.btnCloseBatch.centerYAnchor
        constraintEqualToAnchor:row1.centerYAnchor],
    [self.btnCloseBatch.trailingAnchor
        constraintEqualToAnchor:row1.trailingAnchor
                       constant:0],
    [self.btnCloseBatch.heightAnchor constraintEqualToConstant:24],
    [self.btnCloseBatch.widthAnchor constraintEqualToConstant:24],
    [row1.heightAnchor constraintEqualToConstant:24]
  ]];
  [mainToolbarStack addArrangedSubview:row1];

  self.toolbarStackView = [[UIStackView alloc] init];
  self.toolbarStackView.axis = UILayoutConstraintAxisHorizontal;
  self.toolbarStackView.spacing = 8;
  self.toolbarStackView.distribution = UIStackViewDistributionFillEqually;
  self.toolbarStackView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.toolbarStackView.heightAnchor constraintEqualToConstant:30].active =
      YES;

  UIButton *btnRef = [self createTextToolBtn:TR(@"Mod_Results_Refreshed")
                                       color:[UIColor systemGreenColor]
                                         sel:@selector(doRefreshValues)];
  UIButton *btnBatch = [self createTextToolBtn:TR(@"Btn_Batch_Select")
                                         color:[UIColor systemPurpleColor]
                                           sel:@selector(enterBatchMode)];
  self.btnFilterToggle = [self createTextToolBtn:TR(@"Filter_Btn")
                                           color:[UIColor systemOrangeColor]
                                             sel:@selector(toggleFilterPanel)];

  [self.toolbarStackView addArrangedSubview:btnRef];
  [self.toolbarStackView addArrangedSubview:btnBatch];
  [self.toolbarStackView addArrangedSubview:self.btnFilterToggle];

  [mainToolbarStack addArrangedSubview:self.toolbarStackView];

  self.filterPanelView = [[UIView alloc] init];
  self.filterPanelView.hidden = YES;
  self.filterPanelView.backgroundColor =
      [UIColor secondarySystemGroupedBackgroundColor];
  self.filterPanelView.layer.cornerRadius = 10;
  self.filterPanelView.clipsToBounds = YES;

  [self.headerStackView addArrangedSubview:self.filterPanelView];

  self.segFilterMode = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Filter_Less"), TR(@"Filter_Greater"), TR(@"Filter_Between")
  ]];
  self.segFilterMode.translatesAutoresizingMaskIntoConstraints = NO;
  self.segFilterMode.selectedSegmentIndex = 2;
  [self.segFilterMode addTarget:self
                         action:@selector(filterModeChanged)
               forControlEvents:UIControlEventValueChanged];
  [self.filterPanelView addSubview:self.segFilterMode];

  UIStackView *inputRow = [[UIStackView alloc] init];
  inputRow.axis = UILayoutConstraintAxisHorizontal;
  inputRow.spacing = 8;
  inputRow.translatesAutoresizingMaskIntoConstraints = NO;
  [self.filterPanelView addSubview:inputRow];

  self.tfFilter1 = [self createSmallTF:TR(@"Filter_Input_Min")];
  self.tfFilter2 = [self createSmallTF:TR(@"Filter_Input_Max")];
  UIButton *btnApply = [UIButton buttonWithType:UIButtonTypeSystem];
  [btnApply setTitle:TR(@"Filter_Apply") forState:UIControlStateNormal];
  btnApply.backgroundColor = [UIColor systemOrangeColor];
  [btnApply setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  btnApply.layer.cornerRadius = 6;
  [btnApply.widthAnchor constraintEqualToConstant:70].active = YES;
  [btnApply addTarget:self
                action:@selector(applyFilter)
      forControlEvents:UIControlEventTouchUpInside];

  [inputRow addArrangedSubview:self.tfFilter1];
  [inputRow addArrangedSubview:self.tfFilter2];
  [inputRow addArrangedSubview:btnApply];
  [self.tfFilter1.widthAnchor
      constraintEqualToAnchor:self.tfFilter2.widthAnchor]
      .active = YES;

  [NSLayoutConstraint activateConstraints:@[
    [self.filterPanelView.heightAnchor constraintEqualToConstant:90],
    [self.segFilterMode.topAnchor
        constraintEqualToAnchor:self.filterPanelView.topAnchor
                       constant:8],
    [self.segFilterMode.leadingAnchor
        constraintEqualToAnchor:self.filterPanelView.leadingAnchor
                       constant:8],
    [self.segFilterMode.trailingAnchor
        constraintEqualToAnchor:self.filterPanelView.trailingAnchor
                       constant:-8],
    [inputRow.topAnchor constraintEqualToAnchor:self.segFilterMode.bottomAnchor
                                       constant:8],
    [inputRow.leadingAnchor
        constraintEqualToAnchor:self.filterPanelView.leadingAnchor
                       constant:8],
    [inputRow.trailingAnchor
        constraintEqualToAnchor:self.filterPanelView.trailingAnchor
                       constant:-8],
    [inputRow.heightAnchor constraintEqualToConstant:32]
  ]];

  [self filterModeChanged];
}

- (UIButton *)createToolBtn:(NSString *)title
                       icon:(NSString *)iconName
                      color:(UIColor *)color
                        sel:(SEL)sel {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];

  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *conf =
        [UIButtonConfiguration grayButtonConfiguration];
    conf.image = [UIImage systemImageNamed:iconName];
    conf.title = title;
    conf.imagePadding = 4;
    conf.baseForegroundColor = color;
    conf.baseBackgroundColor = [color colorWithAlphaComponent:0.1];
    conf.cornerStyle = UIButtonConfigurationCornerStyleMedium;
    conf.contentInsets = NSDirectionalEdgeInsetsMake(6, 8, 6, 8);
    btn.configuration = conf;
  } else {
    [btn setImage:[UIImage systemImageNamed:iconName]
         forState:UIControlStateNormal];
    [btn setTitle:[NSString stringWithFormat:@" %@", title]
         forState:UIControlStateNormal];
    [btn setTitleColor:color forState:UIControlStateNormal];
    btn.tintColor = color;
    btn.backgroundColor = [color colorWithAlphaComponent:0.1];
    btn.layer.cornerRadius = 6;
    btn.contentEdgeInsets = UIEdgeInsetsMake(6, 8, 6, 8);
    btn.titleLabel.font = [UIFont systemFontOfSize:14];
  }

  [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  return btn;
}

- (UIButton *)createIconBtn:(NSString *)icon
                      color:(UIColor *)color
                        sel:(SEL)sel {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
  [b setImage:[UIImage systemImageNamed:icon] forState:UIControlStateNormal];
  b.tintColor = color;
  [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  [b.widthAnchor constraintEqualToConstant:40].active = YES;
  return b;
}

- (UIButton *)createTextToolBtn:(NSString *)title
                          color:(UIColor *)color
                            sel:(SEL)sel {
  UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
  [btn setTitle:title forState:UIControlStateNormal];
  [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  btn.backgroundColor = color;

  btn.layer.cornerRadius = 8;
  btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];

  [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  return btn;
}

- (UITextField *)createSmallTF:(NSString *)ph {
  UITextField *tf = [[UITextField alloc] init];
  tf.translatesAutoresizingMaskIntoConstraints = NO;
  tf.borderStyle = UITextBorderStyleRoundedRect;
  tf.placeholder = ph;
  tf.font = [UIFont systemFontOfSize:13];

  tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;

  tf.textAlignment = NSTextAlignmentCenter;
  [self addDoneButtonTo:tf];
  return tf;
}

- (void)toggleFilterPanel {
  BOOL shouldShow = self.filterPanelView.hidden;
  self.filterPanelView.hidden = !shouldShow;

  if (@available(iOS 15.0, *)) {
    UIButtonConfiguration *conf = self.btnFilter.configuration;
    if (!self.filterPanelView.hidden) {
      conf.baseBackgroundColor = [UIColor systemOrangeColor];
      conf.baseForegroundColor = [UIColor whiteColor];
    } else {
      conf.baseBackgroundColor =
          [[UIColor systemOrangeColor] colorWithAlphaComponent:0.15];
      conf.baseForegroundColor = [UIColor systemOrangeColor];
    }
    self.btnFilter.configuration = conf;
  }

  [self.headerMainStack layoutIfNeeded];
  [self.tableView.tableHeaderView layoutIfNeeded];

  [self updateTableHeaderHeight:self.tableView.tableHeaderView];
}

- (void)filterModeChanged {
  NSInteger idx = self.segFilterMode.selectedSegmentIndex;

  if (idx == 0) {
    self.tfFilter1.placeholder = TR(@"Filter_Input_Val");
    self.tfFilter1.hidden = NO;
    self.tfFilter2.hidden = YES;
  } else if (idx == 1) {
    self.tfFilter1.placeholder = TR(@"Filter_Input_Val");
    self.tfFilter1.hidden = NO;
    self.tfFilter2.hidden = YES;
  } else {
    self.tfFilter1.placeholder = TR(@"Filter_Input_Min");
    self.tfFilter2.placeholder = TR(@"Filter_Input_Max");
    self.tfFilter1.hidden = NO;
    self.tfFilter2.hidden = NO;
  }
}

- (void)applyFilter {
  [self.view endEditing:YES];
  VMFilterMode mode;
  NSString *v1 = self.tfFilter1.text;
  NSString *v2 = self.tfFilter2.text;
  NSInteger idx = self.segFilterMode.selectedSegmentIndex;
  if (idx == 0)
    mode = VMFilterModeLess;
  else if (idx == 1)
    mode = VMFilterModeGreater;
  else
    mode = VMFilterModeBetween;
  if (v1.length == 0)
    return;
  self.statusLabel.text = TR(@"Mod_Status_Processing");
  self.view.userInteractionEnabled = NO;

  self.isScanning = YES;
  [self updateButtonStates];
  VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
  [[VMMemoryEngine shared]
      filterResultsWithMode:mode
                       val1:v1
                       val2:v2
                       type:type
                 completion:^(NSUInteger count, NSString *msg) {
                   dispatch_async(dispatch_get_main_queue(), ^{
                     self.isScanning = NO;
                     [self updateButtonStates];
                     self.view.userInteractionEnabled = YES;
                     if (count == 0) {
                       [self handleZeroResults];
                     } else {
                       NSString *detail = (mode == VMFilterModeBetween)
                           ? [NSString stringWithFormat:@"%@ %@~%@",
                                                        [self timelineTypeName:type],
                                                        v1 ?: @"", v2 ?: @""]
                           : [NSString stringWithFormat:@"%@ %@",
                                                        [self timelineTypeName:type],
                                                        v1 ?: @""];
                       [self captureTimelineTitle:[self timelineFilterTitle:mode]
                                           detail:detail
                                             type:type];
                       [self.tableView reloadData];
                       [self updateResultInfo];
                       [self updateEmptyState];

                       [self updateButtonStates];
                     }
                   });
                 }];
}

- (void)dataTypeChanged {
  VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
  NSInteger mode = self.searchModeSegment.selectedSegmentIndex;

  if (type == VMDataTypeString && mode != 0) {
    self.dataTypeSegment.selectedSegmentIndex = 2;
    [self dataTypeChanged];
    return;
  }

  if (type == VMDataTypeString) {
    self.inputField.keyboardType = UIKeyboardTypeDefault;
    self.inputField.placeholder = TR(@"Mod_Input_Str");
  } else {
    if (mode == 2) {
      self.inputField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
      self.inputField.placeholder = TR(@"Mod_Hint_Group");
    } else {
      self.inputField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
      self.inputField.placeholder = TR(@"Mod_Input_Value_Placeholder");
    }
  }

  BOOL showIcon = (mode == 2 && type != VMDataTypeString);
  [self updateGroupHelpButtonState:showIcon];

  [self.inputField reloadInputViews];
}

- (void)performPointerSearch:(uint64_t)targetAddress {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:TR(@"Act_Search_Ptr")
                       message:[NSString
                                   stringWithFormat:@"0x%llX", targetAddress]
                preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Ptr_Exact")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 [self executePointerSearch:targetAddress
                                                    isRange:NO];
                               }]];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Ptr_Struct")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 [self executePointerSearch:targetAddress
                                                    isRange:YES];
                               }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)executePointerSearch:(uint64_t)targetAddress isRange:(BOOL)isRange {
  [[VMMemoryEngine shared] backupCurrentSession];

  VMModifierViewController *ptrVC = [[VMModifierViewController alloc] init];
  ptrVC.isPointerSearchMode = YES;

  if (isRange) {
    uint64_t rangeStart =
        (targetAddress > 0x1000) ? (targetAddress - 0x1000) : 0;
    uint64_t rangeEnd = targetAddress;
    ptrVC.initialSearchVal =
        [NSString stringWithFormat:@"%llu,%llu", rangeStart, rangeEnd];
    ptrVC.initialSearchMode = VMSearchModeBetween;
    ptrVC.title = [NSString
        stringWithFormat:TR(@"Struct_Search_Title_Fmt"), targetAddress];
  } else {
    ptrVC.initialSearchVal = [NSString stringWithFormat:@"%llu", targetAddress];
    ptrVC.initialSearchMode = VMSearchModeExact;
    ptrVC.title =
        [NSString stringWithFormat:TR(@"Ptr_Link_Title_Fmt"), targetAddress];
  }

  [self.navigationController pushViewController:ptrVC animated:YES];
}

- (void)handleZeroResults {
  [[VMMemoryEngine shared] clearSession];

  self.isNextScan = NO;
  [self.searchBtn setTitle:TR(@"Mod_Search_First")
                  forState:UIControlStateNormal];
  self.nearbyBtn.hidden = YES;
  if (self.searchModeSegment.selectedSegmentIndex == 1) {
    self.inputField.hidden = YES;
    self.fuzzySegRow1.hidden = YES;
    self.fuzzySegRow2.hidden = YES;
    self.fuzzyHintLabel.hidden = YES;
  } else {
    self.inputField.hidden = NO;
    self.fuzzySegRow1.hidden = YES;
    self.fuzzySegRow2.hidden = YES;
    self.fuzzyHintLabel.hidden = YES;
  }

  self.statusLabel.text =
      [NSString stringWithFormat:@"%@: 0. %@", TR(@"Mod_Results_Count"),
                                 TR(@"Msg_Search_Zero_Hint")];
  [self.tableView reloadData];
  [self updateResultInfo];
  [self updateEmptyState];
  if (self.isMultiSelectMode)
    [self exitBatchMode];
}

- (void)performLegacyFuzzySearch:(NSString *)valStr type:(VMDataType)type fuzzyType:(VMFuzzyType)fType {
  [[VMMemoryEngine shared]
      scanMemoryWithMode:VMSearchModeFuzzy
                  valStr:valStr
                dataType:type
               fuzzyType:fType
            isNextSearch:self.isNextScan
              completion:^(NSUInteger count, NSString *msg) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  [self.btnSpinner stopAnimating];
                  [self.btnSpinner removeFromSuperview];
                  self.searchBtn.enabled = YES;
                  
                  if (self.isNextScan || count > 0) {
                    [self.searchBtn setTitle:TR(@"Mod_Search_Next") forState:UIControlStateNormal];
                  } else {
                    [self.searchBtn setTitle:TR(@"Mod_Search_First") forState:UIControlStateNormal];
                  }
                  
                  self.isScanning = NO;
                  [self updateButtonStates];
                  self.view.userInteractionEnabled = YES;
                  
                  if (count == 0) {
                    [self handleZeroResults];
                    UINotificationFeedbackGenerator *failGen = [[UINotificationFeedbackGenerator alloc] init];
                    [failGen notificationOccurred:UINotificationFeedbackTypeError];
                    return;
                  }
                  
                  UINotificationFeedbackGenerator *successGen = [[UINotificationFeedbackGenerator alloc] init];
                  [successGen notificationOccurred:UINotificationFeedbackTypeSuccess];
                  
                  NSString *detail = [NSString stringWithFormat:@"%@ %@",
                                                                 [self timelineTypeName:type],
                                                                 valStr ?: @""];
                  [self captureTimelineTitle:[self timelineModeTitle:VMSearchModeFuzzy]
                                      detail:detail
                                        type:type];
                  [self.tableView reloadData];
                  [self updateResultInfo];
                  [self updateEmptyState];
                  [self updateButtonStates];
                  [self showWeakToast:TR(@"Title_Scan_Complete")];
                  
                  self.isNextScan = YES;
                  [self.searchBtn setTitle:TR(@"Mod_Search_Next") forState:UIControlStateNormal];
                  self.btnNearby.hidden = NO;
                  self.fuzzySegRow1.hidden = NO;
                  self.fuzzySegRow2.hidden = NO;
                  self.fuzzyHintLabel.hidden = NO;
                  [self fuzzyTypeChanged];
                  
                  [self updateTableHeaderHeight:self.tableView.tableHeaderView];
                });
              }];
}

- (void)handleSearch {
  
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (eng.targetTask == MACH_PORT_NULL || (eng.targetPid > 0 && kill(eng.targetPid, 0) != 0)) {
    NSString *bid = eng.currentBundleID;
    if (bid && bid.length > 0) {
      if ([self tryAutoReconnect:bid]) {
        
        UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [gen impactOccurred];
        [self showToast:[NSString stringWithFormat:TR(@"Ptr_Auto_Attach_Success"), eng.targetPid]];
      }
    }
  }
  
  if ([VMMemoryEngine shared].targetTask == MACH_PORT_NULL) {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:TR(@"Err_Not_Connected")
                         message:TR(@"Err_Not_Connected_Msg")
                  preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert
        addAction:[UIAlertAction
                      actionWithTitle:TR(@"Btn_Go_Connect")
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *action) {
                                
                                UITabBarController *tab =
                                    (UITabBarController *)
                                        [UIApplication sharedApplication]
                                            .delegate.window.rootViewController;
                                if ([tab isKindOfClass:[UITabBarController
                                                           class]]) {
                                  tab.selectedIndex = 0;
                                }
                              }]];
    [self presentViewController:alert animated:YES completion:nil];
    return;
  }
  [self.inputField resignFirstResponder];
  NSString *valStr = self.inputField.text;
  VMSearchMode mode = (VMSearchMode)self.searchModeSegment.selectedSegmentIndex;
  
  VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;

  // Auto-detect range input in exact mode (not Str type)
  if (mode == VMSearchModeExact && type != VMDataTypeString && valStr.length > 0) {
    BOOL hasComma = [valStr containsString:@","] || [valStr containsString:@"\uFF0C"];
    BOOL hasTilde = [valStr containsString:@"~"] || [valStr containsString:@"\uFF5E"];
    if (hasComma || hasTilde) {
      mode = VMSearchModeBetween;
    }
  }

  NSInteger fIdx = 3;
  if (mode == VMSearchModeFuzzy) {
    if (self.fuzzySegRow1.selectedSegmentIndex != UISegmentedControlNoSegment) {
      fIdx = self.fuzzySegRow1.selectedSegmentIndex;
    } else if (self.fuzzySegRow2.selectedSegmentIndex !=
               UISegmentedControlNoSegment) {
      fIdx = 4 + self.fuzzySegRow2.selectedSegmentIndex;
    }
  }
  VMFuzzyType fType = VMFuzzyChanged;
  if (fIdx == 0)
    fType = VMFuzzyGreater; 
  else if (fIdx == 1)
    fType = VMFuzzyLess; 
  else if (fIdx == 2)
    fType = VMFuzzyUnchanged;
  else if (fIdx == 3)
    fType = VMFuzzyChanged;
  else if (fIdx == 4)
    fType = VMFuzzyIncreasedBy;
  else if (fIdx == 5)
    fType = VMFuzzyDecreasedBy;
  if (!self.isNextScan && (mode != VMSearchModeFuzzy && valStr.length == 0)) {
    [self showToast:TR(@"Err_Target_Empty")];
    return;
  }
  if (mode == VMSearchModeFuzzy && (fIdx == 4 || fIdx == 5)) {
    if (valStr.length == 0) {
      [self showToast:TR(@"Err_Target_Empty")];
      return;
    }
  }

  // Validate numeric input for non-String types in Exact/Between modes
  if (!self.isNextScan && type != VMDataTypeString && valStr.length > 0 &&
      (mode == VMSearchModeExact || mode == VMSearchModeBetween)) {
    NSString *cleaned = [valStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // Split by comma/tilde variants for range input
    NSString *splitPattern = @",|\uFF0C|~|\uFF5E";
    NSRegularExpression *splitRegex = [NSRegularExpression regularExpressionWithPattern:splitPattern options:0 error:nil];
    NSArray *splitMatches = [splitRegex matchesInString:cleaned options:0 range:NSMakeRange(0, cleaned.length)];
    NSMutableArray *parts = [NSMutableArray array];
    BOOL hasRangeSep = (splitMatches.count > 0);
    if (hasRangeSep) {
      NSUInteger lastEnd = 0;
      for (NSTextCheckingResult *m in splitMatches) {
        [parts addObject:[cleaned substringWithRange:NSMakeRange(lastEnd, m.range.location - lastEnd)]];
        lastEnd = m.range.location + m.range.length;
      }
      [parts addObject:[cleaned substringFromIndex:lastEnd]];
    } else {
      [parts addObject:cleaned];
    }
    // Range format must have exactly 2 non-empty numeric parts
    if (hasRangeSep) {
      NSMutableArray *nonEmpty = [NSMutableArray array];
      for (NSString *p in parts) {
        NSString *t = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (t.length > 0) [nonEmpty addObject:t];
      }
      if (nonEmpty.count != 2) {
        [self showToast:TR(@"Err_Range_Invalid")];
        return;
      }
      parts = nonEmpty;
    }
    NSRegularExpression *numRegex = [NSRegularExpression regularExpressionWithPattern:@"^-?\\d+\\.?\\d*$" options:0 error:nil];
    for (NSString *part in parts) {
      NSString *trimmed = [part stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
      if ([numRegex numberOfMatchesInString:trimmed options:0 range:NSMakeRange(0, trimmed.length)] == 0) {
        [self showToast:hasRangeSep ? TR(@"Err_Range_Invalid") : TR(@"Err_Not_Numeric")];
        return;
      }
    }
  }

  UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc]
      initWithStyle:UIImpactFeedbackStyleMedium];
  [gen impactOccurred];

  self.isScanning = YES;
  [self updateButtonStates];

  [self.searchBtn setTitle:@"" forState:UIControlStateNormal]; 
  self.searchBtn.enabled = NO; 

  if (!self.btnSpinner) {
    self.btnSpinner = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.btnSpinner.color = [UIColor systemBlueColor]; 
  }
  self.btnSpinner.center = CGPointMake(self.searchBtn.bounds.size.width / 2,
                                       self.searchBtn.bounds.size.height / 2);
  [self.searchBtn addSubview:self.btnSpinner];
  [self.btnSpinner startAnimating];

  if (!self.isNextScan) {
    self.statusLabel.text = TR(@"Mod_Status_Scanning");
    
  } else {
    [self showWeakToast:TR(@"Mod_Status_Scanning")];
  }

  if (mode == VMSearchModeFuzzy) {
    if (!self.isNextScan) {
      
      [[VMMemoryEngine shared] fastFuzzyInitWithCompletion:^(BOOL success, NSString *msg, NSUInteger addressCount) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.btnSpinner stopAnimating];
          [self.btnSpinner removeFromSuperview];
          self.searchBtn.enabled = YES;
          self.isScanning = NO;
          [self updateButtonStates];
          self.view.userInteractionEnabled = YES;
          
          if (!success) {
            [self showToast:msg];
            UINotificationFeedbackGenerator *failGen = [[UINotificationFeedbackGenerator alloc] init];
            [failGen notificationOccurred:UINotificationFeedbackTypeError];
            return;
          }
          
          UINotificationFeedbackGenerator *successGen = [[UINotificationFeedbackGenerator alloc] init];
          [successGen notificationOccurred:UINotificationFeedbackTypeSuccess];
          
          self.isFuzzyLocked = YES;
          self.fuzzySearchCount = 1;
          [self.searchModeSegment setEnabled:NO forSegmentAtIndex:0]; 
          [self.searchModeSegment setEnabled:NO forSegmentAtIndex:2]; 
          
          NSString *countStr;
          if (addressCount >= 100000000) {
            countStr = [NSString stringWithFormat:@"%.1f亿", addressCount / 100000000.0];
          } else if (addressCount >= 10000) {
            countStr = [NSString stringWithFormat:@"%.1f万", addressCount / 10000.0];
          } else {
            countStr = [NSString stringWithFormat:@"%lu", (unsigned long)addressCount];
          }
          self.statusLabel.text = [NSString stringWithFormat:@"%@: %@", TR(@"Mod_Results_Count"), countStr];
          [self showWeakToast:TR(@"Mod_Fuzzy_Ready")];
          
          self.isNextScan = YES;
          [self.searchBtn setTitle:TR(@"Mod_Search_Next") forState:UIControlStateNormal];
          
          self.fuzzySegRow1.hidden = NO;
          self.fuzzySegRow2.hidden = YES; 
          self.fuzzyHintLabel.hidden = NO;
          
          [self.fuzzySegRow1 setEnabled:NO forSegmentAtIndex:2];
          
          [self fuzzyTypeChanged];
          
          [self updateTableHeaderHeight:self.tableView.tableHeaderView];
        });
      }];
    } else {
      
      VMFilterMode filterMode = VMFilterModeChanged;
      if (fIdx == 0) filterMode = VMFilterModeIncreased;      
      else if (fIdx == 1) filterMode = VMFilterModeDecreased; 
      else if (fIdx == 2) filterMode = VMFilterModeUnchanged;
      else if (fIdx == 3) filterMode = VMFilterModeChanged;
      
      else if (fIdx == 4 || fIdx == 5) {
        
        [self performLegacyFuzzySearch:valStr type:type fuzzyType:fType];
        return;
      }
      
      NSUInteger currentCount = [VMMemoryEngine shared].resultCount;
      if (filterMode == VMFilterModeUnchanged) {
        if (currentCount > 20000000) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self.btnSpinner stopAnimating];
            [self.btnSpinner removeFromSuperview];
            self.searchBtn.enabled = YES;
            self.isScanning = NO;
            [self updateButtonStates];
            self.view.userInteractionEnabled = YES;
            
            UIAlertController *alert = [UIAlertController
                alertControllerWithTitle:TR(@"Alert_Warning")
                                 message:TR(@"Fuzzy_Unchanged_Too_Many")
                          preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
          });
          return;
        }
        
      }
      
      [[VMMemoryEngine shared] fastFuzzyFilterWithMode:filterMode
                                             dataType:type
                                           completion:^(NSUInteger count, NSString *msg) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.btnSpinner stopAnimating];
          [self.btnSpinner removeFromSuperview];
          self.searchBtn.enabled = YES;
          
          if (self.isNextScan || count > 0) {
            [self.searchBtn setTitle:TR(@"Mod_Search_Next") forState:UIControlStateNormal];
          } else {
            [self.searchBtn setTitle:TR(@"Mod_Search_First") forState:UIControlStateNormal];
          }
          
          self.isScanning = NO;
          [self updateButtonStates];
          self.view.userInteractionEnabled = YES;
          
          if (count == 0) {
            [self handleZeroResults];
            UINotificationFeedbackGenerator *failGen = [[UINotificationFeedbackGenerator alloc] init];
            [failGen notificationOccurred:UINotificationFeedbackTypeError];
            return;
          }
          
          UINotificationFeedbackGenerator *successGen = [[UINotificationFeedbackGenerator alloc] init];
          [successGen notificationOccurred:UINotificationFeedbackTypeSuccess];
          
          NSString *detail = [self timelineTypeName:type];
          [self captureTimelineTitle:[self timelineFilterTitle:filterMode]
                              detail:detail
                                type:type];
          [self.tableView reloadData];
          [self updateResultInfo];
          [self updateEmptyState];
          [self updateButtonStates];
          [self showWeakToast:TR(@"Title_Scan_Complete")];
          
          self.fuzzySearchCount++;
          if (self.fuzzySearchCount >= 2) {
            self.isFuzzyLocked = NO;
            [self.searchModeSegment setEnabled:YES forSegmentAtIndex:0];
            [self.searchModeSegment setEnabled:YES forSegmentAtIndex:2];
          }
          
          self.btnNearby.hidden = NO;
          
          self.fuzzySegRow1.hidden = NO;
          self.fuzzySegRow2.hidden = NO;
          self.fuzzyHintLabel.hidden = NO;
          
          BOOL enableUnchanged = (count <= 20000000);
          [self.fuzzySegRow1 setEnabled:enableUnchanged forSegmentAtIndex:2];
          
          [self fuzzyTypeChanged];
          
          [self updateTableHeaderHeight:self.tableView.tableHeaderView];
        });
      }];
    }
    return;
  }

  [[VMMemoryEngine shared]
      scanMemoryWithMode:mode
                  valStr:valStr
                dataType:type
               fuzzyType:fType
            isNextSearch:self.isNextScan
              completion:^(NSUInteger count, NSString *msg) {
                dispatch_async(dispatch_get_main_queue(), ^{
                  
                  [self.btnSpinner stopAnimating];
                  [self.btnSpinner removeFromSuperview];
                  self.searchBtn.enabled = YES;

                  if (self.isNextScan || count > 0) {
                    [self.searchBtn setTitle:TR(@"Mod_Search_Next")
                                    forState:UIControlStateNormal];
                  } else {
                    [self.searchBtn setTitle:TR(@"Mod_Search_First")
                                    forState:UIControlStateNormal];
                  }

                  self.isScanning = NO;
                  [self updateButtonStates];
                  self.view.userInteractionEnabled = YES;

                  if (count == 0) {
                    [self handleZeroResults];
                    
                    UINotificationFeedbackGenerator *failGen =
                        [[UINotificationFeedbackGenerator alloc] init];
                    [failGen
                        notificationOccurred:UINotificationFeedbackTypeError];
                    return;
                  }

                  UINotificationFeedbackGenerator *successGen =
                      [[UINotificationFeedbackGenerator alloc] init];
                  [successGen
                      notificationOccurred:UINotificationFeedbackTypeSuccess];

                  NSString *detail = [NSString stringWithFormat:@"%@ %@",
                                                                 [self timelineTypeName:type],
                                                                 valStr ?: @""];
                  [self captureTimelineTitle:[self timelineModeTitle:mode]
                                      detail:detail
                                        type:type];
                  [self.tableView reloadData];
                  [self updateResultInfo];
                  [self updateEmptyState];

                  [self updateButtonStates];

                  [self showWeakToast:TR(@"Title_Scan_Complete")];

                  self.isNextScan = YES;
                  [self.searchBtn setTitle:TR(@"Mod_Search_Next")
                                  forState:UIControlStateNormal];
                  self.btnNearby.hidden = NO;
                  if (mode == VMSearchModeFuzzy) {
                    self.fuzzySegRow1.hidden = NO;
                    self.fuzzySegRow2.hidden = NO;
                    self.fuzzyHintLabel.hidden = NO;
                    [self fuzzyTypeChanged];
                  } else {
                    self.inputField.hidden = NO;
                    self.fuzzySegRow1.hidden = YES;
                    self.fuzzySegRow2.hidden = YES;
                    self.fuzzyHintLabel.hidden = YES;
                  }

                  [self updateTableHeaderHeight:self.tableView.tableHeaderView];
                });
              }];
}

- (void)handleReset {
  if (self.pinnedResults) {
    [self.pinnedResults removeAllObjects];
  }

  if (self.selectedItems) {
    [self.selectedItems removeAllObjects];
  }

  [self.visitedMemSet removeAllObjects];
  [self.visitedHexSet removeAllObjects];

  self.isScanning = NO;
  
  self.isFuzzyLocked = NO;
  self.fuzzySearchCount = 0;
  [self.searchModeSegment setEnabled:YES forSegmentAtIndex:0]; 
  [self.searchModeSegment setEnabled:YES forSegmentAtIndex:2]; 
  
  if (self.dataTypeSegment.selectedSegmentIndex == UISegmentedControlNoSegment) {
    self.dataTypeSegment.selectedSegmentIndex = VMDataTypeInt32;
  }

  [self.inputHistory removeAllObjects];
  self.previousModeIndex = self.searchModeSegment.selectedSegmentIndex;

  [[VMMemoryEngine shared] clearSession];
  [[VMMemoryEngine shared] clearAllSnapshots];
  [[VMMemoryEngine shared] clearMemoryTimeline];
  [[VMMemoryEngine shared] clearManualWriteUndo];

  self.isNextScan = NO;
  self.btnNearby.hidden = YES;

  dispatch_async(dispatch_get_main_queue(), ^{
    self.inputField.text = @"";
    if (self.searchModeSegment.selectedSegmentIndex == 1) {
      self.fuzzySegRow1.selectedSegmentIndex = 3;
      self.fuzzySegRow2.selectedSegmentIndex = UISegmentedControlNoSegment;
      self.inputField.hidden = YES;
      self.fuzzySegRow1.hidden = YES;
      self.fuzzySegRow2.hidden = YES;
      self.fuzzyHintLabel.hidden = YES;
    } else {
      self.inputField.hidden = NO;
      self.fuzzySegRow1.hidden = YES;
      self.fuzzySegRow2.hidden = YES;
      self.fuzzyHintLabel.hidden = YES;
    }
    [self.searchBtn setTitle:TR(@"Mod_Search_First")
                    forState:UIControlStateNormal];
    self.statusLabel.text = TR(@"Mod_Status_Ready");
    if (self.isMultiSelectMode)
      [self exitBatchMode];
    self.tableView.tableFooterView = nil;
    [self.tableView reloadData];
    [self updateEmptyState];

    [self updateButtonStates];

    [self updateGroupHelpButtonState:(self.searchModeSegment
                                          .selectedSegmentIndex == 2)];
  });
}

- (void)showWeakToast:(NSString *)msg {
  dispatch_async(dispatch_get_main_queue(), ^{
    for (UIView *v in self.view.subviews) {
      if (v.tag == 9999)
        [v removeFromSuperview];
    }
    UIView *toastView = [[UIView alloc] init];
    toastView.tag = 9999;
    toastView.backgroundColor =
        [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.75];
    toastView.layer.cornerRadius = 10;
    toastView.clipsToBounds = YES;
    toastView.userInteractionEnabled = NO;
    toastView.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *label = [[UILabel alloc] init];
    label.text = msg;
    label.font = [UIFont boldSystemFontOfSize:15];
    label.textColor = [UIColor labelColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [toastView addSubview:label];

    [self.view addSubview:toastView];

    [NSLayoutConstraint activateConstraints:@[
      [label.topAnchor constraintEqualToAnchor:toastView.topAnchor constant:12],
      [label.bottomAnchor constraintEqualToAnchor:toastView.bottomAnchor
                                         constant:-12],
      [label.leadingAnchor constraintEqualToAnchor:toastView.leadingAnchor
                                          constant:20],
      [label.trailingAnchor constraintEqualToAnchor:toastView.trailingAnchor
                                           constant:-20],

      [toastView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
      [toastView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];

    toastView.alpha = 0;
    toastView.transform = CGAffineTransformMakeScale(0.9, 0.9);

    [UIView animateWithDuration:0.2
        animations:^{
          toastView.alpha = 1;
          toastView.transform = CGAffineTransformIdentity;
        }
        completion:^(BOOL finished) {
          [UIView animateWithDuration:0.3
              delay:0.6
              options:UIViewAnimationOptionCurveEaseOut
              animations:^{
                toastView.alpha = 0;
                toastView.transform = CGAffineTransformMakeScale(0.9, 0.9);
              }
              completion:^(BOOL finished) {
                [toastView removeFromSuperview];
              }];
        }];
  });
}

#pragma mark - Nearby Search
- (void)handleNearbySearch {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Nearby_Title")
                                          message:TR(@"Nearby_Msg")
                                   preferredStyle:UIAlertControllerStyleAlert];

  UIViewController *contentVC = [[UIViewController alloc] init];
  contentVC.preferredContentSize = CGSizeMake(270, 115);
  contentVC.view.backgroundColor = [UIColor clearColor];

  CGFloat margin = 10.0;
  CGFloat width = 270 - (margin * 2);

  UITextField *tfVal =
      [[UITextField alloc] initWithFrame:CGRectMake(margin, 0, width, 30)];
  tfVal.placeholder = TR(@"Nearby_Placeholder_Val");
  tfVal.borderStyle = UITextBorderStyleRoundedRect;

  tfVal.keyboardType = UIKeyboardTypeNumbersAndPunctuation;

  tfVal.textAlignment = NSTextAlignmentCenter;
  tfVal.font = [UIFont systemFontOfSize:14];
  [self addDoneButtonTo:tfVal];
  [contentVC.view addSubview:tfVal];

  UISegmentedControl *segType = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Type_I8"), TR(@"Type_I16"), TR(@"Type_I32"), TR(@"Type_I64"),
    TR(@"Type_F32"), TR(@"Type_F64")
  ]];
  segType.frame = CGRectMake(margin, 40, width, 30);
  
  NSInteger currentIdx = self.dataTypeSegment.selectedSegmentIndex;
  NSInteger nearbyIdx = 2; 
  switch ((VMDataType)currentIdx) {
    case VMDataTypeInt8:
    case VMDataTypeUInt8:
      nearbyIdx = 0; break;
    case VMDataTypeInt16:
    case VMDataTypeUInt16:
      nearbyIdx = 1; break;
    case VMDataTypeInt32:
    case VMDataTypeUInt32:
      nearbyIdx = 2; break;
    case VMDataTypeInt64:
    case VMDataTypeUInt64:
      nearbyIdx = 3; break;
    case VMDataTypeFloat:
      nearbyIdx = 4; break;
    case VMDataTypeDouble:
      nearbyIdx = 5; break;
    default:
      nearbyIdx = 2; break;
  }
  segType.selectedSegmentIndex = nearbyIdx;
  [contentVC.view addSubview:segType];

  UITextField *tfRange =
      [[UITextField alloc] initWithFrame:CGRectMake(margin, 80, width, 30)];
  tfRange.placeholder = TR(@"Nearby_Range_Placeholder");
  tfRange.borderStyle = UITextBorderStyleRoundedRect;
  tfRange.keyboardType = UIKeyboardTypeNumberPad;
  tfRange.textAlignment = NSTextAlignmentCenter;
  tfRange.font = [UIFont systemFontOfSize:14];
  [self addDoneButtonTo:tfRange];
  [contentVC.view addSubview:tfRange];

  [alert setValue:contentVC forKey:@"contentViewController"];

  [alert
      addAction:[UIAlertAction
                    actionWithTitle:TR(@"Btn_Confirm")
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *action) {
                              NSString *valStr = tfVal.text;

                              static const VMDataType nearbyToMain[] = {
                                VMDataTypeInt8, VMDataTypeInt16, VMDataTypeInt32,
                                VMDataTypeInt64, VMDataTypeFloat, VMDataTypeDouble
                              };
                              NSInteger nearbyIdx = segType.selectedSegmentIndex;
                              if (nearbyIdx >= 0 && nearbyIdx < 6) {
                                VMDataType targetType = nearbyToMain[nearbyIdx];
                                if (self.dataTypeSegment.selectedSegmentIndex != (NSInteger)targetType) {
                                  self.dataTypeSegment.selectedSegmentIndex = (NSInteger)targetType;
                                  [self dataTypeChanged];
                                }
                              }

                              if (valStr.length == 0) {
                                [self showToast:TR(@"Err_Target_Empty")];
                                return;
                              }

                              long long range = 50;
                              if (tfRange.text.length > 0) {
                                range = [tfRange.text longLongValue];
                              }
                              if (range <= 0) {
                                [self showToast:TR(@"Err_Range_Invalid")];
                                return;
                              }

                              if (range < 10) {
                                [self
                                    showRangeConfirmAlert:valStr
                                                    range:range
                                                      msg:TR(@"Msg_Range_Small")
                                                   isRisk:NO];
                              } else if (range > 500) {
                                [self
                                    showRangeConfirmAlert:valStr
                                                    range:range
                                                      msg:TR(@"Msg_Range_Large")
                                                   isRisk:YES];
                              } else {
                                [self performNearbySearchWithVal:valStr
                                                           range:range];
                              }
                            }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showRangeConfirmAlert:(NSString *)val
                        range:(long long)range
                          msg:(NSString *)msg
                       isRisk:(BOOL)risk {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Alert_Warn")
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertActionStyle style =
      risk ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
  NSString *btnTitle = risk ? TR(@"Btn_Force_Cont") : TR(@"Btn_Confirm");

  [alert addAction:[UIAlertAction
                       actionWithTitle:btnTitle
                                 style:style
                               handler:^(UIAlertAction *a) {
                                 [self performNearbySearchWithVal:val
                                                            range:range];
                               }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)performNearbySearchWithVal:(NSString *)val range:(uint64_t)range {
  self.statusLabel.text = TR(@"Status_Nearby_Scan");
  self.view.userInteractionEnabled = NO;

  self.isScanning = YES;
  [self updateButtonStates];

  VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;

  [[VMMemoryEngine shared]
      scanNearbyWithTarget:val
                  dataType:type
                     range:range
                completion:^(NSUInteger count, NSString *msg) {
                  dispatch_async(dispatch_get_main_queue(), ^{
                    self.isScanning = NO;
                    [self updateButtonStates];
                    self.view.userInteractionEnabled = YES;

                    if (count == 0) {
                      UIAlertController *retry = [UIAlertController
                          alertControllerWithTitle:TR(@"Mod_No_Result")
                                           message:TR(@"Msg_Nearby_Retry")
                                    preferredStyle:UIAlertControllerStyleAlert];
                      [retry
                          addAction:
                              [UIAlertAction
                                  actionWithTitle:TR(@"Btn_Retry_100")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self
                                                performNearbySearchWithVal:val
                                                                     range:100];
                                          }]];
                      [retry
                          addAction:[UIAlertAction
                                        actionWithTitle:TR(@"Btn_Cancel")
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];
                      [self presentViewController:retry
                                         animated:YES
                                       completion:nil];
                    } else {
                      NSString *detail = [NSString stringWithFormat:@"%@ %@",
                                                                     [self timelineTypeName:type],
                                                                     val ?: @""];
                      [self captureTimelineTitle:TR(@"Nearby_Btn")
                                          detail:detail
                                            type:type];
                      self.statusLabel.text =
                          [NSString stringWithFormat:@"%@: %@",
                                                     TR(@"Nearby_Prefix"), msg];
                      [self.tableView reloadData];
                      [self updateResultInfo];

                      [self updateButtonStates];
                    }
                  });
                }];
}

#pragma mark - Batch Modify
- (UIView *)tableView:(UITableView *)tableView
    viewForHeaderInSection:(NSInteger)section {
  return nil;
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForHeaderInSection:(NSInteger)section {
  return 0;
}

- (UIButton *)createHeaderBtn:(NSString *)title
                            x:(CGFloat)x
                        color:(UIColor *)c
                          sel:(SEL)sel {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
  b.frame = CGRectMake(x, 7, 90, 30);
  if ([title isEqualToString:TR(@"Btn_Cancel")])
    b.frame = CGRectMake(x, 7, 70, 30);
  if ([title isEqualToString:TR(@"Batch_Mod_Sel")])
    b.frame = CGRectMake(x, 7, 120, 30);
  [b setTitle:title forState:UIControlStateNormal];
  [b setTitleColor:c forState:UIControlStateNormal];
  b.titleLabel.font = [UIFont boldSystemFontOfSize:13];
  [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
  return b;
}

- (void)toggleBatchMode {
  if (self.isMultiSelectMode) {
    [self exitBatchMode];
  } else {
    [self enterBatchMode];
  }
}

- (void)enterBatchMode {
  if ([VMMemoryEngine shared].resultCount == 0)
    return;

  self.isMultiSelectMode = YES;
  self.isGlobalSelectAll = NO;

  if (@available(iOS 15.0, *)) {
    self.btnBatch.configuration.title = TR(@"Btn_Cancel");
    self.btnBatch.configuration.baseForegroundColor = [UIColor systemGrayColor];
    self.btnBatch.configuration.baseBackgroundColor =
        [[UIColor systemGrayColor] colorWithAlphaComponent:0.15];
  } else {
    [self.btnBatch setTitle:TR(@"Btn_Cancel") forState:UIControlStateNormal];
    [self.btnBatch setTitleColor:[UIColor systemGrayColor]
                        forState:UIControlStateNormal];
  }

  [self.tableView setEditing:YES animated:YES];

  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Cancel")
                                       style:UIBarButtonItemStyleDone
                                      target:self
                                      action:@selector(exitBatchMode)];
  self.navigationItem.leftBarButtonItem = nil;

  self.floatingBatchBar.hidden = NO;

  self.batchBarBottomConstraint.constant = -10;

  UIEdgeInsets insets = self.tableView.contentInset;
  insets.bottom += 80;
  self.tableView.contentInset = insets;

  [UIView animateWithDuration:0.3
                        delay:0
       usingSpringWithDamping:0.8
        initialSpringVelocity:0.5
                      options:0
                   animations:^{
                     self.floatingBatchBar.alpha = 1;
                     [self.view layoutIfNeeded];
                   }
                   completion:nil];

  if (!self.filterPanelView.hidden)
    [self toggleFilterPanel];
}

- (void)exitBatchMode {
  self.isMultiSelectMode = NO;
  self.isGlobalSelectAll = NO;

  if (@available(iOS 15.0, *)) {
    self.btnBatch.configuration.title = TR(@"Btn_Batch_Select");
    self.btnBatch.configuration.baseForegroundColor =
        [UIColor systemGreenColor];
    self.btnBatch.configuration.baseBackgroundColor =
        [[UIColor systemGreenColor] colorWithAlphaComponent:0.15];
  } else {
    [self.btnBatch setTitle:TR(@"Btn_Batch_Select")
                   forState:UIControlStateNormal];
    [self.btnBatch setTitleColor:[UIColor systemGreenColor]
                        forState:UIControlStateNormal];
  }

  [self.tableView setEditing:NO animated:YES];
  [self.tableView reloadData];

  UIBarButtonItem *jumpBtn = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"arrow.turn.down.right"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(showJumpMenu)];
  self.navigationItem.rightBarButtonItem = jumpBtn;
  [self restoreTimelineNavigationButton];

  self.batchBarBottomConstraint.constant = 100;

  UIEdgeInsets insets = self.tableView.contentInset;
  insets.bottom -= 80;
  self.tableView.contentInset = insets;

  [UIView animateWithDuration:0.3
      animations:^{
        self.floatingBatchBar.alpha = 0;
        [self.view layoutIfNeeded];
      }
      completion:^(BOOL finished) {
        self.floatingBatchBar.hidden = YES;
      }];

  [self updateButtonStates];
}

- (void)batchSelectAll {
  self.isGlobalSelectAll = !self.isGlobalSelectAll;

  UIButton *btnAll = [self.floatingBatchBar.contentView viewWithTag:101];
  if (btnAll) {
    NSString *imgName =
        self.isGlobalSelectAll ? @"xmark.circle" : @"checkmark.circle";
    [btnAll setImage:[UIImage systemImageNamed:imgName]
            forState:UIControlStateNormal];
  }

  if (!self.isGlobalSelectAll) {
    [self.tableView reloadData];
  } else {
    for (int i = 0; i < [self.tableView numberOfRowsInSection:0]; i++) {
      [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i
                                                              inSection:0]
                                  animated:NO
                            scrollPosition:UITableViewScrollPositionNone];
    }
  }
}

- (void)batchModifyAction {
  NSMutableArray *items = nil;

  if (!self.isGlobalSelectAll) {
    NSArray *paths = [self.tableView indexPathsForSelectedRows];
    if (!paths || paths.count == 0) {
      [self showToast:TR(@"Msg_No_Sel")];
      return;
    }

    items = [NSMutableArray array];
    VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
    for (NSIndexPath *p in paths) {
      VMScanResultItem *itm =
          [[VMMemoryEngine shared] getResultItemAtIndex:p.row dataType:type];
      if (itm)
        [items addObject:itm];
    }
  } else {
  }

  NSString *countStr =
      items ? [NSString stringWithFormat:@"%lu", (unsigned long)items.count]
            : TR(@"Backups_All_Apps");

  UIAlertController *sheet = [UIAlertController
      alertControllerWithTitle:TR(@"Mod_Batch_Menu_Title")
                       message:[NSString
                                   stringWithFormat:@"%@: %@",
                                                    TR(@"Mod_Results_Count"),
                                                    countStr]
                preferredStyle:UIAlertControllerStyleActionSheet];

  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Batch_Fixed_Btn")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self showBatchInputMode:0
                                                               items:items];
                                          }]];
  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Batch_Seq_Btn")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self showBatchInputMode:1
                                                               items:items];
                                          }]];
  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    sheet.popoverPresentationController.sourceView = self.view;
    sheet.popoverPresentationController.sourceRect =
        CGRectMake(self.view.center.x, self.view.center.y, 1, 1);
  }
  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showBatchInputMode:(int)mode items:(NSArray *)items {
  NSString *title = (mode == 0) ? TR(@"Mod_Batch_Fixed") : TR(@"Title_Inc_Val");
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder =
        (mode == 0) ? TR(@"Common_Val") : TR(@"Mod_Input_Val_Start");

    tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;

    [self addDoneButtonTo:tf];
  }];

  [alert
      addAction:[UIAlertAction
                    actionWithTitle:TR(@"Btn_Confirm")
                              style:UIAlertActionStyleDestructive
                            handler:^(UIAlertAction *a) {
                              NSString *val = alert.textFields[0].text;
                              if (val.length == 0)
                                return;

                              VMDataType type =
                                  (VMDataType)
                                      self.dataTypeSegment.selectedSegmentIndex;

                              [[VMMemoryEngine shared] batchModifyValues:val
                                                                   limit:0
                                                                    type:type
                                                                    mode:mode
                                                                   items:items];

                              [self.tableView reloadData];
                              [self showToast:TR(@"Msg_Mod_Success")];
                            }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)batchFavAction {
  NSArray *paths = [self.tableView indexPathsForSelectedRows];
  if (!paths || paths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }
  int count = 0;
  for (NSIndexPath *p in paths) {
    VMScanResultItem *itm = [self getItemAtIndexPath:p];
    if (itm) {
      VMDataType type = itm.type;
      if (type < VMDataTypeInt8 || type > VMDataTypeDouble) {
        type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
      }
      NSMutableDictionary *favItem =
          [NSMutableDictionary dictionaryWithDictionary:@{
            @"addr" : @(itm.address),
            @"note" : TR(@"Batch_Fav_Note"),
            @"type" : @(type)
          }];
      [[VMFavoriteManager shared]
          addFavorite:favItem
               forApp:[VMMemoryEngine shared].currentBundleID];
      count++;
    }
  }
  [self showToast:[NSString stringWithFormat:TR(@"Batch_Fav_Success"), count]];
}

- (void)batchLockAction {
  NSArray *paths = [self.tableView indexPathsForSelectedRows];
  if (!paths || paths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }
  int count = 0;

  NSMutableSet *existingAddrs = [NSMutableSet set];
  for (NSDictionary *d in [VMMemoryEngine shared].lockedItems) {
    [existingAddrs addObject:d[@"addr"]];
  }
  for (NSIndexPath *p in paths) {
    VMScanResultItem *itm = [self getItemAtIndexPath:p];
    if (itm) {
      if ([existingAddrs containsObject:@(itm.address)])
        continue;

      VMDataType type = itm.type;
      if (type < VMDataTypeInt8 || type > VMDataTypeDouble) {
        type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
      }
      
      NSString *val = [[VMMemoryEngine shared] readAddress:itm.address
                                                      type:type];
      
      [[VMLockEngine shared] addAddressLock:itm.address
                                      value:val ?: @"0"
                                       type:(int)type
                                       note:TR(@"Batch_Lock_Note")];
      [existingAddrs addObject:@(itm.address)];
      count++;
    }
  }

  if (count > 0) {
    [self showToast:[NSString stringWithFormat:@"%@ %d",
                                               TR(@"Lock_Add_Success"), count]];
  } else {
    [self showToast:@"Items already locked."];
  }
}

- (void)batchDeleteResultsAction {
  NSArray *paths = [self.tableView indexPathsForSelectedRows];
  if (!paths || paths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }
  NSArray *sortedPaths = [paths sortedArrayUsingComparator:^NSComparisonResult(
                                    NSIndexPath *obj1, NSIndexPath *obj2) {
    return [obj2 compare:obj1];
  }];
  for (NSIndexPath *p in sortedPaths) {
    if (p.row < self.pinnedResults.count) {
      [self.pinnedResults removeObjectAtIndex:p.row];
    } else {
      NSInteger engineIndex = p.row - self.pinnedResults.count;
      [[VMMemoryEngine shared] removeResultAtIndex:engineIndex];
    }
  }
  [self.tableView reloadData];
  [self updateResultInfo];
  [self updateEmptyState];

  [self updateButtonStates];
}

- (void)batchRangeSelectAction {
  self.isGlobalSelectAll = NO;
  UIButton *btnAll = [self.floatingBatchBar.contentView viewWithTag:101];
  if (btnAll) {
    [btnAll setImage:[UIImage systemImageNamed:@"checkmark.circle"]
            forState:UIControlStateNormal];
  }
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Range_Select_Title")
                                          message:TR(@"Range_Select_Msg")
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Range_Start_Placeholder");
    tf.keyboardType = UIKeyboardTypeNumberPad;
    [self addDoneButtonTo:tf];
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Range_End_Placeholder");
    tf.keyboardType = UIKeyboardTypeNumberPad;
    [self addDoneButtonTo:tf];
  }];

  [alert
      addAction:[UIAlertAction
                    actionWithTitle:TR(@"Btn_Confirm")
                              style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction *a) {
                              NSInteger start =
                                  [alert.textFields[0].text integerValue];
                              NSInteger end =
                                  [alert.textFields[1].text integerValue];

                              if (start <= 0)
                                start = 1;
                              if (end < start)
                                end = start;

                              NSInteger maxRows =
                                  [self.tableView numberOfRowsInSection:0];
                              if (end > maxRows)
                                end = maxRows;

                              for (NSInteger i = start - 1; i < end; i++) {
                                [self.tableView
                                    selectRowAtIndexPath:[NSIndexPath
                                                             indexPathForRow:i
                                                                   inSection:0]
                                                animated:NO
                                          scrollPosition:
                                              UITableViewScrollPositionNone];
                              }

                              [self showToast:[NSString
                                                  stringWithFormat:
                                                      TR(@"Msg_Selected_Items"),
                                                      (long)(end - start + 1)]];
                            }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)doRefreshValues {
  [self.tableView reloadData];

  UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc]
      initWithStyle:UIImpactFeedbackStyleLight];
  [gen impactOccurred];

  [self showWeakToast:TR(@"Msg_Refreshed")];
}

- (void)refreshResultsAction {
  [self doRefreshValues];
}

- (void)batchCopyAddressAction {
  NSArray *paths = [self.tableView indexPathsForSelectedRows];
  if (!paths || paths.count == 0) {
    [self showToast:TR(@"Msg_No_Sel")];
    return;
  }
  
  NSMutableArray *addrStrings = [NSMutableArray array];
  for (NSIndexPath *p in paths) {
    VMScanResultItem *item = [self getItemAtIndexPath:p];
    if (item) {
      [addrStrings addObject:[NSString stringWithFormat:@"0x%llX", item.address]];
    }
  }
  
  if (addrStrings.count > 0) {
    NSString *result = [addrStrings componentsJoinedByString:@"\n"];
    [[UIPasteboard generalPasteboard] setString:result];
    [self showToast:[NSString stringWithFormat:TR(@"Browser_Addrs_Copied"), (unsigned long)addrStrings.count]];
  }
}

- (VMScanResultItem *)getItemAtIndexPath:(NSIndexPath *)indexPath {
  if (indexPath.row < self.pinnedResults.count) {
    return self.pinnedResults[indexPath.row];
  } else {
    NSInteger engineIndex = indexPath.row - self.pinnedResults.count;
    VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
    return [[VMMemoryEngine shared] getResultItemAtIndex:engineIndex
                                                dataType:type];
  }
}

#pragma mark - TableView Delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
  if (scrollView != self.tableView) return;
  
  if (!self.toolRowInHeader) return;
  
  CGRect toolRowFrame = [self.toolRowInHeader convertRect:self.toolRowInHeader.bounds toView:self.view];
  
  CGFloat navBarBottom = self.view.safeAreaInsets.top;
  
  BOOL shouldShow = (CGRectGetMaxY(toolRowFrame) < navBarBottom);
  
  if (shouldShow && !self.isToolBarVisible) {
    [self showFloatingToolBar];
  } else if (!shouldShow && self.isToolBarVisible) {
    [self hideFloatingToolBar];
  }
}

- (void)showFloatingToolBar {
  if (self.isToolBarVisible) return;
  self.isToolBarVisible = YES;
  
  [self syncFloatingToolBarState];
  
  self.floatingToolBar.hidden = NO;
  self.toolBarTopConstraint.constant = 8; 
  
  [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
    self.floatingToolBar.alpha = 1.0;
    [self.view layoutIfNeeded];
  } completion:nil];
}

- (void)hideFloatingToolBar {
  if (!self.isToolBarVisible) return;
  self.isToolBarVisible = NO;
  
  self.toolBarTopConstraint.constant = -60; 
  
  [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
    self.floatingToolBar.alpha = 0;
    [self.view layoutIfNeeded];
  } completion:^(BOOL finished) {
    self.floatingToolBar.hidden = YES;
  }];
}

- (void)syncFloatingToolBarState {
  UIView *contentView = self.floatingToolBar.contentView;
  
  UIButton *btnRefresh = [contentView viewWithTag:2001];
  UIButton *btnNearby = [contentView viewWithTag:2002];
  UIButton *btnFilter = [contentView viewWithTag:2003];
  UIButton *btnBatch = [contentView viewWithTag:2004];
  UIButton *btnReset = [contentView viewWithTag:2005];
  
  btnRefresh.enabled = self.btnRefresh.enabled;
  btnRefresh.alpha = self.btnRefresh.alpha;
  
  btnNearby.enabled = self.btnNearby.enabled;
  btnNearby.alpha = self.btnNearby.alpha;
  
  btnFilter.enabled = self.btnFilter.enabled;
  btnFilter.alpha = self.btnFilter.alpha;
  
  btnBatch.enabled = self.btnBatch.enabled;
  btnBatch.alpha = self.btnBatch.alpha;
  
  btnReset.enabled = self.btnReset.enabled;
  btnReset.alpha = self.btnReset.alpha;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  NSUInteger total = [VMMemoryEngine shared].resultCount;
  NSUInteger limit = [VMMemoryEngine shared].resultLimit;
  if (limit == 0)
    limit = NSUIntegerMax;
  NSUInteger resultCount = MIN(total, limit);

  return self.pinnedResults.count + resultCount;
}

- (NSString *)formatBigNumber:(NSString *)numStr {
  if (!numStr || numStr.length == 0)
    return numStr;

  NSCharacterSet *notDigits =
      [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
  if ([numStr rangeOfCharacterFromSet:notDigits].location == NSNotFound) {
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.numberStyle = NSNumberFormatterDecimalStyle;
    fmt.groupingSeparator = @",";
    NSNumber *n = [fmt numberFromString:numStr];
    if (n)
      return [fmt stringFromNumber:n];
  }
  return numStr;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
  return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView
    canEditRowAtIndexPath:(NSIndexPath *)indexPath {
  return YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cid = @"rescell";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                  reuseIdentifier:cid];
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
  }

  cell.selectionStyle = UITableViewCellSelectionStyleDefault;

  UIView *bgView = [[UIView alloc] init];
  bgView.backgroundColor = [UIColor clearColor];
  cell.selectedBackgroundView = bgView;

  VMScanResultItem *item = [self getItemAtIndexPath:indexPath];

  if (item) {
    NSMutableString *displayText = [NSMutableString string];

    BOOL isPinned = (indexPath.row < self.pinnedResults.count);
    if (isPinned) {
      [displayText appendString:@"📌 "];
    } else {
      [displayText appendFormat:@"[%ld] ", (long)(indexPath.row + 1)];
    }

    [displayText appendFormat:@"0x%llX", item.address];

    cell.textLabel.text = displayText;
    cell.textLabel.numberOfLines = 1;

    UIImage *icon = nil;
    UIColor *iconColor = nil;

    BOOL isHexVisited = [self.visitedHexSet containsObject:@(item.address)];
    BOOL isMemVisited = [self.visitedMemSet containsObject:@(item.address)];

    if (isHexVisited) {
      icon = [UIImage systemImageNamed:@"checkmark.circle.fill"];
      iconColor = [UIColor systemPinkColor];
    } else if (isMemVisited) {
      icon = [UIImage systemImageNamed:@"checkmark.circle.fill"];
      iconColor = [UIColor systemPurpleColor];
    }

    cell.imageView.image = icon;
    cell.imageView.tintColor = iconColor;

    if (isPinned) {
      cell.backgroundColor =
          [[UIColor systemYellowColor] colorWithAlphaComponent:0.1];
    } else {
      cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }

    VMDataType displayType = item.type;
    if (displayType < VMDataTypeInt8 || displayType > VMDataTypeString) {
      if (self.dataTypeSegment.selectedSegmentIndex != UISegmentedControlNoSegment) {
        displayType = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
      } else {
        displayType = VMDataTypeInt32;
      }
    }
    
    NSString *val = [[VMMemoryEngine shared]
        readAddress:item.address
               type:displayType];

    VMDataType currentType = displayType;
    if (currentType != VMDataTypeFloat && currentType != VMDataTypeDouble &&
        currentType != VMDataTypeString) {
      cell.detailTextLabel.text = [self formatBigNumber:val] ?: @"?";
    } else {
      cell.detailTextLabel.text = val ?: @"?";
    }

    UIColor *valueColor = [UIColor systemGrayColor];

    VMSearchMode mode =
        (VMSearchMode)self.searchModeSegment.selectedSegmentIndex;
    NSString *targetVal = self.inputField.text;

    if (mode == VMSearchModeExact) {
      if (targetVal.length > 0 && val && ![val isEqualToString:targetVal]) {
        valueColor = [UIColor systemRedColor];
      } else {
        valueColor = [UIColor labelColor];
      }
    } else if (mode == VMSearchModeFuzzy) {
      if (item.valueStr && val && ![val isEqualToString:item.valueStr]) {
        valueColor = [UIColor systemRedColor];
      } else {
        valueColor = [UIColor labelColor];
      }
    } else {
      valueColor = [UIColor labelColor];
    }

    cell.detailTextLabel.textColor = valueColor;
  } else {
    cell.textLabel.text = @"?";
    cell.detailTextLabel.text = @"?";
  }

  cell.textLabel.font =
      [UIFont monospacedDigitSystemFontOfSize:16 weight:UIFontWeightRegular];
  cell.detailTextLabel.font =
      [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (tableView.isEditing) {
    if (self.isGlobalSelectAll) {
      self.isGlobalSelectAll = NO;
      UIView *header = [self.tableView headerViewForSection:0];
      UIButton *btnAll = [header viewWithTag:101];
      [btnAll setTitle:TR(@"Batch_Sel_All") forState:UIControlStateNormal];
      UIButton *btnMod = [header viewWithTag:102];
      [btnMod setTitle:TR(@"Batch_Mod_Sel") forState:UIControlStateNormal];
    }
    return;
  }

  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  VMScanResultItem *item = [self getItemAtIndexPath:indexPath];
  if (!item)
    return;

  VMDataType type = item.type;
  if (type < VMDataTypeInt8 || type > VMDataTypeString) {
    if (self.dataTypeSegment.selectedSegmentIndex != UISegmentedControlNoSegment) {
      type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
    } else {
      type = VMDataTypeInt32;
    }
  }

  NSString *liveVal = [[VMMemoryEngine shared] readAddress:item.address
                                                      type:type];
  item.valueStr = liveVal;

  [tableView reloadRowsAtIndexPaths:@[ indexPath ]
                   withRowAnimation:UITableViewRowAnimationNone];

  [VMMemoryActionSheet
      showActionSheetForAddress:item.address
                          value:liveVal
                       dataType:type
             fromViewController:self
                     sourceView:tableView
                     sourceRect:[tableView rectForRowAtIndexPath:indexPath]
                      extraItem:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:
        (NSIndexPath *)indexPath {
  VMScanResultItem *item = [self getItemAtIndexPath:indexPath];
  if (!item)
    return nil;

  BOOL isPinned = (indexPath.row < self.pinnedResults.count);

  UIContextualAction *del = [UIContextualAction
      contextualActionWithStyle:UIContextualActionStyleDestructive
                          title:nil
                        handler:^(UIContextualAction *action, UIView *view,
                                  void (^completion)(BOOL)) {
                          if (isPinned) {
                            [self.pinnedResults
                                removeObjectAtIndex:indexPath.row];
                          } else {
                            NSInteger engineIndex =
                                indexPath.row - self.pinnedResults.count;
                            [[VMMemoryEngine shared]
                                removeResultAtIndex:engineIndex];
                          }
                          [self.tableView reloadData];
                          [self updateEmptyState];
                          completion(YES);
                        }];
  del.backgroundColor = [UIColor systemRedColor];
  del.title = TR(@"Act_Delete");

  UIContextualAction *pin = [UIContextualAction
      contextualActionWithStyle:UIContextualActionStyleNormal
                          title:nil
                        handler:^(UIContextualAction *action, UIView *view,
                                  void (^completion)(BOOL)) {
                          if (isPinned) {
                            [self.pinnedResults removeObject:item];
                          } else {
                            VMScanResultItem *newItem =
                                [[VMScanResultItem alloc] init];
                            newItem.address = item.address;
                            newItem.valueStr = item.valueStr;
                            [self.pinnedResults addObject:newItem];
                          }
                          [self.tableView reloadData];
                          [self updateEmptyState];
                          completion(YES);
                        }];
  pin.backgroundColor = [UIColor systemIndigoColor];
  pin.title = isPinned ? TR(@"Pin_Unpin") : TR(@"Pin_Pin");

  UIContextualAction *lock = [UIContextualAction
      contextualActionWithStyle:UIContextualActionStyleNormal
                          title:nil
                        handler:^(UIContextualAction *action, UIView *view,
                                  void (^completion)(BOOL)) {
                          
                          VMDataType type = item.type;
                          if (type < VMDataTypeInt8 || type > VMDataTypeString) {
                            if (self.dataTypeSegment.selectedSegmentIndex != UISegmentedControlNoSegment) {
                              type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
                            } else {
                              type = VMDataTypeInt32;
                            }
                          }
                          NSString *currVal =
                              [[VMMemoryEngine shared] readAddress:item.address
                                                              type:type];

                          [[VMLockEngine shared] addAddressLock:item.address
                                                          value:currVal ?: @"0"
                                                           type:(int)type
                                                           note:TR(@"App_Title")];
                          
                          [self showToast:TR(@"Ptr_Lock_Success")];
                          completion(YES);
                        }];
  lock.backgroundColor = [UIColor systemBlueColor];
  lock.title = TR(@"Act_Lock");

  UIContextualAction *fav = [UIContextualAction
      contextualActionWithStyle:UIContextualActionStyleNormal
                          title:nil
                        handler:^(UIContextualAction *action, UIView *view,
                                  void (^completion)(BOOL)) {
                          
                          VMDataType type = item.type;
                          if (type < VMDataTypeInt8 || type > VMDataTypeString) {
                            if (self.dataTypeSegment.selectedSegmentIndex != UISegmentedControlNoSegment) {
                              type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
                            } else {
                              type = VMDataTypeInt32;
                            }
                          }
                          [VMMemoryActionSheet showAddToFavAlert:item.address
                                                            type:type
                                                            inVC:self];
                          completion(YES);
                        }];
  fav.backgroundColor = [UIColor systemOrangeColor];
  fav.title = TR(@"Act_Favorite");

  return [UISwipeActionsConfiguration
      configurationWithActions:@[ del, pin, lock, fav ]];
}

- (void)updateResultInfo {
  NSUInteger total = [VMMemoryEngine shared].resultCount;
  NSUInteger limit = [VMMemoryEngine shared].resultLimit;

  if (total == 0) {
    return;
  }

  if (limit > 0 && total > limit) {
    self.statusLabel.text =
        [NSString stringWithFormat:TR(@"Mod_Status_Truncated_Fmt"),
                                   TR(@"Mod_Results_Count"),
                                   (unsigned long)total, (unsigned long)limit];
    self.statusLabel.textColor = [UIColor systemOrangeColor];
  } else {
    self.statusLabel.text =
        [NSString stringWithFormat:@"%@: %lu", TR(@"Mod_Results_Count"),
                                   (unsigned long)total];
    self.statusLabel.textColor = [UIColor systemBlueColor];
  }
}

- (void)updateEmptyState {
  NSUInteger engineCount = [VMMemoryEngine shared].resultCount;
  NSUInteger pinnedCount = self.pinnedResults.count;

  self.tableView.hidden = NO;

  if (engineCount == 0 && pinnedCount == 0) {
    self.toolbarStackView.hidden = YES;

    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
  } else {
    self.toolbarStackView.hidden = NO;
    self.tableView.tableFooterView = nil;

    if (engineCount == 0 && pinnedCount > 0) {
      self.statusLabel.text =
          [NSString stringWithFormat:@"%@: %lu", TR(@"Pin_Count"),
                                     (unsigned long)pinnedCount];
    } else {
      self.statusLabel.text =
          [NSString stringWithFormat:@"%@: %lu", TR(@"Mod_Results_Count"),
                                     (unsigned long)engineCount];
    }
  }
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

- (void)openPointerTool {
  VMPointerSearchViewController *ptrVC =
      [[VMPointerSearchViewController alloc] init];
  ptrVC.level = 1;
  [self.navigationController pushViewController:ptrVC animated:YES];
}

- (NSString *)timelineTypeName:(VMDataType)type {
  NSArray *names = @[ @"I8", @"I16", @"I32", @"I64", @"U8", @"U16", @"U32", @"U64", @"F32", @"F64", @"Str" ];
  if (type < names.count)
    return names[type];
  return @"?";
}

- (NSString *)timelineModeTitle:(VMSearchMode)mode {
  switch (mode) {
    case VMSearchModeFuzzy:
      return TR(@"Timeline_Mode_Fuzzy");
    case VMSearchModeGroup:
      return TR(@"Timeline_Mode_Group");
    case VMSearchModeBetween:
      return TR(@"Timeline_Mode_Between");
    case VMSearchModeExact:
    default:
      return TR(@"Timeline_Mode_Exact");
  }
}

- (NSString *)timelineFilterTitle:(VMFilterMode)mode {
  switch (mode) {
    case VMFilterModeLess:
      return TR(@"Filter_Less");
    case VMFilterModeGreater:
      return TR(@"Filter_Greater");
    case VMFilterModeBetween:
      return TR(@"Filter_Between");
    case VMFilterModeIncreased:
      return TR(@"Fuz_Increased");
    case VMFilterModeDecreased:
      return TR(@"Fuz_Decreased");
    case VMFilterModeChanged:
      return TR(@"Fuz_Changed");
    case VMFilterModeUnchanged:
      return TR(@"Fuz_Unchanged");
  }
}

- (void)captureTimelineTitle:(NSString *)title
                      detail:(NSString *)detail
                        type:(VMDataType)type {
  [[VMMemoryEngine shared] captureMemoryTimelineWithTitle:title
                                                   detail:detail
                                                 dataType:type];
}

- (void)showTimelineSheet {
  NSArray<VMMemoryTimelineItem *> *items =
      [[VMMemoryEngine shared] memoryTimelineItems];
  UIAlertController *sheet = [UIAlertController
      alertControllerWithTitle:TR(@"Timeline_Title")
                       message:items.count > 0 ? nil : TR(@"Timeline_Empty")
                preferredStyle:UIAlertControllerStyleActionSheet];

  NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
  fmt.dateFormat = @"HH:mm:ss";

  for (NSUInteger i = 0; i < items.count; i++) {
    VMMemoryTimelineItem *item = items[i];
    NSString *time = [fmt stringFromDate:item.date ?: [NSDate date]];
    NSString *title = [NSString
        stringWithFormat:@"%@  %@ · %lu",
                         time,
                         item.title ?: @"",
                         (unsigned long)item.resultCount];
    NSString *detail = item.detail.length > 0 ? item.detail : @"";
    NSString *actionTitle = detail.length > 0
        ? [NSString stringWithFormat:@"%@\n%@", title, detail]
        : title;
    [sheet addAction:[UIAlertAction
                         actionWithTitle:actionTitle
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                   if ([[VMMemoryEngine shared]
                                           restoreMemoryTimelineAtIndex:i]) {
                                     self.dataTypeSegment.selectedSegmentIndex =
                                         item.dataType;
                                     [self.tableView reloadData];
                                     [self updateResultInfo];
                                     [self updateEmptyState];
                                     [self updateButtonStates];
                                     self.isNextScan = YES;
                                     [self.searchBtn
                                         setTitle:TR(@"Mod_Search_Next")
                                         forState:UIControlStateNormal];
                                     [self showToast:
                                               [NSString stringWithFormat:
                                                             TR(@"Timeline_Restored_Fmt"),
                                                             time,
                                                             (unsigned long)item.resultCount]];
                                   } else {
                                     [self showToast:TR(@"Timeline_Restore_Failed")];
                                   }
                                 }]];
  }

  if (items.count > 0) {
    [sheet addAction:[UIAlertAction
                         actionWithTitle:TR(@"Timeline_Clear")
                                   style:UIAlertActionStyleDestructive
                                 handler:^(UIAlertAction *a) {
                                   [[VMMemoryEngine shared] clearMemoryTimeline];
                                 }]];
  }

  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    UIView *navBar = self.navigationController.navigationBar;
    sheet.popoverPresentationController.sourceView = navBar ?: self.view;
    sheet.popoverPresentationController.sourceRect =
        navBar ? CGRectMake(0, 0, 50, 44)
               : CGRectMake(self.view.bounds.size.width / 2,
                            self.view.bounds.size.height / 2, 1, 1);
  }

  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)showJumpMenu {
  UIAlertController *sheet = [UIAlertController
      alertControllerWithTitle:TR(@"Pop_Jump_Title")
                       message:nil
                preferredStyle:UIAlertControllerStyleActionSheet];

  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Pop_Jump_Value")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self promptJumpAddress:NO];
                                          }]];
  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Pop_Jump_Hex")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self promptJumpAddress:YES];
                                          }]];
  [sheet addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    UIView *navBar = self.navigationController.navigationBar;

    if (navBar) {
      sheet.popoverPresentationController.sourceView = navBar;
      sheet.popoverPresentationController.sourceRect =
          CGRectMake(navBar.bounds.size.width - 50, 0, 50, 44);
    } else {
      sheet.popoverPresentationController.sourceView = self.view;
      sheet.popoverPresentationController.sourceRect =
          CGRectMake(self.view.bounds.size.width / 2,
                     self.view.bounds.size.height / 2, 1, 1);
    }
  }

  [self presentViewController:sheet animated:YES completion:nil];
}

- (void)executeBlockAfterDismissal:(void (^)(void))block {
  if (!self.presentedViewController) {
    block();
    return;
  }

  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [self executeBlockAfterDismissal:block];
      });
}

- (void)promptJumpAddress:(BOOL)isHex {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Btn_Jump")
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Prompt_Addr_Input");
    tf.keyboardType = UIKeyboardTypeASCIICapable;
  }];
  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Btn_Confirm")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 NSString *input =
                                     alert.textFields.firstObject.text;

                                 [self executeBlockAfterDismissal:^{
                                   uint64_t addr =
                                       strtoull([input UTF8String], NULL, 16);

                                   if (isHex) {
                                     VMHexEditorViewController *vc =
                                         [VMHexEditorViewController new];
                                     vc.address = addr;
                                     [self.navigationController
                                         pushViewController:vc
                                                   animated:YES];
                                   } else {
                                     VMMemoryBrowserViewController *vc =
                                         [VMMemoryBrowserViewController new];
                                     vc.address = addr;
                                     VMDataType t =
                                         (VMDataType)self.dataTypeSegment
                                             .selectedSegmentIndex;
                                     if (t == VMDataTypeString)
                                       t = VMDataTypeInt32;
                                     vc.type = t;
                                     [self.navigationController
                                         pushViewController:vc
                                                   animated:YES];
                                   }
                                 }];
                               }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  if (textField == self.inputField)
    [self handleSearch];
  return YES;
}

- (void)addDoneButtonTo:(UITextField *)textField {
  CGFloat width = [UIScreen mainScreen].bounds.size.width;
  UIToolbar *toolbar =
      [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, width, 44)];

  toolbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

  UIBarButtonItem *flex = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                           target:nil
                           action:nil];
  UIBarButtonItem *done = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                           target:textField
                           action:@selector(resignFirstResponder)];
  toolbar.items = @[ flex, done ];
  textField.inputAccessoryView = toolbar;
}

- (void)updateGroupHelpButtonState:(BOOL)show {
  NSInteger mode = self.searchModeSegment.selectedSegmentIndex;
  VMDataType type = (VMDataType)self.dataTypeSegment.selectedSegmentIndex;
  BOOL showExact = (mode == 0 && type != VMDataTypeString);
  BOOL shouldShow = show || showExact;

  if (shouldShow) {
    UIButton *infoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [infoBtn setImage:[UIImage systemImageNamed:@"info.circle"]
             forState:UIControlStateNormal];
    infoBtn.tintColor = [UIColor systemBlueColor];
    infoBtn.frame = CGRectMake(0, 0, 30, 30);
    infoBtn.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);

    SEL helpSel = show ? @selector(showGroupHelpAlert) : @selector(showExactHelpAlert);
    [infoBtn addTarget:self
                  action:helpSel
        forControlEvents:UIControlEventTouchUpInside];

    self.inputField.rightView = infoBtn;
    self.inputField.rightViewMode = UITextFieldViewModeAlways;
  } else {
    self.inputField.rightView = nil;
    self.inputField.rightViewMode = UITextFieldViewModeNever;
  }
}

- (void)showGroupHelpAlert {
  [self.view endEditing:YES];

  NSString *title = TR(@"Group_Help_Title");
  NSString *msg = TR(@"Group_Help_Msg");

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];

  NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
  para.alignment = NSTextAlignmentLeft;
  para.lineSpacing = 4;

  NSMutableAttributedString *attrStr =
      [[NSMutableAttributedString alloc] initWithString:msg];
  [attrStr addAttribute:NSParagraphStyleAttributeName
                  value:para
                  range:NSMakeRange(0, msg.length)];
  [attrStr addAttribute:NSFontAttributeName
                  value:[UIFont systemFontOfSize:13]
                  range:NSMakeRange(0, msg.length)];

  [alert setValue:attrStr forKey:@"attributedMessage"];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showExactHelpAlert {
  [self.view endEditing:YES];

  NSString *title = TR(@"Exact_Help_Title");
  NSString *msg = TR(@"Exact_Help_Msg");

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];

  NSMutableParagraphStyle *para = [[NSMutableParagraphStyle alloc] init];
  para.alignment = NSTextAlignmentLeft;
  para.lineSpacing = 4;

  NSMutableAttributedString *attrStr =
      [[NSMutableAttributedString alloc] initWithString:msg];
  [attrStr addAttribute:NSParagraphStyleAttributeName
                  value:para
                  range:NSMakeRange(0, msg.length)];
  [attrStr addAttribute:NSFontAttributeName
                  value:[UIFont systemFontOfSize:13]
                  range:NSMakeRange(0, msg.length)];

  [alert setValue:attrStr forKey:@"attributedMessage"];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)updateBatchBarStyle {
  if (!self.batchStackView)
    return;

  CGFloat screenWidth = self.view.bounds.size.width;
  CGFloat screenHeight = self.view.bounds.size.height;
  BOOL isLandscape = screenWidth > screenHeight;

  CGFloat pointSize;
  CGFloat padding;

  if (isLandscape) {
    pointSize = 24.0; 
    padding = 10.0;
  } else {
    
    if (screenWidth < 350) { 
      pointSize = 18.0;
      padding = 4.0;
    } else {
      pointSize = 22.0;
      padding = 8.0;
    }
  }

  if (isLandscape) {
    
    if (self.batchStackView.distribution != UIStackViewDistributionFill) {
      self.batchStackView.distribution = UIStackViewDistributionFill;
    }
    self.batchStackView.spacing = 30.0; 

    if (screenWidth > 800)
      self.batchStackView.spacing = 50.0;

  } else {
    
    if (self.batchStackView.distribution !=
        UIStackViewDistributionEqualSpacing) {
      self.batchStackView.distribution = UIStackViewDistributionEqualSpacing;
    }
    self.batchStackView.spacing =
        0; 
  }

  UIImageSymbolScale iconScale =
      isLandscape ? UIImageSymbolScaleMedium : UIImageSymbolScaleSmall;

  if (@available(iOS 15.0, *)) {
    UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration
        configurationWithPointSize:pointSize
                            weight:UIImageSymbolWeightSemibold
                             scale:iconScale];

    for (UIView *view in self.batchStackView.arrangedSubviews) {
      if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        UIButtonConfiguration *conf = btn.configuration;

        if (conf.preferredSymbolConfigurationForImage != sym ||
            conf.contentInsets.top != padding) {
          conf.preferredSymbolConfigurationForImage = sym;
          conf.contentInsets =
              NSDirectionalEdgeInsetsMake(padding, padding, padding, padding);
          btn.configuration = conf;
        }
      }
    }
  } else {
    
    UIImageSymbolConfiguration *sym = [UIImageSymbolConfiguration
        configurationWithPointSize:pointSize
                            weight:UIImageSymbolWeightSemibold
                             scale:iconScale];
    for (UIView *view in self.batchStackView.arrangedSubviews) {
      if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        btn.contentEdgeInsets =
            UIEdgeInsetsMake(padding, padding, padding, padding);
        if (btn.currentImage) {
          [btn
              setImage:[btn.currentImage imageByApplyingSymbolConfiguration:sym]
              forState:UIControlStateNormal];
        }
      }
    }
  }

  [self.floatingBatchBar layoutIfNeeded];
}

#pragma mark - Auto Reconnect (v2.5)

- (BOOL)tryAutoReconnect:(NSString *)targetBid {
  if (!targetBid || targetBid.length == 0)
    return NO;
  
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
      
      NSString *plistPath = [appDir stringByAppendingPathComponent:@"Info.plist"];
      NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
      
      if (info && [info[@"CFBundleIdentifier"] caseInsensitiveCompare:targetBid] == NSOrderedSame) {
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
      self.lastAttachedPID = foundPid;
      return YES;
    }
  }
  return NO;
}

@end
