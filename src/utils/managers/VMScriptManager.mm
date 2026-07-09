#import "VMScriptManager.h"
#import "../../core/ScriptCore.hpp"
#import "../../utils/helpers/VMUIHelper.h"
#import "include/VMLocalization.h"
#import "include/VMMemoryEngine.h"
#import <UIKit/UIKit.h>
#include <mach/mach.h>
#include <string>

#ifdef __cplusplus
extern "C" {
#endif
kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t,
                              boolean_t, vm_prot_t);
kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t, vm_offset_t,
                            mach_msg_type_number_t);
#ifdef __cplusplus
}
#endif

#define TR(key) ([[VMLocalization shared] localizedString:key])

@interface VMScriptManager ()
@property(nonatomic, strong) JSContext *context;
@property(nonatomic, strong) NSMutableString *consoleLog;
@end

@implementation VMScriptManager

+ (instancetype)shared {
  static VMScriptManager *s;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    s = [self new];
  });
  return s;
}

- (void)getSearchRangeStart:(uint64_t *)start
                        end:(uint64_t *)end
                    fromArg:(NSString *)argStart
                      toArg:(NSString *)argEnd {
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  std::string s1 = argStart ? [argStart UTF8String] : "";
  std::string s2 = argEnd ? [argEnd UTF8String] : "";
  std::string d1 = [def objectForKey:@"startAddr"]
                       ? [[def objectForKey:@"startAddr"] UTF8String]
                       : "";
  std::string d2 = [def objectForKey:@"endAddr"]
                       ? [[def objectForKey:@"endAddr"] UTF8String]
                       : "";

  VMCore::ScriptCore::getInstance().getSearchRange(s1, s2, d1, d2, *start,
                                                   *end);
}

- (uint8_t)coreTypeFromStr:(NSString *)str {
  return (uint8_t)VMCore::ScriptCore::getInstance().typeFromStr(
      str ? [str UTF8String] : "");
}

- (VMDataType)typeFromStr:(NSString *)str {
  return (VMDataType)[self coreTypeFromStr:str];
}

#pragma mark - Script Execution & Polyfill

- (void)runScript:(NSString *)script
       completion:(void (^)(NSString *))completion {
  self.consoleLog = [NSMutableString string];

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [[VMMemoryEngine shared] switchContext:@"script"];
        
        self.context = [[JSContext alloc] init];
        self.context[@"vm"] = self;

        __weak VMScriptManager *weakSelf = self;

        self.context[@"print"] = ^(NSString *msg) {
          [weakSelf _internalLog:[NSString stringWithFormat:@"%@", msg]];
        };

        // H5GG 兼容别名 (与 VL2.7 一致)
        [self.context evaluateScript:@"var h5gg = vm; var H5GG = vm;"];
        
        // 注册 VL2.7 兼容别名 (searchNumber, clearResults 等)
        self.context[@"vm"][@"searchNumber"] = ^(NSString *val, NSString *type, NSString *start, NSString *end) {
          return [weakSelf search:val type:type from:start to:end];
        };
        self.context[@"vm"][@"clearResults"] = ^{
          [weakSelf clear];
        };
        self.context[@"vm"][@"searchNearby"] = ^(NSString *val, NSString *type, double range) {
          return [weakSelf nearby:val type:type range:range];
        };
        self.context[@"vm"][@"loadPlugin"] = ^(NSString *code, NSString *path) {
          [weakSelf _internalLog:@"Plugin not supported"];
        };
        
        // fuckbase 全局函数 (H5GG 兼容)
        self.context[@"fuckbase"] = ^(NSString *addr, int size) {
          [weakSelf setBaseAddress:addr];
        };

        self.context.exceptionHandler = ^(JSContext *context,
                                          JSValue *exception) {
          NSString *err = [exception toString];
          NSString *stack = [exception[@"stack"] toString];
          if (stack && stack.length > 0) {
            err = [NSString
                stringWithFormat:@"[Error] %@\n[Stack] %@", err, stack];
          } else {
            err = [NSString stringWithFormat:@"[Error] %@", err];
          }
          [weakSelf _internalLog:err];
        };

        [self _internalLog:@"--- Script Start ---"];
        [self.context evaluateScript:script];
        [self _internalLog:@"--- Script End ---"];

        dispatch_async(dispatch_get_main_queue(), ^{
          if (completion)
            completion(self.consoleLog);
        });
      });
}

- (void)_internalLog:(NSString *)msg {
  [self _rawLog:msg];
}

- (void)_rawLog:(NSString *)msg {
  if (self.consoleLog) {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSString *timestamp = [fmt stringFromDate:[NSDate date]];
    [self.consoleLog appendFormat:@"[%@] %@\n", timestamp, msg];
  }
}

#pragma mark - VMScriptExports Implementation

- (void)log:(NSString *)msg {
  [self _rawLog:msg];
}

- (void)toast:(NSString *)msg {
  dispatch_async(dispatch_get_main_queue(), ^{
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:TR(@"Script_Title_Default")
                         message:msg
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:TR(@"Btn_OK")
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
      for (UIWindowScene *scene in [UIApplication sharedApplication]
               .connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
          for (UIWindow *w in scene.windows) {
            if (w.isKeyWindow) {
              window = w;
              break;
            }
          }
        }
        if (window)
          break;
      }
    }
    if (!window) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      window = [[UIApplication sharedApplication] keyWindow];
#pragma clang diagnostic pop
    }
    if (window) {
      UIViewController *top = window.rootViewController;
      while (top.presentedViewController)
        top = top.presentedViewController;
      [top presentViewController:alert animated:YES completion:nil];
    }
  });
}

