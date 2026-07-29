#import "VMAppDelegate.h"
#import "VMRootViewController.h"
#import "include/VMDataSession.h"
#import "include/VMLocalization.h"
#import "include/VMLockManager.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerManager.h"
#import "src/utils/helpers/VMUIHelper.h"
#import "src/utils/managers/VMImportHandler.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMAppDelegate ()
@property(nonatomic, strong) AVAudioPlayer *backgroundPlayer;
- (void)checkAppReinstallOrUpdate;
- (void)setupDefaultSettingsIfNeeded;
- (void)startKeepAlive;
@end

@implementation VMAppDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

  [[NSUserDefaults standardUserDefaults] registerDefaults:@{
    @"app_theme" : @1,
    @"resultLimit" : @100,
    @"groupRange" : @"0x100",
    @"floatTolerance" : @0.001,
    @"lockInterval" : @0.5,
    @"preventSleep" : @NO,
    @"fuzzyRepeatCustomEnabled" : @NO
  }];

  [self checkAppReinstallOrUpdate];

  [self setupDefaultSettingsIfNeeded];

  if (@available(iOS 13.0, *)) {
    self.window.backgroundColor = [UIColor systemBackgroundColor];
  } else {
    self.window.backgroundColor = [UIColor systemBackgroundColor];
  }

  NSInteger themeIdx =
      [[NSUserDefaults standardUserDefaults] integerForKey:@"app_theme"];
  if (@available(iOS 13.0, *)) {
    if (themeIdx == 1) {
      self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    } else if (themeIdx == 2) {
      self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    } else {
      self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
    }
  }

  self.window.rootViewController = [[VMRootViewController alloc] init];
  [self.window makeKeyAndVisible];

  if (@available(iOS 15.0, *)) {
    UINavigationBarAppearance *appearance =
        [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];

    [UINavigationBar appearance].standardAppearance = appearance;
    [UINavigationBar appearance].scrollEdgeAppearance = appearance;
    [UINavigationBar appearance].compactAppearance = appearance;

    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    [tabAppearance configureWithDefaultBackground];
    [UITabBar appearance].standardAppearance = tabAppearance;
    [UITabBar appearance].scrollEdgeAppearance = tabAppearance;
  }

  [self startKeepAlive];

  return YES;
}

- (void)startKeepAlive {
  [[AVAudioSession sharedInstance]
      setCategory:AVAudioSessionCategoryPlayback
      withOptions:AVAudioSessionCategoryOptionMixWithOthers
            error:nil];
  [[AVAudioSession sharedInstance] setActive:YES error:nil];

  unsigned char wavHeader[] = {
      0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56,
      0x45, 0x66, 0x6D, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00,
      0x01, 0x00, 0x44, 0xAC, 0x00, 0x00, 0x88, 0x58, 0x01, 0x00, 0x02,
      0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61, 0x00, 0x00, 0x00, 0x00};
  NSMutableData *soundData = [NSMutableData dataWithBytes:wavHeader
                                                   length:sizeof(wavHeader)];
  [soundData appendData:[NSMutableData dataWithLength:100]];

  NSError *err;
  self.backgroundPlayer = [[AVAudioPlayer alloc] initWithData:soundData
                                                        error:&err];
  if (self.backgroundPlayer) {
    self.backgroundPlayer.numberOfLoops = -1;
    self.backgroundPlayer.volume = 0.01;
    [self.backgroundPlayer prepareToPlay];
    [self.backgroundPlayer play];
  }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  __block UIBackgroundTaskIdentifier taskID =
      [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:taskID];
        taskID = UIBackgroundTaskInvalid;
      }];
  if (![self.backgroundPlayer isPlaying])
    [self.backgroundPlayer play];
}

- (void)applicationWillTerminate:(UIApplication *)application {
  [[VMMemoryEngine shared] clearSession];
}

