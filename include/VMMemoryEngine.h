#import <Foundation/Foundation.h>
#include <mach/mach.h>

@class VMPointerChain;
@class VMRVAPatch;
@class VMModuleInfo;

typedef struct {
  uint64_t address;
  uint64_t valueBits;
} VMRawResult;

typedef enum : NSUInteger {
  VMDataTypeInt8 = 0,
  VMDataTypeInt16 = 1,
  VMDataTypeInt32 = 2,
  VMDataTypeInt64 = 3,
  VMDataTypeUInt8 = 4,
  VMDataTypeUInt16 = 5,
  VMDataTypeUInt32 = 6,
  VMDataTypeUInt64 = 7,
  VMDataTypeFloat = 8,
  VMDataTypeDouble = 9,
  VMDataTypeString = 10
} VMDataType;

typedef enum : NSUInteger {
  VMSearchModeExact,
  VMSearchModeFuzzy,
  VMSearchModeGroup,
  VMSearchModeBetween
} VMSearchMode;

struct VMGroupItem {
  VMDataType type;
  union {
    long long i;
    double d;
  } value;
};

typedef enum : NSUInteger {
  VMFuzzyLess,        
  VMFuzzyGreater,     
  VMFuzzyBetween,     
  VMFuzzyIncreasedBy, 
  VMFuzzyDecreasedBy, 
  VMFuzzyChanged,     
  VMFuzzyUnchanged    
} VMFuzzyType;

typedef enum : NSUInteger {
  VMFilterModeLess = 0,
  VMFilterModeGreater = 1,
  VMFilterModeBetween = 2,
  VMFilterModeIncreased = 3,
  VMFilterModeDecreased = 4,
  VMFilterModeChanged = 5,
  VMFilterModeUnchanged = 6
} VMFilterMode;

@interface VMScanResultItem : NSObject
@property(nonatomic, assign) uint64_t address;
@property(nonatomic, assign) VMDataType type;
@property(nonatomic, strong) NSString *valueStr;
@property(nonatomic, strong) NSNumber *prevValue;
@property(nonatomic, assign) NSUInteger originalSize;
@end

@interface VMModuleInfo : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSString *path;
@property(nonatomic, assign) uint64_t loadAddress;
@property(nonatomic, assign) uint32_t size;
@end

@interface VMModuleMatch : NSObject
@property(nonatomic, copy) NSString *moduleName;
@property(nonatomic, assign) uint64_t baseAddr;
@property(nonatomic, assign) uint64_t offset;
@end

@interface VMMemoryTimelineItem : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *detail;
@property(nonatomic, copy) NSString *filePath;
@property(nonatomic, strong) NSDate *date;
@property(nonatomic, assign) NSUInteger resultCount;
@property(nonatomic, assign) VMDataType dataType;
@end

@interface VMMemoryWriteUndoItem : NSObject
@property(nonatomic, assign) pid_t pid;
@property(nonatomic, copy) NSString *bundleID;
@property(nonatomic, assign) uint64_t address;
@property(nonatomic, assign) VMDataType type;
@property(nonatomic, copy) NSString *oldValue;
@property(nonatomic, copy) NSString *writtenValue;
@property(nonatomic, strong) NSData *oldData;
@property(nonatomic, strong) NSDate *date;
@end

@interface VMMemoryWriteUndoBatch : NSObject
@property(nonatomic, assign) pid_t pid;
@property(nonatomic, copy) NSString *bundleID;
@property(nonatomic, strong) NSMutableArray<VMMemoryWriteUndoItem *> *items;
@property(nonatomic, strong) NSDate *date;
@end

@interface VMMemoryEngine : NSObject

@property(nonatomic, assign) pid_t targetPid;
@property(nonatomic, assign) mach_port_t targetTask;

@property(nonatomic, copy) NSString *resultFilePath;
@property(nonatomic, assign) NSUInteger resultCount;