- (void)sleep:(double)seconds {
  [self _internalLog:[NSString
                         stringWithFormat:TR(@"Script_Sleeping_Fmt"), seconds]];
  usleep((useconds_t)(seconds * 1000000));
}

- (void)setFloatTolerance:(double)tolerance {
  [VMMemoryEngine shared].floatTolerance = tolerance;
  [self _internalLog:[NSString stringWithFormat:TR(@"Script_Log_Float_Tol_Fmt"),
                                                tolerance]];
}

- (void)setBaseAddress:(NSString *)addrStr {
  if (!addrStr || addrStr.length == 0)
    return;
  uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
  [VMMemoryEngine shared].mainModuleAddress = addr;
  [self _internalLog:[NSString stringWithFormat:TR(@"Script_Log_Base_Addr_Fmt"),
                                                addr]];
}

- (NSUInteger)search:(NSString *)val
                type:(NSString *)typeStr
                from:(NSString *)startArg
                  to:(NSString *)endArg {
  std::vector<std::string> args = {
      val ? [val UTF8String] : "", typeStr ? [typeStr UTF8String] : "",
      startArg ? [startArg UTF8String] : "", endArg ? [endArg UTF8String] : ""};

  VMCore::ScriptContext ctx;
  ctx.bridgeInstance = (__bridge void *)self;
  ctx.logFunc = [self](const std::string &m) {
    [self _internalLog:[NSString stringWithUTF8String:m.c_str()]];
  };

  uint64_t start, end;
  [self getSearchRangeStart:&start end:&end fromArg:startArg toArg:endArg];

  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  NSString *oldStart = [def objectForKey:@"startAddr"];
  NSString *oldEnd = [def objectForKey:@"endAddr"];
  [def setObject:[NSString stringWithFormat:@"0x%llX", start]
          forKey:@"startAddr"];
  [def setObject:[NSString stringWithFormat:@"0x%llX", end] forKey:@"endAddr"];

  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSUInteger resultCount = 0;
  uint8_t coreType = [self coreTypeFromStr:typeStr];
  BOOL useGroupMode =
      coreType != VMDataTypeString &&
      ([val containsString:@";"] || [val containsString:@"::"] ||
       [val containsString:@" "]);

  [[VMMemoryEngine shared] clearSession];
  [[VMMemoryEngine shared]
      scanMemoryWithMode:useGroupMode ? VMSearchModeGroup : VMSearchModeExact
                  valStr:val
            coreDataType:coreType
               fuzzyType:VMFuzzyUnchanged
            isNextSearch:NO
              completion:^(NSUInteger count, NSString *msg) {
                resultCount = count;
                dispatch_semaphore_signal(sema);
              }];

  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

  if (oldStart)
    [def setObject:oldStart forKey:@"startAddr"];
  else
    [def removeObjectForKey:@"startAddr"]; 

  if (oldEnd)
    [def setObject:oldEnd forKey:@"endAddr"];
  else
    [def removeObjectForKey:@"endAddr"];

  [self _internalLog:[NSString
                         stringWithFormat:TR(@"Script_Log_Search_Found_Fmt"),
                                          (unsigned long)resultCount]];

  return resultCount;
}

