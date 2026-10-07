#include "../src/memory/core/MemoryCore.hpp"
#include "../src/utils/managers/StorageCore.hpp"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <unistd.h>
#include <vector>

using VMCore::DataType;
static constexpr uint64_t kBase = 0x145966000ULL;
static constexpr size_t kChunk = 1024 * 1024;
static constexpr uint64_t kValue = 4114578669569ULL;
static std::vector<uint8_t> memory;
static size_t shortReadLimit = SIZE_MAX;
static uint64_t allowedStart, allowedEnd;
static size_t invalidReads, checks;
static size_t mutateAfterReadingOffset = SIZE_MAX;

// Replace only the target-memory transport; every search runs production code.
extern "C" kern_return_t mach_vm_region_recurse(vm_map_t, mach_vm_address_t *address,
    mach_vm_size_t *size, uint32_t *, vm_region_recurse_info_t rawInfo,
    mach_msg_type_number_t *) {
  if (*address >= kBase + memory.size()) return KERN_INVALID_ADDRESS;
  *address = kBase;
  *size = memory.size();
  auto info = reinterpret_cast<vm_region_submap_info_data_64_t *>(rawInfo);
  std::memset(info, 0, sizeof(*info));
  info->protection = VM_PROT_READ | VM_PROT_WRITE;
  return KERN_SUCCESS;
}

extern "C" kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t address,
    mach_vm_size_t size, mach_vm_address_t output, mach_vm_size_t *actual) {
  *actual = 0;
  if (address < allowedStart || address > allowedEnd || size > allowedEnd - address) {
    ++invalidReads;
    return KERN_INVALID_ADDRESS;
  }
  *actual = std::min<size_t>(size, shortReadLimit);
  std::memcpy(reinterpret_cast<void *>(output), memory.data() + address - kBase, *actual);
  const uint64_t mutationAddress = kBase + mutateAfterReadingOffset;
  if (mutateAfterReadingOffset != SIZE_MAX && address <= mutationAddress &&
      mutationAddress - address + sizeof(int32_t) <= *actual) {
    const int32_t changed = 999;
    std::memcpy(memory.data() + mutateAfterReadingOffset, &changed, sizeof(changed));
    mutateAfterReadingOffset = SIZE_MAX;
  }
  return KERN_SUCCESS;
}

namespace VMCore {
StorageCore &StorageCore::shared() { static StorageCore store; return store; }
std::string StorageCore::getString(const std::string &, const std::string &fallback) {
  return fallback;
}
}

static void require(bool ok, const std::string &name) {
  if (!ok) { std::fprintf(stderr, "FAIL %s\n", name.c_str()); std::exit(1); }
  ++checks;
}

static void reset(size_t size) {
  memory.assign(size, 0xAA);
  allowedStart = kBase;
  allowedEnd = kBase + size;
  shortReadLimit = SIZE_MAX;
  invalidReads = 0;
  mutateAfterReadingOffset = SIZE_MAX;
}

template <typename T> static void put(size_t offset, T value) {
  require(offset <= memory.size() && sizeof(T) <= memory.size() - offset, "fixture bounds");
  std::memcpy(memory.data() + offset, &value, sizeof(value));
}

static void expect(VMCore::MemoryCore &engine, const std::vector<size_t> &offsets,
                   const std::string &name) {
  auto results = engine.getResults(0, engine.getResultCount());
  std::vector<uint64_t> actual, expected;
  for (auto &r : results) actual.push_back(r.address);
  for (size_t offset : offsets) expected.push_back(kBase + offset);
  std::sort(actual.begin(), actual.end());
  std::sort(expected.begin(), expected.end());
  if (actual != expected) {
    std::fprintf(stderr, "%s: expected %zu results, got %zu\n", name.c_str(), expected.size(), actual.size());
    for (auto address : actual) std::fprintf(stderr, "  +0x%llx\n", address - kBase);
  }
  require(actual == expected, name);
}

