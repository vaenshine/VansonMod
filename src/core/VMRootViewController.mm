#import "VMRootViewController.h"
#import "../../include/VMLocalization.h"
#import "../../include/VMMemoryEngine.h"
#import "../ui/main/VMAppSelectViewController.h"
#import "../ui/main/VMLockListViewController.h"
#import "../ui/main/VMModifierViewController.h"
#import "../ui/main/VMSettingsViewController.h"
#import "../ui/patch/VMPatcherViewController.h"
#import "../ui/pointer/VMPointerSearchViewController.h"
#import "../ui/pointer/VMSavedPointersViewController.h"
#import "../utils/managers/VMUpdateManager.h"
#import "../utils/helpers/VMLanguageRefresh.h"
#import "../utils/helpers/VMUIHelper.h"
#define TR(key) ([[VMLocalization shared] localizedString:key])

static NSString *const kVMTabOrderKey = @"vm_bottom_tab_order";

static BOOL VMBrandOverlapsActions(UIView *view, UIView *container, CGRect brandFrame) {
  if (view.hidden || view.alpha < .01) return NO;
  CGRect frame = [view convertRect:view.bounds toView:container];
  BOOL intersects = CGRectIntersectsRect(frame, brandFrame);
  if (intersects && ([view.accessibilityIdentifier isEqualToString:@"vmBrandingAvoidance"] ||
      [view isKindOfClass:UIToolbar.class])) return YES;
  if (view.clipsToBounds && !intersects) return NO;
  for (UIView *child in view.subviews)
    if (VMBrandOverlapsActions(child, container, brandFrame)) return YES;
  return NO;
}

@interface VMTabReorderCell : UITableViewCell
@end
@implementation VMTabReorderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
  if (self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid]) {
    self.textLabel.font = [VMUIHelper scaledFontOfSize:16 weight:UIFontWeightMedium];
    self.textLabel.adjustsFontForContentSizeCategory = YES;
    self.textLabel.numberOfLines = 0;
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
  }
  return self;
}
@end

@interface VMTabReorderViewController : UITableViewController
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *tabDescriptors;
@property(nonatomic, copy) void (^onDone)(NSArray<NSNumber *> *newOrder);
@end

@implementation VMTabReorderViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = TR(@"Set_Tab_Reorder");
  self.tableView.editing = YES;
  [VMUIHelper styleTableView:self.tableView];
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 60;
  self.tableView.tableHeaderView = [VMUIHelper contextHeaderWithText:TR(@"Set_Tab_Reorder_Hint") symbol:@"arrow.up.arrow.down"];
  self.tableView.tableHeaderView.layoutMargins = UIEdgeInsetsMake(8, 20, 8, 20);
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  [self.tableView registerClass:[VMTabReorderCell class] forCellReuseIdentifier:@"Cell"];
  
  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_OK")
                                       style:UIBarButtonItemStyleDone
                                      target:self
                                      action:@selector(doneTapped)];
  [VMUIHelper styleConfirmationItem:self.navigationItem.rightBarButtonItem];
  self.navigationItem.leftBarButtonItem =
      [[UIBarButtonItem alloc] initWithTitle:TR(@"Btn_Restore_Default")
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(resetTapped)];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
  return self.tabDescriptors.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
  VMTabReorderCell *cell = [tv dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:ip];
  NSDictionary *desc = self.tabDescriptors[ip.row];
  cell.textLabel.text = desc[@"title"];
  cell.imageView.image = [UIImage systemImageNamed:desc[@"icon"]];
  cell.imageView.tintColor = [UIColor systemBlueColor];
  cell.showsReorderControl = YES;
  return cell;
}

- (BOOL)tableView:(UITableView *)tv canMoveRowAtIndexPath:(NSIndexPath *)ip { return YES; }
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }
- (UITableViewCellEditingStyle)tableView:(UITableView *)tv editingStyleForRowAtIndexPath:(NSIndexPath *)ip {
  return UITableViewCellEditingStyleNone;
}
- (BOOL)tableView:(UITableView *)tv shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)ip { return NO; }

- (void)tableView:(UITableView *)tv moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
  NSDictionary *item = self.tabDescriptors[from.row];
  [self.tabDescriptors removeObjectAtIndex:from.row];
  [self.tabDescriptors insertObject:item atIndex:to.row];
}