- (NSUInteger)searchGroup:(NSString *)val
                     type:(NSString *)typeStr
                     from:(NSString *)startArg
                       to:(NSString *)endArg {
  if (!val || val.length == 0) {
    [self _internalLog:TR(@"Script_Err_Search_Empty")];
    return 0;
  }
  
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  
  uint64_t start, end;
  [self getSearchRangeStart:&start end:&end fromArg:startArg toArg:endArg];
  NSUserDefaults *def = [NSUserDefaults standardUserDefaults];
  NSString *oldStart = [def objectForKey:@"startAddr"];
  NSString *oldEnd = [def objectForKey:@"endAddr"];
  [def setObject:[NSString stringWithFormat:@"0x%llX", start]
          forKey:@"startAddr"];
  [def setObject:[NSString stringWithFormat:@"0x%llX", end] forKey:@"endAddr"];
  
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSUInteger resultCount = 0;
  [eng clearSession];
  [eng scanMemoryWithMode:VMSearchModeGroup
                   valStr:val
             coreDataType:[self coreTypeFromStr:typeStr]
                fuzzyType:VMFuzzyUnchanged
             isNextSearch:NO
               completion:^(NSUInteger count, NSString *msg) {
                 resultCount = count;
                 dispatch_semaphore_signal(sema);
               }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  if (oldStart)
    [def setObject:oldStart forKey:@"startAddr"];
  if (oldEnd)
    [def setObject:oldEnd forKey:@"endAddr"];
  [self _internalLog:
            [NSString stringWithFormat:TR(@"Script_Log_Group_Search_Found_Fmt"),
                                       (unsigned long)resultCount]];
  return resultCount;
}

- (NSUInteger)searchBetween:(NSString *)minVal
                        max:(NSString *)maxVal
                       type:(NSString *)typeStr {
  if (!minVal || minVal.length == 0 || !maxVal || maxVal.length == 0) {
    [self _internalLog:@"[Error] searchBetween requires min and max values"];
    return 0;
  }

  NSString *rangeStr = [NSString stringWithFormat:@"%@,%@", minVal, maxVal];

  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSUInteger resultCount = 0;

  [[VMMemoryEngine shared] clearSession];
  [[VMMemoryEngine shared]
      scanMemoryWithMode:VMSearchModeBetween
                  valStr:rangeStr
            coreDataType:[self coreTypeFromStr:typeStr]
               fuzzyType:VMFuzzyUnchanged
            isNextSearch:NO
              completion:^(NSUInteger count, NSString *msg) {
                resultCount = count;
                dispatch_semaphore_signal(sema);
              }];

  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  [self _internalLog:[NSString stringWithFormat:@"Between search [%@~%@] found: %lu",
                      minVal, maxVal, (unsigned long)resultCount]];
  return resultCount;
}

- (NSUInteger)searchFuzzy:(NSString *)typeStr {
  return [self internalScan:@"0"
                       type:typeStr
                       mode:VMSearchModeFuzzy
                  fuzzyType:VMFuzzyChanged];
}

- (NSUInteger)searchSign:(NSString *)signature
                    from:(NSString *)startArg
                      to:(NSString *)endArg {
  if (!signature || signature.length == 0) {
    [self _internalLog:TR(@"Script_Err_Signature_Empty")];
    return 0;
  }
  uint64_t start, end;
  [self getSearchRangeStart:&start end:&end fromArg:startArg toArg:endArg];
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSUInteger count = 0;
  [[VMMemoryEngine shared] clearSession];
  [[VMMemoryEngine shared] scanSignature:signature
                              rangeStart:start
                                rangeEnd:end
                              completion:^(NSArray *results) {
                                count = results.count;
                                dispatch_semaphore_signal(sema);
                              }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  [self _internalLog:[NSString
                         stringWithFormat:TR(@"Script_Log_Signature_Found_Fmt"),
                                          (unsigned long)count]];
  return count;
}

- (NSUInteger)nearby:(NSString *)val
                type:(NSString *)typeStr
               range:(double)range {
  if (!val || val.length == 0)
    return 0;
  if (range <= 0)
    range = 50;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSUInteger resultCount = 0;
  [[VMMemoryEngine shared]
      scanNearbyWithTarget:val
                  dataType:[self typeFromStr:typeStr]
                     range:(uint64_t)range
                completion:^(NSUInteger count, NSString *msg) {
                  resultCount = count;
                  dispatch_semaphore_signal(sema);
                }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  [self
      _internalLog:[NSString stringWithFormat:TR(@"Script_Nearby_Result_Fmt"),
                                              val, (unsigned long)resultCount]];
  return resultCount;
}

- (void)refine:(NSString *)val
          type:(NSString *)typeStr
          mode:(NSString *)modeStr {
  if (!val || val.length == 0) {
    [self _internalLog:TR(@"Script_Err_Refine_Empty")];
    return;
  }
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSUInteger resultCount = 0;
  uint8_t coreType = [self coreTypeFromStr:typeStr];
  VMFuzzyType fuzzyType = VMFuzzyUnchanged;
  VMSearchMode searchMode = VMSearchModeExact;

  if ([modeStr isEqualToString:@"gt"]) {
    fuzzyType = VMFuzzyGreater;
    searchMode = VMSearchModeFuzzy;
  } else if ([modeStr isEqualToString:@"lt"]) {
    fuzzyType = VMFuzzyLess;
    searchMode = VMSearchModeFuzzy;
  } else if ([modeStr isEqualToString:@"chg"]) {
    fuzzyType = VMFuzzyChanged;
    searchMode = VMSearchModeFuzzy;
  } else if ([modeStr isEqualToString:@"inc"]) {
    fuzzyType = VMFuzzyIncreasedBy;
    searchMode = VMSearchModeFuzzy;
  } else if ([modeStr isEqualToString:@"dec"]) {
    fuzzyType = VMFuzzyDecreasedBy;
    searchMode = VMSearchModeFuzzy;
  } else if ([modeStr isEqualToString:@"eq"]) {
    fuzzyType = VMFuzzyUnchanged;
    searchMode = VMSearchModeExact;
  }

  // 联合搜索: 包含分隔符时使用 Group 模式 (与 VL2.7 一致)
  if ([modeStr isEqualToString:@"eq"] &&
      coreType != VMDataTypeString &&
      ([val containsString:@";"] || [val containsString:@"::"] || [val containsString:@" "])) {
    // 空格转分号，统一格式给 Group 引擎
    NSString *normalized = val;
    if ([val containsString:@" "] && ![val containsString:@";"] && ![val containsString:@"::"]) {
      normalized = [val stringByReplacingOccurrencesOfString:@" " withString:@";"];
    }
    
    dispatch_semaphore_t gs = dispatch_semaphore_create(0);
    [[VMMemoryEngine shared]
        scanMemoryWithMode:VMSearchModeGroup
                    valStr:normalized
              coreDataType:coreType
                 fuzzyType:VMFuzzyUnchanged
              isNextSearch:YES
                completion:^(NSUInteger count, NSString *msg) {
                  resultCount = count;
                  dispatch_semaphore_signal(gs);
                }];
    dispatch_semaphore_wait(gs, DISPATCH_TIME_FOREVER);
    [self _internalLog:[NSString stringWithFormat:TR(@"Script_Refine_Result_Fmt"),
                                                  val, (unsigned long)resultCount]];
    return;
  }

  [[VMMemoryEngine shared]
      scanMemoryWithMode:searchMode
                  valStr:val
            coreDataType:coreType
               fuzzyType:fuzzyType
            isNextSearch:YES
              completion:^(NSUInteger count, NSString *msg) {
                resultCount = count;
                dispatch_semaphore_signal(sema);
              }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  [self
      _internalLog:[NSString stringWithFormat:TR(@"Script_Refine_Result_Fmt"),
                                              val, (unsigned long)resultCount]];
}

- (NSUInteger)internalScan:(NSString *)val
                      type:(NSString *)typeStr
                      mode:(VMSearchMode)mode
                 fuzzyType:(VMFuzzyType)fuzzyType {
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  __block NSUInteger resultCount = 0;
  uint8_t coreType = [self coreTypeFromStr:typeStr];
  [[VMMemoryEngine shared] clearSession];
  [[VMMemoryEngine shared]
      scanMemoryWithMode:mode
                  valStr:val
            coreDataType:coreType
               fuzzyType:fuzzyType
            isNextSearch:NO
              completion:^(NSUInteger count, NSString *msg) {
                resultCount = count;
                dispatch_semaphore_signal(sema);
              }];
  dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
  [self _internalLog:[NSString stringWithFormat:@"Search found: %lu",
                                                (unsigned long)resultCount]];
  return resultCount;
}

- (long)getResultsCount {
  return (long)[VMMemoryEngine shared].resultCount;
}

- (NSArray *)getResults:(int)count skip:(int)skip {
  NSMutableArray *arr = [NSMutableArray array];
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  NSUInteger total = eng.resultCount;
  if (skip >= total)
    return @[];
  NSUInteger actualCount = MIN(count, total - skip);
  if (actualCount > 1000)
    [self _internalLog:TR(@"Script_Warn_Large_Data")];
  VMDataType defaultType = [VMMemoryEngine shared].currentDataType;
  for (NSUInteger i = 0; i < actualCount; i++) {
    NSUInteger idx = skip + i;
    VMScanResultItem *item = [eng getResultItemAtIndex:idx
                                              dataType:defaultType];
    if (item) {
      [arr addObject:@{
        @"address" : [NSString stringWithFormat:@"0x%llX", item.address],
        @"value" : item.valueStr ?: @"0",
        @"type" : @(item.type) 
      }];
    }
  }
  return arr;
}

- (NSArray *)getRangesList:(NSString *)name {
  NSArray<VMModuleInfo *> *modules =
      [[VMMemoryEngine shared] loadRemoteModules];
  NSMutableArray *res = [NSMutableArray array];
  for (VMModuleInfo *mod in modules) {
    if (!name || [name isEqualToString:@"0"] || [name length] == 0 ||
        [mod.name containsString:name]) {
      [res addObject:@{
        @"start" : [NSString stringWithFormat:@"0x%llX", mod.loadAddress],
        @"end" :
            [NSString stringWithFormat:@"0x%llX", mod.loadAddress + mod.size],
        @"name" : mod.name ?: @"",
        @"size" : [NSString stringWithFormat:@"0x%X", mod.size]
      }];
    }
  }
  return res;
}

- (void)clear {
  [[VMMemoryEngine shared] clearSession];
  [self _internalLog:TR(@"Script_Clear_Done")];
}

- (void)editAll:(NSString *)val
           type:(NSString *)typeStr
         filter:(NSString *)filter {
  VMDataType type = [self typeFromStr:typeStr];
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  NSUInteger total = eng.resultCount;

  if (total == 0)
    return;

  if (!filter || filter.length == 0 || [filter isEqualToString:@"-1"] || 
      [filter isEqualToString:@"undefined"] || [filter isEqualToString:@"null"]) {
    [eng batchModifyValues:val limit:0 type:type mode:0 items:nil];
    [self log:[NSString
                  stringWithFormat:TR(@"Script_Log_EditAll_Done_Fmt"), val]];
    return;
  }

  long long addrOffset = 0;
  NSString *criteria = filter;
  if ([filter containsString:@"//"]) {
    NSArray *parts = [filter componentsSeparatedByString:@"//"];
    criteria = parts[0];
    if (parts.count > 1) {
      NSString *offStr = parts[1];
      if ([offStr hasPrefix:@"+"])
        offStr = [offStr substringFromIndex:1];
      addrOffset = strtoll([offStr UTF8String], NULL, 0);
    }
  }

  const int chunkSize = 1000;
  int modifiedCount = 0;

  for (NSUInteger skip = 0; skip < total; skip += chunkSize) {
    NSArray *results = [self getResults:chunkSize skip:(int)skip];
    for (NSUInteger i = 0; i < results.count; i++) {
      NSDictionary *dict = results[i];
      NSUInteger currentIdx =
          skip + i + 1; 
      uint64_t addr = strtoull([dict[@"address"] UTF8String], NULL, 16);
      NSString *currentValue = dict[@"value"];

      BOOL match = NO;

      if ([criteria containsString:@"="]) {
        NSArray *range = [criteria componentsSeparatedByString:@"="];
        if (range.count == 2) {
          int start = [range[0] intValue];
          int end = [range[1] intValue];
          if (currentIdx >= start && currentIdx <= end)
            match = YES;
        }
      } else if ([criteria containsString:@"."] ||
                 [criteria containsString:@","]) {
        NSString *clean = [criteria stringByReplacingOccurrencesOfString:@"."
                                                              withString:@","];
        NSArray *indices = [clean componentsSeparatedByString:@","];
        for (NSString *idxStr in indices) {
          if ([idxStr intValue] == currentIdx) {
            match = YES;
            break;
          }
        }
      } else if ([criteria isEqualToString:@"-1"]) {
        match = YES;
      } else if (criteria.length > 0 &&
                 isdigit([criteria characterAtIndex:0])) {
        if ([criteria intValue] == currentIdx)
          match = YES;
      }

      if ([criteria containsString:@"@"] || [criteria containsString:@"&&"]) {
        NSString *suffix = nil;
        if ([criteria containsString:@"@"]) {
          suffix = [[criteria componentsSeparatedByString:@"@"] lastObject];
        } else {
          suffix = [[criteria componentsSeparatedByString:@"&&"] lastObject];
        }
        
        NSString *addrHex = [[dict[@"address"] lowercaseString]
            stringByReplacingOccurrencesOfString:@"0x"
                                      withString:@""];
        if ([addrHex hasSuffix:[suffix lowercaseString]]) {
          
          if ([criteria containsString:@"="] ||
              [criteria containsString:@"."] ||
              [criteria containsString:@","]) {
            
          } else {
            match = YES;
          }
        } else {
          match = NO;
        }
      }

      if ([criteria containsString:@"||"]) {
        NSString *vSearch =
            [[criteria componentsSeparatedByString:@"||"] lastObject];
        if (![currentValue containsString:vSearch]) {
          match = NO;
        } else if (!match && !([criteria containsString:@"="] ||
                               [criteria containsString:@"@"])) {
          
          match = YES;
        }
      }

      if (match) {
        uint64_t targetAddr = addr + addrOffset;
        [eng writeAddress:targetAddr value:val type:type];
        modifiedCount++;
      }
    }
  }

  [self _internalLog:[NSString stringWithFormat:@"EditAll '%@': %d modified", val, modifiedCount]];
}

- (void)editAll:(NSString *)val type:(NSString *)typeStr {
  [self editAll:val type:typeStr filter:nil];
}

- (NSString *)getValue:(NSString *)addrStr type:(NSString *)typeStr {
  std::vector<std::string> args = {addrStr ? [addrStr UTF8String] : "",
                                   typeStr ? [typeStr UTF8String] : ""};
  VMCore::ScriptContext ctx;
  ctx.bridgeInstance = (__bridge void *)self;

  VMCore::ScriptCore::getInstance().dispatchCommand("getValue", args, ctx);
  
  uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
  return [[VMMemoryEngine shared] readAddress:addr
                                         type:[self typeFromStr:typeStr]];
}

- (BOOL)setValue:(NSString *)addrStr
             val:(NSString *)val
            type:(NSString *)typeStr {
  uint64_t addr = strtoull([addrStr UTF8String], NULL, 16);
  [[VMMemoryEngine shared] writeAddress:addr
                                  value:val
                                   type:[self typeFromStr:typeStr]];
  return YES;
}

- (void)writeAll:(NSString *)val type:(NSString *)typeStr {
  [self editAll:val type:typeStr];
}

- (void)write:(NSString *)val type:(NSString *)typeStr offset:(int)index {
  if (!val || val.length == 0) {
    [self _internalLog:TR(@"Script_Err_Write_Empty")];
    return;
  }
  if (index < 0) {
    [self _internalLog:TR(@"Script_Err_Index_Negative")];
    return;
  }
  VMDataType type = [self typeFromStr:typeStr];
  VMScanResultItem *item = [[VMMemoryEngine shared] getResultItemAtIndex:index
                                                                dataType:type];
  if (item) {
    [[VMMemoryEngine shared] writeAddress:item.address value:val type:type];
    [self
        _internalLog:[NSString stringWithFormat:TR(@"Script_Write_Success_Fmt"),
                                                val, index, item.address]];
  } else {
    [self
        log:[NSString stringWithFormat:TR(@"Script_Err_Index_OutOfBounds_Fmt"),
                                       index,
                                       (unsigned long)[VMMemoryEngine shared]
                                           .resultCount]];
  }
}

- (NSString *)readAddress:(NSString *)addrStr type:(NSString *)typeStr {
  return [self getValue:addrStr type:typeStr];
}

- (void)writeAddress:(NSString *)addrStr
                 val:(NSString *)val
                type:(NSString *)typeStr {
  [self setValue:addrStr val:val type:typeStr];
}

- (long)getResultCount {
  return [self getResultsCount];
}

- (long)count {
  return [self getResultsCount];
}

- (void)lock:(NSString *)val type:(NSString *)typeStr index:(int)index {
  if (!val || val.length == 0) {
    [self _internalLog:TR(@"Script_Err_Lock_Val_Empty")];
    return;
  }
  
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  VMDataType type = [self typeFromStr:typeStr];
  
  if (index < 0) {
    [self _internalLog:TR(@"Script_Err_Index_Negative")];
    return;
  }
  
  NSUInteger total = eng.resultCount;
  if ((NSUInteger)index >= total) {
    [self _internalLog:[NSString stringWithFormat:TR(@"Script_Err_Index_OutOfBounds_Fmt"), index, (unsigned long)total]];
    return;
  }
  
  VMScanResultItem *item = [eng getResultItemAtIndex:index dataType:type];
  if (!item) {
    [self _internalLog:TR(@"Script_Err_Lock_NoResults")];
    return;
  }
  
  uint64_t addr = item.address;
  
  for (NSDictionary *lockItem in eng.lockedItems) {
    if ([lockItem[@"addr"] unsignedLongLongValue] == addr) {
      [self _internalLog:[NSString stringWithFormat:TR(@"Script_Lock_Already_Fmt"), [NSString stringWithFormat:@"0x%llx", addr]]];
      return;
    }
  }
  
  NSMutableDictionary *lockItem = [NSMutableDictionary dictionaryWithDictionary:@{
    @"addr" : @(addr),
    @"val" : val,
    @"type" : @(type),
    @"enabled" : @(YES),
    @"note" : TR(@"Script_Lock_Note")
  }];
  
  if (!eng.lockedItems) {
    eng.lockedItems = [NSMutableArray array];
  }
  [eng.lockedItems addObject:lockItem];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"VM_LockItemAdded"
                      object:nil];
  });
  
  [self _internalLog:[NSString stringWithFormat:TR(@"Script_Lock_Success_Fmt"), [NSString stringWithFormat:@"0x%llx", addr], val]];
}

- (void)unlock:(int)index {
  NSMutableArray *lockedItems = [VMMemoryEngine shared].lockedItems;
  
  if (index < 0) {
    [self _internalLog:TR(@"Script_Err_Index_Negative")];
    return;
  }
  
  if ((NSUInteger)index >= lockedItems.count) {
    [self _internalLog:[NSString stringWithFormat:TR(@"Script_Err_Unlock_Index_OutOfBounds_Fmt"), index, (unsigned long)lockedItems.count]];
    return;
  }
  
  [lockedItems removeObjectAtIndex:index];
  [self _internalLog:[NSString stringWithFormat:TR(@"Script_Unlock_Index_Success_Fmt"), index]];
}

- (void)lockAll:(NSString *)val type:(NSString *)typeStr filter:(NSString *)filter {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  NSUInteger total = eng.resultCount;
  
  if (total == 0) {
    [self _internalLog:TR(@"Script_Err_Lock_NoResults")];
    return;
  }
  
  VMDataType type = [self typeFromStr:typeStr];
  NSMutableSet *existingAddrs = [NSMutableSet set];
  for (NSDictionary *item in eng.lockedItems) {
    [existingAddrs addObject:item[@"addr"]];
  }
  
  if (!eng.lockedItems) {
    eng.lockedItems = [NSMutableArray array];
  }
  
  NSString *criteria = filter ?: @"-1";
  if (criteria.length == 0) criteria = @"-1";
  
  long long addrOffset = 0;
  if ([criteria containsString:@"//"]) {
    NSArray *parts = [criteria componentsSeparatedByString:@"//"];
    criteria = parts[0];
    if (parts.count > 1) {
      NSString *offStr = parts[1];
      if ([offStr hasPrefix:@"+"])
        offStr = [offStr substringFromIndex:1];
      addrOffset = strtoll([offStr UTF8String], NULL, 0);
    }
    if (criteria.length == 0) criteria = @"-1";
  }
  
  NSUInteger addedCount = 0;
  NSUInteger maxLock = MIN(total, (NSUInteger)1000);
  
  for (NSUInteger i = 0; i < maxLock; i++) {
    VMScanResultItem *item = [eng getResultItemAtIndex:i dataType:type];
    if (!item) continue;
    
    NSUInteger currentIdx = i + 1; 
    uint64_t addr = item.address;
    NSString *currentValue = item.valueStr ?: @"";
    
    BOOL match = NO;
    
    if ([criteria containsString:@"="]) {
      NSString *rangePart = criteria;
      if ([criteria containsString:@"@"]) {
        rangePart = [[criteria componentsSeparatedByString:@"@"] firstObject];
      }
      if ([criteria containsString:@"||"]) {
        rangePart = [[criteria componentsSeparatedByString:@"||"] firstObject];
      }
      NSArray *range = [rangePart componentsSeparatedByString:@"="];
      if (range.count == 2) {
        int start = [range[0] intValue];
        int end = [range[1] intValue];
        if (currentIdx >= start && currentIdx <= end)
          match = YES;
      }
    } else if ([criteria containsString:@"."] || [criteria containsString:@","]) {
      NSString *clean = [criteria stringByReplacingOccurrencesOfString:@"." withString:@","];
      if ([clean containsString:@"@"]) {
        clean = [[clean componentsSeparatedByString:@"@"] firstObject];
      }
      if ([clean containsString:@"||"]) {
        clean = [[clean componentsSeparatedByString:@"||"] firstObject];
      }
      NSArray *indices = [clean componentsSeparatedByString:@","];
      for (NSString *idxStr in indices) {
        if ([idxStr intValue] == currentIdx) {
          match = YES;
          break;
        }
      }
    } else if ([criteria isEqualToString:@"-1"]) {
      match = YES;
    } else if (criteria.length > 0 && isdigit([criteria characterAtIndex:0])) {
      if ([criteria intValue] == currentIdx)
        match = YES;
    }
    
    if ([criteria containsString:@"@"]) {
      NSString *suffix = [[criteria componentsSeparatedByString:@"@"] lastObject];
      if ([suffix containsString:@"||"]) {
        suffix = [[suffix componentsSeparatedByString:@"||"] firstObject];
      }
      NSString *addrHex = [[NSString stringWithFormat:@"%llx", addr] lowercaseString];
      if ([addrHex hasSuffix:[suffix lowercaseString]]) {
        if (!([criteria containsString:@"="] || [criteria containsString:@"."] || [criteria containsString:@","])) {
          match = YES;
        }
      } else {
        match = NO;
      }
    }
    
    if ([criteria containsString:@"||"]) {
      NSString *vSearch = [[criteria componentsSeparatedByString:@"||"] lastObject];
      if (![currentValue containsString:vSearch]) {
        match = NO;
      } else if (!match && !([criteria containsString:@"="] || [criteria containsString:@"@"])) {
        match = YES;
      }
    }
    
    if (match) {
      uint64_t targetAddr = addr + addrOffset;
      if ([existingAddrs containsObject:@(targetAddr)]) continue;
      NSMutableDictionary *lockItem = [NSMutableDictionary dictionaryWithDictionary:@{
        @"addr" : @(targetAddr),
        @"val" : val,
        @"type" : @(type),
        @"enabled" : @(YES),
        @"note" : TR(@"Script_Lock_Note")
      }];
      [eng.lockedItems addObject:lockItem];
      [existingAddrs addObject:@(targetAddr)];
      addedCount++;
    }
  }
  
  if (addedCount > 0) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [[NSNotificationCenter defaultCenter]
          postNotificationName:@"VM_LockItemAdded"
                        object:nil];
    });
  }
  
  [self _internalLog:[NSString stringWithFormat:TR(@"Script_LockAll_Success_Fmt"), (unsigned long)addedCount]];
}

