// Simulator-only harness: real settings, root controller, localization and dismissal helper;
// target-process operations and the four other page implementations are test doubles.
#import <UIKit/UIKit.h>
#import "src/core/VMRootViewController.h"
#import "src/ui/main/VMSettingsViewController.h"
#import "src/ui/main/VMAppSelectViewController.h"
#import "src/ui/main/VMModifierViewController.h"
#import "src/ui/main/VMLockListViewController.h"
#import "src/ui/patch/VMPatcherViewController.h"
#import "src/utils/helpers/VMUIHelper.h"
#import "src/utils/managers/VMUpdateManager.h"
#import "include/VMMemoryEngine.h"
#import "include/VMLocalization.h"
#import "include/VMIconHelper.h"

static NSUInteger checks, offscreenLoads, contextSwitches, preparedLocks;
static void Check(BOOL ok, NSString *message) {
  printf("%s %s\n", ok ? "PASS" : "FAIL", message.UTF8String); fflush(stdout);
  if (!ok) exit(1);
  checks++;
}
static void Later(double seconds, dispatch_block_t block) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_main_queue(), block);
}
static BOOL HasVisibleLabelText(UIView *view, NSString *text) {
  if (view.hidden || view.alpha == 0) return NO;
  if ([view isKindOfClass:UILabel.class] && [((UILabel *)view).text isEqualToString:text]) return YES;
  for (UIView *child in view.subviews) if (HasVisibleLabelText(child, text)) return YES;
  return NO;
}

@implementation VMMemoryEngine
+ (instancetype)shared { static id engine; if (!engine) engine = [self new]; return engine; }
- (void)switchContext:(NSString *)prefix { contextSwitches++; }
@end
@implementation VMIconHelper
+ (UIImage *)compatibleSystemImageNamed:(NSString *)name { return [UIImage systemImageNamed:name]; }
@end
@implementation VMUpdateManager
+ (instancetype)shared { static id manager; if (!manager) manager = [self new]; return manager; }
- (void)performAutoCheck {}
@end
@implementation VMAppSelectViewController
- (void)viewDidLoad { [super viewDidLoad]; offscreenLoads++; }
@end
@implementation VMModifierViewController
- (void)viewDidLoad { [super viewDidLoad]; offscreenLoads++; }
@end
@implementation VMPatcherViewController
- (void)viewDidLoad { [super viewDidLoad]; offscreenLoads++; }
@end
@implementation VMLockListViewController
- (void)viewDidLoad { [super viewDidLoad]; offscreenLoads++; }
- (void)prepareForLanguageRefresh { preparedLocks++; }
@end
@interface VMSettingsViewController (TestAccess)
- (void)applyLanguage:(NSString *)code;
- (void)showLanguagePicker;
- (void)selectSettingsGroup:(NSInteger)group;
@end

