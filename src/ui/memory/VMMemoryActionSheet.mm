#import "../main/VMLockListViewController.h"
#import "../main/VMModifierViewController.h"
#import "../memory/VMHexEditorViewController.h"
#import "../memory/VMMemoryBrowserViewController.h"
#import "../memory/VMSignatureSearchViewController.h"
#import "../memory/VMWatchpointViewController.h"
#import "../pointer/VMPointerLockCell.h"
#import "../pointer/VMPointerSearchViewController.h"
#import "../../core/VMDebugEngine.h"
#import "include/VMFavoriteManager.h"
#import "include/VMLocalization.h"
#import "include/VMLockEngine.h"
#import "include/VMMemoryEngine.h"
#import "include/VMPointerChain.h"
#import <objc/message.h>
#import "VMStringEditorViewController.h"
#define TR(key) ([[VMLocalization shared] localizedString:key])
@interface VMMemoryActionSheet : NSObject
+ (NSUInteger)writeSizeForType:(VMDataType)type
                       oldValue:(NSString *)oldValue
                       newValue:(NSString *)newValue;
@end

@implementation VMMemoryActionSheet


+ (UIViewController *)getTopViewController {
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

  while (true) {
    if (top.presentedViewController) {
      if (top.presentedViewController.isBeingDismissed) {
        break;
      }
      top = top.presentedViewController;
    } else if ([top isKindOfClass:[UINavigationController class]]) {
      top = [(UINavigationController *)top visibleViewController];
    } else if ([top isKindOfClass:[UITabBarController class]]) {
      top = [(UITabBarController *)top selectedViewController];
    } else {
      break;
    }
  }
  return top;
}

+ (void)safePresentAlert:(UIViewController *)alert
                    from:(UIViewController *)baseVC {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *top = baseVC;
    while (top.presentedViewController) {
      if (top.presentedViewController.isBeingDismissed) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
              [self safePresentAlert:alert from:baseVC];
            });
        return;
      }
      top = top.presentedViewController;
    }

    [top presentViewController:alert animated:YES completion:nil];
  });
}