- (void)unlockAll {
  NSMutableArray *lockedItems = [VMMemoryEngine shared].lockedItems;
  NSUInteger count = lockedItems.count;
  [lockedItems removeAllObjects];
  [self _internalLog:[NSString stringWithFormat:TR(@"Script_UnlockAll_Success_Fmt"), (unsigned long)count]];
}

#pragma mark - [v2.6] Pointer Chain API

- (uint64_t)_resolveModuleBase:(NSString *)moduleName {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (!moduleName || moduleName.length == 0 || [moduleName isEqualToString:@"virtual"]) {
    return eng.mainModuleAddress;
  }
  uint64_t base = [eng findModuleBaseAddress:moduleName];
  if (base == 0) {
    [eng loadRemoteModules];
    base = [eng findModuleBaseAddress:moduleName];
  }
  return base;
}

- (NSDictionary *)resolvePointer:(NSString *)moduleName
                      baseOffset:(NSString *)baseOffsetStr
                         offsets:(NSArray *)offsets
                            type:(NSString *)typeStr {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (eng.targetTask == MACH_PORT_NULL) {
    [self _internalLog:@"[Pointer] Error: No process attached"];
    return @{@"address": @"0x0", @"value": @"", @"success": @NO};
  }
  
  uint64_t modBase = [self _resolveModuleBase:moduleName];
  if (modBase == 0) {
    [self _internalLog:[NSString stringWithFormat:@"[Pointer] Error: Module '%@' not found", moduleName ?: @"virtual"]];
    return @{@"address": @"0x0", @"value": @"", @"success": @NO};
  }
  
  uint64_t baseOffset = strtoull([baseOffsetStr UTF8String], NULL, 16);
  NSMutableArray<NSNumber *> *nsOffsets = [NSMutableArray array];
  for (id o in offsets) {
    if ([o isKindOfClass:[NSNumber class]]) {
      [nsOffsets addObject:o];
    } else {
      [nsOffsets addObject:@(strtoull([[o description] UTF8String], NULL, 0))];
    }
  }
  
  uint64_t finalAddr = [eng resolvePointerChain:(modBase + baseOffset) offsets:nsOffsets];
  if (finalAddr == 0) {
    [self _internalLog:@"[Pointer] Chain resolved to NULL"];
    return @{@"address": @"0x0", @"value": @"", @"success": @NO};
  }
  
  VMDataType type = [self typeFromStr:typeStr];
  NSString *val = [eng readAddress:finalAddr type:type];
  
  [self _internalLog:[NSString stringWithFormat:@"[Pointer] 0x%llX -> %@", finalAddr, val]];
  return @{
    @"address": [NSString stringWithFormat:@"0x%llX", finalAddr],
    @"value": val ?: @"",
    @"success": @YES
  };
}

