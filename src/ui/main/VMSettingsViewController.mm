#import "VMSettingsViewController.h"
#import "../../core/VMRootViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/helpers/VMKeyboardAvoidance.h"
#import "../../utils/helpers/VMLanguageRefresh.h"
#import "../../utils/managers/VMUpdateManager.h"
#import "include/VMIconHelper.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <errno.h>
#include <math.h>
#include <limits.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])

#pragma mark - VMIconDataSource

@interface VMIconDataSource
    : NSObject <UITableViewDataSource, UITableViewDelegate>
@property(nonatomic, strong) NSArray *iconList;
@property(nonatomic, copy) NSString *currentIconName;
@end

@implementation VMIconDataSource

- (instancetype)init {
  if (self = [super init]) {
    
    _iconList = @[
      @{
        @"name" : TR(@"Icon_Default"),
        @"key" : [NSNull null],
        @"file" : @"AppIcon60x60@2x"
      },
      @{@"name" : TR(@"Icon_1"), @"key" : @"Icon-1", @"file" : @"Icon-1@2x"},
      @{@"name" : TR(@"Icon_2"), @"key" : @"Icon-2", @"file" : @"Icon-2@2x"},
      @{@"name" : TR(@"Icon_3"), @"key" : @"Icon-3", @"file" : @"Icon-3@2x"},
      @{@"name" : TR(@"Icon_4"), @"key" : @"Icon-4", @"file" : @"Icon-4@2x"},
      @{@"name" : TR(@"Icon_5"), @"key" : @"Icon-5", @"file" : @"Icon-5@2x"}
    ];
    _currentIconName = [[UIApplication sharedApplication] alternateIconName];
  }
  return self;
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return _iconList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *identifier = @"IconCell";
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:identifier];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:identifier];
  }

  NSDictionary *item = _iconList[indexPath.row];
  NSString *key = item[@"key"];
  NSString *fileName = item[@"file"];

  cell.textLabel.text = item[@"name"];

  NSString *path = [[NSBundle mainBundle] pathForResource:fileName
                                                   ofType:@"png"];
  UIImage *iconImg = [UIImage imageWithContentsOfFile:path];

  if (!iconImg) {
    NSString *file3x = [fileName stringByReplacingOccurrencesOfString:@"@2x"
                                                           withString:@"@3x"];
    path = [[NSBundle mainBundle] pathForResource:file3x ofType:@"png"];
    iconImg = [UIImage imageWithContentsOfFile:path];
  }

  if (!iconImg)
    iconImg = [UIImage systemImageNamed:@"app"];

  cell.imageView.image = iconImg;

  CGSize itemSize = CGSizeMake(36, 36);
  UIGraphicsBeginImageContextWithOptions(itemSize, NO,
                                         UIScreen.mainScreen.scale);
  UIBezierPath *pathClip =
      [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, itemSize.width,
                                                         itemSize.height)
                                 cornerRadius:8];
  [pathClip addClip];
  [iconImg drawInRect:CGRectMake(0, 0, itemSize.width, itemSize.height)];
  cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  BOOL isSelected = NO;
  if (self.currentIconName == nil) {
    if ([key isKindOfClass:[NSNull class]])
      isSelected = YES;
  } else {
    if ([key isKindOfClass:[NSString class]] &&
        [key isEqualToString:self.currentIconName])
      isSelected = YES;
  }

  cell.accessoryType = UITableViewCellAccessoryNone;

  if (isSelected) {
    
    cell.textLabel.textColor = [UIColor systemBlueColor];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:17]; 
    cell.backgroundColor =
        [UIColor secondarySystemBackgroundColor]; 
    cell.tintColor = [UIColor systemBlueColor];   
  } else {
    
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.backgroundColor = [UIColor systemBackgroundColor];
  }

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  NSDictionary *item = _iconList[indexPath.row];
  id key = item[@"key"];
  NSString *iconName = [key isKindOfClass:[NSNull class]] ? nil : key;

  self.currentIconName = iconName;
  [tableView reloadData];

  UIViewController *contentVC =
      (UIViewController *)
          tableView.superview.nextResponder; 
  
  if (![contentVC isKindOfClass:[UIViewController class]]) {
    contentVC = objc_getAssociatedObject(tableView, "hostVC");
  }

  VMSettingsViewController *settingsVC =
      objc_getAssociatedObject(contentVC, "settingsVC");
  if (settingsVC) {
    [settingsVC changeAppIcon:iconName];
  }
}

- (CGFloat)tableView:(UITableView *)tableView
    heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  return 60;
}

@end

// Compact inline settings expand vertically for long controls and accessibility sizes.
@interface VMSettingControlCell : UITableViewCell
@property(nonatomic, strong) UILabel *caption;
@property(nonatomic, strong) UIStackView *stack;
@property(nonatomic, strong) UIView *control;
@property(nonatomic, strong) NSLayoutConstraint *controlWidth;
- (void)configureTitle:(NSString *)title control:(UIView *)control;
@end
@implementation VMSettingControlCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
  if ((self = [super initWithStyle:style reuseIdentifier:identifier])) {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = VMUIHelper.cardColor;
    self.caption = [UILabel new];
    self.caption.font = [VMUIHelper scaledFontOfSize:15 weight:UIFontWeightRegular];
    self.caption.adjustsFontForContentSizeCategory = YES;
    self.caption.textColor = UIColor.labelColor;
    self.caption.numberOfLines = 0;
    self.stack = [[UIStackView alloc] initWithArrangedSubviews:@[self.caption]];
    self.stack.axis = UILayoutConstraintAxisHorizontal;
    self.stack.alignment = UIStackViewAlignmentCenter;
    self.stack.spacing = 12;
    self.stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:self.stack];
    [NSLayoutConstraint activateConstraints:@[
      [self.stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:4],
      [self.stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-4],
      [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:52],
      [self.stack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
      [self.stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16]
    ]];
  }
  return self;
}
- (void)configureTitle:(NSString *)title control:(UIView *)control {
  self.caption.text = title;
  if (self.control != control) {
    self.controlWidth.active = NO;
    self.controlWidth = nil;
    [self.control removeFromSuperview];
    self.control = control;
    [self.stack addArrangedSubview:control];
  }
  control.accessibilityLabel = title;
  [self updateLayoutForWidth:self.bounds.size.width];
}
- (void)updateLayoutForWidth:(CGFloat)width {
  if (!self.control) return;
  CGFloat available = MAX(200, width - 32);
  BOOL textField = [self.control isKindOfClass:UITextField.class];
  CGFloat captionWidth = MIN(140, [self.caption sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width);
  CGFloat desiredWidth = textField ? MAX(140, available * .54) : MAX(120, self.control.intrinsicContentSize.width);
  BOOL vertical = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) ||
      desiredWidth + MIN(captionWidth, 100) + 12 > available;
  self.stack.axis = vertical ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  self.stack.alignment = vertical ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
  self.stack.spacing = vertical ? 4 : 12;
  if (!self.controlWidth) self.controlWidth = [self.control.widthAnchor constraintEqualToConstant:desiredWidth];
  self.controlWidth.constant = desiredWidth;
  self.controlWidth.active = !vertical;
  if (textField) ((UITextField *)self.control).textAlignment = vertical ? NSTextAlignmentNatural : NSTextAlignmentRight;
}
- (CGSize)systemLayoutSizeFittingSize:(CGSize)size withHorizontalFittingPriority:(UILayoutPriority)horizontal verticalFittingPriority:(UILayoutPriority)vertical {
  [self updateLayoutForWidth:size.width];
  return [super systemLayoutSizeFittingSize:size withHorizontalFittingPriority:horizontal verticalFittingPriority:vertical];
}
- (void)layoutSubviews {
  [self updateLayoutForWidth:self.bounds.size.width];
  [super layoutSubviews];
}
@end

#pragma mark - Shared settings information

@interface VMSettingsInfoRow : UIView
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *valueLabel;
@property(nonatomic, strong) UIStackView *captions;
@property(nonatomic) CGFloat accessoryWidth;
- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value disclosure:(BOOL)disclosure;
- (void)updateLayoutForWidth:(CGFloat)width;
@end