+ (void)showActionSheetForAddress:(uint64_t)addr
                            value:(NSString *)valStr
                         dataType:(VMDataType)type
               fromViewController:(UIViewController *)vc
                       sourceView:(UIView *)sourceView
                       sourceRect:(CGRect)sourceRect
                        extraItem:(NSMutableDictionary *)item {
  BOOL isLockListVC = [vc isKindOfClass:[VMLockListViewController class]];
  BOOL isBrowserVC = [vc isKindOfClass:[VMMemoryBrowserViewController class]];
  BOOL isHexVC = [vc isKindOfClass:[VMHexEditorViewController class]];
  NSInteger currentTab = -1;
  if (isLockListVC)
    currentTab = [(VMLockListViewController *)vc currentTab];
  NSString *title = [NSString stringWithFormat:@"0x%llX", addr];
  NSString *symbolInfo = [[VMMemoryEngine shared] symbolicateAddress:addr];
  NSString *displayVal =
      (valStr.length > 50)
          ? [[valStr substringToIndex:50] stringByAppendingString:@"..."]
          : valStr;
  NSString *finalMsg =
      symbolInfo
          ? [NSString stringWithFormat:@"%@\n\n%@", symbolInfo, displayVal]
          : displayVal;
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:title
                       message:finalMsg
                preferredStyle:UIAlertControllerStyleActionSheet];
  if (item) {
    [alert
        addAction:
            [UIAlertAction
                actionWithTitle:TR(@"Ptr_Action_Edit_Note")
                          style:UIAlertActionStyleDefault
                        handler:^(UIAlertAction *a) {
                          UIAlertController *noteAlert = [UIAlertController
                              alertControllerWithTitle:
                                  TR(@"Ptr_Action_Edit_Note")
                                               message:nil
                                        preferredStyle:
                                            UIAlertControllerStyleAlert];
                          [noteAlert addTextFieldWithConfigurationHandler:^(
                                         UITextField *tf) {
                            tf.text = item[@"note"];
                          }];
                          [noteAlert
                              addAction:
                                  [UIAlertAction
                                      actionWithTitle:TR(@"Btn_Confirm")
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action) {
                                                item[@"note"] =
                                                    noteAlert.textFields
                                                        .firstObject.text;
                                                if ([vc isKindOfClass:
                                                            [VMLockListViewController
                                                                class]]) {
                                                  
                                                  NSString *bid =
                                                      [[VMMemoryEngine shared]
                                                          currentBundleID];
                                                  [[VMFavoriteManager shared]
                                                      removeFavorite:item
                                                              forApp:bid];
                                                  [[VMFavoriteManager shared]
                                                      addFavorite:item
                                                           forApp:bid];

                                                  if ([vc respondsToSelector:
                                                              @selector
                                                          (tableView)]) {
                                                    [[(UITableViewController *)
                                                            vc tableView]
                                                        reloadData];
                                                  }
                                                }
                                              }]];
                          [noteAlert
                              addAction:
                                  [UIAlertAction
                                      actionWithTitle:TR(@"Btn_Cancel")
                                                style:UIAlertActionStyleCancel
                                              handler:nil]];
                          [self safePresentAlert:noteAlert from:vc];
                        }]];
  }
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Menu_Modify")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self showModifyAlert:addr
                                                              val:valStr
                                                             type:type
                                                             inVC:vc];
                                          }]];

  VMMemoryWriteUndoItem *undoItem =
      [[VMMemoryEngine shared] lastManualWriteUndoForAddress:addr type:type];
  if (undoItem) {
    NSString *undoTitle = [NSString
        stringWithFormat:@"%@: %@", TR(@"Undo_Last_Modify"),
                         undoItem.oldValue ?: @""];
    [alert addAction:[UIAlertAction
                         actionWithTitle:undoTitle
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                   BOOL ok = [[VMMemoryEngine shared]
                                       undoLastManualWriteForAddress:addr
                                                                type:type];
                                   [self showToast:ok ? TR(@"Undo_Success")
                                                      : TR(@"Undo_Failed")
                                              inVC:vc];
                                   if (ok &&
                                       [vc respondsToSelector:@selector
                                           (doRefreshValues)]) {
                                     [vc performSelector:@selector(doRefreshValues)];
                                   }
                                 }]];
  }

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Tab_Ptr_Analysis")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self launchPointerSearchFrom:vc
                                                            targetAddress:addr];
                                          }]];

  if ([VMDebugEngine isAvailable]) {
    [alert addAction:[UIAlertAction
                         actionWithTitle:TR(@"WP_ActionSheet_Title")
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                   dispatch_after(
                                       dispatch_time(DISPATCH_TIME_NOW,
                                                     (int64_t)(0.2 * NSEC_PER_SEC)),
                                       dispatch_get_main_queue(), ^{
                                         VMWatchpointViewController *wpVC =
                                             [[VMWatchpointViewController alloc] init];
                                         wpVC.initialAddress = addr;
                                         [vc.navigationController
                                             pushViewController:wpVC
                                                       animated:YES];
                                       });
                                 }]];
  }

  if (isLockListVC && currentTab == 2 && item) {
    VMPointerChain *chain = (VMPointerChain *)item; 

    if (!chain.isImported) {

      NSString *modeTitle = (chain.uiMode == VMPointerUIModeSlider)
                                ? TR(@"Mode_Switch_Card")
                                : TR(@"Mode_Switch_Slider");
      [alert addAction:[UIAlertAction
                           actionWithTitle:modeTitle
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *_Nonnull action) {
                                     [self handleSliderSwitchForChain:chain
                                                               fromVC:vc];
                                   }]];

      [alert addAction:[UIAlertAction
                           actionWithTitle:TR(@"Ptr_Action_Copy_Offset")
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *_Nonnull action) {
                                     [self showOffsetCalculatorForBase:addr
                                                                  inVC:vc];
                                   }]];
    }
  }

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Tab_Sig_Analysis")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 VMSignatureSearchViewController *sigVC =
                                     [[VMSignatureSearchViewController alloc]
                                         init];
                                 sigVC.initialAddress = addr;
                                 sigVC.targetType = type;
                                 [vc.navigationController
                                     pushViewController:sigVC
                                               animated:YES];
                               }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Act_Calc_Offset")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *a) {
                                            [self
                                                showOffsetCalculatorForBase:addr
                                                                       inVC:vc];
                                          }]];

  if (!isBrowserVC) {
    if (type == VMDataTypeString) {
      [alert addAction:[UIAlertAction
                           actionWithTitle:TR(@"Browser_Str_Browse")
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *a) {
                                     dispatch_after(
                                         dispatch_time(
                                             DISPATCH_TIME_NOW,
                                             (int64_t)(0.2 * NSEC_PER_SEC)),
                                         dispatch_get_main_queue(), ^{
                                           VMMemoryBrowserViewController *browser =
                                               [VMMemoryBrowserViewController new];
                                           browser.address = addr;
                                           browser.type = VMDataTypeString;
                                           [vc.navigationController pushViewController:browser animated:YES];
                                         });
                                   }]];
    } else {
      [alert addAction:[UIAlertAction
                           actionWithTitle:TR(@"Mod_Menu_Value")
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *a) {
                                     dispatch_after(
                                         dispatch_time(
                                             DISPATCH_TIME_NOW,
                                             (int64_t)(0.2 * NSEC_PER_SEC)),
                                         dispatch_get_main_queue(), ^{
                                           [self finalJumpTo:addr inVC:vc];
                                         });
                                   }]];
    }
  }

  if (!isHexVC) {
    [alert addAction:[UIAlertAction
                         actionWithTitle:TR(@"Mod_Menu_Hex")
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction *a) {
                                   dispatch_after(
                                       dispatch_time(
                                           DISPATCH_TIME_NOW,
                                           (int64_t)(0.2 * NSEC_PER_SEC)),
                                       dispatch_get_main_queue(), ^{
                                         VMHexEditorViewController *hex =
                                             [VMHexEditorViewController new];
                                         hex.address = addr;
                                         [vc.navigationController
                                             pushViewController:hex
                                                       animated:YES];
                                       });
                                   [[NSNotificationCenter defaultCenter]
                                       postNotificationName:@"VM_DidViewHex"
                                                     object:@(addr)];
                                 }]];
  }

  if (!isLockListVC || currentTab != 0) {
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Menu_Lock")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
                                              [self showAddToLockAlert:addr
                                                                 value:valStr
                                                                  type:type
                                                                  inVC:vc];
                                            }]];
  }

  if (!isLockListVC || currentTab != 2) {
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Mod_Menu_Fav")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) {
                                              [self showAddToFavAlert:addr
                                                                 type:type
                                                                 inVC:vc];
                                            }]];
  }

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Pop_Copy_Addr")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 [[UIPasteboard generalPasteboard]
                                     setString:[NSString
                                                   stringWithFormat:@"0x%llX",
                                                                    addr]];
                                 [self showToast:TR(@"Msg_Addr_Copied")
                                            inVC:vc];
                               }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    alert.popoverPresentationController.sourceView = sourceView;
    alert.popoverPresentationController.sourceRect = sourceRect;
  }

  [vc presentViewController:alert animated:YES completion:nil];
}

