#import "../../../include/VMLockEngine.h"
#import "../../../include/VMMemoryEngine.h"
#import "../../../include/VMPointerChain.h"
#import "../../../include/VMLocalization.h"
#import <UIKit/UIKit.h>
#import <os/lock.h>

#define TR(key) ([[VMLocalization shared] localizedString:key])

NSNotificationName const VMLockEngineStateChangedNotification = @"VMLockEngineStateChangedNotification";

@implementation VMLockItemState
@end

@interface VMLockEngine () {
    os_unfair_lock _stateLock;  
}

@property (nonatomic, strong) dispatch_source_t lockTimer;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
@property (nonatomic, assign) BOOL isRunning;

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, VMLockItemState *> *addressStates;
@property (nonatomic, strong) NSMutableDictionary<NSString *, VMLockItemState *> *pointerStates;

@end

@implementation VMLockEngine

+ (instancetype)shared {
    static VMLockEngine *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _stateLock = OS_UNFAIR_LOCK_INIT;
        _lockInterval = 0.5f;
        _addressStates = [NSMutableDictionary dictionary];
        _pointerStates = [NSMutableDictionary dictionary];
        _bgTask = UIBackgroundTaskInvalid;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onProcessChanged)
                                                     name:@"VMProcessChangedNotification"
                                                   object:nil];
        
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
    float interval = [def floatForKey:@"lockInterval"];
    if (interval > 0) {
        _lockInterval = interval;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopEngine];
}

#pragma mark - 引擎控制

- (void)startEngine {
    if (self.isRunning) return;
    
    if ([self totalLockCount] == 0) return;
    
    if ([VMMemoryEngine shared].targetTask == MACH_PORT_NULL) return;
    
    self.isRunning = YES;
    
    self.bgTask = [[UIApplication sharedApplication]
        beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:self.bgTask];
            self.bgTask = UIBackgroundTaskInvalid;
        }];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    self.lockTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    
    uint64_t intervalNS = (uint64_t)(self.lockInterval * NSEC_PER_SEC);
    dispatch_source_set_timer(self.lockTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 0),
                              intervalNS,
                              intervalNS / 10);  
    
    __weak VMLockEngine *weakSelf = self;
    dispatch_source_set_event_handler(self.lockTimer, ^{
        [weakSelf executeLockCycle];
    });
    
    dispatch_resume(self.lockTimer);
    
    [self notifyStateChanged];
}

- (void)stopEngine {
    if (!self.isRunning) return;
    
    self.isRunning = NO;
    
    if (self.lockTimer) {
        dispatch_source_cancel(self.lockTimer);
        self.lockTimer = nil;
    }
    
    if (self.bgTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    }
    
    [self notifyStateChanged];
}

- (void)onProcessChanged {
    
    [self stopEngine];
    
    os_unfair_lock_lock(&_stateLock);
    [self.addressStates removeAllObjects];
    [self.pointerStates removeAllObjects];
    os_unfair_lock_unlock(&_stateLock);
}

#pragma mark - 锁定间隔

- (void)setLockInterval:(float)lockInterval {
    if (lockInterval <= 0) lockInterval = 0.5f;
    _lockInterval = lockInterval;
    
    if (self.isRunning) {
        [self stopEngine];
        [self startEngine];
    }
}

#pragma mark - 地址锁定

- (void)addAddressLock:(uint64_t)address
                 value:(NSString *)value
                  type:(int)dataType
                  note:(NSString *)note {
    [self addAddressLock:address value:value type:dataType note:note stringEncoding:VMStringEncodingUTF8];
}

