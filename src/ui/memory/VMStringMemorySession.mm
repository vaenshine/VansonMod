#import "VMStringMemorySession.h"
#include <errno.h>
#include <stdlib.h>

static const NSUInteger StringMaxEditBytes = 8192;
static const NSUInteger StringContextPageBytes = 1024;
static const NSUInteger StringMaxContextBytes = 65536;

static BOOL StringFail(NSString **error, NSString *key) {
  if (error) *error = key;
  return NO;
}

// Valid UTF-8 scalar, excluding ASCII controls except tab/newline.
static NSUInteger StringScalarSize(const uint8_t *p, NSUInteger remaining) {
  if (!remaining) return 0;
  uint8_t a = p[0];
  if ((a >= 0x20 && a < 0x7f) || a == 9 || a == 10 || a == 13) return 1;
  NSUInteger n = a >= 0xc2 && a <= 0xdf ? 2 :
                 a >= 0xe0 && a <= 0xef ? 3 :
                 a >= 0xf0 && a <= 0xf4 ? 4 : 0;
  if (!n || n > remaining) return 0;
  for (NSUInteger i = 1; i < n; i++) if ((p[i] & 0xc0) != 0x80) return 0;
  if ((a == 0xe0 && p[1] < 0xa0) || (a == 0xed && p[1] >= 0xa0) ||
      (a == 0xf0 && p[1] < 0x90) || (a == 0xf4 && p[1] >= 0x90)) return 0;
  return n;
}

static NSUInteger StringEncodedScalarSize(const uint8_t *p, NSUInteger remaining,
                                          VMStringEncoding encoding) {
  if (encoding == VMStringEncodingUTF8) return StringScalarSize(p, remaining);
  if (remaining < 2) return 0;
  BOOL little = encoding == VMStringEncodingUTF16LE;
  uint16_t a = little ? (uint16_t)(p[0] | p[1] << 8) : (uint16_t)(p[0] << 8 | p[1]);
  if (a >= 0xd800 && a <= 0xdbff) {
    if (remaining < 4) return 0;
    uint16_t b = little ? (uint16_t)(p[2] | p[3] << 8) : (uint16_t)(p[2] << 8 | p[3]);
    return b >= 0xdc00 && b <= 0xdfff ? 4 : 0;
  }
  if (a >= 0xdc00 && a <= 0xdfff) return 0;
  return ((a >= 0x20 && a != 0x7f) || a == 9 || a == 10 || a == 13) ? 2 : 0;
}

static NSUInteger StringTerminatorSize(VMStringEncoding encoding) {
  return encoding == VMStringEncodingUTF8 ? 1 : 2;
}

static BOOL StringHasTerminator(const uint8_t *p, NSUInteger remaining,
                                VMStringEncoding encoding) {
  NSUInteger count = StringTerminatorSize(encoding);
  return remaining >= count && p[0] == 0 && (count == 1 || p[1] == 0);
}

static BOOL StringDraftIsValid(NSString *text) {
  for (NSUInteger i = 0; i < text.length; i++) {
    unichar value = [text characterAtIndex:i];
    if (value == 0) return NO;
    if (value >= 0xd800 && value <= 0xdbff) {
      if (++i >= text.length) return NO;
      unichar low = [text characterAtIndex:i];
      if (low < 0xdc00 || low > 0xdfff) return NO;
    } else if (value >= 0xdc00 && value <= 0xdfff) return NO;
  }
  return YES;
}

@implementation VMStringMemoryRecord
@end

@interface VMStringMemorySession ()
@property(nonatomic) uint64_t address;
@property(nonatomic, copy) NSData *originalBytes;
@property(nonatomic, copy) NSString *originalText;
@property(nonatomic) BOOL rangeMode;
@property(nonatomic) BOOL terminated;
@property(nonatomic) uint64_t contextStart;
@property(nonatomic, strong) NSMutableData *contextData;
@property(nonatomic, strong) NSMutableArray<NSMutableDictionary *> *undoItems;
@end

