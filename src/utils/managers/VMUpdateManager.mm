#import "VMUpdateManager.h"
#import "include/VMLocalization.h"
#import <TargetConditionals.h>
#import <objc/message.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])
#define GITHUB_API_URL @"https://api.github.com/repos/vaenshine/VansonMod/releases/latest"

static NSString *const VMReleasePage = @"https://github.com/vaenshine/VansonMod/releases/latest";

static void VMUpdateOnMainThread(dispatch_block_t work) {
  if (NSThread.isMainThread) work();
  else dispatch_async(dispatch_get_main_queue(), work);
}

static NSString *VMNumericReleaseVersion(NSString *tag) {
  if (![tag isKindOfClass:NSString.class]) return nil;
  NSString *version = tag;
  if ([version hasPrefix:@"v"] || [version hasPrefix:@"V"]) version = [version substringFromIndex:1];
  NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+(?:\\.[0-9]+)*$" options:0 error:nil];
  return version.length && [pattern numberOfMatchesInString:version options:0 range:NSMakeRange(0, version.length)] == 1 ? version : nil;
}

static NSURLComponents *VMOfficialReleaseComponents(NSURL *url) {
  if (!url) return nil;
  NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
  if (![parts.scheme.lowercaseString isEqual:@"https"] || ![parts.host.lowercaseString isEqual:@"github.com"] ||
      parts.user != nil || parts.password != nil || parts.port != nil || parts.query != nil || parts.fragment != nil) return nil;
  return parts;
}

static NSURL *VMValidatedPackageURL(NSURL *url, NSString *expectedTag, NSString *expectedName) {
  NSURLComponents *parts = VMOfficialReleaseComponents(url);
  if (![parts.percentEncodedPath isEqual:parts.path]) return nil;
  NSArray<NSString *> *path = [parts.path componentsSeparatedByString:@"/"];
  if (path.count != 7 || ![path[1] isEqual:@"vaenshine"] || ![path[2] isEqual:@"VansonMod"] ||
      ![path[3] isEqual:@"releases"] || ![path[4] isEqual:@"download"]) return nil;
  NSString *version = VMNumericReleaseVersion(path[5]);
  if (!version || (expectedTag && ![path[5] isEqual:expectedTag]) || (expectedName && ![path[6] isEqual:expectedName])) return nil;
  NSString *tipaName = [NSString stringWithFormat:@"VansonMod_v%@.tipa", version];
  NSString *ipaName = [NSString stringWithFormat:@"VansonMod_v%@.ipa", version];
  return ([path[6] isEqual:tipaName] || [path[6] isEqual:ipaName]) ? parts.URL : nil;
}

static NSURL *VMValidatedReleasePageURL(NSURL *url) {
  NSURLComponents *parts = VMOfficialReleaseComponents(url);
  NSArray<NSString *> *path = [parts.path componentsSeparatedByString:@"/"];
  if (path.count >= 4 && [path[1] isEqual:@"vaenshine"] && [path[2] isEqual:@"VansonMod"] && [path[3] isEqual:@"releases"]) {
    if (path.count == 4 || (path.count == 5 && [path[4] isEqual:@"latest"]) ||
        (path.count == 6 && [path[4] isEqual:@"tag"] && VMNumericReleaseVersion(path[5]))) return parts.URL;
  }
  return [NSURL URLWithString:VMReleasePage];
}

