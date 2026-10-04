#import "VMSavedPointersViewController.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../pointer/VMPointerSessionListViewController.h"
#import "include/VMDataSession.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerManager.h"

#define TR(key) ([[VMLocalization shared] localizedString:key])
@interface VMSavedPointersViewController () <UITableViewDelegate,
                                             UITableViewDataSource>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) NSMutableArray<NSString *> *folderList;
@property(nonatomic, strong) NSMutableDictionary *folderMetadata;
@property(nonatomic, assign) BOOL isFolderMode;
@property(nonatomic, copy) NSString *targetBundleID;
@property(nonatomic, assign) BOOL manuallyShowAllFolders;
@property(nonatomic, copy) NSString *lastAutoNavBundleID;
@end
@implementation VMSavedPointersViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = TR(@"Ptr_Manager_Title");
  self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
  self.folderList = [NSMutableArray array];
  self.folderMetadata = [NSMutableDictionary dictionary];
  self.tableView =
      [[UITableView alloc] initWithFrame:self.view.bounds
                                   style:UITableViewStyleInsetGrouped];
  self.tableView.delegate = self;
  self.tableView.dataSource = self;
  self.tableView.autoresizingMask =
      UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [VMUIHelper styleTableView:self.tableView];
  self.view.tintColor = [VMUIHelper accentColor];
  [self.view addSubview:self.tableView];
  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];
}

- (void)loadFolders {
  NSString *root = [VMPointerManager shared].verifierFolder;
  [self.folderList removeAllObjects];
  [self.folderMetadata removeAllObjects];

  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *contents = [fm contentsOfDirectoryAtPath:root error:nil];

  if (!contents) {
    [self updateEmptyState];
    [self.tableView reloadData];
    return;
  }

  for (NSString *name in contents) {
    if ([name hasPrefix:@"."])
      continue;

    NSString *fullPath = [root stringByAppendingPathComponent:name];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:fullPath isDirectory:&isDir] || !isDir)
      continue;

    NSArray *files = [fm contentsOfDirectoryAtPath:fullPath error:nil];
    NSUInteger fileCount = [[files filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH %@", @".vmvapt"]] count];
    if (fileCount == 0) continue;
    VMDataSession *session = nil;

    for (NSString *fileName in files) {
      if (!session && [fileName hasSuffix:@".vmvapt"]) {
        NSString *filePath = [fullPath stringByAppendingPathComponent:fileName];
        NSData *data = [NSData dataWithContentsOfFile:filePath];
        session = [VMDataSession fromVerifierData:data];
      }
    }

    [self.folderList addObject:name];

    if (session) {
      self.folderMetadata[name] = @{
        @"name" : session.appName ?: name,
        @"ver" : session.appVersion ?: @"",
        @"count" : @(fileCount)
      };
    } else {
      self.folderMetadata[name] =
          @{@"name" : name, @"ver" : @"", @"count" : @(fileCount)};
    }
  }

  [self.folderList
      sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  [self updateEmptyState];
  [self.tableView reloadData];
}

- (void)enterFolderMode {
  self.isFolderMode = YES;
  self.targetBundleID = nil;
  self.title = TR(@"Ptr_Manager_Title");
  self.navigationItem.rightBarButtonItem = nil;
  [self loadFolders];
}

- (void)enterFileMode {
  VMPointerSessionListViewController *vc =
      [[VMPointerSessionListViewController alloc] init];
  vc.bundleID = self.targetBundleID;
  [self.navigationController pushViewController:vc animated:NO];
  self.manuallyShowAllFolders = YES;
  [self loadFolders];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self checkInitialNavigation];
}

- (void)checkInitialNavigation {
  NSString *currentBid = [VMMemoryEngine shared].currentBundleID;
  if (currentBid && ![currentBid isEqualToString:self.lastAutoNavBundleID]) {
    self.manuallyShowAllFolders = NO;
    self.lastAutoNavBundleID = currentBid;
  }
  if (currentBid && currentBid.length > 0 && !self.manuallyShowAllFolders) {
    NSString *rootPath = [VMPointerManager shared].verifierFolder;
    NSString *path = [rootPath stringByAppendingPathComponent:currentBid];

    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path
                                             isDirectory:&isDir] &&
        isDir) {
      self.targetBundleID = currentBid;
      [self enterFileMode];
      return;
    }
  }
  [self enterFolderMode];
}

- (void)showAllFolders {
  self.manuallyShowAllFolders = YES;
  self.isFolderMode = YES;
  self.targetBundleID = nil;
  self.title = TR(@"Ptr_Manager_Title");
  self.navigationItem.rightBarButtonItem = nil;
  [self loadFolders];
}

#pragma mark - TableView
- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  return self.folderList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *cid = @"folder";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                  reuseIdentifier:cid];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.font = [VMUIHelper scaledFontOfSize:16 weight:UIFontWeightSemibold];
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
  }
  NSString *bid = self.folderList[indexPath.row];
  NSDictionary *meta = self.folderMetadata[bid];
  NSString *name = meta[@"name"];
  NSString *ver = meta[@"ver"];
  if (ver.length > 0)
    cell.textLabel.text = [NSString stringWithFormat:@"%@ - v%@", name, ver];
  else
    cell.textLabel.text = name;
  NSUInteger count = [meta[@"count"] unsignedIntegerValue];
  cell.detailTextLabel.text =
      [NSString stringWithFormat:@"%@ · %lu", bid, (unsigned long)count];
  cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
  cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
  cell.imageView.tintColor = [UIColor systemBlueColor];
  return cell;
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  NSString *bid = self.folderList[indexPath.row];
  VMPointerSessionListViewController *vc =
      [[VMPointerSessionListViewController alloc] init];
  vc.bundleID = bid;
  [self.navigationController pushViewController:vc animated:YES];
}

- (void)updateEmptyState {
  self.tableView.tableFooterView.hidden = self.folderList.count == 0;
  self.tableView.backgroundView = self.folderList.count == 0 ? [VMUIHelper emptyStateWithTitle:TR(@"Ptr_Manager_Title") message:TR(@"Ptr_Sessions_Empty") symbol:@"folder"] : nil;
}

@end