@implementation VMStringMemorySession

- (instancetype)init {
  if ((self = [super init])) _undoItems = [NSMutableArray array];
  return self;
}

@synthesize stringEncoding = _stringEncoding;

- (void)setStringEncoding:(VMStringEncoding)encoding {
  if (self.originalBytes) return;
  _stringEncoding = encoding <= VMStringEncodingUTF16BE ? encoding : VMStringEncodingUTF8;
}

+ (NSStringEncoding)foundationEncodingForStringEncoding:(VMStringEncoding)encoding {
  switch (encoding) {
    case VMStringEncodingUTF16LE: return NSUTF16LittleEndianStringEncoding;
    case VMStringEncodingUTF16BE: return NSUTF16BigEndianStringEncoding;
    default: return NSUTF8StringEncoding;
  }
}

+ (NSString *)nameForStringEncoding:(VMStringEncoding)encoding {
  switch (encoding) {
    case VMStringEncodingUTF16LE: return @"UTF-16LE";
    case VMStringEncodingUTF16BE: return @"UTF-16BE";
    default: return @"UTF-8";
  }
}

- (NSStringEncoding)foundationEncoding {
  return [self.class foundationEncodingForStringEncoding:self.stringEncoding];
}

- (NSUInteger)terminatorByteCount { return StringTerminatorSize(self.stringEncoding); }

+ (NSString *)textPrefixInData:(NSData *)data stringEncoding:(VMStringEncoding)encoding
                   byteLength:(NSUInteger *)byteLength terminated:(BOOL *)terminated {
  const uint8_t *bytes = (const uint8_t *)data.bytes;
  NSUInteger length = 0, size = 0;
  while (length < data.length &&
         (size = StringEncodedScalarSize(bytes + length, data.length - length, encoding))) length += size;
  BOOL foundTerminator = length < data.length &&
      StringHasTerminator(bytes + length, data.length - length, encoding);
  if (byteLength) *byteLength = length;
  if (terminated) *terminated = foundTerminator;
  if (!length && !foundTerminator) return nil;
  return [[NSString alloc] initWithBytes:bytes length:length
                              encoding:[self foundationEncodingForStringEncoding:encoding]];
}

- (BOOL)valid {
  return self.reader && self.writer && self.targetIsValid && self.targetIsValid();
}

- (NSData *)readExact:(uint64_t)address length:(NSUInteger)length {
  if (![self valid] || !address || !length || length > UINT64_MAX - address) return nil;
  NSData *data = self.reader(address, length);
  return [self valid] && data.length == length ? data : nil;
}

// Small chunks allow reads to stop at an unreadable page without dereferencing it.
- (NSData *)readPrefix:(uint64_t)address limit:(NSUInteger)limit {
  NSMutableData *result = [NSMutableData data];
  if (!address || limit > UINT64_MAX - address) return result;
  while (result.length < limit && [self valid]) {
    uint64_t cursor = address + result.length;
    NSUInteger size = MIN((NSUInteger)256, limit - result.length);
    NSData *part = nil;
    while (size && !(part = [self readExact:cursor length:size])) size /= 2;
    if (!part) break;
    [result appendData:part];
  }
  return result;
}

- (NSUInteger)byteLimit {
  return self.originalBytes.length - (self.terminated && !self.rangeMode ? self.terminatorByteCount : 0);
}

- (BOOL)openStringAtAddress:(uint64_t)address error:(NSString **)error {
  if (![self valid]) return StringFail(error, @"Str_Target_Changed");
  NSData *data = [self readPrefix:address limit:MIN((uint64_t)StringMaxEditBytes, UINT64_MAX - address)];
  if (!data.length) return StringFail(error, @"Str_Read_Failed");
  NSUInteger length = 0;
  BOOL terminated = NO;
  NSString *text = [self.class textPrefixInData:data stringEncoding:self.stringEncoding
                                     byteLength:&length terminated:&terminated];
  if (!text) return StringFail(error, @"Str_Not_Text");
  NSData *snapshot = [data subdataWithRange:NSMakeRange(0, length + (terminated ? self.terminatorByteCount : 0))];
  self.address = address;
  self.originalBytes = snapshot;
  self.originalText = text;
  self.terminated = terminated;
  self.rangeMode = NO;
  [self updateContextSnapshot];
  return YES;
}

