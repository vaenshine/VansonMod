#import <UIKit/UIKit.h>
#import "src/utils/managers/VMUpdateManager.h"
#import "include/VMLocalization.h"
#import <objc/runtime.h>

// Isolate network behavior from translations and presented UIKit alerts.
@implementation VMLocalization
+ (instancetype)shared { static VMLocalization *s; if (!s) s = [self new]; return s; }
- (NSString *)localizedString:(NSString *)key { return key; }
@end

static NSUInteger checks;
static void Check(BOOL passed, NSString *message) {
  if (!passed) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
  checks++;
}

@interface VMUpdateManager (TestSeams)
- (NSURLSession *)updateSession;
- (void)showAlert:(NSString *)title msg:(NSString *)message;
- (UIViewController *)topViewController;
- (BOOL)canOpenTrollStoreInstaller;
- (void)openExternalURL:(NSURL *)url completion:(void (^)(BOOL))completion;
- (UIAlertController *)updateAlertForViewController:(UIViewController *)vc;
- (void)installTIPAAtURL:(NSURL *)url releasePageURL:(NSURL *)releasePageURL fromViewController:(UIViewController *)vc;
- (void)presentUpdatePrompt:(UIAlertController *)alert fromViewController:(UIViewController *)vc;
@end

@interface UpdateFakeTask : NSObject
@property(nonatomic, copy) void (^operation)(void);
- (void)resume;
@end
@implementation UpdateFakeTask
- (void)resume {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), self.operation);
}
@end

@interface UpdateFakeSession : NSObject
@property(nonatomic) NSInteger status;
@property(nonatomic) NSUInteger requests;
@property(nonatomic, strong) NSData *body;
@property(nonatomic, strong) NSError *error;
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                          completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion;
@end
@implementation UpdateFakeSession
- (instancetype)init {
  if ((self = [super init])) { self.status = 200; self.body = [@"{\"tag_name\":\"v3.5\"}" dataUsingEncoding:NSUTF8StringEncoding]; }
  return self;
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                          completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completion {
  Check(NSThread.isMainThread, @"request creation runs on main thread");
  self.requests++;
  NSData *body = self.body;
  NSError *error = self.error;
  NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:self.status HTTPVersion:@"HTTP/1.1" headerFields:nil];
  UpdateFakeTask *task = [UpdateFakeTask new];
  task.operation = ^{ completion(body, response, error); };
  return (NSURLSessionDataTask *)task;
}
@end

@interface UpdateFixture : VMUpdateManager
@property(nonatomic, strong) UpdateFakeSession *fake;
@property(nonatomic) NSUInteger alerts;
@property(nonatomic) NSUInteger updateAlerts;
@property(nonatomic) BOOL exerciseUpdatePrompt;
@end
@implementation UpdateFixture
- (instancetype)init { if ((self = [super init])) self.fake = [UpdateFakeSession new]; return self; }
- (NSURLSession *)updateSession { return (NSURLSession *)self.fake; }
- (void)showAlert:(NSString *)title msg:(NSString *)message { self.alerts++; }
- (UIViewController *)topViewController { return nil; }
- (void)showUpdateAlertFromViewController:(UIViewController *)vc {
  self.updateAlerts++;
  if (self.exerciseUpdatePrompt) [super showUpdateAlertFromViewController:vc];
}
@end

@interface UpdateInstallFixture : UpdateFixture
@property(nonatomic) VMUpdateInstallKind fixtureInstallKind;
@property(nonatomic) BOOL installerAvailable;
@property(nonatomic) BOOL openingSucceeds;
@property(nonatomic, strong) NSMutableArray<NSURL *> *openedURLs;
@property(nonatomic, strong) NSMutableArray<UIAlertController *> *prompts;
@end
@implementation UpdateInstallFixture
- (instancetype)init {
  if ((self = [super init])) {
    self.exerciseUpdatePrompt = YES;
    self.fixtureInstallKind = VMUpdateInstallKindTrollStore;
    self.installerAvailable = YES;
    self.openingSucceeds = YES;
    self.openedURLs = [NSMutableArray array];
    self.prompts = [NSMutableArray array];
    self.hasNewVersion = YES;
    self.checkState = VMUpdateCheckStateAvailable;
    self.latestVersionStr = @"3.10";
    self.releaseNotes = @"Release notes";
    self.downloadURL = @"https://github.com/vaenshine/VansonMod/releases/tag/v3.10";
    self.tipaDownloadURL = @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa";
  }
  return self;
}
- (VMUpdateInstallKind)installationKind { return self.fixtureInstallKind; }
- (BOOL)canOpenTrollStoreInstaller { return self.installerAvailable; }
- (void)openExternalURL:(NSURL *)url completion:(void (^)(BOOL))completion {
  Check(NSThread.isMainThread, @"external handoff runs on main thread");
  Check(url != nil, @"external handoff has a URL");
  [self.openedURLs addObject:url];
  if (completion) completion(self.openingSucceeds);
}
- (void)presentUpdatePrompt:(UIAlertController *)alert fromViewController:(UIViewController *)vc {
  Check(NSThread.isMainThread, @"update prompts run on main thread");
  Check(vc != nil, @"update prompt preserves its presenting controller");
  [self.prompts addObject:alert];
}
@end