@property(nonatomic, assign) uint64_t groupSearchRange;
@property(nonatomic, assign) NSUInteger resultLimit;
@property(nonatomic, assign) double floatTolerance;
@property(nonatomic, assign) BOOL groupAnchorMode;  
@property(nonatomic, assign) VMDataType currentDataType;
@property(nonatomic, assign) uint64_t searchRangeStart;
@property(nonatomic, assign) uint64_t searchRangeEnd;

@property(nonatomic, strong) NSMutableArray *lockedItems;
@property(nonatomic, strong)
    NSMutableArray<VMPointerChain *> *activeLockedPointers;

@property(nonatomic, strong) NSMutableArray *favoriteItems; 

@property(nonatomic, strong) NSMutableArray<VMRVAPatch *> *rvaPatches;
@property(nonatomic, strong, readonly)
    NSMutableArray<NSDictionary *> *sessionStack;

@property(nonatomic, copy) NSString *currentProcessName;
@property(nonatomic, copy) NSString *currentBundleID;
@property(nonatomic, assign) uint64_t mainModuleAddress;
@property(nonatomic, copy, readonly) NSString *rvaRootFolder;

@property(nonatomic, copy) NSString *contextPrefix;
- (void)switchContext:(NSString *)prefix;

+ (instancetype)shared;
- (BOOL)attachToPid:(pid_t)pid;

+ (BOOL)isProcessStarred:(NSString *)bundleID;
+ (void)starProcess:(NSString *)bundleID;
+ (void)unstarProcess:(NSString *)bundleID;
+ (NSArray<NSString *> *)starredProcesses;
+ (void)loadStarredProcesses;  

- (void)scanMemoryWithMode:(VMSearchMode)mode
                    valStr:(NSString *)valStr
                  dataType:(VMDataType)type
                 fuzzyType:(VMFuzzyType)fuzzyType
              isNextSearch:(BOOL)isNext
                completion:(void (^)(NSUInteger count, NSString *msg))comp;

- (void)scanMemoryWithMode:(VMSearchMode)mode
                    valStr:(NSString *)valStr
              coreDataType:(uint8_t)coreType
                 fuzzyType:(VMFuzzyType)fuzzyType
              isNextSearch:(BOOL)isNext
                completion:(void (^)(NSUInteger count, NSString *msg))comp;

- (void)scanNearbyWithTarget:(NSString *)targetVal
                    dataType:(VMDataType)type
                       range:(uint64_t)range
                  completion:(void (^)(NSUInteger count, NSString *msg))comp;

- (void)filterResultsWithMode:(VMFilterMode)mode
                         val1:(NSString *)v1
                         val2:(NSString *)v2
                         type:(VMDataType)type
                   completion:(void (^)(NSUInteger count, NSString *msg))comp;

- (NSString *)symbolicateAddress:(uint64_t)address;
- (VMModuleMatch *)findModuleForAddress:(uint64_t)address;

- (VMScanResultItem *)getResultItemAtIndex:(NSUInteger)index
                                  dataType:(VMDataType)type;
- (void)removeResultAtIndex:(NSUInteger)index;

- (void)clearSession;

- (void)backupCurrentSession;
- (void)restorePreviousSession;
- (void)clearSnapshot;
- (void)clearAllSnapshots;
- (BOOL)hasBackupSession;

- (NSArray<VMMemoryTimelineItem *> *)memoryTimelineItems;
- (void)captureMemoryTimelineWithTitle:(NSString *)title
                                detail:(NSString *)detail
                              dataType:(VMDataType)type;
- (BOOL)restoreMemoryTimelineAtIndex:(NSUInteger)index;
- (BOOL)canRestoreMemoryTimelineValuesAtIndex:(NSUInteger)index;
- (NSUInteger)restoreMemoryTimelineValuesAtIndex:(NSUInteger)index;
- (void)removeMemoryTimelineAtIndex:(NSUInteger)index;
- (void)clearMemoryTimeline;

- (void)rememberManualWriteUndoAtAddress:(uint64_t)address
                                    type:(VMDataType)type
                                oldValue:(NSString *)oldValue
                                oldData:(NSData *)oldData
                                newValue:(NSString *)newValue;