+ (void)showModifyAlert:(uint64_t)address
                    val:(NSString *)val
                   type:(VMDataType)type
                   inVC:(UIViewController *)vc {

  [vc.view endEditing:YES];

  if (type == VMDataTypeString) {
    [self showStringModifyAlert:address val:val inVC:vc];
    return;
  }

  NSString *msg =
      [NSString stringWithFormat:TR(@"Alert_Edit_Addr_Msg"), address];
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Alert_Edit_Val")
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.text = val;
    if (type != VMDataTypeString)
      tf.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
  }];

  [alert
      addAction:[UIAlertAction
                    actionWithTitle:TR(@"Btn_Confirm")
                              style:UIAlertActionStyleDestructive
                            handler:^(UIAlertAction *a) {
                              NSString *newVal =
                                  alert.textFields.firstObject.text;
                              NSString *oldVal =
                                  [[VMMemoryEngine shared] readAddress:address
                                                                  type:type];
                              NSUInteger oldSize =
                                  [self writeSizeForType:type
                                                oldValue:oldVal
                                                newValue:newVal];
                              NSData *oldData =
                                  [[VMMemoryEngine shared] readRawMemory:address
                                                                  length:oldSize];
                              [[VMMemoryEngine shared]
                                  rememberManualWriteUndoAtAddress:address
                                                              type:type
                                                          oldValue:oldVal
                                                           oldData:oldData
                                                          newValue:newVal];

                              [[VMMemoryEngine shared] writeAddress:address
                                                              value:newVal
                                                               type:type];

                              [self showToast:TR(@"Msg_Mod_Success") inVC:vc];

                              if ([vc respondsToSelector:@selector
                                      (doRefreshValues)]) {
                                [vc performSelector:@selector(doRefreshValues)];
                              }
                            }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [self safePresentAlert:alert from:vc];
}

+ (void)showStringModifyAlert:(uint64_t)address
                          val:(NSString *)val
                         inVC:(UIViewController *)vc {
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  pid_t pid = engine.targetPid;
  mach_port_t task = engine.targetTask;
  VMStringMemorySession *session = [VMStringMemorySession new];
  session.targetIsValid = ^BOOL {
    return pid > 0 && task != MACH_PORT_NULL &&
           engine.targetPid == pid && engine.targetTask == task;
  };
  session.reader = ^NSData *(uint64_t addr, NSUInteger length) {
    if (engine.targetPid != pid || engine.targetTask != task) return nil;
    return [engine readRawMemory:addr length:length];
  };
  session.writer = ^BOOL(uint64_t addr, NSData *data) {
    if (engine.targetPid != pid || engine.targetTask != task) return NO;
    BOOL ok = [engine writeRawData:data toAddress:addr];
    if (ok) {
      const uint8_t *bytes = (const uint8_t *)data.bytes;
      NSUInteger length = 0;
      while (length < data.length && bytes[length] != 0) length++;
      NSString *value = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
      if (value) {
        for (NSMutableDictionary *entry in engine.lockedItems) {
          if ([entry[@"addr"] unsignedLongLongValue] == addr &&
              [entry[@"type"] integerValue] == VMDataTypeString) entry[@"val"] = value;
        }
      }
    }
    return ok;
  };
  session.didWrite = ^(uint64_t addr, NSData *before, NSData *after) {
    [engine rememberManualWriteUndoAtAddress:addr type:VMDataTypeString
        oldValue:[VMStringMemorySession escapedTextForData:before]
        oldData:before newValue:[VMStringMemorySession escapedTextForData:after]];
  };
  VMStringEditorViewController *editor = [VMStringEditorViewController new];
  editor.session = session;
  editor.initialAddress = address;
  __weak __typeof(vc) weakVC = vc;
  editor.didChangeMemory = ^{
    if ([weakVC respondsToSelector:@selector(doRefreshValues)])
      [weakVC performSelector:@selector(doRefreshValues)];
  };
  UINavigationController *navigation =
      [[UINavigationController alloc] initWithRootViewController:editor];
  navigation.modalPresentationStyle = UIModalPresentationFullScreen;
  [self safePresentAlert:navigation from:vc];
}

+ (NSUInteger)writeSizeForType:(VMDataType)type
                       oldValue:(NSString *)oldValue
                       newValue:(NSString *)newValue {
  switch (type) {
    case VMDataTypeInt8:
    case VMDataTypeUInt8:
      return 1;
    case VMDataTypeInt16:
    case VMDataTypeUInt16:
      return 2;
    case VMDataTypeInt64:
    case VMDataTypeUInt64:
    case VMDataTypeDouble:
      return 8;
    case VMDataTypeString: {
      NSUInteger oldLen = [oldValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      NSUInteger newLen = [newValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      return MAX((NSUInteger)1, MAX(oldLen, newLen));
    }
    case VMDataTypeInt32:
    case VMDataTypeUInt32:
    case VMDataTypeFloat:
    default:
      return 4;
  }
}

+ (void)showOffsetCalculatorForBase:(uint64_t)baseAddr
                               inVC:(UIViewController *)vc {
  [vc.view endEditing:YES];

  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:TR(@"Offset_Title")
                       message:[NSString
                                   stringWithFormat:
                                       TR(@"Offset_Calc_Origin_Msg"), baseAddr]
                preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = @"+8, -16, 0x100, 0x1A2B3C4D";
    tf.keyboardType = UIKeyboardTypeASCIICapable;
    tf.returnKeyType = UIReturnKeyDone;
    tf.enablesReturnKeyAutomatically = YES;
  }];

  [alert
      addAction:
          [UIAlertAction
              actionWithTitle:TR(@"Btn_Confirm")
                        style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction *a) {
                        NSString *input =
                            [alert.textFields.firstObject.text
                                stringByTrimmingCharactersInSet:
                                    [NSCharacterSet
                                        whitespaceAndNewlineCharacterSet]];
                        if (input.length == 0)
                          return;

                        uint64_t targetAddr = 0;
                        int64_t offset = 0;
                        
                        if ([input hasPrefix:@"+"] || [input hasPrefix:@"-"]) {
                          
                          BOOL isNegative = [input hasPrefix:@"-"];
                          NSString *numPart = [input substringFromIndex:1];
                          numPart = [numPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                          
                          if ([numPart.lowercaseString hasPrefix:@"0x"]) {
                            offset = strtoull([[numPart substringFromIndex:2] UTF8String], NULL, 16);
                          } else {
                            offset = strtoull([numPart UTF8String], NULL, 10);
                          }
                          
                          if (isNegative) offset = -offset;
                          targetAddr = baseAddr + offset;
                        } else if ([input.lowercaseString hasPrefix:@"0x"]) {
                          
                          targetAddr = strtoull([[input substringFromIndex:2] UTF8String], NULL, 16);
                          offset = (int64_t)(targetAddr - baseAddr);
                        } else {
                          
                          offset = strtoll([input UTF8String], NULL, 10);
                          targetAddr = baseAddr + offset;
                        }

                        NSString *sign = (offset >= 0) ? @"+" : @"";
                        NSString *resMsg = [NSString
                            stringWithFormat:@"%@ → %@\n\n%@ = %@%lld (0x%llX)",
                                             [NSString stringWithFormat:@"0x%llX", baseAddr],
                                             [NSString stringWithFormat:@"0x%llX", targetAddr],
                                             TR(@"Offset_Title"),
                                             sign, offset,
                                             (uint64_t)(offset >= 0 ? offset : -offset)];

                        UIAlertController *resAlert = [UIAlertController
                            alertControllerWithTitle:TR(@"Offset_Calc_Result_Title")
                                             message:resMsg
                                      preferredStyle:UIAlertControllerStyleAlert];

                        [resAlert addAction:
                            [UIAlertAction
                                actionWithTitle:TR(@"Mod_Menu_Value")
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *_Nonnull action) {
                                          dispatch_after(
                                              dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                                              dispatch_get_main_queue(), ^{
                                                [self finalJumpTo:targetAddr inVC:vc];
                                              });
                                        }]];

                        [resAlert addAction:
                            [UIAlertAction
                                actionWithTitle:TR(@"Btn_Copy")
                                          style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *_Nonnull action) {
                                          [[UIPasteboard generalPasteboard]
                                              setString:[NSString stringWithFormat:@"%@%lld", sign, offset]];
                                          [self showToast:TR(@"Msg_Copied") inVC:vc];
                                        }]];

                        [resAlert addAction:
                            [UIAlertAction
                                actionWithTitle:TR(@"Btn_OK")
                                          style:UIAlertActionStyleCancel
                                        handler:nil]];

                        [self safePresentAlert:resAlert from:vc];
                      }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];

  [self safePresentAlert:alert from:vc];
}