static void WaitUntil(BOOL (^finished)(void)) {
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:2];
  while (!finished() && deadline.timeIntervalSinceNow > 0)
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];
  Check(finished(), @"asynchronous request completes within the deadline");
}

static void ExpectState(UpdateFixture *fixture, VMUpdateCheckState expected) {
  __block BOOL finished = NO;
  [fixture checkForUpdateManual:NO completion:^{
    Check(NSThread.isMainThread, @"completion runs on main thread");
    Check(fixture.checkState == expected, @"completion sees the final state");
    finished = YES;
  }];
  Check(fixture.checkState == VMUpdateCheckStateChecking, @"request immediately exposes Checking");
  WaitUntil(^BOOL { return finished; });
  Check(fixture.alerts == 0 && fixture.updateAlerts == 0, @"automatic checks remain silent");
}

static NSDictionary *ReleaseAsset(NSString *name, id url) {
  return @{@"name": name, @"browser_download_url": url};
}

static NSData *ReleaseWithAssets(id assets, NSString *tag) {
  NSMutableDictionary *release = [@{@"tag_name": tag, @"body": @"Changes",
    @"html_url": @"https://github.com/vaenshine/VansonMod/releases/tag/v3.10"} mutableCopy];
  if (assets) release[@"assets"] = assets;
  return [NSJSONSerialization dataWithJSONObject:release options:0 error:nil];
}

static void ExpectAsset(id assets, NSString *tag, NSString *expected, NSString *message) {
  UpdateFixture *fixture = [UpdateFixture new];
  fixture.fake.body = ReleaseWithAssets(assets, tag);
  ExpectState(fixture, VMUpdateCheckStateAvailable);
  Check(expected ? [fixture.tipaDownloadURL isEqualToString:expected] : fixture.tipaDownloadURL == nil, message);
  Check(fixture.downloadURL.length > 0, @"every available release keeps a release-page fallback");
}