static NSURL *VMInstallAssetFromRelease(NSDictionary *release) {
  NSString *tag = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : nil;
  NSString *version = VMNumericReleaseVersion(tag);
  NSArray *assets = [release[@"assets"] isKindOfClass:NSArray.class] ? release[@"assets"] : nil;
  if (!version) return nil;
  // Select an exact versioned package; helper apps and DEB variants stay out of this flow.
  for (NSString *extension in @[@"tipa", @"ipa"]) {
    NSString *name = [NSString stringWithFormat:@"VansonMod_v%@.%@", version, extension];
    for (id asset in assets) {
      if (![asset isKindOfClass:NSDictionary.class] || ![asset[@"name"] isEqual:name] ||
          ![asset[@"browser_download_url"] isKindOfClass:NSString.class]) continue;
      if (asset[@"state"] && ![asset[@"state"] isEqual:@"uploaded"]) continue;
      NSURL *url = VMValidatedPackageURL([NSURL URLWithString:asset[@"browser_download_url"]], tag, name);
      if (url) return url;
    }
  }
  return nil;
}

@interface VMUpdateManager ()
@property (nonatomic, strong) NSMutableArray *pendingCompletions;
@property (nonatomic) BOOL requestInFlight;
@property (nonatomic) BOOL manualRequestPending;
@property (nonatomic) BOOL openingInstaller;
@end

@implementation VMUpdateManager

+ (instancetype)shared {
  static VMUpdateManager *s;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ s = [self new]; });
  return s;
}

- (void)performAutoCheck {
  [self checkForUpdateManual:NO completion:nil];
}

- (NSURLSession *)updateSession {
  return NSURLSession.sharedSession;
}

- (NSString *)trollStoreBundleIdentifier {
#if TARGET_OS_SIMULATOR || TARGET_OS_MACCATALYST
  return nil;
#else
  NSString *container = NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;
  NSFileManager *files = NSFileManager.defaultManager;
  BOOL regular = [files fileExistsAtPath:[container stringByAppendingPathComponent:@"_TrollStore"]];
  BOOL lite = [files fileExistsAtPath:[container stringByAppendingPathComponent:@"_TrollStoreLite"]];
  if (regular == lite) return nil;
  return lite ? @"com.opa334.TrollStoreLite" : @"com.opa334.TrollStore";
#endif
}

- (VMUpdateInstallKind)installationKind {
  if ([self trollStoreBundleIdentifier]) return VMUpdateInstallKindTrollStore;
#if !TARGET_OS_SIMULATOR && !TARGET_OS_MACCATALYST
  NSString *parent = NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent;
  if ([parent.lastPathComponent isEqual:@"Applications"]) return VMUpdateInstallKindPackageManager;
#endif
  return VMUpdateInstallKindUnknown;
}

- (BOOL)canOpenTrollStoreInstaller {
  NSString *identifier = [self trollStoreBundleIdentifier];
  if (!identifier) return NO;
  @try {
    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    SEL lookup = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (![proxyClass respondsToSelector:lookup]) return NO;
    id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass, lookup, identifier);
    SEL bundleSelector = NSSelectorFromString(@"bundleURL");
    if (![proxy respondsToSelector:bundleSelector]) return NO;
    NSURL *bundle = ((id (*)(id, SEL))objc_msgSend)(proxy, bundleSelector);
    if (![bundle isKindOfClass:NSURL.class] || !bundle.isFileURL) return NO;
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:[bundle URLByAppendingPathComponent:@"Info.plist"]];
    if (![info[@"CFBundleIdentifier"] isEqual:identifier]) return NO;
    BOOL configured = NO;
    if ([info[@"CFBundleURLTypes"] isKindOfClass:NSArray.class]) {
      for (id type in info[@"CFBundleURLTypes"]) {
        if (![type isKindOfClass:NSDictionary.class] || ![type[@"CFBundleURLSchemes"] isKindOfClass:NSArray.class]) continue;
        for (id scheme in type[@"CFBundleURLSchemes"])
          if ([scheme isKindOfClass:NSString.class] && [scheme caseInsensitiveCompare:@"apple-magnifier"] == NSOrderedSame) configured = YES;
      }
    }
    if (!configured) return NO;
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL workspaceSelector = NSSelectorFromString(@"defaultWorkspace");
    SEL handlersSelector = NSSelectorFromString(@"applicationsAvailableForHandlingURLScheme:");
    if (![workspaceClass respondsToSelector:workspaceSelector]) return NO;
    id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, workspaceSelector);
    if (![workspace respondsToSelector:handlersSelector]) return NO;
    id handlers = ((id (*)(id, SEL, id))objc_msgSend)(workspace, handlersSelector, @"apple-magnifier");
    if (![handlers isKindOfClass:NSArray.class]) return NO;
    NSMutableSet<NSString *> *identifiers = [NSMutableSet set];
    SEL identifierSelector = NSSelectorFromString(@"applicationIdentifier");
    for (id handler in handlers) {
      if (![handler respondsToSelector:identifierSelector]) return NO;
      id handlerID = ((id (*)(id, SEL))objc_msgSend)(handler, identifierSelector);
      if (![handlerID isKindOfClass:NSString.class] || ![handlerID length]) return NO;
      [identifiers addObject:handlerID];
    }
    // The system Magnifier shares this scheme. Only hand off when the registered
    // handler is unambiguously the installer that owns this application.
    if (identifiers.count != 1 || ![identifiers containsObject:identifier]) return NO;
    return [UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:@"apple-magnifier://install"]];
  } @catch (__unused NSException *exception) {
    return NO;
  }
}

