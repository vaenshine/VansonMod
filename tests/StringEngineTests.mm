#import <UIKit/UIKit.h>
#import "include/VMMemoryEngine.h"
#import "include/VMLockEngine.h"
#import "src/ui/memory/VMStringMemorySession.h"
#import <objc/runtime.h>
#include <sys/mman.h>
#include <unistd.h>

static NSUInteger checks = 0;
@interface VMLockEngine (StringEngineTestAccess)
- (void)executeLockCycle;
@end
static void Check(BOOL value, const char *message) {
  if (!value) { fprintf(stderr, "FAIL: %s\n", message); fflush(stderr); exit(1); }
  checks++;
}

static void RunStringEngineTests(void) {
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  Check([engine attachToPid:getpid()], "engine attaches only to test process");
  NSUInteger page = (NSUInteger)getpagesize();
  uint8_t *region = (uint8_t *)mmap(NULL, page * 3, PROT_READ | PROT_WRITE,
      MAP_PRIVATE | MAP_ANON, -1, 0);
  Check(region != MAP_FAILED, "allocate bounded self-memory fixture");
  Check(mprotect(region + page * 2, page, PROT_NONE) == 0, "protect fixture boundary");
  // Drive the real lock cycle synchronously to keep fixture mutations deterministic.
  Method startMethod = class_getInstanceMethod(VMLockEngine.class, @selector(startEngine));
  IMP noopStart = imp_implementationWithBlock(^(VMLockEngine *lockEngine) {});
  IMP originalStart = method_setImplementation(startMethod, noopStart);
  for (NSNumber *choice in @[@(VMStringEncodingUTF8), @(VMStringEncodingUTF16LE), @(VMStringEncodingUTF16BE)]) {
    VMStringEncoding encoding = (VMStringEncoding)choice.unsignedIntegerValue;
    NSStringEncoding foundation = VMFoundationStringEncoding(encoding);
    NSUInteger unit = encoding == VMStringEncodingUTF8 ? 1 : 2;
    NSString *text = @"Vanson中文😀";
    NSData *encoded = [text dataUsingEncoding:foundation];
    for (NSUInteger alignment = 0; alignment < 8; alignment++) {
      uint8_t *location = region + 64 + alignment;
      memset(location, 0xab, 128);
      memcpy(location, encoded.bytes, encoded.length);
      memset(location + encoded.length, 0, unit);
      uint64_t address = (uint64_t)location;
      Check([[engine readStringAtAddress:address encoding:encoding maxBytes:256] isEqualToString:text],
          "live engine decodes Unicode/emoji at every byte alignment");
      NSData *replacement = [@"HELLO" dataUsingEncoding:foundation];
      Check([engine writeStringAtAddress:address value:@"HELLO" encoding:encoding],
          "live engine accepts explicitly encoded write");
      Check(!memcmp(location, replacement.bytes, replacement.length) &&
          !memcmp(location + replacement.length, (const uint8_t *)encoded.bytes + replacement.length,
              encoded.length - replacement.length), "encoded write preserves following bytes");
    }
    uint8_t *crossing = region + page - encoded.length / 2;
    memcpy(crossing, encoded.bytes, encoded.length);
    memset(crossing + encoded.length, 0, unit);
    Check([[engine readStringAtAddress:(uint64_t)crossing encoding:encoding maxBytes:256] isEqualToString:text],
        "live engine decodes across a readable page boundary");
    uint8_t *edge = region + page * 2 - encoded.length - unit;
    memcpy(edge, encoded.bytes, encoded.length);
    memset(edge + encoded.length, 0, unit);
    Check([[engine readStringAtAddress:(uint64_t)edge encoding:encoding maxBytes:256] isEqualToString:text],
        "live engine preserves terminated text immediately before protected page");
    edge = region + page * 2 - encoded.length;
    memcpy(edge, encoded.bytes, encoded.length);
    Check([[engine readStringAtAddress:(uint64_t)edge encoding:encoding maxBytes:256] isEqualToString:text],
        "live engine returns complete unterminated prefix before protected page");
    uint8_t *location = region + 512;
    memcpy(location, encoded.bytes, encoded.length);
    memset(location + encoded.length, 0, unit);
    NSString *prefix = @"Vanson中文";
    NSUInteger prefixBytes = [prefix lengthOfBytesUsingEncoding:foundation];
    Check([[engine readStringAtAddress:(uint64_t)location encoding:encoding maxBytes:prefixBytes + 1]
        isEqualToString:prefix], "byte cap never exposes a partial emoji");
    if (unit == 2) {
      Check([[engine readStringAtAddress:(uint64_t)location encoding:encoding maxBytes:prefixBytes + 3]
          isEqualToString:prefix], "odd UTF-16 byte cap drops incomplete surrogate pair");
    }
    memset(location, 0, unit);
    Check([[engine readStringAtAddress:(uint64_t)location encoding:encoding maxBytes:64] isEqualToString:@""],
        "live engine represents empty string without consuming adjacent memory");

    // Use the same captured callbacks as the production editor, with real Mach reads and writes.
    memcpy(location, encoded.bytes, encoded.length);
    memset(location + encoded.length, 0, unit);
    VMStringMemorySession *session = [VMStringMemorySession new];
    session.stringEncoding = encoding;
    session.targetIsValid = ^BOOL { return engine.targetPid == getpid(); };
    session.reader = ^NSData *(uint64_t address, NSUInteger length) {
      return [engine readRawMemory:address length:length];
    };
    session.writer = ^BOOL(uint64_t address, NSData *data) {
      return [engine writeRawData:data toAddress:address];
    };
    Check([session openStringAtAddress:(uint64_t)location error:NULL] &&
        [session.originalText isEqualToString:text], "editor session reads selected engine encoding");
    engine.stringEncoding = (VMStringEncoding)((encoding + 1) % 3);
    Check([session commitDraft:@"改😀" error:NULL] &&
        [[engine readStringAtAddress:(uint64_t)location encoding:encoding maxBytes:256] isEqualToString:@"改😀"],
        "existing editor keeps encoding after search option changes");
    Check([session undo:NULL] && !memcmp(location, encoded.bytes, encoded.length),
        "editor undo restores exact bytes through live engine transport");

    NSData *before = [NSData dataWithBytes:location length:encoded.length + unit];
    NSData *changed = [@"Test" dataUsingEncoding:foundation];
    memcpy(location, changed.bytes, changed.length);
    memset(location + changed.length, 0, unit);
    NSMutableDictionary *lock = [@{@"addr": @((uint64_t)location), @"type": @(VMDataTypeString),
        @"val": @"Test", @"stringEncoding": @(encoding), @"enabled": @NO,
        @"stringByteCapacity": @(changed.length)} mutableCopy];
    NSMutableDictionary *favorite = [lock mutableCopy];
    [engine.lockedItems addObject:lock];
    [engine.favoriteItems addObject:favorite];
    [engine rememberManualWriteUndoAtAddress:(uint64_t)location type:VMDataTypeString
        oldValue:text oldData:before newValue:@"Test" stringEncoding:encoding stringRangeMode:NO];
    VMMemoryWriteUndoItem *undo = [engine lastManualWriteUndoForAddress:(uint64_t)location type:VMDataTypeString];
    Check(undo.stringEncoding == encoding && !undo.stringRangeMode && [undo.oldValue isEqualToString:text],
        "manual undo stores readable Unicode and captured encoding");
    Check([engine undoLastManualWriteForAddress:(uint64_t)location type:VMDataTypeString] &&
        !memcmp(location, before.bytes, before.length), "manual undo verifies complete restored string span");
    Check([lock[@"val"] isEqualToString:text] && [favorite[@"val"] isEqualToString:text] &&
        [lock[@"stringEncoding"] unsignedIntegerValue] == encoding &&
        [favorite[@"stringEncoding"] unsignedIntegerValue] == encoding,
        "manual undo synchronizes corresponding lock and favorite values with captured encoding");
    Check([lock[@"stringByteCapacity"] unsignedIntegerValue] == before.length &&
        [favorite[@"stringByteCapacity"] unsignedIntegerValue] == before.length &&
        [lock[@"stringTerminatorBytes"] unsignedIntegerValue] == unit &&
        [favorite[@"stringTerminatorBytes"] unsignedIntegerValue] == unit,
        "manual undo restores confirmed byte capacity including terminator");
    memset(location, 'x', before.length);
    lock[@"val"] = @"raw lock marker";
    favorite[@"val"] = @"raw favorite marker";
    [engine rememberManualWriteUndoAtAddress:(uint64_t)location type:VMDataTypeString
        oldValue:[VMStringMemorySession escapedTextForData:before] oldData:before newValue:@"raw"
        stringEncoding:encoding stringRangeMode:YES];
    Check([engine undoLastManualWriteForAddress:(uint64_t)location type:VMDataTypeString] &&
        !memcmp(location, before.bytes, before.length), "raw range undo restores its original exact bytes");
    Check([lock[@"val"] isEqualToString:@"raw lock marker"] &&
        [favorite[@"val"] isEqualToString:@"raw favorite marker"],
        "raw range undo preserves independent single-string lock metadata");
    [engine.lockedItems removeObject:lock];
    [engine.favoriteItems removeObject:favorite];

    VMLockEngine *locker = [VMLockEngine shared];
    memcpy(location, before.bytes, before.length);
    uint8_t *neighbor = location + before.length;
    memset(neighbor, 0xa7, 8);
    [locker addAddressLock:(uint64_t)location value:text type:VMDataTypeString note:@"fixture"
        stringEncoding:encoding];
    NSDictionary *entry = engine.lockedItems.lastObject;
    Check([entry[@"stringEncoding"] unsignedIntegerValue] == encoding &&
        [entry[@"stringByteCapacity"] unsignedIntegerValue] == encoded.length + unit &&
        [entry[@"stringTerminatorBytes"] unsignedIntegerValue] == unit &&
        [locker stateForAddress:(uint64_t)location].lastWriteSuccess,
        "new string lock captures encoding and bounded byte capacity before first write");
    Check(!memcmp(location, before.bytes, before.length), "initial lock write preserves exact Unicode bytes");
    [locker updateAddressLock:(uint64_t)location value:@"改😀"];
    Check([[engine readStringAtAddress:(uint64_t)location encoding:encoding maxBytes:256] isEqualToString:@"改😀"] &&
        [locker stateForAddress:(uint64_t)location].lastWriteSuccess,
        "shorter lock value clears trailing bytes within captured capacity");
    NSData *shortState = [NSData dataWithBytes:location length:before.length];
    [locker updateAddressLock:(uint64_t)location value:@"This value is much longer than the captured string capacity"];
    Check(![locker stateForAddress:(uint64_t)location].lastWriteSuccess &&
        !memcmp(location, shortState.bytes, shortState.length), "oversized lock value is rejected without memory changes");
    [locker updateAddressLock:(uint64_t)location value:text];
    // The target extends its text into the old terminator. The lock must restore that boundary.
    NSData *suffix = [@"X" dataUsingEncoding:foundation];
    memcpy(location + encoded.length, suffix.bytes, suffix.length);
    [locker executeLockCycle];
    Check(!memcmp(location, before.bytes, before.length), "periodic lock cycle restores original encoded value after shortening");
    uint8_t expectedNeighbor[8]; memset(expectedNeighbor, 0xa7, sizeof(expectedNeighbor));
    Check(!memcmp(neighbor, expectedNeighbor, sizeof(expectedNeighbor)), "lock edits and cycles preserve neighboring memory");
    [locker removeAddressLock:(uint64_t)location];

    unichar invalidUnit = 0xd800;
    NSString *invalid = [[NSString alloc] initWithCharacters:&invalidUnit length:1];
    Check(![engine writeStringAtAddress:(uint64_t)location value:invalid encoding:encoding byteCapacity:encoded.length],
        "engine bounded write rejects unpaired surrogate");
    unichar embeddedUnits[] = {'A', 0, 'B'};
    NSString *embedded = [[NSString alloc] initWithCharacters:embeddedUnits length:3];
    Check(![engine writeStringAtAddress:(uint64_t)location value:embedded encoding:encoding byteCapacity:encoded.length],
        "engine bounded write rejects embedded NUL");
    if (unit == 2)
      Check(![engine writeStringAtAddress:(uint64_t)location value:@"a" encoding:encoding byteCapacity:3],
          "UTF-16 bounded writes require whole code-unit capacity");
  }
  method_setImplementation(startMethod, originalStart);
  imp_removeBlock(noopStart);
  Check(mprotect(region + page * 2, page, PROT_READ | PROT_WRITE) == 0, "restore fixture protection");
  Check(munmap(region, page * 3) == 0, "release fixture memory");
}