+ (void)showToast:(NSString *)msg inVC:(UIViewController *)vc {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:nil
                                          message:msg
                                   preferredStyle:UIAlertControllerStyleAlert];

  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *top = vc;
    while (top.presentedViewController) {
      if (top.presentedViewController.isBeingDismissed) {
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
              [self showToast:msg inVC:vc];
            });
        return;
      }
      top = top.presentedViewController;
    }

    [top presentViewController:alert animated:YES completion:nil];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          [alert dismissViewControllerAnimated:YES completion:nil];
        });
  });
}

+ (void)showAddToLockAlert:(uint64_t)addr
                     value:(NSString *)val
                      type:(VMDataType)type
                      inVC:(UIViewController *)vc {
  for (NSDictionary *item in [VMMemoryEngine shared].lockedItems) {
    if ([item[@"addr"] unsignedLongLongValue] == addr) {
      [self showToast:TR(@"Msg_Already_Locked") inVC:vc];
      return;
    }
  }

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Lock_Add_Note_Title")
                                          message:nil
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Placeholder_Note");
  }];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Btn_Confirm")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 NSString *note =
                                     alert.textFields.firstObject.text;
                                 if (!note || note.length == 0)
                                   note = TR(@"App_Title");

                                 [[VMLockEngine shared] addAddressLock:addr
                                                                 value:val ?: @"0"
                                                                  type:(int)type
                                                                  note:note];

                                 [self showToast:TR(@"Alert_Success") inVC:vc];
                               }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self safePresentAlert:alert from:vc];
}

