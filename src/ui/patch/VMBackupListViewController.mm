#import "../patch/VMBackupListViewController.h"
#import "../../utils/helpers/VMShareHelper.h"
#import "../../utils/helpers/VMUIHelper.h"
#import "../../utils/managers/VMBackupManager.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <signal.h>
#include <sys/sysctl.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])
extern "C" int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
@interface VMBackupListViewController () <UIDocumentPickerDelegate>
@property(nonatomic, strong) NSMutableArray *backups;
@property(nonatomic, strong) NSMutableDictionary *folderMetadata;
@property(nonatomic, copy) NSString *viewingBundleID;
@end
@implementation VMBackupListViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  [VMUIHelper styleTableView:self.tableView];
  self.view.tintColor = [VMUIHelper accentColor];
  self.folderList = [NSMutableArray array];
  self.folderMetadata = [NSMutableDictionary dictionary];
  if (self.bid && self.bid.length > 0) {
    self.isFolderMode = NO;
    self.title = self.appName ?: self.bid;
  } else {
    self.isFolderMode = YES;
    self.title = TR(@"Backups_Global_Title");
  }
  self.navigationItem.leftBarButtonItem = nil;
  UIBarButtonItem *importBtn = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"square.and.arrow.down"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(importBackupAction)];
  importBtn.accessibilityLabel = TR(@"Act_Import");
  self.navigationItem.rightBarButtonItem = importBtn;
  [VMUIHelper addFixedFooterTo:self forTableView:self.tableView];
  [self loadData];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self checkInitialNavigation];
}

- (void)checkInitialNavigation {
  if (self.bid.length > 0) {
    self.viewingBundleID = self.bid;
    [self enterFileMode];
  } else if (!self.isFolderMode && self.viewingBundleID.length > 0) {
    [self enterFileMode];
  } else {
    [self enterFolderMode];
  }
}

#pragma mark - Data Loading
- (void)loadData {
  if (self.isFolderMode) {
    [self loadAllBackupFolders];
  } else {
    [self loadFilesForBid:self.bid];
  }
}

- (void)enterFolderMode {
  self.isFolderMode = YES;
  self.viewingBundleID = nil;
  self.tableView.backgroundView = nil;
  self.title = TR(@"Backups_Global_Title");
  self.navigationItem.leftBarButtonItem = nil; // 恢复系统返回按钮
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"square.and.arrow.down"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(importBackupAction)];
  [self loadAllBackupFolders];
}

- (void)enterFileMode {
  self.isFolderMode = NO;
  NSString *targetFolder = self.viewingBundleID;
  if (!targetFolder || targetFolder.length == 0) {
    targetFolder = self.appName;
  }
  self.title = (self.bid.length > 0 && self.appName.length > 0) ? self.appName : targetFolder;
  NSArray *list = [[VMBackupManager shared] getBackupsForApp:targetFolder];
  self.backups = [list mutableCopy];
  [self updateEmptyState];
  [self.tableView reloadData];

  // 如果是从 folder 列表进入的（非直接 push 进来的单 app 模式），显示返回按钮
  if (self.bid && self.bid.length > 0) {
    // 单 app 模式，保留系统返回按钮
    self.navigationItem.leftBarButtonItem = nil;
  } else {
    // 全局模式下从 folder 列表进入 file 列表，显示返回 folder 列表的按钮
    UIBarButtonItem *listBtn = [[UIBarButtonItem alloc]
        initWithImage:[UIImage systemImageNamed:@"list.bullet"]
                style:UIBarButtonItemStylePlain
               target:self
               action:@selector(backToFolderList)];
    self.navigationItem.leftBarButtonItem = listBtn;
  }
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithImage:[UIImage systemImageNamed:@"square.and.arrow.down"]
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(importBackupAction)];
}

- (void)backToFolderList {
  [self enterFolderMode];
}

- (void)loadAllBackupFolders {
  NSString *root = [VMBackupManager shared].myBackupFolder;
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
    NSUInteger fileCount = files.count;

    [self.folderList addObject:name];
    self.folderMetadata[name] = @{@"name" : name, @"count" : @(fileCount)};
  }

  [self.folderList
      sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
  [self updateEmptyState];
  [self.tableView reloadData];
}

- (void)loadFilesForBid:(NSString *)bid {
  self.backups = [[[VMBackupManager shared] getBackupsForApp:bid] mutableCopy];
  [self updateEmptyState];
  [self.tableView reloadData];

}

