#import "../../include/VMMemoryEngine.h"
#import "../../include/VMDataSession.h"
#import "../../include/VMLocalization.h"
#import "../../include/VMLockManager.h"
#import "../../include/VMRVAPatch.h"
#import "../../include/VMStoragePathHelper.h"
#include "../core/SystemCore.hpp"
#include "../utils/managers/PatchCore.hpp"
#include "../utils/managers/StorageCore.hpp"
#include "core/MemoryCore.hpp"
#include "core/SessionCore.hpp"
#import <Foundation/Foundation.h>

#include <mach-o/dyld_images.h>
#include <mach-o/loader.h>
#include <mach/mach.h>
#include <memory>
#include <stdatomic.h>
#include <stdio.h>
#include <string>
#include <sys/sysctl.h>
#include <vector>
#define TR(key) ([[VMLocalization shared] localizedString:key])
extern "C" {
int proc_pidpath(int pid, void *buffer, uint32_t buffersize);
}
struct dyld_image_info_64 {
  uint64_t imageLoadAddress;
  uint64_t imageFilePath;
  uint64_t imageFileModDate;
};
struct dyld_all_image_infos_64 {
  uint32_t version;
  uint32_t infoArrayCount;
  uint64_t infoArray;
  uint64_t notification;
  bool processDetachedFromSharedRegion;
  bool libSystemInitialized;
};
extern "C" {
kern_return_t mach_vm_region(vm_map_t, mach_vm_address_t *, mach_vm_size_t *,
                             vm_region_flavor_t, vm_region_info_t,
                             mach_msg_type_number_t *, mach_port_t *);
kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t,
                                     mach_vm_size_t, mach_vm_address_t,
                                     mach_vm_size_t *);
kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t, vm_offset_t,
                            mach_msg_type_number_t);
kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t,
                              boolean_t, vm_prot_t);
}
#define FILE_BUFFER_SIZE (1024 * 1024)
static const NSUInteger VM_VISIBLE_STRING_MAX_LEN = 256;

static uint64_t VMParseAddressSetting(NSString *text, uint64_t fallback) {
  NSString *trimmed =
      [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (trimmed.length == 0)
    return fallback;

  const char *cstr = [trimmed UTF8String];
  char *end = nullptr;
  int base = ([trimmed hasPrefix:@"0x"] || [trimmed hasPrefix:@"0X"]) ? 0 : 16;
  unsigned long long parsed = strtoull(cstr, &end, base);
  if (end == cstr || *end != '\0')
    return fallback;
  return (uint64_t)parsed;
}

static NSMutableOrderedSet<NSString *> *_starredProcessBIDs = nil;
static BOOL _starredProcessesLoaded = NO;

static NSString *getStarredProcessFilePath(void) {
  NSString *basePath = [VMStoragePathHelper vansonModDirectory];
  return [basePath stringByAppendingPathComponent:@"process.vmps"];
}

static BOOL VMIsVisibleStringByte(uint8_t b) {
  return (b >= 0x20 && b <= 0x7E) || b >= 0xC0;
}

static NSString *VMStringFromVisibleBytes(const uint8_t *bytes, NSUInteger length) {
  if (!bytes || length == 0)
    return @"";

  NSUInteger len = 0;
  while (len < length && len < VM_VISIBLE_STRING_MAX_LEN) {
    if (bytes[len] == '\0')
      break;
    if (!VMIsVisibleStringByte(bytes[len]))
      break;
    len++;
  }
  if (len == 0)
    return @"";

  NSString *str = [[NSString alloc] initWithBytes:bytes
                                           length:len
                                         encoding:NSUTF8StringEncoding];
  return str ?: @"";
}

static void saveStarredProcesses(void) {
  NSString *filePath = getStarredProcessFilePath();
  
  if (!_starredProcessBIDs || _starredProcessBIDs.count == 0) {
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    return;
  }
  
  NSArray *starredArray = [_starredProcessBIDs array];
  
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:starredArray options:0 error:&error];
  if (error || !jsonData) return;
  
  [jsonData writeToFile:filePath atomically:YES];
}

static VMCore::DataType convertToCoreDataType(VMDataType type) {
  return static_cast<VMCore::DataType>(type);
}

__attribute__((unused))
static VMDataType convertToVMDataType(VMCore::DataType type) {
  return static_cast<VMDataType>(type);
}

@interface VMRegionBlock : NSObject
@property(nonatomic, assign) uint64_t start;
@property(nonatomic, assign) uint64_t size;
@property(nonatomic, strong) NSData *memoryData;          
@property(nonatomic, assign, readonly) void *dataPointer; 
@end

@implementation VMRegionBlock
- (void)setMemoryData:(NSData *)memoryData {
  _memoryData = memoryData;
}

- (void *)dataPointer {
  return (void *)_memoryData.bytes;
}
@end

static void autoSearchProgressBridge(VMCore::MemoryCore::SearchProgress sp,
                                     void *userData) {
  void (^progressBlock)(NSInteger, NSUInteger) =
      (__bridge void (^)(NSInteger, NSUInteger))userData;
  if (progressBlock) {
    dispatch_async(dispatch_get_main_queue(), ^{
      progressBlock(sp.level, sp.foundCount);
    });
  }
}

@implementation VMScanResultItem
@end
@implementation VMModuleInfo
@end
@implementation VMModuleMatch
@end
@implementation VMMemoryTimelineItem
@end
@implementation VMMemoryWriteUndoItem
@end
@implementation VMMemoryWriteUndoBatch
@end
@interface VMMemoryEngine () {
  std::unique_ptr<VMCore::MemoryCore> _core;
  
}
@property(nonatomic, strong) NSMutableDictionary *contextStates;
@property(nonatomic, strong) NSMutableArray<VMRegionBlock *> *memorySnapshot;
@property(nonatomic, strong) NSMutableArray<VMMemoryTimelineItem *> *memoryTimeline;
@property(nonatomic, strong) NSMutableArray<VMMemoryWriteUndoItem *> *manualWriteUndoStack;
@property(nonatomic, strong) NSMutableArray<VMMemoryWriteUndoBatch *> *manualWriteUndoBatches;
@property(nonatomic, strong) NSMutableDictionary<NSString *, VMMemoryWriteUndoBatch *> *valueSnapshots;
@end
@implementation VMMemoryEngine
+ (instancetype)shared {
  static VMMemoryEngine *s;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    s = [self new];
  });
  return s;
}

+ (void)loadStarredProcesses {
  if (_starredProcessesLoaded) return;
  _starredProcessesLoaded = YES;
  
  NSString *filePath = getStarredProcessFilePath();
  NSData *fileData = [NSData dataWithContentsOfFile:filePath];
  if (!fileData || fileData.length == 0) {
    _starredProcessBIDs = [NSMutableOrderedSet orderedSet];
    return;
  }
  
  NSError *error;
  NSArray *starredArray = [NSJSONSerialization JSONObjectWithData:fileData options:0 error:&error];
  if (error || ![starredArray isKindOfClass:[NSArray class]]) {
    _starredProcessBIDs = [NSMutableOrderedSet orderedSet];
    return;
  }
  
  _starredProcessBIDs = [NSMutableOrderedSet orderedSetWithArray:starredArray];
}

+ (NSArray<NSString *> *)starredProcesses {
  [self loadStarredProcesses];
  return [_starredProcessBIDs array] ?: @[];
}

+ (BOOL)isProcessStarred:(NSString *)bundleID {
  if (!bundleID || bundleID.length == 0) return NO;
  [self loadStarredProcesses];
  return [_starredProcessBIDs containsObject:bundleID];
}

+ (void)starProcess:(NSString *)bundleID {
  if (!bundleID || bundleID.length == 0) return;
  [self loadStarredProcesses];
  
  [_starredProcessBIDs removeObject:bundleID];
  [_starredProcessBIDs insertObject:bundleID atIndex:0];
  
  saveStarredProcesses();
}

+ (void)unstarProcess:(NSString *)bundleID {
  if (!bundleID || bundleID.length == 0) return;
  [self loadStarredProcesses];
  
  [_starredProcessBIDs removeObject:bundleID];
  
  saveStarredProcesses();
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _resultCount = 0;
    _resultFilePath = nil;

    _core = std::make_unique<VMCore::MemoryCore>();
    _core->setResultLimit(0); 

    NSString *pathA = [self getPathA];
    NSString *pathB = [self getPathB];
    _core->setStoragePath([pathA UTF8String], [pathB UTF8String]);

    _contextStates = [NSMutableDictionary dictionary];
    _lockedItems = [NSMutableArray array];
    _favoriteItems = [NSMutableArray array];  
    _activeLockedPointers = [NSMutableArray array];
    _rvaPatches = [NSMutableArray array];
    _memoryTimeline = [NSMutableArray array];
    _manualWriteUndoStack = [NSMutableArray array];
    _manualWriteUndoBatches = [NSMutableArray array];
    _valueSnapshots = [NSMutableDictionary dictionary];

    [self switchContext:@"mod"];
    [self loadSettings];
    [self loadRVAPatches];
  }
  return self;
}

- (NSString *)rvaRootFolder {
  std::string path = PatchCore::getInstance().getPatchRootFolder();
  return [NSString stringWithUTF8String:path.c_str()];
}

- (void)loadSettings {
  
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];

  self.searchRangeStart =
      VMParseAddressSetting([def objectForKey:@"startAddr"], 0x100000000ULL);
  self.searchRangeEnd =
      VMParseAddressSetting([def objectForKey:@"endAddr"], 0x300000000ULL);
  if (self.searchRangeEnd <= self.searchRangeStart) {
    self.searchRangeStart = 0x100000000ULL;
    self.searchRangeEnd = 0x300000000ULL;
  }
  
  NSString *grpStr = [def objectForKey:@"groupRange"];
  if (grpStr && grpStr.length > 0) {
    if ([grpStr hasPrefix:@"0x"] || [grpStr hasPrefix:@"0X"]) {
      self.groupSearchRange = strtoull([grpStr UTF8String], NULL, 16);
    } else {
      self.groupSearchRange = [grpStr longLongValue];
    }
  } else {
    self.groupSearchRange = 0x100; 
  }
  
  NSString *limitStr = [def objectForKey:@"resultLimit"];
  if (limitStr && limitStr.length > 0) {
    self.resultLimit = [limitStr integerValue];
  } else {
    self.resultLimit = 0;
  }
  
  NSString *tolStr = [def objectForKey:@"floatTolerance"];
  if (tolStr && tolStr.length > 0) {
    self.floatTolerance = [tolStr doubleValue];
  } else {
    self.floatTolerance = 0.001;
  }
  
  id anchorObj = [def objectForKey:@"groupAnchorMode"];
  BOOL anchorMode = (anchorObj == nil) ? NO : [def boolForKey:@"groupAnchorMode"];
  self.groupAnchorMode = anchorMode;
}

- (void)setFloatTolerance:(double)floatTolerance {
  _floatTolerance = floatTolerance;
  if (_core) {
    _core->setFloatTolerance(floatTolerance);
  }
}

- (void)setGroupSearchRange:(uint64_t)groupSearchRange {
  _groupSearchRange = groupSearchRange;
  if (_core) {
    _core->setGroupSearchRange(groupSearchRange);
  }
}

- (void)setGroupAnchorMode:(BOOL)groupAnchorMode {
  _groupAnchorMode = groupAnchorMode;
  if (_core) {
    _core->setGroupAnchorMode(groupAnchorMode);
  }
}

- (void)setResultLimit:(NSUInteger)resultLimit {
  _resultLimit = resultLimit;
  if (_core) {
    size_t coreLimit =
        (resultLimit == 0) ? std::numeric_limits<size_t>::max() : resultLimit;
    _core->setResultLimit(coreLimit);
  }
}

- (BOOL)attachToPid:(pid_t)pid {
  
  if (_targetTask != MACH_PORT_NULL) {
    mach_port_deallocate(mach_task_self(), _targetTask);
    _targetTask = MACH_PORT_NULL;
  }
  
  _targetPid = pid;
  
  kern_return_t kr = task_for_pid(mach_task_self(), pid, &_targetTask);
  if (kr != KERN_SUCCESS) {
    _targetTask = MACH_PORT_NULL;
    
    _core->attach(0);
    return NO;
  }
  
  BOOL success = _core->attach(pid);
  if (success) {
    [self clearSession];
    [self clearAllSnapshots];
    [self clearMemoryTimeline];
    [self clearManualWriteUndo];
    [self clearAllValueSnapshots];
    [self.lockedItems removeAllObjects];

    [self.rvaPatches removeAllObjects];
    _cachedModules = nil;

    char pathBuffer[4096];
    memset(pathBuffer, 0, sizeof(pathBuffer));
    proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    NSString *fullPath = [NSString stringWithUTF8String:pathBuffer];
    if (fullPath.length > 0) {
      self.currentProcessName =
          [[fullPath lastPathComponent] stringByDeletingPathExtension];

      NSString *appDir = [fullPath stringByDeletingLastPathComponent];
      NSDictionary *info = [NSDictionary
          dictionaryWithContentsOfFile:
              [appDir stringByAppendingPathComponent:@"Info.plist"]];
      NSString *bid = info[@"CFBundleIdentifier"];
      self.currentBundleID = bid ?: @"com.unknown.app";
    } else {
      self.currentProcessName = [NSString stringWithFormat:@"PID_%d", pid];
      self.currentBundleID = nil;
    }

    [self refreshMainModuleAddress];

    [self loadRVAPatches];

    if (self.currentBundleID) {
      NSArray *savedLocks =
          [[VMLockManager shared] loadLocksForApp:self.currentBundleID];

      for (VMPointerChain *chain in savedLocks) {
        chain.lockEnabled = NO;
      }

      self.activeLockedPointers = [savedLocks mutableCopy];

      if (self.activeLockedPointers.count > 0) {
        [[VMLockManager shared] saveLocks:self.activeLockedPointers
                                   forApp:self.currentBundleID];
      }
    } else {
      self.activeLockedPointers = [NSMutableArray array];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"VMProcessChangedNotification"
                      object:nil];
    return YES;
  }
  return NO;
}

- (void)refreshMainModuleAddress {
  self.mainModuleAddress = 0;
  NSArray *modules = [self loadRemoteModules];
  if (modules.count > 0) {
    VMModuleInfo *mainMod = modules.firstObject;
    self.mainModuleAddress = mainMod.loadAddress;
  }
}