- (void)addAddressLock:(uint64_t)address
                 value:(NSString *)value
                  type:(int)dataType
                  note:(NSString *)note
        stringEncoding:(VMStringEncoding)encoding {
    
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (NSDictionary *item in eng.lockedItems) {
        if ([item[@"addr"] unsignedLongLongValue] == address) {
            return;  
        }
    }
    
    NSMutableDictionary *lockItem = [@{
        @"addr": @(address),
        @"val": value ?: @"0",
        @"type": @(dataType),
        @"stringEncoding": @(encoding),
        @"enabled": @(YES),
        @"note": note ?: @""
    } mutableCopy];
    if (dataType == VMDataTypeString) {
        NSString *current = [eng readStringAtAddress:address encoding:encoding maxBytes:8192];
        NSData *existing = [current dataUsingEncoding:VMFoundationStringEncoding(encoding) allowLossyConversion:NO];
        // Capture the readable byte span before the lock's first write.
        NSData *locked = [value dataUsingEncoding:VMFoundationStringEncoding(encoding) allowLossyConversion:NO];
        NSUInteger capacity = MIN(existing.length, locked.length);
        NSUInteger unit = encoding == VMStringEncodingUTF8 ? 1 : 2;
        if (existing && locked && existing.length == locked.length && capacity + unit <= 8192) {
            NSData *ending = [eng readRawMemory:address + capacity length:unit];
            const uint8_t *bytes = (const uint8_t *)ending.bytes;
            if (ending.length == unit && bytes[0] == 0 && (unit == 1 || bytes[1] == 0)) {
                capacity += unit;
                lockItem[@"stringTerminatorBytes"] = @(unit);
            }
        }
        lockItem[@"stringByteCapacity"] = @(capacity);
    }
    
    if (!eng.lockedItems) {
        eng.lockedItems = [NSMutableArray array];
    }
    [eng.lockedItems addObject:lockItem];
    
    os_unfair_lock_lock(&_stateLock);
    VMLockItemState *state = [[VMLockItemState alloc] init];
    state.identifier = address;
    state.itemType = VMLockItemTypeAddress;
    state.enabled = YES;
    state.lastWriteSuccess = NO;
    self.addressStates[@(address)] = state;
    os_unfair_lock_unlock(&_stateLock);
    
    if (!self.isRunning) {
        [self startEngine];
    }
    
    [self executeImmediateWrite:address value:value type:dataType];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VMLockItemAddedNotification" object:nil];
    [self notifyStateChanged];
}

- (void)removeAddressLock:(uint64_t)address {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    NSMutableArray *toRemove = [NSMutableArray array];
    for (NSDictionary *item in eng.lockedItems) {
        if ([item[@"addr"] unsignedLongLongValue] == address) {
            [toRemove addObject:item];
        }
    }
    [eng.lockedItems removeObjectsInArray:toRemove];
    
    os_unfair_lock_lock(&_stateLock);
    [self.addressStates removeObjectForKey:@(address)];
    os_unfair_lock_unlock(&_stateLock);
    
    if ([self totalLockCount] == 0) {
        [self stopEngine];
    }
    
    [self notifyStateChanged];
}

- (void)setAddressLock:(uint64_t)address enabled:(BOOL)enabled {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (NSMutableDictionary *item in eng.lockedItems) {
        if ([item[@"addr"] unsignedLongLongValue] == address) {
            item[@"enabled"] = @(enabled);
            break;
        }
    }
    
    os_unfair_lock_lock(&_stateLock);
    VMLockItemState *state = self.addressStates[@(address)];
    if (state) {
        state.enabled = enabled;
    }
    os_unfair_lock_unlock(&_stateLock);
    
    if (enabled) {
        for (NSDictionary *item in eng.lockedItems) {
            if ([item[@"addr"] unsignedLongLongValue] == address) {
                [self executeImmediateWrite:address
                                      value:item[@"val"]
                                       type:[item[@"type"] intValue]];
                break;
            }
        }
        
        if (!self.isRunning && [self activeLockCount] > 0) {
            [self startEngine];
        }
    }
    
    [self notifyStateChanged];
}

- (void)updateAddressLock:(uint64_t)address value:(NSString *)value {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (NSMutableDictionary *item in eng.lockedItems) {
        if ([item[@"addr"] unsignedLongLongValue] == address) {
            item[@"val"] = value;
            
            if ([item[@"enabled"] boolValue]) {
                [self executeImmediateWrite:address
                                      value:value
                                       type:[item[@"type"] intValue]];
            }
            break;
        }
    }
}

#pragma mark - 指针链锁定

- (void)setPointerLock:(NSString *)uniqueId enabled:(BOOL)enabled {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (VMPointerChain *chain in eng.activeLockedPointers) {
        if ([chain.uniqueId isEqualToString:uniqueId]) {
            chain.lockEnabled = enabled;
            
            os_unfair_lock_lock(&_stateLock);
            VMLockItemState *state = self.pointerStates[uniqueId];
            if (!state) {
                state = [[VMLockItemState alloc] init];
                state.identifier = [uniqueId hash];
                state.itemType = VMLockItemTypePointer;
                self.pointerStates[uniqueId] = state;
            }
            state.enabled = enabled;
            os_unfair_lock_unlock(&_stateLock);
            
            if (enabled) {
                [self executeImmediatePointerWrite:chain];
                
                if (!self.isRunning) {
                    [self startEngine];
                }
            }
            
            break;
        }
    }
    
    [self notifyStateChanged];
}

- (void)updatePointerLock:(NSString *)uniqueId value:(NSString *)value {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (VMPointerChain *chain in eng.activeLockedPointers) {
        if ([chain.uniqueId isEqualToString:uniqueId]) {
            chain.lockValue = value;
            
            if (chain.lockEnabled) {
                [self executeImmediatePointerWrite:chain];
            }
            break;
        }
    }
}

