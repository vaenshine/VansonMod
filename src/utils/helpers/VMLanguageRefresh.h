#import <UIKit/UIKit.h>

// Run after the alert action and its dismissal have both completed.
void VMRefreshAfterDismissal(UIViewController *presenter, dispatch_block_t refresh);

#if VM_LANGUAGE_TRACE
void VMLanguageTrace(NSString *stage);
NSURL *VMLanguageTraceURL(void);
void VMLanguageWatchMainQueue(void);
#else
static inline void VMLanguageTrace(__unused NSString *stage) {}
static inline void VMLanguageWatchMainQueue(void) {}
#endif
