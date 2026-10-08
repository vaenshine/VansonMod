#include "../src/memory/core/MemoryCore.hpp"
#include "../src/memory/core/StringSearch.hpp"
#include "../src/utils/managers/StorageCore.hpp"
#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <string>
#include <unistd.h>
#include <vector>

using VMCore::DataType;
using VMCore::StringEncoding;
static constexpr uint64_t kBase = 0x145966000ULL;
static constexpr size_t kChunk = 1024 * 1024;
static std::vector<uint8_t> memory;
static size_t shortReadLimit = SIZE_MAX;
static uint64_t allowedStart, allowedEnd;
static size_t invalidReads, checks;
static std::function<void()> onRead;

// Mock only Mach transport; all scans use the shipped MemoryCore implementation.
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
  if (onRead) { auto callback = std::move(onRead); onRead = {}; callback(); }
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
  memory.assign(size, 0xFF);
  allowedStart = kBase;
  allowedEnd = kBase + size;
  shortReadLimit = SIZE_MAX;
  invalidReads = 0;
  onRead = {};
}

// Test fixture encoding uses C++ UTF-16 literals, independently of production conversion.
static std::vector<uint8_t> encode(const std::string &utf8, const std::u16string &utf16,
                                 StringEncoding encoding) {
  if (encoding == StringEncoding::UTF8) return {utf8.begin(), utf8.end()};
  std::vector<uint8_t> bytes;
  for (uint16_t unit : utf16) {
    if (encoding == StringEncoding::UTF16LE) {
      bytes.push_back(unit & 0xFF); bytes.push_back(unit >> 8);
    } else {
      bytes.push_back(unit >> 8); bytes.push_back(unit & 0xFF);
    }
  }
  return bytes;
}

static void put(size_t offset, const std::vector<uint8_t> &bytes) {
  require(offset <= memory.size() && bytes.size() <= memory.size() - offset, "fixture bounds");
  std::copy(bytes.begin(), bytes.end(), memory.begin() + offset);
}

static void expect(VMCore::MemoryCore &engine, const std::vector<size_t> &offsets,
                   const std::string &name, const std::vector<size_t> &lengths = {}) {
  auto results = engine.getResults(0, engine.getResultCount());
  std::vector<uint64_t> actual, expected;
  for (auto &r : results) actual.push_back(r.address);
  for (size_t offset : offsets) expected.push_back(kBase + offset);
  std::sort(actual.begin(), actual.end());
  std::sort(expected.begin(), expected.end());
  if (actual != expected)
    std::fprintf(stderr, "%s: expected %zu results, got %zu\n", name.c_str(), expected.size(), actual.size());
  require(actual == expected, name);
  for (size_t i = 0; i < lengths.size(); ++i)
    require(results[i].value.u64 == lengths[i], name + " actual matched byte length");
}

