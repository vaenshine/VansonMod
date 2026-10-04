// Public documentation captures using shipping UIKit views and synthetic data.
// This entry point is compiled into a separate simulator app, never VansonMod.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "src/core/VMRootViewController.h"
#import "src/ui/main/VMAppSelectViewController.h"
#import "src/ui/main/VMSettingsViewController.h"
#import "src/ui/main/VMScriptViewController.h"
#import "src/ui/common/VMFormSheetViewController.h"
#import "src/utils/managers/VMUpdateManager.h"
#import "src/utils/helpers/VMUIHelper.h"
#import "ReleaseMemoryScreenshots.h"
#import "ReleasePointerScreenshots.h"

static void ReleaseRequire(BOOL valid, NSString *message) {
  printf("%s %s\n", valid ? "PASS" : "FAIL", message.UTF8String);
  fflush(stdout);
  if (!valid) exit(1);
}
static void ReleaseLater(double seconds, dispatch_block_t work) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_main_queue(), work);
}
static void ReleaseReplace(Class cls, SEL selector, id block) {
  Method method = class_getInstanceMethod(cls, selector);
  ReleaseRequire(method != NULL, NSStringFromSelector(selector));
  class_replaceMethod(cls, selector, imp_implementationWithBlock(block), method_getTypeEncoding(method));
}

@interface VMAppSelectViewController (ReleaseAccess)
- (void)updateSegmentTitles;
@end
@interface VMSettingsViewController (ReleaseAccess)
- (void)selectSettingsGroup:(NSInteger)group;
@end
@interface VMLockListViewController (ReleaseAccess)
- (void)addNewScript;
@end

static NSArray<NSDictionary *> *ReleaseDemoApps(void) {
  return @[
    @{@"name":@"Atlas Demo", @"bid":@"com.example.atlasdemo", @"pid":@4242, @"ver":@"1.0", @"path":@"com.example.atlasdemo"},
    @{@"name":@"Pixel Lab", @"bid":@"com.example.pixellab", @"pid":@4310, @"ver":@"2.1", @"path":@"com.example.pixellab"},
    @{@"name":@"Orbit Notes", @"bid":@"com.example.orbitnotes", @"pid":@4388, @"ver":@"1.4", @"path":@"com.example.orbitnotes"},
    @{@"name":@"Sample Player", @"bid":@"com.example.sampleplayer", @"pid":@4502, @"ver":@"3.0", @"path":@"com.example.sampleplayer"},
    @{@"name":@"Garden Demo", @"bid":@"com.example.gardendemo", @"pid":@4618, @"ver":@"1.2", @"path":@"com.example.gardendemo"},
    @{@"name":@"Draft Studio", @"bid":@"com.example.draftstudio", @"pid":@4726, @"ver":@"2.0", @"path":@"com.example.draftstudio"}
  ];
}
static void ReleaseCacheDemoIcons(void) {
  NSArray *symbols = @[@"cube.fill", @"paintpalette.fill", @"note.text", @"play.rectangle.fill", @"leaf.fill", @"square.stack.3d.up.fill"];
  NSArray *colors = @[UIColor.systemIndigoColor, UIColor.systemPinkColor, UIColor.systemOrangeColor,
                      UIColor.systemBlueColor, UIColor.systemGreenColor, UIColor.systemPurpleColor];
  [ReleaseDemoApps() enumerateObjectsUsingBlock:^(NSDictionary *app, NSUInteger index, BOOL *stop) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(64, 64)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
      [colors[index] setFill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 64, 64) cornerRadius:14] fill];
      UIImage *symbol = [[UIImage systemImageNamed:symbols[index]] imageWithTintColor:UIColor.whiteColor renderingMode:UIImageRenderingModeAlwaysOriginal];
      CGFloat scale = MIN(36 / symbol.size.width, 36 / symbol.size.height);
      CGSize size = CGSizeMake(symbol.size.width * scale, symbol.size.height * scale);
      [symbol drawInRect:CGRectMake((64-size.width)/2, (64-size.height)/2, size.width, size.height)];
    }];
    [VMUIHelper cacheApplicationIcon:image forBundleID:app[@"bid"]];
  }];
}