#pragma mark - 状态查询

- (NSArray<VMLockItemState *> *)allLockStates {
    os_unfair_lock_lock(&_stateLock);
    NSMutableArray *result = [NSMutableArray array];
    [result addObjectsFromArray:self.addressStates.allValues];
    [result addObjectsFromArray:self.pointerStates.allValues];
    os_unfair_lock_unlock(&_stateLock);
    return result;
}

- (VMLockItemState *)stateForAddress:(uint64_t)address {
    os_unfair_lock_lock(&_stateLock);
    VMLockItemState *state = self.addressStates[@(address)];
    os_unfair_lock_unlock(&_stateLock);
    return state;
}

- (NSUInteger)activeLockCount {
    NSUInteger count = 0;
    
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (NSDictionary *item in eng.lockedItems) {
        if ([item[@"enabled"] boolValue]) {
            count++;
        }
    }
    
    for (VMPointerChain *chain in eng.activeLockedPointers) {
        if (chain.lockEnabled) {
            count++;
        }
    }
    
    return count;
}

- (NSUInteger)totalLockCount {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    return eng.lockedItems.count + eng.activeLockedPointers.count;
}

#pragma mark - 批量操作

- (void)disableAllLocks {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (NSMutableDictionary *item in eng.lockedItems) {
        item[@"enabled"] = @(NO);
    }
    
    for (VMPointerChain *chain in eng.activeLockedPointers) {
        chain.lockEnabled = NO;
    }
    
    os_unfair_lock_lock(&_stateLock);
    for (VMLockItemState *state in self.addressStates.allValues) {
        state.enabled = NO;
    }
    for (VMLockItemState *state in self.pointerStates.allValues) {
        state.enabled = NO;
    }
    os_unfair_lock_unlock(&_stateLock);
    
    [self stopEngine];
    
    [self notifyStateChanged];
}

- (void)enableAllLocks {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    
    for (NSMutableDictionary *item in eng.lockedItems) {
        item[@"enabled"] = @(YES);
    }
    
    for (VMPointerChain *chain in eng.activeLockedPointers) {
        chain.lockEnabled = YES;
    }
    
    os_unfair_lock_lock(&_stateLock);
    for (VMLockItemState *state in self.addressStates.allValues) {
        state.enabled = YES;
    }
    for (VMLockItemState *state in self.pointerStates.allValues) {
        state.enabled = YES;
    }
    os_unfair_lock_unlock(&_stateLock);
    
    [self startEngine];
    
    [self notifyStateChanged];
}

#pragma mark - 核心锁定循环

- (void)executeLockCycle {
    VMMemoryEngine *eng = [VMMemoryEngine shared];
    mach_port_t task = eng.targetTask;
    if (task == MACH_PORT_NULL) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self stopEngine];
        });
        return;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    NSArray *addrLocks = [[VMMemoryEngine shared].lockedItems copy];
    for (NSDictionary *item in addrLocks) {
        if (![item[@"enabled"] boolValue]) continue;
        
        uint64_t addr = [item[@"addr"] unsignedLongLongValue];
        NSString *val = item[@"val"];
        VMDataType type = (VMDataType)[item[@"type"] intValue];
        
        BOOL success = type == VMDataTypeString
            ? [self writeStringLockItem:item value:val]
            : [eng writeAddress:addr value:val type:type];
        
        os_unfair_lock_lock(&_stateLock);
        VMLockItemState *state = self.addressStates[@(addr)];
        if (state) {
            state.lastWriteSuccess = success;
            state.lastWriteTime = now;
        }
        os_unfair_lock_unlock(&_stateLock);
    }
    
    static NSUInteger failureCount = 0;
    NSArray *pointerLocks = [[VMMemoryEngine shared].activeLockedPointers copy];
    
    for (VMPointerChain *chain in pointerLocks) {
        if (!chain.lockEnabled) continue;
        
        uint64_t modBase = 0;
        if ([chain.moduleName isEqualToString:@"virtual"]) {
            modBase = [VMMemoryEngine shared].mainModuleAddress;
        } else {
            modBase = [[VMMemoryEngine shared] findModuleBaseAddress:chain.moduleName];
        }
        
        if (modBase == 0) {
            failureCount++;
            if (failureCount > 5) {
                [[VMMemoryEngine shared] loadRemoteModules];
                failureCount = 0;
            }
            
            os_unfair_lock_lock(&_stateLock);
            VMLockItemState *state = self.pointerStates[chain.uniqueId];
            if (state) {
                state.lastWriteSuccess = NO;
            }
            os_unfair_lock_unlock(&_stateLock);
            continue;
        }
        
        uint64_t startAddr = modBase + chain.baseOffset;
        uint64_t finalAddr = [[VMMemoryEngine shared] resolvePointerChain:startAddr
                                                                  offsets:chain.offsets];
        
        if (finalAddr > 0) {
            NSString *valToWrite = chain.lockValue ?: @"0";
            VMDataType type = (chain.lockType == 0) ? VMDataTypeInt32 : (VMDataType)chain.lockType;
            [[VMMemoryEngine shared] writeAddress:finalAddr value:valToWrite type:type];
            
            os_unfair_lock_lock(&_stateLock);
            VMLockItemState *state = self.pointerStates[chain.uniqueId];
            if (state) {
                state.lastWriteSuccess = YES;
                state.lastWriteTime = now;
            }
            os_unfair_lock_unlock(&_stateLock);
        }
    }
}