int main(int argc, char **argv) {
  require(argc == 2, "temporary storage directory");
  VMCore::MemoryCore engine;
  require(engine.attach(getpid()), "attach fixture transport");
  engine.setStoragePath(std::string(argv[1]) + "/strings.bin", std::string(argv[1]) + "/strings-swap.bin");
  require(engine.getStringSearchOptions().encoding == StringEncoding::UTF8 &&
          engine.getStringSearchOptions().caseSensitive, "backward-compatible default options");
  auto scan = [&](const std::string &query) {
    engine.scan(DataType::String, query, 0, allowedStart, allowedEnd);
    require(invalidReads == 0, "initial search stays within region and selected bounds");
  };
  auto rescan = [&](const std::string &query) {
    engine.nextScan({}, DataType::String, query, 100);
    require(invalidReads == 0, "rescan stays within readable region");
  };

  for (auto encoding : {StringEncoding::UTF8, StringEncoding::UTF16LE, StringEncoding::UTF16BE}) {
    engine.setStringSearchOptions({encoding, true});
    const auto original = encode("Vanson中文😀", u"Vanson中文😀", encoding);
    const auto changed = encode("vanson中文😀", u"vanson中文😀", encoding);
    for (size_t alignment = 0; alignment < 8; ++alignment) {
      reset(512); put(32 + alignment, original); put(160 + alignment, changed);
      scan("Vanson中文😀");
      expect(engine, {32 + alignment}, "sensitive Unicode and emoji at every byte alignment", {original.size()});
      rescan("Vanson中文😀");
      expect(engine, {32 + alignment}, "sensitive rescan retains exact address", {original.size()});
      engine.setStringSearchOptions({encoding, false});
      scan("VANSON中文😀");
      expect(engine, {32 + alignment, 160 + alignment}, "insensitive Unicode and emoji at every alignment");
      engine.setStringSearchOptions({encoding, true});
    }

    for (bool sensitive : {true, false}) {
      engine.setStringSearchOptions({encoding, sensitive});
      reset(kChunk + 256); put(kChunk - 3, original); put(kChunk + 80, original);
      scan("Vanson中文😀");
      expect(engine, {kChunk - 3, kChunk + 80}, "cross-block matches have no misses or duplicates");
      reset(8192); put(4093, original);
      scan("Vanson中文😀"); rescan("Vanson中文😀");
      expect(engine, {4093}, "cross-page initial and subsequent search");

      reset(original.size() + 7); put(7, original);
      scan("Vanson中文😀"); rescan("Vanson中文😀");
      expect(engine, {7}, "last complete string at region end", {original.size()});
      --allowedEnd;
      scan("Vanson中文😀"); expect(engine, {}, "reject incomplete string at selected end");
      ++allowedEnd; allowedStart = kBase + 8;
      scan("Vanson中文😀"); expect(engine, {}, "exclude start preceding selected range");
    }

    engine.setStringSearchOptions({encoding, false});
    reset(1024);
    const auto sharpS = encode("Straße", u"Straße", encoding);
    const auto expanded = encode("STRASSE", u"STRASSE", encoding);
    put(11, sharpS); put(89, expanded);
    scan("strasse"); expect(engine, {11, 89}, "full sharp-S folding", {sharpS.size(), expanded.size()});
    rescan("STRAẞE"); expect(engine, {11, 89}, "folded rescan tracks variable byte lengths", {sharpS.size(), expanded.size()});
    reset(128); put(3, encode("ß", u"ß", encoding));
    scan("s"); expect(engine, {}, "full scalar fold required at match end");
    scan("ss"); expect(engine, {3}, "two folded scalars match one original scalar");

    reset(1024);
    put(3, encode("ÉCOLE", u"ÉCOLE", encoding));
    put(100, encode("Σσς", u"Σσς", encoding));
    put(200, encode("ПрИвЕт", u"ПрИвЕт", encoding));
    put(300, encode("𐐀𐐁", u"𐐀𐐁", encoding));
    put(400, encode("İ", u"İ", encoding));
    put(500, encode("ﬃ", u"ﬃ", encoding));
    scan("école"); expect(engine, {3}, "accented Latin case folding");
    scan("σσσ"); expect(engine, {100}, "Greek final sigma case folding");
    scan("привет"); expect(engine, {200}, "Cyrillic case folding");
    scan("𐐨𐐩"); expect(engine, {300}, "supplementary-plane case folding");
    scan("i̇"); expect(engine, {400}, "Unicode default dotted-I expansion");
    scan("ffi"); expect(engine, {500}, "three-scalar ligature expansion");
    scan("ecole"); expect(engine, {}, "case folding preserves diacritics");

    engine.setStringSearchOptions({encoding, true});
    reset(512); put(3, encode("prefixneedle", u"prefixneedle", encoding));
    scan("prefix"); rescan("needle");
    expect(engine, {}, "rescan never retains an address based on a later substring");

    const std::string longText = std::string(100, 'x') + "中文😀tail";
    const std::u16string longUTF16 = std::u16string(100, u'x') + u"中文😀tail";
    const auto longBytes = encode(longText, longUTF16, encoding);
    reset(1024); put(3, longBytes);
    scan(longText); rescan(longText);
    expect(engine, {3}, "rescan supports strings longer than old 64-byte buffer", {longBytes.size()});
    shortReadLimit = longBytes.size() - 1;
    rescan(longText); expect(engine, {}, "successful incomplete read cannot match full string");

    reset(128); put(3, encode("a,b;c~d", u"a,b;c~d", encoding));
    scan("a,b;c~d"); expect(engine, {3}, "string punctuation is literal");
    scan(""); expect(engine, {}, "empty initial string produces no results");
    scan(std::string("\xC0\xAF", 2)); expect(engine, {}, "invalid overlong UTF-8 query rejected");
    scan(std::string("\xED\xA0\x80", 3)); expect(engine, {}, "UTF-8 encoded surrogate query rejected");
    scan(std::string("\xF4\x90\x80\x80", 4)); expect(engine, {}, "out-of-range scalar query rejected");
    scan("a,b;c~d"); rescan(""); expect(engine, {3}, "invalid rescan preserves previous results for retry");

    const auto prefix = encode("中文😀", u"中文😀", encoding);
    auto nulTerminated = prefix;
    nulTerminated.insert(nulTerminated.end(), encoding == StringEncoding::UTF8 ? 1 : 2, 0);
    const auto suffix = encode("tail", u"tail", encoding);
    nulTerminated.insert(nulTerminated.end(), suffix.begin(), suffix.end());
    require(VMCore::validStringPrefixLength(nulTerminated.data(), nulTerminated.size(), encoding) == prefix.size(),
            "preview stops at Unicode NUL, keeps zero bytes inside UTF16 units");
    require(VMCore::validStringPrefixLength(prefix.data(), prefix.size() - 1, encoding) == prefix.size() - 4,
            "preview omits incomplete final emoji");

    reset(256); put(3, original);
    engine.setStringSearchOptions({encoding, false});
    onRead = [&]() { engine.setStringSearchOptions({StringEncoding::UTF8, true}); };
    scan("VANSON中文😀"); expect(engine, {3}, "in-flight initial options are immutable");
    engine.setStringSearchOptions({encoding, false});
    onRead = [&]() { engine.setStringSearchOptions({StringEncoding::UTF8, true}); };
    rescan("VANSON中文😀"); expect(engine, {3}, "in-flight rescan options are immutable");
  }

  engine.setStringSearchOptions({StringEncoding::UTF16LE, false});
  reset(128); put(3, {0x00, 0xD8, 0x41, 0x00});
  scan("😀"); expect(engine, {}, "malformed UTF16 surrogate candidate rejected");
  engine.setStringSearchOptions({StringEncoding::UTF8, false});
  reset(128); put(3, {0xC0, 0xAF});
  scan("/"); expect(engine, {}, "malformed UTF8 memory candidate rejected");
  // Session restoration validates before changing the active file or count.
  engine.setStringSearchOptions({StringEncoding::UTF8, true});
  reset(128); put(3, {'t', 'e', 's', 't'}); scan("test");
  const std::string activePath = std::string(argv[1]) + "/strings.bin";
  const std::string backupPath = std::string(argv[1]) + "/restore-backup.bin";
  auto readFile = [](const std::string &path) {
    FILE *file = fopen(path.c_str(), "rb");
    std::vector<uint8_t> data;
    if (file) { int ch; while ((ch = fgetc(file)) != EOF) data.push_back(ch); fclose(file); }
    return data;
  };
  auto writeFile = [](const std::string &path, const std::vector<uint8_t> &data) {
    FILE *file = fopen(path.c_str(), "wb");
    require(file != nullptr, "create restoration fixture");
    require(fwrite(data.data(), 1, data.size(), file) == data.size(), "write restoration fixture");
    fclose(file);
  };
  const auto originalFile = readFile(activePath);
  require(!originalFile.empty(), "existing result file before adoption");
  engine.clearResults();
  require(engine.restoreResultsFromFile(activePath, 1), "adopt same result file path");
  expect(engine, {3}, "same-path adoption restores count and data", {4});
  require(readFile(activePath) == originalFile, "same-path adoption preserves file bytes");
  require(!engine.restoreResultsFromFile(activePath, 2), "reject count larger than file");
  require(!engine.restoreResultsFromFile(activePath, 0), "reject count smaller than file");
  require(!engine.restoreResultsFromFile(activePath, SIZE_MAX), "reject overflowing count");
  require(!engine.restoreResultsFromFile(std::string(argv[1]) + "/missing.bin", 1), "reject missing source");
  require(!engine.restoreResultsFromFile("", 1), "reject empty source with nonzero count");
  expect(engine, {3}, "failed validation retains old count and data");
  require(readFile(activePath) == originalFile, "failed validation preserves old file");
  auto partial = originalFile; partial.pop_back();
  writeFile(backupPath, partial);
  require(!engine.restoreResultsFromFile(backupPath, 1), "reject partial result record");
  require(readFile(activePath) == originalFile && readFile(backupPath) == partial,
          "invalid source leaves both files intact");
  writeFile(backupPath, originalFile);
  const std::string unavailablePath = std::string(argv[1]) + "/missing-dir/results.bin";
  engine.setStoragePath(unavailablePath, std::string(argv[1]) + "/unused-swap.bin");
  require(!engine.restoreResultsFromFile(backupPath, 1), "rename failure is reported");
  require(engine.getResultCount() == 1 && readFile(activePath) == originalFile &&
          readFile(backupPath) == originalFile, "rename failure preserves source, old file and count");
  engine.setStoragePath(activePath, std::string(argv[1]) + "/strings-swap.bin");
  require(engine.restoreResultsFromFile(backupPath, 1), "validated backup atomically replaces active file");
  require(access(backupPath.c_str(), F_OK) != 0, "successful restore consumes backup");
  expect(engine, {3}, "restored backup keeps matched-byte metadata", {4});
  writeFile(backupPath, {});
  require(engine.restoreResultsFromFile(backupPath, 0), "empty session file can be restored");
  require(engine.getResultCount() == 0 && readFile(activePath).empty(), "zero-result restore clears state");
  require(engine.restoreResultsFromFile("", 0), "explicit empty session clears storage");
  require(engine.getResultCount() == 0 && access(activePath.c_str(), F_OK) != 0,
          "explicit clear removes result file");

  std::printf("PASS %zu string search checks (production engine, ASan + UBSan)\n", checks);
}