- (BOOL)openRangeFrom:(uint64_t)start through:(uint64_t)end error:(NSString **)error {
  if (![self valid]) return StringFail(error, @"Str_Target_Changed");
  if (!start || end < start || end - start >= StringMaxEditBytes || end == UINT64_MAX)
    return StringFail(error, @"Str_Invalid_Range");
  NSData *data = [self readExact:start length:(NSUInteger)(end - start + 1)];
  if (!data) return StringFail(error, @"Str_Read_Failed");
  self.address = start;
  self.originalBytes = data;
  self.originalText = [self.class escapedTextForData:data];
  self.terminated = NO;
  self.rangeMode = YES;
  [self updateContextSnapshot];
  return YES;
}

- (void)updateContextSnapshot {
  if (!self.contextData || self.address < self.contextStart ||
      self.address - self.contextStart > self.contextData.length ||
      self.originalBytes.length > self.contextData.length - (self.address - self.contextStart)) {
    [self resetContext];
  } else {
    [self.contextData replaceBytesInRange:NSMakeRange((NSUInteger)(self.address - self.contextStart),
                                                    self.originalBytes.length)
                               withBytes:self.originalBytes.bytes];
  }
}

- (void)resetContext {
  self.contextStart = self.address;
  self.contextData = [self.originalBytes mutableCopy];
}

- (NSUInteger)contextByteCount { return self.contextData.length; }

- (BOOL)loadMoreBefore:(BOOL)before error:(NSString **)error {
  if (![self valid]) return StringFail(error, @"Str_Target_Changed");
  if (!self.contextData.length) return StringFail(error, @"Str_Read_Failed");
  if (self.contextData.length >= StringMaxContextBytes) return StringFail(error, @"Str_Context_Limit");
  NSUInteger count = MIN(StringContextPageBytes, StringMaxContextBytes - self.contextData.length);
  NSData *part = nil;
  if (before) {
    count = (NSUInteger)MIN((uint64_t)count, self.contextStart > 1 ? self.contextStart - 1 : 0);
    while (count && !(part = [self readExact:self.contextStart - count length:count])) count /= 2;
    if (!part) return StringFail(error, @"Str_Read_Failed");
    self.contextStart -= part.length;
    NSMutableData *combined = [part mutableCopy];
    [combined appendData:self.contextData];
    self.contextData = combined;
  } else {
    uint64_t end = self.contextStart + self.contextData.length;
    count = (NSUInteger)MIN((uint64_t)count, UINT64_MAX - end);
    part = [self readPrefix:end limit:count];
    if (!part.length) return StringFail(error, @"Str_Read_Failed");
    [self.contextData appendData:part];
  }
  return YES;
}

- (NSArray<VMStringMemoryRecord *> *)records {
  return [self.class recordsInData:self.contextData atAddress:self.contextStart
                   stringEncoding:self.stringEncoding alignmentAddress:self.address];
}

