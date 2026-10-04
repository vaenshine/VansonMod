// Release screenshot fixtures. Imported only by the local UIKit review harness.
// These subclasses render the shipping controllers and cells with in-memory demo
// models; scanning, attachment, timers and persistence are disabled here.
#pragma once

#import "src/ui/pointer/VMPointerSearchViewController.h"
#import "src/ui/pointer/VMPointerVerifierViewController.h"
#import "src/ui/pointer/VMPointerLockCell.h"
#import "src/ui/main/VMLockListViewController.h"
#import "src/ui/patch/VMRVAManagerCell.h"
#import "src/utils/helpers/VMUIHelper.h"
#import "include/VMPointerChain.h"
#import "include/VMRVAPatch.h"
#import "include/VMLocalization.h"

static NSArray<VMPointerChain *> *VMReleaseDemoPointerChains(void) {
  NSMutableArray<VMPointerChain *> *chains = [NSMutableArray array];
  NSArray<NSString *> *titles = @[@"Training Count", @"Demo Energy", @"Scene Toggle", @"Move Speed", @"Progress Count", @"Demo Score"];
  NSArray<NSString *> *values = @[@"100", @"250", @"1", @"1.25", @"100", @"250"];
  for (NSUInteger index = 0; index < titles.count; index++) {
    VMPointerChain *chain = [VMPointerChain new];
    chain.moduleName = @"AtlasDemo";
    chain.baseOffset = 0x12A840 + index * 0x80;
    chain.offsets = @[@0x20, @(0x18 + index * 8), @0x10];
    chain.note = titles[index];
    chain.author = @"VansonMod";
    chain.bundleID = @"com.example.atlasdemo";
    chain.appName = @"Atlas Demo";
    chain.appVersion = @"1.0";
    chain.createdAt = 1791072000;
    chain.chainType = VMPointerChainTypeStatic;
    chain.runtimeValue = values[index];
    chain.isRuntimeValid = YES;
    chain.lockValue = values[index];
    chain.lockType = index == 3 ? VMDataTypeFloat : VMDataTypeInt32;
    chain.uiMode = index == 1 ? VMPointerUIModeSlider :
        (index == 2 ? VMPointerUIModeSwitch : VMPointerUIModeInput);
    chain.uiMin = 0;
    chain.uiMax = 500;
    chain.switchOnValue = @"1";
    chain.switchOffValue = @"0";
    chain.lockEnabled = index == 0;
    chain.cachedRuntimeAddress = 0x105A02410 + index * 0x100;
    [chains addObject:chain];
  }
  return chains;
}

static NSArray<VMRVAPatch *> *VMReleaseDemoRVAPatches(void) {
  NSMutableArray<VMRVAPatch *> *patches = [NSMutableArray array];
  NSArray<NSString *> *titles = @[@"Training Count · 100", @"Demo Energy · 250", @"Scene Visibility"];
  NSArray<NSString *> *patched = @[@"64 00 00 00", @"FA 00 00 00", @"01 00 00 00"];
  NSArray<NSString *> *original = @[@"32 00 00 00", @"64 00 00 00", @"00 00 00 00"];
  for (NSUInteger index = 0; index < titles.count; index++) {
    VMRVAPatch *patch = [VMRVAPatch new];
    patch.moduleName = @"AtlasDemo";
    patch.offset = 0x2C410 + index * 0x100;
    patch.patchHex = patched[index];
    patch.originalHex = original[index];
    patch.note = titles[index];
    patch.author = @"VansonMod";
    patch.bundleID = @"com.example.atlasdemo";
    patch.appName = @"Atlas Demo";
    patch.appVersion = @"1.0";
    patch.createdAt = 1791072000;
    patch.isOn = index == 0;
    [patches addObject:patch];
  }
  return patches;
}

@interface VMPointerSearchViewController (VMReleaseScreenshotMethods)
- (void)updateStatsLabel;
@end

@interface VMReleasePointerSearchPage : VMPointerSearchViewController
@end

@implementation VMReleasePointerSearchPage
- (void)viewDidLoad {
  [super viewDidLoad];
  ((UITextField *)[self valueForKey:@"moduleField"]).text = @"AtlasDemo";
  ((UITextField *)[self valueForKey:@"depthField"]).text = @"5";
  ((UITextField *)[self valueForKey:@"offsetField"]).text = @"2000";
  ((UITextField *)[self valueForKey:@"limitField"]).text = @"500000";
}
- (void)viewWillAppear:(BOOL)animated {
  [self updateStatsLabel];
  [(UITableView *)[self valueForKey:@"tableView"] reloadData];
}
- (void)viewWillDisappear:(BOOL)animated {}
- (void)updateStatsLabel {
  ((UILabel *)[self valueForKey:@"statsLabel"]).text =
      [NSString stringWithFormat:@"%@: 8", [[VMLocalization shared] localizedString:@"Mod_Results_Count"]];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 8;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"release-pointer-result"];
  if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"release-pointer-result"];
  uint64_t address = 0x10012A840 + indexPath.row * 0x80;
  cell.textLabel.text = [NSString stringWithFormat:@"0x%llX", address];
  NSString *format = [[VMLocalization shared] localizedString:@"Ptr_Result_Offset"];
  NSString *symbol = [NSString stringWithFormat:@"AtlasDemo + 0x%llX", address - 0x100000000];
  cell.detailTextLabel.text = [NSString stringWithFormat:format, (long long)(0x20 + indexPath.row * 8), symbol];
  cell.detailTextLabel.textColor = UIColor.systemGreenColor;
  return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {}
- (void)handleStartAction {}
- (void)directSaveStaticPointers {}
@end

