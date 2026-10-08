#import <UIKit/UIKit.h>
#import "include/VMMemoryEngine.h"

@interface VMMemoryActionSheet : NSObject

+ (void)showActionSheetForAddress:(uint64_t)addr
                            value:(NSString *)valStr
                         dataType:(VMDataType)type
               fromViewController:(UIViewController *)vc
                       sourceView:(UIView *)sourceView
                       sourceRect:(CGRect)sourceRect
                        extraItem:(NSMutableDictionary *)item;

+ (void)showActionSheetForAddress:(uint64_t)addr
                            value:(NSString *)valStr
                         dataType:(VMDataType)type
                   stringEncoding:(VMStringEncoding)encoding
               fromViewController:(UIViewController *)vc
                       sourceView:(UIView *)sourceView
                       sourceRect:(CGRect)sourceRect
                        extraItem:(NSMutableDictionary *)item;

+ (void)showAddToFavAlert:(uint64_t)addr inVC:(UIViewController *)vc;
+ (void)showAddToFavAlert:(uint64_t)addr type:(VMDataType)type inVC:(UIViewController *)vc;

+ (void)showAddToFavAlert:(uint64_t)addr type:(VMDataType)type
          stringEncoding:(VMStringEncoding)encoding inVC:(UIViewController *)vc;

@end