static void ReleaseInstallFixtures(void) {
  ReleaseCacheDemoIcons();
  ReleaseReplace(VMUpdateManager.class, @selector(performAutoCheck), ^(id object) {});
  ReleaseReplace(VMAppSelectViewController.class, NSSelectorFromString(@"loadProcesses"), ^(VMAppSelectViewController *page) {
    NSArray *apps = ReleaseDemoApps();
    [page setValue:apps forKey:@"userApps"];
    [page setValue:apps forKey:@"displayedApps"];
    [page setValue:apps forKey:@"allInstalledApps"];
    [page updateSegmentTitles];
    [(UITableView *)[page valueForKey:@"tableView"] reloadData];
  });
  ReleaseReplace(VMAppSelectViewController.class, NSSelectorFromString(@"loadInstalledApps"), ^(id object) {});
  ReleaseReplace(VMAppSelectViewController.class, NSSelectorFromString(@"getAppIcon:isSystem:"), ^UIImage *(id object, NSString *path, BOOL system) {
    return [VMUIHelper applicationIconForBundleID:path];
  });
  // Every memory read resolves to the synthetic local array. No task attachment
  // or writes are used by this documentation capture process.
  ReleaseReplace(VMMemoryEngine.class, @selector(readRawMemory:length:), ^NSData *(id engine, uint64_t address, size_t length) {
    return VMReleaseMemoryRead(address, length);
  });
  ReleaseReplace(VMMemoryEngine.class, @selector(readAddress:type:), ^NSString *(id engine, uint64_t address, VMDataType type) {
    return VMReleaseMemoryReadValue(address, type);
  });
  ReleaseReplace(VMMemoryEngine.class, @selector(attachToPid:), ^BOOL(id engine, pid_t pid) { return NO; });
}

@interface VMReleaseScreenshotApp : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) VMRootViewController *root;
@property(nonatomic, copy) NSArray<NSString *> *names;
@property(nonatomic) NSUInteger step;
@end