- (void)doneTapped {
  NSMutableArray<NSNumber *> *order = [NSMutableArray array];
  for (NSDictionary *d in self.tabDescriptors) {
    [order addObject:d[@"tag"]];
  }
  [[NSUserDefaults standardUserDefaults] setObject:order forKey:kVMTabOrderKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  if (self.onDone) self.onDone(order);
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)resetTapped {
  
  NSArray *defaultOrder = @[@0, @1, @2, @3, @4];
  self.tabDescriptors = [NSMutableArray array];
  
  NSArray *allDescs = [self defaultDescriptors];
  for (NSNumber *tag in defaultOrder) {
    for (NSDictionary *d in allDescs) {
      if ([d[@"tag"] isEqual:tag]) {
        [self.tabDescriptors addObject:d];
        break;
      }
    }
  }
  [self.tableView reloadData];
}

- (NSArray *)defaultDescriptors {
  return @[
    @{@"tag": @0, @"title": TR(@"Tab_App"),     @"icon": @"list.bullet"},
    @{@"tag": @1, @"title": TR(@"Tab_Mod"),     @"icon": @"hammer"},
    @{@"tag": @2, @"title": TR(@"Tab_Patch"),   @"icon": @"cpu"},
    @{@"tag": @3, @"title": TR(@"Tab_Toolbox"), @"icon": @"briefcase"},
    @{@"tag": @4, @"title": TR(@"Tab_Set"),     @"icon": @"gear"},
  ];
}

@end

@interface VMRootViewController () <UITabBarControllerDelegate>
@property(nonatomic, strong) NSArray<UINavigationController *> *allNavControllers;
@property(nonatomic, strong) UIView *brandingFooter;
@property(nonatomic, copy) NSString *brandingIconName;
@property(nonatomic) CGRect brandingKeyboardFrame;

@end
@implementation VMRootViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  VMAppSelectViewController *vc1 = [[VMAppSelectViewController alloc] init];
  UINavigationController *nav1 =
      [[UINavigationController alloc] initWithRootViewController:vc1];
  nav1.tabBarItem = [[UITabBarItem alloc]
      initWithTitle:TR(@"Tab_App")
              image:[UIImage systemImageNamed:@"list.bullet"]
                tag:0];

  VMModifierViewController *vc2 = [[VMModifierViewController alloc] init];
  UINavigationController *nav2 =
      [[UINavigationController alloc] initWithRootViewController:vc2];
  nav2.tabBarItem =
      [[UITabBarItem alloc] initWithTitle:TR(@"Tab_Mod")
                                    image:[UIImage systemImageNamed:@"hammer"]
                                      tag:1];

  VMPatcherViewController *vcPatch = [[VMPatcherViewController alloc] init];
  UINavigationController *navPatch =
      [[UINavigationController alloc] initWithRootViewController:vcPatch];
  navPatch.tabBarItem =
      [[UITabBarItem alloc] initWithTitle:TR(@"Tab_Patch")
                                    image:[UIImage systemImageNamed:@"cpu"]
                                      tag:2];

  VMLockListViewController *vc4 = [[VMLockListViewController alloc] init];
  UINavigationController *nav4 =
      [[UINavigationController alloc] initWithRootViewController:vc4];
  nav4.tabBarItem = [[UITabBarItem alloc]
      initWithTitle:TR(@"Tab_Toolbox")
              image:[UIImage systemImageNamed:@"briefcase"]
                tag:3];

  VMSettingsViewController *vc5 = [[VMSettingsViewController alloc] init];
  UINavigationController *nav5 =
      [[UINavigationController alloc] initWithRootViewController:vc5];
  nav5.tabBarItem =
      [[UITabBarItem alloc] initWithTitle:TR(@"Tab_Set")
                                    image:[UIImage systemImageNamed:@"gear"]
                                      tag:4];

  self.allNavControllers = @[ nav1, nav2, navPatch, nav4, nav5 ];
  NSArray *selectedSymbols = @[@"square.grid.2x2.fill", @"slider.horizontal.3", @"cpu.fill", @"shippingbox.fill", @"gearshape.fill"];
  NSArray *symbols = @[@"square.grid.2x2", @"slider.horizontal.3", @"cpu", @"shippingbox", @"gearshape"];
  for (NSUInteger i = 0; i < self.allNavControllers.count; i++) {
    UINavigationController *nav = self.allNavControllers[i];
    [VMUIHelper applyNavigationAppearance:nav];
    nav.tabBarItem.image = [UIImage systemImageNamed:symbols[i]];
    nav.tabBarItem.selectedImage = [UIImage systemImageNamed:selectedSymbols[i]];
  }
  self.view.tintColor = VMUIHelper.accentColor;
  self.tabBar.tintColor = VMUIHelper.accentColor;
  self.tabBar.unselectedItemTintColor = UIColor.secondaryLabelColor;
  
  [self applyTabOrder];
  self.delegate = self;

  if ([[VMMemoryEngine shared] respondsToSelector:@selector(switchContext:)]) {
    [[VMMemoryEngine shared] switchContext:@"mod"];
  }

  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(handleUpdateBadge)
             name:kVMUpdateAvailableNotification
           object:nil];
  
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(handleJumpToTab:)
             name:@"VM_JUMP_TO_TAB"
           object:nil];
  
  UILongPressGestureRecognizer *lp =
      [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(handleTabBarLongPress:)];
  lp.minimumPressDuration = 0.5;
  [self.tabBar addGestureRecognizer:lp];
  
  NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
  [center addObserver:self selector:@selector(refreshBranding) name:UIApplicationDidBecomeActiveNotification object:nil];
  [center addObserver:self selector:@selector(refreshBranding) name:@"VMApplicationIconDidChange" object:nil];
  [center addObserver:self selector:@selector(brandingKeyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
  [center addObserver:self selector:@selector(brandingKeyboardHidden:) name:UIKeyboardWillHideNotification object:nil];
  [self refreshBranding];
  [[VMUpdateManager shared] performAutoCheck];
}

- (void)refreshBranding {
  NSString *iconName = UIApplication.sharedApplication.alternateIconName ?: @"";
  if (!self.brandingFooter || ![self.brandingIconName isEqualToString:iconName]) {
    [self.brandingFooter removeFromSuperview];
    self.brandingIconName = iconName;
    self.brandingFooter = [VMUIHelper createVansonFooterViewForWidth:self.view.bounds.size.width];
    [self.view addSubview:self.brandingFooter];
  }
  [self.view setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self refreshBrandingOverlay];
}

- (void)refreshBrandingOverlay {
  if (!self.brandingFooter) return;
  CGRect bar = [self.tabBar convertRect:self.tabBar.bounds toView:self.view];
  UINavigationController *selected = (id)self.selectedViewController;
  BOOL visible = !self.tabBar.hidden && self.tabBar.alpha > .01 &&
      !selected.topViewController.hidesBottomBarWhenPushed &&
      CGRectGetHeight(bar) > 0 && CGRectGetMidY(bar) > CGRectGetMidY(self.view.bounds) &&
      CGRectGetMinY(bar) < CGRectGetMaxY(self.view.bounds);
  CGSize size = [self.brandingFooter systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
  // A transparent, touch-through overlay; page safe areas belong to the native tab bar.
  self.brandingFooter.frame = CGRectMake(round((self.view.bounds.size.width - size.width) / 2),
      CGRectGetMinY(bar) - size.height - 2, size.width, size.height);
  BOOL keyboardCoversBrand = NO;
  UIWindow *window = self.view.window;
  if (window && !CGRectIsEmpty(self.brandingKeyboardFrame)) {
    CGRect windowFrame = [window convertRect:self.brandingKeyboardFrame fromCoordinateSpace:window.screen.coordinateSpace];
    CGRect frame = [self.view convertRect:windowFrame fromView:window];
    keyboardCoversBrand = CGRectIntersectsRect(frame, self.brandingFooter.frame);
  }
  self.brandingFooter.hidden = !visible || keyboardCoversBrand ||
      VMBrandOverlapsActions(selected.view, self.view, self.brandingFooter.frame);
  [self.view bringSubviewToFront:self.brandingFooter];
}

- (void)brandingKeyboardChanged:(NSNotification *)notification {
  self.brandingKeyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  [self.view setNeedsLayout];
}

- (void)brandingKeyboardHidden:(NSNotification *)notification {
  self.brandingKeyboardFrame = CGRectZero;
  [self.view setNeedsLayout];
}

- (BOOL)shouldAutorotate {
  return YES;
}

- (void)refreshLocalizedPages {
  NSAssert(NSThread.isMainThread, @"Language refresh must run on the main thread");
  NSArray<Class> *classes = @[
    VMAppSelectViewController.class, VMModifierViewController.class,
    VMPatcherViewController.class, VMLockListViewController.class, VMSettingsViewController.class
  ];
  NSArray<NSString *> *keys = @[@"Tab_App", @"Tab_Mod", @"Tab_Patch", @"Tab_Toolbox", @"Tab_Set"];
  // Keep the window, tab controller, navigation controllers, selection and tab order.
  // Offscreen root pages stay unloaded until the user opens their tab.
  for (NSUInteger i = 0; i < self.allNavControllers.count; i++) {
    VMLanguageTrace([NSString stringWithFormat:@"refresh-page-%lu-begin", (unsigned long)i]);
    UINavigationController *nav = self.allNavControllers[i];
    for (UIViewController *page in nav.viewControllers) {
      if ([page isKindOfClass:VMLockListViewController.class])
        [(VMLockListViewController *)page prepareForLanguageRefresh];
    }
    UIViewController *page = [[classes[i] alloc] init];
    [nav setViewControllers:@[page] animated:NO];
    nav.tabBarItem.title = TR(keys[i]);
    VMLanguageTrace([NSString stringWithFormat:@"refresh-page-%lu-end", (unsigned long)i]);
  }
  [self handleUpdateBadge];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  if ([[UIDevice currentDevice] userInterfaceIdiom] ==
      UIUserInterfaceIdiomPad) {
    return UIInterfaceOrientationMaskAll;
  }
  return UIInterfaceOrientationMaskAll;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - [v2.6] Tab 排序

- (void)applyTabOrder {
  UIViewController *selected = self.selectedViewController;
  NSArray *savedOrder = [NSUserDefaults.standardUserDefaults arrayForKey:kVMTabOrderKey];
  NSMutableArray *ordered = [NSMutableArray array];
  NSMutableIndexSet *seen = [NSMutableIndexSet indexSet];
  if (savedOrder.count == self.allNavControllers.count) {
    for (id tag in savedOrder) {
      if (![tag isKindOfClass:NSNumber.class]) break;
      NSInteger index = [tag integerValue];
      if (index < 0 || index >= (NSInteger)self.allNavControllers.count ||
          [tag doubleValue] != (double)index || [seen containsIndex:index]) break;
      [seen addIndex:index];
      [ordered addObject:self.allNavControllers[index]];
    }
  }
  self.viewControllers = ordered.count == self.allNavControllers.count ? ordered : self.allNavControllers;
  if (selected && [self.viewControllers containsObject:selected]) self.selectedViewController = selected;
}

- (void)handleTabBarLongPress:(UILongPressGestureRecognizer *)gesture {
  if (gesture.state != UIGestureRecognizerStateBegan || self.presentedViewController) return;
  
  UIImpactFeedbackGenerator *gen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
  [gen impactOccurred];
  
  [self showTabReorder];
}

- (void)showTabReorder {
  if (self.presentedViewController) return;
  VMTabReorderViewController *reorderVC = [[VMTabReorderViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
  
  NSMutableArray<NSDictionary *> *descs = [NSMutableArray array];
  for (UIViewController *vc in self.viewControllers) {
    NSInteger tag = vc.tabBarItem.tag;
    NSString *title = vc.tabBarItem.title ?: @"";
    NSString *icon = @"questionmark";
    switch (tag) {
      case 0: icon = @"list.bullet"; break;
      case 1: icon = @"hammer"; break;
      case 2: icon = @"cpu"; break;
      case 3: icon = @"briefcase"; break;
      case 4: icon = @"gear"; break;
    }
    [descs addObject:@{@"tag": @(tag), @"title": title, @"icon": icon}];
  }
  reorderVC.tabDescriptors = descs;
  
  __weak VMRootViewController *weakSelf = self;
  reorderVC.onDone = ^(NSArray<NSNumber *> *newOrder) {
    [weakSelf applyTabOrder];
    
    [weakSelf handleUpdateBadge];
  };
  
  UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:reorderVC];
  nav.modalPresentationStyle = UIModalPresentationFormSheet;
  if (@available(iOS 15.0, *)) {
    nav.sheetPresentationController.detents = @[
      UISheetPresentationControllerDetent.mediumDetent,
      UISheetPresentationControllerDetent.largeDetent
    ];
    nav.sheetPresentationController.prefersGrabberVisible = YES;
  }
  [self presentViewController:nav animated:YES completion:nil];
}

- (NSInteger)indexForTabTag:(NSInteger)tag {
  for (NSInteger i = 0; i < (NSInteger)self.viewControllers.count; i++) {
    if (self.viewControllers[i].tabBarItem.tag == tag) return i;
  }
  return NSNotFound;
}

- (void)handleUpdateBadge {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSInteger settingsIdx = [self indexForTabTag:4];
    if (settingsIdx != NSNotFound && settingsIdx < (NSInteger)self.tabBar.items.count) {
      UITabBarItem *item = self.tabBar.items[settingsIdx];
      item.badgeValue = [VMUpdateManager shared].hasNewVersion ? @"1" : nil;
      item.badgeColor = UIColor.systemRedColor;
    }
  });
}

- (void)handleJumpToTab:(NSNotification *)notification {
  NSDictionary *info = notification.userInfo;
  NSInteger targetTab = [info[@"targetTab"] integerValue];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    
    if (targetTab >= 2 && targetTab <= 6) {
      
      NSInteger toolboxIdx = [self indexForTabTag:3];
      if (toolboxIdx != NSNotFound) {
        self.selectedIndex = toolboxIdx;
      }
    }
  });
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  [self showDisclaimerIfNeeded];
}