- (void)checkForUpdateManual:(BOOL)manual completion:(void (^)(void))completion {
  if (!NSThread.isMainThread) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self checkForUpdateManual:manual completion:completion];
    });
    return;
  }

  NSString *localVer = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
  if ([localVer hasPrefix:@"Test"]) {
    if (completion) completion();
    return;
  }

  if (!self.pendingCompletions) self.pendingCompletions = [NSMutableArray array];
  if (completion) [self.pendingCompletions addObject:[completion copy]];
  self.manualRequestPending |= manual;
  // A manual check can join the automatic request already in progress.
  if (self.requestInFlight) return;
  self.requestInFlight = YES;
  self.checkState = VMUpdateCheckStateChecking;
  [[NSNotificationCenter defaultCenter] postNotificationName:kVMUpdateStateDidChangeNotification
                                                      object:self];

  NSURL *url = [NSURL URLWithString:GITHUB_API_URL];
  NSURLRequest *request = [NSURLRequest requestWithURL:url
                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                       timeoutInterval:15.0];
  [[[self updateSession] dataTaskWithRequest:request
      completionHandler:^(NSData *data, NSURLResponse *res, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          NSString *failureKey = nil;
          NSDictionary *json = nil;
          NSString *remoteVer = nil;
          NSInteger statusCode = [res isKindOfClass:NSHTTPURLResponse.class]
                                     ? ((NSHTTPURLResponse *)res).statusCode : 0;
          if (error || !data || statusCode < 200 || statusCode >= 300) {
            failureKey = @"Err_Network_Failed";
          } else {
            NSError *jsonErr = nil;
            id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (!jsonErr && [decoded isKindOfClass:NSDictionary.class]) json = decoded;
            id tag = json[@"tag_name"];
            if ([tag isKindOfClass:NSString.class]) {
              remoteVer = [tag stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
              if ([remoteVer hasPrefix:@"v"] || [remoteVer hasPrefix:@"V"]) remoteVer = [remoteVer substringFromIndex:1];
            }
            // Stable releases use numeric version components. API error
            // objects and non-version tags must never produce "latest".
            NSRegularExpression *versionPattern = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+(?:\\.[0-9]+)*$"
                                                                                            options:0 error:nil];
            BOOL validRemote = remoteVer.length && [versionPattern numberOfMatchesInString:remoteVer options:0 range:NSMakeRange(0, remoteVer.length)] == 1;
            BOOL validLocal = [localVer isKindOfClass:NSString.class] && localVer.length &&
                [versionPattern numberOfMatchesInString:localVer options:0 range:NSMakeRange(0, localVer.length)] == 1;
            if (!validRemote || !validLocal) failureKey = @"Err_Invalid_JSON";
          }

          if (failureKey) {
            self.checkState = VMUpdateCheckStateFailed;
          } else {
            self.hasNewVersion = [remoteVer compare:localVer options:NSNumericSearch] == NSOrderedDescending;
            self.checkState = self.hasNewVersion ? VMUpdateCheckStateAvailable : VMUpdateCheckStateCurrent;
            self.latestVersionStr = self.hasNewVersion ? remoteVer : nil;
            self.releaseNotes = self.hasNewVersion && [json[@"body"] isKindOfClass:NSString.class] ? json[@"body"] : nil;
            // The release page is optional in some responses; a valid GitHub
            // release tag always has a safe, usable repository fallback.
            NSURL *releaseURL = [json[@"html_url"] isKindOfClass:NSString.class] ? [NSURL URLWithString:json[@"html_url"]] : nil;
            self.downloadURL = self.hasNewVersion ? VMValidatedReleasePageURL(releaseURL).absoluteString : nil;
            self.tipaDownloadURL = self.hasNewVersion ? VMInstallAssetFromRelease(json).absoluteString : nil;
          }

          BOOL shouldShowAlert = self.manualRequestPending;
          NSArray *completions = [self.pendingCompletions copy];
          self.pendingCompletions = nil;
          self.manualRequestPending = NO;
          self.requestInFlight = NO;
          [[NSNotificationCenter defaultCenter] postNotificationName:kVMUpdateStateDidChangeNotification
                                                              object:self];
          [[NSNotificationCenter defaultCenter] postNotificationName:kVMUpdateAvailableNotification
                                                              object:self];
          for (void (^callback)(void) in completions) callback();
          if (shouldShowAlert) {
            if (failureKey) {
              [self showAlert:TR(@"Alert_Error") msg:TR(failureKey)];
            } else if (self.hasNewVersion) {
              [self showUpdateAlertFromViewController:[self topViewController]];
            } else {
              [self showAlert:TR(@"Alert_Success") msg:TR(@"Update_No_New")];
            }
          }
        });
      }] resume];
}