@implementation VMReleaseScreenshotApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  [defaults setBool:YES forKey:@"has_agreed_disclaimer"];
  [defaults setInteger:1 forKey:@"app_theme"];
  [defaults removeObjectForKey:@"vm_bottom_tab_order"];
  [defaults removeObjectForKey:@"vm_settings_group"];
  [defaults registerDefaults:@{@"resultLimit":@100, @"floatTolerance":@.001, @"groupRange":@"0x100", @"lockInterval":@.5}];
  [VMLocalization.shared setLanguage:@"en"];
  ReleaseInstallFixtures();
  [VMUIHelper installAppearance];
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
  self.root = [VMRootViewController new];
  self.window.rootViewController = self.root;
  [self.window makeKeyAndVisible];
  self.names = @[@"APP_SELECT", @"MEM_DEBUG", @"MEM_BROWSER", @"MEM_HEX_MIX",
                @"POINTER_ANALYSIS", @"POINTER_VERIFY", @"POINTER_LOCKER", @"RVA_MANAGER",
                @"SCRIPT_EDITOR", @"SCRIPT_CREATE", @"SETTINGS", @"SETTINGS_DARK"];
  ReleaseLater(.5, ^{ [self nextCapture]; });
  return YES;
}
- (void)prepareDemoIdentity {
  VMMemoryEngine *engine = VMMemoryEngine.shared;
  engine.targetPid = 4242;
  engine.targetTask = mach_task_self();
  engine.currentProcessName = @"Atlas Demo";
  engine.currentBundleID = @"com.example.atlasdemo";
}
- (UIViewController *)scriptEditor {
  VMScriptModel *model = [VMScriptModel new];
  model.note = @"Read Results";
  model.author = @"VansonMod";
  model.desc = @"Read demo values";
  model.bundleID = @"com.example.atlasdemo";
  model.scriptContent = @"// Atlas Demo · read-only example\nconst results = vm.getResults(5, 0);\nconst count = vm.getResultsCount();\n\nvm.log('Atlas Demo');\nvm.log('Results: ' + count);\n\nfor (const row of results) {\n  vm.log(row.address + '  ' +\n    row.value);\n}\n";
  VMScriptViewController *page = [VMScriptViewController new];
  page.scriptModel = model;
  [page loadViewIfNeeded];
  UITextView *console = [page valueForKey:@"consoleView"];
  console.text = @"Atlas Demo\nResults: 12\n0x100806000  100\n0x100806020  100\n0x100806040  250\n0x100806060  100\n0x100806080  100";
  return page;
}
- (void)nextCapture {
  if (self.step == self.names.count) {
    printf("PASS: Release screenshots completed (%lu screenshots)\n", (unsigned long)self.step);
    fflush(stdout); exit(0);
  }
  NSString *name = self.names[self.step];
  [self prepareDemoIdentity];
  self.window.overrideUserInterfaceStyle = [name isEqual:@"SETTINGS_DARK"] ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
  NSUInteger tab = 0;
  BOOL child = NO;
  UIViewController *page = nil;
  if ([name isEqual:@"APP_SELECT"]) page = [VMAppSelectViewController new];
  else if ([name hasPrefix:@"MEM_"]) {
    tab = 1; child = ![name isEqual:@"MEM_DEBUG"];
    page = VMReleaseMemoryPage(name);
  } else if ([name hasPrefix:@"POINTER_"] || [name isEqual:@"RVA_MANAGER"]) {
    tab = [name isEqual:@"POINTER_ANALYSIS"] ? 1 : 3;
    child = [name isEqual:@"POINTER_ANALYSIS"] || [name isEqual:@"POINTER_VERIFY"];
    page = VMReleasePointerPage(name);
  } else if ([name isEqual:@"SCRIPT_EDITOR"]) {
    tab = 3; child = YES; page = [self scriptEditor];
  } else if ([name isEqual:@"SCRIPT_CREATE"]) {
    tab = 3;
    VMLockListViewController *toolbox = [VMLockListViewController new];
    toolbox.defaultTabIndex = 6;
    page = toolbox;
  } else if ([name hasPrefix:@"SETTINGS"]) {
    tab = 4; page = [VMSettingsViewController new];
  }
  ReleaseRequire(page != nil, [@"shipping page: " stringByAppendingString:name]);
  UINavigationController *nav = (id)self.root.viewControllers[tab];
  if (child) {
    UIViewController *parent = tab == 1 ? VMReleaseMemoryPage(@"MEM_DEBUG") : [VMLockListViewController new];
    parent.title = [VMLocalization.shared localizedString:tab == 1 ? @"Tab_Mod" : @"Tab_Toolbox"];
    [nav setViewControllers:@[parent, page] animated:NO];
  } else [nav setViewControllers:@[page] animated:NO];
  self.root.selectedIndex = tab;
  [page loadViewIfNeeded];
  if ([page isKindOfClass:VMSettingsViewController.class]) {
    [(VMSettingsViewController *)page selectSettingsGroup:0];
    VMUpdateManager.shared.checkState = VMUpdateCheckStateCurrent;
    [NSNotificationCenter.defaultCenter postNotificationName:kVMUpdateStateDidChangeNotification object:VMUpdateManager.shared];
  }
  [self.window layoutIfNeeded];
  ReleaseLater(.4, ^{
    if ([name isEqual:@"SCRIPT_CREATE"]) [(VMLockListViewController *)page addNewScript];
    ReleaseLater(2.3, ^{
      [self.window layoutIfNeeded];
      [self.root refreshBrandingOverlay];
      [self capture:name];
      void (^advance)(void) = ^{ self.step++; [self nextCapture]; };
      if (page.presentedViewController) [page dismissViewControllerAnimated:NO completion:advance];
      else advance();
    });
  });
}
- (void)capture:(NSString *)name {
  NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"ReleaseScreenshots"];
  [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:self.window.bounds.size];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [self.window drawViewHierarchyInRect:self.window.bounds afterScreenUpdates:YES];
  }];
  NSString *file = [folder stringByAppendingPathComponent:[name stringByAppendingString:@".PNG"]];
  ReleaseRequire([UIImagePNGRepresentation(image) writeToFile:file atomically:YES], [@"captured " stringByAppendingString:name]);
}
@end

int main(int argc, char **argv) {
  @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(VMReleaseScreenshotApp.class)); }
}
