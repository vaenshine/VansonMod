// Local simulator review: real controllers and models, isolated fixture process list.
// Captures layouts; device-only attach/write/watchpoint workflows require hardware checks.
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "src/core/VMDebugEngine.h"
#import "src/ui/pointer/VMPointerVerifierViewController.h"
#import "include/VMDataSession.h"
#import "src/ui/pointer/VMPointerLockCell.h"
#import "src/ui/pointer/VMSignatureLockCell.h"
#import "src/ui/patch/VMRVAManagerCell.h"
#import "include/VMRVAPatch.h"
#import "src/core/VMRootViewController.h"
#import "src/utils/helpers/VMUIHelper.h"
#import "src/utils/managers/VMUpdateManager.h"
#import "src/ui/main/VMAppSelectViewController.h"
#import "src/ui/main/VMSettingsViewController.h"
#import "src/ui/main/VMModifierViewController.h"
#import "src/ui/main/VMLockListViewController.h"
#import "src/ui/patch/VMPatcherViewController.h"
#import "src/ui/common/VMFormSheetViewController.h"
#import "src/ui/main/VMScriptViewController.h"
#import "src/ui/main/VMScriptToolsViewController.h"
#import "src/ui/pointer/VMPointerSearchViewController.h"
#import "src/ui/pointer/VMPointerSessionListViewController.h"
#import "src/ui/pointer/VMItemEditViewController.h"
#import "src/ui/patch/VMBackupListViewController.h"
#import "src/ui/memory/VMMemoryBrowserViewController.h"
#import "src/ui/memory/VMHexEditorViewController.h"
#import "src/ui/memory/VMHexRowEditorViewController.h"
#import "src/ui/memory/VMStringEditorViewController.h"
#import "src/ui/memory/VMSignatureSearchViewController.h"
#import "src/ui/memory/VMModuleListViewController.h"
#import "src/ui/memory/VMWatchpointViewController.h"
#import "src/ui/memory/VMProcessAuditViewController.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerChain.h"

static void Check(BOOL valid, NSString *message) {
  printf("%s %s\n", valid ? "PASS" : "FAIL", message.UTF8String); fflush(stdout);
  if (!valid) exit(1);
}
static void Later(double seconds, dispatch_block_t block) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * NSEC_PER_SEC), dispatch_get_main_queue(), block);
}
static NSArray<UIView *> *ViewsOfClass(UIView *view, Class type) {
  NSMutableArray *matches = [NSMutableArray array];
  if ([view isKindOfClass:type]) [matches addObject:view];
  for (UIView *child in view.subviews) [matches addObjectsFromArray:ViewsOfClass(child, type)];
  return matches;
}
static BOOL ContainsLabel(UIView *view, NSString *text) {
  for (UILabel *label in ViewsOfClass(view, UILabel.class)) {
    if (!label.hidden && [label.text containsString:text]) return YES;
  }
  return NO;
}
static NSUInteger reviewCaptureCount = 0;
static void CaptureReviewWindow(UIWindow *window, NSDictionary *entry) {
  NSString *folder = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"UIReview"];
  [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:window.bounds.size];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
    [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
  }];
  NSString *name = entry[@"captureName"] ?: entry[@"name"];
  NSString *path = [folder stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]];
  Check([UIImagePNGRepresentation(image) writeToFile:path atomically:YES], [@"captured " stringByAppendingString:name]);
  reviewCaptureCount++;
}

@interface VMUpdateManager (ReviewAccess)
- (BOOL)canOpenTrollStoreInstaller;
- (void)openExternalURL:(NSURL *)url completion:(void (^)(BOOL))completion;
@end

// Automated update scenarios replace only installation environment and external
// handoff. The production alert builder and UIKit presentation stay active.
@interface VMUpdateReviewFixture : VMUpdateManager
@property(nonatomic) VMUpdateInstallKind fixtureKind;
@property(nonatomic) BOOL installerAvailable;
@property(nonatomic) BOOL handoffSucceeds;
@property(nonatomic, strong) NSMutableArray<NSURL *> *openedURLs;
@end
@implementation VMUpdateReviewFixture
- (instancetype)init {
  if ((self = [super init])) {
    self.fixtureKind = VMUpdateInstallKindTrollStore;
    self.installerAvailable = YES;
    self.handoffSucceeds = YES;
    self.openedURLs = [NSMutableArray array];
    self.checkState = VMUpdateCheckStateAvailable;
    self.hasNewVersion = YES;
    self.latestVersionStr = @"3.6";
    self.releaseNotes = @"优化界面体验，修复搜索显示问题。";
    self.downloadURL = @"https://github.com/vaenshine/VansonMod/releases/tag/v3.6";
    self.tipaDownloadURL = @"https://github.com/vaenshine/VansonMod/releases/download/v3.6/VansonMod_v3.6.tipa";
  }
  return self;
}
- (VMUpdateInstallKind)installationKind { return self.fixtureKind; }
- (BOOL)canOpenTrollStoreInstaller { return self.installerAvailable; }
- (void)checkForUpdateManual:(BOOL)manual completion:(void (^)(void))completion {
  Check(NO, @"available update fixture must open its prompt without a network request");
}
- (void)openExternalURL:(NSURL *)url completion:(void (^)(BOOL))completion {
  [self.openedURLs addObject:url];
  if (completion) Later(.03, ^{ completion(self.handoffSucceeds); });
}
@end

static const void *UpdateReviewActionHandlerKey = &UpdateReviewActionHandlerKey;
static UIAlertAction *(*UpdateReviewOriginalActionFactory)(id, SEL, NSString *, UIAlertActionStyle, void (^)(UIAlertAction *));
static UIAlertAction *UpdateReviewCaptureActionFactory(id cls, SEL sel, NSString *title,
    UIAlertActionStyle style, void (^handler)(UIAlertAction *)) {
  UIAlertAction *action = UpdateReviewOriginalActionFactory(cls, sel, title, style, handler);
  if (handler) objc_setAssociatedObject(action, UpdateReviewActionHandlerKey, handler, OBJC_ASSOCIATION_COPY_NONATOMIC);
  return action;
}