- (VMMemoryWriteUndoItem *)lastManualWriteUndoForAddress:(uint64_t)address
                                                    type:(VMDataType)type;
- (BOOL)undoLastManualWriteForAddress:(uint64_t)address type:(VMDataType)type;
- (NSUInteger)performManualBatchWrites:(NSArray<NSDictionary *> *)writes;
- (BOOL)canUndoLastManualWriteBatch;
- (NSUInteger)lastManualWriteBatchCount;
- (NSUInteger)undoLastManualWriteBatch;
- (void)clearManualWriteUndo;

- (NSUInteger)captureValueSnapshotForKey:(NSString *)key
                                   items:(NSArray<NSDictionary *> *)items;
- (BOOL)hasValueSnapshotForKey:(NSString *)key;
- (NSUInteger)valueSnapshotCountForKey:(NSString *)key;
- (NSUInteger)restoreValueSnapshotForKey:(NSString *)key;
- (void)clearAllValueSnapshots;

- (void)scanPointersPointingToAddresses:(NSSet<NSNumber *> *)targets
                             rangeStart:(uint64_t)start
                               rangeEnd:(uint64_t)end
                              maxOffset:(uint32_t)maxOffset
                             completion:
                                 (void (^)(NSArray<NSDictionary *> *results))
                                     comp;

- (void)autoSearchPointerChain:(uint64_t)targetAddress
                     heapStart:(uint64_t)heapStart
                       heapEnd:(uint64_t)heapEnd
                     baseStart:(uint64_t)baseStart
                       baseEnd:(uint64_t)baseEnd
                     maxLevels:(NSInteger)maxLevels
                   maxPerLevel:(NSInteger)maxPerLevel
                     maxOffset:(uint32_t)maxOffset
                selectedModule:(VMModuleInfo *)selectedModule
                 progressBlock:(void (^)(NSInteger level,
                                         NSUInteger count))progress
                    completion:(void (^)(NSArray<NSArray *> *paths))comp;

- (void)autoSearchPointerChainEx:(uint64_t)targetAddress
                       heapStart:(uint64_t)heapStart
                         heapEnd:(uint64_t)heapEnd
                       baseStart:(uint64_t)baseStart
                         baseEnd:(uint64_t)baseEnd
                       maxLevels:(NSInteger)maxLevels
                     maxPerLevel:(NSInteger)maxPerLevel
                       maxOffset:(uint32_t)maxOffset
                  selectedModule:(VMModuleInfo *)selectedModule
                  includeDynamic:(BOOL)includeDynamic
                   progressBlock:(void (^)(NSInteger level, NSUInteger count))progress
                      completion:(void (^)(NSArray<VMPointerChain *> *chains))comp;

- (void)autoSearchPointerChainPrecise:(uint64_t)targetAddress
                            heapStart:(uint64_t)heapStart
                              heapEnd:(uint64_t)heapEnd
                            maxLevels:(NSInteger)maxLevels
                     firstLevelOffset:(uint32_t)firstLevelOffset
                     subsequentOffset:(uint32_t)subsequentOffset
                       selectedModule:(VMModuleInfo *)selectedModule
                        progressBlock:(void (^)(NSInteger level, NSUInteger count))progress
                           completion:(void (^)(NSArray<VMPointerChain *> *chains))comp;

- (void)autoSearchPointerChainObjC:(uint64_t)targetAddress
                         heapStart:(uint64_t)heapStart
                           heapEnd:(uint64_t)heapEnd
                         baseStart:(uint64_t)baseStart
                           baseEnd:(uint64_t)baseEnd
                         maxLevels:(NSInteger)maxLevels
                       maxPerLevel:(NSInteger)maxPerLevel
                         maxOffset:(uint32_t)maxOffset
                    selectedModule:(VMModuleInfo *)selectedModule
                     progressBlock:(void (^)(NSInteger level, NSUInteger count))progress
                        completion:(void (^)(NSArray<NSArray *> *paths))comp;