+ (NSArray<VMStringMemoryRecord *> *)recordsInData:(NSData *)data
                                       atAddress:(uint64_t)address
                                  stringEncoding:(VMStringEncoding)encoding
                                alignmentAddress:(uint64_t)alignmentAddress {
  NSMutableArray *result = [NSMutableArray array];
  const uint8_t *p = (const uint8_t *)data.bytes;
  NSUInteger stride = StringTerminatorSize(encoding);
  NSUInteger total = data.length, i = stride == 2 ? ((address ^ alignmentAddress) & 1) : 0;
  while (i < total) {
    NSUInteger n = StringEncodedScalarSize(p + i, total - i, encoding);
    if (!n) { i += MIN(stride, total - i); continue; }
    NSUInteger start = i;
    do { i += n; } while (i < total && address + i != alignmentAddress &&
                         (n = StringEncodedScalarSize(p + i, total - i, encoding)));
    VMStringMemoryRecord *record = [VMStringMemoryRecord new];
    record.address = address + start;
    record.terminated = i < total && StringHasTerminator(p + i, total - i, encoding);
    record.bytes = [data subdataWithRange:NSMakeRange(start, i - start + (record.terminated ? stride : 0))];
    record.text = [[NSString alloc] initWithBytes:p + start length:i - start
                                       encoding:[self foundationEncodingForStringEncoding:encoding]];
    if (record.text) [result addObject:record];
    if (record.terminated) i += stride;
  }
  return result;
}

+ (BOOL)parseAddress:(NSString *)text value:(uint64_t *)value {
  NSString *trimmed = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if ([trimmed.lowercaseString hasPrefix:@"0x"]) trimmed = [trimmed substringFromIndex:2];
  if (!trimmed.length || trimmed.length > 16 ||
      [trimmed rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet]].location != NSNotFound) return NO;
  errno = 0;
  char *end = NULL;
  uint64_t address = strtoull(trimmed.UTF8String, &end, 16);
  if (errno || !end || *end || !address) return NO;
  if (value) *value = address;
  return YES;
}

+ (NSString *)escapedTextForData:(NSData *)data {
  NSMutableString *text = [NSMutableString string];
  const uint8_t *p = (const uint8_t *)data.bytes;
  for (NSUInteger i = 0; i < data.length;) {
    NSString *escape = p[i] == 0 ? @"\\0" : p[i] == 10 ? @"\\n" :
        p[i] == 13 ? @"\\r" : p[i] == 9 ? @"\\t" : p[i] == '\\' ? @"\\\\" : nil;
    if (escape) { [text appendString:escape]; i++; continue; }
    NSUInteger n = StringScalarSize(p + i, data.length - i);
    if (n) {
      [text appendString:[[NSString alloc] initWithBytes:p + i length:n encoding:NSUTF8StringEncoding]];
      i += n;
    } else {
      [text appendFormat:@"\\x%02X", p[i++]];
    }
  }
  return text;
}

