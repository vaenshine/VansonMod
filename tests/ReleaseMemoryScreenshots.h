// Release screenshots only. Fixed demo addresses map to this process's buffer;
// no real application memory or installed-application metadata is used.
#pragma once
#import <UIKit/UIKit.h>
#import "include/VMMemoryEngine.h"
#import "include/VMLocalization.h"
#import "src/ui/main/VMModifierViewController.h"
#import "src/ui/memory/VMMemoryBrowserViewController.h"
#import "src/ui/memory/VMHexEditorViewController.h"
#include <stdint.h>
#include <string.h>

static const uint64_t VMReleaseMemoryBase = 0x100804000ULL;
static const NSUInteger VMReleaseMemoryLength = 0x4000;
static uint8_t VMReleaseMemoryBytes[VMReleaseMemoryLength];

static void VMReleaseSeedMemory(void) {
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    const int32_t values[] = {100, 250, 150, 75, 200, 120, 64, 32,
                              180, 90, 50, 300, 160, 80, 25, 100};
    for (NSUInteger offset = 0; offset + sizeof(int32_t) <= VMReleaseMemoryLength;
         offset += sizeof(int32_t)) {
      int32_t value = values[(offset / sizeof(int32_t)) % 16];
      memcpy(VMReleaseMemoryBytes + offset, &value, sizeof(value));
    }
    // Exact-search snapshot: two values changed from 100 to 250 after the scan.
    for (NSUInteger i = 0; i < 12; i++) {
      int32_t value = (i == 2 || i == 7) ? 250 : 100;
      memcpy(VMReleaseMemoryBytes + 0x2000 + i * 0x20, &value, sizeof(value));
    }
    // Every text record is eight bytes, matching the production split Hex view.
    const char *records[] = {"ATLAS   ", "DEMO    ", "PLAYER01", "HEALTH  ",
                             "ENERGY  ", "SCORE   ", "ZONE-03 ", "LEVEL-12",
                             "READY   ", "LANG=EN ", "CHECK=OK", "SESSION1"};
    for (NSUInteger row = 0; row < 120; row++) {
      memcpy(VMReleaseMemoryBytes + 0x3000 + row * 8,
             records[row % (sizeof(records) / sizeof(records[0]))], 8);
    }
  });
}

// The harness's shared engine fixture forwards its read methods to these helpers.
// Bounds are checked against a local byte array; fixed addresses are display data.
static NSData *VMReleaseMemoryRead(uint64_t address, size_t length) {
  VMReleaseSeedMemory();
  if (address < VMReleaseMemoryBase) return nil;
  uint64_t offset = address - VMReleaseMemoryBase;
  if (offset >= VMReleaseMemoryLength || length > VMReleaseMemoryLength - offset) return nil;
  return [NSData dataWithBytes:VMReleaseMemoryBytes + offset length:length];
}

static NSString *VMReleaseMemoryReadValue(uint64_t address, VMDataType type) {
  if (type == VMDataTypeString) {
    NSData *bytes = VMReleaseMemoryRead(address, 256);
    if (!bytes) return nil;
    size_t length = strnlen((const char *)bytes.bytes, bytes.length);
    return [[NSString alloc] initWithBytes:bytes.bytes length:length encoding:NSUTF8StringEncoding];
  }
  NSData *bytes = VMReleaseMemoryRead(address, 8);
  if (!bytes) return nil;
  union {
    int8_t i8; uint8_t u8; int16_t i16; uint16_t u16;
    int32_t i32; uint32_t u32; int64_t i64; uint64_t u64;
    float f32; double f64;
  } value = {};
  memcpy(&value, bytes.bytes, sizeof(value));
  switch (type) {
    case VMDataTypeInt8: return [NSString stringWithFormat:@"%d", value.i8];
    case VMDataTypeUInt8: return [NSString stringWithFormat:@"%u", value.u8];
    case VMDataTypeInt16: return [NSString stringWithFormat:@"%d", value.i16];
    case VMDataTypeUInt16: return [NSString stringWithFormat:@"%u", value.u16];
    case VMDataTypeInt32: return [NSString stringWithFormat:@"%d", value.i32];
    case VMDataTypeUInt32: return [NSString stringWithFormat:@"%u", value.u32];
    case VMDataTypeInt64: return [NSString stringWithFormat:@"%lld", value.i64];
    case VMDataTypeUInt64: return [NSString stringWithFormat:@"%llu", value.u64];
    case VMDataTypeFloat: return [NSString stringWithFormat:@"%.4f", value.f32];
    case VMDataTypeDouble: return [NSString stringWithFormat:@"%g", value.f64];
    case VMDataTypeString: return nil;
  }
  return nil;
}