@implementation VMSettingsInfoRow
- (instancetype)initWithTitle:(NSString *)title value:(NSString *)value disclosure:(BOOL)disclosure {
  if (!(self = [super initWithFrame:CGRectZero])) return nil;
  self.titleLabel = [UILabel new];
  self.titleLabel.text = title;
  self.titleLabel.font = [VMUIHelper scaledFontOfSize:17 weight:UIFontWeightMedium];
  self.titleLabel.textColor = UIColor.labelColor;
  self.valueLabel = [UILabel new];
  self.valueLabel.text = value;
  self.valueLabel.font = [VMUIHelper scaledFontOfSize:15 weight:UIFontWeightRegular];
  self.valueLabel.textColor = UIColor.secondaryLabelColor;
  for (UILabel *label in @[self.titleLabel, self.valueLabel]) {
    label.adjustsFontForContentSizeCategory = YES;
    label.numberOfLines = 0;
    [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
  }
  [self.titleLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
  [self.valueLabel setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  self.captions = [[UIStackView alloc] initWithArrangedSubviews:@[self.titleLabel, self.valueLabel]];
  self.captions.spacing = 12;
  self.captions.alignment = UIStackViewAlignmentCenter;
  UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[self.captions]];
  content.spacing = 8;
  content.alignment = UIStackViewAlignmentCenter;
  if (disclosure) {
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.forward"]];
    chevron.contentMode = UIViewContentModeScaleAspectFit;
    chevron.tintColor = UIColor.tertiaryLabelColor;
    [chevron.widthAnchor constraintEqualToConstant:10].active = YES;
    [chevron.heightAnchor constraintEqualToConstant:16].active = YES;
    [content addArrangedSubview:chevron];
    self.accessoryWidth = 18;
  }
  content.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [self.heightAnchor constraintGreaterThanOrEqualToConstant:44],
    [content.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
    [content.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
    [content.topAnchor constraintEqualToAnchor:self.topAnchor constant:8],
    [content.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-8]
  ]];
  self.isAccessibilityElement = YES;
  self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", title, value];
  return self;
}
- (void)updateLayoutForWidth:(CGFloat)width {
  CGFloat available = MAX(0, width - 32 - self.accessoryWidth);
  CGFloat titleWidth = ceil([self.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width);
  CGFloat valueWidth = ceil([self.valueLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width);
  BOOL vertical = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory) ||
      (available > 0 && titleWidth + valueWidth + 12 > available);
  self.captions.axis = vertical ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  self.captions.alignment = vertical ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
  self.captions.spacing = vertical ? 4 : 12;
  BOOL rightToLeft = self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
  self.valueLabel.textAlignment = vertical ? NSTextAlignmentNatural :
      (rightToLeft ? NSTextAlignmentLeft : NSTextAlignmentRight);
}
@end

#pragma mark - VMSettingsViewController

static NSString *const VMSettingsGroupPreferenceKey = @"vm_settings_group";

@interface VMSettingsViewController () <
    UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (void)changeAppIcon:(NSString *)iconName;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UIScrollView *groupTabScroll;
@property(nonatomic, strong) UISegmentedControl *groupTabs;
@property(nonatomic, strong) NSLayoutConstraint *groupTabsMinWidth;
@property(nonatomic, strong) UIFont *groupTabFont;
@property(nonatomic) CGFloat groupTabAvailableWidth;
@property(nonatomic) UIUserInterfaceLayoutDirection groupTabLayoutDirection;
@property(nonatomic) BOOL groupTabNeedsReveal;
@property(nonatomic) NSInteger selectedSettingsGroup;
@property(nonatomic) BOOL settingValidationFailed;
@property(nonatomic, strong) UIButton *versionButton;
@property(nonatomic, strong) VMSettingsInfoRow *versionInfoRow;
@property(nonatomic, strong) UIButton *disclaimerButton;
@property(nonatomic, strong) UILabel *disclaimerStateLabel;
@property(nonatomic, strong) UILabel *legalFooterLabel;
@property(nonatomic, strong) UILabel *versionValueLabel;
@property(nonatomic, strong) UIView *legalInfoSection;
@property(nonatomic, strong) NSArray<VMSettingsInfoRow *> *legalInfoRows;

@property(nonatomic, strong) UITextField *startField;
@property(nonatomic, strong) UITextField *endField;
@property(nonatomic, strong) UISegmentedControl *intervalSegment;
@property(nonatomic, strong) UISegmentedControl *themeSegment;
@property(nonatomic, strong) NSString *selectedLanguageCode;  
@property(nonatomic) BOOL applyingLanguage;

@property(nonatomic, strong) UITextField *groupRangeField;
@property(nonatomic, strong) UITextField *resultLimitField;
@property(nonatomic, strong) UITextField *toleranceField;
@property(nonatomic, strong) UISegmentedControl *preventSleepSegment;  
@property(nonatomic, strong) UISegmentedControl *groupAnchorSegment;   
@property(nonatomic, strong) UISegmentedControl *fuzzyRepeatSegment;
@end

@implementation VMSettingsViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = TR(@"Set_Title");
  self.tabBarItem.title = TR(@"Tab_Set");
#if VM_LANGUAGE_TRACE
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
      initWithTitle:TR(@"Audit_Export") style:UIBarButtonItemStylePlain
      target:self action:@selector(exportLanguageTrace)];
  VMLanguageTrace(@"settings-ready");
#endif

  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  NSInteger savedGroup = [def integerForKey:VMSettingsGroupPreferenceKey];
  self.selectedSettingsGroup = savedGroup >= 0 && savedGroup < 3 ? savedGroup : 0;
  self.view.backgroundColor = VMUIHelper.canvasColor;
  [self setupGroupTabs];

  self.tableView =
      [[UITableView alloc] initWithFrame:CGRectZero
                                   style:UITableViewStyleInsetGrouped];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
  self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
  self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  [self.view addSubview:self.tableView];
  [NSLayoutConstraint activateConstraints:@[
    [self.tableView.topAnchor constraintEqualToAnchor:self.groupTabScroll.bottomAnchor],
    [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
  ]];
  if (@available(iOS 15.0, *)) {
    self.tableView.sectionHeaderTopPadding = 0;
  }
  [VMUIHelper styleTableView:self.tableView];
  [VMKeyboardAvoidance installForScrollView:self.tableView];
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 52;
  self.tableView.estimatedSectionHeaderHeight = 0;
  self.tableView.estimatedSectionFooterHeight = 0;
  self.tableView.sectionHeaderHeight = CGFLOAT_MIN;
  self.tableView.sectionFooterHeight = CGFLOAT_MIN;
  self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, CGFLOAT_MIN)];
  if (@available(iOS 15.0, *)) self.tableView.sectionHeaderTopPadding = 0;
  self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];

  self.startField = [self createTextField:@"0x100000000"];
  
  self.endField = [self createTextField:@"0x300000000"];

  self.groupRangeField =
      [self createTextField:TR(@"Set_Group_Range_Placeholder")];
  if (![def objectForKey:@"groupRange"])
    self.groupRangeField.text = @"0x100";
  self.resultLimitField = [self createTextField:@"100"];
  self.resultLimitField.keyboardType = UIKeyboardTypeNumberPad;
  self.toleranceField = [self createTextField:@"0.001"];
  self.toleranceField.keyboardType = UIKeyboardTypeDecimalPad;

  self.groupAnchorSegment = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Group_Anchor"), TR(@"Group_Order")
  ]];
  self.groupAnchorSegment.frame = CGRectMake(0, 0, 120, 30);
  [self.groupAnchorSegment addTarget:self
                              action:@selector(groupAnchorChanged:)
                    forControlEvents:UIControlEventValueChanged];

  self.intervalSegment = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Interval_0_1s"), TR(@"Interval_0_5s"), TR(@"Interval_1_0s")
  ]];
  self.intervalSegment.frame = CGRectMake(0, 0, 180, 30);
  [self.intervalSegment addTarget:self
                           action:@selector(autoSaveAction)
                 forControlEvents:UIControlEventValueChanged];

  self.themeSegment = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Theme_Auto"), TR(@"Theme_Light"), TR(@"Theme_Dark")
  ]];
  self.themeSegment.frame = CGRectMake(0, 0, 250, 30);
  [self.themeSegment addTarget:self
                        action:@selector(themeChanged:)
              forControlEvents:UIControlEventValueChanged];

  self.selectedLanguageCode = [[VMLocalization shared] currentLanguage];

  self.preventSleepSegment = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Seg_Off"), TR(@"Seg_On")
  ]];
  self.preventSleepSegment.frame = CGRectMake(0, 0, 100, 30);
  [self.preventSleepSegment addTarget:self
                               action:@selector(preventSleepChanged:)
                     forControlEvents:UIControlEventValueChanged];

  self.fuzzyRepeatSegment = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Fuz_Repeat_Default"), TR(@"Fuz_Repeat_Custom")
  ]];
  self.fuzzyRepeatSegment.frame = CGRectMake(0, 0, 150, 30);
  [self.fuzzyRepeatSegment addTarget:self
                              action:@selector(fuzzyRepeatChanged:)
                    forControlEvents:UIControlEventValueChanged];

  self.startField.text = [def objectForKey:@"startAddr"] ?: @"0x100000000";
  
  self.endField.text = [def objectForKey:@"endAddr"] ?: @"";
  self.endField.placeholder =
      TR(@"Settings_Auto_By_Mode"); 
  self.groupRangeField.text = [def objectForKey:@"groupRange"] ?: @"0x100";
  self.resultLimitField.text = [[def objectForKey:@"resultLimit"] description] ?: @"100";
  self.toleranceField.text = [[def objectForKey:@"floatTolerance"] description] ?: @"0.001";

  float val = [def floatForKey:@"lockInterval"];
  if (val == 0.1f)
    self.intervalSegment.selectedSegmentIndex = 0;
  else if (val == 1.0f)
    self.intervalSegment.selectedSegmentIndex = 2;
  else
    self.intervalSegment.selectedSegmentIndex = 1;

  NSInteger theme = [def integerForKey:@"app_theme"];
  if (theme >= 0 && theme <= 2)
    self.themeSegment.selectedSegmentIndex = theme;

  BOOL prevSleep = [def boolForKey:@"preventSleep"];
  self.preventSleepSegment.selectedSegmentIndex = prevSleep ? 1 : 0;
  [UIApplication sharedApplication].idleTimerDisabled = prevSleep;

  BOOL fuzzyRepeatEnabled = [def boolForKey:@"fuzzyRepeatCustomEnabled"];
  self.fuzzyRepeatSegment.selectedSegmentIndex = fuzzyRepeatEnabled ? 1 : 0;

  id anchorObj = [def objectForKey:@"groupAnchorMode"];
  BOOL anchorMode = (anchorObj == nil) ? NO : [def boolForKey:@"groupAnchorMode"];
  self.groupAnchorSegment.selectedSegmentIndex = anchorMode ? 0 : 1;  
  [VMMemoryEngine shared].groupAnchorMode = anchorMode;

  for (UIView *control in @[self.startField, self.endField, self.groupRangeField,
      self.resultLimitField, self.toleranceField, self.groupAnchorSegment,
      self.intervalSegment, self.themeSegment, self.preventSleepSegment, self.fuzzyRepeatSegment]) {
    control.translatesAutoresizingMaskIntoConstraints = NO;
    [control.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    if ([control isKindOfClass:UISegmentedControl.class]) {
      UISegmentedControl *segment = (UISegmentedControl *)control;
      [segment setTitleTextAttributes:@{NSFontAttributeName:[VMUIHelper scaledFontOfSize:14 weight:UIFontWeightMedium]}
                            forState:UIControlStateNormal];
      segment.selectedSegmentTintColor = VMUIHelper.cardColor;
    }
  }
  [self setupFooter];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshVersionStatus)
      name:kVMUpdateStateDidChangeNotification object:nil];

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"arrow.counterclockwise"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(confirmReset)];
  self.navigationItem.rightBarButtonItem.accessibilityLabel = TR(@"Set_Reset_Title");
}

- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updateGroupTabMetrics];
  if (self.groupTabNeedsReveal) {
    self.groupTabNeedsReveal = NO;
    [self.groupTabScroll layoutIfNeeded];
    [self revealSelectedSettingsGroupAnimated:NO];
  }
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
  for (VMSettingsInfoRow *row in self.legalInfoRows) {
    [row updateLayoutForWidth:MAX(0, self.tableView.bounds.size.width - 32)];
  }
  [VMUIHelper sizeFooterToFitTableView:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self updateDisclaimerState];
  [self refreshVersionStatus];
  [self.tableView reloadData];
  if (self.navigationController.tabBarItem.badgeValue) {
    self.navigationController.tabBarItem.badgeValue = nil;
  }
}

- (void)setupGroupTabs {
  self.groupTabScroll = [UIScrollView new];
  self.groupTabScroll.translatesAutoresizingMaskIntoConstraints = NO;
  self.groupTabScroll.showsHorizontalScrollIndicator = NO;
  self.groupTabScroll.showsVerticalScrollIndicator = NO;
  self.groupTabScroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
  self.groupTabScroll.accessibilityIdentifier = @"settingsGroupTabs";
  [self.view addSubview:self.groupTabScroll];
  self.groupTabs = [[UISegmentedControl alloc] initWithItems:@[
    TR(@"Set_Search_Section"), TR(@"Set_Sec_Func"), TR(@"Set_Sec_About")
  ]];
  self.groupTabs.translatesAutoresizingMaskIntoConstraints = NO;
  self.groupTabs.apportionsSegmentWidthsByContent = NO;
  self.groupTabs.backgroundColor = UIColor.tertiarySystemFillColor;
  self.groupTabs.selectedSegmentTintColor = [VMUIHelper filledColorForTint:VMUIHelper.accentColor];
  self.groupTabs.selectedSegmentIndex = self.selectedSettingsGroup;
  self.groupTabs.accessibilityLabel = TR(@"Set_Title");
  [self.groupTabs addTarget:self action:@selector(settingsGroupChanged:) forControlEvents:UIControlEventValueChanged];
  [self.groupTabScroll addSubview:self.groupTabs];
  UILayoutGuide *content = self.groupTabScroll.contentLayoutGuide;
  self.groupTabsMinWidth = [self.groupTabs.widthAnchor constraintEqualToConstant:264];
  [NSLayoutConstraint activateConstraints:@[
    [self.groupTabScroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [self.groupTabScroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
    [self.groupTabScroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
    [self.groupTabScroll.heightAnchor constraintEqualToConstant:60],
    [self.groupTabs.topAnchor constraintEqualToAnchor:content.topAnchor constant:8],
    [self.groupTabs.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-8],
    [self.groupTabs.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:16],
    [self.groupTabs.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-16],
    [self.groupTabs.heightAnchor constraintEqualToConstant:44],
    self.groupTabsMinWidth
  ]];
  [self updateGroupTabMetrics];
}

- (void)updateGroupTabMetrics {
  UIFont *font = [[UIFontMetrics defaultMetrics] scaledFontForFont:[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold]
      maximumPointSize:18 compatibleWithTraitCollection:self.traitCollection];
  CGFloat available = MAX(0, self.groupTabScroll.bounds.size.width - 32);
  UIUserInterfaceLayoutDirection direction = self.groupTabs.effectiveUserInterfaceLayoutDirection;
  BOOL fontChanged = ![self.groupTabFont isEqual:font];
  if (!fontChanged && fabs(self.groupTabAvailableWidth - available) <= .5 &&
      self.groupTabLayoutDirection == direction) return;
  self.groupTabFont = font;
  self.groupTabAvailableWidth = available;
  self.groupTabLayoutDirection = direction;
  if (fontChanged) {
    [self.groupTabs setTitleTextAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.secondaryLabelColor}
        forState:UIControlStateNormal];
    [self.groupTabs setTitleTextAttributes:@{NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.whiteColor}
        forState:UIControlStateSelected];
  }
  NSMutableArray<NSNumber *> *widths = [NSMutableArray array];
  CGFloat contentWidth = 0;
  for (NSInteger index = 0; index < self.groupTabs.numberOfSegments; index++) {
    CGFloat width = ceil(MAX(80, [[self.groupTabs titleForSegmentAtIndex:index] sizeWithAttributes:@{NSFontAttributeName:font}].width + 32));
    [widths addObject:@(width)];
    contentWidth += width;
  }
  CGFloat extra = widths.count ? MAX(0, available - contentWidth) / widths.count : 0;
  CGFloat totalWidth = 0;
  for (NSInteger index = 0; index < (NSInteger)widths.count; index++) {
    CGFloat width = widths[index].doubleValue + extra;
    [self.groupTabs setWidth:width forSegmentAtIndex:index];
    totalWidth += width;
  }
  if (fabs(self.groupTabsMinWidth.constant - totalWidth) > .5) self.groupTabsMinWidth.constant = totalWidth;
  self.groupTabNeedsReveal = YES;
}

- (void)revealSelectedSettingsGroupAnimated:(BOOL)animated {
  NSInteger group = self.selectedSettingsGroup;
  if (group < 0 || group >= self.groupTabs.numberOfSegments || self.groupTabScroll.bounds.size.width <= 0) return;
  CGFloat x = 0;
  for (NSInteger index = 0; index < group; index++) x += [self.groupTabs widthForSegmentAtIndex:index];
  CGFloat width = [self.groupTabs widthForSegmentAtIndex:group];
  if (self.groupTabs.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft)
    x = self.groupTabs.bounds.size.width - x - width;
  CGRect segment = CGRectMake(x, 0, width, self.groupTabs.bounds.size.height);
  [self.groupTabScroll scrollRectToVisible:[self.groupTabs convertRect:CGRectInset(segment, -4, 0) toView:self.groupTabScroll] animated:animated];
}

- (void)settingsGroupChanged:(UISegmentedControl *)sender {
  [self selectSettingsGroup:sender.selectedSegmentIndex];
}

- (void)selectSettingsGroup:(NSInteger)index {
  [self loadViewIfNeeded];
  NSInteger group = index >= 0 && index < 3 ? index : 0;
  self.settingValidationFailed = NO;
  [self.view endEditing:YES];
  if (self.settingValidationFailed || self.presentedViewController) {
    self.groupTabs.selectedSegmentIndex = self.selectedSettingsGroup;
    return;
  }
  self.selectedSettingsGroup = group;
  self.groupTabs.selectedSegmentIndex = group;
  [NSUserDefaults.standardUserDefaults setInteger:group forKey:VMSettingsGroupPreferenceKey];
  [self.tableView reloadData];
  [self.tableView layoutIfNeeded];
  self.tableView.contentOffset = CGPointMake(0, -self.tableView.adjustedContentInset.top);
  [self.groupTabScroll layoutIfNeeded];
  [self revealSelectedSettingsGroupAnimated:YES];
}

- (UITextField *)createTextField:(NSString *)ph {
  UITextField *tf =
      [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 160, 30)];
  [VMUIHelper styleTextField:tf];
  tf.textAlignment = NSTextAlignmentNatural;
  tf.placeholder = ph;
  tf.textColor = [UIColor labelColor];
  tf.returnKeyType = UIReturnKeyDone;
  tf.delegate = self;
  [self addDoneButtonTo:tf];
  return tf;
}

#pragma mark - Auto Save Logic

static BOOL VMParseSettingInteger(NSString *text, int base, uint64_t *value) {
  if (!text.length || [text hasPrefix:@"-"] || [text hasPrefix:@"+"]) return NO;
  const char *bytes = text.UTF8String;
  char *end = NULL;
  errno = 0;
  unsigned long long parsed = strtoull(bytes, &end, base);
  if (errno == ERANGE || end == bytes || *end != '\0') return NO;
  *value = parsed;
  return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
  NSUserDefaults *def = NSUserDefaults.standardUserDefaults;
  NSString *text = [textField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSString *key = nil;
  BOOL valid = YES;
  uint64_t value = 0;
  VMMemoryEngine *engine = VMMemoryEngine.shared;
  if (textField == self.startField || textField == self.endField) {
    BOOL isStart = textField == self.startField;
    key = isStart ? @"startAddr" : @"endAddr";
    valid = (!isStart && text.length == 0) || VMParseSettingInteger(text, 16, &value);
    uint64_t other = 0;
    NSString *otherText = [def stringForKey:isStart ? @"endAddr" : @"startAddr"] ?: @"0";
    VMParseSettingInteger(otherText, 16, &other);
    if (valid) valid = isStart ? (other == 0 || value < other) : (value == 0 || value > other);
    if (valid) {
      if (isStart) engine.searchRangeStart = value;
      else engine.searchRangeEnd = value;
    }
  } else if (textField == self.groupRangeField) {
    key = @"groupRange";
    valid = VMParseSettingInteger(text, [text.lowercaseString hasPrefix:@"0x"] ? 16 : 10, &value) && value > 0;
    if (valid) engine.groupSearchRange = value;
  } else if (textField == self.resultLimitField) {
    key = @"resultLimit";
    valid = VMParseSettingInteger(text, 10, &value) && value > 0 && value <= INT_MAX;
    if (valid) engine.resultLimit = (NSInteger)value;
  } else if (textField == self.toleranceField) {
    key = @"floatTolerance";
    NSScanner *scanner = [NSScanner scannerWithString:text];
    scanner.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    double tolerance = 0;
    valid = [scanner scanDouble:&tolerance] && scanner.isAtEnd && isfinite(tolerance) && tolerance >= 0;
    if (!valid) {
      scanner = [NSScanner scannerWithString:text];
      scanner.locale = NSLocale.currentLocale;
      valid = [scanner scanDouble:&tolerance] && scanner.isAtEnd && isfinite(tolerance) && tolerance >= 0;
    }
    if (valid) {
      engine.floatTolerance = tolerance;
      text = [NSString stringWithFormat:@"%.12g", tolerance];
    }
  }
  if (!key) return;
  if (valid) {
    [def setObject:text forKey:key];
    textField.text = text;
  } else {
    self.settingValidationFailed = YES;
    textField.text = [[def objectForKey:key] description] ?: @"";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Set_Invalid_Value")
        message:TR(@"Set_Invalid_Value_Hint") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
    if (!self.presentedViewController) [self presentViewController:alert animated:YES completion:nil];
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [textField resignFirstResponder];
  return YES;
}

- (void)autoSaveAction {
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  float v = 0.5f;
  if (self.intervalSegment.selectedSegmentIndex == 0)
    v = 0.1f;
  if (self.intervalSegment.selectedSegmentIndex == 2)
    v = 1.0f;
  [def setFloat:v forKey:@"lockInterval"];
  [def synchronize];
}

- (void)themeChanged:(UISegmentedControl *)sender {
  NSInteger idx = sender.selectedSegmentIndex;
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  [def setInteger:idx forKey:@"app_theme"];
  [def synchronize];

  if (@available(iOS 13.0, *)) {
    UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified;
    if (idx == 1)
      style = UIUserInterfaceStyleLight;
    if (idx == 2)
      style = UIUserInterfaceStyleDark;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
      window.overrideUserInterfaceStyle = style;
    }
  }
}

- (void)preventSleepChanged:(UISegmentedControl *)sender {
  BOOL isOn = (sender.selectedSegmentIndex == 1);
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  [def setBool:isOn forKey:@"preventSleep"];
  [def synchronize];

  [UIApplication sharedApplication].idleTimerDisabled = isOn;
}

- (void)fuzzyRepeatChanged:(UISegmentedControl *)sender {
  BOOL isCustom = (sender.selectedSegmentIndex == 1);
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  [def setBool:isCustom forKey:@"fuzzyRepeatCustomEnabled"];
  [def synchronize];
}

- (void)groupAnchorChanged:(UISegmentedControl *)sender {
  
  BOOL anchorMode = (sender.selectedSegmentIndex == 0);
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  [def setBool:anchorMode forKey:@"groupAnchorMode"];
  [def synchronize];
  
  [VMMemoryEngine shared].groupAnchorMode = anchorMode;
}

- (NSString *)displayNameForLanguageCode:(NSString *)code {
  if ([code isEqualToString:@"en"]) return @"English";
  if ([code isEqualToString:@"zh-Hans"]) return @"简体中文";
  if ([code isEqualToString:@"zh-Hant"]) return @"繁體中文";
  if ([code isEqualToString:@"ja"]) return @"日本語";
  if ([code isEqualToString:@"ko"]) return @"한국어";
  if ([code isEqualToString:@"vi"]) return @"Tiếng Việt";
  if ([code isEqualToString:@"th"]) return @"ไทย";
  if ([code isEqualToString:@"ru"]) return @"Русский";
  if ([code isEqualToString:@"es"]) return @"Español";
  if ([code isEqualToString:@"pt"]) return @"Português";
  if ([code isEqualToString:@"fr"]) return @"Français";
  if ([code isEqualToString:@"de"]) return @"Deutsch";
  if ([code isEqualToString:@"ar"]) return @"العربية";
  return TR(@"Lang_Auto");  
}

- (void)showLanguagePicker {
  UIAlertController *alert = [UIAlertController 
      alertControllerWithTitle:TR(@"Set_Lang")
                       message:nil
                preferredStyle:UIAlertControllerStyleActionSheet];
  
  NSArray *languages = @[
    @[@"Auto", TR(@"Lang_Auto")],
    @[@"en", @"English"],
    @[@"zh-Hans", @"简体中文"],
    @[@"zh-Hant", @"繁體中文"],
    @[@"ja", @"日本語"],
    @[@"ko", @"한국어"],
    @[@"vi", @"Tiếng Việt"],
    @[@"th", @"ไทย"],
    @[@"ru", @"Русский"],
    @[@"es", @"Español"],
    @[@"pt", @"Português"],
    @[@"fr", @"Français"],
    @[@"de", @"Deutsch"],
    @[@"ar", @"العربية"],
  ];
  
  for (NSArray *lang in languages) {
    NSString *code = lang[0];
    NSString *name = lang[1];
    
    UIAlertAction *action = [UIAlertAction 
        actionWithTitle:name
                  style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *a) {
                  [self applyLanguage:code];
                }];
    
    if ([code isEqualToString:self.selectedLanguageCode]) {
      [action setValue:[UIImage systemImageNamed:@"checkmark"] forKey:@"image"];
    }
    
    [alert addAction:action];
  }
  
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") 
                                            style:UIAlertActionStyleCancel 
                                          handler:nil]];
  
  if (alert.popoverPresentationController) {
    alert.popoverPresentationController.sourceView = self.tableView;
    alert.popoverPresentationController.sourceRect = 
        [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:1]];
  }
  
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyLanguage:(NSString *)code {
  if (self.applyingLanguage) return;
  VMRootViewController *root = (id)self.tabBarController;
  if (![root isKindOfClass:VMRootViewController.class]) return;
  self.applyingLanguage = YES;
  VMLanguageTrace(@"apply-begin");
  VMLanguageWatchMainQueue();
  [self.view endEditing:YES];
  self.selectedLanguageCode = code;
  [[VMLocalization shared] setLanguage:code];
  VMLanguageTrace(@"language-saved");
  VMRefreshAfterDismissal(self, ^{
    if (self.tabBarController == root && root.viewIfLoaded.window) {
      VMLanguageTrace(@"refresh-begin");
      [root refreshLocalizedPages];
      VMLanguageTrace(@"refresh-complete");
      dispatch_async(dispatch_get_main_queue(), ^{ VMLanguageTrace(@"next-runloop"); });
      UINotificationFeedbackGenerator *gen = [[UINotificationFeedbackGenerator alloc] init];
      [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
    } else {
      VMLanguageTrace(@"refresh-skipped-detached-page");
    }
    self.applyingLanguage = NO;
  });
}

#if VM_LANGUAGE_TRACE
- (void)exportLanguageTrace {
  NSURL *url = VMLanguageTraceURL();
  if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return;
  UIActivityViewController *share = [[UIActivityViewController alloc]
      initWithActivityItems:@[url] applicationActivities:nil];
  share.popoverPresentationController.barButtonItem = self.navigationItem.leftBarButtonItem;
  [self presentViewController:share animated:YES completion:nil];
}
#endif

- (void)setupFooter {
  UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 120)];
  footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;

  self.legalInfoSection = [UIView new];
  self.legalInfoSection.accessibilityIdentifier = @"settingsLegalSection";
  self.legalInfoSection.backgroundColor = VMUIHelper.cardColor;
  self.legalInfoSection.layer.cornerRadius = 16;
  self.legalInfoSection.layer.cornerCurve = kCACornerCurveContinuous;
  self.legalInfoSection.clipsToBounds = YES;
  self.legalInfoSection.translatesAutoresizingMaskIntoConstraints = NO;
  [footer addSubview:self.legalInfoSection];

  self.versionButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.versionButton.accessibilityLabel = TR(@"Set_Legal_Version");
  self.versionButton.accessibilityHint = TR(@"Set_Check_Update");
  self.versionButton.accessibilityIdentifier = @"settingsVersion";
  [self.versionButton addTarget:self action:@selector(checkForUpdate) forControlEvents:UIControlEventTouchUpInside];
  VMSettingsInfoRow *versionRow = [[VMSettingsInfoRow alloc] initWithTitle:TR(@"Set_Legal_Version")
      value:@"" disclosure:YES];
  self.versionInfoRow = versionRow;
  versionRow.accessibilityElementsHidden = YES;
  versionRow.userInteractionEnabled = NO;
  versionRow.translatesAutoresizingMaskIntoConstraints = NO;
  self.versionValueLabel = versionRow.valueLabel;
  self.versionValueLabel.accessibilityIdentifier = @"settingsVersionValue";
  [self.versionButton addSubview:versionRow];
  [NSLayoutConstraint activateConstraints:@[
    [versionRow.leadingAnchor constraintEqualToAnchor:self.versionButton.leadingAnchor],
    [versionRow.trailingAnchor constraintEqualToAnchor:self.versionButton.trailingAnchor],
    [versionRow.topAnchor constraintEqualToAnchor:self.versionButton.topAnchor],
    [versionRow.bottomAnchor constraintEqualToAnchor:self.versionButton.bottomAnchor]
  ]];

  self.disclaimerButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.disclaimerButton.accessibilityLabel = TR(@"Dis_Title");
  self.disclaimerButton.accessibilityIdentifier = @"settingsDisclaimer";
  [self.disclaimerButton addTarget:self action:@selector(showDisclaimer) forControlEvents:UIControlEventTouchUpInside];
  VMSettingsInfoRow *disclaimerRow = [[VMSettingsInfoRow alloc] initWithTitle:TR(@"Dis_Title")
      value:@"" disclosure:YES];
  disclaimerRow.accessibilityElementsHidden = YES;
  disclaimerRow.userInteractionEnabled = NO;
  disclaimerRow.translatesAutoresizingMaskIntoConstraints = NO;
  self.disclaimerStateLabel = disclaimerRow.valueLabel;
  [self.disclaimerButton addSubview:disclaimerRow];
  [NSLayoutConstraint activateConstraints:@[
    [disclaimerRow.leadingAnchor constraintEqualToAnchor:self.disclaimerButton.leadingAnchor],
    [disclaimerRow.trailingAnchor constraintEqualToAnchor:self.disclaimerButton.trailingAnchor],
    [disclaimerRow.topAnchor constraintEqualToAnchor:self.disclaimerButton.topAnchor],
    [disclaimerRow.bottomAnchor constraintEqualToAnchor:self.disclaimerButton.bottomAnchor]
  ]];

  VMSettingsInfoRow *creditsRow = [[VMSettingsInfoRow alloc] initWithTitle:TR(@"Set_Legal_Thanks")
      value:@"Gey1ist, Xiczee, Zoomin" disclosure:NO];
  creditsRow.accessibilityIdentifier = @"settingsCredits";
  VMSettingsInfoRow *technologyRow = [[VMSettingsInfoRow alloc] initWithTitle:TR(@"Set_Legal_Technology")
      value:@"Theos & Mach API" disclosure:NO];
  technologyRow.accessibilityIdentifier = @"settingsTechnology";
  VMSettingsInfoRow *licenseRow = [[VMSettingsInfoRow alloc] initWithTitle:TR(@"Set_Legal_License")
      value:@"GPL-3.0" disclosure:NO];
  licenseRow.accessibilityIdentifier = @"settingsLicense";
  self.legalInfoRows = @[versionRow, disclaimerRow, creditsRow, technologyRow, licenseRow];

  self.legalFooterLabel = [UILabel new];
  self.legalFooterLabel.numberOfLines = 0;
  self.legalFooterLabel.textAlignment = NSTextAlignmentCenter;
  self.legalFooterLabel.font = [VMUIHelper scaledFontOfSize:12 weight:UIFontWeightRegular];
  self.legalFooterLabel.adjustsFontForContentSizeCategory = YES;
  self.legalFooterLabel.textColor = UIColor.secondaryLabelColor;
  self.legalFooterLabel.text = TR(@"Set_Legal_Copyright");
  self.legalFooterLabel.translatesAutoresizingMaskIntoConstraints = NO;
  UIView *copyrightRow = [UIView new];
  [copyrightRow addSubview:self.legalFooterLabel];
  [NSLayoutConstraint activateConstraints:@[
    [self.legalFooterLabel.leadingAnchor constraintEqualToAnchor:copyrightRow.leadingAnchor constant:16],
    [self.legalFooterLabel.trailingAnchor constraintEqualToAnchor:copyrightRow.trailingAnchor constant:-16],
    [self.legalFooterLabel.topAnchor constraintEqualToAnchor:copyrightRow.topAnchor constant:10],
    [self.legalFooterLabel.bottomAnchor constraintEqualToAnchor:copyrightRow.bottomAnchor constant:-10]
  ]];

  UIStackView *stack = [UIStackView new];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  NSArray<UIView *> *rows = @[self.versionButton, self.disclaimerButton, creditsRow, technologyRow, licenseRow, copyrightRow];
  CGFloat pixel = 1.0 / MAX(1, UIScreen.mainScreen.scale);
  for (NSUInteger index = 0; index < rows.count; index++) {
    [stack addArrangedSubview:rows[index]];
    if (index + 1 < rows.count) {
      UIView *separatorRow = [UIView new];
      UIView *separator = [UIView new];
      separator.backgroundColor = UIColor.separatorColor;
      separator.translatesAutoresizingMaskIntoConstraints = NO;
      [separatorRow addSubview:separator];
      [NSLayoutConstraint activateConstraints:@[
        [separator.leadingAnchor constraintEqualToAnchor:separatorRow.leadingAnchor constant:16],
        [separator.trailingAnchor constraintEqualToAnchor:separatorRow.trailingAnchor],
        [separator.topAnchor constraintEqualToAnchor:separatorRow.topAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:separatorRow.bottomAnchor],
        [separator.heightAnchor constraintEqualToConstant:pixel]
      ]];
      [stack addArrangedSubview:separatorRow];
    }
  }
  [self.legalInfoSection addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [self.legalInfoSection.topAnchor constraintEqualToAnchor:footer.topAnchor constant:16],
    [self.legalInfoSection.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-16],
    [self.legalInfoSection.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:16],
    [self.legalInfoSection.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-16],
    [stack.topAnchor constraintEqualToAnchor:self.legalInfoSection.topAnchor],
    [stack.bottomAnchor constraintEqualToAnchor:self.legalInfoSection.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:self.legalInfoSection.leadingAnchor],
    [stack.trailingAnchor constraintEqualToAnchor:self.legalInfoSection.trailingAnchor]
  ]];
  self.tableView.tableFooterView = footer;
  [self updateDisclaimerState];
  [self refreshVersionStatus];
}

