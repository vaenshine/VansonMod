#import "./VMGlobalBackupViewController.h"
#import "../patch/VMBackupListViewController.h"
#import "../../utils/managers/VMBackupManager.h"
#import "include/VMLocalization.h"
#import "../../utils/helpers/VMUIHelper.h"
#define TR(key) ([[VMLocalization shared] localizedString:key])
@interface VMGlobalBackupViewController ()
@property (nonatomic, strong) NSMutableArray<NSString *> *backupFolders;
@end
@implementation VMGlobalBackupViewController
- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [VMUIHelper sizeHeaderToFitTableView:self.tableView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadBackupFolders];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = TR(@"Backups_Global_Title");

    [VMUIHelper styleTableView:self.tableView];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 88;
    self.navigationItem.rightBarButtonItem = nil;

    [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];

    [self loadBackupFolders];
}

- (void)loadBackupFolders {
    NSString *rootPath = [[VMBackupManager shared] myBackupFolder];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSError *err;
    NSArray *contents = [fm contentsOfDirectoryAtPath:rootPath error:&err];
    if (!contents) contents = @[];
    
    NSMutableArray *dirs = [NSMutableArray array];
    for (NSString *name in contents) {
        if ([name hasPrefix:@"."]) continue; 
        
        NSString *fullPath = [rootPath stringByAppendingPathComponent:name];
        BOOL isDir = NO;
        if ([fm fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            [dirs addObject:name];
        }
    }
    
    [dirs sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    self.backupFolders = dirs;
    [self.tableView reloadData];
    
    self.tableView.backgroundView = self.backupFolders.count ? nil :
        [VMUIHelper emptyStateWithTitle:TR(@"Backups_Global_Title") message:TR(@"Backups_Empty") symbol:@"externaldrive"];

}

- (NSString *)formatAppInfoForFolder:(NSString *)folderName {
    NSString *bid = folderName;
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id proxy = [NSClassFromString(@"LSApplicationProxy") performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:") withObject:bid];
    
    if (proxy) {
        NSString *name = [proxy performSelector:NSSelectorFromString(@"localizedName")];
        NSString *ver = [proxy performSelector:NSSelectorFromString(@"shortVersionString")];
        if (!name) name = bid;
        if (!ver) ver = @"?";
        
        return [NSString stringWithFormat:@"%@ - v%@\n%@", name, ver, bid];
    }
    #pragma clang diagnostic pop
    
    return bid;
}

#pragma mark - TableView
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.backupFolders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"backFolder";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *folderName = self.backupFolders[indexPath.row];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.adjustsFontForContentSizeCategory = YES;
    cell.textLabel.text = [self formatAppInfoForFolder:folderName];
    cell.textLabel.font = [VMUIHelper scaledFontOfSize:15 weight:UIFontWeightMedium];
    cell.imageView.image = [UIImage systemImageNamed:@"folder"];
    cell.imageView.tintColor = [VMUIHelper accentColor];
    
    NSString *path = [[[VMBackupManager shared] myBackupFolder] stringByAppendingPathComponent:folderName];
    NSArray *subs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"NOT (self BEGINSWITH '.')"];
    subs = [subs filteredArrayUsingPredicate:pred];
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)subs.count];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *folderName = self.backupFolders[indexPath.row];
    
    NSString *installedPath = [[VMBackupManager shared] getDataPathForBundleID:folderName];
    if (!installedPath) {
    }
    
    VMBackupListViewController *vc = [[VMBackupListViewController alloc] init];
    vc.appName = folderName; 
    vc.bid = folderName;     
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.row >= self.backupFolders.count) return;
    NSString *folder = self.backupFolders[indexPath.row];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:TR(@"Act_Delete")
        message:[self formatAppInfoForFolder:folder] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Delete") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *path = [[[VMBackupManager shared] myBackupFolder] stringByAppendingPathComponent:folder];
        NSError *error = nil;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error]) {
            UIAlertController *failure = [UIAlertController alertControllerWithTitle:TR(@"Alert_Fail")
                message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [failure addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK") style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:failure animated:YES completion:nil];
        }
        [self loadBackupFolders];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