@interface VMModifierViewController (ReleaseMemoryAccess)
- (VMScanResultItem *)getItemAtIndexPath:(NSIndexPath *)path;
- (void)updateButtonStates;
- (void)updateResultInfo;
- (void)updateEmptyState;
@end

@interface VMHexEditorViewController (ReleaseMemoryAccess)
- (void)viewModeChanged:(UISegmentedControl *)segment;
@end

// Production view hierarchy and table rendering, with a deterministic result list.
@interface VMReleaseModifierController : VMModifierViewController
@end
@implementation VMReleaseModifierController
- (void)applyReleaseSearchState {
  VMMemoryEngine.shared.resultCount = 12;
  VMMemoryEngine.shared.currentDataType = VMDataTypeInt32;
  [self setValue:@YES forKey:@"isNextScan"];
  UITextField *input = [self valueForKey:@"inputField"];
  input.text = @"100";
  UISegmentedControl *type = [self valueForKey:@"dataTypeSegment"];
  type.selectedSegmentIndex = VMDataTypeInt32;
  UIButton *search = [self valueForKey:@"searchBtn"];
  [search setTitle:[VMLocalization.shared localizedString:@"Mod_Search_Next"] forState:UIControlStateNormal];
  [self updateButtonStates];
  [self updateResultInfo];
  [self updateEmptyState];
  [[self valueForKey:@"tableView"] reloadData];
}
- (void)viewDidLoad {
  [super viewDidLoad];
  [self applyReleaseSearchState];
}
- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self applyReleaseSearchState];
}
- (VMScanResultItem *)getItemAtIndexPath:(NSIndexPath *)path {
  if (path.row < 0 || path.row >= 12) return nil;
  VMScanResultItem *item = [VMScanResultItem new];
  item.address = VMReleaseMemoryBase + 0x2000 + path.row * 0x20;
  item.type = VMDataTypeInt32;
  item.valueStr = @"100";
  item.prevValue = @100;
  return item;
}
@end

static UIViewController *VMReleaseMemoryPage(NSString *name) {
  VMReleaseSeedMemory();
  if ([name isEqualToString:@"MEM_DEBUG"]) {
    VMMemoryEngine.shared.resultCount = 12;
    VMMemoryEngine.shared.currentDataType = VMDataTypeInt32;
    return [VMReleaseModifierController new];
  }
  if ([name isEqualToString:@"MEM_BROWSER"]) {
    VMMemoryBrowserViewController *page = [VMMemoryBrowserViewController new];
    page.address = VMReleaseMemoryBase + 0x800;
    page.type = VMDataTypeInt32;
    return page;
  }
  if ([name isEqualToString:@"MEM_HEX_MIX"]) {
    VMHexEditorViewController *page = [VMHexEditorViewController new];
    page.address = VMReleaseMemoryBase + 0x3000;
    [page loadViewIfNeeded];
    UISegmentedControl *segment = [page valueForKey:@"viewModeSegment"];
    segment.selectedSegmentIndex = 1;
    [page viewModeChanged:segment];
    return page;
  }
  return nil;
}