- (BOOL)writePointer:(NSString *)moduleName
          baseOffset:(NSString *)baseOffsetStr
             offsets:(NSArray *)offsets
                 val:(NSString *)val
                type:(NSString *)typeStr {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (eng.targetTask == MACH_PORT_NULL) {
    [self _internalLog:@"[Pointer] Error: No process attached"];
    return NO;
  }
  
  uint64_t modBase = [self _resolveModuleBase:moduleName];
  if (modBase == 0) {
    [self _internalLog:[NSString stringWithFormat:@"[Pointer] Error: Module '%@' not found", moduleName ?: @"virtual"]];
    return NO;
  }
  
  uint64_t baseOffset = strtoull([baseOffsetStr UTF8String], NULL, 16);
  NSMutableArray<NSNumber *> *nsOffsets = [NSMutableArray array];
  for (id o in offsets) {
    if ([o isKindOfClass:[NSNumber class]]) {
      [nsOffsets addObject:o];
    } else {
      [nsOffsets addObject:@(strtoull([[o description] UTF8String], NULL, 0))];
    }
  }
  
  uint64_t finalAddr = [eng resolvePointerChain:(modBase + baseOffset) offsets:nsOffsets];
  if (finalAddr == 0) {
    [self _internalLog:@"[Pointer] Chain resolved to NULL, write aborted"];
    return NO;
  }
  
  VMDataType type = [self typeFromStr:typeStr];
  [eng writeAddress:finalAddr value:val type:type];
  [self _internalLog:[NSString stringWithFormat:@"[Pointer] Write 0x%llX = %@", finalAddr, val]];
  return YES;
}

