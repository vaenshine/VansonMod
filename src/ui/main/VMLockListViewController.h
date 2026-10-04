#import <UIKit/UIKit.h>

@interface VMLockListViewController
    : UIViewController <UITableViewDelegate, UITextFieldDelegate>

@property(nonatomic, assign) NSInteger defaultTabIndex;
@property(nonatomic, copy) NSString *autoOpenVerifierPath;

@property(nonatomic, assign, readonly) NSInteger currentTab;
- (void)prepareForLanguageRefresh;

@end