#pragma mark - Import Logic
- (void)importBackupAction {
  UIDocumentPickerViewController *documentPicker;
  if (@available(iOS 14.0, *)) {
    documentPicker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:@[ UTTypeFolder ]
                            asCopy:NO];
  } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    documentPicker = [[UIDocumentPickerViewController alloc]
        initWithDocumentTypes:@[ @"public.folder" ]
                       inMode:UIDocumentPickerModeOpen];
#pragma clang diagnostic pop
  }
  documentPicker.delegate = self;
  documentPicker.allowsMultipleSelection = NO;
  [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  if (urls.count == 0)
    return;
  NSURL *srcURL = urls.firstObject;
  BOOL accessing = [srcURL startAccessingSecurityScopedResource];

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Act_Restore_File")
                                          message:srcURL.lastPathComponent
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Btn_Confirm")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *_Nonnull action) {
                                 [self performImport:srcURL securityScoped:accessing];
                               }]];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Btn_Cancel")
                                 style:UIAlertActionStyleCancel
                               handler:^(UIAlertAction *_Nonnull action) {
                                 if (accessing)
                                   [srcURL stopAccessingSecurityScopedResource];
                               }]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)performImport:(NSURL *)srcURL securityScoped:(BOOL)securityScoped {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *folderName = srcURL.lastPathComponent;
  
  NSString *targetAppFolder = nil;
  if (self.isFolderMode) {
    
    NSString *possibleBid = folderName;
    NSRange underscoreRange = [folderName rangeOfString:@"_"];
    if (underscoreRange.location != NSNotFound) {
      possibleBid = [folderName substringToIndex:underscoreRange.location];
    }
    
    if ([possibleBid containsString:@"."]) {
      targetAppFolder = possibleBid;
    } else {
      
      targetAppFolder = folderName;
      
      NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
      [fmt setDateFormat:@"_MMddHHmm"];
      folderName = [folderName stringByAppendingString:[fmt stringFromDate:[NSDate date]]];
    }
  } else {
    
    targetAppFolder = self.viewingBundleID ?: self.bid ?: self.appName;
    if (!targetAppFolder || targetAppFolder.length == 0) {
      [self showToast:TR(@"Restore_Err_NoApp")];
      return;
    }
    
    if (![folderName containsString:@"_"]) {
      NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
      [fmt setDateFormat:@"_MMddHHmm"];
      folderName = [folderName stringByAppendingString:[fmt stringFromDate:[NSDate date]]];
    }
  }
  
  NSString *appBackupRoot = [[[VMBackupManager shared] myBackupFolder]
      stringByAppendingPathComponent:targetAppFolder];
  if (![fm fileExistsAtPath:appBackupRoot]) {
    [fm createDirectoryAtPath:appBackupRoot
        withIntermediateDirectories:YES
                         attributes:nil
                              error:nil];
  }
  NSString *destPath =
      [appBackupRoot stringByAppendingPathComponent:folderName];
  
  if ([fm fileExistsAtPath:destPath]) {
    NSString *baseName = folderName;
    int counter = 1;
    while ([fm fileExistsAtPath:destPath]) {
      folderName = [NSString stringWithFormat:@"%@_%d", baseName, counter++];
      destPath = [appBackupRoot stringByAppendingPathComponent:folderName];
    }
  }
  
  NSError *err;
  BOOL success = [fm copyItemAtURL:srcURL
                  toURL:[NSURL fileURLWithPath:destPath]
                  error:&err];
  
  if (securityScoped) {
    [srcURL stopAccessingSecurityScopedResource];
  }
  
  if (success) {
    [self showToast:TR(@"Alert_Success")];
    if (self.isFolderMode) {
      [self loadAllBackupFolders];
    } else {
      [self enterFileMode];
    }
  } else {
    [self showToast:[NSString stringWithFormat:TR(@"Err_Import_Failed"),
                                               err.localizedDescription]];
  }
}

#pragma mark - TableView DS & Action
- (NSInteger)tableView:(UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section {
  if (self.isFolderMode)
    return self.folderList.count;
  return self.backups.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.isFolderMode) {
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
    NSUInteger count = [meta[@"count"] unsignedIntegerValue];
    cell.textLabel.text = bid;
    cell.detailTextLabel.text =
        [NSString stringWithFormat:TR(@"Backup_Count_Fmt"), (unsigned long)count];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = [UIImage systemImageNamed:@"folder.fill"];
    cell.imageView.tintColor = [UIColor systemBlueColor];
    return cell;
  } else {
    static NSString *cid = @"backupCell";
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
    NSString *backupName = self.backups[indexPath.row];
    cell.textLabel.text = backupName;
    cell.imageView.image = [UIImage systemImageNamed:@"archivebox.fill"];
    cell.imageView.tintColor = [UIColor systemBlueColor];
    return cell;
  }
}