- (void)checkAppReinstallOrUpdate {
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];

  NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

  NSError *error = nil;
  NSDictionary *attrs =
      [[NSFileManager defaultManager] attributesOfItemAtPath:bundlePath
                                                       error:&error];

  if (attrs) {
    
    NSDate *bundleDate = attrs[NSFileModificationDate];
    
    NSString *currentVer =
        [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];

    NSString *currentSignature =
        [NSString stringWithFormat:@"%@_%@", currentVer, bundleDate];

    NSString *savedSignature = [def objectForKey:@"last_install_signature"];

    if (!savedSignature || ![savedSignature isEqualToString:currentSignature]) {
      
      [def setBool:NO forKey:@"has_agreed_disclaimer"];
      
      [def removeObjectForKey:@"fuzzySearchMode"];
      [def removeObjectForKey:@"fastScanEnabled"];

      [def setObject:currentSignature forKey:@"last_install_signature"];

      [def synchronize];
    }
  }
}
- (void)setupDefaultSettingsIfNeeded {
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];

  if (![def boolForKey:@"has_initialized_config_v2"]) {

    [def setObject:@"0x100000000" forKey:@"startAddr"];
    
    [def setObject:@"0x100" forKey:@"groupRange"];
    [def setObject:@"100" forKey:@"resultLimit"];
    [def setObject:@"0.001" forKey:@"floatTolerance"];

    [def setFloat:0.5f forKey:@"lockInterval"];
    [def setInteger:1 forKey:@"app_theme"];
    [def setObject:@"Auto" forKey:@"user_lang"];
    [def setBool:NO forKey:@"fuzzyRepeatCustomEnabled"];

    [def setBool:YES forKey:@"has_initialized_config_v2"];
    [def setBool:NO
          forKey:@"has_agreed_disclaimer"]; 
    [def synchronize];
  }
}

- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:
                (NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {

  if (url.isFileURL) {
    return [[VMImportHandler shared] handleImportWithData:nil url:url];
  }

  if ([url.scheme isEqualToString:@"vansonmod"]) {
    NSURLComponents *components = [NSURLComponents componentsWithURL:url
                                             resolvingAgainstBaseURL:NO];
    NSArray<NSURLQueryItem *> *queryItems = components.queryItems;
    NSString *dataBase64 = nil;

    for (NSURLQueryItem *item in queryItems) {
      if ([item.name isEqualToString:@"data"])
        dataBase64 = item.value;
    }

    if (dataBase64) {
      NSData *decodedData =
          [[NSData alloc] initWithBase64EncodedString:dataBase64 options:0];
      if (decodedData) {
        
        return [[VMImportHandler shared] handleImportWithData:decodedData
                                                          url:nil];
      }
    }
  }
  return YES;
}

#pragma mark - [新增] 文件直接处理方法

#pragma mark - 过时方法清理

- (void)notifyJumpToTab:(NSInteger)targetTab {
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VM_JUMP_TO_TAB"
                                                        object:nil
                                                      userInfo:@{
                                                        @"tab" : @(targetTab)
                                                      }];
  });
}

- (void)showToast:(NSString *)message {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *rootVC = self.window.rootViewController;
    if (@available(iOS 13.0, *)) {
      UIWindowScene *activeScene = nil;
      for (UIScene *scene in
           [[UIApplication sharedApplication] connectedScenes]) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
          activeScene = (UIWindowScene *)scene;
          break;
        }
      }
      if (activeScene) {
        for (UIWindow *window in activeScene.windows) {
          if (window.isKeyWindow) {
            rootVC = window.rootViewController;
            break;
          }
        }
      }
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:nil
                         message:message
                  preferredStyle:UIAlertControllerStyleAlert];

    [rootVC presentViewController:alert
                         animated:YES
                       completion:^{
                         dispatch_after(
                             dispatch_time(DISPATCH_TIME_NOW,
                                           (int64_t)(1.5 * NSEC_PER_SEC)),
                             dispatch_get_main_queue(), ^{
                               [alert dismissViewControllerAnimated:YES
                                                         completion:nil];
                             });
                       }];
  });
}

@end