- (void)refreshVersionStatus {
  VMUpdateCheckState state = VMUpdateManager.shared.checkState;
  NSString *statusKey = @"Set_Check_Update";
  switch (state) {
    case VMUpdateCheckStateChecking: statusKey = @"Update_Checking"; break;
    case VMUpdateCheckStateCurrent: statusKey = @"Status_Latest"; break;
    case VMUpdateCheckStateAvailable: statusKey = @"Status_New"; break;
    case VMUpdateCheckStateFailed: statusKey = @"Update_Check_Failed"; break;
    case VMUpdateCheckStateIdle: break;
  }
  NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
  self.versionValueLabel.text = [NSString stringWithFormat:@"v%@ · %@", version, TR(statusKey)];
  self.versionValueLabel.textColor = state == VMUpdateCheckStateAvailable ? VMUIHelper.accentColor : UIColor.secondaryLabelColor;
  self.versionButton.enabled = state != VMUpdateCheckStateChecking;
  self.versionButton.accessibilityValue = self.versionValueLabel.text;
  [self.versionInfoRow updateLayoutForWidth:MAX(0, self.tableView.bounds.size.width - 32)];
  [self.view setNeedsLayout];
}

- (void)checkForUpdate {
  self.settingValidationFailed = NO;
  [self.view endEditing:YES];
  if (self.settingValidationFailed || self.presentedViewController) return;
  VMUpdateManager *manager = VMUpdateManager.shared;
  if (manager.checkState == VMUpdateCheckStateChecking) return;
  if (manager.checkState == VMUpdateCheckStateAvailable) {
    [manager showUpdateAlertFromViewController:self];
    return;
  }
  __weak VMSettingsViewController *weakSelf = self;
  [manager checkForUpdateManual:YES completion:^{ [weakSelf refreshVersionStatus]; }];
}

