#import <UIKit/UIKit.h>

@interface VMRootViewController : UITabBarController

- (void)showDisclaimer:(BOOL)isReadOnly;
- (void)applyTabOrder;
- (void)showTabReorder;
- (void)refreshLocalizedPages;
- (void)refreshBrandingOverlay;

@end