int main(int argc, char **argv) {
  require(argc == 2, "temporary storage directory");
  VMCore::MemoryCore engine;
  require(engine.attach(getpid()), "attach fixture transport");
  engine.setStoragePath(std::string(argv[1]) + "/results.bin", std::string(argv[1]) + "/swap.bin");
  auto scan = [&](DataType type = DataType::UInt64, std::string value = std::to_string(kValue), int mode = 0) {
    engine.scan(type, value, mode, allowedStart, allowedEnd);
    require(invalidReads == 0, "initial scan respects selected range and region");
  };

  reset(4096); put(0xA4, kValue);
  uint64_t direct = 0;
  require(engine.readMemory(kBase + 0xA4, &direct, 8) && direct == kValue, "reported address reads correctly");
  scan(); expect(engine, {0xA4}, "reported value at 4 mod 8");

  for (size_t alignment = 0; alignment < 8; ++alignment) {
    reset(128); put(32 + alignment, kValue);
    scan(); expect(engine, {32 + alignment}, "U64 every byte alignment");
    scan(DataType::Int64); expect(engine, {32 + alignment}, "I64 every byte alignment");
    scan(DataType::UInt64, std::to_string(kValue - 1) + "~" + std::to_string(kValue + 1), 3);
    expect(engine, {32 + alignment}, "U64 range every byte alignment");
    scan(DataType::Int64, std::to_string(kValue) + "~" + std::to_string(kValue), 3);
    expect(engine, {32 + alignment}, "I64 range every byte alignment");
  }

  for (size_t overlap = 1; overlap < 8; ++overlap) {
    reset(kChunk + 128); put(kChunk - overlap, kValue);
    scan(); expect(engine, {kChunk - overlap}, "U64 crossing block boundary");
    scan(DataType::Int64); expect(engine, {kChunk - overlap}, "I64 crossing block boundary");
    scan(DataType::UInt64, std::to_string(kValue) + "~" + std::to_string(kValue), 3);
    expect(engine, {kChunk - overlap}, "U64 range crossing block boundary");
  }
  reset(kChunk + 128);
  std::fill(memory.begin() + kChunk - 8, memory.begin() + kChunk + 8, 1);
  scan(DataType::UInt64, "72340172838076673");
  std::vector<size_t> dense;
  for (size_t i = kChunk - 8; i <= kChunk; ++i) dense.push_back(i);
  expect(engine, dense, "overlapping values emitted exactly once");

  reset(35); put(27, kValue);
  scan(); expect(engine, {27}, "last complete value in region");
  allowedStart = kBase + 27;
  scan(); expect(engine, {27}, "unaligned eight-byte selected range");
  --allowedEnd;
  scan(); expect(engine, {}, "exclude value extending beyond selected end");
  ++allowedEnd; ++allowedStart;
  scan(); expect(engine, {}, "exclude value before selected start");
  for (size_t size = 1; size < 8; ++size) {
    reset(size); std::fill(memory.begin(), memory.end(), 0);
    scan(DataType::UInt64, "0"); expect(engine, {}, "short region has no complete U64");
  }
  reset(64); put(0, kValue); shortReadLimit = 7;
  scan(); expect(engine, {}, "successful short read has no complete U64");

  reset(8192); put(4093, kValue); put(4132, kValue);
  scan(); expect(engine, {4093, 4132}, "cross-page initial results");
  engine.nextScan({}, DataType::UInt64, std::to_string(kValue), 100);
  expect(engine, {4093, 4132}, "cross-page exact rescan");
  put(4132, kValue + 1);
  engine.nextScan({}, DataType::UInt64, std::to_string(kValue), 100);
  expect(engine, {4093}, "rescan removes changed value");
  shortReadLimit = 7;
  engine.nextScan({}, DataType::UInt64, std::to_string(kValue), 100);
  expect(engine, {}, "rescan rejects incomplete fallback read");

  reset(8192); put(3, kValue); scan(); shortReadLimit = 8;
  engine.nextScan({}, DataType::UInt64, std::to_string(kValue), 100);
  expect(engine, {3}, "short cached page falls back to complete value read");

  const uint64_t high = 0xF123456789ABCDEFULL;
  reset(8192); put(29, high); put(61, high & 0xFFFFFFFFFFFFULL); put(93, high + 1);
  scan(DataType::UInt64, std::to_string(high)); expect(engine, {29}, "U64 retains high bits");
  engine.nextScan({}, DataType::UInt64, std::to_string(high), 100);
  expect(engine, {29}, "high-bit U64 exact rescan");
  scan(DataType::UInt64, std::to_string(high) + "~" + std::to_string(high + 1), 3);
  expect(engine, {29, 93}, "high-bit U64 range comparison");
  reset(128); put<int64_t>(19, -1234567890123LL);
  scan(DataType::Int64, "-1234567890123"); expect(engine, {19}, "negative I64 unaligned exact");

  // Preserve natural-width strides for smaller integers and floating-point data.
  reset(128); put<uint32_t>(16, 123456789); put<uint32_t>(33, 123456789);
  scan(DataType::UInt32, "123456789"); expect(engine, {16}, "U32 keeps four-byte stride");
  scan(DataType::Int32, "123456789"); expect(engine, {16}, "I32 keeps four-byte stride");
  reset(128); put<uint16_t>(16, 23456); put<uint16_t>(33, 23456);
  scan(DataType::UInt16, "23456"); expect(engine, {16}, "U16 keeps two-byte stride");
  reset(128); put<float>(16, 123.25f); put<float>(33, 123.25f);
  scan(DataType::Float, "123.25"); expect(engine, {16}, "F32 keeps four-byte stride");
  reset(128); put<double>(16, 123.25); put<double>(36, 123.25);
  allowedStart = kBase + 1;
  scan(DataType::Double, "123.25"); expect(engine, {16}, "F64 keeps eight-byte alignment");

  const std::string group = std::to_string(kValue) + " u64;24681357 i32";
  reset(kChunk + 128); put(kChunk - 3, kValue); put<int32_t>(kChunk + 19, 24681357);
  engine.setGroupSearchRange(32); engine.setGroupAnchorMode(false);
  scan(DataType::Int32, group, 2);
  expect(engine, {kChunk - 3, kChunk + 19}, "ordered group with packed U64 crossing block");
  allowedEnd = kBase + kChunk + 21;
  scan(DataType::Int32, group, 2); expect(engine, {}, "group member respects selected end");

  reset(kChunk + 128); put(kChunk + 3, kValue); put<int32_t>(kChunk - 19, 24681357);
  engine.setGroupAnchorMode(true);
  scan(DataType::Int32, group, 2);
  expect(engine, {kChunk - 19, kChunk + 3}, "anchor group reads preceding block");
  allowedStart = kBase + kChunk;
  scan(DataType::Int32, group, 2); expect(engine, {}, "anchor group respects selected start");

  reset(kChunk + 128); put(kChunk - 3, kValue); put<int32_t>(kChunk + 10, 24681357);
  engine.setGroupAnchorMode(false);
  scan(DataType::Int32, std::to_string(kValue) + " u64;w:5;24681357 i32", 2);
  expect(engine, {kChunk - 3, kChunk + 10}, "layout group crossing block");
  reset(128); put(3, kValue); put<int32_t>(40, 24681357);
  engine.setGroupSearchRange(UINT64_MAX);
  scan(DataType::Int32, group, 2);
  expect(engine, {3, 40}, "huge group range clipped to region");
  scan(DataType::Int32, std::to_string(kValue) + " u64;w:18446744073709551615;24681357 i32", 2);
  expect(engine, {}, "huge layout skip cannot wrap");

  reset(kChunk + 8192);
  put(kChunk - 3, kValue); put<int32_t>(kChunk + 19, 24681357); put<int32_t>(kChunk + 5000, 13579246);
  engine.setGroupSearchRange(6000);
  mutateAfterReadingOffset = kChunk + 19;
  scan(DataType::Int32, group + ";13579246 i32", 2);
  expect(engine, {kChunk - 3, kChunk + 19, kChunk + 5000}, "complete group retained across cache windows");
  auto capturedGroup = engine.getResults(0, 3);
  require(capturedGroup[1].value.i32 == 24681357, "group stores value captured during match");

  std::printf("PASS %zu integer scan checks (production engine, ASan + UBSan)\n", checks);
}