- (NSString *)getPathA {
  NSString *prefix = self.contextPrefix ?: @"default";
  NSString *name = [NSString stringWithFormat:@"%@_scan_buffer_a.bin", prefix];
  return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

- (NSString *)getPathB {
  NSString *prefix = self.contextPrefix ?: @"default";
  NSString *name = [NSString stringWithFormat:@"%@_scan_buffer_b.bin", prefix];
  return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

- (void)switchContext:(NSString *)newPrefix {
  if ([self.contextPrefix isEqualToString:newPrefix])
    return;
  NSMutableDictionary *currentState = [NSMutableDictionary dictionary];
  if (self.resultFilePath)
    currentState[@"path"] = self.resultFilePath;
  currentState[@"count"] = @(self.resultCount);
  
  if (self.contextPrefix) {
    _contextStates[self.contextPrefix] = currentState;
  }

  self.contextPrefix = newPrefix;
  if (_core) {
    NSString *pathA = [self getPathA];
    NSString *pathB = [self getPathB];
    _core->setStoragePath([pathA UTF8String], [pathB UTF8String]);
  }

  NSDictionary *savedState = _contextStates[newPrefix];
  if (savedState) {
    self.resultFilePath = savedState[@"path"];
    self.resultCount = [savedState[@"count"] unsignedLongValue];
    
    SessionCore::getInstance().clearSnapshots();
     
  } else {
    self.resultFilePath = nil;
    self.resultCount = 0;
    
    SessionCore::getInstance().clearSnapshots();
  }
}

- (void)clearSession {
  self.resultCount = 0;
  self.resultFilePath = nil;
  
  if (_core) {
    _core->clearResults();
  }
  
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:[self getPathA]])
    [fm removeItemAtPath:[self getPathA] error:nil];
  if ([fm fileExistsAtPath:[self getPathB]])
    [fm removeItemAtPath:[self getPathB] error:nil];
  
  [self clearBaselineSnapshot];
  
  [self clearFastFuzzySnapshot];
}

- (NSString *)memoryTimelineSnapshotPath {
  NSString *uuid = [[NSUUID UUID] UUIDString];
  NSString *name = [NSString stringWithFormat:@"vm_timeline_%@.bin", uuid];
  return [NSTemporaryDirectory() stringByAppendingPathComponent:name];
}

- (void)trimMemoryTimelineIfNeeded {
  const NSUInteger maxItems = 20;
  NSFileManager *fm = [NSFileManager defaultManager];
  while (self.memoryTimeline.count > maxItems) {
    VMMemoryTimelineItem *old = self.memoryTimeline.lastObject;
    if (old.filePath.length > 0) {
      [fm removeItemAtPath:old.filePath error:nil];
    }
    [self.memoryTimeline removeLastObject];
  }
}

- (NSArray<VMMemoryTimelineItem *> *)memoryTimelineItems {
  return [self.memoryTimeline copy];
}

- (void)captureMemoryTimelineWithTitle:(NSString *)title
                                detail:(NSString *)detail
                              dataType:(VMDataType)type {
  if (self.resultCount == 0 || !self.resultFilePath)
    return;

  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:self.resultFilePath])
    return;

  NSString *snapPath = [self memoryTimelineSnapshotPath];
  NSError *error = nil;
  if (![fm copyItemAtPath:self.resultFilePath toPath:snapPath error:&error])
    return;

  VMMemoryTimelineItem *item = [VMMemoryTimelineItem new];
  item.title = title ?: @"";
  item.detail = detail ?: @"";
  item.filePath = snapPath;
  item.resultCount = self.resultCount;
  item.dataType = type;
  item.date = [NSDate date];
  [self.memoryTimeline insertObject:item atIndex:0];
  [self trimMemoryTimelineIfNeeded];
}

- (BOOL)restoreMemoryTimelineAtIndex:(NSUInteger)index {
  if (index >= self.memoryTimeline.count)
    return NO;

  VMMemoryTimelineItem *item = self.memoryTimeline[index];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (item.filePath.length == 0 || ![fm fileExistsAtPath:item.filePath])
    return NO;

  NSString *copyPath = [self memoryTimelineSnapshotPath];
  if (![fm copyItemAtPath:item.filePath toPath:copyPath error:nil])
    return NO;

  BOOL ok = _core->restoreResultsFromFile([copyPath UTF8String], item.resultCount);
  if (ok) {
    self.resultFilePath = [self getPathA];
    self.resultCount = item.resultCount;
    self.currentDataType = item.dataType;
  } else {
    [fm removeItemAtPath:copyPath error:nil];
  }
  return ok;
}

- (BOOL)canRestoreMemoryTimelineValuesAtIndex:(NSUInteger)index {
  if (index >= self.memoryTimeline.count)
    return NO;
  NSUInteger count = self.memoryTimeline[index].resultCount;
  return count > 0 && count <= 10000 && self.targetTask != MACH_PORT_NULL;
}

- (NSUInteger)restoreMemoryTimelineValuesAtIndex:(NSUInteger)index {
  if (![self canRestoreMemoryTimelineValuesAtIndex:index])
    return 0;
  VMMemoryTimelineItem *item = self.memoryTimeline[index];
  if (item.filePath.length == 0 ||
      ![[NSFileManager defaultManager] fileExistsAtPath:item.filePath])
    return 0;
  return _core->restoreValuesFromFile([item.filePath UTF8String],
                                      item.resultCount, 10000);
}

- (void)removeMemoryTimelineAtIndex:(NSUInteger)index {
  if (index >= self.memoryTimeline.count)
    return;
  VMMemoryTimelineItem *item = self.memoryTimeline[index];
  if (item.filePath.length > 0) {
    [[NSFileManager defaultManager] removeItemAtPath:item.filePath error:nil];
  }
  [self.memoryTimeline removeObjectAtIndex:index];
}

- (void)clearMemoryTimeline {
  NSFileManager *fm = [NSFileManager defaultManager];
  for (VMMemoryTimelineItem *item in self.memoryTimeline) {
    if (item.filePath.length > 0) {
      [fm removeItemAtPath:item.filePath error:nil];
    }
  }
  [self.memoryTimeline removeAllObjects];
}

- (void)rememberManualWriteUndoAtAddress:(uint64_t)address
                                    type:(VMDataType)type
                                oldValue:(NSString *)oldValue
                                 oldData:(NSData *)oldData
                                newValue:(NSString *)newValue {
  if (!oldData || oldData.length == 0)
    return;

  VMMemoryWriteUndoItem *item = [VMMemoryWriteUndoItem new];
  item.pid = self.targetPid;
  item.bundleID = self.currentBundleID ?: @"";
  item.address = address;
  item.type = type;
  item.oldValue = oldValue ?: @"";
  item.writtenValue = newValue ?: @"";
  item.oldData = oldData;
  item.date = [NSDate date];
  [self.manualWriteUndoStack insertObject:item atIndex:0];

  const NSUInteger maxItems = 30;
  while (self.manualWriteUndoStack.count > maxItems) {
    [self.manualWriteUndoStack removeLastObject];
  }
}

- (VMMemoryWriteUndoItem *)lastManualWriteUndoForAddress:(uint64_t)address
                                                    type:(VMDataType)type {
  for (VMMemoryWriteUndoItem *item in self.manualWriteUndoStack) {
    BOOL sameProcess = item.pid == self.targetPid;
    BOOL sameBundle = [item.bundleID isEqualToString:(self.currentBundleID ?: @"")];
    if (sameProcess && sameBundle && item.address == address && item.type == type) {
      return item;
    }
  }
  return nil;
}

- (BOOL)undoLastManualWriteForAddress:(uint64_t)address type:(VMDataType)type {
  VMMemoryWriteUndoItem *item = [self lastManualWriteUndoForAddress:address type:type];
  if (!item)
    return NO;

  BOOL ok = [self writeRawData:item.oldData toAddress:address];
  if (ok) {
    [self.manualWriteUndoStack removeObject:item];
  }
  return ok;
}

- (void)clearManualWriteUndo {
  [self.manualWriteUndoStack removeAllObjects];
  [self.manualWriteUndoBatches removeAllObjects];
}

- (NSUInteger)writeSizeForType:(VMDataType)type
                      oldValue:(NSString *)oldValue
                      newValue:(NSString *)newValue {
  switch (type) {
    case VMDataTypeInt8:
    case VMDataTypeUInt8:
      return 1;
    case VMDataTypeInt16:
    case VMDataTypeUInt16:
      return 2;
    case VMDataTypeInt64:
    case VMDataTypeUInt64:
    case VMDataTypeDouble:
      return 8;
    case VMDataTypeString: {
      NSUInteger oldLen = [oldValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      NSUInteger newLen = [newValue lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      return MAX((NSUInteger)1, MAX(oldLen, newLen) + 1);
    }
    case VMDataTypeInt32:
    case VMDataTypeUInt32:
    case VMDataTypeFloat:
    default:
      return 4;
  }
}

- (NSUInteger)performManualBatchWrites:(NSArray<NSDictionary *> *)writes {
  if (writes.count == 0 || self.targetTask == MACH_PORT_NULL)
    return 0;

  VMMemoryWriteUndoBatch *batch = [VMMemoryWriteUndoBatch new];
  batch.pid = self.targetPid;
  batch.bundleID = self.currentBundleID ?: @"";
  batch.items = [NSMutableArray array];
  batch.date = [NSDate date];

  NSMutableSet<NSString *> *captured = [NSMutableSet set];
  NSUInteger successCount = 0;
  for (NSDictionary *write in writes) {
    uint64_t address = [write[@"address"] unsignedLongLongValue];
    VMDataType type = (VMDataType)[write[@"type"] unsignedIntegerValue];
    NSString *newValue = write[@"value"];
    if (address == 0 || newValue.length == 0)
      continue;

    NSString *key = [NSString stringWithFormat:@"%llX-%lu", address,
                                               (unsigned long)type];
    NSString *oldValue = [self readAddress:address type:type] ?: @"";
    NSUInteger size = [self writeSizeForType:type
                                    oldValue:oldValue
                                    newValue:newValue];
    NSData *oldData = [self readRawMemory:address length:size];
    if (!oldData)
      continue;

    if ([self writeAddress:address value:newValue type:type]) {
      successCount++;
      if (![captured containsObject:key]) {
        VMMemoryWriteUndoItem *item = [VMMemoryWriteUndoItem new];
        item.pid = self.targetPid;
        item.bundleID = self.currentBundleID ?: @"";
        item.address = address;
        item.type = type;
        item.oldValue = oldValue;
        item.writtenValue = newValue;
        item.oldData = oldData;
        item.date = batch.date;
        [batch.items addObject:item];
        [captured addObject:key];
      }
    }
  }

  if (batch.items.count > 0) {
    [self.manualWriteUndoBatches insertObject:batch atIndex:0];
    const NSUInteger maxBatches = 10;
    while (self.manualWriteUndoBatches.count > maxBatches)
      [self.manualWriteUndoBatches removeLastObject];
  }
  return successCount;
}

- (BOOL)canUndoLastManualWriteBatch {
  VMMemoryWriteUndoBatch *batch = self.manualWriteUndoBatches.firstObject;
  if (!batch)
    return NO;
  return batch.pid == self.targetPid &&
         [batch.bundleID isEqualToString:(self.currentBundleID ?: @"")];
}

- (NSUInteger)lastManualWriteBatchCount {
  return [self canUndoLastManualWriteBatch]
             ? self.manualWriteUndoBatches.firstObject.items.count
             : 0;
}

- (NSUInteger)undoLastManualWriteBatch {
  if (![self canUndoLastManualWriteBatch])
    return 0;

  VMMemoryWriteUndoBatch *batch = self.manualWriteUndoBatches.firstObject;
  NSMutableArray<VMMemoryWriteUndoItem *> *failed = [NSMutableArray array];
  NSUInteger restored = 0;
  for (VMMemoryWriteUndoItem *item in [batch.items reverseObjectEnumerator]) {
    if ([self writeRawData:item.oldData toAddress:item.address]) {
      restored++;
      for (NSMutableDictionary *lockItem in self.lockedItems) {
        if ([lockItem[@"addr"] unsignedLongLongValue] == item.address) {
          lockItem[@"val"] = item.oldValue ?: @"";
          break;
        }
      }
    } else {
      [failed addObject:item];
    }
  }

  if (failed.count == 0)
    [self.manualWriteUndoBatches removeObjectAtIndex:0];
  else
    batch.items = failed;
  return restored;
}

- (NSUInteger)captureValueSnapshotForKey:(NSString *)key
                                   items:(NSArray<NSDictionary *> *)items {
  if (key.length == 0 || items.count == 0 || self.targetTask == MACH_PORT_NULL)
    return 0;

  VMMemoryWriteUndoBatch *snapshot = [VMMemoryWriteUndoBatch new];
  snapshot.pid = self.targetPid;
  snapshot.bundleID = self.currentBundleID ?: @"";
  snapshot.items = [NSMutableArray array];
  snapshot.date = [NSDate date];

  NSMutableSet<NSString *> *captured = [NSMutableSet set];
  for (NSDictionary *source in items) {
    uint64_t address = [source[@"address"] unsignedLongLongValue];
    VMDataType type = (VMDataType)[source[@"type"] unsignedIntegerValue];
    NSString *identity = [NSString stringWithFormat:@"%llX-%lu", address,
                                                    (unsigned long)type];
    if (address == 0 || [captured containsObject:identity])
      continue;

    NSString *value = [self readAddress:address type:type] ?: @"";
    NSUInteger size = [self writeSizeForType:type oldValue:value newValue:value];
    NSData *data = [self readRawMemory:address length:size];
    if (!data)
      continue;

    VMMemoryWriteUndoItem *item = [VMMemoryWriteUndoItem new];
    item.pid = self.targetPid;
    item.bundleID = self.currentBundleID ?: @"";
    item.address = address;
    item.type = type;
    item.oldValue = value;
    item.oldData = data;
    item.date = snapshot.date;
    [snapshot.items addObject:item];
    [captured addObject:identity];
  }

  if (snapshot.items.count > 0)
    self.valueSnapshots[key] = snapshot;
  return snapshot.items.count;
}

- (BOOL)hasValueSnapshotForKey:(NSString *)key {
  VMMemoryWriteUndoBatch *snapshot = self.valueSnapshots[key];
  return snapshot.items.count > 0 && snapshot.pid == self.targetPid &&
         [snapshot.bundleID isEqualToString:(self.currentBundleID ?: @"")];
}

- (NSUInteger)valueSnapshotCountForKey:(NSString *)key {
  return [self hasValueSnapshotForKey:key] ? self.valueSnapshots[key].items.count : 0;
}

- (NSUInteger)restoreValueSnapshotForKey:(NSString *)key {
  if (![self hasValueSnapshotForKey:key])
    return 0;

  VMMemoryWriteUndoBatch *snapshot = self.valueSnapshots[key];
  NSUInteger restored = 0;
  for (VMMemoryWriteUndoItem *item in snapshot.items) {
    if (![self writeRawData:item.oldData toAddress:item.address])
      continue;
    restored++;
    for (NSMutableDictionary *entry in self.lockedItems) {
      if ([entry[@"addr"] unsignedLongLongValue] == item.address) {
        entry[@"val"] = item.oldValue ?: @"";
        break;
      }
    }
    for (NSMutableDictionary *entry in self.favoriteItems) {
      if ([entry[@"addr"] unsignedLongLongValue] == item.address) {
        entry[@"val"] = item.oldValue ?: @"";
        break;
      }
    }
  }
  return restored;
}

- (void)clearAllValueSnapshots {
  [self.valueSnapshots removeAllObjects];
}

#pragma mark - Session Snapshot Stack
- (void)backupCurrentSession {
  if (!self.resultFilePath || self.resultCount == 0) {
    SessionCore::getInstance().pushSnapshot("", 0);
    return;
  }

  std::string currentPath = [self.resultFilePath UTF8String];
  SessionCore::getInstance().pushSnapshot(currentPath, self.resultCount);
}

- (void)restorePreviousSession {
  if (!SessionCore::getInstance().hasSnapshots())
    return;

  std::string path;
  size_t count;
  if (SessionCore::getInstance().popSnapshot(path, count)) {
    if (path.empty() && count == 0) {
      [self clearSession];
    } else {
      NSString *backupPath = [NSString stringWithUTF8String:path.c_str()];
      NSFileManager *fm = [NSFileManager defaultManager];

      if ([fm fileExistsAtPath:backupPath]) {
        NSString *mainPath = [self getPathA];
        if ([fm fileExistsAtPath:mainPath])
          [fm removeItemAtPath:mainPath error:nil];

        [fm moveItemAtPath:backupPath toPath:mainPath error:nil];
        self.resultFilePath = mainPath;
        self.resultCount = count;
      }
    }
  }
}

- (void)clearAllSnapshots {
  SessionCore::getInstance().clearSnapshots();
}

- (BOOL)hasBackupSession {
  return SessionCore::getInstance().hasSnapshots();
}

#pragma mark - 核心搜索逻辑
- (void)scanMemoryWithMode:(VMSearchMode)mode
                    valStr:(NSString *)valStr
                  dataType:(VMDataType)type
                 fuzzyType:(VMFuzzyType)fuzzyType
              isNextSearch:(BOOL)isNext
                completion:(void (^)(NSUInteger count, NSString *msg))comp {
  
  VMCore::DataType coreType = convertToCoreDataType(type);
  [self scanMemoryWithMode:mode
                    valStr:valStr
              coreDataType:(uint8_t)coreType
                 fuzzyType:fuzzyType
              isNextSearch:isNext
                completion:comp];
}

- (void)scanMemoryWithMode:(VMSearchMode)mode
                    valStr:(NSString *)valStr
              coreDataType:(uint8_t)coreType
                 fuzzyType:(VMFuzzyType)fuzzyType
              isNextSearch:(BOOL)isNext
                completion:(void (^)(NSUInteger count, NSString *msg))comp {

  if (self.targetTask == MACH_PORT_NULL) {
    if (comp)
      comp(0, TR(@"Msg_Target_Not_Found"));
    return;
  }

  self.currentDataType = (VMDataType)coreType;

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    VMCore::DataType coreDataType = (VMCore::DataType)coreType;
    std::string cValStr = [valStr UTF8String] ?: "";
    int cMode = (int)mode;

    if (isNext) {
      
      int finalMode;
      if (mode == VMSearchModeExact) {
        finalMode = 100;
      } else if (mode == VMSearchModeBetween) {
        finalMode = 101;
      } else if (mode == VMSearchModeFuzzy) {
        finalMode = (int)fuzzyType;
      } else {
        finalMode = cMode;
      }
      _core->nextScan({}, coreDataType, cValStr, finalMode);
    } else {
      
      _core->clearBaselineSnapshot();
      
      _core->scan(coreDataType, cValStr, cMode, self.searchRangeStart,
                  self.searchRangeEnd);
      
      if (mode == VMSearchModeFuzzy && _core->getResultCount() > 0) {
        _core->saveBaselineSnapshot();
      }
    }

    self.resultCount = _core->getResultCount();
    self.resultFilePath = self.resultCount > 0 ? [self getPathA] : nil;

    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) {
        NSString *msg = self.resultCount > 0 ? TR(@"Msg_Search_Success")
                                             : TR(@"Msg_Search_No_Res");
        comp(self.resultCount, msg);
      }
    });
  });
}

