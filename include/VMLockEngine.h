#ifndef VMLockEngine_h
#define VMLockEngine_h

#import <Foundation/Foundation.h>
#import "VMMemoryEngine.h"

NS_ASSUME_NONNULL_BEGIN

extern NSNotificationName const VMLockEngineStateChangedNotification;

typedef NS_ENUM(NSInteger, VMLockItemType) {
    VMLockItemTypeAddress = 0,   
    VMLockItemTypePointer = 1,   
    VMLockItemTypeSignature = 2  
};

@interface VMLockItemState : NSObject
@property (nonatomic, assign) uint64_t identifier;      
@property (nonatomic, assign) VMLockItemType itemType;
@property (nonatomic, assign) BOOL enabled;             
@property (nonatomic, assign) BOOL lastWriteSuccess;    
@property (nonatomic, assign) NSTimeInterval lastWriteTime;
@end

@interface VMLockEngine : NSObject

+ (instancetype)shared;

#pragma mark - 引擎控制

- (void)startEngine;

- (void)stopEngine;

@property (nonatomic, readonly) BOOL isRunning;

#pragma mark - 锁定间隔

@property (nonatomic, assign) float lockInterval;

#pragma mark - 地址锁定

- (void)addAddressLock:(uint64_t)address
                 value:(NSString *)value
                  type:(int)dataType
                  note:(nullable NSString *)note;
- (void)addAddressLock:(uint64_t)address
                 value:(NSString *)value
                  type:(int)dataType
                  note:(nullable NSString *)note
        stringEncoding:(VMStringEncoding)encoding;

- (void)removeAddressLock:(uint64_t)address;

- (void)setAddressLock:(uint64_t)address enabled:(BOOL)enabled;

- (void)updateAddressLock:(uint64_t)address value:(NSString *)value;

#pragma mark - 指针链锁定

- (void)setPointerLock:(NSString *)uniqueId enabled:(BOOL)enabled;

- (void)updatePointerLock:(NSString *)uniqueId value:(NSString *)value;

#pragma mark - 状态查询

- (NSArray<VMLockItemState *> *)allLockStates;

- (nullable VMLockItemState *)stateForAddress:(uint64_t)address;

@property (nonatomic, readonly) NSUInteger activeLockCount;

#pragma mark - 批量操作

- (void)disableAllLocks;

- (void)enableAllLocks;

@end

NS_ASSUME_NONNULL_END

#endif /* VMLockEngine_h */