- (void)lockPointer:(NSString *)moduleName
         baseOffset:(NSString *)baseOffsetStr
            offsets:(NSArray *)offsets
                val:(NSString *)val
               type:(NSString *)typeStr
               note:(NSString *)note {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (eng.targetTask == MACH_PORT_NULL) {
    [self _internalLog:@"[Pointer] Error: No process attached"];
    return;
  }
  
  uint64_t modBase = [self _resolveModuleBase:moduleName];
  if (modBase == 0) {
    [self _internalLog:[NSString stringWithFormat:@"[Pointer] Error: Module '%@' not found", moduleName ?: @"virtual"]];
    return;
  }
  
  uint64_t baseOffset = strtoull([baseOffsetStr UTF8String], NULL, 16);
  NSMutableArray<NSNumber *> *nsOffsets = [NSMutableArray array];
  for (id o in offsets) {
    if ([o isKindOfClass:[NSNumber class]]) {
      [nsOffsets addObject:o];
    } else {
      [nsOffsets addObject:@(strtoull([[o description] UTF8String], NULL, 0))];
    }
  }
  
  uint64_t finalAddr = [eng resolvePointerChain:(modBase + baseOffset) offsets:nsOffsets];
  if (finalAddr == 0) {
    [self _internalLog:@"[Pointer] Chain resolved to NULL, lock aborted"];
    return;
  }
  
  VMDataType type = [self typeFromStr:typeStr];
  
  for (NSDictionary *item in eng.lockedItems) {
    if ([item[@"addr"] unsignedLongLongValue] == finalAddr) {
      [self _internalLog:[NSString stringWithFormat:@"[Pointer] 0x%llX already locked", finalAddr]];
      return;
    }
  }
  
  if (!eng.lockedItems) eng.lockedItems = [NSMutableArray array];
  
  NSMutableDictionary *lockItem = [NSMutableDictionary dictionaryWithDictionary:@{
    @"addr" : @(finalAddr),
    @"val" : val,
    @"type" : @(type),
    @"enabled" : @(YES),
    @"note" : (note && note.length > 0) ? note : @"Script Pointer Lock"
  }];
  [eng.lockedItems addObject:lockItem];
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"VM_LockItemAdded" object:nil];
  });
  
  [self _internalLog:[NSString stringWithFormat:@"[Pointer] Locked 0x%llX = %@", finalAddr, val]];
}

