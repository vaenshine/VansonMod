#import <Foundation/Foundation.h>
#import "../src/ui/memory/VMStringMemorySession.h"
#include <string.h>

static int checks = 0;
static void Check(BOOL ok, const char *message) {
  if (!ok) { fprintf(stderr, "FAIL: %s\n", message); exit(1); }
  checks++;
}
@interface Fixture : NSObject
@property(nonatomic, strong) NSMutableData *memory;
@property(nonatomic) BOOL valid;
@property(nonatomic) NSUInteger readableLength;
@property(nonatomic) NSUInteger writes;
@property(nonatomic) NSInteger failure;
@property(nonatomic, strong) VMStringMemorySession *session;
@end
@implementation Fixture
- (instancetype)init {
  if ((self = [super init])) {
    self.memory = [NSMutableData dataWithLength:131072];
    self.readableLength = self.memory.length;
    self.valid = YES;
    self.session = [VMStringMemorySession new];
    __weak __typeof(self) weak = self;
    self.session.targetIsValid = ^BOOL { return weak.valid; };
    self.session.reader = ^NSData *(uint64_t address, NSUInteger count) {
      Fixture *f = weak;
      if (!f || address < 0x1000 || address - 0x1000 > f.readableLength ||
          count > f.readableLength - (address - 0x1000)) return nil;
      return [f.memory subdataWithRange:NSMakeRange(address - 0x1000, count)];
    };
    self.session.writer = ^BOOL(uint64_t address, NSData *data) {
      Fixture *f = weak;
      f.writes++;
      if (f.failure == 1) return NO;
      if (address < 0x1000 || address - 0x1000 > f.memory.length ||
          data.length > f.memory.length - (address - 0x1000)) return NO;
      NSUInteger length = f.failure == 2 ? 1 : data.length;
      [f.memory replaceBytesInRange:NSMakeRange(address - 0x1000, length) withBytes:data.bytes];
      if (f.failure == 3) ((uint8_t *)f.memory.mutableBytes)[address - 0x1000] ^= 1;
      return f.failure != 2;
    };
    memcpy((uint8_t *)self.memory.mutableBytes + 4096, "abc\0def\0ghi\0", 12);
  }
  return self;
}
@end

