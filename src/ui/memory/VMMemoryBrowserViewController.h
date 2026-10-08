#import <UIKit/UIKit.h>
#import "include/VMMemoryEngine.h"

@interface VMMemoryBrowserViewController : UIViewController
@property(nonatomic) VMStringEncoding stringEncoding;
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) VMDataType type;

@property (nonatomic, assign) BOOL isMultiSelectMode;
@property (nonatomic, strong) NSMutableSet<NSNumber *> *selectedAddresses;
@end
