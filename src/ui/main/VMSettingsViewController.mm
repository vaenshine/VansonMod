#import "VMSettingsViewController.h"
#import "../../core/VMRootViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/managers/VMUpdateManager.h"
#import "include/VMIconHelper.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

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

#pragma mark - VMSettingsViewController

@interface VMSettingsViewController () <
    UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (void)changeAppIcon:(NSString *)iconName;
@property(nonatomic, strong) UITableView *tableView;

@property(nonatomic, strong) UITextField *startField;
@property(nonatomic, strong) UITextField *endField;
@property(nonatomic, strong) UISegmentedControl *intervalSegment;
@property(nonatomic, strong) UISegmentedControl *themeSegment;
@property(nonatomic, strong) NSString *selectedLanguageCode;  

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

  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];

  self.tableView =
      [[UITableView alloc] initWithFrame:self.view.bounds
                                   style:UITableViewStyleInsetGrouped];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
  [self.view addSubview:self.tableView];
  if (@available(iOS 15.0, *)) {
    self.tableView.sectionHeaderTopPadding = 0;
  }
  self.tableView.tableHeaderView =
      [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, CGFLOAT_MIN)];

  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];

  self.startField = [self createTextField:@"0x100000000"];
  
  self.endField = [self createTextField:@"0x300000000"];

  self.groupRangeField =
      [self createTextField:TR(@"Set_Group_Range_Placeholder")];
  if (![def objectForKey:@"groupRange"])
    self.groupRangeField.text = @"0x100";
  self.resultLimitField = [self createTextField:@"100"];
  self.resultLimitField.keyboardType = UIKeyboardTypeNumberPad;
  self.toleranceField = [self createTextField:@"0.0001"];
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
  self.resultLimitField.text = [def objectForKey:@"resultLimit"] ?: @"100";
  self.toleranceField.text = [def objectForKey:@"floatTolerance"] ?: @"0.0001";

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

  [self setupFooter];

  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"arrow.counterclockwise"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(confirmReset)];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.tableView reloadData];
  if (self.navigationController.tabBarItem.badgeValue) {
    self.navigationController.tabBarItem.badgeValue = nil;
  }
}

- (UITextField *)createTextField:(NSString *)ph {
  UITextField *tf =
      [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 160, 30)];
  tf.textAlignment = NSTextAlignmentRight;
  tf.placeholder = ph;
  tf.textColor = [UIColor systemGrayColor];
  tf.returnKeyType = UIReturnKeyDone;
  tf.delegate = self;
  [self addDoneButtonTo:tf];
  return tf;
}

#pragma mark - Auto Save Logic

- (void)textFieldDidEndEditing:(UITextField *)textField {
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  if (textField == self.startField) {
    [def setObject:textField.text forKey:@"startAddr"];
    NSString *text = [textField.text stringByTrimmingCharactersInSet:
                                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [VMMemoryEngine shared].searchRangeStart =
        strtoull([text UTF8String], NULL,
                 ([text hasPrefix:@"0x"] || [text hasPrefix:@"0X"]) ? 0 : 16);
  } else if (textField == self.endField) {
    [def setObject:textField.text forKey:@"endAddr"];
    NSString *text = [textField.text stringByTrimmingCharactersInSet:
                                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [VMMemoryEngine shared].searchRangeEnd =
        strtoull([text UTF8String], NULL,
                 ([text hasPrefix:@"0x"] || [text hasPrefix:@"0X"]) ? 0 : 16);
  } else if (textField == self.groupRangeField) {
    [def setObject:textField.text forKey:@"groupRange"];
    if ([textField.text hasPrefix:@"0x"])
      [VMMemoryEngine shared].groupSearchRange =
          strtoull([textField.text UTF8String], NULL, 16);
    else
      [VMMemoryEngine shared].groupSearchRange = [textField.text longLongValue];
  } else if (textField == self.resultLimitField) {
    [def setObject:textField.text forKey:@"resultLimit"];
    [VMMemoryEngine shared].resultLimit = [textField.text integerValue];
  } else if (textField == self.toleranceField) {
    [def setObject:textField.text forKey:@"floatTolerance"];
    [VMMemoryEngine shared].floatTolerance = [textField.text doubleValue];
  }
  [def synchronize];
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
        [self.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:1]];
  }
  
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyLanguage:(NSString *)code {
  self.selectedLanguageCode = code;
  [[VMLocalization shared] setLanguage:code];
  
  [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:2 inSection:1]] 
                        withRowAnimation:UITableViewRowAnimationNone];

  UIWindow *window = nil;
  if (@available(iOS 13.0, *)) {
    for (UIWindowScene *scene in [UIApplication sharedApplication]
             .connectedScenes) {
      if (scene.activationState == UISceneActivationStateForegroundActive) {
        for (UIWindow *w in scene.windows) {
          if (w.isKeyWindow) {
            window = w;
            break;
          }
        }
      }
      if (window)
        break;
    }
  }
  if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    window = [[UIApplication sharedApplication] keyWindow];
#pragma clang diagnostic pop
  }

  VMRootViewController *newRoot = [[VMRootViewController alloc] init];
  if (@available(iOS 13.0, *)) {
    newRoot.overrideUserInterfaceStyle = window.overrideUserInterfaceStyle;
  }

  if (window) {
    [UIView transitionWithView:window
                      duration:0.3
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      window.rootViewController = newRoot;
                    }
                    completion:nil];
  }

  UINotificationFeedbackGenerator *gen =
      [[UINotificationFeedbackGenerator alloc] init];
  [gen notificationOccurred:UINotificationFeedbackTypeSuccess];
}

