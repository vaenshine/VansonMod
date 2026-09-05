#import <Foundation/Foundation.h>

@interface VMStringMemoryRecord : NSObject
@property(nonatomic) uint64_t address;
@property(nonatomic, copy) NSData *bytes;
@property(nonatomic, copy) NSString *text;
@property(nonatomic) BOOL terminated;
@end

// All offsets and limits are byte-based. Reads/writes belong to one target session.
@interface VMStringMemorySession : NSObject
@property(nonatomic, copy) NSData *(^reader)(uint64_t address, NSUInteger length);
@property(nonatomic, copy) BOOL (^writer)(uint64_t address, NSData *data);
@property(nonatomic, copy) BOOL (^targetIsValid)(void);
@property(nonatomic, copy) void (^didWrite)(uint64_t address, NSData *before, NSData *after);
@property(nonatomic, readonly) uint64_t address;
@property(nonatomic, readonly) NSData *originalBytes;
@property(nonatomic, readonly) NSString *originalText;
@property(nonatomic, readonly) BOOL rangeMode;
@property(nonatomic, readonly) BOOL terminated;
@property(nonatomic, readonly) NSUInteger byteLimit;
@property(nonatomic, readonly) BOOL canUndo;
@property(nonatomic, readonly) NSArray<VMStringMemoryRecord *> *records;
@property(nonatomic, readonly) NSUInteger contextByteCount;
- (BOOL)openStringAtAddress:(uint64_t)address error:(NSString **)error;
- (BOOL)openRangeFrom:(uint64_t)start through:(uint64_t)end error:(NSString **)error;
- (BOOL)loadMoreBefore:(BOOL)before error:(NSString **)error;
- (void)resetContext;
- (NSData *)dataForDraft:(NSString *)text error:(NSString **)error;
- (BOOL)commitDraft:(NSString *)text error:(NSString **)error;
- (BOOL)undo:(NSString **)error;
+ (BOOL)parseAddress:(NSString *)text value:(uint64_t *)value;
+ (NSString *)escapedTextForData:(NSData *)data;
+ (NSData *)dataForEscapedText:(NSString *)text;
@end