- (void)openExternalURL:(NSURL *)url completion:(void (^)(BOOL))completion {
  [UIApplication.sharedApplication openURL:url options:@{} completionHandler:completion];
}

- (void)presentUpdatePrompt:(UIAlertController *)alert fromViewController:(UIViewController *)vc {
  UIViewController *host = vc ?: [self topViewController];
  if (!host) return;
  if ([host isKindOfClass:UIAlertController.class] && host.presentingViewController)
    host = host.presentingViewController;
  if ([host.presentedViewController isKindOfClass:UIAlertController.class]) {
    [host dismissViewControllerAnimated:YES completion:^{
      [self presentUpdatePrompt:alert fromViewController:host];
    }];
    return;
  }
  while (host.presentedViewController) host = host.presentedViewController;
  id<UIViewControllerTransitionCoordinator> transition = host.transitionCoordinator;
  if (transition) {
    BOOL deferred = [transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
      [self presentUpdatePrompt:alert fromViewController:host];
    }];
    if (deferred) return;
  }
  [host presentViewController:alert animated:YES completion:nil];
}

- (void)openReleasePage:(NSURL *)url fromViewController:(UIViewController *)vc {
  NSURL *page = VMValidatedReleasePageURL(url);
  __weak UIViewController *weakVC = vc;
  [self openExternalURL:page completion:^(BOOL success) {
    if (success) return;
    VMUpdateOnMainThread(^{
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Error")
          message:TR(@"Update_Open_Failed") preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleCancel handler:nil]];
      [self presentUpdatePrompt:alert fromViewController:weakVC];
    });
  }];
}