- (void)scanNearbyWithTarget:(NSString *)targetVal
                    dataType:(VMDataType)type
                       range:(uint64_t)range
                  completion:(void (^)(NSUInteger count, NSString *msg))comp {

  if (self.targetTask == MACH_PORT_NULL) {
    if (comp)
      comp(0, TR(@"Msg_Target_Not_Found"));
    return;
  }

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    std::string cValStr = [targetVal UTF8String] ?: "";
    VMCore::DataType coreType = convertToCoreDataType(type);

    _core->scanNearby({}, coreType, cValStr, range);
    self.resultCount = _core->getResultCount();
    self.resultFilePath = self.resultCount > 0 ? [self getPathA] : nil;

    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) {
        NSString *msg = self.resultCount > 0 ? TR(@"Msg_Search_Success")
                                             : TR(@"Msg_Search_No_Res");
        comp(self.resultCount, msg);
      }
    });
  });
}

- (void)filterResultsWithMode:(VMFilterMode)mode
                         val1:(NSString *)v1
                         val2:(NSString *)v2
                         type:(VMDataType)type
                   completion:(void (^)(NSUInteger count, NSString *msg))comp {

  if (self.targetTask == MACH_PORT_NULL) {
    if (comp)
      comp(0, TR(@"Msg_Target_Not_Found"));
    return;
  }

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    VMCore::DataType coreType = convertToCoreDataType(type);
    std::string s1 = [v1 UTF8String] ?: "";
    std::string s2 = [v2 UTF8String] ?: "";

    if (mode == VMFilterModeLess || mode == VMFilterModeGreater || mode == VMFilterModeBetween) {
      
      VMCore::FilterMode coreMode;
      switch (mode) {
        case VMFilterModeLess:
          coreMode = VMCore::FilterMode::Less;
          break;
        case VMFilterModeGreater:
          coreMode = VMCore::FilterMode::Greater;
          break;
        case VMFilterModeBetween:
        default:
          coreMode = VMCore::FilterMode::Between;
          break;
      }
      _core->filterResults(coreMode, coreType, s1, s2);
    } else {
      
      int searchMode = 6; 
      switch (mode) {
        case VMFilterModeIncreased:
          searchMode = 1;
          break;
        case VMFilterModeDecreased:
          searchMode = 0;
          break;
        case VMFilterModeChanged:
          searchMode = 5;
          break;
        case VMFilterModeUnchanged:
          searchMode = 6;
          break;
        default:
          searchMode = 6;
          break;
      }
      _core->nextScan({}, coreType, s1, searchMode);
    }
    
    self.resultCount = _core->getResultCount();
    self.resultFilePath = self.resultCount > 0 ? [self getPathA] : nil;

    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) {
        NSString *msg = self.resultCount > 0 ? TR(@"Msg_Filter_Success")
                                             : TR(@"Msg_Filter_No_Res");
        comp(self.resultCount, msg);
      }
    });
  });
}

#pragma mark - UI 懒加载
- (VMScanResultItem *)getResultItemAtIndex:(NSUInteger)index
                                  dataType:(VMDataType)type {
  if (index >= self.resultCount)
    return nil;

  std::vector<VMCore::ScanResult> res = _core->getResults(index, 1);
  if (res.empty())
    return nil;

  auto &cppItem = res[0];
  VMScanResultItem *item = [VMScanResultItem new];
  item.address = cppItem.address;
  
  VMDataType actualType = (VMDataType)cppItem.type;
  if (actualType >= VMDataTypeInt8 && actualType <= VMDataTypeDouble) {
    item.type = actualType;
  } else {
    item.type = type;
  }

  if ([self isFloatType:item.type]) {
    double val;
    if ([self getSizeForType:item.type] == 4) {
      float temp;
      memcpy(&temp, &cppItem.value, 4);
      val = temp;
    } else {
      memcpy(&val, &cppItem.value, 8);
    }
    item.prevValue = @(val);
    item.valueStr = [self formatValue:val type:item.type];
  } else if (item.type == VMDataTypeString) {
    item.valueStr = nil;
  } else {
    
    long long val = 0;
    
    size_t sz = [self getSizeForType:item.type];
    memcpy(&val, &cppItem.value, sz > 8 ? 8 : sz); 

    item.prevValue = @(val);
    item.valueStr = [NSString stringWithFormat:@"%lld", val];
  }
  return item;
}

- (void)removeResultAtIndex:(NSUInteger)index {
  if (!_core)
    return;
  if (_core->removeResult(index)) {
    self.resultCount--;
  }
}

- (BOOL)isFloatType:(VMDataType)type {
  return (type == VMDataTypeFloat || type == VMDataTypeDouble);
}
- (int)getSizeForType:(VMDataType)type {
  switch (type) {
    case VMDataTypeInt8:
    case VMDataTypeUInt8:
      return 1;
    case VMDataTypeInt16:
    case VMDataTypeUInt16:
      return 2;
    case VMDataTypeInt64:
    case VMDataTypeUInt64:
    case VMDataTypeDouble:
      return 8;
    case VMDataTypeString:
      return 1;
    default:
      return 4;
  }
}

- (double)readDoubleFromBuffer:(void *)ptr type:(VMDataType)type {
  switch (type) {
  case VMDataTypeFloat:
    return (double)(*(float *)ptr);
  case VMDataTypeDouble:
    return *(double *)ptr;
  default:
    return 0.0;
  }
}

- (long long)readLongLongFromBuffer:(void *)ptr type:(VMDataType)type {
  switch (type) {
  case VMDataTypeInt8:
    return *(int8_t *)ptr;
  case VMDataTypeUInt8:
    return *(uint8_t *)ptr;
  case VMDataTypeInt16:
    return *(int16_t *)ptr;
  case VMDataTypeUInt16:
    return *(uint16_t *)ptr;
  case VMDataTypeInt32:
    return *(int32_t *)ptr;
  case VMDataTypeUInt32:
    return *(uint32_t *)ptr;
  case VMDataTypeInt64:
    return *(int64_t *)ptr;
  case VMDataTypeUInt64:
    return (long long)(*(uint64_t *)ptr);
  default:
    return 0;
  }
}

- (NSString *)formatValue:(double)val type:(VMDataType)type {
  if (type == VMDataTypeDouble) {
    return [NSString stringWithFormat:@"%g", val];
  }
  return [NSString stringWithFormat:@"%.4f", val];
}

- (NSString *)readAddress:(uint64_t)address type:(VMDataType)type {
  if (address < 0x10000 || address > 0x800000000000ULL) {
    return @"(Null)";
  }
  if (type == VMDataTypeString) {
    uint8_t buf[VM_VISIBLE_STRING_MAX_LEN] = {0};
    mach_vm_size_t sz = VM_VISIBLE_STRING_MAX_LEN;
    if (mach_vm_read_overwrite(self.targetTask, address, VM_VISIBLE_STRING_MAX_LEN,
                               (mach_vm_address_t)buf, &sz) != KERN_SUCCESS) {
      return @"(? ?)";
    }
    return VMStringFromVisibleBytes(buf, (NSUInteger)sz);
  }
  uint8_t buf[8];
  mach_vm_size_t sz = 8;
  if (mach_vm_read_overwrite(self.targetTask, address, 8,
                             (mach_vm_address_t)buf, &sz) != KERN_SUCCESS) {
    return @"? ?";
  }

  switch (type) {
  case VMDataTypeInt8:
    return [NSString stringWithFormat:@"%d", *(int8_t *)buf];
  case VMDataTypeUInt8:
    return [NSString stringWithFormat:@"%u", *(uint8_t *)buf];
  case VMDataTypeInt16:
    return [NSString stringWithFormat:@"%d", *(int16_t *)buf];
  case VMDataTypeUInt16:
    return [NSString stringWithFormat:@"%u", *(uint16_t *)buf];
  case VMDataTypeInt32:
    return [NSString stringWithFormat:@"%d", *(int32_t *)buf];
  case VMDataTypeUInt32:
    return [NSString stringWithFormat:@"%u", *(uint32_t *)buf];
  case VMDataTypeInt64:
    return [NSString stringWithFormat:@"%lld", *(int64_t *)buf];
  case VMDataTypeUInt64:
    return [NSString stringWithFormat:@"%llu", *(uint64_t *)buf];
  case VMDataTypeFloat:
    return [NSString stringWithFormat:@"%.4f", *(float *)buf];
  case VMDataTypeDouble:
    return [NSString stringWithFormat:@"%g", *(double *)buf];
  default:
    return @"?";
  }
}

- (BOOL)readFromSnapshot:(uint64_t)address buffer:(void *)buffer size:(size_t)size {
  if (!_core || !buffer || size == 0)
    return NO;
  return _core->readFromSnapshot(address, buffer, size);
}

- (BOOL)writeRawData:(NSData *)data toAddress:(uint64_t)address {
  if (!_core || !data)
    return NO;
  return _core->writeMemory(address, data.bytes, data.length);
}