- (void)showDisclaimerIfNeeded {
  
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:@"has_agreed_disclaimer"]) {
    return; 
  }

  NSString *disTitle = TR(@"Dis_Title");
  NSString *disMsg = TR(@"Dis_Msg");

  CGFloat fontSize = 13.0;
  NSMutableParagraphStyle *paragraphStyle =
      [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.alignment = NSTextAlignmentLeft;
  paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;

  NSDictionary *attrDict = @{
    NSForegroundColorAttributeName : [UIColor labelColor],
    NSParagraphStyleAttributeName : paragraphStyle,
    NSFontAttributeName : [UIFont systemFontOfSize:fontSize
                                            weight:UIFontWeightRegular]
  };
  NSAttributedString *attributedMsg =
      [[NSAttributedString alloc] initWithString:disMsg attributes:attrDict];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:disTitle
                                          message:@""
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert setValue:attributedMsg forKey:@"attributedMessage"];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Dis_Agree")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *action) {
                                 
                                 [defaults setBool:YES
                                            forKey:@"has_agreed_disclaimer"];
                                 [defaults synchronize];
                               }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Dis_Exit")
                                            style:UIAlertActionStyleDestructive
                                          handler:^(UIAlertAction *action) {
                                            exit(0);
                                          }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDisclaimer:(BOOL)isReadOnly {
  NSString *disTitle = TR(@"Dis_Title");
  NSString *disMsg = TR(@"Dis_Msg");

  CGFloat fontSize = 13.0;
  NSMutableParagraphStyle *paragraphStyle =
      [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.alignment = NSTextAlignmentLeft;
  paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;

  NSDictionary *attrDict = @{
    NSForegroundColorAttributeName : [UIColor labelColor],
    NSParagraphStyleAttributeName : paragraphStyle,
    NSFontAttributeName : [UIFont systemFontOfSize:fontSize
                                            weight:UIFontWeightRegular]
  };
  NSAttributedString *attributedMsg =
      [[NSAttributedString alloc] initWithString:disMsg attributes:attrDict];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:disTitle
                                          message:@""
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert setValue:attributedMsg forKey:@"attributedMessage"];

  if (isReadOnly) {
    
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
  } else {
    
    [alert addAction:[UIAlertAction
                         actionWithTitle:TR(@"Dis_Agree")
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *action) {
                                   NSUserDefaults *defaults =
                                       [NSUserDefaults standardUserDefaults];
                                   [defaults setBool:YES
                                              forKey:@"has_agreed_disclaimer"];
                                   [defaults synchronize];
                                 }]];
    [alert
        addAction:[UIAlertAction actionWithTitle:TR(@"Dis_Exit")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                           exit(0);
                                         }]];
  }

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)tabBarController:(UITabBarController *)tabBarController
    didSelectViewController:(UIViewController *)viewController {
  
  NSInteger tag = viewController.tabBarItem.tag;
  if (tag == 0) {
    UINavigationController *nav = (UINavigationController *)viewController;
    if ([nav.topViewController
            isKindOfClass:[VMAppSelectViewController class]]) {
      VMAppSelectViewController *appVC =
          (VMAppSelectViewController *)nav.topViewController;
      if ([appVC respondsToSelector:@selector(loadProcesses)]) {
        [appVC performSelector:@selector(loadProcesses)];
      }
    }
  }
}

@end