- (void)updateDisclaimerState {
  NSString *state = TR([NSUserDefaults.standardUserDefaults boolForKey:@"has_agreed_disclaimer"] ? @"Dis_Agreed" : @"Dis_Not_Agreed");
  self.disclaimerStateLabel.text = state;
  self.disclaimerButton.accessibilityValue = state;
}

- (void)showDisclaimer {
  self.settingValidationFailed = NO;
  [self.view endEditing:YES];
  if (self.settingValidationFailed || self.presentedViewController) return;
  if ([self.tabBarController isKindOfClass:VMRootViewController.class]) {
    [(VMRootViewController *)self.tabBarController showDisclaimer:YES];
  }
}

#pragma mark - TableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 3; 
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return section == self.selectedSettingsGroup ? (section == 2 ? 5 : 6) : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
  return CGFLOAT_MIN;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
  return CGFLOAT_MIN;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSArray *searchTitles = @[@"Set_Start", @"Set_End", @"Set_Group_Range", @"Set_Group_Mode", @"Set_Res_Limit", @"Set_Float_Tol"];
  NSArray *searchControls = @[self.startField, self.endField, self.groupRangeField, self.groupAnchorSegment, self.resultLimitField, self.toleranceField];
  NSArray *behaviorTitles = @[@"Set_Rate", @"Set_Theme", @"Set_Fuzzy_Repeat", @"Set_Lang", @"Set_Prev_Sleep"];
  NSArray *behaviorControls = @[self.intervalSegment, self.themeSegment, self.fuzzyRepeatSegment, NSNull.null, self.preventSleepSegment];
  BOOL hasControl = indexPath.section == 0 || (indexPath.section == 1 && indexPath.row != 3 && indexPath.row < 5);
  if (hasControl) {
    NSString *identifier = [NSString stringWithFormat:@"control-%ld-%ld", (long)indexPath.section, (long)indexPath.row];
    VMSettingControlCell *controlCell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!controlCell) controlCell = [[VMSettingControlCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
    NSArray *titles = indexPath.section == 0 ? searchTitles : behaviorTitles;
    NSArray *controls = indexPath.section == 0 ? searchControls : behaviorControls;
    [controlCell configureTitle:TR(titles[indexPath.row]) control:controls[indexPath.row]];
    return controlCell;
  }
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c"];
  if (!cell)
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                  reuseIdentifier:@"c"];

  cell.textLabel.font = [VMUIHelper scaledFontOfSize:16 weight:UIFontWeightMedium];
  cell.textLabel.adjustsFontForContentSizeCategory = YES;
  cell.textLabel.numberOfLines = 0;
  cell.detailTextLabel.font = [VMUIHelper scaledFontOfSize:13 weight:UIFontWeightRegular];
  cell.detailTextLabel.adjustsFontForContentSizeCategory = YES;
  cell.backgroundColor = VMUIHelper.cardColor;
  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.accessoryView = nil;
  cell.accessoryType = UITableViewCellAccessoryNone;
  cell.imageView.image = nil;
  cell.detailTextLabel.text = nil;
  cell.textLabel.textColor = UIColor.labelColor;
  cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;

  if (indexPath.section == 0) {
    if (indexPath.row == 0) {
      cell.textLabel.text = TR(@"Set_Start");
      cell.accessoryView = self.startField;
    } else if (indexPath.row == 1) {
      cell.textLabel.text = TR(@"Set_End");
      cell.accessoryView = self.endField;
    } else if (indexPath.row == 2) {
      cell.textLabel.text = TR(@"Set_Group_Range");
      cell.accessoryView = self.groupRangeField;
    } else if (indexPath.row == 3) {
      cell.textLabel.text = TR(@"Set_Group_Mode");
      cell.accessoryView = self.groupAnchorSegment;
    } else if (indexPath.row == 4) {
      cell.textLabel.text = TR(@"Set_Res_Limit");
      cell.accessoryView = self.resultLimitField;
    } else if (indexPath.row == 5) {
      cell.textLabel.text = TR(@"Set_Float_Tol");
      cell.accessoryView = self.toleranceField;
    }
  }
  
  else if (indexPath.section == 1) {
    if (indexPath.row == 0) {
      cell.textLabel.text = TR(@"Set_Rate");
      cell.accessoryView = self.intervalSegment;
    } else if (indexPath.row == 1) {
      cell.textLabel.text = TR(@"Set_Theme");
      cell.accessoryView = self.themeSegment;
    } else if (indexPath.row == 2) {
      cell.textLabel.text = TR(@"Set_Fuzzy_Repeat");
      cell.accessoryView = self.fuzzyRepeatSegment;
    } else if (indexPath.row == 3) {
      cell.textLabel.text = TR(@"Set_Lang");
      cell.accessoryView = nil;
      cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
      cell.selectionStyle = UITableViewCellSelectionStyleDefault;
      cell.detailTextLabel.text = [self displayNameForLanguageCode:self.selectedLanguageCode];
    } else if (indexPath.row == 4) {
      cell.textLabel.text = TR(@"Set_Prev_Sleep");
      cell.accessoryView = self.preventSleepSegment;
    }
  }
  
  else if (indexPath.section == 2) {
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.tintColor = [UIColor labelColor]; 

    if (indexPath.row == 0) {  
      cell.textLabel.text = TR(@"Set_Github");
      cell.detailTextLabel.text = @"Vaenshine";
      cell.imageView.image =
          [VMIconHelper compatibleSystemImageNamed:
                            @"chevron.left.forwardslash.chevron.right"];
    }
    
    else if (indexPath.row == 1) {  
      cell.textLabel.text = TR(@"Set_TG");
      cell.detailTextLabel.text = @"@VansonMod";
      cell.detailTextLabel.textColor = [UIColor systemOrangeColor];
      cell.imageView.image = [UIImage systemImageNamed:@"paperplane.fill"];
      cell.imageView.tintColor = [UIColor colorWithRed:0.0
                                                 green:0.53
                                                  blue:0.8
                                                 alpha:1.0];
    }
    
    else if (indexPath.row == 2) {  
      cell.textLabel.text = TR(@"Set_TS_Comm");
      cell.detailTextLabel.text = @"@iOS_TrollStore";
      cell.imageView.image = [UIImage systemImageNamed:@"paperplane.fill"];
      cell.imageView.tintColor = [UIColor systemBlueColor];
    } else if (indexPath.row == 3) {  
      cell.textLabel.text = @"iOSGods";
      cell.detailTextLabel.text = TR(@"Lab_Community");
      cell.imageView.image = [UIImage systemImageNamed:@"globe"];
      cell.imageView.tintColor = [UIColor systemPurpleColor];
    }
    
    else if (indexPath.row == 4) {
      cell.textLabel.text = TR(@"Set_AppIcon");
      
      NSString *curr = [[UIApplication sharedApplication] alternateIconName];
      UIImage *rawImage = nil;
      if (curr == nil) {
        cell.detailTextLabel.text = TR(@"Icon_Default");
        NSString *path =
            [[NSBundle mainBundle] pathForResource:@"AppIcon60x60@2x"
                                            ofType:@"png"];
        rawImage = [UIImage imageWithContentsOfFile:path]
                       ?: [UIImage systemImageNamed:@"app.badge"];
      } else {
        NSString *iconKey =
            [curr stringByReplacingOccurrencesOfString:@"Icon-"
                                            withString:@"Icon_"];
        NSString *localizedIconName = TR(iconKey);
        cell.detailTextLabel.text = [localizedIconName isEqualToString:iconKey]
                                        ? curr
                                        : localizedIconName;

        NSString *file = [NSString stringWithFormat:@"%@@2x", curr];
        NSString *path = [[NSBundle mainBundle] pathForResource:file
                                                         ofType:@"png"];
        rawImage = [UIImage imageWithContentsOfFile:path]
                       ?: [UIImage systemImageNamed:@"app.badge.checkmark"];
      }

      if (rawImage) {
        CGSize standardSize = CGSizeMake(29, 29);
        UIGraphicsBeginImageContextWithOptions(standardSize, NO,
                                               [UIScreen mainScreen].scale);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 29, 29)
                                    cornerRadius:6] addClip];
        [rawImage drawInRect:CGRectMake(0, 0, 29, 29)];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
      }
      cell.imageView.layer.cornerRadius = 0;
      cell.imageView.clipsToBounds = NO;
      cell.imageView.tintColor = nil;
    }

  }

  if (indexPath.section == 1 && indexPath.row == 5) {
    cell.textLabel.text = TR(@"Set_Tab_Reorder");
    cell.imageView.image = [UIImage systemImageNamed:@"arrow.up.arrow.down"];
    cell.imageView.tintColor = VMUIHelper.accentColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
  }
  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  if (indexPath.section != self.selectedSettingsGroup) return;

  if (indexPath.section == 1) {
    
    if (indexPath.row == 3) {
      [self showLanguagePicker];
    } else if (indexPath.row == 5 && [self.tabBarController isKindOfClass:VMRootViewController.class]) {
      [(VMRootViewController *)self.tabBarController showTabReorder];
    }
  } else if (indexPath.section == 2) {
    if (indexPath.row == 0)
      [[UIApplication sharedApplication]
                    openURL:[NSURL
                                URLWithString:
                                    @"https://github.com/vaenshine/VansonMod/"]
                    options:@{}
          completionHandler:nil];
    else if (indexPath.row == 1)
      [[UIApplication sharedApplication]
                    openURL:[NSURL URLWithString:@"https://t.me/VansonMod"]
                    options:@{}
          completionHandler:nil];
    
    else if (indexPath.row == 2)
      [[UIApplication sharedApplication]
                    openURL:[NSURL URLWithString:@"https://t.me/iOS_TrollStore"]
                    options:@{}
          completionHandler:nil];
    else if (indexPath.row == 3)
      [[UIApplication sharedApplication]
                    openURL:[NSURL URLWithString:@"https://iosgods.com/"]
                    options:@{}
          completionHandler:nil];
    else if (indexPath.row == 4) { 
      [self showIconSelection];
    }
  }
}

