#import <UIKit/UIKit.h>

@interface VMUIHelper : NSObject

+ (UIColor *)accentColor;
+ (UIColor *)filledColorForTint:(UIColor *)tint;
+ (UIColor *)canvasColor;
+ (UIColor *)cardColor;
+ (UIFont *)scaledFontOfSize:(CGFloat)size weight:(UIFontWeight)weight;
+ (void)styleCard:(UIView *)view;
+ (void)styleTextField:(UITextField *)field;
+ (void)styleTableView:(UITableView *)tableView;
+ (void)styleButton:(UIButton *)button primary:(BOOL)primary;
+ (void)styleConfirmationItem:(UIBarButtonItem *)item;
+ (void)installAppearance;
+ (void)applyNavigationAppearance:(UINavigationController *)navigationController;
+ (UIView *)contextHeaderWithText:(NSString *)text symbol:(NSString *)symbol;
+ (UIImage *)applicationIconForBundleID:(NSString *)bundleID;
+ (void)cacheApplicationIcon:(UIImage *)icon forBundleID:(NSString *)bundleID;
+ (UIView *)processHeaderWithName:(NSString *)name bundleID:(NSString *)bundleID pid:(int)pid;
+ (void)sizeHeaderToFitTableView:(UITableView *)tableView;
+ (void)sizeFooterToFitTableView:(UITableView *)tableView;
+ (UIView *)emptyStateWithTitle:(NSString *)title message:(NSString *)message symbol:(NSString *)symbol;

+ (UIButton *)createButtonWithTitle:(NSString *)title
                              color:(UIColor *)color
                             target:(id)target
                             action:(SEL)action;

+ (UIButton *)createIconButton:(NSString *)iconName
                         color:(UIColor *)color
                        target:(id)target
                        action:(SEL)action;

+ (UIView *)createVansonFooterViewForWidth:(CGFloat)width;

+ (void)addFixedFooterTo:(UIViewController *)vc forTableView:(UITableView *)tableView;

@end