- (BOOL)writeAddress:(uint64_t)address
               value:(NSString *)value
                type:(VMDataType)type {
  for (NSMutableDictionary *item in self.lockedItems) {
    if ([item[@"addr"] unsignedLongLongValue] == address) {
      item[@"val"] = value;
      break;
    }
  }
  if (self.targetTask == MACH_PORT_NULL)
    return NO;

  NSMutableData *data = nil;
  if (type == VMDataTypeString) {
    const char *cstr = [value UTF8String];
    if (cstr)
      data = [NSMutableData dataWithBytes:cstr length:strlen(cstr)];
  } else {
    switch (type) {
      case VMDataTypeInt8: {
        int8_t v = [value intValue];
        data = [NSMutableData dataWithBytes:&v length:1];
        break;
      }
      case VMDataTypeUInt8: {
        uint8_t v = [value intValue];
        data = [NSMutableData dataWithBytes:&v length:1];
        break;
      }
      case VMDataTypeInt16: {
        int16_t v = [value intValue];
        data = [NSMutableData dataWithBytes:&v length:2];
        break;
      }
      case VMDataTypeUInt16: {
        uint16_t v = [value intValue];
        data = [NSMutableData dataWithBytes:&v length:2];
        break;
      }
      case VMDataTypeInt32: {
        int32_t v = [value intValue];
        data = [NSMutableData dataWithBytes:&v length:4];
        break;
      }
      case VMDataTypeUInt32: {
        uint32_t v = (uint32_t)[value longLongValue];
        data = [NSMutableData dataWithBytes:&v length:4];
        break;
      }
      case VMDataTypeInt64: {
        int64_t v = [value longLongValue];
        data = [NSMutableData dataWithBytes:&v length:8];
        break;
      }
      case VMDataTypeUInt64: {
        uint64_t v = strtoull([value UTF8String], NULL, 10);
        data = [NSMutableData dataWithBytes:&v length:8];
        break;
      }
      case VMDataTypeFloat: {
        float v = [value floatValue];
        data = [NSMutableData dataWithBytes:&v length:4];
        break;
      }
      case VMDataTypeDouble: {
        double v = [value doubleValue];
        data = [NSMutableData dataWithBytes:&v length:8];
        break;
      }
      default:
        break;
    }
  }
  return data ? [self writeRawData:data toAddress:address] : NO;
}

- (NSData *)readRawMemory:(uint64_t)address length:(size_t)len {
  if (!_core)
    return nil;
  void *buf = malloc(len);
  if (_core->readMemory(address, buf, len)) {
    NSData *data = [NSData dataWithBytes:buf length:len];
    free(buf);
    return data;
  }
  free(buf);
  return nil;
}

- (void)batchModifyValues:(NSString *)input
                    limit:(NSInteger)limit
                     type:(VMDataType)type
                     mode:(int)mode
                    items:(NSArray<VMScanResultItem *> *)items {
  if (!_core || !input)
    return;

  if (items && items.count > 0) {
    
    double dValue = [input doubleValue];
    long long iValue = [input longLongValue];
    NSMutableArray<NSDictionary *> *writes = [NSMutableArray array];
    for (NSInteger i = 0; i < items.count; i++) {
      if (limit > 0 && i >= limit)
        break;
      VMScanResultItem *item = items[i];
      
      VMDataType actualType = item.type;
      
      if (actualType < VMDataTypeInt8 || actualType > VMDataTypeDouble) {
        actualType = type;
      }
      
      NSString *writeStr = [self _calculateValueForIndex:i
                                                    mode:mode
                                                    type:actualType
                                                  inputD:dValue
                                                  inputI:iValue];
      [writes addObject:@{
        @"address" : @(item.address),
        @"type" : @(actualType),
        @"value" : writeStr
      }];
    }
    [self performManualBatchWrites:writes];
  } else {
    NSUInteger count = self.resultCount;
    if (limit > 0)
      count = MIN(count, (NSUInteger)limit);
    if (count <= 10000) {
      NSMutableArray<VMScanResultItem *> *allItems =
          [NSMutableArray arrayWithCapacity:count];
      for (NSUInteger i = 0; i < count; i++) {
        VMScanResultItem *item = [self getResultItemAtIndex:i dataType:type];
        if (item)
          [allItems addObject:item];
      }
      [self batchModifyValues:input
                        limit:0
                         type:type
                         mode:mode
                        items:allItems];
    } else {
      _core->batchModify([input UTF8String], (int)limit,
                         convertToCoreDataType(type), mode);
    }
  }
}

- (NSString *)_calculateValueForIndex:(NSInteger)index
                                 mode:(int)mode
                                 type:(VMDataType)type
                               inputD:(double)inputD
                               inputI:(long long)inputI {
  if ([self isFloatType:type]) {
    double val = inputD;
    if (mode == 1)
      val += (double)index;
    return [self formatValue:val type:type];
  } else {
    long long val = inputI;
    if (mode == 1)
      val += (long long)index;
    return [NSString stringWithFormat:@"%lld", val];
  }
}

- (BOOL)isRegionExecutable:(uint64_t)address {
  if (self.targetTask == MACH_PORT_NULL)
    return NO;
  vm_region_basic_info_data_64_t info;
  mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
  mach_vm_address_t regionAddress = address;
  mach_vm_size_t size;
  mach_port_t object_name;
  kern_return_t kr = mach_vm_region(
      self.targetTask, &regionAddress, &size, VM_REGION_BASIC_INFO_64,
      (vm_region_info_t)&info, &count, &object_name);
  if (kr == KERN_SUCCESS) {
    if (address >= regionAddress && address < (regionAddress + size)) {
      if (info.protection & VM_PROT_EXECUTE) {
        return YES;
      }
    }
  }
  return NO;
}

- (BOOL)isDeviceJailbroken {
  return VMCore::SystemCore::getInstance().isDeviceJailbroken();
}

- (NSArray<VMModuleInfo *> *)loadRemoteModules {
    NSMutableArray *modules = [NSMutableArray array];
    task_dyld_info_data_t dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    
    if (task_info(self.targetTask, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count) != KERN_SUCCESS) return modules;
    
    uint64_t all_infos_addr = dyld_info.all_image_info_addr;
    if (all_infos_addr == 0) return modules;
    
    struct dyld_all_image_infos_64 infos;
    mach_vm_size_t size = sizeof(infos);
    if (mach_vm_read_overwrite(self.targetTask, all_infos_addr, size, (mach_vm_address_t)&infos, &size) != KERN_SUCCESS) return modules;
    
    uint32_t cnt = infos.infoArrayCount;
    if (cnt > 5000) cnt = 5000; 
    
    mach_vm_size_t arrSize = cnt * sizeof(struct dyld_image_info_64);
    void *buf = malloc(arrSize);
    if (!buf) return modules;
    
    if (mach_vm_read_overwrite(self.targetTask, infos.infoArray, arrSize, (mach_vm_address_t)buf, &arrSize) == KERN_SUCCESS) {
        struct dyld_image_info_64 *imgs = (struct dyld_image_info_64 *)buf;
        
        for (uint32_t i = 0; i < cnt; i++) {
            VMModuleInfo *m = [VMModuleInfo new];
            m.loadAddress = imgs[i].imageLoadAddress;
            
            char path[1024];
            mach_vm_size_t pSize = 1024;
            if (mach_vm_read_overwrite(self.targetTask, imgs[i].imageFilePath, pSize, (mach_vm_address_t)path, &pSize) == KERN_SUCCESS) {
                path[pSize-1] = '\0';
                m.path = [NSString stringWithUTF8String:path];
                m.name = [m.path lastPathComponent];
            } else {
                continue; 
            }
            
            m.size = [self calculateMachOSizeForAddress:m.loadAddress];
            
            [modules addObject:m];
        }
    }
    free(buf);
    
    [modules sortUsingComparator:^NSComparisonResult(VMModuleInfo *m1, VMModuleInfo *m2) {
        if (m1.loadAddress < m2.loadAddress) return NSOrderedAscending;
        return NSOrderedDescending;
    }];
    
    _cachedModules = modules;
    return modules;
}

- (uint32_t)calculateMachOSizeForAddress:(uint64_t)loadAddr {
    struct mach_header_64 header;
    mach_vm_size_t headerSize = sizeof(header);
    if (mach_vm_read_overwrite(self.targetTask, loadAddr, headerSize, (mach_vm_address_t)&header, &headerSize) != KERN_SUCCESS) return 0;
    if (header.magic != MH_MAGIC_64) return 0;
    
    uint32_t ncmds = header.ncmds;
    uint32_t sizeofcmds = header.sizeofcmds;
    
    uint8_t *cmdsBuffer = (uint8_t *)malloc(sizeofcmds);
    if (!cmdsBuffer) return 0;
    
    mach_vm_size_t readSize = sizeofcmds;
    if (mach_vm_read_overwrite(self.targetTask, loadAddr + sizeof(header), readSize, (mach_vm_address_t)cmdsBuffer, &readSize) != KERN_SUCCESS) {
        free(cmdsBuffer);
        return 0;
    }
    
    uint64_t totalVMSize = 0;
    uint8_t *cursor = cmdsBuffer;
    
    for (uint32_t i = 0; i < ncmds; i++) {
        struct load_command *lc = (struct load_command *)cursor;
        if (lc->cmd == LC_SEGMENT_64) {
            struct segment_command_64 *seg = (struct segment_command_64 *)lc;
            totalVMSize += seg->vmsize;
        }
        cursor += lc->cmdsize;
        if (cursor >= cmdsBuffer + sizeofcmds) break;
    }
    free(cmdsBuffer);
    
    return (uint32_t)totalVMSize;
}

- (NSData *)dataFromHexString:(NSString *)hexString {
  hexString = [hexString stringByReplacingOccurrencesOfString:@" "
                                                   withString:@""];
  hexString = [hexString stringByReplacingOccurrencesOfString:@"0x"
                                                   withString:@""];
  NSMutableData *data = [[NSMutableData alloc] init];
  unsigned char whole_byte;
  char byte_chars[3] = {'\0', '\0', '\0'};
  for (int i = 0; i < [hexString length] / 2; i++) {
    byte_chars[0] = [hexString characterAtIndex:i * 2];
    byte_chars[1] = [hexString characterAtIndex:i * 2 + 1];
    whole_byte = strtol(byte_chars, NULL, 16);
    [data appendBytes:&whole_byte length:1];
  }
  return data;
}

#pragma mark - Filter Logic

static NSArray *_cachedModules = nil;
- (VMModuleMatch *)findModuleForAddress:(uint64_t)address {
  if (!_cachedModules) {
    _cachedModules = [self loadRemoteModules];
  }

  for (VMModuleInfo *mod in _cachedModules) {
    if (mod.loadAddress > address) break;

    if (address >= mod.loadAddress && address < (mod.loadAddress + mod.size)) {
      
      if ([mod.path hasPrefix:@"/usr/lib/"] || 
          [mod.path hasPrefix:@"/System/Library/"] ||
          [mod.name isEqualToString:@"dyld"]) {
        continue;
      }

      VMModuleMatch *match = [VMModuleMatch new];
      match.moduleName = mod.name;
      match.baseAddr = mod.loadAddress;
      match.offset = address - mod.loadAddress;
      return match;
    }
  }
  
  return nil;
}

- (NSString *)symbolicateAddress:(uint64_t)address {
  VMModuleMatch *match = [self findModuleForAddress:address];
  if (match) {
    if (match.offset < 0x40000000) {
      return [NSString
          stringWithFormat:@"%@ + 0x%llX", match.moduleName, match.offset];
    }
  }
  return nil;
}

#pragma mark - Auto Pointer Chain Search
- (void)scanPointersPointingToAddresses:(NSSet<NSNumber *> *)targets
                             rangeStart:(uint64_t)startAddr
                               rangeEnd:(uint64_t)endAddr
                              maxOffset:(uint32_t)maxOffset
                             completion:
                                 (void (^)(NSArray<NSDictionary *> *results))
                                     comp {

  if (self.targetTask == MACH_PORT_NULL || targets.count == 0) {
    if (comp)
      comp(@[]);
    return;
  }

  std::vector<uint64_t> cTargets;
  cTargets.reserve(targets.count);
  for (NSNumber *num in targets) {
    cTargets.push_back([num unsignedLongLongValue] & 0xFFFFFFFFFFFF);
  }

  std::sort(cTargets.begin(), cTargets.end());

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    std::vector<VMCore::PointerResult> cResults =
        _core->scanPointers(cTargets, startAddr, endAddr, maxOffset);

    NSMutableArray *matches =
        [NSMutableArray arrayWithCapacity:cResults.size()];
    for (const auto &res : cResults) {
      [matches addObject:@{
        @"addr" : @(res.address),
        @"val" : @(res.value),
        @"offset" : @(res.offset)
      }];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp)
        comp(matches);
    });
  });
}

#pragma mark - Pointer Search
- (void)scanPointerValue:(uint64_t)targetAddress
              rangeStart:(uint64_t)start
                rangeEnd:(uint64_t)end
              completion:
                  (void (^)(NSArray<VMScanResultItem *> *results))completion {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    NSMutableArray *results = [NSMutableArray array];
    size_t align = 8;
    [self scanMemoryWithStart:start
                          end:end
                    alignment:align
                      handler:^(void *buffer, size_t size, uint64_t baseAddr) {
                        size_t offset = 0;
                        if (baseAddr % align != 0) {
                          offset = align - (baseAddr % align);
                        }
                        uint8_t *ptr = (uint8_t *)buffer;
                        for (size_t i = offset; i + 8 <= size; i += align) {
                          uint64_t val = *(uint64_t *)(ptr + i);
                          val &= 0xFFFFFFFFFFFF; 
                          if (val == targetAddress) {
                            VMScanResultItem *item = [VMScanResultItem new];
                            item.address = baseAddr + i;
                            item.valueStr =
                                [NSString stringWithFormat:@"%llX", val];
                            @synchronized(results) {
                              [results addObject:item];
                            }
                            if (results.count >= 2000)
                              return;
                          }
                        }
                      }];
    if (completion)
      completion(results);
  });
}

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
                    completion:(void (^)(NSArray<NSArray *> *paths))comp {

  if (_core == nullptr || self.targetTask == MACH_PORT_NULL) {
    if (comp)
      comp(@[]);
    return;
  }

  if (maxPerLevel > 5000000)
    maxPerLevel = 5000000;

  if (!_cachedModules)
    _cachedModules = [self loadRemoteModules];

  std::vector<std::pair<uint64_t, uint64_t>> moduleRanges;
  NSMutableString *rangeLog = [NSMutableString string];
  int modCount = 0;

  if (selectedModule) {
    
    if (selectedModule.loadAddress > 0 && selectedModule.size > 0) {
      moduleRanges.push_back(
          {selectedModule.loadAddress,
           selectedModule.loadAddress + selectedModule.size});
      [rangeLog appendFormat:@"[%@: 0x%llX-0x%llX] ", selectedModule.name,
                             selectedModule.loadAddress,
                             selectedModule.loadAddress + selectedModule.size];
      modCount++;
    }
  } else {
    
    for (VMModuleInfo *m in _cachedModules) {
      if (m.loadAddress > 0 && m.size > 0) {
        moduleRanges.push_back({m.loadAddress, m.loadAddress + m.size});
        if (modCount < 5) {
          [rangeLog appendFormat:@"[%@: 0x%llX-0x%llX] ", m.name, m.loadAddress,
                                 m.loadAddress + m.size];
        }
        modCount++;
      }
    }
  }

  std::sort(moduleRanges.begin(), moduleRanges.end());

  VMCore::MemoryCore::IsBaseAddressCallback isBaseCallback =
      [moduleRanges](uint64_t addr) -> bool {
    
    auto it = std::upper_bound(
        moduleRanges.begin(), moduleRanges.end(), addr,
        [](uint64_t a, const std::pair<uint64_t, uint64_t> &r) {
          return a < r.first;
        });
    if (it != moduleRanges.begin()) {
      --it;
      if (addr >= it->first && addr < it->second) {
        return true;
      }
    }
    return false;
  };

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    
    int safeMaxL = (int)maxLevels;
    if (safeMaxL > 100)
      safeMaxL = 100;
    size_t safeMaxPL = (size_t)maxPerLevel;
    if (safeMaxPL > 5000000)
      safeMaxPL = 5000000;

    auto rawPaths = _core->autoSearchChain(
        targetAddress & 0xFFFFFFFFFFFF, heapStart, heapEnd, baseStart, baseEnd,
        safeMaxL, safeMaxPL, (uint32_t)maxOffset, autoSearchProgressBridge,
        (__bridge void *)progress, isBaseCallback);

    NSMutableArray *finalResults = [NSMutableArray array];

    std::vector<std::pair<uint64_t, uint64_t>> validRanges;
    for (VMModuleInfo *m in _cachedModules) {
      validRanges.push_back({m.loadAddress, m.loadAddress + m.size});
    }

    for (const auto &path : rawPaths) {
      uint64_t baseAddr = path.front();

      bool isValidBase = false;
      for (const auto &range : validRanges) {
        if (baseAddr >= range.first && baseAddr < range.second) {
          isValidBase = true;
          break;
        }
      }
      if (!isValidBase) {
        
        continue;
      }

      VMModuleMatch *match = [self findModuleForAddress:baseAddr];
      if (!match)
        continue; 

      NSMutableArray *objcPath = [NSMutableArray arrayWithCapacity:path.size()];
      for (uint64_t addr : path) {
        [objcPath addObject:@(addr)];
      }

      NSString *sym = [self symbolicateAddress:baseAddr];

      [finalResults addObject:@{
        @"path" : objcPath,
        @"base" : sym ?: @"Unknown",
        @"baseAddr" : @(baseAddr)
      }];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp)
        comp(finalResults);
    });
  });
}

