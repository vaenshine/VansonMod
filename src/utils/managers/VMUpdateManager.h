#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define kVMUpdateAvailableNotification @"VMUpdateAvailableNotification"
#define kVMUpdateStateDidChangeNotification @"VMUpdateStateDidChangeNotification"

typedef NS_ENUM(NSInteger, VMUpdateCheckState) {
  VMUpdateCheckStateIdle,
  VMUpdateCheckStateChecking,
  VMUpdateCheckStateCurrent,
  VMUpdateCheckStateAvailable,
  VMUpdateCheckStateFailed
};

typedef NS_ENUM(NSInteger, VMUpdateInstallKind) {
  VMUpdateInstallKindUnknown,
  VMUpdateInstallKindTrollStore,
  VMUpdateInstallKindPackageManager
};

@interface VMUpdateManager : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) BOOL hasNewVersion;
@property (nonatomic, assign) VMUpdateCheckState checkState;
@property (nonatomic, copy) NSString *latestVersionStr;
@property (nonatomic, copy) NSString *releaseNotes;
@property (nonatomic, copy) NSString *downloadURL;
@property (nonatomic, copy) NSString *tipaDownloadURL;

- (VMUpdateInstallKind)installationKind;

- (void)performAutoCheck;

- (void)checkForUpdateManual:(BOOL)manual completion:(void(^)(void))completion;

- (void)showUpdateAlertFromViewController:(UIViewController *)vc;

@end