+ (void)showAddToFavAlert:(uint64_t)addr
                     type:(VMDataType)type
                     inVC:(UIViewController *)vc {
  NSString *bundleID = [[VMMemoryEngine shared] currentBundleID];
  if ([[VMFavoriteManager shared] isFavorite:addr forApp:bundleID]) {
    [self showToast:TR(@"Msg_Already_Fav") inVC:vc];
    return;
  }

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Mod_Menu_Fav")
                                          message:TR(@"Mod_Placeholder")
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Placeholder_Note");
  }];

  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Btn_Confirm")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 NSString *note =
                                     alert.textFields.firstObject.text;
                                 NSMutableDictionary *favItem =
                                     [NSMutableDictionary
                                         dictionaryWithDictionary:@{
                                           @"addr" : @(addr),
                                           @"note" : note ?: @"",
                                           @"type" : @(type)
                                         }];
                                 [[VMFavoriteManager shared]
                                     addFavorite:favItem
                                          forApp:bundleID];

                                 [self showToast:TR(@"Alert_Success") inVC:vc];
                               }]];

  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self safePresentAlert:alert from:vc];
}

+ (void)showAddToFavAlert:(uint64_t)addr inVC:(UIViewController *)vc {
  NSString *bundleID = [[VMMemoryEngine shared] currentBundleID];
  if ([[VMFavoriteManager shared] isFavorite:addr forApp:bundleID]) {
    [self showToast:TR(@"Msg_Already_Fav") inVC:vc];
    return;
  }

  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:TR(@"Mod_Menu_Fav")
                                          message:TR(@"Mod_Placeholder")
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
    tf.placeholder = TR(@"Placeholder_Note");
    tf.returnKeyType = UIReturnKeyDone;
    tf.enablesReturnKeyAutomatically = YES;
  }];
  [alert addAction:[UIAlertAction
                       actionWithTitle:TR(@"Btn_Confirm")
                                 style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction *a) {
                                 NSString *note =
                                     alert.textFields.firstObject.text;
                                 NSMutableDictionary *favItem =
                                     [NSMutableDictionary
                                         dictionaryWithDictionary:@{
                                           @"addr" : @(addr),
                                           @"note" : note ?: @""
                                         }];
                                 [[VMFavoriteManager shared]
                                     addFavorite:favItem
                                          forApp:bundleID];
                                 [self showToast:TR(@"Alert_Success") inVC:vc];
                               }]];
  [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  [self safePresentAlert:alert from:vc];
}