@interface VMCardReviewController : UITableViewController
@property(nonatomic, copy) NSString *variant;
@property(nonatomic) BOOL importedFixture;
@end
@implementation VMCardReviewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"示例卡片";
  [VMUIHelper styleTableView:self.tableView];
  self.tableView.rowHeight = UITableViewAutomaticDimension;
  self.tableView.estimatedRowHeight = 260;
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 1; }
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path {
  if ([self.variant isEqual:@"signature"]) {
    VMSignatureLockCell *cell = [[VMSignatureLockCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    VMSignatureModel *sig = [VMSignatureModel new];
    sig.isImported = self.importedFixture;
    sig.note = @"示例特征码 · 参数调节"; sig.author = @"VansonMod"; sig.moduleName = @"Demo.framework";
    sig.signature = @"1F 20 03 D5 ?? ?? ?? ??"; sig.lockType = VMDataTypeInt32;
    sig.runtimeResults = @[@{@"addr":@0x100100000, @"val":@"100"}];
    sig.resultConfig = [@{@0x100100000:@{@"type":@"slider", @"min":@0, @"max":@200}} mutableCopy];
    [cell configureWithSignature:sig]; return cell;
  }
  if ([self.variant isEqual:@"patch"]) {
    VMRVAManagerCell *cell = [[VMRVAManagerCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    VMRVAPatch *patch = [VMRVAPatch new];
    patch.isImported = self.importedFixture;
    patch.note = @"示例补丁"; patch.author = @"VansonMod"; patch.moduleName = @"Demo.framework";
    patch.appName = @"Vanson Demo"; patch.appVersion = @"1.0"; patch.offset = 0x108;
    patch.originalHex = @"C0 03 5F D6"; patch.patchHex = @"1F 20 03 D5";
    [cell configureWithPatch:patch]; return cell;
  }
  VMPointerLockCell *cell = [[VMPointerLockCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
  VMPointerChain *chain = [VMPointerChain new];
  chain.isImported = self.importedFixture;
  chain.note = @"示例指针 · 长名称检查"; chain.author = @"VansonMod"; chain.moduleName = @"Demo.framework";
  chain.baseOffset = 0x100; chain.offsets = @[@0x20,@0x8]; chain.lockType = VMDataTypeInt32;
  chain.uiMode = VMPointerUIModeSlider; chain.uiMin = 0; chain.uiMax = 200;
  [cell configureWithChain:chain address:@"0x100100000" val:@"100" type:@"I32"]; return cell;
}
@end

@interface VMSettingsViewController (ReviewAccess)
- (void)textFieldDidEndEditing:(UITextField *)field;
- (void)selectSettingsGroup:(NSInteger)group;
@end

static void CheckSettingsGroup(VMSettingsViewController *settings, NSInteger group) {
  [settings.view layoutIfNeeded];
  UITableView *table = [settings valueForKey:@"tableView"];
  [table layoutIfNeeded];
  Check([[settings valueForKey:@"selectedSettingsGroup"] integerValue] == group,
      @"settings retain the selected group");
  Check(table.numberOfSections == 3, @"settings keep stable section identities");
  for (NSInteger section = 0; section < 3; section++)
    Check([table numberOfRowsInSection:section] == (section == group ? (section == 2 ? 5 : 6) : 0),
        @"only the selected settings group supplies rows");
  for (NSIndexPath *path in table.indexPathsForVisibleRows)
    Check(path.section == group, @"visible settings rows belong to the selected group");
  UISegmentedControl *tabs = [settings valueForKey:@"groupTabs"];
  NSArray *keys = @[@"Set_Search_Section", @"Set_Sec_Func", @"Set_Sec_About"];
  Check(tabs.numberOfSegments == 3 && tabs.selectedSegmentIndex == group,
      @"settings category tabs reflect the active group");
  for (NSInteger index = 0; index < 3; index++)
    Check([[tabs titleForSegmentAtIndex:index] isEqualToString:[[VMLocalization shared] localizedString:keys[index]]],
        @"settings category title is localized");
  UIScrollView *tabScroll = [settings valueForKey:@"groupTabScroll"];
  CGRect tabsFrame = [tabScroll convertRect:tabScroll.bounds toView:settings.view];
  CGRect tableFrame = [table convertRect:table.bounds toView:settings.view];
  Check(!tabScroll.hidden && !tabScroll.showsHorizontalScrollIndicator &&
      CGRectGetHeight(tabsFrame) >= 44 && CGRectGetMaxY(tabsFrame) <= CGRectGetMinY(tableFrame) + 1,
      @"settings categories remain pinned above the scrolling group");
  UIButton *disclaimer = [settings valueForKey:@"disclaimerButton"];
  UILabel *legal = [settings valueForKey:@"legalFooterLabel"];
  Check(disclaimer.enabled && !disclaimer.hidden && [disclaimer isDescendantOfView:table.tableFooterView] &&
      [disclaimer actionsForTarget:settings forControlEvent:UIControlEventTouchUpInside].count > 0,
      @"every settings group retains an actionable footer disclaimer entry");
  Check(legal.text.length > 0 && [legal isDescendantOfView:table.tableFooterView],
      @"every settings group retains the shared legal footer");
  CGSize legalSize = [legal sizeThatFits:CGSizeMake(legal.bounds.size.width, CGFLOAT_MAX)];
  Check(legal.bounds.size.width > 0 && legal.bounds.size.height >= legalSize.height - 1,
      @"settings legal footer fits its full text at the current width and text size");
  Check(legal.textAlignment == NSTextAlignmentCenter, @"copyright is centered in its row");
  UIButton *versionButton = [settings valueForKey:@"versionButton"];
  Check([versionButton isDescendantOfView:table.tableFooterView] &&
      [[versionButton actionsForTarget:settings forControlEvent:UIControlEventTouchUpInside] containsObject:@"checkForUpdate"],
      @"every group exposes update checking through the shared version row");
  VMUpdateCheckState updateState = VMUpdateManager.shared.checkState;
  Check(versionButton.enabled == (updateState != VMUpdateCheckStateChecking), @"version action follows shared checking state");
  NSArray *stateKeys = @[@"Set_Check_Update", @"Update_Checking", @"Status_Latest", @"Status_New", @"Update_Check_Failed"];
  UILabel *versionValue = [settings valueForKey:@"versionValueLabel"];
  Check([versionValue.text containsString:[[VMLocalization shared] localizedString:stateKeys[updateState]]],
      @"version row shows the actual localized update state");
  Check([versionButton.accessibilityValue isEqualToString:versionValue.text], @"version state is available to VoiceOver");
  UIView *section = [settings valueForKey:@"legalInfoSection"];
  UILabel *version = [settings valueForKey:@"versionValueLabel"];
  Check([version isDescendantOfView:section] && [legal isDescendantOfView:section] &&
      [disclaimer isDescendantOfView:section], @"version, disclaimer and legal information share one section");
  CGRect versionFrame = [version convertRect:version.bounds toView:section];
  CGRect disclaimerFrame = [disclaimer convertRect:disclaimer.bounds toView:section];
  Check(CGRectGetMaxY(versionFrame) < CGRectGetMinY(disclaimerFrame), @"settings version appears before the disclaimer");
  NSArray *infoRows = [settings valueForKey:@"legalInfoRows"];
  UIFont *titleFont = [(UILabel *)[infoRows.firstObject valueForKey:@"titleLabel"] font];
  UIFont *valueFont = [(UILabel *)[infoRows.firstObject valueForKey:@"valueLabel"] font];
  Check(titleFont.pointSize >= 17 && valueFont.pointSize >= 15, @"information titles and values use readable type sizes");
  for (UIView *row in infoRows) {
    Check([[(UILabel *)[row valueForKey:@"titleLabel"] font] isEqual:titleFont] &&
        [[(UILabel *)[row valueForKey:@"valueLabel"] font] isEqual:valueFont] && row.bounds.size.height >= 44,
        @"all information rows share typography and minimum height");
    for (UILabel *label in ViewsOfClass(row, UILabel.class)) {
      CGSize size = [label sizeThatFits:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX)];
      Check(label.bounds.size.width > 0 && label.bounds.size.height >= size.height - 1,
          @"settings information rows fit their complete text");
    }
  }
}
@interface VMAppSelectViewController (ReviewAccess)
- (void)updateSegmentTitles;
- (VMPointerChain *)parsePointerChainFromString:(NSString *)input;
- (void)showAddPointerAlertForBundleID:(NSString *)bundleID appName:(NSString *)appName;
@end
@interface VMLockListViewController (ReviewAccess)
- (void)addLock;
- (void)addNewScript;
- (void)updateFooter;
@end
@interface VMPatcherViewController (ReviewAccess)
- (void)savePatchAction;
@end
@interface VMFormSheetViewController (ReviewAccess)
- (void)submit;
@end
@interface VMScriptViewController (ReviewAccess)
- (void)editNoteAction;
- (BOOL)hasUnsavedChanges;
- (BOOL)saveScriptModelToDisk;
- (BOOL)writeScriptModelToDisk:(VMScriptModel *)model;
- (void)textViewDidChange:(UITextView *)view;
- (void)updateHeaderInfo;
- (void)clearEditorContents;
- (void)undoEditor;
@end
@interface VMHexRowEditorViewController (ReviewAccess)
- (BOOL)hasUnsavedChanges;
- (void)textViewDidChange:(UITextView *)view;
@end
@interface VMModifierViewController (ReviewAccess)
- (NSArray<VMScanResultItem *> *)batchModificationItems;
- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)modeChanged;
- (void)dataTypeChanged;
- (void)showTimelineSheet;
- (void)handleSearch;
- (void)handleReset;
- (void)refreshProcessHeader;
- (void)toggleFilterPanel;
- (void)applyFilter;
- (void)fuzzyTypeChanged;
- (void)executeFuzzyRepeatWithFilterMode:(VMFilterMode)mode total:(NSInteger)total;
- (void)updateButtonStates;
@end
@interface VMItemEditViewController (ReviewAccess)
- (void)onModeChange:(UISegmentedControl *)sender;
- (void)onSaveBtn;
- (void)onCancel;
@end
@interface VMWatchpointViewController (ReviewAccess)
- (void)showInspectorForHit:(VMWatchHit *)hit;
@end
static uint8_t reviewMemory[16384] __attribute__((aligned(4096)));
// Keep real controller callbacks and UI transitions while isolating all memory work.
@interface VMZeroSearchFixture : NSObject
@property(nonatomic) NSUInteger nextCount;
@property(nonatomic) NSUInteger initCount;
@property(nonatomic) BOOL initSuccess;
@property(nonatomic) NSUInteger initCalls;
@property(nonatomic) NSUInteger scanCalls;
@property(nonatomic) NSUInteger fuzzyCalls;
@property(nonatomic) NSUInteger filterCalls;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *implementations;
- (void)restore;
@end
@implementation VMZeroSearchFixture
- (void)replace:(SEL)selector block:(id)block {
  Method method = class_getInstanceMethod(VMMemoryEngine.class, selector);
  IMP replacement = imp_implementationWithBlock(block);
  [self.implementations addObject:@{@"selector":NSStringFromSelector(selector),
    @"original":[NSValue valueWithPointer:(const void *)method_getImplementation(method)],
    @"replacement":[NSValue valueWithPointer:(const void *)replacement]}];
  method_setImplementation(method, replacement);
}
- (instancetype)init {
  if ((self = [super init])) {
    self.implementations = [NSMutableArray array];
    self.initSuccess = YES;
    self.initCount = 4096;
    __weak VMZeroSearchFixture *weakSelf = self;
    [self replace:@selector(fastFuzzyInitWithCompletion:) block:^(VMMemoryEngine *engine, void (^completion)(BOOL, NSString *, NSUInteger)) {
      VMZeroSearchFixture *fixture = weakSelf;
      fixture.initCalls++;
      completion(fixture.initSuccess, fixture.initSuccess ? @"" : @"快照初始化失败，请重试", fixture.initCount);
    }];
    [self replace:@selector(fastFuzzyFilterWithMode:dataType:completion:) block:^(VMMemoryEngine *engine, VMFilterMode mode, VMDataType type, void (^completion)(NSUInteger, NSString *)) {
      VMZeroSearchFixture *fixture = weakSelf;
      fixture.fuzzyCalls++;
      engine.resultCount = fixture.nextCount;
      completion(fixture.nextCount, @"");
    }];
    [self replace:@selector(scanMemoryWithMode:valStr:dataType:fuzzyType:isNextSearch:completion:) block:^(VMMemoryEngine *engine, VMSearchMode mode, NSString *value, VMDataType type, VMFuzzyType fuzzy, BOOL next, void (^completion)(NSUInteger, NSString *)) {
      VMZeroSearchFixture *fixture = weakSelf;
      fixture.scanCalls++;
      engine.resultCount = fixture.nextCount;
      completion(fixture.nextCount, @"");
    }];
    [self replace:@selector(filterResultsWithMode:val1:val2:type:completion:) block:^(VMMemoryEngine *engine, VMFilterMode mode, NSString *value1, NSString *value2, VMDataType type, void (^completion)(NSUInteger, NSString *)) {
      VMZeroSearchFixture *fixture = weakSelf;
      fixture.filterCalls++;
      engine.resultCount = fixture.nextCount;
      completion(fixture.nextCount, @"");
    }];
    [self replace:@selector(getResultItemAtIndex:dataType:) block:^VMScanResultItem *(VMMemoryEngine *engine, NSUInteger index, VMDataType type) {
      VMScanResultItem *item = [VMScanResultItem new];
      item.address = (uint64_t)(reviewMemory + 256);
      item.type = type;
      item.valueStr = @"100";
      return item;
    }];
    [self replace:@selector(captureMemoryTimelineWithTitle:detail:dataType:) block:^(VMMemoryEngine *engine, NSString *title, NSString *detail, VMDataType type) {}];
  }
  return self;
}
- (void)restore {
  for (NSDictionary *entry in self.implementations) {
    method_setImplementation(class_getInstanceMethod(VMMemoryEngine.class, NSSelectorFromString(entry[@"selector"])),
      (IMP)[entry[@"original"] pointerValue]);
    imp_removeBlock((IMP)[entry[@"replacement"] pointerValue]);
  }
  [self.implementations removeAllObjects];
}
@end

// The scan transport is a deterministic callback fixture. Controllers, input
// events, result rendering and timeline capture/restore use production code.
// Reads are limited to reviewMemory, and value restoration is disabled.
@interface VMStringOptionsFixture : NSObject
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *implementations;
@property(nonatomic, copy) void (^pendingCompletion)(NSUInteger, NSString *);
@property(nonatomic) NSUInteger scanCalls;
@property(nonatomic) VMStringEncoding observedEncoding;
@property(nonatomic) BOOL observedCaseSensitive;
@property(nonatomic) BOOL observedNext;
- (void)completeScan;
- (void)restore;
@end
@implementation VMStringOptionsFixture
- (void)replace:(SEL)selector block:(id)block {
  Method method = class_getInstanceMethod(VMMemoryEngine.class, selector);
  IMP replacement = imp_implementationWithBlock(block);
  [self.implementations addObject:@{@"selector":NSStringFromSelector(selector),
    @"original":[NSValue valueWithPointer:(const void *)method_getImplementation(method)],
    @"replacement":[NSValue valueWithPointer:(const void *)replacement]}];
  method_setImplementation(method, replacement);
}
- (instancetype)init {
  if ((self = [super init])) {
    self.implementations = [NSMutableArray array];
    __weak VMStringOptionsFixture *weakSelf = self;
    [self replace:@selector(scanMemoryWithMode:valStr:dataType:fuzzyType:isNextSearch:completion:)
        block:^(VMMemoryEngine *engine, VMSearchMode mode, NSString *value, VMDataType type,
                VMFuzzyType fuzzy, BOOL next, void (^completion)(NSUInteger, NSString *)) {
      VMStringOptionsFixture *fixture = weakSelf;
      Check(mode == VMSearchModeExact && type == VMDataTypeString,
          @"Str UI fixture receives only exact string searches");
      Check(engine.targetPid == getpid(), @"Str UI fixture keeps the isolated self-process target");
      fixture.scanCalls++;
      fixture.observedEncoding = engine.stringEncoding;
      fixture.observedCaseSensitive = engine.stringCaseSensitive;
      fixture.observedNext = next;
      fixture.pendingCompletion = completion;
    }];
    [self replace:@selector(getResultItemAtIndex:dataType:)
        block:^VMScanResultItem *(VMMemoryEngine *engine, NSUInteger index, VMDataType type) {
      VMScanResultItem *item = [VMScanResultItem new];
      item.address = (uint64_t)(reviewMemory + 8192);
      item.type = VMDataTypeString;
      item.stringEncoding = engine.stringEncoding;
      item.originalSize = [@"Straße 世界 😀" lengthOfBytesUsingEncoding:VMFoundationStringEncoding(item.stringEncoding)];
      return item;
    }];
    [self replace:@selector(canRestoreMemoryTimelineValuesAtIndex:)
        block:^BOOL(VMMemoryEngine *engine, NSUInteger index) { return NO; }];
  }
  return self;
}
- (void)completeScan {
  VMMemoryEngine *engine = VMMemoryEngine.shared;
  NSData *text = [@"Straße 世界 😀" dataUsingEncoding:VMFoundationStringEncoding(engine.stringEncoding)];
  memset(reviewMemory + 8192, 0, 512);
  memcpy(reviewMemory + 8192, text.bytes, text.length);
  // Match the production on-disk 24-byte RawResult layout for real timeline I/O.
  uint8_t result[24] = {};
  uint64_t address = (uint64_t)(reviewMemory + 8192), length = text.length;
  memcpy(result, &address, sizeof(address));
  memcpy(result + 8, &length, sizeof(length));
  result[16] = VMDataTypeString;
  NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
      [NSString stringWithFormat:@"string-ui-fixture-%@.bin", NSUUID.UUID.UUIDString]];
  Check([[NSData dataWithBytes:result length:sizeof(result)] writeToFile:path atomically:YES],
      @"Str UI fixture writes one bounded result for production timeline capture");
  engine.resultFilePath = path;
  engine.currentDataType = VMDataTypeString;
  engine.resultCount = 1;
  void (^completion)(NSUInteger, NSString *) = self.pendingCompletion;
  self.pendingCompletion = nil;
  Check(completion != nil, @"Str UI fixture completes an outstanding search callback");
  completion(1, @"");
}
- (void)restore {
  for (NSDictionary *entry in self.implementations) {
    method_setImplementation(class_getInstanceMethod(VMMemoryEngine.class, NSSelectorFromString(entry[@"selector"])),
        (IMP)[entry[@"original"] pointerValue]);
    imp_removeBlock((IMP)[entry[@"replacement"] pointerValue]);
  }
  [self.implementations removeAllObjects];
}
@end

static void CheckSearchHeaderFit(VMModifierViewController *modifier, NSString *stage) {
  UITableView *table = [modifier valueForKey:@"tableView"];
  UIView *header = table.tableHeaderView;
  // Measuring does not resize the table header or call controller layout methods.
  CGFloat natural = [header systemLayoutSizeFittingSize:CGSizeMake(table.bounds.size.width, UILayoutFittingCompressedSize.height)
      withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
  Check(fabs(header.bounds.size.height - ceil(natural)) <= 1,
      [NSString stringWithFormat:@"%@: callback resizes table header (actual %.1f, fitting %.1f)", stage, header.bounds.size.height, natural]);
}

static UIScrollView *EnclosingScrollView(UIView *view) {
  for (UIView *parent = view.superview; parent; parent = parent.superview)
    if ([parent isKindOfClass:UIScrollView.class]) return (UIScrollView *)parent;
  return nil;
}

// These checks exercise the real layout and cancellation policy. Programmatic
// scrolling and control actions do not synthesize a finger drag; that has a
// separate interactive check in the simulator/device review.
static void CheckMemoryControlStrips(VMModifierViewController *modifier, BOOL compact) {
  [modifier.view layoutIfNeeded];
  UISegmentedControl *types = [modifier valueForKey:@"dataTypeSegment"];
  UIStackView *headerActions = [modifier valueForKey:@"toolRowInHeader"];
  UIVisualEffectView *floating = [modifier valueForKey:@"floatingToolBar"];
  UIStackView *batchActions = [modifier valueForKey:@"batchStackView"];
  UIScrollView *typeStrip = EnclosingScrollView(types);
  UIScrollView *headerStrip = EnclosingScrollView(headerActions);
  UIScrollView *floatingStrip = (UIScrollView *)ViewsOfClass(floating.contentView, UIScrollView.class).firstObject;
  UIScrollView *batchStrip = EnclosingScrollView(batchActions);
  Check(typeStrip && headerStrip && floatingStrip && batchStrip,
      @"memory types, header actions, floating actions and batch actions have scroll containers");
  NSArray<UIScrollView *> *strips = @[typeStrip, headerStrip, floatingStrip, batchStrip];
  Check([NSSet setWithArray:strips].count == 4, @"all four independent memory control strips are covered");
  UIScrollView *standard = [UIScrollView new];
  NSArray<UIView *> *editingControls = @[[UITextField new], [UITextView new], [UISlider new], [UISwitch new]];
  for (NSUInteger index = 0; index < strips.count; index++) {
    UIScrollView *strip = strips[index];
    [strip layoutIfNeeded];
    UITableView *table = [modifier valueForKey:@"tableView"];
    printf("CONTROL_STRIP index=%lu bounds=%.1fx%.1f content=%.1fx%.1f parent=%.1fx%.1f table=%.1fx%.1f offset=%.1f\n",
        (unsigned long)index, strip.bounds.size.width, strip.bounds.size.height,
        strip.contentSize.width, strip.contentSize.height,
        strip.superview.bounds.size.width, strip.superview.bounds.size.height,
        table.bounds.size.width, table.bounds.size.height, strip.contentOffset.x);
    fflush(stdout);
    Check(strip.bounds.size.width <= strip.superview.bounds.size.width + 1 &&
        strip.bounds.size.width <= modifier.view.bounds.size.width + 1,
        @"scroll viewport fits its parent and screen instead of being clipped as oversized content");
    Check(strip.scrollEnabled && strip.canCancelContentTouches && strip.panGestureRecognizer.enabled,
        [NSString stringWithFormat:@"strip %lu permits scrolling and cancellation after control tracking", (unsigned long)index]);
    Check(strip.bounds.size.width > 0 && strip.bounds.size.height >= 44 &&
        strip.contentSize.width >= strip.bounds.size.width - 1,
        @"control strip has a usable viewport and measured content width");
    NSArray<UIControl *> *controls = index == 0 ? @[types] : ViewsOfClass(strip, UIButton.class);
    Check(controls.count > 0, @"control strip contains its real type/action controls");
    for (UIControl *control in controls)
      Check([strip touchesShouldCancelInContentView:control],
          @"horizontal drag may cancel tracking of each type/action control");
    for (UIControl *control in controls) {
      NSArray<UIView *> *subviews = ViewsOfClass(control, UIView.class);
      NSUInteger nestedControls = 0;
      for (UIView *subview in subviews) {
        if (subview == control) continue;
        if ([subview isKindOfClass:UIControl.class]) nestedControls++;
        Check([strip touchesShouldCancelInContentView:subview],
            @"real type/action subviews yield tracking through their enclosing control");
      }
      printf("CONTROL_TRACKING strip=%lu control=%s descendants=%lu nestedControls=%lu\n",
          (unsigned long)index, NSStringFromClass(control.class).UTF8String,
          (unsigned long)(subviews.count - 1), (unsigned long)nestedControls);
      fflush(stdout);
    }
    for (UIView *editingControl in editingControls)
      Check([strip touchesShouldCancelInContentView:editingControl] ==
          [standard touchesShouldCancelInContentView:editingControl],
          @"text entry and continuous-value controls keep the standard tracking policy");
    if (index > 0) {
      UIControl *last = controls.lastObject;
      CGRect destination = [last convertRect:last.bounds toView:strip];
      [strip scrollRectToVisible:destination animated:NO];
      CGRect revealed = [last convertRect:last.bounds toView:strip];
      Check(CGRectContainsRect(CGRectInset(strip.bounds, -1, -1), revealed),
          @"last toolbar action fits fully inside its scrolled viewport");
      [strip setContentOffset:CGPointZero animated:NO];
    }
  }
  // A bounded hierarchy covers SDKs that implement a segment with a nested
  // UIControl. It leaves the actual UISegmentedControl's private views intact.
  UISegmentedControl *nestedFixture = [[UISegmentedControl alloc] initWithItems:@[@"Fixture"]];
  UIControl *nestedControl = [UIControl new];
  UIView *nestedContent = [UIView new];
  [nestedFixture addSubview:nestedControl];
  [nestedControl addSubview:nestedContent];
  Check([typeStrip touchesShouldCancelInContentView:nestedControl] &&
      [typeStrip touchesShouldCancelInContentView:nestedContent],
      @"a nested UIControl inside a segment yields tracking to horizontal scrolling");
  NSMutableArray<NSString *> *typeTitles = [NSMutableArray array];
  for (NSInteger index = 0; index < types.numberOfSegments; index++)
    [typeTitles addObject:[types titleForSegmentAtIndex:index] ?: @""];
  UISegmentedControl *standardTypes = [[UISegmentedControl alloc] initWithItems:typeTitles];
  standardTypes.frame = types.frame;
  UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
  UITableView *table = [modifier valueForKey:@"tableView"];
  NSInteger originalSelection = types.selectedSegmentIndex;
  BOOL originalHighlight = types.highlighted;
  // Highlighted/selected state is set explicitly. A real tracking interaction
  // still requires the separate physical/simulator drag check.
  for (NSNumber *selection in @[@(VMDataTypeInt32), @(VMDataTypeString)]) {
    for (NSNumber *highlighted in @[@NO, @YES]) {
      types.selectedSegmentIndex = standardTypes.selectedSegmentIndex = selection.integerValue;
      types.highlighted = standardTypes.highlighted = highlighted.boolValue;
      Check([types gestureRecognizerShouldBegin:typeStrip.panGestureRecognizer],
          @"selected and highlighted type controls permit their enclosing strip to begin panning");
      Check([types gestureRecognizerShouldBegin:tap] == [standardTypes gestureRecognizerShouldBegin:tap] &&
          [types gestureRecognizerShouldBegin:table.panGestureRecognizer] ==
          [standardTypes gestureRecognizerShouldBegin:table.panGestureRecognizer],
          @"tap and outer-table gestures retain UIKit's ordinary segmented-control policy");
      Check(types.selectedSegmentIndex == selection.integerValue,
          @"checking scroll gesture admission preserves the chosen data type");
    }
  }
  types.selectedSegmentIndex = originalSelection;
  types.highlighted = originalHighlight;
  NSInteger strIndex = NSNotFound;
  for (NSInteger index = 0; index < types.numberOfSegments; index++)
    if ([[types titleForSegmentAtIndex:index] isEqualToString:@"Str"]) strIndex = index;
  Check(strIndex != NSNotFound, @"memory type control retains the Str search entry");
  [typeStrip setContentOffset:CGPointZero animated:NO];
  CGFloat segmentWidth = types.bounds.size.width / types.numberOfSegments;
  CGRect strSegment = CGRectMake(segmentWidth * strIndex, 0, segmentWidth, types.bounds.size.height);
  CGRect destination = [types convertRect:strSegment toView:typeStrip];
  if (compact)
    Check(CGRectGetMaxX(destination) > CGRectGetMaxX(typeStrip.bounds),
        @"compact fixture exercises a Str entry initially beyond the right edge");
  [typeStrip scrollRectToVisible:destination animated:NO];
  Check(CGRectContainsRect(CGRectInset(typeStrip.bounds, -1, -1), [types convertRect:strSegment toView:typeStrip]),
      @"scroll content reaches the complete Str segment at the end of the type bar");
  if (compact) Check(typeStrip.contentOffset.x > 0, @"compact type strip actually changes its content offset");

  UISegmentedControl *modes = [modifier valueForKey:@"searchModeSegment"];
  UITextField *input = [modifier valueForKey:@"inputField"];
  for (NSNumber *restrictedMode in @[@(VMSearchModeFuzzy), @(VMSearchModeGroup)]) {
    modes.selectedSegmentIndex = VMSearchModeExact;
    [modes sendActionsForControlEvents:UIControlEventValueChanged];
    Check([types isEnabledForSegmentAtIndex:strIndex], @"exact mode enables Str selection");
    types.selectedSegmentIndex = strIndex;
    [types sendActionsForControlEvents:UIControlEventValueChanged];
    Check(types.selectedSegmentIndex == VMDataTypeString && !input.hidden &&
        input.keyboardType == UIKeyboardTypeDefault &&
        [input.placeholder isEqualToString:[[VMLocalization shared] localizedString:@"Mod_Input_Str"]],
        @"selecting Str through the real action configures visible text input and its placeholder");
    modes.selectedSegmentIndex = restrictedMode.integerValue;
    [modes sendActionsForControlEvents:UIControlEventValueChanged];
    Check(![types isEnabledForSegmentAtIndex:strIndex] && types.selectedSegmentIndex != VMDataTypeString,
        @"fuzzy/group modes retain their numeric-only type selection");
  }
  modes.selectedSegmentIndex = VMSearchModeExact;
  [modes sendActionsForControlEvents:UIControlEventValueChanged];
  types.selectedSegmentIndex = strIndex;
  [types sendActionsForControlEvents:UIControlEventValueChanged];
  Check([types isEnabledForSegmentAtIndex:strIndex] && input.keyboardType == UIKeyboardTypeDefault,
      @"returning to exact mode restores usable Str input");
}

@interface UIReviewApp : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) VMRootViewController *root;
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *pages;
@property(nonatomic) NSUInteger step;
@property(nonatomic, strong) VMZeroSearchFixture *zeroFixture;
@property(nonatomic) BOOL zeroScenarioReady;
@property(nonatomic, strong) VMStringOptionsFixture *stringFixture;
@property(nonatomic, strong) VMUpdateReviewFixture *updateFixture;
@property(nonatomic) IMP originalUpdateShared;
@property(nonatomic) IMP updateSharedReplacement;
@end
@implementation UIReviewApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  [defaults registerDefaults:@{@"app_theme":@1, @"resultLimit":@100, @"floatTolerance":@.001,
      @"groupRange":@"0x100", @"lockInterval":@.5}];
  [defaults setBool:YES forKey:@"has_agreed_disclaimer"];
  [defaults removeObjectForKey:@"vm_bottom_tab_order"];
  [defaults removeObjectForKey:@"vm_settings_group"];
  [[VMLocalization shared] setLanguage:@"zh-Hans"];
  class_replaceMethod(VMUpdateManager.class, @selector(performAutoCheck), imp_implementationWithBlock(^(id object) {}), "v@:");
  // Fixture list contains no user's installed applications or process metadata.
  IMP fixtures = imp_implementationWithBlock(^(UIViewController *page) {
    NSArray *apps = @[
      @{@"name":@"Vanson Demo", @"bid":@"com.vanson.demo", @"pid":@(getpid()), @"ver":@"1.0", @"path":@""},
      @{@"name":@"Long Application Name · 示例测试应用", @"bid":@"com.vanson.review.long-application-name", @"pid":@4096, @"ver":@"2.4", @"path":@""}
    ];
    [page setValue:apps forKey:@"userApps"];
    [page setValue:apps forKey:@"displayedApps"];
    [page setValue:apps forKey:@"allInstalledApps"];
    [(VMAppSelectViewController *)page updateSegmentTitles];
    UITableView *table = [page valueForKey:@"tableView"];
    [table reloadData];
  });
  class_replaceMethod(VMAppSelectViewController.class, NSSelectorFromString(@"loadProcesses"), fixtures, "v@:");
  class_replaceMethod(VMAppSelectViewController.class, NSSelectorFromString(@"loadInstalledApps"), imp_implementationWithBlock(^(id object) {}), "v@:");
  UIImage *fixtureIcon = [UIImage imageNamed:@"AppIcon60x60@2x"];
  [VMUIHelper cacheApplicationIcon:fixtureIcon forBundleID:@"com.vanson.demo"];
  [VMUIHelper cacheApplicationIcon:fixtureIcon forBundleID:@"com.vanson.local.uireview"];
  [VMUIHelper installAppearance];
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
  self.root = [VMRootViewController new];
#if TARGET_OS_MACCATALYST
  if (@available(macCatalyst 17.0, *)) {
    self.root.traitOverrides.horizontalSizeClass = UIUserInterfaceSizeClassCompact;
    self.root.traitOverrides.userInterfaceIdiom = UIUserInterfaceIdiomPhone;
    self.window.traitOverrides.horizontalSizeClass = UIUserInterfaceSizeClassCompact;
    self.window.traitOverrides.userInterfaceIdiom = UIUserInterfaceIdiomPhone;
  }
  if (@available(macCatalyst 18.0, *)) {
    self.root.mode = UITabBarControllerModeTabBar;
  }
#endif
  self.window.rootViewController = self.root;
  [self.window makeKeyAndVisible];
  BOOL interactive = [NSProcessInfo.processInfo.arguments containsObject:@"--interactive"];
#if TARGET_OS_MACCATALYST
  interactive = YES;
  dispatch_async(dispatch_get_main_queue(), ^{
    UIWindowScene *scene = self.window.windowScene;
    scene.titlebar.toolbar = nil;
    scene.sizeRestrictions.minimumSize = CGSizeMake(390, 740);
    scene.sizeRestrictions.maximumSize = CGSizeMake(430, 900);
    if (@available(macCatalyst 16.0, *)) {
      UIWindowSceneGeometryPreferencesMac *geometry = [[UIWindowSceneGeometryPreferencesMac alloc]
          initWithSystemFrame:CGRectMake(120, 80, 430, 900)];
      [scene requestGeometryUpdateWithPreferences:geometry errorHandler:^(NSError *error) {
        NSLog(@"Preview window sizing: %@", error.localizedDescription);
      }];
    }
  });
#endif
  if (interactive) {
    NSInteger theme = [defaults integerForKey:@"app_theme"];
    self.window.overrideUserInterfaceStyle = theme == 2 ? UIUserInterfaceStyleDark :
        theme == 1 ? UIUserInterfaceStyleLight : UIUserInterfaceStyleUnspecified;
    memcpy(reviewMemory + 8192, "VansonMod UI Review", 20);
    int32_t sampleValue = 100;
    memcpy(reviewMemory + 256, &sampleValue, sizeof(sampleValue));
    printf("Interactive VansonMod preview ready. Select Vanson Demo for a sandboxed self-process.\n");
    fflush(stdout);
    return YES;
  }
  self.pages = [NSMutableArray array];
  NSArray *names = @[@"applications", @"search", @"patch", @"toolbox", @"settings"];
  for (NSUInteger i = 0; i < names.count; i++)
    [self.pages addObject:@{@"name":names[i], @"tab":@(i)}];
  for (NSUInteger i = 0; i < names.count; i++)
    [self.pages addObject:@{@"name":[names[i] stringByAppendingString:@"-dark"], @"tab":@(i), @"dark":@YES}];
  for (NSUInteger i = 0; i < names.count; i++)
    [self.pages addObject:@{@"name":[names[i] stringByAppendingString:@"-compact"], @"tab":@(i), @"compact":@YES}];
  [self.pages addObjectsFromArray:@[
    @{@"name":@"toolbox-connected", @"tab":@3, @"connected":@YES},
    @{@"name":@"toolbox-connected-compact", @"tab":@3, @"connected":@YES, @"compact":@YES},
    @{@"name":@"patch-connected", @"tab":@2, @"connected":@YES},
    @{@"name":@"search-connected", @"tab":@1, @"connected":@YES},
    @{@"name":@"search-filters", @"tab":@1, @"connected":@YES, @"filterPanelOpen":@YES},
    @{@"name":@"search-fuzzy-compact", @"tab":@1, @"connected":@YES, @"compact":@YES},
    @{@"name":@"add-pointer", @"tab":@0, @"modal":@"pointer"},
    @{@"name":@"add-pointer-compact", @"tab":@0, @"modal":@"pointer", @"compact":@YES},
    @{@"name":@"add-pointer-keyboard", @"tab":@0, @"modal":@"pointer", @"compact":@YES},
    @{@"name":@"add-pointer-invalid-compact", @"tab":@0, @"modal":@"pointer", @"compact":@YES},
    @{@"name":@"toolbox-add-lock-compact", @"tab":@3, @"modal":@"lock", @"compact":@YES},
    @{@"name":@"patch-save-compact", @"tab":@2, @"modal":@"rva", @"compact":@YES}
  ]];
  [self.pages addObjectsFromArray:@[
    @{@"name":@"settings-function", @"tab":@4, @"settingsGroup":@1},
    @{@"name":@"settings-function-compact", @"tab":@4, @"settingsGroup":@1, @"compact":@YES},
    @{@"name":@"settings-function-dark", @"tab":@4, @"settingsGroup":@1, @"dark":@YES},
    @{@"name":@"settings-function-large-type", @"tab":@4, @"settingsGroup":@1, @"large":@YES},
    @{@"name":@"settings-about", @"tab":@4, @"settingsGroup":@2},
    @{@"name":@"settings-about-compact", @"tab":@4, @"settingsGroup":@2, @"compact":@YES},
    @{@"name":@"settings-about-dark", @"tab":@4, @"settingsGroup":@2, @"dark":@YES},
    @{@"name":@"settings-about-large-type", @"tab":@4, @"settingsGroup":@2, @"large":@YES}
  ]];
  [self.pages addObject:@{@"name":@"settings-large-type", @"tab":@4, @"large":@YES}];
  [self.pages addObject:@{@"name":@"settings-keyboard", @"tab":@4}];
  [self.pages addObject:@{@"name":@"settings-footer-compact", @"tab":@4, @"settingsGroup":@2, @"compact":@YES}];
  [self.pages addObject:@{@"name":@"patch-manager-batch-compact", @"tab":@2, @"compact":@YES}];
  [self.pages addObject:@{@"name":@"toolbox-batch-compact", @"tab":@3, @"compact":@YES}];
  for (NSArray *entry in @[
    @[@"pointer-search", @"VMPointerSearchViewController"],
    @[@"pointer-search-compact", @"VMPointerSearchViewController"],
    @[@"pointer-editor-large-type", @"VMItemEditViewController"],
    @[@"pointer-card", @"VMCardReviewController"],
    @[@"signature-card", @"VMCardReviewController"],
    @[@"patch-card", @"VMCardReviewController"],
    @[@"pointer-sessions", @"VMPointerSessionListViewController"],
    @[@"backups", @"VMBackupListViewController"],
    @[@"modules", @"VMModuleListViewController"],
    @[@"watchpoints", @"VMWatchpointViewController"],
    @[@"process-audit", @"VMProcessAuditViewController"],
    @[@"script-editor", @"VMScriptViewController"],
    @[@"script-tools", @"VMScriptShortcutViewController"],
    @[@"script-guide", @"VMScriptExampleViewController"],
    @[@"pointer-editor", @"VMItemEditViewController"],
    @[@"pointer-verifier", @"VMPointerVerifierViewController"],
    @[@"memory-browser", @"VMMemoryBrowserViewController"],
    @[@"hex-browser", @"VMHexEditorViewController"],
    @[@"hex-row-editor", @"VMHexRowEditorViewController"],
    @[@"hex-row-editor-compact", @"VMHexRowEditorViewController"],
    @[@"string-editor-keyboard", @"VMStringEditorViewController"],
    @[@"memory-browser-landscape", @"VMMemoryBrowserViewController"],
    @[@"pointer-editor-keyboard", @"VMItemEditViewController"],
    @[@"string-editor", @"VMStringEditorViewController"],
    @[@"signature-search", @"VMSignatureSearchViewController"],
    @[@"inspector", @"VMWatchpointViewController"],
    @[@"hex-browser-compact", @"VMHexEditorViewController"],
    @[@"signature-search-landscape", @"VMSignatureSearchViewController"],
    @[@"string-editor-compact", @"VMStringEditorViewController"],
    @[@"script-editor-compact", @"VMScriptViewController"],
    @[@"script-tools-compact", @"VMScriptShortcutViewController"],
    @[@"script-editor-dark", @"VMScriptViewController"],
    @[@"script-tools-dark", @"VMScriptShortcutViewController"]]) {
    [self.pages addObject:@{@"name":entry[0], @"class":entry[1]}];
  }
  for (NSArray *target in @[@[@"search-connected", @1], @[@"patch-connected", @2], @[@"toolbox-connected", @3]]) {
    [self.pages addObject:@{@"name":target[0], @"captureName":[target[0] stringByAppendingString:@"-long-id-compact"],
      @"tab":target[1], @"connected":@YES, @"compact":@YES, @"longBundleID":@YES}];
  }
  NSSet *darkScenarios = [NSSet setWithArray:@[
    @"toolbox-connected", @"patch-connected", @"search-connected", @"search-filters", @"search-fuzzy-compact",
    @"add-pointer", @"add-pointer-invalid-compact", @"add-pointer-keyboard",
    @"toolbox-add-lock-compact", @"patch-save-compact", @"settings-keyboard",
    @"settings-footer-compact", @"patch-manager-batch-compact", @"toolbox-batch-compact",
    @"pointer-search", @"pointer-editor", @"pointer-card", @"signature-card", @"patch-card",
    @"pointer-sessions", @"backups", @"modules", @"watchpoints", @"process-audit",
    @"pointer-verifier", @"memory-browser", @"hex-browser", @"hex-row-editor",
    @"string-editor", @"string-editor-keyboard", @"signature-search", @"inspector", @"script-guide"
  ]];
  for (NSDictionary *entry in self.pages.copy) {
    if (![darkScenarios containsObject:entry[@"name"]]) continue;
    NSMutableDictionary *dark = entry.mutableCopy;
    dark[@"captureName"] = [(entry[@"captureName"] ?: entry[@"name"]) stringByAppendingString:@"-dark"];
    dark[@"dark"] = @YES;
    dark[@"liveThemeSwitch"] = @YES;
    [self.pages addObject:dark];
  }
  NSArray *versionStates = @[@"idle", @"checking", @"current", @"available", @"failed"];
  for (NSUInteger state = 0; state < versionStates.count; state++) {
    for (NSNumber *dark in @[@NO, @YES]) {
      [self.pages addObject:@{@"name":[@"settings-version-" stringByAppendingString:versionStates[state]],
        @"captureName":[NSString stringWithFormat:@"settings-version-%@%@", versionStates[state], dark.boolValue ? @"-dark" : @""],
        @"tab":@4, @"settingsGroup":@2, @"compact":@YES, @"dark":dark, @"updateState":@(state)}];
    }
  }
  for (NSString *scenario in @[@"fuzzy-first", @"fuzzy-expanded", @"fuzzy-repeat", @"fuzzy-repeat-first", @"fuzzy-legacy", @"exact", @"group", @"filter", @"fuzzy-init-empty", @"fuzzy-init-failed"]) {
    for (NSNumber *dark in @[@NO, @YES]) {
      [self.pages addObject:@{@"name":[@"search-zero-" stringByAppendingString:scenario],
        @"captureName":[NSString stringWithFormat:@"search-zero-%@-compact%@", scenario, dark.boolValue ? @"-dark" : @""],
        @"tab":@1, @"connected":@YES, @"compact":@YES, @"dark":dark, @"zeroScenario":scenario}];
    }
  }
  for (NSString *scenario in @[@"trollstore", @"missing-package", @"package-manager", @"installer-unavailable", @"handoff-failed"]) {
    for (NSNumber *dark in @[@NO, @YES]) {
      [self.pages addObject:@{@"name":[@"settings-update-" stringByAppendingString:scenario],
        @"captureName":[NSString stringWithFormat:@"settings-update-%@-compact%@", scenario, dark.boolValue ? @"-dark" : @""],
        @"tab":@4, @"settingsGroup":@2, @"compact":@YES, @"dark":dark, @"updateScenario":scenario}];
    }
  }
  for (NSNumber *dark in @[@NO, @YES]) {
    [self.pages addObject:@{@"name":@"toolbox-add-script-compact",
      @"captureName":[@"toolbox-add-script-compact" stringByAppendingString:dark.boolValue ? @"-dark" : @""],
      @"tab":@3, @"connected":@YES, @"compact":@YES, @"dark":dark, @"modal":@"script-new"}];
    [self.pages addObject:@{@"name":@"script-info-compact",
      @"captureName":[@"script-info-compact" stringByAppendingString:dark.boolValue ? @"-dark" : @""],
      @"class":@"VMScriptViewController", @"compact":@YES, @"dark":dark, @"modal":@"script-info"}];
  }
  BOOL searchZeroOnly = [NSProcessInfo.processInfo.arguments containsObject:@"--search-zero-only"];
  BOOL updateUIOnly = [NSProcessInfo.processInfo.arguments containsObject:@"--update-ui-only"];
  BOOL formHintsOnly = [NSProcessInfo.processInfo.arguments containsObject:@"--form-hints-only"];
  BOOL controlScrollOnly = [NSProcessInfo.processInfo.arguments containsObject:@"--control-scroll-only"];
  BOOL stringOptionsOnly = [NSProcessInfo.processInfo.arguments containsObject:@"--string-options-only"];
  for (NSNumber *compact in @[@NO, @YES]) {
    for (NSNumber *dark in @[@NO, @YES]) {
      [self.pages addObject:@{@"name":[NSString stringWithFormat:@"memory-control-scroll%@%@",
          compact.boolValue ? @"-compact" : @"", dark.boolValue ? @"-dark" : @""],
        @"tab":@1, @"connected":@YES, @"compact":compact, @"dark":dark, @"controlScroll":@YES}];
    }
  }
  for (NSNumber *width in @[@400, @320]) {
    for (NSNumber *dark in @[@NO, @YES]) {
      [self.pages addObject:@{@"name":[NSString stringWithFormat:@"string-options-%@%@",
          width, dark.boolValue ? @"-dark" : @"-light"],
        @"class":@"VMModifierViewController", @"connected":@YES,
        @"width":width, @"dark":dark, @"stringOptions":@YES}];
    }
  }
  if (searchZeroOnly || updateUIOnly || formHintsOnly || controlScrollOnly || stringOptionsOnly) {
    self.pages = [[self.pages filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *entry, NSDictionary *bindings) {
      return stringOptionsOnly ? entry[@"stringOptions"] != nil : controlScrollOnly ? entry[@"controlScroll"] != nil : formHintsOnly ? entry[@"modal"] != nil : updateUIOnly ? entry[@"updateScenario"] != nil : entry[@"zeroScenario"] != nil;
    }]] mutableCopy];
  }
  Later(.5, ^{
    if (searchZeroOnly || updateUIOnly || formHintsOnly || controlScrollOnly || stringOptionsOnly) [self next]; else [self validate];
  });
  return YES;
}
- (void)validate {
  for (UIColor *tint in @[UIColor.systemIndigoColor, UIColor.systemBlueColor, UIColor.systemGreenColor, UIColor.systemRedColor, UIColor.systemOrangeColor]) {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tintColor = tint;
    [VMUIHelper styleButton:button primary:YES];
    UIColor *fill = button.backgroundColor;
    if (@available(iOS 15.0, *)) fill = button.configuration.background.backgroundColor;
    for (NSNumber *style in @[@(UIUserInterfaceStyleLight), @(UIUserInterfaceStyleDark)]) {
      UIColor *resolved = [fill resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style.integerValue]];
      CGFloat r, g, b, alpha;
      Check([resolved getRed:&r green:&g blue:&b alpha:&alpha], @"primary button fill resolves to RGB");
      double (^linear)(double) = ^double(double value) { return value <= .04045 ? value / 12.92 : pow((value + .055) / 1.055, 2.4); };
      double contrast = 1.05 / (.2126 * linear(r) + .7152 * linear(g) + .0722 * linear(b) + .05);
      Check(alpha == 1 && contrast >= 4.5, @"small white primary titles meet 4.5 contrast in both themes");
    }
  }
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  [defaults setObject:@[@0,@0,@2,@3,@4] forKey:@"vm_bottom_tab_order"];
  [self.root applyTabOrder];
  VMAppSelectViewController *applications = (id)((UINavigationController *)self.root.viewControllers[0]).topViewController;
  VMPointerChain *parsedChain = [applications parsePointerChainFromString:@"[Demo+0x100]\n+0x20-0x8"];
  Check(parsedChain && parsedChain.baseOffset == 0x100 && parsedChain.offsets.count == 2 && parsedChain.offsets.lastObject.longLongValue == -8,
      @"multiline pointer input retains module base and signed offsets");
  Check([applications parsePointerChainFromString:@"[Demo+0x100]garbage+0x20"] == nil &&
      [applications parsePointerChainFromString:@"[Demo+0x10000000000000000]+0x20"] == nil,
      @"malformed and overflowing pointer input is rejected before save");
  Check([applications parsePointerChainFromString:@"[Demo+0x100]+0xFFFFFFFFFFFFFFFF"] == nil &&
      [applications parsePointerChainFromString:@"[Demo+0x100]-0x8000000000000000"].offsets.lastObject.longLongValue == INT64_MIN &&
      [applications parsePointerChainFromString:@"[Demo+0x100]-0x8000000000000001"] == nil,
      @"pointer offsets enforce signed 64-bit boundaries");
  Check([NSSet setWithArray:self.root.viewControllers].count == 5, @"duplicate tab order restores five distinct pages");
  [defaults setObject:@[@4,@3,@2,@1,@0] forKey:@"vm_bottom_tab_order"];
  UIViewController *selected = self.root.selectedViewController;
  [self.root applyTabOrder];
  Check(self.root.selectedViewController == selected, @"reordering preserves active page");
  [defaults removeObjectForKey:@"vm_bottom_tab_order"];
  [self.root applyTabOrder];
  UINavigationController *nav = self.root.viewControllers[4];
  VMSettingsViewController *settings = (id)nav.topViewController;
  [settings loadViewIfNeeded];
  self.root.selectedViewController = nav;
  [self validateSettingsWhenReady:settings attempts:20];
}
- (void)validateSettingsWhenReady:(VMSettingsViewController *)settings attempts:(NSUInteger)attempts {
  [self.window layoutIfNeeded];
  if (settings.view.window != self.window && attempts > 0) {
    Later(.05, ^{ [self validateSettingsWhenReady:settings attempts:attempts - 1]; });
    return;
  }
  Check(settings.view.window == self.window, @"settings validation begins after its tab enters the window");
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  Check([[settings valueForKey:@"selectedSettingsGroup"] integerValue] == 0, @"settings open on search by default");
  for (NSInteger group = 0; group < 3; group++) {
    [settings selectSettingsGroup:group];
    CheckSettingsGroup(settings, group);
  }
  [settings selectSettingsGroup:0];
  UITextField *limit = [settings valueForKey:@"resultLimitField"];
  Check([limit.text isKindOfClass:NSString.class], @"numeric defaults appear as text");
  limit.text = @"250";
  [settings textFieldDidEndEditing:limit];
  Check([defaults integerForKey:@"resultLimit"] == 250, @"valid result limit saved");
  UITableView *validationTable = [settings valueForKey:@"tableView"];
  [validationTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
  [validationTable layoutIfNeeded];
  Check([limit becomeFirstResponder], @"settings group switch begins with an active numeric edit");
  limit.text = @"275";
  [settings selectSettingsGroup:1];
  Check(!limit.isFirstResponder && [defaults integerForKey:@"resultLimit"] == 275,
      @"changing settings groups finishes editing and saves the pending value");
  [self.window layoutIfNeeded];
  Check(fabs(validationTable.contentOffset.y + validationTable.adjustedContentInset.top) <= 1,
      @"changing settings groups resets the list to its first row");
  [settings selectSettingsGroup:0];
  [validationTable scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:4 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
  [validationTable layoutIfNeeded];
  Check([limit becomeFirstResponder], @"invalid settings edit receives keyboard focus");
  limit.text = @"12garbage";
  [settings selectSettingsGroup:1];
  Check([defaults integerForKey:@"resultLimit"] == 275 && [limit.text isEqual:@"275"], @"invalid numeric suffix retains saved value");
  Check([[settings valueForKey:@"selectedSettingsGroup"] integerValue] == 0 &&
      ((UISegmentedControl *)[settings valueForKey:@"groupTabs"]).selectedSegmentIndex == 0,
      @"invalid pending input retains the original settings group and tab");
  [settings dismissViewControllerAnimated:NO completion:nil];
  VMScriptModel *undoModel = [VMScriptModel new];
  undoModel.scriptContent = @"console.log('keep this');";
  VMScriptViewController *undoPage = [VMScriptViewController new];
  undoPage.scriptModel = undoModel;
  [undoPage loadViewIfNeeded];
  [undoPage clearEditorContents];
  UITextView *undoText = [undoPage valueForKey:@"editorView"];
  Check(undoText.text.length == 0 && undoText.undoManager.canUndo, @"script clear registers an undoable edit");
  [undoPage undoEditor];
  Check([undoText.text isEqual:undoModel.scriptContent] && ![undoPage hasUnsavedChanges], @"script undo restores content and clean baseline");
  VMHexRowEditorViewController *hex = [VMHexRowEditorViewController new];
  hex.originalData = [NSData dataWithBytes:"AB" length:2];
  [hex loadViewIfNeeded];
  Check(![hex hasUnsavedChanges], @"fresh Hex row starts clean");
  UITextView *hexText = [hex valueForKey:@"hexTextView"];
  hexText.text = @"43 44";
  [hex textViewDidChange:hexText];
  Check([hex hasUnsavedChanges] && hex.navigationItem.leftBarButtonItem != nil, @"Hex draft protects the back action");
  hexText.text = @"41 42";
  [hex textViewDidChange:hexText];
  Check(![hex hasUnsavedChanges] && hex.navigationItem.leftBarButtonItem == nil, @"restoring original Hex clears draft protection");
  VMScriptModel *script = [VMScriptModel new];
  script.scriptContent = @"original"; script.fileName = @"draft.vmsc"; script.bundleID = @"com.vanson.ui.fixture";
  VMScriptViewController *scriptEditor = [VMScriptViewController new]; scriptEditor.scriptModel = script;
  [scriptEditor loadViewIfNeeded];
  UITextView *textView = [scriptEditor valueForKey:@"editorView"];
  textView.text = @"draft"; [scriptEditor textViewDidChange:textView];
  script.desc = @"updated metadata"; [scriptEditor updateHeaderInfo];
  NSString *unsaved = [[VMLocalization shared] localizedString:@"Str_Unsaved"];
  Check([scriptEditor hasUnsavedChanges] && [((UILabel *)[scriptEditor valueForKey:@"infoLabel"]).text containsString:unsaved], @"metadata changes retain script dirty indicator");
  Method writeMethod = class_getInstanceMethod(VMScriptViewController.class, @selector(writeScriptModelToDisk:));
  IMP originalWrite = method_getImplementation(writeMethod);
  IMP failWrite = imp_implementationWithBlock(^BOOL(id object, VMScriptModel *candidate) { return NO; });
  method_setImplementation(writeMethod, failWrite);
  Check(![scriptEditor saveScriptModelToDisk] && [script.scriptContent isEqual:@"original"] && [textView.text isEqual:@"draft"] && [scriptEditor hasUnsavedChanges], @"failed script save preserves model and draft");
  IMP successWrite = imp_implementationWithBlock(^BOOL(id object, VMScriptModel *candidate) { return YES; });
  method_setImplementation(writeMethod, successWrite);
  Check([scriptEditor saveScriptModelToDisk] && [script.scriptContent isEqual:@"draft"] && ![scriptEditor hasUnsavedChanges], @"successful script save advances saved baseline");
  method_setImplementation(writeMethod, originalWrite); imp_removeBlock(failWrite); imp_removeBlock(successWrite);
  VMMemoryEngine *engine = VMMemoryEngine.shared;
  NSUInteger oldCount = engine.resultCount;
  VMScanResultItem *first = [VMScanResultItem new]; first.address = 0x1110; first.type = VMDataTypeInt32; first.valueStr = @"1";
  VMScanResultItem *second = [VMScanResultItem new]; second.address = 0x2220; second.type = VMDataTypeInt32; second.valueStr = @"2";
  VMScanResultItem *pinned = [VMScanResultItem new]; pinned.address = 0x3330; pinned.type = VMDataTypeFloat; pinned.valueStr = @"3";
  SEL selector = @selector(getResultItemAtIndex:dataType:);
  Method method = class_getInstanceMethod(VMMemoryEngine.class, selector);
  IMP original = method_getImplementation(method);
  IMP fixture = imp_implementationWithBlock(^VMScanResultItem *(id object, NSUInteger index, VMDataType type) {
    return index == 0 ? first : index == 1 ? second : nil;
  });
  method_setImplementation(method, fixture);
  engine.resultCount = 2;
  VMModifierViewController *modifier = [VMModifierViewController new];
  [modifier loadViewIfNeeded];
  [modifier setValue:[NSMutableArray arrayWithObject:pinned] forKey:@"pinnedResults"];
  UITableView *results = [modifier valueForKey:@"tableView"];
  results.allowsMultipleSelectionDuringEditing = YES;
  [results setEditing:YES];
  [results reloadData];
  for (NSUInteger row = 0; row < 2; row++) [results selectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
  NSArray *items = [modifier batchModificationItems];
  Check(items.count == 2 && ((VMScanResultItem *)items[0]).address == pinned.address && ((VMScanResultItem *)items[1]).address == first.address, @"batch selection maps pinned and engine rows to visible addresses");
  [modifier setValue:@YES forKey:@"isGlobalSelectAll"];
  NSIndexPath *removed = [NSIndexPath indexPathForRow:0 inSection:0];
  [results deselectRowAtIndexPath:removed animated:NO];
  [modifier tableView:results didDeselectRowAtIndexPath:removed];
  items = [modifier batchModificationItems];
  Check(![[modifier valueForKey:@"isGlobalSelectAll"] boolValue] && items.count == 1 && ((VMScanResultItem *)items[0]).address == first.address, @"deselecting after all limits batch writes to remaining selected rows");
  method_setImplementation(method, original);
  imp_removeBlock(fixture);
  engine.resultCount = oldCount;
  [engine batchModifyValues:@"2" limit:0 type:VMDataTypeInt32 mode:0 items:@[]];
  Check(YES, @"empty explicit write selection returns safely");
  VMPointerChain *chain = [VMPointerChain new];
  chain.note = @"Original"; chain.author = @"Keep Author"; chain.lockValue = @"123";
  chain.lockType = VMDataTypeUInt64; chain.uiMode = VMPointerUIModeInput;
  chain.uiMin = -10; chain.uiMax = 90; chain.switchOnValue = @"7"; chain.switchOffValue = @"2";
  VMItemEditViewController *editor = [VMItemEditViewController new];
  editor.model = chain;
  [editor loadViewIfNeeded];
  UISegmentedControl *mode = [editor valueForKey:@"modeSegment"];
  mode.selectedSegmentIndex = 1;
  [editor onModeChange:mode];
  Check(chain.uiMode == VMPointerUIModeInput, @"editing display mode retains original until save");
  [editor onCancel];
  Check(chain.uiMode == VMPointerUIModeInput, @"cancel retains pointer display mode");
  editor = [VMItemEditViewController new];
  editor.model = chain;
  [editor loadViewIfNeeded];
  [editor onSaveBtn];
  Check(chain.lockType == VMDataTypeUInt64, @"unmodified unsigned type survives save");
  Check([chain.author isEqual:@"Keep Author"] && chain.uiMin == -10 && chain.uiMax == 90 && [chain.switchOnValue isEqual:@"7"], @"save without scrolling retains author and hidden mode values");
  chain.isImported = YES;
  chain.lockType = VMDataTypeString;
  editor = [VMItemEditViewController new]; editor.model = chain; [editor loadViewIfNeeded];
  NSDictionary *fields = [editor valueForKey:@"fields"];
  ((UITextField *)fields[@"author"]).text = @"Changed";
  ((UITextField *)fields[@"note"]).text = @"Renamed";
  [editor onSaveBtn];
  Check(chain.lockType == VMDataTypeString && [chain.author isEqual:@"Keep Author"] && [chain.note isEqual:@"Renamed"], @"imported metadata protection and String type survive save");
  UITableView *table = [settings valueForKey:@"tableView"];
  UIEdgeInsets before = table.contentInset;
  UIView *legalFooter = table.tableFooterView;
  [VMUIHelper addFixedFooterTo:settings forTableView:table];
  [VMUIHelper addFixedFooterTo:settings forTableView:table];
  Check(UIEdgeInsetsEqualToEdgeInsets(before, table.contentInset), @"footer installation keeps stable content insets");
  table.tableFooterView = legalFooter;
  // Finish the deliberate validation alert transition before photographing pages.
  Later(.5, ^{
    [self.root dismissViewControllerAnimated:NO completion:^{ [self next]; }];
  });
}
- (void)runSearchZeroScenario:(NSString *)scenario modifier:(VMModifierViewController *)modifier {
  self.zeroScenarioReady = NO;
  self.zeroFixture = [VMZeroSearchFixture new];
  VMZeroSearchFixture *fixture = self.zeroFixture;
  [modifier handleReset];
  // The reset and every engine completion enqueue their real controller work first.
  dispatch_async(dispatch_get_main_queue(), ^{
    UISegmentedControl *mode = [modifier valueForKey:@"searchModeSegment"];
    BOOL fuzzy = [scenario hasPrefix:@"fuzzy"];
    mode.selectedSegmentIndex = fuzzy ? VMSearchModeFuzzy : [scenario isEqual:@"group"] ? VMSearchModeGroup : VMSearchModeExact;
    [modifier modeChanged];
    ((UITextField *)[modifier valueForKey:@"inputField"]).text = fuzzy ? @"" : [scenario isEqual:@"group"] ? @"100;200" : @"100";
    dispatch_block_t finished = ^{
      CheckSearchHeaderFit(modifier, scenario);
      self.zeroScenarioReady = YES;
    };
    dispatch_block_t zeroScan = ^{
      fixture.nextCount = 0;
      if ([scenario isEqual:@"filter"]) {
        [modifier toggleFilterPanel];
        ((UITextField *)[modifier valueForKey:@"tfFilter1"]).text = @"50";
        [modifier applyFilter];
      } else if ([scenario isEqual:@"fuzzy-repeat"] || [scenario isEqual:@"fuzzy-repeat-first"]) {
        [modifier executeFuzzyRepeatWithFilterMode:VMFilterModeChanged total:3];
      } else {
        if ([scenario isEqual:@"fuzzy-legacy"]) {
          ((UISegmentedControl *)[modifier valueForKey:@"fuzzySegRow1"]).selectedSegmentIndex = UISegmentedControlNoSegment;
          ((UISegmentedControl *)[modifier valueForKey:@"fuzzySegRow2"]).selectedSegmentIndex = 0;
          ((UITextField *)[modifier valueForKey:@"inputField"]).text = @"1";
          [modifier fuzzyTypeChanged];
        }
        [modifier handleSearch];
      }
      // Repeat uses an additional queued step; the extra hop observes its completion.
      dispatch_async(dispatch_get_main_queue(), ^{ dispatch_async(dispatch_get_main_queue(), finished); });
    };
    if ([scenario isEqual:@"fuzzy-init-empty"] || [scenario isEqual:@"fuzzy-init-failed"]) {
      fixture.initCount = 0;
      fixture.initSuccess = ![scenario isEqual:@"fuzzy-init-failed"];
      [modifier handleSearch];
      dispatch_async(dispatch_get_main_queue(), finished);
    } else if (fuzzy) {
      [modifier handleSearch];
      dispatch_async(dispatch_get_main_queue(), ^{
        Check([[modifier valueForKey:@"isNextScan"] boolValue] && [[modifier valueForKey:@"isFuzzyLocked"] boolValue],
            @"zero-result scenario starts from a real fuzzy initialization callback");
        Check(![[modifier valueForKey:@"fuzzySegRow1"] isHidden], @"fuzzy baseline shows refinement controls before collapsing");
        if ([scenario isEqual:@"fuzzy-first"] || [scenario isEqual:@"fuzzy-repeat-first"]) {
          Check(VMMemoryEngine.shared.resultCount == 0, @"initial fuzzy snapshot precedes materialized search results");
          zeroScan();
        } else {
          fixture.nextCount = 1;
          [modifier handleSearch];
          dispatch_async(dispatch_get_main_queue(), ^{
            Check(![[modifier valueForKey:@"fuzzySegRow2"] isHidden] && VMMemoryEngine.shared.resultCount == 1,
                @"expanded fuzzy scenario first receives a successful refinement callback");
            zeroScan();
          });
        }
      });
    } else if ([scenario isEqual:@"filter"]) {
      fixture.nextCount = 1;
      [modifier handleSearch];
      dispatch_async(dispatch_get_main_queue(), zeroScan);
    } else {
      zeroScan();
    }
  });
}
- (void)checkSearchZeroScenario:(NSString *)scenario modifier:(VMModifierViewController *)modifier {
  Check(self.zeroScenarioReady, @"zero-result callback completes before capture");
  CheckSearchHeaderFit(modifier, scenario);
  Check(VMMemoryEngine.shared.resultCount == 0 && ![[modifier valueForKey:@"isNextScan"] boolValue] &&
      ![[modifier valueForKey:@"isFuzzyLocked"] boolValue] && ![[modifier valueForKey:@"isScanning"] boolValue],
      @"empty search returns to a fresh unlocked session");
  UISegmentedControl *modes = [modifier valueForKey:@"searchModeSegment"];
  Check([modes isEnabledForSegmentAtIndex:0] && [modes isEnabledForSegmentAtIndex:2], @"empty fuzzy search permits exact and group searches");
  UIButton *search = [modifier valueForKey:@"searchBtn"];
  Check(search.enabled && modifier.view.userInteractionEnabled &&
      [[search titleForState:UIControlStateNormal] isEqualToString:[[VMLocalization shared] localizedString:@"Mod_Search_First"]],
      @"empty or failed search retains a labeled and usable first-search button");
  for (NSString *key in @[@"fuzzySegRow1", @"fuzzySegRow2", @"fuzzyHintLabel", @"filterPanelView"])
    Check([[modifier valueForKey:key] isHidden], [@"zero-result state collapses " stringByAppendingString:key]);
  UITableView *table = [modifier valueForKey:@"tableView"];
  UIView *context = [modifier valueForKey:@"contextHeader"];
  CGFloat natural = [context systemLayoutSizeFittingSize:CGSizeMake(context.bounds.size.width, UILayoutFittingCompressedSize.height)
      withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel].height;
  Check(context.bounds.size.width > 0 && fabs(context.bounds.size.height - natural) <= 1,
      @"attached process identity keeps its intrinsic height after zero results");
  CGRect identity = [context convertRect:context.bounds toView:table.tableHeaderView];
  CGRect modeFrame = [modes.superview convertRect:modes.superview.bounds toView:table.tableHeaderView];
  Check(fabs(CGRectGetMinY(identity) - 8) <= 1 && fabs(CGRectGetMinY(modeFrame) - CGRectGetMaxY(identity) - 10) <= 1,
      @"process identity retains compact top and bottom spacing");
  VMZeroSearchFixture *fixture = self.zeroFixture;
  if ([scenario hasPrefix:@"fuzzy"]) Check(fixture.initCalls == 1, @"fuzzy fixture passes through the initialization engine API");
  if ([scenario isEqual:@"fuzzy-first"] || [scenario isEqual:@"fuzzy-repeat-first"])
    Check(fixture.fuzzyCalls == 1, @"initial fuzzy refinement and repeat each call the engine before accepting zero results");
  if ([scenario isEqual:@"fuzzy-expanded"] || [scenario isEqual:@"fuzzy-repeat"])
    Check(fixture.fuzzyCalls == 2, @"expanded and repeated fuzzy searches stop immediately at zero results");
  if ([scenario isEqual:@"filter"]) Check(fixture.filterCalls == 1, @"expanded filter zero result uses the filter engine callback");
  if ([scenario isEqual:@"exact"] || [scenario isEqual:@"group"] || [scenario isEqual:@"fuzzy-legacy"])
    Check(fixture.scanCalls == 1, @"exact, group and legacy fuzzy zero results use the scan engine callback");
}
- (void)retrySearchAfterZero:(VMModifierViewController *)modifier completion:(dispatch_block_t)completion {
  VMZeroSearchFixture *fixture = self.zeroFixture;
  BOOL fuzzy = ((UISegmentedControl *)[modifier valueForKey:@"searchModeSegment"]).selectedSegmentIndex == VMSearchModeFuzzy;
  NSUInteger before = fuzzy ? fixture.initCalls : fixture.scanCalls;
  fixture.initSuccess = YES;
  fixture.initCount = 4096;
  fixture.nextCount = 1;
  [modifier handleSearch];
  dispatch_async(dispatch_get_main_queue(), ^{
    Check((fuzzy ? fixture.initCalls : fixture.scanCalls) == before + 1 && [[modifier valueForKey:@"isNextScan"] boolValue],
        @"search after zero starts a new engine scan and accepts its successful callback");
    if (fuzzy) {
      UISegmentedControl *row1 = [modifier valueForKey:@"fuzzySegRow1"];
      UISegmentedControl *row2 = [modifier valueForKey:@"fuzzySegRow2"];
      UILabel *hint = [modifier valueForKey:@"fuzzyHintLabel"];
      Check(row1.selectedSegmentIndex == 3 && row2.selectedSegmentIndex == UISegmentedControlNoSegment &&
          !hint.hidden && hint.text.length > 0,
          @"fresh fuzzy initialization restores changed-value selection and its visible hint");
    }
    [modifier handleReset];
    dispatch_async(dispatch_get_main_queue(), ^{
      [fixture restore];
      self.zeroFixture = nil;
      completion();
    });
  });
}
- (void)finishUpdateScenario:(NSDictionary *)entry settings:(VMSettingsViewController *)settings
    originalPrompt:(UIAlertController *)originalPrompt failure:(BOOL)failure {
  UIAlertController *alert = (id)settings.presentedViewController;
  Check([alert isKindOfClass:UIAlertController.class] && alert.view.window == self.window,
      @"update scenario finishes with a visible native alert");
  Check(alert.traitCollection.userInterfaceStyle == self.window.traitCollection.userInterfaceStyle,
      @"update alert follows the current light or dark theme");
  NSString *scenario = entry[@"updateScenario"];
  NSString *messageKey = failure ? @"Update_Installer_Unavailable" :
      [scenario isEqual:@"missing-package"] ? @"Update_Package_Unavailable" :
      [scenario isEqual:@"package-manager"] ? @"Update_Deb_Hint" : @"Update_Install_Hint";
  NSString *message = [VMLocalization.shared localizedString:messageKey];
  Check([alert.message containsString:message] && ContainsLabel(alert.view, message),
      @"update guidance appears in the rendered native alert");
  NSMutableArray *titles = [NSMutableArray array];
  for (UIAlertAction *action in alert.actions) [titles addObject:action.title ?: @""];
  NSMutableArray *expected = [NSMutableArray array];
  if (!failure && [scenario isEqual:@"trollstore"])
    [expected addObject:[VMLocalization.shared localizedString:@"Update_Install_TrollStore"]];
  [expected addObject:[VMLocalization.shared localizedString:@"Update_Release_Page"]];
  [expected addObject:[VMLocalization.shared localizedString:@"Btn_Cancel"]];
  Check([titles isEqualToArray:expected], @"native update alert keeps the correct install and fallback actions");
  if (failure) {
    Check(alert != originalPrompt && originalPrompt.presentingViewController == nil,
        @"failure prompt replaces the dismissed update alert");
    NSUInteger expectedOpens = [scenario isEqual:@"handoff-failed"] ? 1 : 0;
    Check(self.updateFixture.openedURLs.count == expectedOpens,
        @"failure scenario invokes only the expected simulated handoff");
    if (expectedOpens) {
      NSURLComponents *parts = [NSURLComponents componentsWithURL:self.updateFixture.openedURLs.firstObject resolvingAgainstBaseURL:NO];
      Check([parts.scheme isEqual:@"apple-magnifier"] && [parts.host isEqual:@"install"] &&
          parts.queryItems.count == 1 && [parts.queryItems.firstObject.value isEqual:self.updateFixture.tipaDownloadURL],
          @"native install action hands the validated package to the simulated installer");
    }
  } else {
    Check(self.updateFixture.openedURLs.count == 0, @"viewing update choices leaves external apps untouched");
  }
  for (UILabel *label in ViewsOfClass(alert.view, UILabel.class)) {
    if (label.hidden || label.alpha == 0 || !label.text.length || label.bounds.size.width == 0) continue;
    CGSize natural = [label sizeThatFits:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX)];
    Check(label.bounds.size.height + 1 >= natural.height, @"native update alert labels fit on compact width");
  }
  CaptureReviewWindow(self.window, entry);
  [settings dismissViewControllerAnimated:NO completion:^{
    Check(settings.presentedViewController == nil, @"update prompt dismisses back to settings");
    Check([(UIButton *)[settings valueForKey:@"versionButton"] isEnabled], @"version action remains usable after update prompt dismissal");
    Method sharedMethod = class_getClassMethod(VMUpdateManager.class, @selector(shared));
    method_setImplementation(sharedMethod, self.originalUpdateShared);
    imp_removeBlock(self.updateSharedReplacement);
    self.updateSharedReplacement = NULL;
    method_setImplementation(class_getClassMethod(UIAlertAction.class, @selector(actionWithTitle:style:handler:)),
        (IMP)UpdateReviewOriginalActionFactory);
    self.updateFixture = nil;
    [NSNotificationCenter.defaultCenter postNotificationName:kVMUpdateStateDidChangeNotification object:VMUpdateManager.shared];
    self.step++;
    [self next];
  }];
}
- (void)runUpdateScenario:(NSDictionary *)entry settings:(VMSettingsViewController *)settings {
  VMUpdateReviewFixture *fixture = [VMUpdateReviewFixture new];
  self.updateFixture = fixture;
  NSString *scenario = entry[@"updateScenario"];
  if ([scenario isEqual:@"missing-package"]) fixture.tipaDownloadURL = nil;
  if ([scenario isEqual:@"package-manager"]) fixture.fixtureKind = VMUpdateInstallKindPackageManager;
  if ([scenario isEqual:@"installer-unavailable"]) fixture.installerAvailable = NO;
  if ([scenario isEqual:@"handoff-failed"]) fixture.handoffSucceeds = NO;
  Method sharedMethod = class_getClassMethod(VMUpdateManager.class, @selector(shared));
  self.originalUpdateShared = method_getImplementation(sharedMethod);
  self.updateSharedReplacement = imp_implementationWithBlock(^VMUpdateManager *(id cls) { return fixture; });
  method_setImplementation(sharedMethod, self.updateSharedReplacement);
  Method actionFactory = class_getClassMethod(UIAlertAction.class, @selector(actionWithTitle:style:handler:));
  UpdateReviewOriginalActionFactory = (decltype(UpdateReviewOriginalActionFactory))method_getImplementation(actionFactory);
  method_setImplementation(actionFactory, (IMP)UpdateReviewCaptureActionFactory);
  [NSNotificationCenter.defaultCenter postNotificationName:kVMUpdateStateDidChangeNotification object:fixture];
  [self.window layoutIfNeeded];
  CheckSettingsGroup(settings, 2);
  UITableView *table = [settings valueForKey:@"tableView"];
  UIButton *versionButton = [settings valueForKey:@"versionButton"];
  [table scrollRectToVisible:[versionButton convertRect:versionButton.bounds toView:table] animated:NO];
  [versionButton sendActionsForControlEvents:UIControlEventTouchUpInside];
  Later(.65, ^{
    UIAlertController *alert = (id)settings.presentedViewController;
    Check([alert isKindOfClass:UIAlertController.class] && alert.view.window == self.window,
        @"shared version row opens the real update prompt");
    BOOL failure = [scenario isEqual:@"installer-unavailable"] || [scenario isEqual:@"handoff-failed"];
    if (!failure) {
      [self finishUpdateScenario:entry settings:settings originalPrompt:alert failure:NO];
      return;
    }
    NSString *installTitle = [VMLocalization.shared localizedString:@"Update_Install_TrollStore"];
    UIAlertAction *install = nil;
    for (UIAlertAction *action in alert.actions) if ([action.title isEqual:installTitle]) { install = action; break; }
    void (^handler)(UIAlertAction *) = install ? objc_getAssociatedObject(install, UpdateReviewActionHandlerKey) : nil;
    Check(handler != nil, @"update install action retains its production handler");
    if ([scenario isEqual:@"handoff-failed"]) {
      // Model UIKit's action dismissal while the external handoff callback is
      // still pending. Production presentation must wait for that transition.
      [alert dismissViewControllerAnimated:YES completion:nil];
      Check(alert.isBeingDismissed || settings.transitionCoordinator != nil || alert.transitionCoordinator != nil,
          @"handoff failure begins during a real UIKit dismissal transition");
    }
    // With an unavailable installer the original alert remains presented;
    // the production recovery helper must dismiss it before showing failure.
    handler(install);
    Later(1.1, ^{ [self finishUpdateScenario:entry settings:settings originalPrompt:alert failure:YES]; });
  });
}
- (void)runControlScrollScenario:(NSDictionary *)entry modifier:(VMModifierViewController *)modifier {
  [modifier handleReset];
  // Allow the real reset callback and tab transition to finish before measuring.
  Later(.3, ^{
    CheckMemoryControlStrips(modifier, [entry[@"compact"] boolValue]);
    VMZeroSearchFixture *fixture = [VMZeroSearchFixture new];
    UISegmentedControl *types = [modifier valueForKey:@"dataTypeSegment"];
    types.selectedSegmentIndex = VMDataTypeInt32;
    [types sendActionsForControlEvents:UIControlEventValueChanged];
    VMMemoryEngine.shared.currentDataType = VMDataTypeInt32;
    VMMemoryEngine.shared.resultCount = 1;
    [modifier updateButtonStates];
    UIButton *filter = [modifier valueForKey:@"btnFilter"];
    UIView *panel = [modifier valueForKey:@"filterPanelView"];
    Check(filter.enabled && panel.hidden, @"fixture result enables the existing filter action");
    [filter sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(!panel.hidden, @"header filter button retains its real click callback");
    [filter sendActionsForControlEvents:UIControlEventTouchUpInside];
    Check(panel.hidden, @"repeated filter click closes the panel");
    VMMemoryEngine.shared.resultCount = 0;
    [modifier updateButtonStates];
    [fixture restore];
    [self.window layoutIfNeeded];
    CaptureReviewWindow(self.window, entry);
    self.step++;
    [self next];
  });
}
- (void)captureStringOptions:(NSDictionary *)entry suffix:(NSString *)suffix {
  [self.window layoutIfNeeded];
  CaptureReviewWindow(self.window, @{@"captureName":[entry[@"name"] stringByAppendingString:suffix]});
}
- (void)finishStringOptionsScenario:(NSDictionary *)entry modifier:(VMModifierViewController *)modifier {
  [self.stringFixture restore];
  self.stringFixture = nil;
  [modifier handleReset];
  Later(.12, ^{
    UISegmentedControl *encoding = [modifier valueForKey:@"stringEncodingSegment"];
    UISwitch *caseSwitch = [modifier valueForKey:@"stringCaseSwitch"];
    Check(encoding.enabled && caseSwitch.enabled && ![[modifier valueForKey:@"isNextScan"] boolValue],
        @"reset unlocks both Str options and exits result refinement");
    CheckSearchHeaderFit(modifier, @"Str reset");
    [self captureStringOptions:entry suffix:@"-reset"];
    self.step++;
    [self next];
  });
}
- (void)restoreStringOptionsTimeline:(NSDictionary *)entry modifier:(VMModifierViewController *)modifier {
  VMMemoryEngine *engine = VMMemoryEngine.shared;
  Check(engine.memoryTimelineItems.count >= 2, @"real search callbacks capture string timeline entries");
  VMMemoryTimelineItem *snapshot = engine.memoryTimelineItems.firstObject;
  Check(snapshot.stringEncoding == VMStringEncodingUTF16LE && !snapshot.stringCaseSensitive,
      @"production timeline retains encoding and case options");
  [engine clearSession];
  engine.stringEncoding = VMStringEncodingUTF16BE;
  engine.stringCaseSensitive = YES;
  [modifier setValue:@NO forKey:@"isNextScan"];
  UISegmentedControl *encoding = [modifier valueForKey:@"stringEncodingSegment"];
  UISwitch *caseSwitch = [modifier valueForKey:@"stringCaseSwitch"];
  encoding.selectedSegmentIndex = VMStringEncodingUTF8;
  caseSwitch.on = YES;
  [modifier updateButtonStates];
  Method factory = class_getClassMethod(UIAlertAction.class, @selector(actionWithTitle:style:handler:));
  UpdateReviewOriginalActionFactory = (decltype(UpdateReviewOriginalActionFactory))method_getImplementation(factory);
  method_setImplementation(factory, (IMP)UpdateReviewCaptureActionFactory);
  [modifier showTimelineSheet];
  method_setImplementation(factory, (IMP)UpdateReviewOriginalActionFactory);
  Later(.2, ^{
    UIAlertController *sheet = (id)modifier.presentedViewController;
    Check([sheet isKindOfClass:UIAlertController.class] && sheet.actions.count > 1,
        @"Str timeline opens its production UIKit sheet");
    UIAlertAction *restore = sheet.actions.firstObject;
    void (^handler)(UIAlertAction *) = objc_getAssociatedObject(restore, UpdateReviewActionHandlerKey);
    Check(handler != nil, @"timeline restore uses its actual action handler");
    [modifier dismissViewControllerAnimated:NO completion:^{
      handler(restore);
      Check(engine.stringEncoding == VMStringEncodingUTF16LE && !engine.stringCaseSensitive,
          @"real timeline restoration restores engine string configuration");
      Check(encoding.selectedSegmentIndex == VMStringEncodingUTF16LE && !caseSwitch.on &&
          !encoding.enabled && !caseSwitch.enabled,
          @"restored timeline synchronizes and locks visible Str configuration");
      Check(((UISegmentedControl *)[modifier valueForKey:@"dataTypeSegment"]).selectedSegmentIndex == VMDataTypeString &&
          ((UISegmentedControl *)[modifier valueForKey:@"searchModeSegment"]).selectedSegmentIndex == VMSearchModeExact,
          @"restored Str timeline keeps the exact search controls active");
      Later(1.4, ^{
        CheckSearchHeaderFit(modifier, @"Str timeline restore");
        [self captureStringOptions:entry suffix:@"-restored"];
        [self finishStringOptionsScenario:entry modifier:modifier];
      });
    }];
  });
}
- (void)runStringOptionsScenario:(NSDictionary *)entry modifier:(VMModifierViewController *)modifier {
  [modifier handleReset];
  Later(.25, ^{
    [self.window layoutIfNeeded];
    UISegmentedControl *types = [modifier valueForKey:@"dataTypeSegment"];
    UISegmentedControl *modes = [modifier valueForKey:@"searchModeSegment"];
    UISegmentedControl *encoding = [modifier valueForKey:@"stringEncodingSegment"];
    UISwitch *caseSwitch = [modifier valueForKey:@"stringCaseSwitch"];
    UIStackView *options = [modifier valueForKey:@"stringOptionsStack"];
    UITextField *input = [modifier valueForKey:@"inputField"];
    UITableView *table = [modifier valueForKey:@"tableView"];
    modes.selectedSegmentIndex = VMSearchModeExact;
    [modes sendActionsForControlEvents:UIControlEventValueChanged];
    types.selectedSegmentIndex = VMDataTypeInt32;
    [types sendActionsForControlEvents:UIControlEventValueChanged];
    [self.window layoutIfNeeded];
    CGFloat numericHeight = table.tableHeaderView.bounds.size.height;
    Check(options.hidden, @"numeric search collapses the entire string-options stack");
    types.selectedSegmentIndex = VMDataTypeString;
    [types sendActionsForControlEvents:UIControlEventValueChanged];
    [self.window layoutIfNeeded];
    Check(!options.hidden && encoding.numberOfSegments == 3 && encoding.selectedSegmentIndex == VMStringEncodingUTF8 && caseSwitch.on,
        @"new Str search offers UTF-8, UTF-16 LE and UTF-16 BE with case-sensitive UTF-8 defaults");
    Check([[encoding titleForSegmentAtIndex:0] isEqual:@"UTF-8"] &&
        [[encoding titleForSegmentAtIndex:1] isEqual:@"UTF-16 LE"] &&
        [[encoding titleForSegmentAtIndex:2] isEqual:@"UTF-16 BE"], @"all three encoding labels identify their byte order");
    Check(encoding.enabled && caseSwitch.enabled, @"fresh Str options are enabled");
    Check(input.keyboardType == UIKeyboardTypeDefault &&
        [input.placeholder isEqual:[VMLocalization.shared localizedString:@"Mod_Input_Str"]],
        @"Str keeps its localized text placeholder and Unicode-capable keyboard");
    Check(input.autocapitalizationType == UITextAutocapitalizationTypeNone &&
        input.autocorrectionType == UITextAutocorrectionTypeNo && input.spellCheckingType == UITextSpellCheckingTypeNo &&
        input.smartQuotesType == UITextSmartQuotesTypeNo && input.smartDashesType == UITextSmartDashesTypeNo,
        @"Str search preserves typed case, quotes and punctuation without automatic substitutions");
    Check(table.tableHeaderView.bounds.size.height >= numericHeight + 75,
        @"visible Str controls receive their natural height");
    for (UIView *control in @[encoding, caseSwitch]) {
      CGRect rect = [control convertRect:control.bounds toView:options];
      printf("STRING_OPTION_LAYOUT control=%s rect=%.1f,%.1f %.1fx%.1f stack=%.1fx%.1f\n",
          NSStringFromClass(control.class).UTF8String, rect.origin.x, rect.origin.y, rect.size.width,
          rect.size.height, options.bounds.size.width, options.bounds.size.height); fflush(stdout);
      // iOS 26 UISwitch uses a 28pt intrinsic height and its thumb artwork
      // extends 2pt beyond the layout width. Preserve UIKit's native sizing.
      CGFloat minimumHeight = control == caseSwitch ? caseSwitch.intrinsicContentSize.height : 40;
      CGFloat edgeAllowance = control == caseSwitch ? 3 : 1;
      Check(rect.size.width > 0 && rect.size.height >= minimumHeight - 1 && rect.origin.x >= -edgeAllowance &&
          CGRectGetMaxX(rect) <= options.bounds.size.width + edgeAllowance,
          @"encoding and case controls fit the 400pt or 320pt content width");
    }
    for (UILabel *label in ViewsOfClass(options, UILabel.class)) {
      if (label.hidden || !label.text.length || label.bounds.size.width == 0) continue;
      CGSize natural = [label sizeThatFits:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX)];
      Check(label.bounds.size.height >= natural.height - 1, @"Str option labels fit their complete localized text");
    }
    CheckSearchHeaderFit(modifier, @"Str visible");
    types.selectedSegmentIndex = VMDataTypeInt32;
    [types sendActionsForControlEvents:UIControlEventValueChanged];
    [self.window layoutIfNeeded];
    Check(options.hidden && fabs(table.tableHeaderView.bounds.size.height - numericHeight) <= 1,
        @"switching back to numbers removes every Str-options row without a blank gap");
    CheckSearchHeaderFit(modifier, @"Str collapsed");
    types.selectedSegmentIndex = VMDataTypeString;
    [types sendActionsForControlEvents:UIControlEventValueChanged];
    UIScrollView *typeStrip = EnclosingScrollView(types);
    [typeStrip setContentOffset:CGPointMake(MAX(0, typeStrip.contentSize.width - typeStrip.bounds.size.width), 0) animated:NO];
    input.text = @"Straße 世界 😀";
    [input sendActionsForControlEvents:UIControlEventEditingChanged];
    // Native segmented-control selection springs continue after layout.
    Later(.55, ^{
    [self captureStringOptions:entry suffix:@"-ready"];
    encoding.selectedSegmentIndex = VMStringEncodingUTF16LE;
    [encoding sendActionsForControlEvents:UIControlEventValueChanged];
    caseSwitch.on = NO;
    [caseSwitch sendActionsForControlEvents:UIControlEventValueChanged];
    Check([NSUserDefaults.standardUserDefaults integerForKey:@"VMStringSearchEncoding"] == VMStringEncodingUTF16LE &&
        ![NSUserDefaults.standardUserDefaults boolForKey:@"VMStringSearchCaseSensitive"],
        @"user option changes save both search preferences");
    self.stringFixture = [VMStringOptionsFixture new];
    [modifier handleSearch];
    VMStringOptionsFixture *fixture = self.stringFixture;
    Check(fixture.scanCalls == 1 && !fixture.observedNext && fixture.observedEncoding == VMStringEncodingUTF16LE && !fixture.observedCaseSensitive,
        @"first Str search forwards the selected encoding and Unicode case mode");
    Check(!encoding.enabled && !caseSwitch.enabled && [[modifier valueForKey:@"isScanning"] boolValue],
        @"both options lock while the search callback is pending");
    [fixture completeScan];
    Later(1.35, ^{
      Check([[modifier valueForKey:@"isNextScan"] boolValue] && !encoding.enabled && !caseSwitch.enabled,
          @"completed string results retain locked options for consistent rescans");
      Check([((UILabel *)[modifier valueForKey:@"stringOptionsHint"]).text isEqual:
          [VMLocalization.shared localizedString:@"Search_Str_Reset_Hint"]],
          @"existing string results explain how to change their search options");
      Check(![(UIButton *)[modifier valueForKey:@"btnFilter"] isEnabled],
          @"numeric comparison filtering is disabled for string results");
      UITableViewCell *cell = [table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
      Check([cell.detailTextLabel.text isEqual:@"Straße 世界 😀"],
          @"UTF-16 search result decodes and displays the complete Unicode fixture");
      [self captureStringOptions:entry suffix:@"-results"];
      // Deliberate stale control values simulate a restored/shared session; the
      // next-search path must use the engine's saved result configuration.
      encoding.selectedSegmentIndex = VMStringEncodingUTF8;
      caseSwitch.on = YES;
      [modifier handleSearch];
      Check(fixture.scanCalls == 2 && fixture.observedNext &&
          fixture.observedEncoding == VMStringEncodingUTF16LE && !fixture.observedCaseSensitive,
          @"rescan preserves engine configuration despite stale control values");
      [fixture completeScan];
      Later(1.35, ^{ [self restoreStringOptionsTimeline:entry modifier:modifier]; });
    });
    });
  });
}
- (void)next {
  if (self.step >= self.pages.count) {
    printf("PASS: UI review completed (%lu scenarios, %lu screenshots)\n", (unsigned long)self.step, (unsigned long)reviewCaptureCount); fflush(stdout); exit(0);
  }
  NSDictionary *entry = self.pages[self.step];
  BOOL compact = [entry[@"compact"] boolValue] || [entry[@"name"] hasSuffix:@"-compact"];
  self.window.frame = [entry[@"name"] hasSuffix:@"-landscape"] ? CGRectMake(0,0,740,360) : compact ? CGRectMake(0,0,320,740) : UIScreen.mainScreen.bounds;
  if (entry[@"width"]) self.window.frame = CGRectMake(0, 0, [entry[@"width"] doubleValue], 800);
  if (entry[@"stringOptions"]) {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"VMStringSearchEncoding"];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"VMStringSearchCaseSensitive"];
    [VMMemoryEngine.shared clearSession];
    [VMMemoryEngine.shared clearMemoryTimeline];
    VMMemoryEngine.shared.stringEncoding = VMStringEncodingUTF8;
    VMMemoryEngine.shared.stringCaseSensitive = YES;
  }
  self.window.overrideUserInterfaceStyle = ![entry[@"liveThemeSwitch"] boolValue] &&
      ([entry[@"dark"] boolValue] || [entry[@"name"] hasSuffix:@"-dark"]) ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
  if ([entry[@"connected"] boolValue] || [entry[@"modal"] isEqual:@"rva"]) {
    if (VMMemoryEngine.shared.targetPid != getpid()) Check([VMMemoryEngine.shared attachToPid:getpid()], @"UI flows attach only to the fixture process");
    VMMemoryEngine.shared.currentProcessName = @"Vanson Demo";
    VMMemoryEngine.shared.currentBundleID = @"com.vanson.local.uireview";
    if ([entry[@"longBundleID"] boolValue]) {
      VMMemoryEngine.shared.currentBundleID = @"com.vanson.review.verylongapplicationidentifier.shareddevelopment.demonstration";
      [VMUIHelper cacheApplicationIcon:[UIImage imageNamed:@"AppIcon60x60@2x"] forBundleID:VMMemoryEngine.shared.currentBundleID];
    }
  }
  if (entry[@"tab"]) {
    self.window.rootViewController = self.root;
    self.root.selectedIndex = [entry[@"tab"] unsignedIntegerValue];
    UINavigationController *nav = (id)self.root.selectedViewController;
    UITraitCollection *traits = [UITraitCollection traitCollectionWithPreferredContentSizeCategory:[entry[@"large"] boolValue] ? UIContentSizeCategoryAccessibilityExtraLarge : UIContentSizeCategoryLarge];
    [self.root setOverrideTraitCollection:traits forChildViewController:nav];
  } else {
    UIViewController *page = [NSClassFromString(entry[@"class"]) new];
    Check(page != nil, [@"page exists: " stringByAppendingString:entry[@"class"]]);
    if ([page isKindOfClass:VMCardReviewController.class]) {
      ((VMCardReviewController *)page).variant = [entry[@"name"] componentsSeparatedByString:@"-"].firstObject;
      ((VMCardReviewController *)page).importedFixture = [entry[@"liveThemeSwitch"] boolValue];
    }
    if ([page isKindOfClass:VMScriptViewController.class]) {
      VMScriptModel *script = [VMScriptModel new];
      script.note = @"数值检查"; script.author = @"VansonMod"; script.bundleID = @"com.vanson.demo";
      if ([entry[@"modal"] isEqual:@"script-info"]) script.desc = @"检查当前搜索结果并输出日志";
      script.scriptContent = @"// 检查当前搜索结果\nconst results = vm.getResults(10);\nconsole.log(results);\n";
      ((VMScriptViewController *)page).scriptModel = script;
    }
    if ([page isKindOfClass:VMItemEditViewController.class]) {
      VMPointerChain *chain = [VMPointerChain new];
      chain.note = @"示例指针"; chain.author = @"VansonMod"; chain.moduleName = @"Demo";
      ((VMItemEditViewController *)page).model = chain;
    }
    uint64_t address = (uint64_t)(reviewMemory + 8192);
    memcpy(reviewMemory + 8192, "VansonMod UI Review", 20);
    if ([page isKindOfClass:VMMemoryBrowserViewController.class] || [page isKindOfClass:VMHexEditorViewController.class] ||
        [page isKindOfClass:VMSignatureSearchViewController.class] || [entry[@"name"] isEqual:@"inspector"]) {
      static BOOL fixtureAttached = NO;
      if (!fixtureAttached) {
        Check([VMMemoryEngine.shared attachToPid:getpid()], @"self-memory fixture attached");
        fixtureAttached = YES;
      }
      VMMemoryEngine.shared.currentProcessName = @"Vanson Demo";
      VMMemoryEngine.shared.currentBundleID = @"com.vanson.local.uireview";
    }
    if ([page isKindOfClass:VMMemoryBrowserViewController.class]) {
      ((VMMemoryBrowserViewController *)page).address = address;
      ((VMMemoryBrowserViewController *)page).type = VMDataTypeInt32;
    }
    if ([page isKindOfClass:VMHexEditorViewController.class]) ((VMHexEditorViewController *)page).address = address;
    if ([page isKindOfClass:VMSignatureSearchViewController.class]) ((VMSignatureSearchViewController *)page).initialAddress = address;
    if ([page isKindOfClass:VMHexRowEditorViewController.class]) {
      ((VMHexRowEditorViewController *)page).address = address;
      ((VMHexRowEditorViewController *)page).originalData = [NSData dataWithBytes:reviewMemory + 8192 length:16];
    }
    if ([page isKindOfClass:VMStringEditorViewController.class]) {
      VMStringMemorySession *session = [VMStringMemorySession new];
      session.targetIsValid = ^BOOL { return YES; };
      session.reader = ^NSData *(uint64_t start, NSUInteger length) {
        uint64_t first = (uint64_t)reviewMemory, end = first + sizeof(reviewMemory);
        if (start < first || start >= end) return nil;
        return [NSData dataWithBytes:(void *)start length:MIN(length, end - start)];
      };
      session.writer = ^BOOL(uint64_t start, NSData *bytes) { return NO; };
      ((VMStringEditorViewController *)page).session = session;
      ((VMStringEditorViewController *)page).initialAddress = address;
    }
    if ([page isKindOfClass:VMPointerVerifierViewController.class]) {
      VMPointerChain *chain = [VMPointerChain new];
      chain.moduleName = @"Demo"; chain.baseOffset = 0x100; chain.offsets = @[@0x20,@0x8];
      chain.note = @"示例指针"; chain.appName = @"Vanson Demo"; chain.bundleID = @"com.vanson.ui.fixture";
      VMDataSession *session = [VMDataSession sessionWithData:@[chain] bundleID:chain.bundleID dataType:@"pointer"];
      NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ui-review.vmvapt"];
      [[session toVerifierJSONData] writeToFile:path atomically:YES];
      ((VMPointerVerifierViewController *)page).filePath = path;
    }
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
    if ([entry[@"name"] isEqual:@"inspector"]) {
      [page loadViewIfNeeded];
      VMWatchHit *hit = [VMWatchHit new]; hit.pc = address; hit.address = address;
      hit.imageName = @"Demo"; hit.offset = 0x100; hit.newValue = 100; hit.slotIndex = 0;
      Later(.1, ^{ [(VMWatchpointViewController *)page showInspectorForHit:hit]; });
    }
    [VMUIHelper applyNavigationAppearance:nav];
    if ([entry[@"name"] hasSuffix:@"-large-type"])
      [nav setOverrideTraitCollection:[UITraitCollection traitCollectionWithPreferredContentSizeCategory:UIContentSizeCategoryAccessibilityExtraLarge] forChildViewController:page];
    self.window.rootViewController = nav;
  }
  [self.window layoutIfNeeded];
  UINavigationController *activeNav = [self.window.rootViewController isKindOfClass:UINavigationController.class]
      ? (id)self.window.rootViewController : (id)self.root.selectedViewController;
  UIViewController *activePage = activeNav.topViewController;
  // A filtered run can visit a tab for the first time here. Instantiate its real
  // controls before filling fixture fields or invoking an action on the page.
  [activePage loadViewIfNeeded];
  [self.window layoutIfNeeded];
  if ([activePage isKindOfClass:VMSettingsViewController.class]) {
    VMSettingsViewController *settings = (id)activePage;
    NSInteger group = [entry[@"settingsGroup"] integerValue];
    [settings selectSettingsGroup:group];
    VMUpdateManager.shared.checkState = entry[@"updateState"] ? (VMUpdateCheckState)[entry[@"updateState"] integerValue] : VMUpdateCheckStateIdle;
    [NSNotificationCenter.defaultCenter postNotificationName:kVMUpdateStateDidChangeNotification object:VMUpdateManager.shared];
    [self.window layoutIfNeeded];
  }
  if (entry[@"updateScenario"]) {
    Later(.1, ^{ [self runUpdateScenario:entry settings:(id)activePage]; });
    return;
  }
  if (entry[@"controlScroll"]) {
    [self runControlScrollScenario:entry modifier:(id)activePage];
    return;
  }
  if (entry[@"stringOptions"]) {
    [self runStringOptionsScenario:entry modifier:(id)activePage];
    return;
  }
  if ([entry[@"connected"] boolValue] && [activePage isKindOfClass:VMLockListViewController.class])
    [(VMLockListViewController *)activePage updateFooter];
  if ([entry[@"filterPanelOpen"] boolValue]) {
    UIView *panel = [activePage valueForKey:@"filterPanelView"];
    if (panel.hidden) [activePage performSelector:NSSelectorFromString(@"toggleFilterPanel")];
    [self.window layoutIfNeeded];
  }
  if (entry[@"zeroScenario"]) {
    // Start after the tab transition settles; callbacks alone must shrink its header.
    Later(.1, ^{ [self runSearchZeroScenario:entry[@"zeroScenario"] modifier:(id)activePage]; });
  }
  if ([entry[@"name"] isEqual:@"search-fuzzy-compact"]) {
    Later(.1, ^{
      VMModifierViewController *modifier = (id)activePage;
      UISegmentedControl *mode = [modifier valueForKey:@"searchModeSegment"];
      mode.selectedSegmentIndex = VMSearchModeFuzzy;
      [modifier modeChanged];
      Method method = class_getInstanceMethod(VMMemoryEngine.class, @selector(fastFuzzyInitWithCompletion:));
      IMP original = method_getImplementation(method);
      IMP stub = imp_implementationWithBlock(^(id object, void (^completion)(BOOL, NSString *, NSUInteger)) {
        completion(YES, @"", 4096);
      });
      method_setImplementation(method, stub);
      [modifier handleSearch];
      method_setImplementation(method, original);
      imp_removeBlock(stub);
    });
  }
  VMFormSheetViewController *reviewForm = nil;
  if ([entry[@"modal"] isEqual:@"pointer"]) {
    [(VMAppSelectViewController *)activePage showAddPointerAlertForBundleID:@"com.vanson.ui.fixture" appName:@"Vanson Demo"];
  } else if ([entry[@"modal"] isEqual:@"lock"]) {
    [(VMLockListViewController *)activePage addLock];
  } else if ([entry[@"modal"] isEqual:@"script-new"]) {
    [(VMLockListViewController *)activePage addNewScript];
  } else if ([entry[@"modal"] isEqual:@"script-info"]) {
    [(VMScriptViewController *)activePage editNoteAction];
  } else if ([entry[@"modal"] isEqual:@"rva"]) {
    VMModuleInfo *module = [VMModuleInfo new];
    module.name = @"Demo.framework";
    module.loadAddress = (uint64_t)reviewMemory;
    module.size = sizeof(reviewMemory);
    UITextField *offsetField = [activePage valueForKey:@"offsetField"];
    UITextField *hexField = [activePage valueForKey:@"hexField"];
    Check(offsetField != nil && hexField != nil, @"RVA fixture loads its input controls before configuring the save action");
    [activePage setValue:module forKey:@"selectedModule"];
    offsetField.text = @"0x2000";
    hexField.text = @"1F 20 03 D5";
    memcpy(reviewMemory + 8192, "VansonMod UI Review", 20);
    [(VMPatcherViewController *)activePage savePatchAction];
  }
  if (entry[@"modal"]) {
    UINavigationController *sheet = (id)activePage.presentedViewController;
    Check([sheet isKindOfClass:UINavigationController.class] && [sheet.topViewController isKindOfClass:VMFormSheetViewController.class],
        [@"native scrollable modal: " stringByAppendingString:entry[@"name"]]);
    reviewForm = (id)sheet.topViewController;
    NSArray<UITextField *> *fields = [reviewForm valueForKey:@"fields"];
    if ([entry[@"modal"] isEqual:@"pointer"]) {
      UITextView *chain = (id)ViewsOfClass(reviewForm.view, UITextView.class).firstObject;
      chain.text = @"[Demo.framework+0x100]\n+0x20+0x8+0x10+0x18+0x28";
      fields[0].text = @"示例指针链 · 多级偏移";
      fields[1].text = @"-12.5";
      fields[2].text = @"VansonMod";
      if ([entry[@"name"] containsString:@"invalid"]) {
        chain.text = @"[Demo.framework+0x100]invalid+0x20";
        Later(.35, ^{ [reviewForm submit]; });
      }
    } else if ([entry[@"modal"] isEqual:@"lock"]) {
      fields[0].text = [NSString stringWithFormat:@"0x%llX", (uint64_t)(reviewMemory + 256)];
      fields[1].text = @"100";
    }
  }
  UIEdgeInsets batchOriginalInset = UIEdgeInsetsZero;
  if ([entry[@"name"] isEqual:@"toolbox-batch-compact"])
    batchOriginalInset = ((UITableView *)[activePage valueForKey:@"tableView"]).contentInset;
  if ([entry[@"name"] isEqual:@"patch-manager-batch-compact"]) {
    [activePage performSelector:NSSelectorFromString(@"toggleViewMode")];
    [activePage performSelector:NSSelectorFromString(@"enterBatchMode")];
  } else if ([entry[@"name"] isEqual:@"toolbox-batch-compact"]) {
    [activePage performSelector:NSSelectorFromString(@"enterBatchMode")];
  }
  if ([entry[@"name"] isEqual:@"settings-footer-compact"] || entry[@"updateState"]) {
    UITableView *table = [activePage valueForKey:@"tableView"];
    [table layoutIfNeeded];
    CGFloat bottom = MAX(-table.adjustedContentInset.top, table.contentSize.height - table.bounds.size.height + table.adjustedContentInset.bottom);
    table.contentOffset = CGPointMake(0, bottom);
  }
  BOOL keyboardTest = [entry[@"name"] hasSuffix:@"-keyboard"];
  __block UIEdgeInsets originalKeyboardInset = UIEdgeInsetsZero;
  __block UIScrollView *keyboardScroll = nil;
  __block UIView *keyboardInput = nil;
  if (keyboardTest) {
    if (reviewForm) {
      keyboardScroll = [reviewForm valueForKey:@"scrollView"];
      keyboardInput = ((NSArray *)[reviewForm valueForKey:@"fields"]).lastObject;
    } else if ([activePage isKindOfClass:VMStringEditorViewController.class]) {
      keyboardInput = [activePage valueForKey:@"textView"];
    } else if ([activePage isKindOfClass:VMSettingsViewController.class]) {
      keyboardScroll = [activePage valueForKey:@"tableView"];
      [(UITableView *)keyboardScroll scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:5 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
      [keyboardScroll layoutIfNeeded];
      keyboardInput = [activePage valueForKey:@"toleranceField"];
    } else {
      keyboardScroll = [activePage valueForKey:@"tableView"];
      keyboardInput = [activePage valueForKey:@"fields"][@"note"];
    }
    originalKeyboardInset = keyboardScroll.contentInset;
    Later(reviewForm ? .4 : .1, ^{
      Check([keyboardInput becomeFirstResponder], [@"keyboard focus: " stringByAppendingString:entry[@"name"]]);
      // The explicit frame also covers hosts with a hardware keyboard connected.
      CGRect frame = CGRectMake(0, self.window.bounds.size.height - 340, self.window.bounds.size.width, 340);
      [NSNotificationCenter.defaultCenter postNotificationName:UIKeyboardWillChangeFrameNotification object:nil userInfo:@{
        UIKeyboardFrameEndUserInfoKey:[NSValue valueWithCGRect:frame], UIKeyboardAnimationDurationUserInfoKey:@0,
        UIKeyboardAnimationCurveUserInfoKey:@0}];
      [self.window layoutIfNeeded];
    });
  }
  if ([entry[@"liveThemeSwitch"] boolValue]) {
    Later(.45, ^{
      self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
      [self.window layoutIfNeeded];
    });
  }
  __block BOOL guideThemeVerified = NO;
  BOOL guidePage = [activePage isKindOfClass:VMScriptExampleViewController.class];
  if (guidePage) {
    Later(2.5, ^{
      WKWebView *web = [activePage valueForKey:@"webView"];
      [web evaluateJavaScript:@"({theme:document.documentElement.dataset.theme,text:document.body.innerText.length})"
          completionHandler:^(id result, NSError *error) {
        NSString *theme = self.window.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark ? @"dark" : @"light";
        guideThemeVerified = !error && [result isKindOfClass:NSDictionary.class] &&
            [result[@"theme"] isEqual:theme] && [result[@"text"] integerValue] > 100;
      }];
    });
  }
  Later(guidePage ? 4 : reviewForm ? 1.8 : entry[@"zeroScenario"] ? 1.7 : [entry[@"liveThemeSwitch"] boolValue] ? 1.6 : .8, ^{
    if (guidePage) Check(guideThemeVerified, @"script guide content follows the live native theme");
    if ([entry[@"liveThemeSwitch"] boolValue]) {
      Check(activePage.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark,
          @"existing page responds to a live dark theme change");
      if (reviewForm) Check(reviewForm.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark,
          @"presented form responds to a live dark theme change");
      if ([activePage isKindOfClass:VMCardReviewController.class]) {
        UITableViewCell *cell = ((UITableViewController *)activePage).tableView.visibleCells.firstObject;
        UIView *card = [cell valueForKey:@"cardContainer"];
        UIColor *border = [((VMCardReviewController *)activePage).variant isEqual:@"patch"] ? UIColor.systemGreenColor : UIColor.systemGray4Color;
        CGColorRef expected = [border resolvedColorWithTraitCollection:cell.traitCollection].CGColor;
        Check(cell && card.layer.borderColor && CGColorEqualToColor(card.layer.borderColor, expected),
            @"imported card border refreshes when the existing cell changes theme");
      }
    }
    if ([entry[@"name"] hasPrefix:@"applications"]) {
      UITableView *table = [activePage valueForKey:@"tableView"];
      UISegmentedControl *segments = [activePage valueForKey:@"segmentControl"];
      NSString *expected = [NSString stringWithFormat:@"%@ 2", [[VMLocalization shared] localizedString:@"Filter_Running"]];
      Check([[segments titleForSegmentAtIndex:0] isEqual:expected], @"running count is shown inside the filter segment");
      CGRect firstRow = [table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
      Check(CGRectGetMinY(firstRow) - CGRectGetMaxY(table.tableHeaderView.frame) <= 12,
          @"process results follow search without a redundant section gap");
    }
    if ([entry[@"connected"] boolValue] && [activePage isKindOfClass:VMModifierViewController.class]) {
      UIView *header = [activePage valueForKey:@"contextHeader"];
      Check(ContainsLabel(header, @"Vanson Demo") && ContainsLabel(header, [NSString stringWithFormat:@"PID %d", getpid()]),
          @"connected memory header identifies the process by name and PID");
      Check(ContainsLabel(header, VMMemoryEngine.shared.currentBundleID), @"connected memory header includes Bundle ID");
      UIImageView *icon = (id)ViewsOfClass(header, UIImageView.class).firstObject;
      Check(icon.image != nil && !icon.image.isSymbolImage, @"connected memory header displays the application icon");
    }
    if ([entry[@"connected"] boolValue] && [activePage isKindOfClass:VMLockListViewController.class]) {
      UITableView *table = [activePage valueForKey:@"tableView"];
      UIView *header = table.tableHeaderView;
      UIImageView *icon = (id)ViewsOfClass(header, UIImageView.class).firstObject;
      Check(ContainsLabel(header, @"Vanson Demo") && ContainsLabel(header, [NSString stringWithFormat:@"PID %d", getpid()]),
          @"toolbox uses the connected process name and PID");
      Check(ContainsLabel(header, VMMemoryEngine.shared.currentBundleID), @"toolbox process header includes Bundle ID");
      CGRect iconFrame = [icon convertRect:icon.bounds toView:header];
      Check(icon.image && !icon.image.isSymbolImage && CGRectGetMinX(iconFrame) >= 16,
          @"toolbox process icon aligns with the list content");
    }
    if ([entry[@"name"] isEqual:@"patch-connected"]) {
      UIImageView *icon = [activePage valueForKey:@"procIconView"];
      UILabel *pidLabel = [activePage valueForKey:@"procPIDLabel"];
      Check(icon.image && !icon.image.isSymbolImage && [pidLabel.text containsString:[@(getpid()) stringValue]],
          @"RVA connected process card displays its application icon and PID");
      UILabel *bundle = [activePage valueForKey:@"procBundleIDLabel"];
      Check(!bundle.hidden && [bundle.text isEqualToString:VMMemoryEngine.shared.currentBundleID],
          @"RVA process card includes the current Bundle ID");
    }
    if ([entry[@"longBundleID"] boolValue]) {
      UILabel *bundle = nil;
      for (UILabel *label in ViewsOfClass(activePage.view, UILabel.class))
        if ([label.text isEqualToString:VMMemoryEngine.shared.currentBundleID]) { bundle = label; break; }
      CGSize natural = [bundle sizeThatFits:CGSizeMake(bundle.bounds.size.width, CGFLOAT_MAX)];
      Check(bundle && bundle.bounds.size.width > 0 && bundle.bounds.size.height >= natural.height - 1,
          @"long Bundle ID is fully readable on a compact screen");
    }
    if (self.window.rootViewController == self.root) {
      UIView *brand = [self.root valueForKey:@"brandingFooter"];
      Check(fabs(activeNav.additionalSafeAreaInsets.bottom) < .1,
          @"brand overlay leaves the page native bottom safe area intact");
      if (!brand.hidden) {
        CGPoint center = [self.root.view convertPoint:brand.center toView:self.window];
        UIView *hit = [self.window hitTest:center withEvent:nil];
        Check(hit != brand && ![hit isDescendantOfView:brand], @"brand overlay allows touches to pass through");
      }
      if ([entry[@"name"] isEqual:@"toolbox-batch-compact"]) {
        UIView *toolbar = [activePage valueForKey:@"batchToolbar"];
        CGRect actions = [toolbar convertRect:toolbar.bounds toView:self.root.view];
        Check(brand.hidden || !CGRectIntersectsRect(brand.frame, actions),
            @"brand remains clear of visible batch actions");
      }
    }
    if ([entry[@"name"] isEqual:@"search-fuzzy-compact"]) {
      UIButton *reset = [activePage valueForKey:@"btnReset"];
      CGRect button = [reset convertRect:reset.bounds toView:self.window];
      Check(reset.enabled && !reset.hidden && reset.userInteractionEnabled &&
          CGRectContainsRect(self.window.bounds, button) && CGRectGetWidth(button) >= 44 &&
          CGRectGetMaxY(button) < CGRectGetMinY(self.root.tabBar.frame),
          @"fuzzy initialization leaves a visible and enabled reset action");
    }
    if (entry[@"zeroScenario"]) [self checkSearchZeroScenario:entry[@"zeroScenario"] modifier:(id)activePage];
    if ([activePage isKindOfClass:VMSettingsViewController.class])
      CheckSettingsGroup((id)activePage, [entry[@"settingsGroup"] integerValue]);
    if ([entry[@"name"] isEqual:@"settings-compact"]) {
      UITableView *table = [activePage valueForKey:@"tableView"];
      CGFloat rowTotal = 0;
      for (NSUInteger row = 0; row < 6; row++) rowTotal += [table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]].size.height;
      Check(table.indexPathsForVisibleRows.count >= 5 && rowTotal / 6.0 <= 80,
          @"compact settings keep search rows readable below the pinned categories");
      Check(table.tableHeaderView.bounds.size.height <= 1, @"settings begin with options without a duplicate autosave header");
    }
    if (reviewForm) {
      UIScrollView *formScroll = [reviewForm valueForKey:@"scrollView"];
      Check(formScroll.bounds.size.height > 100 && reviewForm.navigationItem.rightBarButtonItem != nil,
          @"modal keeps scrollable fields and a reachable submit action");
      if ([entry[@"modal"] hasPrefix:@"script-"]) {
        NSArray<UITextField *> *fields = [reviewForm valueForKey:@"fields"];
        NSString *(^localized)(NSString *) = ^NSString *(NSString *key) { return [[VMLocalization shared] localizedString:key]; };
        Check([fields.firstObject.accessibilityLabel isEqual:localized(@"Script_Name_Label")] &&
            [fields.firstObject.placeholder isEqual:localized(@"Script_Name_Placeholder")],
            @"script name has a semantic label and localized input hint");
        if ([entry[@"modal"] isEqual:@"script-new"]) {
          Check(fields.count == 2 && [fields[1].accessibilityLabel isEqual:@"作者"] && ContainsLabel(reviewForm.view, @"作者"),
              @"new script labels the author field as 作者");
          Check([fields[1].text isEqual:@"VansonMod"] && [fields[1].placeholder isEqual:localized(@"Placeholder_Author")],
              @"new script retains VansonMod as author while offering an input hint");
          Check(fields.firstObject.text.length == 0, @"new script name hint remains separate from its empty value");
        } else {
          UITextView *description = (id)ViewsOfClass(reviewForm.view, UITextView.class).firstObject;
          UILabel *hint = [description valueForKey:@"placeholderLabel"];
          NSString *placeholder = [description valueForKey:@"placeholder"];
          Check([description.accessibilityLabel isEqual:localized(@"Script_Desc_Label")] &&
              [placeholder isEqual:localized(@"Script_Desc_Placeholder")] && [hint.text isEqual:placeholder],
              @"script description has a semantic label and localized multiline hint");
          Check(description.text.length > 0 && hint.hidden, @"existing description hides its placeholder");
          description.text = @"";
          Check(!hint.hidden && description.text.length == 0, @"clearing description shows a hint without inserting it into text");
          description.selectedRange = NSMakeRange(0, 0);
          [description insertText:@"A"];
          Check(hint.hidden && [description.text isEqual:@"A"], @"typing hides the multiline hint");
          [description deleteBackward];
          Check(!hint.hidden && description.text.length == 0, @"deleting the last character restores the multiline hint");
          description.text = @"程序赋值";
          Check(hint.hidden && [description.text isEqual:@"程序赋值"], @"programmatic text assignment refreshes the hint");
          description.attributedText = [[NSAttributedString alloc] initWithString:@""];
          Check(!hint.hidden && description.text.length == 0, @"programmatic attributed text clearing restores the hint");
          [description layoutIfNeeded];
          Check(hint.bounds.size.width > 0 && hint.bounds.size.height > 0 && !hint.isAccessibilityElement,
              @"empty description displays a laid-out hint without a duplicate accessibility element");
        }
      }
      if ([entry[@"name"] containsString:@"invalid"]) {
        UITextView *chain = (id)ViewsOfClass(reviewForm.view, UITextView.class).firstObject;
        UILabel *error = [reviewForm valueForKey:@"errorLabel"];
        Check(reviewForm.navigationController.presentingViewController != nil && !error.hidden && error.text.length > 0 &&
            [chain.text isEqual:@"[Demo.framework+0x100]invalid+0x20"] && reviewForm.navigationItem.rightBarButtonItem.enabled,
            @"invalid pointer submission preserves the draft and allows correction");
      }
      if ([entry[@"modal"] isEqual:@"lock"]) {
        NSArray<UITextField *> *fields = [reviewForm valueForKey:@"fields"];
        UISegmentedControl *types = (id)ViewsOfClass(reviewForm.view, UISegmentedControl.class).firstObject;
        NSString *validValue = fields[1].text;
        fields[1].text = @"9223372036854775808";
        types.selectedSegmentIndex = 3;
        Check(reviewForm.submitHandler(reviewForm).length > 0, @"manual lock rejects overflowing Int64 values");
        fields[1].text = @"1e100";
        types.selectedSegmentIndex = 4;
        Check(reviewForm.submitHandler(reviewForm).length > 0, @"manual lock rejects values outside Float32 range");
        fields[1].text = validValue;
        types.selectedSegmentIndex = 2;
      }
    }
    if ([entry[@"name"] isEqual:@"toolbox-batch-compact"]) {
      UIToolbar *toolbar = [activePage valueForKey:@"batchToolbar"];
      CGRect bar = [toolbar convertRect:toolbar.bounds toView:self.root.view];
      Check(!toolbar.hidden && CGRectGetHeight(bar) >= 44 && CGRectGetMaxY(bar) <= CGRectGetMinY(self.root.tabBar.frame) - 4,
          @"batch actions remain visible above the tab bar");
      UITableView *table = [activePage valueForKey:@"tableView"];
      UIEdgeInsets inset = table.contentInset;
      [activePage performSelector:NSSelectorFromString(@"enterBatchMode")];
      Check(UIEdgeInsetsEqualToEdgeInsets(inset, table.contentInset), @"reentering batch mode keeps stable bottom inset");
    }
    if ([entry[@"name"] isEqual:@"search-compact"]) {
      UITableView *table = [activePage valueForKey:@"tableView"];
      for (UIView *view in table.tableFooterView.subviews) {
        if ([view isKindOfClass:UIButton.class]) {
          CGRect button = [view convertRect:view.bounds toView:self.root.view];
          Check(CGRectGetMaxY(button) <= CGRectGetMinY(self.root.tabBar.frame) - 4, @"compact search connect action clears tab bar");
        }
      }
    }
    if ([entry[@"name"] isEqual:@"settings-footer-compact"]) {
      UITableView *table = [activePage valueForKey:@"tableView"];
      UILabel *label = [activePage valueForKey:@"legalFooterLabel"];
      UIButton *disclaimer = [activePage valueForKey:@"disclaimerButton"];
      Check([label isDescendantOfView:table.tableFooterView] && [disclaimer isDescendantOfView:table.tableFooterView],
          @"settings footer contains the disclaimer action and legal copy");
      CGRect actionFrame = [disclaimer convertRect:disclaimer.bounds toView:self.window];
      Check(disclaimer.bounds.size.height >= 44 && CGRectGetMaxY(actionFrame) <= CGRectGetMinY(self.root.tabBar.frame) + 1,
          @"compact settings footer disclaimer remains reachable above the tab bar");
      CGSize natural = [label sizeThatFits:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX)];
      Check(label.bounds.size.height >= natural.height - 1, @"settings footer displays every line on compact width");
      NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
      UILabel *versionLabel = [activePage valueForKey:@"versionValueLabel"];
      Check([versionLabel.text hasPrefix:[NSString stringWithFormat:@"v%@ · ", version]], @"settings footer uses the current project version");
    }
    if (keyboardTest) {
      if ([activePage isKindOfClass:VMStringEditorViewController.class]) {
        Check(keyboardInput.bounds.size.height >= 120, @"string keyboard keeps at least 120pt of editing space");
        Check([[activePage valueForKey:@"contextTable"] isHidden], @"string context yields space while typing");
      } else {
        Check(keyboardScroll.contentInset.bottom > originalKeyboardInset.bottom + 100, @"form scroll inset avoids keyboard");
        CGRect field = [keyboardInput convertRect:keyboardInput.bounds toView:self.window];
        Check(CGRectGetMaxY(field) < self.window.bounds.size.height - 330, @"active form input remains above keyboard");
      }
    }
    CaptureReviewWindow(self.window, entry);
    if ([entry[@"filterPanelOpen"] boolValue]) [activePage performSelector:NSSelectorFromString(@"toggleFilterPanel")];
    if ([entry[@"name"] isEqual:@"patch-manager-batch-compact"]) {
      [activePage performSelector:NSSelectorFromString(@"exitBatchMode")];
      [activePage performSelector:NSSelectorFromString(@"toggleViewMode")];
    }
    if ([entry[@"name"] isEqual:@"toolbox-batch-compact"]) {
      [activePage performSelector:NSSelectorFromString(@"exitBatchMode")];
      UIToolbar *toolbar = [activePage valueForKey:@"batchToolbar"];
      UITableView *table = [activePage valueForKey:@"tableView"];
      Check(toolbar.hidden && UIEdgeInsetsEqualToEdgeInsets(batchOriginalInset, table.contentInset), @"leaving batch mode hides toolbar and restores inset");
    }
    if (keyboardTest) {
      [self.window endEditing:YES];
      [NSNotificationCenter.defaultCenter postNotificationName:UIKeyboardWillHideNotification object:nil userInfo:@{UIKeyboardAnimationDurationUserInfoKey:@0, UIKeyboardAnimationCurveUserInfoKey:@0}];
      Check(!keyboardScroll || UIEdgeInsetsEqualToEdgeInsets(originalKeyboardInset, keyboardScroll.contentInset), @"keyboard dismissal restores form insets");
    }
    dispatch_block_t advance = ^{ self.step++; [self next]; };
    if (entry[@"zeroScenario"]) {
      [self retrySearchAfterZero:(id)activePage completion:advance];
    } else if ([entry[@"name"] isEqual:@"search-fuzzy-compact"]) {
      [(VMModifierViewController *)activePage handleReset];
      Later(.1, ^{
        UISegmentedControl *modes = [activePage valueForKey:@"searchModeSegment"];
        Check([modes isEnabledForSegmentAtIndex:0] && [modes isEnabledForSegmentAtIndex:2] &&
            ![[activePage valueForKey:@"isNextScan"] boolValue], @"reset restores exact and group search after fuzzy initialization");
        advance();
      });
    } else if (reviewForm) {
      [self.window.rootViewController dismissViewControllerAnimated:NO completion:advance];
    } else {
      advance();
    }
  });
}
@end
int main(int argc, char **argv) {
  @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(UIReviewApp.class)); }
}