#pragma mark - [v2.10] Pure ObjC Pointer Search (完整移植自 2.3.1)

typedef struct {
    uint64_t address;       
    int32_t parentIndex;    
} VMNode;

typedef struct {
    VMNode *nodes;          
    size_t count;           
    size_t capacity;        
} VMLevelBuffer;

static void VMLevelInit(VMLevelBuffer *lvl, size_t cap) {
    lvl->nodes = (VMNode *)malloc(cap * sizeof(VMNode));
    lvl->count = 0;
    lvl->capacity = cap;
}

static void VMLevelAdd(VMLevelBuffer *lvl, uint64_t addr, int32_t pIdx) {
    if (lvl->count >= lvl->capacity) {
        return;
    }
    lvl->nodes[lvl->count].address = addr;
    lvl->nodes[lvl->count].parentIndex = pIdx;
    lvl->count++;
}

static void VMLevelFree(VMLevelBuffer *lvl) {
    if (lvl->nodes) {
        free(lvl->nodes);
        lvl->nodes = NULL;
    }
    lvl->count = 0;
    lvl->capacity = 0;
}

static int vm_binary_search_first_ge(const uint64_t *arr, int n, uint64_t target) {
    int l = 0, r = n - 1;
    int result = -1;
    while (l <= r) {
        int mid = l + (r - l) / 2;
        if (arr[mid] >= target) {
            result = mid;
            r = mid - 1;
        } else {
            l = mid + 1;
        }
    }
    return result;
}

static int vm_compare_uint64(const void *a, const void *b) {
    uint64_t va = *(uint64_t *)a;
    uint64_t vb = *(uint64_t *)b;
    if (va < vb) return -1;
    if (va > vb) return 1;
    return 0;
}

- (size_t)_scanRawTargetsObjC:(uint64_t *)sortedTargets
                  targetCount:(size_t)tgtCount
                   rangeStart:(uint64_t)startAddr
                     rangeEnd:(uint64_t)endAddr
                    maxOffset:(uint32_t)maxOffset
                   matchesOut:(uint64_t *)outBuffer
                   maxMatches:(size_t)maxMatches
                usingSnapshot:(NSArray<VMRegionBlock *> *)snapshot {

    if (snapshot && snapshot.count > 0) {
        __block _Atomic size_t totalMatches = 0;

        dispatch_apply(snapshot.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t blockIdx) {
            
            if (blockIdx >= snapshot.count) return;

            VMRegionBlock *block = snapshot[blockIdx];
            uint64_t *ptrData = (uint64_t *)block.dataPointer;
            if (!ptrData) return;

            uint64_t effectiveEnd = (endAddr == 0) ? UINT64_MAX : endAddr;
            if (block.start >= effectiveEnd || (block.start + block.size) <= startAddr) return;
            size_t count64 = block.size / 8;

            for (size_t i = 0; i < count64; i++) {
                uint64_t val = ptrData[i];
                if (val < 0x100000000) continue;

                uint64_t stripped = val & 0xFFFFFFFFFFFF;
                int foundIdx = vm_binary_search_first_ge(sortedTargets, (int)tgtCount, stripped);

                if (foundIdx != -1) {
                    uint64_t target = sortedTargets[foundIdx];
                    if (target >= stripped) {
                        uint64_t diff = target - stripped;
                        if (diff <= maxOffset) {
                            if (diff > 128 && (diff % 4 != 0)) continue;

                            size_t idx = atomic_fetch_add_explicit(&totalMatches, 1, memory_order_relaxed);
                            if (idx < maxMatches) {
                                size_t base = idx * 3;
                                outBuffer[base + 0] = block.start + (i * 8);
                                outBuffer[base + 1] = stripped;
                                outBuffer[base + 2] = diff;
                            } else {
                                if (idx > maxMatches + 10000) return;
                            }
                        }
                    }
                }
            }
        });

        return atomic_load_explicit(&totalMatches, memory_order_relaxed);
    }
    return 0;
}

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
                        completion:(void (^)(NSArray<NSArray *> *paths))comp {

    if (self.targetTask == MACH_PORT_NULL) {
        if (comp) comp(@[]);
        return;
    }

    if (maxPerLevel > 1000000) maxPerLevel = 1000000;

    if (!_cachedModules) _cachedModules = [self loadRemoteModules];

    NSArray *localSnapshot = nil;

    @synchronized (self) {
        if (self.memorySnapshot && self.memorySnapshot.count > 0) {
            localSnapshot = [self.memorySnapshot copy];
        }
    }

    if (!localSnapshot || localSnapshot.count == 0) {
        if (comp) comp(@[]);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

        size_t levelBufSize = (maxLevels + 1) * sizeof(VMLevelBuffer);
        VMLevelBuffer *levels = (VMLevelBuffer *)malloc(levelBufSize);
        memset(levels, 0, levelBufSize);

        for (int i = 0; i <= maxLevels; i++) {
            size_t cap = (i == 0) ? 1 : maxPerLevel;
            VMLevelInit(&levels[i], cap);
            if (!levels[i].nodes) { free(levels); return; }
        }

        VMLevelAdd(&levels[0], targetAddress, -1);

        NSMutableArray *finalPaths = [NSMutableArray array];

        size_t outBufCap = maxPerLevel + 10000;

        uint64_t *scanOutput = (uint64_t *)malloc(outBufCap * 3 * sizeof(uint64_t));
        uint64_t *targetsBuf = (uint64_t *)malloc(maxPerLevel * sizeof(uint64_t));

        typedef struct { uint64_t val; int32_t originalIdx; } TargetMap;
        TargetMap *tMap = (TargetMap *)malloc(maxPerLevel * sizeof(TargetMap));

        for (int level = 0; level < maxLevels; level++) {
            VMLevelBuffer *currLvl = &levels[level];
            VMLevelBuffer *nextLvl = &levels[level + 1];

            if (currLvl->count == 0) break;

            for (size_t i = 0; i < currLvl->count; i++) {
                tMap[i].val = currLvl->nodes[i].address;
                tMap[i].originalIdx = (int32_t)i;
            }
            qsort(tMap, currLvl->count, sizeof(TargetMap), vm_compare_uint64);
            for (size_t i = 0; i < currLvl->count; i++) targetsBuf[i] = tMap[i].val;

            uint64_t sStart = (level == maxLevels - 1) ? baseStart : heapStart;
            uint64_t sEnd   = (level == maxLevels - 1) ? baseEnd : heapEnd;
            if (sStart == 0) sStart = heapStart;

            size_t foundCount = [self _scanRawTargetsObjC:targetsBuf
                                              targetCount:currLvl->count
                                               rangeStart:sStart
                                                 rangeEnd:sEnd
                                                maxOffset:maxOffset
                                               matchesOut:scanOutput
                                               maxMatches:outBufCap
                                            usingSnapshot:localSnapshot];

            size_t processCount = (foundCount > outBufCap) ? outBufCap : foundCount;

            if (progress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    progress(level + 1, processCount);
                });
            }

            int addedCount = 0;
            int baseFoundCount = 0;

            for (size_t i = 0; i < processCount; i++) {
                uint64_t ptrAddr = scanOutput[i*3 + 0];
                uint64_t val     = scanOutput[i*3 + 1];
                uint64_t off     = scanOutput[i*3 + 2];

                if (ptrAddr == 0) continue;

                uint64_t originTarget = val + off;

                int32_t parentIdx = -1;
                int l = 0, r = (int)currLvl->count - 1;
                while (l <= r) {
                    int mid = l + (r - l) / 2;
                    if (tMap[mid].val == originTarget) {
                        parentIdx = tMap[mid].originalIdx;
                        break;
                    } else if (tMap[mid].val < originTarget) {
                        l = mid + 1;
                    } else {
                        r = mid - 1;
                    }
                }

                if (parentIdx == -1) {
                    continue; 
                }

                VMModuleMatch *match = [self findModuleForAddress:ptrAddr];
                BOOL isBase = NO;
                if (match) {
                    if (selectedModule) {
                        if ([match.moduleName isEqualToString:selectedModule.name]) isBase = YES;
                    } else {
                        isBase = YES;
                    }
                }

                if (isBase) {
                    baseFoundCount++;
                    
                    NSMutableArray *fullPath = [NSMutableArray array];
                    [fullPath addObject: @(ptrAddr)];
                    int32_t currP = parentIdx;
                    for (int k = level; k >= 0; k--) {
                        if (currP < 0 || currP >= (int)levels[k].count) break;
                        VMNode pNode = levels[k].nodes[currP];
                        [fullPath addObject: @(pNode.address)];
                        currP = pNode.parentIndex;
                    }
                    NSString *sym = [self symbolicateAddress:ptrAddr];
                    [finalPaths addObject: @{
                        @"path": fullPath,
                        @"base": sym ?: @"Unknown",
                        @"baseAddr": @(ptrAddr)
                    }];
                } else {
                    if (level < maxLevels - 1) {
                        if (nextLvl->count < nextLvl->capacity) {
                            VMLevelAdd(nextLvl, ptrAddr, parentIdx);
                            addedCount++;
                        }
                    }
                }
            }
            
            (void)addedCount;
            (void)baseFoundCount;

            if (nextLvl->count == 0) break;
        }

        for (int i = 0; i <= maxLevels; i++) VMLevelFree(&levels[i]);
        free(levels);
        free(scanOutput);
        free(targetsBuf);
        free(tMap);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (comp) comp(finalPaths);
        });
    });
}

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
                          completion:(void (^)(NSArray<VMPointerChain *> *chains))comp {
  
  NSString *bid = self.currentBundleID;
  NSString *cachedAppName = nil;
  NSString *cachedAppVersion = nil;
  if (bid && bid.length > 0) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id proxy = [NSClassFromString(@"LSApplicationProxy") 
                performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:") 
                withObject:bid];
    if (proxy) {
      cachedAppName = [proxy performSelector:NSSelectorFromString(@"localizedName")];
      cachedAppVersion = [proxy performSelector:NSSelectorFromString(@"shortVersionString")];
      if (!cachedAppVersion) {
        cachedAppVersion = [proxy performSelector:NSSelectorFromString(@"bundleVersion")];
      }
    }
    #pragma clang diagnostic pop
  }
  
  NSArray *snapshotForOffsets = nil;
  @synchronized (self) {
    if (self.memorySnapshot && self.memorySnapshot.count > 0) {
      snapshotForOffsets = [self.memorySnapshot copy];
    }
  }
  
  [self autoSearchPointerChainObjC:targetAddress
                         heapStart:heapStart
                           heapEnd:heapEnd
                         baseStart:baseStart
                           baseEnd:baseEnd
                         maxLevels:maxLevels
                       maxPerLevel:maxPerLevel
                         maxOffset:maxOffset
                    selectedModule:selectedModule
                     progressBlock:progress
                        completion:^(NSArray<NSArray *> *paths) {
    
    NSMutableArray<VMPointerChain *> *chains = [NSMutableArray arrayWithCapacity:paths.count];
    
    for (NSDictionary *info in paths) {
      NSArray *addrPath = info[@"path"];
      uint64_t baseAddr = [info[@"baseAddr"] unsignedLongLongValue];
      
      VMModuleMatch *match = [self findModuleForAddress:baseAddr];
      if (!match) continue;
      
      VMPointerChain *chain = [[VMPointerChain alloc] init];
      chain.moduleName = match.moduleName;
      chain.baseOffset = match.offset;
      chain.lastKnownValue = targetAddress;
      chain.createdAt = [[NSDate date] timeIntervalSince1970];
      chain.bundleID = bid;
      chain.appName = cachedAppName;
      chain.appVersion = cachedAppVersion;
      chain.chainType = VMPointerChainTypeStatic;
      
      NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:addrPath.count];
      BOOL chainValid = YES;
      
      for (NSUInteger i = 0; i < addrPath.count - 1; i++) {
        uint64_t currAddr = [addrPath[i] unsignedLongLongValue];
        uint64_t nextTarget = [addrPath[i+1] unsignedLongLongValue];
        
        uint64_t val = 0;
        BOOL readSuccess = NO;
        
        if (snapshotForOffsets) {
          for (VMRegionBlock *block in snapshotForOffsets) {
            if (currAddr >= block.start && currAddr + 8 <= block.start + block.size) {
              uint64_t offset = currAddr - block.start;
              uint64_t *ptrData = (uint64_t *)block.dataPointer;
              if (ptrData) {
                val = ptrData[offset / 8] & 0xFFFFFFFFFFFF;
                readSuccess = YES;
              }
              break;
            }
          }
        }
        
        if (!readSuccess) {
          NSString *valStr = [self readAddress:currAddr type:VMDataTypeInt64];
          if (valStr && ![valStr isEqualToString:@"? ?"] && ![valStr isEqualToString:@"(Null)"]) {
            val = strtoull(valStr.UTF8String, NULL, 10) & 0xFFFFFFFFFFFF;
            readSuccess = YES;
          }
        }
        
        if (!readSuccess) {
          chainValid = NO;
          break;
        }
        
        int64_t off = (int64_t)nextTarget - (int64_t)val;
        [offsets addObject:@(off)];
      }
      
      if (!chainValid) continue;
      
      chain.offsets = offsets;
      chain.note = [NSString stringWithFormat:@"ObjC Lv.%lu", (unsigned long)addrPath.count];
      
      [chains addObject:chain];
    }
    
    if (comp) comp(chains);
  }];
}