- (void)tableView:(UITableView *)tableView
    didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
  if (self.isFolderMode) {
    self.viewingBundleID = self.folderList[indexPath.row];
    [self enterFileMode];
  } else {
    if (!self.viewingBundleID || self.viewingBundleID.length == 0) {
      [self showToast:TR(@"Restore_Err_NoApp")];
      return;
    }
    NSString *backupName = self.backups[indexPath.row];
    NSString *msg = [NSString
        stringWithFormat:TR(@"Msg_Restore_Confirm_Fmt"), self.viewingBundleID];
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:TR(@"Confirm_Restore")
                         message:msg
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert
        addAction:[UIAlertAction actionWithTitle:TR(@"Restore_Backup")
                                           style:UIAlertActionStyleDestructive
                                         handler:^(UIAlertAction *action) {
                                           [self performRestore:backupName];
                                         }]];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
  }
}

- (void)performRestore:(NSString *)backupName {
  UIAlertController *loading = [UIAlertController
      alertControllerWithTitle:nil
                       message:[NSString
                                   stringWithFormat:@"%@\n", TR(@"Restoring")]
                preferredStyle:UIAlertControllerStyleAlert];
  UIActivityIndicatorView *spin = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
  spin.translatesAutoresizingMaskIntoConstraints = NO;
  [spin startAnimating];
  [loading.view addSubview:spin];
  [NSLayoutConstraint activateConstraints:@[
    [spin.centerXAnchor constraintEqualToAnchor:loading.view.centerXAnchor],
    [spin.centerYAnchor constraintEqualToAnchor:loading.view.centerYAnchor
                                       constant:15]
  ]];
  [self presentViewController:loading animated:YES completion:nil];

  dispatch_async(dispatch_get_global_queue(0, 0), ^{
    NSString *folderName = self.viewingBundleID;
    NSString *fullPath = [[[[VMBackupManager shared] myBackupFolder]
        stringByAppendingPathComponent:folderName]
        stringByAppendingPathComponent:backupName];
    BOOL success = [[VMBackupManager shared] restoreApp:self.viewingBundleID
                                             backupPath:fullPath];

    if (success) {
      [self killAppByBundleID:self.viewingBundleID];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      [loading
          dismissViewControllerAnimated:YES
                             completion:^{
                               [self showToast:success ? TR(@"Restore_Success")
                                                       : TR(@"Restore_Failed")];
                             }];
    });
  });
}