#pragma mark - [v2.6] RVA Patch API

- (BOOL)patchRVA:(NSString *)moduleName
          offset:(NSString *)offsetStr
        patchHex:(NSString *)patchHex {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (eng.targetTask == MACH_PORT_NULL) {
    [self _internalLog:@"[RVA] Error: No process attached"];
    return NO;
  }
  
  uint64_t modBase = [self _resolveModuleBase:moduleName];
  if (modBase == 0) {
    [self _internalLog:[NSString stringWithFormat:@"[RVA] Error: Module '%@' not found", moduleName ?: @"virtual"]];
    return NO;
  }
  
  uint64_t offset = strtoull([offsetStr UTF8String], NULL, 16);
  uint64_t addr = modBase + offset;
  
  NSString *cleanHex = [[patchHex stringByReplacingOccurrencesOfString:@" " withString:@""]
                         stringByReplacingOccurrencesOfString:@"\n" withString:@""];
  NSData *data = [eng dataFromHexString:cleanHex];
  if (!data || data.length == 0) {
    [self _internalLog:@"[RVA] Error: Invalid patch hex"];
    return NO;
  }
  
  mach_vm_protect(eng.targetTask, addr, data.length, FALSE,
                  VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
  
  kern_return_t kr = mach_vm_write(eng.targetTask, addr,
                                    (vm_offset_t)data.bytes,
                                    (mach_msg_type_number_t)data.length);
  
  mach_vm_protect(eng.targetTask, addr, data.length, FALSE,
                  VM_PROT_READ | VM_PROT_EXECUTE);
  
  if (kr != KERN_SUCCESS) {
    
    BOOL fallback = [eng writeRawData:data toAddress:addr];
    if (!fallback) {
      [self _internalLog:[NSString stringWithFormat:@"[RVA] Write failed at 0x%llX (kern: %d)", addr, kr]];
      return NO;
    }
  }
  
  usleep(5000);
  NSData *readBack = [eng readRawMemory:addr length:data.length];
  BOOL verified = readBack && [readBack isEqualToData:data];
  
  [self _internalLog:[NSString stringWithFormat:@"[RVA] Patch 0x%llX (%@+0x%llX) = %@ %@",
                      addr, moduleName ?: @"virtual", offset, cleanHex,
                      verified ? @"✓" : @"(unverified)"]];
  return YES;
}

- (BOOL)restoreRVA:(NSString *)moduleName
            offset:(NSString *)offsetStr
       originalHex:(NSString *)originalHex {
  
  return [self patchRVA:moduleName offset:offsetStr patchHex:originalHex];
}

- (NSString *)readRVA:(NSString *)moduleName
               offset:(NSString *)offsetStr
               length:(int)length {
  VMMemoryEngine *eng = [VMMemoryEngine shared];
  if (eng.targetTask == MACH_PORT_NULL) {
    [self _internalLog:@"[RVA] Error: No process attached"];
    return @"";
  }
  
  uint64_t modBase = [self _resolveModuleBase:moduleName];
  if (modBase == 0) {
    [self _internalLog:[NSString stringWithFormat:@"[RVA] Error: Module '%@' not found", moduleName ?: @"virtual"]];
    return @"";
  }
  
  if (length <= 0 || length > 4096) {
    [self _internalLog:@"[RVA] Error: Invalid length (1-4096)"];
    return @"";
  }
  
  uint64_t offset = strtoull([offsetStr UTF8String], NULL, 16);
  uint64_t addr = modBase + offset;
  
  NSData *data = [eng readRawMemory:addr length:length];
  if (!data) {
    [self _internalLog:[NSString stringWithFormat:@"[RVA] Read failed at 0x%llX", addr]];
    return @"";
  }
  
  NSString *hex = [eng hexStringFromData:data];
  [self _internalLog:[NSString stringWithFormat:@"[RVA] Read 0x%llX (%d bytes) = %@", addr, length, hex]];
  return hex ?: @"";
}

@end