#pragma mark - [v2.5] Enhanced Pointer Search with Dynamic Mode

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
                      completion:(void (^)(NSArray<VMPointerChain *> *chains))comp {

  if (_core == nullptr || self.targetTask == MACH_PORT_NULL) {
    if (comp) comp(@[]);
    return;
  }

  if (maxPerLevel > 5000000) maxPerLevel = 5000000;

  if (!_cachedModules) _cachedModules = [self loadRemoteModules];

  std::vector<std::pair<uint64_t, uint64_t>> dataSegmentRanges;
  if (selectedModule) {
    NSArray *segments = [self getDataSegmentsForModule:selectedModule];
    for (NSDictionary *seg in segments) {
      uint64_t start = [seg[@"start"] unsignedLongLongValue];
      uint64_t end = [seg[@"end"] unsignedLongLongValue];
      if (start > 0 && end > start) {
        dataSegmentRanges.push_back({start, end});
      }
    }
  } else {
    for (VMModuleInfo *m in _cachedModules) {
      if (m.loadAddress > 0 && m.size > 0) {
        NSArray *segments = [self getDataSegmentsForModule:m];
        for (NSDictionary *seg in segments) {
          uint64_t start = [seg[@"start"] unsignedLongLongValue];
          uint64_t end = [seg[@"end"] unsignedLongLongValue];
          if (start > 0 && end > start) {
            dataSegmentRanges.push_back({start, end});
          }
        }
      }
    }
  }
  std::sort(dataSegmentRanges.begin(), dataSegmentRanges.end());

  if (dataSegmentRanges.empty()) {
    if (selectedModule) {
      if (selectedModule.loadAddress > 0 && selectedModule.size > 0) {
        dataSegmentRanges.push_back({selectedModule.loadAddress, 
                                     selectedModule.loadAddress + selectedModule.size});
      }
    } else {
      for (VMModuleInfo *m in _cachedModules) {
        if (m.loadAddress > 0 && m.size > 0) {
          dataSegmentRanges.push_back({m.loadAddress, m.loadAddress + m.size});
        }
      }
      std::sort(dataSegmentRanges.begin(), dataSegmentRanges.end());
    }
  }

  VMCore::MemoryCore::IsBaseAddressCallback isBaseCallback;
  
  isBaseCallback = [dataSegmentRanges](uint64_t addr) -> bool {
    
    if (dataSegmentRanges.empty()) {
      return false;
    }
    auto it = std::upper_bound(
        dataSegmentRanges.begin(), dataSegmentRanges.end(), addr,
        [](uint64_t a, const std::pair<uint64_t, uint64_t> &r) {
          return a < r.first;
        });
    if (it != dataSegmentRanges.begin()) {
      --it;
      if (addr >= it->first && addr < it->second) {
        return true;
      }
    }
    return false;
  };

  NSString *bid = self.currentBundleID;
  NSString *cachedAppName = nil;
  NSString *cachedAppVersion = nil;
  if (bid && bid.length > 0) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id proxy = [NSClassFromString(@"LSApplicationProxy") 
                performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:") 
                withObject:bid];
    if (proxy) {
      cachedAppName = [proxy performSelector:NSSelectorFromString(@"localizedName")];
      cachedAppVersion = [proxy performSelector:NSSelectorFromString(@"shortVersionString")];
      if (!cachedAppVersion) {
        cachedAppVersion = [proxy performSelector:NSSelectorFromString(@"bundleVersion")];
      }
    }
    #pragma clang diagnostic pop
  }

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    int safeMaxL = (int)maxLevels;
    if (safeMaxL > 100) safeMaxL = 100;
    size_t safeMaxPL = (size_t)maxPerLevel;
    if (safeMaxPL > 5000000) safeMaxPL = 5000000;

    auto rawPaths = _core->autoSearchChain(
        targetAddress & 0xFFFFFFFFFFFF, heapStart, heapEnd, baseStart, baseEnd,
        safeMaxL, safeMaxPL, (uint32_t)maxOffset, autoSearchProgressBridge,
        (__bridge void *)progress, isBaseCallback);

    NSMutableArray<VMPointerChain *> *chains = [NSMutableArray arrayWithCapacity:rawPaths.size()];

    for (const auto &path : rawPaths) {
      if (path.size() < 2) continue;
      
      uint64_t baseAddr = path.front();
      
      BOOL isInDataSegment = NO;
      for (const auto &range : dataSegmentRanges) {
        if (baseAddr >= range.first && baseAddr < range.second) {
          isInDataSegment = YES;
          break;
        }
      }
      
      BOOL isStatic = NO;
      VMModuleMatch *match = nil;
      if (isInDataSegment) {
        match = [self findModuleForAddress:baseAddr];
        if (match) {
          isStatic = YES;
        }
      }
      
      if (!includeDynamic && !isStatic) {
        continue;
      }
      
      VMPointerChain *chain = [[VMPointerChain alloc] init];
      
      if (isStatic) {
        
        chain.chainType = VMPointerChainTypeStatic;
        chain.moduleName = match.moduleName;
        chain.baseOffset = match.offset;
        chain.heapBaseAddress = 0;
      } else {
        
        chain.chainType = VMPointerChainTypeDynamic;
        chain.moduleName = @"Heap";  
        chain.baseOffset = baseAddr; 
        chain.heapBaseAddress = baseAddr;
      }
      
      chain.lastKnownValue = targetAddress;
      chain.createdAt = [[NSDate date] timeIntervalSince1970];
      chain.bundleID = bid;
      chain.appName = cachedAppName;
      chain.appVersion = cachedAppVersion;
      
      NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:path.size()];
      BOOL snapshotValid = _core->hasSnapshot();  
      BOOL chainValid = YES;
      
      for (NSUInteger i = 0; i < path.size() - 1; i++) {
        uint64_t currAddr = path[i];
        uint64_t nextTarget = path[i + 1];
        
        uint64_t val = 0;
        BOOL readSuccess = NO;
        
        if (snapshotValid) {
          readSuccess = _core->readFromSnapshot(currAddr, &val, 8);
          if (readSuccess) {
            val = val & 0xFFFFFFFFFFFF;
          }
        }
        
        if (!readSuccess) {
          
          NSString *valStr = [self readAddress:currAddr type:VMDataTypeInt64];
          val = strtoull(valStr.UTF8String, NULL, 10) & 0xFFFFFFFFFFFF;
          
          if (snapshotValid) {
            chainValid = NO;
          }
        }
        
        int64_t off = (int64_t)nextTarget - (int64_t)val;
        [offsets addObject:@(off)];
      }
      chain.offsets = offsets;
      
      if (isStatic) {
        if (chainValid) {
          chain.note = [NSString stringWithFormat:@"Static Lv.%lu", (unsigned long)path.size()];
        } else {
          chain.note = [NSString stringWithFormat:@"Static Lv.%lu (Verify Required)", (unsigned long)path.size()];
        }
      } else {
        chain.note = [NSString stringWithFormat:@"Dynamic Lv.%lu (Session Only)", (unsigned long)path.size()];
      }
      
      [chains addObject:chain];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) comp(chains);
    });
  });
}

#pragma mark - [v2.9] Precise Pointer Chain Search

- (void)autoSearchPointerChainPrecise:(uint64_t)targetAddress
                            heapStart:(uint64_t)heapStart
                              heapEnd:(uint64_t)heapEnd
                            maxLevels:(NSInteger)maxLevels
                     firstLevelOffset:(uint32_t)firstLevelOffset
                     subsequentOffset:(uint32_t)subsequentOffset
                       selectedModule:(VMModuleInfo *)selectedModule
                        progressBlock:(void (^)(NSInteger level, NSUInteger count))progress
                           completion:(void (^)(NSArray<VMPointerChain *> *chains))comp {
  
  if (_core == nullptr || self.targetTask == MACH_PORT_NULL) {
    if (comp) comp(@[]);
    return;
  }
  
  if (!_cachedModules) _cachedModules = [self loadRemoteModules];
  
  std::vector<std::pair<uint64_t, uint64_t>> dataSegmentRanges;
  if (selectedModule) {
    NSArray *segments = [self getDataSegmentsForModule:selectedModule];
    for (NSDictionary *seg in segments) {
      uint64_t start = [seg[@"start"] unsignedLongLongValue];
      uint64_t end = [seg[@"end"] unsignedLongLongValue];
      if (start > 0 && end > start) {
        dataSegmentRanges.push_back({start, end});
      }
    }
  } else {
    for (VMModuleInfo *m in _cachedModules) {
      if (m.loadAddress > 0 && m.size > 0) {
        NSArray *segments = [self getDataSegmentsForModule:m];
        for (NSDictionary *seg in segments) {
          uint64_t start = [seg[@"start"] unsignedLongLongValue];
          uint64_t end = [seg[@"end"] unsignedLongLongValue];
          if (start > 0 && end > start) {
            dataSegmentRanges.push_back({start, end});
          }
        }
      }
    }
  }
  std::sort(dataSegmentRanges.begin(), dataSegmentRanges.end());
  
  if (dataSegmentRanges.empty()) {
    if (selectedModule && selectedModule.loadAddress > 0) {
      dataSegmentRanges.push_back({selectedModule.loadAddress, 
                                   selectedModule.loadAddress + selectedModule.size});
    } else {
      for (VMModuleInfo *m in _cachedModules) {
        if (m.loadAddress > 0 && m.size > 0) {
          dataSegmentRanges.push_back({m.loadAddress, m.loadAddress + m.size});
        }
      }
      std::sort(dataSegmentRanges.begin(), dataSegmentRanges.end());
    }
  }
  
  VMCore::MemoryCore::IsBaseAddressCallback isBaseCallback = 
    [dataSegmentRanges](uint64_t addr) -> bool {
      if (dataSegmentRanges.empty()) return false;
      auto it = std::upper_bound(
          dataSegmentRanges.begin(), dataSegmentRanges.end(), addr,
          [](uint64_t a, const std::pair<uint64_t, uint64_t> &r) {
            return a < r.first;
          });
      if (it != dataSegmentRanges.begin()) {
        --it;
        if (addr >= it->first && addr < it->second) {
          return true;
        }
      }
      return false;
    };
  
  NSString *bid = self.currentBundleID;
  NSString *cachedAppName = nil;
  NSString *cachedAppVersion = nil;
  if (bid && bid.length > 0) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id proxy = [NSClassFromString(@"LSApplicationProxy") 
                performSelector:NSSelectorFromString(@"applicationProxyForIdentifier:") 
                withObject:bid];
    if (proxy) {
      cachedAppName = [proxy performSelector:NSSelectorFromString(@"localizedName")];
      cachedAppVersion = [proxy performSelector:NSSelectorFromString(@"shortVersionString")];
      if (!cachedAppVersion) {
        cachedAppVersion = [proxy performSelector:NSSelectorFromString(@"bundleVersion")];
      }
    }
    #pragma clang diagnostic pop
  }
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    
    VMCore::MemoryCore::PointerSearchConfig config;
    config.firstLevelMaxOffset = firstLevelOffset;
    config.subsequentMaxOffset = subsequentOffset;
    config.preferAlignedOffsets = true;
    config.validatePointerTarget = true;
    config.maxResultsPerLevel = 100000;
    config.scoreAndSort = true;
    
    int safeMaxL = (int)maxLevels;
    if (safeMaxL > 100) safeMaxL = 100;
    
    auto rawResults = _core->autoSearchChainEnhanced(
        targetAddress & 0xFFFFFFFFFFFF, heapStart, heapEnd,
        config, safeMaxL, autoSearchProgressBridge,
        (__bridge void *)progress, isBaseCallback);
    
    NSMutableArray<VMPointerChain *> *chains = [NSMutableArray arrayWithCapacity:rawResults.size()];
    
    for (const auto &result : rawResults) {
      if (result.path.size() < 2) continue;
      
      uint64_t baseAddr = result.path.front();
      
      if (!result.isStatic) continue;
      
      VMModuleMatch *match = [self findModuleForAddress:baseAddr];
      if (!match) continue;
      
      VMPointerChain *chain = [[VMPointerChain alloc] init];
      chain.chainType = VMPointerChainTypeStatic;
      chain.moduleName = match.moduleName;
      chain.baseOffset = match.offset;
      chain.heapBaseAddress = 0;
      chain.lastKnownValue = targetAddress;
      chain.createdAt = [[NSDate date] timeIntervalSince1970];
      chain.bundleID = bid;
      chain.appName = cachedAppName;
      chain.appVersion = cachedAppVersion;
      
      NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:result.offsets.size()];
      for (const auto &off : result.offsets) {
        [offsets addObject:@(off)];
      }
      chain.offsets = offsets;
      
      chain.note = [NSString stringWithFormat:@"Static Lv.%lu (Score: %u)", 
                    (unsigned long)result.path.size(), result.totalScore];
      
      [chains addObject:chain];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) comp(chains);
    });
  });
}

#pragma mark - [v2.5] Forward Pointer Chain Search

static void forwardSearchProgressBridge(VMCore::MemoryCore::SearchProgress progress,
                                        void *userData) {
  if (!userData) return;
  void (^block)(NSInteger, NSUInteger) = (__bridge void (^)(NSInteger, NSUInteger))userData;
  block(progress.level, progress.foundCount);
}