#pragma mark - 即时写入

- (BOOL)writeStringLockItem:(NSDictionary *)item value:(NSString *)value {
    if (!item) return NO;
    VMMemoryEngine *engine = [VMMemoryEngine shared];
    uint64_t address = [item[@"addr"] unsignedLongLongValue];
    VMStringEncoding encoding = (VMStringEncoding)[item[@"stringEncoding"] unsignedIntegerValue];
    NSNumber *capacity = item[@"stringByteCapacity"];
    if (!capacity) {
        // Compatibility for address locks created before encoding metadata.
        NSString *current = [engine readStringAtAddress:address encoding:encoding maxBytes:8192];
        NSData *existing = [current dataUsingEncoding:VMFoundationStringEncoding(encoding) allowLossyConversion:NO];
        if (!existing) return NO;
        capacity = @(existing.length);
        if ([item isKindOfClass:NSMutableDictionary.class])
            ((NSMutableDictionary *)item)[@"stringByteCapacity"] = capacity;
    }
    NSUInteger terminator = [item[@"stringTerminatorBytes"] unsignedIntegerValue];
    if (terminator > capacity.unsignedIntegerValue ||
        [value lengthOfBytesUsingEncoding:VMFoundationStringEncoding(encoding)] > capacity.unsignedIntegerValue - terminator)
        return NO;
    return [engine writeStringAtAddress:address value:value encoding:encoding byteCapacity:capacity.unsignedIntegerValue];
}

- (void)executeImmediateWrite:(uint64_t)address value:(NSString *)value type:(int)dataType {
    if ([VMMemoryEngine shared].targetTask == MACH_PORT_NULL) return;
    VMMemoryEngine *engine = [VMMemoryEngine shared];
    NSDictionary *lockItem = nil;
    for (NSDictionary *item in engine.lockedItems) {
        if ([item[@"addr"] unsignedLongLongValue] == address) {
            lockItem = item;
            break;
        }
    }
    BOOL success = dataType == VMDataTypeString
        ? [self writeStringLockItem:lockItem value:value]
        : [engine writeAddress:address value:value type:(VMDataType)dataType];
    
    os_unfair_lock_lock(&_stateLock);
    VMLockItemState *state = self.addressStates[@(address)];
    if (state) {
        state.lastWriteSuccess = success;
        state.lastWriteTime = [[NSDate date] timeIntervalSince1970];
    }
    os_unfair_lock_unlock(&_stateLock);
}

- (void)executeImmediatePointerWrite:(VMPointerChain *)chain {
    if ([VMMemoryEngine shared].targetTask == MACH_PORT_NULL) return;
    
    uint64_t modBase = 0;
    if ([chain.moduleName isEqualToString:@"virtual"]) {
        modBase = [VMMemoryEngine shared].mainModuleAddress;
    } else {
        modBase = [[VMMemoryEngine shared] findModuleBaseAddress:chain.moduleName];
    }
    
    if (modBase == 0) return;
    
    uint64_t startAddr = modBase + chain.baseOffset;
    uint64_t finalAddr = [[VMMemoryEngine shared] resolvePointerChain:startAddr
                                                              offsets:chain.offsets];
    
    if (finalAddr > 0) {
        NSString *valToWrite = chain.lockValue ?: @"0";
        VMDataType type = (chain.lockType == 0) ? VMDataTypeInt32 : (VMDataType)chain.lockType;
        [[VMMemoryEngine shared] writeAddress:finalAddr value:valToWrite type:type];
        
        os_unfair_lock_lock(&_stateLock);
        VMLockItemState *state = self.pointerStates[chain.uniqueId];
        if (state) {
            state.lastWriteSuccess = YES;
            state.lastWriteTime = [[NSDate date] timeIntervalSince1970];
        }
        os_unfair_lock_unlock(&_stateLock);
    }
}

#pragma mark - 通知

- (void)notifyStateChanged {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:VMLockEngineStateChangedNotification
                          object:self];
    });
}

@end