@interface LanguageCheckApp : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) VMRootViewController *root;
@property(nonatomic, strong) NSArray *navs;
@property(nonatomic, strong) NSArray<NSString *> *languages;
@property(nonatomic) NSUInteger step;
@property(nonatomic) NSUInteger initialLoads;
@end
@implementation LanguageCheckApp
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
  [NSUserDefaults.standardUserDefaults setBool:YES forKey:@"has_agreed_disclaimer"];
  [NSUserDefaults.standardUserDefaults removeObjectForKey:@"vm_settings_group"];
  [NSUserDefaults.standardUserDefaults setObject:@[@4, @3, @1, @0, @2] forKey:@"vm_bottom_tab_order"];
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
  self.root = [VMRootViewController new];
  self.window.rootViewController = self.root;
  [self.window makeKeyAndVisible];
  self.languages = @[@"Auto", @"en", @"zh-Hans", @"zh-Hant", @"ja", @"ko", @"vi", @"th", @"ru", @"es", @"pt", @"fr", @"de", @"ar"];
  Later(1, ^{
    // Cover navigation controllers whose old pages have already been visited.
    for (UIViewController *pageNav in self.root.viewControllers) [pageNav loadViewIfNeeded];
    self.navs = [self.root.viewControllers copy];
    self.initialLoads = offscreenLoads;
    UINavigationController *settingsNav = (id)self.root.selectedViewController;
    VMSettingsViewController *settings = (id)settingsNav.topViewController;
    Check([[settings valueForKey:@"selectedSettingsGroup"] integerValue] == 0, @"fresh settings begin in the search group");
    [self next];
  });
  return YES;
}
- (void)next {
  if (self.step == self.languages.count * 2) {
    Check(preparedLocks == self.step, @"shared locking lifecycle preserved on every refresh");
    printf("PASS: %lu language UI checks\n", (unsigned long)checks); fflush(stdout);
    exit(0);
  }
  UINavigationController *nav = (id)self.root.selectedViewController;
  VMSettingsViewController *settings = (id)nav.topViewController;
  Check([settings isKindOfClass:VMSettingsViewController.class], @"settings tab remains selected");
  NSString *code = self.languages[self.step % self.languages.count];
  BOOL narrowAbout = self.step == 11; // One long-label rebuild covers the last tab at compact width.
  self.window.frame = narrowAbout ? CGRectMake(0, 0, 320, 740) : UIScreen.mainScreen.bounds;
  [self.window layoutIfNeeded];
  [settings selectSettingsGroup:narrowAbout ? 2 : 1];
  [settings.view layoutIfNeeded];
  Check([[settings valueForKey:@"selectedSettingsGroup"] integerValue] == (narrowAbout ? 2 : 1),
      @"language change starts from the requested settings group");
  if (self.step % 3 == 0 || narrowAbout) {
    [settings applyLanguage:code];
    [settings applyLanguage:code]; // duplicate request is ignored by this page
    Later(.4, ^{ [self verifyWhenReady:settings code:code attempts:50]; });
    return;
  }
  [settings showLanguagePicker];
  Later(.6, ^{
    UIAlertController *alert = (id)settings.presentedViewController;
    Check([alert isKindOfClass:UIAlertController.class], @"real language picker presented");
    UIAlertAction *action = alert.actions[self.step % self.languages.count];
    void (^handler)(UIAlertAction *) = [action valueForKey:@"handler"];
    handler(action);
    if (self.step % 3 == 1) [settings dismissViewControllerAnimated:YES completion:nil];
    Later(.7, ^{ [self verifyWhenReady:settings code:code attempts:50]; });
  });
}
- (void)verifyWhenReady:(VMSettingsViewController *)oldSettings code:(NSString *)code attempts:(NSUInteger)attempts {
  UINavigationController *nav = (id)self.root.selectedViewController;
  if (attempts > 0 && (nav.topViewController == oldSettings || nav.topViewController.presentedViewController || self.root.presentedViewController)) {
    Later(.1, ^{ [self verifyWhenReady:oldSettings code:code attempts:attempts - 1]; });
    return;
  }
  [self verify:oldSettings code:code];
}
- (void)verify:(VMSettingsViewController *)oldSettings code:(NSString *)code {
  Check(self.window.rootViewController == self.root, @"window root identity preserved");
  Check([self.root.viewControllers isEqualToArray:self.navs], @"navigation identities and custom tab order preserved");
  Check(self.root.selectedViewController == self.navs.firstObject, @"selected navigation preserved");
  UINavigationController *nav = (id)self.root.selectedViewController;
  Check(nav.topViewController != oldSettings, @"settings page refreshed");
  if (nav.topViewController.presentedViewController || self.root.presentedViewController)
    NSLog(@"Remaining modal: new=%@ root=%@ old=%@ dismissing=%d", nav.topViewController.presentedViewController,
        self.root.presentedViewController, oldSettings.presentedViewController, self.root.presentedViewController.isBeingDismissed);
  Check(!nav.topViewController.presentedViewController && !self.root.presentedViewController, @"no modal left over");
  Check(!UIApplication.sharedApplication.isIgnoringInteractionEvents, @"UIKit accepts interaction events");
  Check([[[VMLocalization shared] currentLanguage] isEqualToString:code], @"language preference saved");
  Check([nav.topViewController.title isEqualToString:[[VMLocalization shared] localizedString:@"Set_Title"]], @"new settings title localized");
  VMSettingsViewController *settings = (id)nav.topViewController;
  [settings.view layoutIfNeeded];
  BOOL narrowAbout = self.step == 11;
  NSInteger expectedGroup = narrowAbout ? 2 : 1;
  Check([[settings valueForKey:@"selectedSettingsGroup"] integerValue] == expectedGroup,
      @"language refresh preserves the active settings group");
  UITableView *table = [settings valueForKey:@"tableView"];
  for (NSInteger section = 0; section < 3; section++)
    Check([table numberOfRowsInSection:section] == (section == expectedGroup ? (section == 2 ? 5 : 6) : 0),
        @"refreshed settings display only the selected group");
  UISegmentedControl *groups = [settings valueForKey:@"groupTabs"];
  NSArray *groupKeys = @[@"Set_Search_Section", @"Set_Sec_Func", @"Set_Sec_About"];
  Check(groups.selectedSegmentIndex == expectedGroup && groups.numberOfSegments == 3, @"refreshed settings tabs retain their selection");
  for (NSUInteger index = 0; index < groupKeys.count; index++)
    Check([[groups titleForSegmentAtIndex:index] isEqualToString:[[VMLocalization shared] localizedString:groupKeys[index]]],
        @"refreshed settings category title is localized");
  if (narrowAbout) {
    UIScrollView *tabScroll = [settings valueForKey:@"groupTabScroll"];
    CGFloat x = [groups widthForSegmentAtIndex:0] + [groups widthForSegmentAtIndex:1];
    CGFloat width = [groups widthForSegmentAtIndex:2];
    CGRect selected = [groups convertRect:CGRectMake(x, 0, width, groups.bounds.size.height) toView:tabScroll];
    Check(width > 0 && CGRectContainsRect(CGRectInset(tabScroll.bounds, -1, -1), selected),
        @"French about tab remains fully visible after refresh at 320pt width");
    [settings selectSettingsGroup:1];
    [settings.view layoutIfNeeded];
  }
  NSIndexPath *languagePath = [NSIndexPath indexPathForRow:3 inSection:1];
  [table scrollToRowAtIndexPath:languagePath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
  [table layoutIfNeeded];
  UITableViewCell *languageCell = [table cellForRowAtIndexPath:languagePath];
  Check([languageCell.textLabel.text isEqualToString:[[VMLocalization shared] localizedString:@"Set_Lang"]] &&
      languageCell.accessoryType == UITableViewCellAccessoryDisclosureIndicator,
      @"translated language row remains available in the behavior group");
  UISegmentedControl *interval = [settings valueForKey:@"intervalSegment"];
  NSInteger originalInterval = interval.selectedSegmentIndex;
  interval.selectedSegmentIndex = (originalInterval + 1) % 3;
  [interval sendActionsForControlEvents:UIControlEventValueChanged];
  const float intervals[] = {0.1f, 0.5f, 1.0f};
  Check(interval.enabled && fabsf([NSUserDefaults.standardUserDefaults floatForKey:@"lockInterval"] - intervals[interval.selectedSegmentIndex]) < .001f,
      @"refreshed behavior controls remain interactive and save changes");
  interval.selectedSegmentIndex = originalInterval;
  [interval sendActionsForControlEvents:UIControlEventValueChanged];
  UIButton *disclaimer = [settings valueForKey:@"disclaimerButton"];
  UILabel *legal = [settings valueForKey:@"legalFooterLabel"];
  Check([disclaimer isDescendantOfView:table.tableFooterView] && !disclaimer.hidden && disclaimer.enabled &&
      [disclaimer actionsForTarget:settings forControlEvent:UIControlEventTouchUpInside].count > 0,
      @"language refresh retains the shared disclaimer action");
  NSString *disclaimerTitle = [[VMLocalization shared] localizedString:@"Dis_Title"];
  Check([disclaimer.accessibilityLabel isEqualToString:disclaimerTitle] && HasVisibleLabelText(disclaimer, disclaimerTitle),
      @"shared disclaimer title is localized");
  Check(legal.text.length > 0 && [legal isDescendantOfView:table.tableFooterView], @"language refresh retains the legal footer");
  UIView *information = [settings valueForKey:@"legalInfoSection"];
  for (NSString *key in @[@"Set_Legal_Version", @"Set_Legal_Thanks", @"Set_Legal_Technology", @"Set_Legal_License", @"Set_Legal_Copyright"])
    Check(HasVisibleLabelText(information, [[VMLocalization shared] localizedString:key]), @"shared information section labels are localized");
  NSArray *updateKeys = @[@"Set_Check_Update", @"Update_Checking", @"Status_Latest", @"Status_New", @"Update_Check_Failed"];
  for (NSUInteger state = 0; state < updateKeys.count; state++) {
    VMUpdateManager.shared.checkState = (VMUpdateCheckState)state;
    [NSNotificationCenter.defaultCenter postNotificationName:kVMUpdateStateDidChangeNotification object:VMUpdateManager.shared];
    UILabel *version = [settings valueForKey:@"versionValueLabel"];
    NSString *translated = [[VMLocalization shared] localizedString:updateKeys[state]];
    Check(![translated isEqualToString:updateKeys[state]] && [version.text containsString:translated], @"version status refreshes in the selected language");
    UIButton *versionButton = [settings valueForKey:@"versionButton"];
    Check([versionButton.accessibilityValue isEqualToString:version.text] && versionButton.enabled == (state != VMUpdateCheckStateChecking),
        @"localized version status preserves accessibility and checking behavior");
  }
  VMUpdateManager.shared.checkState = VMUpdateCheckStateIdle;
  [NSNotificationCenter.defaultCenter postNotificationName:kVMUpdateStateDidChangeNotification object:VMUpdateManager.shared];
  Check(self.window.overrideUserInterfaceStyle == UIUserInterfaceStyleDark, @"theme preserved");
  Check(offscreenLoads == self.initialLoads, @"language refresh avoids offscreen process-page loading");
  Check(contextSwitches == 1, @"language refresh leaves memory context intact");
  NSArray *keys = @[@"Tab_Set", @"Tab_Toolbox", @"Tab_Mod", @"Tab_App", @"Tab_Patch"];
  for (NSUInteger i = 0; i < self.navs.count; i++)
    Check([((UIViewController *)self.navs[i]).tabBarItem.title isEqualToString:[[VMLocalization shared] localizedString:keys[i]]], @"tab title localized");
#if VM_LANGUAGE_TRACE
  Check(nav.topViewController.navigationItem.leftBarButtonItem != nil, @"diagnostic export available");
#endif
  self.step++;
  Later(.1, ^{ [self next]; });
}
@end
int main(int argc, char **argv) {
  @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(LanguageCheckApp.class)); }
}
