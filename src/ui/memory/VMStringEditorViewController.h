#import <UIKit/UIKit.h>
#import "VMStringMemorySession.h"

@interface VMStringEditorViewController : UIViewController
@property(nonatomic, strong) VMStringMemorySession *session;
@property(nonatomic) uint64_t initialAddress;
@property(nonatomic, copy) void (^didChangeMemory)(void);
@end
