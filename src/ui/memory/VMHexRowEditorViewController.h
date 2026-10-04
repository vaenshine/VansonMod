#import <UIKit/UIKit.h>

@protocol VMHexRowEditorDelegate <NSObject>
- (void)rowEditorDidSaveData:(NSData *)data atAddress:(uint64_t)address completion:(void (^)(BOOL success, NSString *errorKey))completion;
@end

@interface VMHexRowEditorViewController : UIViewController
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, strong) NSData *originalData;
@property (nonatomic, weak) id<VMHexRowEditorDelegate> delegate;
@end
