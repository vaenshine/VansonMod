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
  return self.originalBytes.length - (self.terminated && !self.rangeMode ? 1 : 0);
}

- (BOOL)openStringAtAddress:(uint64_t)address error:(NSString **)error {
  if (![self valid]) return StringFail(error, @"Str_Target_Changed");
  NSData *data = [self readPrefix:address limit:MIN((uint64_t)StringMaxEditBytes, UINT64_MAX - address)];
  if (!data.length) return StringFail(error, @"Str_Read_Failed");
  const uint8_t *p = (const uint8_t *)data.bytes;
  NSUInteger length = 0, n = 0;
  while (length < data.length && (n = StringScalarSize(p + length, data.length - length))) length += n;
  BOOL terminated = length < data.length && p[length] == 0;
  if (!length && !terminated) return StringFail(error, @"Str_Not_Text");
  NSData *snapshot = [data subdataWithRange:NSMakeRange(0, length + (terminated ? 1 : 0))];
  self.address = address;
  self.originalBytes = snapshot;
  self.originalText = [[NSString alloc] initWithBytes:p length:length encoding:NSUTF8StringEncoding] ?: @"";
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
  NSMutableArray *result = [NSMutableArray array];
  const uint8_t *p = (const uint8_t *)self.contextData.bytes;
  NSUInteger total = self.contextData.length, i = 0;
  while (i < total) {
    NSUInteger n = StringScalarSize(p + i, total - i);
    if (!n) { i++; continue; }
    NSUInteger start = i;
    do { i += n; } while (i < total && (n = StringScalarSize(p + i, total - i)));
    VMStringMemoryRecord *record = [VMStringMemoryRecord new];
    record.address = self.contextStart + start;
    record.terminated = i < total && p[i] == 0;
    record.bytes = [self.contextData subdataWithRange:NSMakeRange(start, i - start + (record.terminated ? 1 : 0))];
    record.text = [[NSString alloc] initWithBytes:p + start length:i - start encoding:NSUTF8StringEncoding];
    [result addObject:record];
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
  NSData *data = self.rangeMode ? [self.class dataForEscapedText:text] : [text dataUsingEncoding:NSUTF8StringEncoding];
  if (!data || (!self.rangeMode && [text rangeOfString:[NSString stringWithFormat:@"%C", (unichar)0]].location != NSNotFound)) {
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
  if (self.terminated && !self.rangeMode) { uint8_t zero = 0; [writeData appendBytes:&zero length:1]; }
  NSMutableData *expected = [before mutableCopy];
  [expected replaceBytesInRange:NSMakeRange(0, writeData.length) withBytes:writeData.bytes];
  if ([before isEqualToData:expected]) return YES;
  // Retain the complete original span before attempting a write.
  NSMutableDictionary *undo = [@{@"address": @(self.address), @"before": before,
      @"after": expected, @"range": @(self.rangeMode), @"terminated": @(self.terminated),
      @"text": self.originalText ?: @""} mutableCopy];
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
  self.originalText = item[@"text"];
  self.rangeMode = [item[@"range"] boolValue];
  self.terminated = [item[@"terminated"] boolValue];
  [self.undoItems removeLastObject];
  [self updateContextSnapshot];
  return YES;
}
@end