- (BOOL)shouldScanModule:(VMModuleInfo *)module {
  if (!module || !module.name) return NO;
  
  NSString *name = module.name.lowercaseString;
  
  if ([name containsString:@"unity"] ||
      [name containsString:@"il2cpp"] ||
      [name containsString:@"unreal"] ||
      [name containsString:@"cocos"] ||
      [name containsString:@"gameassembly"]) {
    return YES;
  }
  
  if (_cachedModules && _cachedModules.count > 0) {
    VMModuleInfo *mainModule = _cachedModules.firstObject;
    if ([module.name isEqualToString:mainModule.name]) {
      return YES;
    }
  }
  
  return NO;
}

- (void)forwardSearchPointerChain:(uint64_t)targetAddress
                        maxDepth:(NSInteger)maxDepth
                       maxOffset:(uint32_t)maxOffset
                      maxResults:(NSUInteger)maxResults
                  selectedModule:(VMModuleInfo *)selectedModule
                   progressBlock:(void (^)(NSInteger level, NSUInteger foundCount))progress
                      completion:(void (^)(NSArray<VMPointerChain *> *chains))comp {
  
  if (_core == nullptr || self.targetTask == MACH_PORT_NULL) {
    if (comp) comp(@[]);
    return;
  }
  
  if (!_cachedModules) {
    _cachedModules = [self loadRemoteModules];
  }
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    
    std::vector<std::pair<uint64_t, uint64_t>> dataSegments;
    
    if (selectedModule) {
      
      NSArray *segments = [self getDataSegmentsForModule:selectedModule];
      for (NSDictionary *seg in segments) {
        uint64_t start = [seg[@"start"] unsignedLongLongValue];
        uint64_t end = [seg[@"end"] unsignedLongLongValue];
        if (start > 0 && end > start) {
          dataSegments.push_back({start, end});
        }
      }
      
      if (dataSegments.empty() && selectedModule.loadAddress > 0) {
        dataSegments.push_back({
          selectedModule.loadAddress,
          selectedModule.loadAddress + selectedModule.size
        });
      }
    } else {
      
      for (VMModuleInfo *mod in _cachedModules) {
        if (![self shouldScanModule:mod]) {
          continue;
        }
        
        NSArray *segments = [self getDataSegmentsForModule:mod];
        for (NSDictionary *seg in segments) {
          uint64_t start = [seg[@"start"] unsignedLongLongValue];
          uint64_t end = [seg[@"end"] unsignedLongLongValue];
          if (start > 0 && end > start) {
            dataSegments.push_back({start, end});
          }
        }
      }
    }
    
    if (dataSegments.empty()) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (comp) comp(@[]);
      });
      return;
    }
    
    void *userData = progress ? (__bridge void *)progress : nullptr;
    
    auto rawResults = _core->forwardSearchChain(
      targetAddress,
      dataSegments,
      (int)maxDepth,
      maxOffset,
      maxResults,
      progress ? forwardSearchProgressBridge : nullptr,
      userData
    );
    
    NSString *bid = self.currentBundleID;
    NSMutableArray<VMPointerChain *> *chains = [NSMutableArray arrayWithCapacity:rawResults.size()];
    
    for (const auto &result : rawResults) {
      
      VMModuleMatch *match = [self findModuleForAddress:result.baseAddress];
      if (!match) continue;
      
      VMPointerChain *chain = [[VMPointerChain alloc] init];
      chain.moduleName = match.moduleName;
      chain.baseOffset = match.offset;
      chain.bundleID = bid;
      
      NSMutableArray *offsets = [NSMutableArray arrayWithCapacity:result.offsets.size()];
      for (int64_t off : result.offsets) {
        [offsets addObject:@(off)];
      }
      chain.offsets = offsets;
      
      [chains addObject:chain];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) comp(chains);
    });
  });
}

- (NSArray<NSDictionary *> *)getDataSegmentsForModule:(VMModuleInfo *)module {
  NSMutableArray *segments = [NSMutableArray array];
  
  if (!module || module.loadAddress == 0) return segments;
  
  uint64_t base = module.loadAddress;
  
  struct mach_header_64 header;
  if (![self readMemory:base buffer:&header size:sizeof(header)]) {
    return segments;
  }
  
  if (header.magic != MH_MAGIC_64) {
    return segments;
  }
  
  uint64_t cmdOffset = base + sizeof(struct mach_header_64);
  
  uint64_t textVmaddr = 0;
  uint64_t tempCmdOffset = cmdOffset;
  for (uint32_t i = 0; i < header.ncmds; i++) {
    struct load_command lc;
    if (![self readMemory:tempCmdOffset buffer:&lc size:sizeof(lc)]) break;
    
    if (lc.cmd == LC_SEGMENT_64) {
      struct segment_command_64 seg;
      if ([self readMemory:tempCmdOffset buffer:&seg size:sizeof(seg)]) {
        if (strncmp(seg.segname, "__TEXT", 6) == 0) {
          textVmaddr = seg.vmaddr;
          break;
        }
      }
    }
    tempCmdOffset += lc.cmdsize;
  }
  
  int64_t slide = (int64_t)base - (int64_t)textVmaddr;
  
  for (uint32_t i = 0; i < header.ncmds; i++) {
    struct load_command lc;
    if (![self readMemory:cmdOffset buffer:&lc size:sizeof(lc)]) {
      break;
    }
    
    if (lc.cmd == LC_SEGMENT_64) {
      struct segment_command_64 seg;
      if ([self readMemory:cmdOffset buffer:&seg size:sizeof(seg)]) {
        
        if (strncmp(seg.segname, "__DATA", 6) == 0) {
          
          uint64_t segStart = seg.vmaddr + slide;
          uint64_t segEnd = segStart + seg.vmsize;
          
          [segments addObject:@{
            @"name": [NSString stringWithUTF8String:seg.segname],
            @"start": @(segStart),
            @"end": @(segEnd)
          }];
        }
      }
    }
    
    cmdOffset += lc.cmdsize;
  }
  
  return segments;
}

- (BOOL)readMemory:(uint64_t)address buffer:(void *)buffer size:(size_t)size {
  if (_core == nullptr) return NO;
  return _core->readMemory(address, buffer, size);
}

#pragma mark - Pointer Chain Resolution
- (uint64_t)resolvePointerChain:(uint64_t)baseAddress
                        offsets:(NSArray<NSNumber *> *)offsets {
  if (self.targetTask == MACH_PORT_NULL)
    return 0;

  if (baseAddress == 0) {
    [self loadRemoteModules];
    return 0;
  }

  uint64_t currentAddr = baseAddress;

  for (NSNumber *offsetNum in offsets) {
    
    int64_t offset = [offsetNum longLongValue];
    NSString *ptrStr = [self readAddress:currentAddr type:VMDataTypeInt64];

    if (!ptrStr || [ptrStr isEqualToString:@"0"] ||
        [ptrStr isEqualToString:@"? ?"]) {
      return 0;
    }

    uint64_t ptrValue = (uint64_t)strtoull([ptrStr UTF8String], NULL, 0);

    ptrValue = ptrValue & 0xFFFFFFFFFFFF; 

    currentAddr = (uint64_t)((int64_t)ptrValue + offset);
  }

  return currentAddr;
}

- (uint64_t)findModuleBaseAddress:(NSString *)moduleName {
  if (!_cachedModules) {
    _cachedModules = [self loadRemoteModules];
  }

  NSString *targetName = [moduleName lastPathComponent];

  for (VMModuleInfo *module in _cachedModules) {
    NSString *currentName = [module.name lastPathComponent];
    if ([currentName isEqualToString:targetName] ||
        [module.name isEqualToString:moduleName]) {
      return module.loadAddress;
    }
  }

  for (VMModuleInfo *module in _cachedModules) {
    if ([module.name containsString:targetName] ||
        [targetName containsString:module.name]) {
      return module.loadAddress;
    }
  }

  return 0;
}

- (void)reloadLockedPointers {
  if (!self.currentBundleID) {
    self.activeLockedPointers = [NSMutableArray array];
    return;
  }

  NSArray *loaded = [[NSClassFromString(@"VMLockManager")
      performSelector:@selector(shared)] loadLocksForApp:self.currentBundleID];
  self.activeLockedPointers = [loaded mutableCopy];
}

- (void)saveRVAPatches {
  if (!self.currentBundleID)
    return;

  std::vector<PatchItem> items;
  NSInteger index = 1;
  for (VMRVAPatch *p in self.rvaPatches) {
    
    if ([p.bundleID isEqualToString:self.currentBundleID]) {
      
      if (!p.fileName || p.fileName.length == 0) {
        p.fileName = [NSString stringWithFormat:@"Rva-%@-%ld.vmrva", self.currentBundleID, (long)index];
      }
      items.push_back([self patchToCpp:p]);
      index++;
    }
  }

  PatchCore::getInstance().savePatches([self.currentBundleID UTF8String],
                                       items);
}

- (void)loadRVAPatches {
  [self.rvaPatches removeAllObjects];
  if (!self.currentBundleID)
    return;

  std::vector<PatchItem> items =
      PatchCore::getInstance().loadPatches([self.currentBundleID UTF8String]);

  for (const auto &item : items) {
    [self.rvaPatches addObject:[self cppToPatch:item]];
  }
}

- (void)loadRVAPatchesForApp:(NSString *)bundleID {
  [self.rvaPatches removeAllObjects];
  if (!bundleID || bundleID.length == 0)
    return;

  std::vector<PatchItem> items =
      PatchCore::getInstance().loadPatches([bundleID UTF8String]);

  for (const auto &item : items) {
    VMRVAPatch *patch = [self cppToPatch:item];
    [self.rvaPatches addObject:patch];
  }
}

- (PatchItem)patchToCpp:(VMRVAPatch *)patch {
  PatchItem item;
  item.moduleName = patch.moduleName ? [patch.moduleName UTF8String] : "";
  item.offset = patch.offset;
  item.patchHex = patch.patchHex ? [patch.patchHex UTF8String] : "";
  item.originalHex = patch.originalHex ? [patch.originalHex UTF8String] : "";
  item.isOn = patch.isOn;
  item.note = patch.note ? [patch.note UTF8String] : "";
  item.author = patch.author ? [patch.author UTF8String] : "";
  item.isImported = patch.isImported;
  item.bundleID = patch.bundleID ? [patch.bundleID UTF8String] : "";
  item.appName = patch.appName ? [patch.appName UTF8String] : "";
  item.appVersion = patch.appVersion ? [patch.appVersion UTF8String] : "";
  item.createdAt = patch.createdAt;
  item.sortOrder = patch.sortOrder;
  item.fileName = patch.fileName ? [patch.fileName UTF8String] : "";
  return item;
}

- (VMRVAPatch *)cppToPatch:(const PatchItem &)item {
  VMRVAPatch *p = [[VMRVAPatch alloc] init];
  p.moduleName = [NSString stringWithUTF8String:item.moduleName.c_str()];
  p.offset = item.offset;
  p.patchHex = [NSString stringWithUTF8String:item.patchHex.c_str()];
  p.originalHex = [NSString stringWithUTF8String:item.originalHex.c_str()];
  p.isOn = item.isOn;
  p.note = [NSString stringWithUTF8String:item.note.c_str()];
  p.author = [NSString stringWithUTF8String:item.author.c_str()];
  p.isImported = item.isImported;
  p.bundleID = [NSString stringWithUTF8String:item.bundleID.c_str()];
  p.appName = [NSString stringWithUTF8String:item.appName.c_str()];
  p.appVersion = [NSString stringWithUTF8String:item.appVersion.c_str()];
  p.createdAt = item.createdAt;
  p.sortOrder = item.sortOrder;
  p.fileName = [NSString stringWithUTF8String:item.fileName.c_str()];
  return p;
}

- (BOOL)applyPatch:(VMRVAPatch *)patch enable:(BOOL)enable {
  if (!patch)
    return NO;

  PatchItem item = [self patchToCpp:patch];
  uint64_t base = self.mainModuleAddress;

  VMMemoryEngine *__unsafe_unretained rawSelf = self;
  auto writer = [rawSelf](uint64_t addr, const void *data, size_t len) -> bool {
    if (!rawSelf)
      return false;
    NSData *nsData = [NSData dataWithBytes:data length:len];
    return [rawSelf writeRawData:nsData toAddress:addr];
  };

  BOOL success =
      PatchCore::getInstance().applyPatch(item, enable, base, writer);
  if (success) {
    patch.isOn = enable;
    [self saveRVAPatches];
  }
  return success;
}

- (NSData *)readMemory:(uint64_t)address size:(NSUInteger)size {
  if (self.targetTask == MACH_PORT_NULL)
    return nil;

  mach_vm_size_t bytesRead = 0;

  mach_vm_address_t addr = (mach_vm_address_t)address;

  kern_return_t kr =
      mach_vm_read_overwrite(self.targetTask, addr, size, addr, &bytesRead);
  if (kr != KERN_SUCCESS || bytesRead != size)
    return nil;

  return [NSData dataWithBytes:(void *)addr length:size];
}

- (NSString *)hexStringFromData:(NSData *)data {
  if (!data)
    return nil;

  const unsigned char *bytes = (const unsigned char *)[data bytes];
  NSUInteger length = [data length];
  NSMutableString *hexString = [NSMutableString stringWithCapacity:length * 2];

  for (NSUInteger i = 0; i < length; i++) {
    [hexString appendFormat:@"%02X", bytes[i]];
  }

  return hexString;
}