+ (NSData *)dataForEscapedText:(NSString *)text {
  NSMutableData *data = [NSMutableData data];
  NSUInteger i = 0;
  while (i < text.length) {
    NSRange slash = [text rangeOfString:@"\\" options:0 range:NSMakeRange(i, text.length - i)];
    NSUInteger end = slash.location == NSNotFound ? text.length : slash.location;
    NSData *plain = [[text substringWithRange:NSMakeRange(i, end - i)] dataUsingEncoding:NSUTF8StringEncoding];
    if (!plain) return nil;
    [data appendData:plain];
    if (end == text.length) break;
    i = end + 1;
    if (i == text.length) return nil;
    unichar c = [text characterAtIndex:i++];
    uint8_t byte = 0;
    if (c == '0') byte = 0;
    else if (c == 'n') byte = 10;
    else if (c == 'r') byte = 13;
    else if (c == 't') byte = 9;
    else if (c == '\\') byte = '\\';
    else if (c == 'x') {
      if (i + 2 > text.length) return nil;
      NSString *hex = [text substringWithRange:NSMakeRange(i, 2)];
      if ([hex rangeOfCharacterFromSet:[[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet]].location != NSNotFound) return nil;
      byte = (uint8_t)strtoul(hex.UTF8String, NULL, 16);
      i += 2;
    } else return nil;
    [data appendBytes:&byte length:1];
  }
  return data;
}

- (NSData *)dataForDraft:(NSString *)text error:(NSString **)error {
  NSData *data = self.rangeMode ? [self.class dataForEscapedText:text] : [text dataUsingEncoding:self.foundationEncoding allowLossyConversion:NO];
  if (!data || (!self.rangeMode && !StringDraftIsValid(text))) {
    StringFail(error, @"Str_Invalid_Text");
    return nil;
  }
  if (self.rangeMode || !self.terminated) {
    if (data.length != self.byteLimit) { StringFail(error, @"Str_Equal_Length"); return nil; }
  } else if (data.length > self.byteLimit) {
    StringFail(error, @"Str_Too_Long"); return nil;
  }
  return data;
}

- (BOOL)canUndo { return self.undoItems.count > 0; }

- (BOOL)commitDraft:(NSString *)text error:(NSString **)error {
  if (![self valid]) return StringFail(error, @"Str_Target_Changed");
  NSData *payload = [self dataForDraft:text error:error];
  if (!payload || !self.originalBytes.length) return NO;
  NSData *before = [self readExact:self.address length:self.originalBytes.length];
  if (!before) return StringFail(error, @"Str_Read_Failed");
  if (![before isEqualToData:self.originalBytes]) return StringFail(error, @"Str_Conflict");
  NSMutableData *writeData = [payload mutableCopy];
  if (self.terminated && !self.rangeMode) { uint16_t zero = 0; [writeData appendBytes:&zero length:self.terminatorByteCount]; }
  NSMutableData *expected = [before mutableCopy];
  [expected replaceBytesInRange:NSMakeRange(0, writeData.length) withBytes:writeData.bytes];
  if ([before isEqualToData:expected]) return YES;
  // Retain the complete original span before attempting a write.
  NSMutableDictionary *undo = [@{@"address": @(self.address), @"before": before,
      @"after": expected, @"range": @(self.rangeMode), @"terminated": @(self.terminated),
      @"text": self.originalText ?: @"", @"encoding": @(self.stringEncoding)} mutableCopy];
  [self.undoItems addObject:undo];
  if (self.undoItems.count > 10) [self.undoItems removeObjectAtIndex:0];
  BOOL ok = self.writer(self.address, writeData);
  NSData *after = [self readExact:self.address length:before.length];
  if (!ok || ![after isEqualToData:expected]) {
    // A failed API may still have changed bytes. Preserve the snapshot for inspection/recovery.
    if (after) undo[@"after"] = after;
    if ([after isEqualToData:before]) [self.undoItems removeLastObject];
    return StringFail(error, @"Str_Write_Unverified");
  }
  if (self.didWrite) self.didWrite(self.address, before, expected);
  BOOL wasRange = self.rangeMode;
  if (wasRange) {
    self.originalBytes = expected;
    self.originalText = [self.class escapedTextForData:expected];
  } else {
    self.originalBytes = writeData;
    self.originalText = text;
  }
  [self updateContextSnapshot];
  return YES;
}

- (BOOL)undo:(NSString **)error {
  if (![self valid]) return StringFail(error, @"Str_Target_Changed");
  NSMutableDictionary *item = self.undoItems.lastObject;
  if (!item) return StringFail(error, @"Str_No_Undo");
  uint64_t address = [item[@"address"] unsignedLongLongValue];
  NSData *before = item[@"before"], *expected = item[@"after"];
  NSData *current = [self readExact:address length:expected.length];
  if (!current) return StringFail(error, @"Str_Read_Failed");
  if (![current isEqualToData:expected]) return StringFail(error, @"Str_Conflict");
  BOOL ok = self.writer(address, before);
  NSData *actual = [self readExact:address length:before.length];
  if (!ok || ![actual isEqualToData:before]) {
    if (actual) item[@"after"] = actual;
    return StringFail(error, @"Str_Write_Unverified");
  }
  self.address = address;
  self.originalBytes = before;
  _stringEncoding = (VMStringEncoding)[item[@"encoding"] unsignedIntegerValue];
  self.originalText = item[@"text"];
  self.rangeMode = [item[@"range"] boolValue];
  self.terminated = [item[@"terminated"] boolValue];
  [self.undoItems removeLastObject];
  [self updateContextSnapshot];
  return YES;
}
@end