static void RunTests(void) {
  NSString *error = nil;
  Fixture *f = [Fixture new];
  VMStringMemorySession *s = f.session;
  Check([s openStringAtAddress:0x2004 error:&error], "open middle string");
  Check([s.originalText isEqualToString:@"def"] && s.byteLimit == 3 && s.terminated, "capture exact address and byte limit");
  Check([s loadMoreBefore:YES error:&error] && [s loadMoreBefore:NO error:&error], "load adjacent context");
  NSMutableDictionary *byAddress = [NSMutableDictionary dictionary];
  for (VMStringMemoryRecord *r in s.records) byAddress[@(r.address)] = r.text;
  Check([byAddress[@0x2000] isEqualToString:@"abc"] &&
        [byAddress[@0x2004] isEqualToString:@"def"] &&
        [byAddress[@0x2008] isEqualToString:@"ghi"], "neighbor strings keep real addresses");
  Check(s.address == 0x2004 && [s.originalText isEqualToString:@"def"], "loading context preserves edit selection");
  Check(![s commitDraft:@"1234567890" error:&error] && f.writes == 0, "single write never expands into neighbors");
  Check([error isEqualToString:@"Str_Too_Long"], "oversize reports byte limit");
  Check([s commitDraft:@"xy" error:&error], "shorter terminated string is allowed");
  Check(!memcmp((uint8_t *)f.memory.bytes + 4096, "abc\0xy\0\0ghi\0", 12), "shorter write terminates and preserves neighbors");
  Check([s undo:&error] && !memcmp((uint8_t *)f.memory.bytes + 4096, "abc\0def\0ghi\0", 12), "undo restores exact original span");
  Check([s commitDraft:@"" error:&error], "empty string writes terminator");
  Check(((uint8_t *)f.memory.bytes)[4100] == 0, "empty write clears visible string");
  Check([s undo:&error], "empty write is undoable");

  NSData *chinese = [@"中文" dataUsingEncoding:NSUTF8StringEncoding];
  memcpy((uint8_t *)f.memory.mutableBytes + 4096, chinese.bytes, chinese.length);
  ((uint8_t *)f.memory.mutableBytes)[4096 + chinese.length] = 0;
  Check([s openStringAtAddress:0x2000 error:&error] && s.byteLimit == 6, "UTF-8 Chinese has byte-based limit");
  Check([s commitDraft:@"字" error:&error], "shorter multibyte string");
  Check(((uint8_t *)f.memory.bytes)[4099] == 0, "UTF-8 terminator at encoded byte offset");
  Check([s undo:&error], "UTF-8 original bytes restored");

  f = [Fixture new]; s = f.session;
  f.readableLength = 4099;
  Check([s openStringAtAddress:0x2000 error:&error] && !s.terminated && s.byteLimit == 3, "unterminated page-edge fragment uses exact length");
  Check(![s commitDraft:@"xy" error:&error] && f.writes == 0, "ambiguous boundary blocks shortening");
  Check([s commitDraft:@"xyz" error:&error] && f.writes == 1, "equal-length fragment writes within readable boundary");

  f = [Fixture new]; s = f.session;
  Check([s openStringAtAddress:0x2004 error:&error], "open conflict fixture");
  ((uint8_t *)f.memory.mutableBytes)[4100] = 'X';
  Check(![s commitDraft:@"xyz" error:&error] && [error isEqualToString:@"Str_Conflict"] && f.writes == 0, "external mutation blocks write");
  f.valid = NO;
  Check(![s commitDraft:@"xyz" error:&error] && [error isEqualToString:@"Str_Target_Changed"], "target identity check blocks write");
  Check(![s loadMoreBefore:NO error:&error], "target change blocks context reads");

  f = [Fixture new]; s = f.session;
  Check([s openRangeFrom:0x2000 through:0x200b error:&error], "range end is inclusive");
  Check(s.byteLimit == 12 && [s.originalText isEqualToString:@"abc\\0def\\0ghi\\0"], "range renders separator bytes explicitly");
  Check(![s commitDraft:@"1234567890" error:&error] && f.writes == 0, "range blocks byte-count mismatch");
  Check([s commitDraft:@"1234567890\\0\\0" error:&error], "explicit equal-length range replacement");
  Check(!memcmp((uint8_t *)f.memory.bytes + 4096, "1234567890\0\0", 12) &&
        ((uint8_t *)f.memory.bytes)[4108] == 0, "range writes exactly selected bytes");
  Check([s undo:&error] && !memcmp((uint8_t *)f.memory.bytes + 4096, "abc\0def\0ghi\0", 12), "range undo restores data and separators");
  Check(![s openRangeFrom:0x2000 through:0x4000 error:&error], "oversize range rejected");
  Check(![s openRangeFrom:0x2000 through:0x1000 error:&error], "reversed range rejected");
  Check(![s openRangeFrom:UINT64_MAX - 2 through:UINT64_MAX error:&error], "address overflow rejected");

  uint64_t parsed = 0;
  Check([VMStringMemorySession parseAddress:@" 280000000 " value:&parsed] && parsed == 0x280000000ULL, "bare addresses parsed as hexadecimal");
  Check([VMStringMemorySession parseAddress:@"0Xabcdef" value:&parsed] && parsed == 0xabcdef, "hex prefix accepted");
  for (NSString *bad in @[@"", @"0", @"-1", @"+123", @"12xz", @"10000000000000000"])
    Check(![VMStringMemorySession parseAddress:bad value:&parsed], "invalid address rejected");

  NSMutableData *binary = [NSMutableData dataWithLength:256];
  for (NSUInteger i = 0; i < 256; i++) ((uint8_t *)binary.mutableBytes)[i] = i;
  NSString *escaped = [VMStringMemorySession escapedTextForData:binary];
  Check([[VMStringMemorySession dataForEscapedText:escaped] isEqualToData:binary], "all 256 byte values round-trip losslessly");
  NSData *unicode = [@"中😀\\line\n" dataUsingEncoding:NSUTF8StringEncoding];
  Check([[VMStringMemorySession dataForEscapedText:[VMStringMemorySession escapedTextForData:unicode]] isEqualToData:unicode], "Unicode and literal backslashes round-trip");
  for (NSString *bad in @[@"\\", @"\\x", @"\\xQ2", @"\\q"])
    Check([VMStringMemorySession dataForEscapedText:bad] == nil, "malformed escape rejected");
  uint8_t zeros[] = {'a', 0, 'b'};
  NSString *embedded = [[NSString alloc] initWithBytes:zeros length:3 encoding:NSUTF8StringEncoding];
  Check([s openStringAtAddress:0x2004 error:&error], "reopen single string");
  Check([s dataForDraft:embedded error:&error] == nil, "single string rejects embedded zero");

  for (NSInteger failure = 1; failure <= 3; failure++) {
    f = [Fixture new]; s = f.session;
    Check([s openStringAtAddress:0x2004 error:&error], "open write failure fixture");
    f.failure = failure;
    Check(![s commitDraft:@"xyz" error:&error] && [error isEqualToString:@"Str_Write_Unverified"], "write failure/readback mismatch never reports success");
    if (failure == 1) Check(!s.canUndo, "failed unchanged write adds no undo");
    else {
      Check(s.canUndo, "partial write retains original snapshot");
      f.failure = 0;
      Check([s undo:&error] && !memcmp((uint8_t *)f.memory.bytes + 4100, "def\0", 4), "partial write can restore original bytes after conflict check");
    }
  }
  f = [Fixture new]; s = f.session;
  Check([s openStringAtAddress:0x2004 error:&error] && [s commitDraft:@"xyz" error:&error], "successful edit creates undo");
  ((uint8_t *)f.memory.mutableBytes)[4101] = '!';
  NSUInteger writes = f.writes;
  Check(![s undo:&error] && [error isEqualToString:@"Str_Conflict"] && f.writes == writes, "undo avoids overwriting external mutations");

  f = [Fixture new]; s = f.session;
  Check([s openStringAtAddress:0x2004 error:&error], "open context cap fixture");
  while ([s loadMoreBefore:NO error:&error]) {}
  Check(s.contextByteCount == 65536 && [error isEqualToString:@"Str_Context_Limit"], "context memory use is bounded at 64 KB");
  Check(s.address == 0x2004 && [s.originalText isEqualToString:@"def"], "all context pages preserve draft baseline");

  f = [Fixture new]; s = f.session;
  Check(![s openStringAtAddress:UINT64_MAX error:&error], "highest address fails gracefully");
  f.readableLength = 0;
  Check(![s openStringAtAddress:0x2000 error:&error], "unreadable address rejected");
}
int main(void) {
  @autoreleasepool {
    RunTests();
    printf("PASS: %d string memory checks\n", checks);
  }
  return 0;
}