static void RunSnapshotTests(void (^completion)(void)) {
  VMMemoryEngine *engine = [VMMemoryEngine shared];
  NSUInteger page = (NSUInteger)getpagesize();
  uint8_t *region = (uint8_t *)mmap(NULL, page, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
  Check(region != MAP_FAILED, "allocate isolated search snapshot fixture");
  NSString *text = @"SavedUnicode中文😀";
  NSData *encoded = [text dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
  memcpy(region + 3, encoded.bytes, encoded.length);
  engine.searchRangeStart = (uint64_t)region;
  engine.searchRangeEnd = (uint64_t)region + page;
  engine.stringEncoding = VMStringEncodingUTF16LE;
  engine.stringCaseSensitive = NO;
  [engine clearAllSnapshots];
  [engine clearSession];
  [engine scanMemoryWithMode:VMSearchModeExact valStr:@"savedunicode中文😀" dataType:VMDataTypeString
      fuzzyType:VMFuzzyLess isNextSearch:NO completion:^(NSUInteger count, NSString *message) {
    Check(count == 1, "engine searches Unicode fixture with captured UTF-16 case folding");
    [engine backupCurrentSession];
    engine.stringEncoding = VMStringEncodingUTF8;
    engine.stringCaseSensitive = YES;
    [engine scanMemoryWithMode:VMSearchModeExact valStr:@"missing-value" dataType:VMDataTypeString
        fuzzyType:VMFuzzyLess isNextSearch:NO completion:^(NSUInteger discardedCount, NSString *discardedMessage) {
      Check(discardedCount == 0, "second search replaces live core results");
      [engine restorePreviousSession];
      Check(engine.stringEncoding == VMStringEncodingUTF16LE && !engine.stringCaseSensitive && engine.resultCount == 1,
          "restoring search restores UTF-16 encoding case sensitivity and result count");
      VMScanResultItem *item = [engine getResultItemAtIndex:0 dataType:VMDataTypeString];
      Check(item.address == (uint64_t)(region + 3) && item.stringEncoding == VMStringEncodingUTF16LE &&
          [[engine readStringAtAddress:item.address encoding:item.stringEncoding maxBytes:256] isEqualToString:text],
          "restored core results decode using restored encoding");
      [engine scanMemoryWithMode:VMSearchModeExact valStr:@"SAVEDUNICODE中文😀" dataType:VMDataTypeString
          fuzzyType:VMFuzzyLess isNextSearch:YES completion:^(NSUInteger retainedCount, NSString *retainedMessage) {
        Check(retainedCount == 1, "restored search supports subsequent case-folded UTF-16 rescan");
        [engine clearSession];
        Check(munmap(region, page) == 0, "release snapshot fixture");
        printf("PASS: %lu live string engine checks\n", (unsigned long)checks);
        fflush(stdout);
        completion();
      }];
    }];
  }];
}

@interface StringEngineTestAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation StringEngineTestAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = [UIViewController new];
  [self.window makeKeyAndVisible];
  dispatch_async(dispatch_get_main_queue(), ^{
    RunStringEngineTests();
    RunSnapshotTests(^{ exit(0); });
  });
  return YES;
}
@end

int main(int argc, char **argv) {
  @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(StringEngineTestAppDelegate.class)); }
}