#pragma mark - Core Scanning Logic
- (void)scanMemoryWithStart:(uint64_t)rangeStart
                        end:(uint64_t)rangeEnd
                  alignment:(size_t)align
                    handler:(void (^)(void *buffer, size_t size,
                                      uint64_t baseAddr))handler {
  if (self.targetTask == MACH_PORT_NULL) {
    return;
  }
  mach_vm_address_t address = rangeStart;
  mach_vm_size_t size = 0;
  vm_region_basic_info_data_64_t info;
  mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object_name;
  const mach_vm_size_t kChunkSize = 512 * 1024;
  while (true) {
    kern_return_t kr = mach_vm_region(
        self.targetTask, &address, &size, VM_REGION_BASIC_INFO_64,
        (vm_region_info_t)&info, &count, &object_name);
    if (kr != KERN_SUCCESS) {
      break;
    }
    if (rangeEnd > 0 && address >= rangeEnd) {
      break;
    }
    if (info.protection & VM_PROT_READ) {
      mach_vm_address_t scanStart = address;
      mach_vm_address_t scanEnd = address + size;
      if (scanStart < rangeStart)
        scanStart = rangeStart;
      if (rangeEnd > 0 && scanEnd > rangeEnd)
        scanEnd = rangeEnd;
      if (scanEnd > scanStart) {
        mach_vm_size_t totalScanSize = scanEnd - scanStart;
        mach_vm_address_t currentChunkAddr = scanStart;
        mach_vm_size_t bytesLeft = totalScanSize;
        while (bytesLeft > 0) {
          mach_vm_size_t currentReadSize =
              (bytesLeft > kChunkSize) ? kChunkSize : bytesLeft;
          void *buffer = malloc(currentReadSize);
          if (buffer) {
            mach_vm_size_t actualSize = currentReadSize;
            if (mach_vm_read_overwrite(
                    self.targetTask, currentChunkAddr, currentReadSize,
                    (mach_vm_address_t)buffer, &actualSize) == KERN_SUCCESS) {
              handler(buffer, (size_t)actualSize, currentChunkAddr);
            } else {
            }
            free(buffer);
          }
          currentChunkAddr += currentReadSize;
          bytesLeft -= currentReadSize;
        }
      }
    }
    address += size;
  }
}

#pragma mark - Signature Search

- (void)scanSignature:(NSString *)signature
           rangeStart:(uint64_t)rangeStart
             rangeEnd:(uint64_t)rangeEnd
           completion:
               (void (^)(NSArray<VMScanResultItem *> *results))completion {
  if (_core == nullptr || signature.length == 0) {
    if (completion)
      completion(@[]);
    return;
  }

  if (self.targetTask == MACH_PORT_NULL) {
    if (completion)
      completion(@[]);
    return;
  }

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    std::string sigStr = [signature UTF8String];
    auto rawResults = _core->scanSignature(sigStr, rangeStart, rangeEnd);

    NSMutableArray<VMScanResultItem *> *items =
        [NSMutableArray arrayWithCapacity:rawResults.size()];
    for (const auto &res : rawResults) {
      VMScanResultItem *item = [[VMScanResultItem alloc] init];
      item.address = res.address;
      item.type = VMDataTypeInt8;
      item.valueStr = @"-";
      [items addObject:item];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(items);
    });
  });
}

- (void)scanSignature:(NSString *)signature
           completion:
               (void (^)(NSArray<VMScanResultItem *> *results))completion {
  [self scanSignature:signature rangeStart:0 rangeEnd:0 completion:completion];
}

- (void)fastScanSignature:(NSString *)signature
                 inModule:(NSString *)moduleName
               completion:
                   (void (^)(NSArray<VMScanResultItem *> *results))completion {
  if (_core == nullptr || signature.length == 0) {
    if (completion)
      completion(@[]);
    return;
  }

  uint64_t startAddr = 0;
  uint64_t totalSize = 0;
  
  BOOL isVirtualModule = [moduleName isEqualToString:@"Heap"] || 
                         [moduleName isEqualToString:@"virtual"] ||
                         [moduleName isEqualToString:@"heap"];

  if (moduleName && moduleName.length > 0 && !isVirtualModule) {
    if (!_cachedModules) {
      _cachedModules = [self loadRemoteModules];
    }
    
    for (VMModuleInfo *m in _cachedModules) {
      if ([m.name isEqualToString:moduleName]) {
        startAddr = m.loadAddress;
        totalSize = m.size;
        break;
      }
    }
  }

  if (startAddr == 0 || totalSize == 0) {
    
    startAddr = 0x100000000ULL;
    totalSize = 0x300000000ULL; 
  }

  [self scanSignature:signature
           rangeStart:startAddr
             rangeEnd:startAddr + totalSize
           completion:completion];
}

- (uint64_t)getModuleSize:(NSString *)name {
  NSArray *mods = [self loadRemoteModules];
  for (VMModuleInfo *m in mods) {
    if ([m.name isEqualToString:name]) {
      return m.size;
    }
  }
  return 0;
}

#pragma mark - Task Validation & Reconnection

- (BOOL)validateTargetTask {
  
  if (self.targetTask == MACH_PORT_NULL)
    return NO;

  if (self.targetPid > 0 && kill(self.targetPid, 0) != 0) {
    
    self.targetTask = MACH_PORT_NULL;
    return NO;
  }
  return YES;
}

- (int)getPidForBundleID:(NSString *)bundleID {
  if (!bundleID)
    return 0;
  return VMCore::SystemCore::getInstance().getPidByBundleID(
      [bundleID UTF8String]);
}

- (void)takeGlobalSnapshot {
  
  _core->takeSnapshot(1024ULL * 1024 * 1024 * 8);
  
  [self takeGlobalSnapshotObjC];
}

- (void)takeGlobalSnapshotObjC {
  
  if (![self validateTargetTask]) {
    if (self.currentBundleID && self.currentBundleID.length > 0) {
      int pid = [self getPidForBundleID:self.currentBundleID];
      if (pid > 0) {
        [self attachToPid:pid];
      } else {
        return;
      }
    } else {
      return;
    }
  }
  
  if (self.targetTask == MACH_PORT_NULL) return;
  
  self.memorySnapshot = [NSMutableArray array];
  
  mach_vm_address_t address = 0x100000000;
  
  mach_vm_address_t endLimit = 0x800000000;
  
  mach_vm_size_t size;
  vm_region_basic_info_data_64_t info;
  mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object_name;
  
  uint64_t totalCaptured = 0;
  
  uint64_t MAX_SNAPSHOT_SIZE = (uint64_t)(1024 * 1024 * 1024 * 1.5);
  
  while (address < endLimit) {
    kern_return_t kr = mach_vm_region(self.targetTask, &address, &size, 
                                       VM_REGION_BASIC_INFO_64, 
                                       (vm_region_info_t)&info, &count, &object_name);
    if (kr != KERN_SUCCESS) break;
    
    if (!(info.protection & VM_PROT_READ)) {
      address += size;
      continue;
    }
    
    if (size > 256 * 1024 * 1024) {
      address += size;
      continue;
    }
    
    void *buffer = malloc(size);
    if (!buffer) {
      address += size;
      continue;
    }
    
    mach_vm_size_t readSize = size;
    if (mach_vm_read_overwrite(self.targetTask, address, size, 
                                (mach_vm_address_t)buffer, &readSize) == KERN_SUCCESS) {
      VMRegionBlock *block = [VMRegionBlock new];
      block.start = address;
      block.size = readSize;  
      
      block.memoryData = [NSData dataWithBytesNoCopy:buffer length:readSize freeWhenDone:YES];
      
      [self.memorySnapshot addObject:block];
      
      totalCaptured += readSize;
      
      if (totalCaptured > MAX_SNAPSHOT_SIZE) {
        break;
      }
    } else {
      free(buffer); 
    }
    address += size;
  }
}

- (void)clearSnapshot {
  _core->clearSnapshot();
  
  self.memorySnapshot = nil;
}

#pragma mark - [v2.5] 增量快照

- (void)saveBaselineSnapshot {
  _core->saveBaselineSnapshot();
}

- (void)clearBaselineSnapshot {
  _core->clearBaselineSnapshot();
}

- (BOOL)hasBaselineSnapshot {
  return _core->hasBaselineSnapshot();
}

- (NSArray<NSDictionary *> *)compareWithBaseline {
  auto diffs = _core->compareWithBaseline(8);  
  
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:diffs.size()];
  for (const auto &diff : diffs) {
    [result addObject:@{
      @"address": @(diff.address),
      @"size": @(diff.size)
    }];
  }
  return result;
}

#pragma mark - [v2.5] 快速模糊搜索

- (void)fastFuzzyInitWithCompletion:(void (^)(BOOL success, NSString *msg, NSUInteger addressCount))comp {
  if (self.targetTask == MACH_PORT_NULL) {
    if (comp) comp(NO, TR(@"Msg_Target_Not_Found"), 0);
    return;
  }
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    NSDate *startTime = [NSDate date];
    
    _core->fastFuzzyInit(self.searchRangeStart, self.searchRangeEnd);
    
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:startTime];
    size_t addressCount = _core->getFastFuzzyAddressCount();
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) {
        BOOL success = _core->hasFastFuzzySnapshot();
        if (success) {
          NSString *msg = [NSString stringWithFormat:TR(@"Mod_Fuzzy_Ready_Fmt"), elapsed];
          comp(YES, msg, (NSUInteger)addressCount);
        } else {
          comp(NO, TR(@"Msg_Snapshot_Failed"), 0);
        }
      }
    });
  });
}

- (BOOL)hasFastFuzzySnapshot {
  return _core->hasFastFuzzySnapshot();
}

- (void)fastFuzzyFilterWithMode:(VMFilterMode)mode
                       dataType:(VMDataType)type
                     completion:(void (^)(NSUInteger count, NSString *msg))comp {
  if (self.targetTask == MACH_PORT_NULL) {
    if (comp) comp(0, TR(@"Msg_Target_Not_Found"));
    return;
  }
  
  if (!_core->hasFastFuzzySnapshot()) {
    if (comp) comp(0, TR(@"Msg_No_Snapshot"));
    return;
  }
  
  self.currentDataType = type;
  
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    VMCore::DataType coreType = convertToCoreDataType(type);
    
    int filterMode = 5;  
    switch (mode) {
      case VMFilterModeDecreased:
        filterMode = 0;
        break;
      case VMFilterModeIncreased:
        filterMode = 1;
        break;
      case VMFilterModeChanged:
        filterMode = 5;
        break;
      case VMFilterModeUnchanged:
        filterMode = 6;
        break;
      default:
        filterMode = 5;
        break;
    }
    
    _core->fastFuzzyFilter(coreType, filterMode, self.searchRangeStart, self.searchRangeEnd);
    self.resultCount = _core->getResultCount();
    self.resultFilePath = self.resultCount > 0 ? [self getPathA] : nil;
    
    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp) {
        NSString *msg = self.resultCount > 0 ? TR(@"Msg_Search_Success") : TR(@"Msg_Search_No_Res");
        comp(self.resultCount, msg);
      }
    });
  });
}

- (void)clearFastFuzzySnapshot {
  _core->clearFastFuzzySnapshot();
}

- (void)clearAllData {
  NSString *rootPath = [VMStoragePathHelper vansonModDirectory];

  if ([[NSFileManager defaultManager] fileExistsAtPath:rootPath]) {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:rootPath error:&error];
  }

  [self.lockedItems removeAllObjects];
  [self.rvaPatches removeAllObjects];
  [self.activeLockedPointers removeAllObjects];
  [self.favoriteItems removeAllObjects];
  _cachedModules = nil;
  self.currentBundleID = nil;
  self.targetTask = MACH_PORT_NULL;
  self.targetPid = 0;

  [[NSNotificationCenter defaultCenter]
      postNotificationName:@"VMDataDidResetNotification"
                    object:nil];
}

- (void)saveFavorites {
  if (!self.currentBundleID) {
    return;
  }

}

#pragma mark - Batch Pointer Verification

- (void)batchVerifyPointerChains:(NSArray<VMPointerChain *> *)chains
                     targetInput:(NSString *)input
                        dataType:(VMDataType)type
                      completion:(void (^)(NSUInteger successCount))comp {

  if (self.targetTask == MACH_PORT_NULL || chains.count == 0) {
    if (comp)
      comp(0);
    return;
  }

  NSMutableDictionary<NSString *, NSNumber *> *moduleMap =
      [NSMutableDictionary dictionary];
  NSArray *modules = [self loadRemoteModules];
  for (VMModuleInfo *m in modules) {
    if (m.name)
      moduleMap[m.name] = @(m.loadAddress);
  }
  uint64_t mainBase = self.mainModuleAddress;

  BOOL isHexInput = [input hasPrefix:@"0x"];
  uint64_t targetHex = 0;
  if (isHexInput)
    targetHex = strtoull([input UTF8String], NULL, 16);
  double targetDouble = [input doubleValue];
  BOOL isFloat = (type == VMDataTypeFloat || type == VMDataTypeDouble);

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
    __block _Atomic NSUInteger successCounter = 0;

    NSUInteger count = chains.count;

    dispatch_apply(
        count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
        ^(size_t i) {
          
          VMPointerChain *chain = chains[i];

          uint64_t modBase = 0;
          NSString *modName = chain.moduleName;
          if (!modName || [modName isEqualToString:@"virtual"]) {
            modBase = mainBase;
          } else {
            NSNumber *n = moduleMap[modName];
            if (n)
              modBase = [n unsignedLongLongValue];
          }

          BOOL isValid = NO;
          NSString *resultVal = @"--"; 

          if (modBase > 0) {
            
            uint64_t current = modBase + chain.baseOffset;
            BOOL chainBroken = NO;

            for (NSNumber *off in chain.offsets) {
              uint64_t ptrVal = 0;
              
              if (_core->readMemory(current, &ptrVal, 8)) {
                current = (ptrVal & 0xFFFFFFFFFFFF) + [off longLongValue];
              } else {
                chainBroken = YES;
                break;
              }
            }

            if (!chainBroken) {
              
              if (isFloat) {
                double val = 0;
                if (type == VMDataTypeFloat) {
                  float f;
                  _core->readMemory(current, &f, 4);
                  val = f;
                } else {
                  _core->readMemory(current, &val, 8);
                }
                if (fabs(val - targetDouble) < self.floatTolerance)
                  isValid = YES;
                resultVal = [self formatValue:val type:type];
              } else {
                uint64_t val64 = 0;
                size_t sz = [self getSizeForType:type];
                _core->readMemory(current, &val64, sz);

                if (isHexInput) {
                  if ((val64 & 0xFFFFFFFF) == targetHex)
                    isValid = YES;
                } else {
                  
                  long long v = 0;
                  
                  if (sz == 1)
                    v = (int8_t)val64;
                  else if (sz == 2)
                    v = (int16_t)val64;
                  else if (sz == 4)
                    v = (int32_t)val64;
                  else
                    v = (int64_t)val64;

                  NSString *s = [NSString stringWithFormat:@"%lld", v];
                  if ([s isEqualToString:input])
                    isValid = YES;
                  resultVal = s;
                }
              }
            }
          }

          chain.isRuntimeValid = isValid;
          chain.runtimeValue = resultVal;

          if (isValid) {
            atomic_fetch_add_explicit(&successCounter, 1, memory_order_relaxed);
          }
        });

    NSUInteger finalCount =
        atomic_load_explicit(&successCounter, memory_order_relaxed);
    dispatch_async(dispatch_get_main_queue(), ^{
      if (comp)
        comp(finalCount);
    });
  });
}

@end