- (void)showInstallFailure:(NSString *)messageKey releasePageURL:(NSURL *)releasePageURL fromViewController:(UIViewController *)vc {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Alert_Error")
      message:TR(messageKey) preferredStyle:UIAlertControllerStyleAlert];
  __weak UIViewController *weakVC = vc;
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Update_Release_Page") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self openReleasePage:releasePageURL fromViewController:weakVC];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [self presentUpdatePrompt:alert fromViewController:vc];
}

- (void)installTIPAAtURL:(NSURL *)url releasePageURL:(NSURL *)releasePageURL fromViewController:(UIViewController *)vc {
  if (self.openingInstaller) return;
  NSURL *package = VMValidatedPackageURL(url, nil, nil);
  NSURL *page = VMValidatedReleasePageURL(releasePageURL);
  if (!package) {
    [self showInstallFailure:@"Update_Package_Unavailable" releasePageURL:page fromViewController:vc];
    return;
  }
  if ([self installationKind] != VMUpdateInstallKindTrollStore || ![self canOpenTrollStoreInstaller]) {
    [self showInstallFailure:@"Update_Installer_Unavailable" releasePageURL:page fromViewController:vc];
    return;
  }
  NSURLComponents *handoff = [NSURLComponents new];
  handoff.scheme = @"apple-magnifier";
  handoff.host = @"install";
  handoff.queryItems = @[[NSURLQueryItem queryItemWithName:@"url" value:package.absoluteString]];
  self.openingInstaller = YES;
  __weak UIViewController *weakVC = vc;
  [self openExternalURL:handoff.URL completion:^(BOOL success) {
    VMUpdateOnMainThread(^{
      self.openingInstaller = NO;
      if (!success) [self showInstallFailure:@"Update_Installer_Unavailable" releasePageURL:page fromViewController:weakVC];
    });
  }];
}

- (UIAlertController *)updateAlertForViewController:(UIViewController *)vc {
  VMUpdateInstallKind kind = [self installationKind];
  NSURL *package = VMValidatedPackageURL([NSURL URLWithString:self.tipaDownloadURL ?: @""], nil, nil);
  NSURL *page = VMValidatedReleasePageURL([NSURL URLWithString:self.downloadURL ?: @""]);
  NSMutableArray<NSString *> *paragraphs = [NSMutableArray array];
  if (self.releaseNotes.length) [paragraphs addObject:self.releaseNotes];
  if (kind == VMUpdateInstallKindTrollStore)
    [paragraphs addObject:TR(package ? @"Update_Install_Hint" : @"Update_Package_Unavailable")];
  else if (kind == VMUpdateInstallKindPackageManager) [paragraphs addObject:TR(@"Update_Deb_Hint")];
  NSString *title = [NSString stringWithFormat:@"%@ v%@", TR(@"Update_Found"), self.latestVersionStr ?: @""];
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
      message:[paragraphs componentsJoinedByString:@"\n\n"] preferredStyle:UIAlertControllerStyleAlert];
  __weak UIViewController *weakVC = vc;
  if (kind == VMUpdateInstallKindTrollStore && package) {
    UIAlertAction *install = [UIAlertAction actionWithTitle:TR(@"Update_Install_TrollStore") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [self installTIPAAtURL:package releasePageURL:page fromViewController:weakVC];
    }];
    [alert addAction:install];
    alert.preferredAction = install;
  }
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Update_Release_Page") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [self openReleasePage:page fromViewController:weakVC];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
  return alert;
}

- (void)showUpdateAlertFromViewController:(UIViewController *)vc {
  UIViewController *host = vc ?: [self topViewController];
  [self presentUpdatePrompt:[self updateAlertForViewController:host] fromViewController:host];
}

- (void)showAlert:(NSString *)title msg:(NSString *)msg {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [[self topViewController] presentViewController:alert
                                         animated:YES
                                       completion:nil];
}

- (UIViewController *)topViewController {
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

  UIViewController *top = window.rootViewController;
  while (top.presentedViewController) {
    top = top.presentedViewController;
  }
  return top;
}

@end