- (void)setupFooter {
  UIView *footer = [[UIView alloc]
      initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 120)];
  
  footer.autoresizingMask = UIViewAutoresizingFlexibleWidth;

  UILabel *lbl = [[UILabel alloc] init];
  lbl.numberOfLines = 0;
  lbl.textAlignment = NSTextAlignmentCenter;
  lbl.font = [UIFont systemFontOfSize:12];
  lbl.textColor = [UIColor systemGrayColor];

  NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
  NSString *ver = infoDict[@"CFBundleShortVersionString"];
  lbl.text = [NSString stringWithFormat:TR(@"Set_Footer_Info"), ver];

  lbl.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  lbl.frame = CGRectMake(20, 10, footer.bounds.size.width - 40,
                         footer.bounds.size.height - 20);
  [footer addSubview:lbl];
  self.tableView.tableFooterView = footer;
}

#pragma mark - TableView DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 3; 
}

- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  if (section == 0)
    return 6; 
  if (section == 1)
    return 5;
  return 7;   
}

- (NSString *)tableView:(UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section {
  if (section == 0)
    return nil;
  if (section == 1)
    return TR(@"Set_Sec_Func");
  return TR(@"Set_Sec_About");
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c"];
  if (!cell)
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                  reuseIdentifier:@"c"];

  cell.selectionStyle = UITableViewCellSelectionStyleNone;
  cell.accessoryView = nil;
  cell.accessoryType = UITableViewCellAccessoryNone;
  cell.imageView.image = nil;
  cell.detailTextLabel.text = nil;

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

    else if (indexPath.row == 5) {
      cell.textLabel.text = TR(@"Set_Check_Update");
      cell.imageView.image = [VMIconHelper
          compatibleSystemImageNamed:@"arrow.triangle.2.circlepath"];
      cell.imageView.tintColor = [UIColor systemBlueColor];

      if ([VMUpdateManager shared].hasNewVersion) {
        cell.detailTextLabel.text = TR(@"Status_New");
        cell.detailTextLabel.textColor = [UIColor systemRedColor];
      } else {
        cell.detailTextLabel.text = TR(@"Status_Latest");
        cell.detailTextLabel.textColor = [UIColor systemGrayColor];
      }
    }
    
    else if (indexPath.row == 6) {
      cell.textLabel.text = TR(@"Dis_Title");
      cell.imageView.image =
          [VMIconHelper compatibleSystemImageNamed:@"doc.text"];
      cell.imageView.tintColor = [UIColor systemOrangeColor];

      NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
      if ([defaults boolForKey:@"has_agreed_disclaimer"]) {
        cell.detailTextLabel.text = TR(@"Dis_Agreed");
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
      } else {
        cell.detailTextLabel.text = TR(@"Dis_Not_Agreed");
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
      }
    }
  }

  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];

  if (indexPath.section == 1) {
    
    if (indexPath.row == 3) {
      [self showLanguagePicker];
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
    } else if (indexPath.row == 5) { 
      if ([VMUpdateManager shared].hasNewVersion) {
        [[VMUpdateManager shared] showUpdateAlertFromViewController:self];
      } else {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [spinner startAnimating];
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        UIView *oldAccessory = cell.accessoryView;
        cell.accessoryView = spinner;
        [[VMUpdateManager shared]
            checkForUpdateManual:YES
                      completion:^{
                        cell.accessoryView = oldAccessory;
                        [tableView
                            reloadRowsAtIndexPaths:@[ indexPath ]
                                  withRowAnimation:UITableViewRowAnimationNone];
                      }];
      }
    } else if (indexPath.row == 6) { 
      
      if (self.tabBarController &&
          [self.tabBarController isKindOfClass:[VMRootViewController class]]) {
        VMRootViewController *rootVC =
            (VMRootViewController *)self.tabBarController;
        [rootVC showDisclaimer:YES];
      }
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
        cellForRowAtIndexPath:[NSIndexPath indexPathForRow:3 inSection:1]];
    alert.popoverPresentationController.sourceView = cell;
    alert.popoverPresentationController.sourceRect = cell.bounds;
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
  
  [def setObject:@"0x300000000" forKey:@"endAddr"];
  [def setObject:@"0x100" forKey:@"groupRange"];
  [def setObject:@"100" forKey:@"resultLimit"];
  [def setObject:@"0.001" forKey:@"floatTolerance"];
  [def setFloat:0.5f forKey:@"lockInterval"];
  [def setInteger:1 forKey:@"app_theme"]; 
  [def setObject:@"Auto" forKey:@"user_lang"];
  [def setBool:NO forKey:@"preventSleep"];
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
  [VMMemoryEngine shared].searchRangeEnd = 0x300000000ULL;

  self.startField.text = @"0x100000000";
  
  self.endField.text = @"0x300000000";
  self.groupRangeField.text = @"0x100";
  self.resultLimitField.text = @"100";
  self.toleranceField.text = @"0.001";
  self.intervalSegment.selectedSegmentIndex = 1; 
  self.themeSegment.selectedSegmentIndex = 1;    
  self.selectedLanguageCode = @"Auto";           
  self.preventSleepSegment.selectedSegmentIndex = 0;  
  self.groupAnchorSegment.selectedSegmentIndex = 1;   
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