@interface VMPointerVerifierViewController (VMReleaseScreenshotMethods)
- (void)updateDisplayList;
@end

@interface VMReleasePointerVerifierPage : VMPointerVerifierViewController
@end

@implementation VMReleasePointerVerifierPage
- (void)startAsyncLoad {
  NSMutableArray *chains = [VMReleaseDemoPointerChains() mutableCopy];
  for (VMPointerChain *chain in chains) chain.runtimeValue = @"100";
  [self setValue:chains forKey:@"allChains"];
  [self setValue:@"com.example.atlasdemo" forKey:@"fileBundleID"];
  [self setValue:@"Atlas Demo" forKey:@"fileAppName"];
  [self setValue:@YES forKey:@"hasVerifiedOnce"];
  ((UITextField *)[self valueForKey:@"inputField"]).text = @"100";
  [self updateDisplayList];
  [self updateStatusUI];
}
- (void)checkAndReconnectIfNeeded {}
- (void)checkProcessStatus { [self updateStatusUI]; }
- (BOOL)tryAutoAttach { return NO; }
- (void)updateStatusUI {
  UILabel *name = [self valueForKey:@"appNameLabel"];
  name.text = [NSString stringWithFormat:@"Atlas Demo - %@",
               [[VMLocalization shared] localizedString:@"Status_Connected"]];
  name.textColor = UIColor.labelColor;
  ((UILabel *)[self valueForKey:@"bundleIdLabel"]).text = @"com.example.atlasdemo";
  UIImageView *icon = [self valueForKey:@"statusIcon"];
  icon.image = [UIImage systemImageNamed:@"checkmark.circle.fill"];
  icon.tintColor = UIColor.systemGreenColor;
}
- (void)runVerification {}
- (void)manualSaveAction {}
- (void)openAppSelector {}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {}
@end

@interface VMLockListViewController (VMReleaseScreenshotMethods)
- (void)updateNavBar;
- (void)updateFooter;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

@interface VMReleasePointerLockerPage : VMLockListViewController
@property(nonatomic, copy) NSArray *releaseItems;
@property(nonatomic, assign) BOOL releaseContextCreated;
@end

@implementation VMReleasePointerLockerPage
- (NSArray *)currentDisplayData { return self.releaseItems ?: @[]; }
- (void)reloadFolderData {}
- (void)reloadFolderDataOrFileData {}
- (void)checkSmartNavigation {}
- (void)startGCDTimer {}
- (void)stopGCDTimer {}
- (void)scanAndProcessImports {}
- (void)refreshVisiblePointerValues {}
- (void)tabChanged {
  [self setValue:@NO forKey:@"isFolderMode"];
  [self setValue:@"com.example.atlasdemo" forKey:@"targetBundleID"];
  UITableView *table = [self valueForKey:@"tableView"];
  [table registerClass:VMPointerLockCell.class forCellReuseIdentifier:@"VMPointerLockCell"];
  [self updateNavBar];
  [self updateFooter];
  [table reloadData];
}
- (void)viewWillAppear:(BOOL)animated {
  [self.navigationController setToolbarHidden:YES animated:NO];
  [self tabChanged];
}
- (void)updateContextHeader {
  if (self.releaseContextCreated) return;
  UITableView *table = [self valueForKey:@"tableView"];
  if (!table) return;
  self.releaseContextCreated = YES;
  UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, table.bounds.size.width, 48)];
  UIView *process = [VMUIHelper processHeaderWithName:@"Atlas Demo" bundleID:@"com.example.atlasdemo" pid:4242];
  process.translatesAutoresizingMaskIntoConstraints = NO;
  [container addSubview:process];
  [NSLayoutConstraint activateConstraints:@[
    [process.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:16],
    [process.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-16],
    [process.topAnchor constraintEqualToAnchor:container.topAnchor],
    [process.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
  ]];
  table.tableHeaderView = container;
  [VMUIHelper sizeHeaderToFitTableView:table];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.currentTab == 3) {
    VMRVAManagerCell *cell = (VMRVAManagerCell *)[super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.delegate = nil;
    return cell;
  }
  VMPointerChain *chain = self.releaseItems[indexPath.row];
  VMPointerLockCell *cell = [tableView dequeueReusableCellWithIdentifier:@"VMPointerLockCell" forIndexPath:indexPath];
  cell.delegate = nil;
  NSString *address = [NSString stringWithFormat:@"0x%llX", chain.cachedRuntimeAddress];
  [cell configureWithChain:chain address:address val:chain.runtimeValue
                     type:chain.lockType == VMDataTypeFloat ? @"F32" : @"I32"];
  return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {}
- (void)importAction {}
@end

static UIViewController *VMReleasePointerPage(NSString *name) {
  if ([name isEqualToString:@"POINTER_ANALYSIS"]) {
    VMReleasePointerSearchPage *page = [VMReleasePointerSearchPage new];
    page.targetAddress = 0x105A02410;
    page.level = 1;
    return page;
  }
  if ([name isEqualToString:@"POINTER_VERIFY"]) return [VMReleasePointerVerifierPage new];
  if ([name isEqualToString:@"POINTER_LOCKER"] || [name isEqualToString:@"RVA_MANAGER"]) {
    VMReleasePointerLockerPage *page = [VMReleasePointerLockerPage new];
    page.defaultTabIndex = [name isEqualToString:@"RVA_MANAGER"] ? 3 : 2;
    if (page.defaultTabIndex == 3) page.releaseItems = VMReleaseDemoRVAPatches();
    else page.releaseItems = VMReleaseDemoPointerChains();
    return page;
  }
  return nil;
}