- (void)showIconSelection {
  UIViewController *contentVC = [[UIViewController alloc] init];
  contentVC.preferredContentSize = CGSizeMake(300, 320); 
  contentVC.view.backgroundColor = [UIColor systemBackgroundColor];

  UITableView *tv =
      [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 300, 320)
                                   style:UITableViewStylePlain];
  tv.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
  [contentVC.view addSubview:tv];

  VMIconDataSource *ds = [[VMIconDataSource alloc] init];

  objc_setAssociatedObject(contentVC, "iconDS", ds,
                           OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(tv, "hostVC", contentVC, OBJC_ASSOCIATION_ASSIGN);
  objc_setAssociatedObject(contentVC, "settingsVC", self,
                           OBJC_ASSOCIATION_ASSIGN);

  tv.dataSource = ds;
  tv.delegate = ds;

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Set_AppIcon")
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert setValue:contentVC forKey:@"contentViewController"];

  objc_setAssociatedObject(contentVC, "alertController", alert,
                           OBJC_ASSOCIATION_ASSIGN);

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    UITableViewCell *cell = [self.tableView
        cellForRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:2]];
    alert.popoverPresentationController.sourceView = cell ?: self.tableView;
    alert.popoverPresentationController.sourceRect = cell ? cell.bounds :
        CGRectMake(CGRectGetMidX(self.tableView.bounds), CGRectGetMidY(self.tableView.bounds), 1, 1);
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)joinGroup:(NSString *)groupUin key:(NSString *)key {
  NSString *urlStr =
      [NSString stringWithFormat:
                    @"mqqapi://card/"
                    @"show_pslcard?src_type=internal&version=1&uin=%@&authSig=%"
                    @"@&card_type=group&source=external&jump_from=webapi",
                    groupUin, key];
  NSURL *url = [NSURL URLWithString:urlStr];
  if ([[UIApplication sharedApplication] canOpenURL:url]) {
    [[UIApplication sharedApplication] openURL:url
                                       options:@{}
                             completionHandler:nil];
    return YES;
  } else {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:TR(@"Alert_Fail")
                         message:TR(@"Err_QQ_Not_Installed")
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    return NO;
  }
}