- (void)killAppByBundleID:(NSString *)targetBid {
  if (!targetBid || targetBid.length == 0)
    return;

  int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t size;
  if (sysctl(mib, 4, NULL, &size, NULL, 0) == -1)
    return;

  struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
  if (!procs)
    return;

  if (sysctl(mib, 4, procs, &size, NULL, 0) == -1) {
    free(procs);
    return;
  }

  int count = size / sizeof(struct kinfo_proc);
  for (int i = 0; i < count; i++) {
    pid_t pid = procs[i].kp_proc.p_pid;
    if (pid <= 0)
      continue;

    char pathBuffer[4096];
    bzero(pathBuffer, 4096);
    proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];

    if ([fullPath containsString:@".app/"]) {
      NSString *appPath = [fullPath stringByDeletingLastPathComponent];
      while (![appPath.pathExtension isEqualToString:@"app"] &&
             ![appPath isEqualToString:@"/"]) {
        appPath = [appPath stringByDeletingLastPathComponent];
      }

      if ([appPath.pathExtension isEqualToString:@"app"]) {
        NSString *plistPath =
            [appPath stringByAppendingPathComponent:@"Info.plist"];
        NSDictionary *info =
            [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if ([info[@"CFBundleIdentifier"] isEqualToString:targetBid]) {
          kill(pid, SIGKILL);
        }
      }
    }
  }
  free(procs);
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:
        (NSIndexPath *)indexPath {
  if (self.isFolderMode) {
    NSString *folderName = self.folderList[indexPath.row];

    UIContextualAction *del = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:TR(@"Act_Delete")
                          handler:^(UIContextualAction *action,
                                    UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            NSString *fullPath =
                                [[[VMBackupManager shared] myBackupFolder]
                                    stringByAppendingPathComponent:folderName];

                            [[NSFileManager defaultManager]
                                removeItemAtPath:fullPath
                                           error:nil];

                            [self.folderList removeObjectAtIndex:indexPath.row];
                            [self.folderMetadata removeObjectForKey:folderName];

                            [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                                             withRowAnimation:
                                                 UITableViewRowAnimationFade];

                            if (self.folderList.count == 0) {
                              [self updateEmptyState];
  [self.tableView reloadData];
                            }

                            completionHandler(YES);
                          }];
    del.title = TR(@"Act_Delete");

    return [UISwipeActionsConfiguration configurationWithActions:@[ del ]];
  }

  NSString *backupName = self.backups[indexPath.row];
  
  NSString *folderName = self.viewingBundleID ?: self.bid ?: self.appName;
  if (!folderName || folderName.length == 0) {
    return nil; 
  }

  UIContextualAction *del = [UIContextualAction
      contextualActionWithStyle:UIContextualActionStyleDestructive
                          title:TR(@"Act_Delete")
                        handler:^(UIContextualAction *action,
                                  UIView *sourceView,
                                  void (^completionHandler)(BOOL)) {
                          NSString *fullPath =
                              [[[[VMBackupManager shared] myBackupFolder]
                                  stringByAppendingPathComponent:folderName]
                                  stringByAppendingPathComponent:backupName];

                          [[VMBackupManager shared] deleteBackupPath:fullPath];

                          [self.backups removeObjectAtIndex:indexPath.row];

                          if (self.backups.count == 0) {
                            NSString *appFolder =
                                [[[VMBackupManager shared] myBackupFolder]
                                    stringByAppendingPathComponent:folderName];
                            NSError *err;
                            if ([[NSFileManager defaultManager]
                                    removeItemAtPath:appFolder
                                               error:&err]) {
                            }

                            [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                                             withRowAnimation:
                                                 UITableViewRowAnimationFade];

                            dispatch_after(
                                dispatch_time(DISPATCH_TIME_NOW,
                                              (int64_t)(0.3 * NSEC_PER_SEC)),
                                dispatch_get_main_queue(), ^{
                                  if (self.navigationController.viewControllers
                                          .count > 1) {
                                    [self.navigationController
                                        popViewControllerAnimated:YES];
                                  } else {
                                    [self backToFolderList];
                                  }
                                });
                          } else {
                            [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                                             withRowAnimation:
                                                 UITableViewRowAnimationFade];
                          }

                          completionHandler(YES);
                        }];
  del.title = TR(@"Act_Delete");

  UIContextualAction *share = [UIContextualAction
      contextualActionWithStyle:UIContextualActionStyleNormal
                          title:TR(@"Act_Export")
                        handler:^(UIContextualAction *action,
                                  UIView *sourceView,
                                  void (^completionHandler)(BOOL)) {
                          NSString *fullPath =
                              [[[[VMBackupManager shared] myBackupFolder]
                                  stringByAppendingPathComponent:folderName]
                                  stringByAppendingPathComponent:backupName];
                          NSURL *url = [NSURL fileURLWithPath:fullPath];

                          CGRect rectInTableView =
                              [tableView rectForRowAtIndexPath:indexPath];
                          CGRect rectInView =
                              [tableView convertRect:rectInTableView
                                              toView:self.view];

                          [VMShareHelper shareContent:url
                                   fromViewController:self
                                           sourceView:self.view
                                           sourceRect:rectInView];

                          completionHandler(YES);
                        }];
  share.backgroundColor = [UIColor systemBlueColor];
  share.title = TR(@"Act_Export");

  return [UISwipeActionsConfiguration configurationWithActions:@[ del, share ]];
}

- (void)showToast:(NSString *)msg {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:nil
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self presentViewController:alert animated:YES completion:nil];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
      });
}

- (void)updateEmptyState {
  NSUInteger count = self.isFolderMode ? self.folderList.count : self.backups.count;
  self.tableView.tableFooterView.hidden = count == 0;
  self.tableView.backgroundView = count == 0 ? [VMUIHelper emptyStateWithTitle:TR(@"Backups_Global_Title") message:TR(@"No_Backup_Found") symbol:@"archivebox"] : nil;
}

@end