static void RunAssetTests(void) {
  NSString *tipa = @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa";
  NSString *ipa = @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.ipa";
  NSDictionary *tipaAsset = ReleaseAsset(@"VansonMod_v3.10.tipa", tipa);
  NSDictionary *ipaAsset = ReleaseAsset(@"VansonMod_v3.10.ipa", ipa);
  ExpectAsset(@[tipaAsset], @"v3.10", tipa, @"official TIPA is selected for the matching release");
  ExpectAsset(@[ipaAsset], @"v3.10", ipa, @"official IPA is available when the release has no TIPA");
  ExpectAsset(@[ipaAsset, tipaAsset], @"v3.10", tipa, @"TIPA takes precedence when IPA appears first");
  ExpectAsset(@[tipaAsset, ipaAsset], @"v3.10", tipa, @"TIPA takes precedence when IPA appears last");
  NSString *uppercaseTag = [tipa stringByReplacingOccurrencesOfString:@"/v3.10/" withString:@"/V3.10/"];
  ExpectAsset(@[ReleaseAsset(@"VansonMod_v3.10.tipa", uppercaseTag)], @"V3.10", uppercaseTag,
              @"asset path follows the release's exact uppercase tag");
  NSString *bareTag = [tipa stringByReplacingOccurrencesOfString:@"/v3.10/" withString:@"/3.10/"];
  ExpectAsset(@[ReleaseAsset(@"VansonMod_v3.10.tipa", bareTag)], @"3.10", bareTag,
              @"asset path follows a release tag without a v prefix");

  for (id assets in @[[NSNull null], @"invalid", @{}, @[],
                     @[[NSNull null], @42, @"invalid", @{}],
                     @[@{@"name": @42, @"browser_download_url": tipa}],
                     @[ReleaseAsset(@"VansonMod_v3.10.tipa", [NSNull null])],
                     @[ReleaseAsset(@"VansonMod_v3.10.tipa", @42)],
                     @[ReleaseAsset(@"VansonMod_v3.10.tipa", @[])]]) {
    ExpectAsset(assets, @"v3.10", nil, @"malformed asset metadata preserves page-only updates");
  }
  ExpectAsset(nil, @"v3.10", nil, @"releases with no assets preserve page-only updates");
  ExpectAsset(@[ReleaseAsset(@"com.vanson.modifier_3.10_iphoneos-arm.deb",
                 @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/com.vanson.modifier_3.10_iphoneos-arm.deb")],
              @"v3.10", nil, @"DEB archives never become a TrollStore install asset");
  ExpectAsset(@[ReleaseAsset(@"OtherApp_v3.10.tipa", tipa)], @"v3.10", nil,
              @"a different product's asset name is rejected");
  ExpectAsset(@[ReleaseAsset(@"VansonMod_v3.9.tipa", tipa)], @"v3.10", nil,
              @"a stale asset name is rejected");
  ExpectAsset(@[ReleaseAsset(@"VansonMod_v3.10.ipa", tipa)], @"v3.10", nil,
              @"asset name and download filename must agree");

  NSArray<NSString *> *untrustedURLs = @[
    @"http://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"file:///vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://evil.example/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://github.com.evil.example/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://github.com@evil.example/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://user@github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://user:password@github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://github.com:443/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://github.com/other/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://github.com/vaenshine/OtherApp/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.9/VansonMod_v3.10.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/V3.10/VansonMod_v3.10.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.9.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.deb",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa?url=https://evil.example/app.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa#fragment",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/../VansonMod_v3.10.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/%2e%2e/VansonMod_v3.10.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10%2fVansonMod_v3.10.tipa",
    @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa/extra",
    @"https://github.com//vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa",
    @"apple-magnifier://install?url=https://evil.example/app.tipa"
  ];
  for (NSString *url in untrustedURLs)
    ExpectAsset(@[ReleaseAsset(@"VansonMod_v3.10.tipa", url)], @"v3.10", nil,
                [@"reject untrusted asset: " stringByAppendingString:url]);
  ExpectAsset(@[ReleaseAsset(@"VansonMod_v3.10.tipa", untrustedURLs.firstObject), tipaAsset],
              @"v3.10", tipa, @"an invalid first asset does not hide a later official TIPA");

  UpdateFixture *fixture = [UpdateFixture new];
  fixture.fake.body = ReleaseWithAssets(@[tipaAsset], @"v3.10");
  ExpectState(fixture, VMUpdateCheckStateAvailable);
  fixture.fake.body = ReleaseWithAssets(@[], @"v3.11");
  ExpectState(fixture, VMUpdateCheckStateAvailable);
  Check(fixture.tipaDownloadURL == nil, @"a later assetless release clears the previous install URL");
  fixture.fake.body = ReleaseWithAssets(@[tipaAsset], @"v3.10");
  ExpectState(fixture, VMUpdateCheckStateAvailable);
  fixture.fake.body = ReleaseWithAssets(@[], @"v3.5");
  ExpectState(fixture, VMUpdateCheckStateCurrent);
  Check(fixture.tipaDownloadURL == nil, @"Current clears the previous install URL");
}

// Capture only test-created handlers through the public factory. The suite
// invokes actions without presenting UIKit sheets or opening external apps.
static const void *ActionHandlerKey = &ActionHandlerKey;
static UIAlertAction *(*OriginalActionFactory)(id, SEL, NSString *, UIAlertActionStyle, void (^)(UIAlertAction *));
static UIAlertAction *CaptureActionFactory(id cls, SEL sel, NSString *title, UIAlertActionStyle style,
                                          void (^handler)(UIAlertAction *)) {
  UIAlertAction *action = OriginalActionFactory(cls, sel, title, style, handler);
  if (handler) objc_setAssociatedObject(action, ActionHandlerKey, handler, OBJC_ASSOCIATION_COPY_NONATOMIC);
  return action;
}

static UIAlertAction *FindAction(UIAlertController *alert, NSString *title) {
  for (UIAlertAction *action in alert.actions) if ([action.title isEqualToString:title]) return action;
  Check(NO, [@"expected action: " stringByAppendingString:title]);
  return nil;
}

static void InvokeAction(UIAlertController *alert, NSString *title) {
  UIAlertAction *action = FindAction(alert, title);
  void (^handler)(UIAlertAction *) = objc_getAssociatedObject(action, ActionHandlerKey);
  Check(handler != nil, @"selected action has an executable handler");
  handler(action);
}

static void CheckPromptActions(UIAlertController *alert, NSArray<NSString *> *titles) {
  NSMutableArray *actual = [NSMutableArray array];
  NSUInteger cancelCount = 0;
  for (UIAlertAction *action in alert.actions) {
    [actual addObject:action.title ?: @""];
    if (action.style == UIAlertActionStyleCancel) cancelCount++;
  }
  Check([actual isEqualToArray:titles], @"update prompt exposes the expected ordered actions");
  Check(cancelCount == 1, @"update prompt has exactly one cancel action");
}

static void CheckInstallerURL(NSURL *url, NSString *assetURL) {
  NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
  Check([components.scheme isEqualToString:@"apple-magnifier"] && [components.host isEqualToString:@"install"],
        @"install hands off to TrollStore's official URL scheme");
  Check(components.queryItems.count == 1 && [components.queryItems.firstObject.name isEqualToString:@"url"],
        @"install URL contains one encoded asset parameter");
  Check([components.queryItems.firstObject.value isEqualToString:assetURL] && components.fragment == nil,
        @"install URL round-trips the complete asset URL without query injection");
}

static void RunInstallTests(void) {
  Method factory = class_getClassMethod(UIAlertAction.class, @selector(actionWithTitle:style:handler:));
  OriginalActionFactory = (decltype(OriginalActionFactory))method_getImplementation(factory);
  method_setImplementation(factory, (IMP)CaptureActionFactory);
  UIViewController *presenter = [UIViewController new];
  NSArray *fallbackActions = @[@"Update_Release_Page", @"Btn_Cancel"];

  UpdateInstallFixture *fixture = [UpdateInstallFixture new];
  [fixture showUpdateAlertFromViewController:presenter];
  Check(fixture.prompts.count == 1, @"show update builds and presents the installation choices");
  UIAlertController *prompt = fixture.prompts.lastObject;
  CheckPromptActions(prompt, @[@"Update_Install_TrollStore", @"Update_Release_Page", @"Btn_Cancel"]);
  Check([prompt.message containsString:@"Release notes"] && [prompt.message containsString:@"Update_Install_Hint"],
        @"TrollStore prompt includes release notes and installation guidance");
  NSString *originalAsset = [fixture.tipaDownloadURL copy];
  NSString *originalRelease = [fixture.downloadURL copy];
  fixture.tipaDownloadURL = @"https://evil.example/replacement.tipa";
  fixture.downloadURL = @"https://evil.example/release";
  InvokeAction(prompt, @"Update_Install_TrollStore");
  Check(fixture.openedURLs.count == 1, @"installation requests one external handoff");
  CheckInstallerURL(fixture.openedURLs.lastObject, originalAsset);
  InvokeAction(prompt, @"Update_Release_Page");
  Check([fixture.openedURLs.lastObject.absoluteString isEqualToString:originalRelease],
        @"release action keeps the validated URL captured with the prompt");

  fixture = [UpdateInstallFixture new];
  fixture.tipaDownloadURL = nil;
  prompt = [fixture updateAlertForViewController:presenter];
  CheckPromptActions(prompt, fallbackActions);
  Check([prompt.message containsString:@"Update_Package_Unavailable"], @"missing install package explains page fallback");

  fixture = [UpdateInstallFixture new];
  fixture.fixtureInstallKind = VMUpdateInstallKindPackageManager;
  prompt = [fixture updateAlertForViewController:presenter];
  CheckPromptActions(prompt, fallbackActions);
  Check([prompt.message containsString:@"Update_Deb_Hint"], @"DEB installation directs users to their package manager");
  InvokeAction(prompt, @"Update_Release_Page");
  Check([fixture.openedURLs.lastObject.scheme isEqualToString:@"https"], @"DEB update action opens the release page");

  fixture = [UpdateInstallFixture new];
  fixture.fixtureInstallKind = VMUpdateInstallKindUnknown;
  prompt = [fixture updateAlertForViewController:presenter];
  CheckPromptActions(prompt, fallbackActions);
  Check(fixture.openedURLs.count == 0, @"unknown installation environments await a release-page action");

  for (NSString *invalidURL in @[@"https://evil.example/VansonMod_v3.10.tipa",
         @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.deb",
         @"https://github.com/vaenshine/VansonMod/releases/download/v3.9/VansonMod_v3.10.tipa",
         @"https://github.com/vaenshine/VansonMod/releases/download/v3.10/VansonMod_v3.10.tipa?url=evil"]) {
    fixture = [UpdateInstallFixture new];
    fixture.tipaDownloadURL = invalidURL;
    prompt = [fixture updateAlertForViewController:presenter];
    CheckPromptActions(prompt, fallbackActions);
    [fixture installTIPAAtURL:[NSURL URLWithString:invalidURL]
              releasePageURL:[NSURL URLWithString:fixture.downloadURL] fromViewController:presenter];
    Check(fixture.openedURLs.count == 0, @"direct install entry rejects invalid assets before opening any URL");
    Check([fixture.prompts.lastObject.message containsString:@"Update_Package_Unavailable"],
          @"direct install rejection explains the missing trusted package");
    CheckPromptActions(fixture.prompts.lastObject, fallbackActions);
  }

  fixture = [UpdateInstallFixture new];
  fixture.installerAvailable = NO;
  [fixture installTIPAAtURL:[NSURL URLWithString:fixture.tipaDownloadURL]
            releasePageURL:[NSURL URLWithString:fixture.downloadURL] fromViewController:presenter];
  Check(fixture.openedURLs.count == 0, @"unavailable TrollStore never receives an installation URL");
  Check([fixture.prompts.lastObject.message containsString:@"Update_Installer_Unavailable"],
        @"unavailable installer gives an actionable explanation");
  CheckPromptActions(fixture.prompts.lastObject, fallbackActions);
  InvokeAction(fixture.prompts.lastObject, @"Update_Release_Page");
  Check([fixture.openedURLs.lastObject.absoluteString isEqualToString:fixture.downloadURL],
        @"unavailable installer retains a working release-page action");

  fixture = [UpdateInstallFixture new];
  fixture.openingSucceeds = NO;
  [fixture installTIPAAtURL:[NSURL URLWithString:fixture.tipaDownloadURL]
            releasePageURL:[NSURL URLWithString:fixture.downloadURL] fromViewController:presenter];
  Check(fixture.openedURLs.count == 1 && fixture.prompts.count == 1,
        @"failed installation handoff presents one recovery prompt");
  Check([fixture.prompts.lastObject.message containsString:@"Update_Installer_Unavailable"],
        @"failed installation handoff explains installer recovery");
  CheckPromptActions(fixture.prompts.lastObject, fallbackActions);
  fixture.openingSucceeds = YES;
  InvokeAction(fixture.prompts.lastObject, @"Update_Release_Page");
  Check(fixture.openedURLs.count == 2 && [fixture.openedURLs.lastObject.absoluteString isEqualToString:fixture.downloadURL],
        @"failed installation handoff can recover through the release page");

  fixture = [UpdateInstallFixture new];
  fixture.openingSucceeds = NO;
  prompt = [fixture updateAlertForViewController:presenter];
  InvokeAction(prompt, @"Update_Release_Page");
  Check(fixture.prompts.count == 1 && [fixture.prompts.lastObject.message containsString:@"Update_Open_Failed"],
        @"release-page open failure is reported");
  CheckPromptActions(fixture.prompts.lastObject, @[@"Btn_OK"]);
  method_setImplementation(factory, (IMP)OriginalActionFactory);
}

static void RunTests(void) {
  UpdateFixture *fixture = [UpdateFixture new];
  Check(fixture.checkState == VMUpdateCheckStateIdle && !fixture.hasNewVersion, @"fresh manager begins Idle");
  NSMutableArray *states = [NSMutableArray array];
  __block NSUInteger badges = 0;
  id stateObserver = [NSNotificationCenter.defaultCenter addObserverForName:kVMUpdateStateDidChangeNotification object:fixture queue:nil usingBlock:^(NSNotification *note) {
    Check(NSThread.isMainThread, @"state notification runs on main thread");
    [states addObject:@(fixture.checkState)];
  }];
  id badgeObserver = [NSNotificationCenter.defaultCenter addObserverForName:kVMUpdateAvailableNotification object:fixture queue:nil usingBlock:^(NSNotification *note) { badges++; }];
  ExpectState(fixture, VMUpdateCheckStateCurrent);
  Check([states isEqualToArray:@[@(VMUpdateCheckStateChecking), @(VMUpdateCheckStateCurrent)]], @"observers receive Checking then Current");
  Check(badges == 1, @"legacy badge notification also fires for Current");
  [NSNotificationCenter.defaultCenter removeObserver:stateObserver];
  [NSNotificationCenter.defaultCenter removeObserver:badgeObserver];

  fixture.fake.body = [@"{\"tag_name\":\"v3.10\",\"body\":\"Changes\",\"html_url\":\"https://github.com/vaenshine/VansonMod/releases/tag/v3.10\"}" dataUsingEncoding:NSUTF8StringEncoding];
  ExpectState(fixture, VMUpdateCheckStateAvailable);
  Check(fixture.hasNewVersion && [fixture.latestVersionStr isEqualToString:@"3.10"], @"numeric version comparison recognizes 3.10 as newer than 3.5");
  Check([fixture.releaseNotes isEqualToString:@"Changes"] && [fixture.downloadURL hasSuffix:@"v3.10"], @"available release keeps its content and page");
  fixture.fake.body = [@"{\"tag_name\":\"v3.4\"}" dataUsingEncoding:NSUTF8StringEncoding];
  ExpectState(fixture, VMUpdateCheckStateCurrent);
  Check(!fixture.hasNewVersion && !fixture.latestVersionStr && !fixture.releaseNotes && !fixture.downloadURL, @"Current clears stale available-release metadata");

  NSArray *malformed = @[@"{", @"[]", @"null", @"{}", @"{\"message\":\"API rate limit exceeded\"}", @"{\"tag_name\":null}", @"{\"tag_name\":35}", @"{\"tag_name\":[]}", @"{\"tag_name\":\"\"}", @"{\"tag_name\":\"v\"}", @"{\"tag_name\":\"release\"}"];
  for (NSString *body in malformed) {
    fixture = [UpdateFixture new];
    fixture.fake.body = [body dataUsingEncoding:NSUTF8StringEncoding];
    ExpectState(fixture, VMUpdateCheckStateFailed);
    Check(!fixture.hasNewVersion, @"malformed responses never claim a release is available");
  }
  for (NSNumber *code in @[@403, @404, @500]) {
    fixture = [UpdateFixture new]; fixture.fake.status = code.integerValue;
    ExpectState(fixture, VMUpdateCheckStateFailed);
  }
  fixture = [UpdateFixture new];
  fixture.fake.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
  ExpectState(fixture, VMUpdateCheckStateFailed);
  fixture.fake.error = nil;
  ExpectState(fixture, VMUpdateCheckStateCurrent);

  fixture = [UpdateFixture new];
  fixture.fake.body = [@"{\"tag_name\":\"v3.6\",\"body\":[],\"html_url\":null}" dataUsingEncoding:NSUTF8StringEncoding];
  ExpectState(fixture, VMUpdateCheckStateAvailable);
  Check(!fixture.releaseNotes && [fixture.downloadURL isEqualToString:@"https://github.com/vaenshine/VansonMod/releases/latest"], @"optional malformed release fields get a safe fallback");

  fixture = [UpdateFixture new];
  __block NSUInteger callbacks = 0;
  [fixture checkForUpdateManual:NO completion:^{
    Check(fixture.checkState == VMUpdateCheckStateCurrent, @"automatic completion sees coalesced final state"); callbacks++;
  }];
  [fixture checkForUpdateManual:YES completion:^{
    Check(fixture.checkState == VMUpdateCheckStateCurrent, @"manual completion sees coalesced final state"); callbacks++;
  }];
  Check(fixture.fake.requests == 1, @"automatic and manual requests share one network task");
  WaitUntil(^BOOL { return callbacks == 2; });
  Check(fixture.alerts == 1, @"manual join produces one result alert");

  fixture = [UpdateFixture new];
  __block BOOL backgroundFinished = NO;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [fixture checkForUpdateManual:NO completion:^{
      Check(NSThread.isMainThread && fixture.checkState == VMUpdateCheckStateCurrent, @"background caller receives final completion on main thread");
      backgroundFinished = YES;
    }];
  });
  WaitUntil(^BOOL { return backgroundFinished; });
  RunAssetTests();
  RunInstallTests();
  printf("PASS: %lu update manager checks\n", (unsigned long)checks);
  fflush(stdout);
  exit(0);
}

@interface UpdateCheckApp : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation UpdateCheckApp
- (void)runTests {
  RunTests();
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = [UIViewController new];
  [self.window makeKeyAndVisible];
  // Run outside a main-dispatch block so WaitUntil can service the main queue
  // through its nested run loop while asynchronous responses finish.
  [self performSelector:@selector(runTests) withObject:nil afterDelay:.1];
  return YES;
}
@end

int main(int argc, char **argv) {
  @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(UpdateCheckApp.class)); }
}