- (void)changeAppIcon:(NSString *)iconName {
  
  SEL selector =
      NSSelectorFromString(@"_setAlternateIconName:completionHandler:");

  if ([[UIApplication sharedApplication] respondsToSelector:selector]) {
    
    void (^completionBlock)(NSError *) = ^(NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        if (!error) [[NSNotificationCenter defaultCenter] postNotificationName:@"VMApplicationIconDidChange" object:nil];
        
        [self showToast:TR(@"Msg_Saved")];
      });
    };

    ((void (*)(id, SEL, id, id))objc_msgSend)(
        [UIApplication sharedApplication], selector, iconName, completionBlock);

  } else {
    
    [[UIApplication sharedApplication]
        setAlternateIconName:iconName
           completionHandler:^(NSError *_Nullable error) {
             dispatch_async(dispatch_get_main_queue(), ^{
               [self.tableView reloadData];
        if (!error) [[NSNotificationCenter defaultCenter] postNotificationName:@"VMApplicationIconDidChange" object:nil];
             });
           }];
  }
}

- (void)showToast:(NSString *)message {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:nil
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:alert animated:YES completion:nil];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
      });
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
  [VMUIHelper styleConfirmationItem:done];
  textField.inputAccessoryView = toolbar;
}

- (void)confirmReset {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Set_Reset_Title")
                                          message:TR(@"Set_Reset_Msg")
                                   preferredStyle:UIAlertControllerStyleAlert];

  // Build a custom content VC with a switch
  UIViewController *contentVC = [[UIViewController alloc] init];
  UISwitch *cleanSwitch = [[UISwitch alloc] init];
  cleanSwitch.on = NO;
  UILabel *cleanLabel = [[UILabel alloc] init];
  cleanLabel.text = TR(@"Set_Reset_Clean_Files");
  cleanLabel.font = [UIFont systemFontOfSize:13];
  cleanLabel.textColor = [UIColor labelColor];
  cleanLabel.numberOfLines = 0;

  UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[cleanSwitch, cleanLabel]];
  stack.axis = UILayoutConstraintAxisHorizontal;
  stack.spacing = 10;
  stack.alignment = UIStackViewAlignmentCenter;
  stack.translatesAutoresizingMaskIntoConstraints = NO;

  [cleanSwitch setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [cleanSwitch setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [cleanLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];

  [contentVC.view addSubview:stack];
  [NSLayoutConstraint activateConstraints:@[
    [stack.leadingAnchor constraintEqualToAnchor:contentVC.view.leadingAnchor constant:12],
    [stack.trailingAnchor constraintEqualToAnchor:contentVC.view.trailingAnchor constant:-12],
    [stack.topAnchor constraintEqualToAnchor:contentVC.view.topAnchor constant:8],
    [stack.bottomAnchor constraintEqualToAnchor:contentVC.view.bottomAnchor constant:-8],
  ]];
  contentVC.preferredContentSize = CGSizeMake(270, 55);
  [alert setValue:contentVC forKey:@"contentViewController"];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Confirm")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
                                            [self performResetWithCleanFiles:cleanSwitch.isOn];
                                          }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)performResetWithCleanFiles:(BOOL)cleanFiles {
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];

  [def setObject:@"0x100000000" forKey:@"startAddr"];
  
  [def setObject:@"" forKey:@"endAddr"];
  [def setObject:@"0x100" forKey:@"groupRange"];
  [def setObject:@"100" forKey:@"resultLimit"];
  [def setObject:@"0.001" forKey:@"floatTolerance"];
  [def setFloat:0.5f forKey:@"lockInterval"];
  [def setInteger:1 forKey:@"app_theme"]; 
  [def setObject:@"Auto" forKey:@"user_lang"];
  [def setBool:NO forKey:@"preventSleep"];
  [def setBool:NO forKey:@"fuzzyRepeatCustomEnabled"];
  [def setBool:NO forKey:@"groupAnchorMode"];  
  [def synchronize];

  if (cleanFiles) {
    // Only clean .vm* files, preserve user backups
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *rootPath = [docPath stringByAppendingPathComponent:@"VansonMod"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:rootPath]) {
      NSArray *vmExts = @[@".vmpt", @".vmrva", @".vmsig", @".vmvapt", @".vmsc", @".vmps"];
      NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:rootPath];
      NSString *file;
      NSMutableArray *toDelete = [NSMutableArray array];
      while ((file = [enumerator nextObject])) {
        for (NSString *ext in vmExts) {
          if ([file hasSuffix:ext]) {
            [toDelete addObject:[rootPath stringByAppendingPathComponent:file]];
            break;
          }
        }
      }
      for (NSString *path in toDelete) {
        [fm removeItemAtPath:path error:nil];
      }
    }
  }

  [VMMemoryEngine shared].groupSearchRange = 0x100;
  [VMMemoryEngine shared].resultLimit = 100;
  [VMMemoryEngine shared].floatTolerance = 0.001;
  [VMMemoryEngine shared].groupAnchorMode = NO;  
  [VMMemoryEngine shared].searchRangeStart = 0x100000000ULL;
  [VMMemoryEngine shared].searchRangeEnd = 0;

  self.startField.text = @"0x100000000";
  
  self.endField.text = @"";
  self.groupRangeField.text = @"0x100";
  self.resultLimitField.text = @"100";
  self.toleranceField.text = @"0.001";
  self.intervalSegment.selectedSegmentIndex = 1; 
  self.themeSegment.selectedSegmentIndex = 1;    
  self.selectedLanguageCode = @"Auto";           
  self.preventSleepSegment.selectedSegmentIndex = 0;  
  self.groupAnchorSegment.selectedSegmentIndex = 1;
  self.fuzzyRepeatSegment.selectedSegmentIndex = 0;
  [UIApplication sharedApplication].idleTimerDisabled = NO;

  [self.tableView reloadData];

  if (@available(iOS 13.0, *)) {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
      window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }
  }

  [[VMLocalization shared] setLanguage:@"Auto"];
  self.selectedLanguageCode = @"Auto";

  if (cleanFiles) {
    [self showToast:TR(@"Msg_Reset_Done")];
  } else {
    [self showToast:TR(@"Msg_Reset_Done_No_Clean")];
  }

  [self applyLanguage:@"Auto"];
}

@end