- (void)autoSearchPointerChainObjCEx:(uint64_t)targetAddress
                           heapStart:(uint64_t)heapStart
                             heapEnd:(uint64_t)heapEnd
                           baseStart:(uint64_t)baseStart
                             baseEnd:(uint64_t)baseEnd
                           maxLevels:(NSInteger)maxLevels
                         maxPerLevel:(NSInteger)maxPerLevel
                           maxOffset:(uint32_t)maxOffset
                      selectedModule:(VMModuleInfo *)selectedModule
                       progressBlock:(void (^)(NSInteger level, NSUInteger count))progress
                          completion:(void (^)(NSArray<VMPointerChain *> *chains))comp;

- (void)forwardSearchPointerChain:(uint64_t)targetAddress
                        maxDepth:(NSInteger)maxDepth
                       maxOffset:(uint32_t)maxOffset
                      maxResults:(NSUInteger)maxResults
                  selectedModule:(VMModuleInfo *)selectedModule
                   progressBlock:(void (^)(NSInteger level, NSUInteger foundCount))progress
                      completion:(void (^)(NSArray<VMPointerChain *> *chains))comp;

- (void)scanPointerValue:(uint64_t)targetAddress
              rangeStart:(uint64_t)start
                rangeEnd:(uint64_t)end
              completion:
                  (void (^)(NSArray<VMScanResultItem *> *results))completion;

- (uint64_t)resolvePointerChain:(uint64_t)baseAddress
                        offsets:(NSArray<NSNumber *> *)offsets;

- (uint64_t)findModuleBaseAddress:(NSString *)moduleName;

- (NSString *)readAddress:(uint64_t)address type:(VMDataType)type;

- (BOOL)readFromSnapshot:(uint64_t)address buffer:(void *)buffer size:(size_t)size;
- (BOOL)writeAddress:(uint64_t)address
               value:(NSString *)value
                type:(VMDataType)type;
- (NSData *)readRawMemory:(uint64_t)address length:(size_t)len;
- (BOOL)writeRawData:(NSData *)data toAddress:(uint64_t)address;

- (void)batchModifyValues:(NSString *)input
                    limit:(NSInteger)limit
                     type:(VMDataType)type
                     mode:(int)mode
                    items:(NSArray<VMScanResultItem *> *)items;

- (NSArray<VMModuleInfo *> *)loadRemoteModules;
- (uint32_t)calculateMachOSizeForAddress:(uint64_t)loadAddr;
- (NSData *)dataFromHexString:(NSString *)hexString;

- (BOOL)isRegionExecutable:(uint64_t)address;
- (BOOL)isDeviceJailbroken;

- (void)reloadLockedPointers;
- (void)saveFavorites; 

- (void)saveRVAPatches;
- (void)loadRVAPatches;
- (void)loadRVAPatchesForApp:(NSString *)bundleID;
- (NSData *)readMemory:(uint64_t)address size:(NSUInteger)size;

- (void)scanSignature:(NSString *)signature
           rangeStart:(uint64_t)start
             rangeEnd:(uint64_t)end
           completion:
               (void (^)(NSArray<VMScanResultItem *> *results))completion;

- (void)fastScanSignature:(NSString *)signature
                 inModule:(NSString *)moduleName
               completion:
                   (void (^)(NSArray<VMScanResultItem *> *results))completion;

- (NSString *)hexStringFromData:(NSData *)data;

- (void)takeGlobalSnapshot;
- (void)takeGlobalSnapshotObjC;  
- (void)clearSnapshot;

- (void)saveBaselineSnapshot;
- (void)clearBaselineSnapshot;
- (BOOL)hasBaselineSnapshot;
- (NSArray<NSDictionary *> *)compareWithBaseline;  

- (void)fastFuzzyInitWithCompletion:(void (^)(BOOL success, NSString *msg, NSUInteger addressCount))comp;
- (BOOL)hasFastFuzzySnapshot;
- (void)fastFuzzyFilterWithMode:(VMFilterMode)mode
                       dataType:(VMDataType)type
                     completion:(void (^)(NSUInteger count, NSString *msg))comp;
- (void)clearFastFuzzySnapshot;

- (void)clearAllData;

@end
