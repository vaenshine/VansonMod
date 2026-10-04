#import "VMLanguageRefresh.h"

void VMRefreshAfterDismissal(UIViewController *presenter, dispatch_block_t refresh) {
  dispatch_async(dispatch_get_main_queue(), ^{
    // UIKit may promote an action sheet's presenter to the tab controller.
    UIViewController *owner = presenter;
    while (owner.parentViewController) owner = owner.parentViewController;
    UIViewController *modal = owner.presentedViewController;
    dispatch_block_t run = ^{
      dispatch_async(dispatch_get_main_queue(), ^{
        VMLanguageTrace(@"dismissal-complete");
        refresh();
      });
    };
    dispatch_block_t finish = ^{
      // Leave UIKit's dismissal completion before changing the navigation stack.
      dispatch_async(dispatch_get_main_queue(), ^{
        if (modal && owner.presentedViewController == modal)
          [owner dismissViewControllerAnimated:NO completion:run];
        else
          run();
      });
    };
    if (!modal) {
      finish();
    } else if (modal.isBeingDismissed && modal.transitionCoordinator) {
      BOOL registered = [modal.transitionCoordinator animateAlongsideTransition:nil
          completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> context) {
        finish();
      }];
      if (!registered) [owner dismissViewControllerAnimated:NO completion:finish];
    } else {
      [owner dismissViewControllerAnimated:NO completion:finish];
    }
  });
}

#if VM_LANGUAGE_TRACE
#import <os/log.h>

NSURL *VMLanguageTraceURL(void) {
  NSURL *directory = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
      inDomains:NSUserDomainMask].firstObject;
  return [directory URLByAppendingPathComponent:@"Vanson-language-trace.log"];
}

void VMLanguageTrace(NSString *stage) {
  // Test builds only: bounded local log, containing stages and timestamps only.
  static dispatch_queue_t queue;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ queue = dispatch_queue_create("vm.language.trace", DISPATCH_QUEUE_SERIAL); });
  NSString *line = [NSString stringWithFormat:@"%.3f %@\n", NSDate.date.timeIntervalSince1970, stage];
  os_log(OS_LOG_DEFAULT, "VM language: %{public}@", stage);
  dispatch_async(queue, ^{
    NSURL *url = VMLanguageTraceURL();
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtURL:url.URLByDeletingLastPathComponent withIntermediateDirectories:YES
        attributes:nil error:nil];
    NSDictionary *attrs = [fm attributesOfItemAtPath:url.path error:nil];
    if (!attrs || [attrs[NSFileSize] unsignedLongLongValue] > 64 * 1024) {
      [line writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:nil];
      return;
    }
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:url.path];
    @try {
      [file seekToEndOfFile];
      [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch (__unused NSException *exception) {
    } @finally {
      [file closeFile];
    }
  });
}

void VMLanguageWatchMainQueue(void) {
  dispatch_semaphore_t acknowledged = dispatch_semaphore_create(0);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
      dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    dispatch_async(dispatch_get_main_queue(), ^{ dispatch_semaphore_signal(acknowledged); });
    if (dispatch_semaphore_wait(acknowledged, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC)))
      VMLanguageTrace(@"main-queue-unresponsive");
    else
      VMLanguageTrace(@"main-queue-responsive");
  });
}
#endif