+ (void)finalJumpTo:(uint64_t)addr inVC:(UIViewController *)vc {
  if ([vc isKindOfClass:NSClassFromString(@"VMMemoryBrowserViewController")]) {
    SEL selector = NSSelectorFromString(@"performJumpToAddress:");
    if ([vc respondsToSelector:selector]) {
      void (*func)(id, SEL, uint64_t) =
          (void (*)(id, SEL, uint64_t))objc_msgSend;
      func(vc, selector, addr);
      [self showToast:[NSString stringWithFormat:TR(@"Msg_Jump_To"), addr]
                 inVC:vc];
    }
  } else {
    VMMemoryBrowserViewController *browser =
        [VMMemoryBrowserViewController new];
    browser.address = addr;
    browser.type = VMDataTypeInt32;
    [vc.navigationController pushViewController:browser animated:YES];
  }

  [[NSNotificationCenter defaultCenter] postNotificationName:@"VM_DidViewMemory"
                                                      object:@(addr)];
}

+ (void)launchPointerSearchFrom:(UIViewController *)currentVC
                  targetAddress:(uint64_t)addr {
  
  VMPointerSearchViewController *ptrVC =
      [[VMPointerSearchViewController alloc] init];
  ptrVC.targetAddress = addr;
  ptrVC.level = 1;

  if (currentVC.navigationController) {
    [currentVC.navigationController pushViewController:ptrVC animated:YES];
  } else {
    UINavigationController *nav =
        [[UINavigationController alloc] initWithRootViewController:ptrVC];
    [currentVC presentViewController:nav animated:YES completion:nil];
  }
}
+ (void)handleSliderSwitchForChain:(VMPointerChain *)chain
                            fromVC:(UIViewController *)vc {
  if (chain.uiMode == VMPointerUIModeSlider) {
    chain.uiMode = VMPointerUIModeInput;
    chain.type = @"card";
    if ([vc respondsToSelector:@selector(tableView)]) {
      [[(UITableViewController *)vc tableView] reloadData];
    }
  } else {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:TR(@"Mode_Switch_Slider")
                         message:nil
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(
               UITextField *_Nonnull textField) {
      textField.placeholder = TR(@"Slider_Min_Placeholder");
      textField.keyboardType = UIKeyboardTypeDecimalPad;
      textField.text = @"0";
    }];
    [alert addTextFieldWithConfigurationHandler:^(
               UITextField *_Nonnull textField) {
      textField.placeholder = TR(@"Slider_Max_Placeholder");
      textField.keyboardType = UIKeyboardTypeDecimalPad;
      textField.text = @"100";
    }];

    [alert
        addAction:[UIAlertAction
                      actionWithTitle:TR(@"Btn_Confirm")
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *_Nonnull action) {
                                float min =
                                    [alert.textFields[0].text floatValue];
                                float max =
                                    [alert.textFields[1].text floatValue];
                                if (min >= max) {
                                  [self showToast:TR(@"Slider_Err_Min_Less_Max")
                                             inVC:vc];
                                  return;
                                }
                                chain.uiMin = min;
                                chain.uiMax = max;
                                chain.uiMode = VMPointerUIModeSlider;
                                chain.type = @"slider";
                                if ([vc respondsToSelector:@selector
                                        (tableView)]) {
                                  [[(UITableViewController *)vc tableView]
                                      reloadData];
                                }
                              }]];

    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_Cancel")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
  }
}

@end
