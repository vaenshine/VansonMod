#ifndef MemoryCore_cpp
#define MemoryCore_cpp

#include "MemoryCore.hpp"
#include "../../utils/managers/StorageCore.hpp"
#include <algorithm>
#include <arm_neon.h>
#include <atomic>
#include <cctype>
#include <cmath>
#include <cstring>
#include <dispatch/dispatch.h>
#include <mach/mach.h>
#include <memory>
#include <unordered_set>
#include <unordered_map>
#include <utility>

#include <sstream>
#include <sys/sysctl.h>
#include <unistd.h>

extern "C" {
kern_return_t mach_vm_read_overwrite(vm_map_t target_task,
                                     mach_vm_address_t address,
                                     mach_vm_size_t size,
                                     mach_vm_address_t data,
                                     mach_vm_size_t *out_size);
kern_return_t mach_vm_write(vm_map_t target_task, mach_vm_address_t address,
                            vm_offset_t data, mach_msg_type_number_t dataCnt);
kern_return_t mach_vm_region(vm_map_t target_task, mach_vm_address_t *address,
                             mach_vm_size_t *size, vm_region_flavor_t flavor,
                             vm_region_info_t info,
                             mach_msg_type_number_t *infoCnt,
                             mach_port_t *object_name);
kern_return_t mach_vm_protect(vm_map_t target_task, mach_vm_address_t address,
                              mach_vm_size_t size, boolean_t set_maximum,
                              vm_prot_t new_protection);
kern_return_t mach_vm_region_recurse(vm_map_t target_task,
                                     mach_vm_address_t *address,
                                     mach_vm_size_t *size,
                                     uint32_t *nesting_depth,
                                     vm_region_recurse_info_t info,
                                     mach_msg_type_number_t *infoCnt);
int ptrace(int request, pid_t pid, caddr_t addr, int data);
}

namespace VMCore {

struct RawResult {
  uint64_t address;
  uint64_t value;
  uint8_t type;
  uint8_t padding1;
  uint16_t padding2;
  uint8_t padding[4];    
};

static inline RawResult makeRawResult(uint64_t addr, uint64_t val, DataType type = DataType::Int32) {
  RawResult r;
  r.address = addr;
  r.value = val;
  r.type = (uint8_t)type;
  r.padding1 = 0;
  r.padding2 = 0;
  memset(r.padding, 0, sizeof(r.padding));
  return r;
}

static size_t getSizeForType(DataType type) {
  switch (type) {
  case DataType::Int8:
  case DataType::UInt8:
    return 1;
  case DataType::Int16:
  case DataType::UInt16:
    return 2;
  case DataType::Int32:
  case DataType::UInt32:
  case DataType::Float:
    return 4;
  case DataType::Int64:
  case DataType::UInt64:
  case DataType::Double:
    return 8;
  default:
    return 1;
  }
}

static bool hasRangeSeparator(const std::string &s) {
  return s.find(',') != std::string::npos ||
         s.find("\xEF\xBC\x8C") != std::string::npos ||
         s.find('~') != std::string::npos ||
         s.find("\xEF\xBD\x9E") != std::string::npos;
}

static bool isFloatingDataType(DataType type) {
  return type == DataType::Float || type == DataType::Double;
}

static bool isUnsignedDataType(DataType type) {
  return type == DataType::UInt8 || type == DataType::UInt16 ||
         type == DataType::UInt32 || type == DataType::UInt64;
}

static int64_t readSignedValue(const void *ptr, DataType type) {
  switch (type) {
    case DataType::Int8: return *(const int8_t *)ptr;
    case DataType::Int16: return *(const int16_t *)ptr;
    case DataType::Int32: return *(const int32_t *)ptr;
    case DataType::Int64: return *(const int64_t *)ptr;
    default: {
      uint64_t value = 0;
      size_t size = getSizeForType(type);
      memcpy(&value, ptr, std::min((size_t)8, size));
      return (int64_t)value;
    }
  }
}

static uint64_t readUnsignedValue(const void *ptr, DataType type) {
  switch (type) {
    case DataType::UInt8: return *(const uint8_t *)ptr;
    case DataType::UInt16: return *(const uint16_t *)ptr;
    case DataType::UInt32: return *(const uint32_t *)ptr;
    case DataType::UInt64: return *(const uint64_t *)ptr;
    case DataType::Int8: return (uint64_t)(uint8_t)(*(const int8_t *)ptr);
    case DataType::Int16: return (uint64_t)(uint16_t)(*(const int16_t *)ptr);
    case DataType::Int32: return (uint64_t)(uint32_t)(*(const int32_t *)ptr);
    case DataType::Int64: return (uint64_t)(*(const int64_t *)ptr);
    default: {
      uint64_t value = 0;
      size_t size = getSizeForType(type);
      memcpy(&value, ptr, std::min((size_t)8, size));
      return value;
    }
  }
}

static int64_t groupSignedValue(const GroupItem::Value &value, DataType type) {
  switch (type) {
    case DataType::Int8: return value.i8;
    case DataType::Int16: return value.i16;
    case DataType::Int32: return value.i32;
    case DataType::Int64: return value.i64;
    default: return (int64_t)value.u64;
  }
}

static uint64_t groupUnsignedValue(const GroupItem::Value &value, DataType type) {
  switch (type) {
    case DataType::UInt8: return value.u8;
    case DataType::UInt16: return value.u16;
    case DataType::UInt32: return value.u32;
    case DataType::UInt64: return value.u64;
    case DataType::Int8: return (uint64_t)(uint8_t)value.i8;
    case DataType::Int16: return (uint64_t)(uint16_t)value.i16;
    case DataType::Int32: return (uint64_t)(uint32_t)value.i32;
    case DataType::Int64: return (uint64_t)value.i64;
    default: return value.u64;
  }
}

static double groupFloatValue(const GroupItem::Value &value, DataType type) {
  return type == DataType::Float ? (double)value.f : value.d;
}

static bool matchGroupItemValue(const void *ptr, const GroupItem &item,
                                double floatTolerance) {
  if (item.isWildcard)
    return true;

  if (isFloatingDataType(item.type)) {
    double value = item.type == DataType::Float ? (double)(*(const float *)ptr)
                                                : *(const double *)ptr;
    if (item.isRange) {
      double minValue = groupFloatValue(item.minValue, item.type);
      double maxValue = groupFloatValue(item.maxValue, item.type);
      if (minValue > maxValue)
        std::swap(minValue, maxValue);
      return value >= minValue - floatTolerance &&
             value <= maxValue + floatTolerance;
    }
    double target = groupFloatValue(item.value, item.type);
    return std::abs(value - target) <= floatTolerance;
  }

  if (isUnsignedDataType(item.type)) {
    uint64_t value = readUnsignedValue(ptr, item.type);
    if (item.isRange) {
      uint64_t minValue = groupUnsignedValue(item.minValue, item.type);
      uint64_t maxValue = groupUnsignedValue(item.maxValue, item.type);
      if (minValue > maxValue)
        std::swap(minValue, maxValue);
      return value >= minValue && value <= maxValue;
    }
    return value == groupUnsignedValue(item.value, item.type);
  }

  int64_t value = readSignedValue(ptr, item.type);
  if (item.isRange) {
    int64_t minValue = groupSignedValue(item.minValue, item.type);
    int64_t maxValue = groupSignedValue(item.maxValue, item.type);
    if (minValue > maxValue)
      std::swap(minValue, maxValue);
    bool matched = value >= minValue && value <= maxValue;
    if (item.type == DataType::Int64 && minValue >= 0) {
      uint64_t stripped = ((uint64_t)value) & 0xFFFFFFFFFFFFULL;
      matched = matched || (stripped >= (uint64_t)minValue &&
                            stripped <= (uint64_t)maxValue);
    }
    return matched;
  }

  int64_t target = groupSignedValue(item.value, item.type);
  return value == target ||
         (item.type == DataType::Int64 &&
          (((uint64_t)value) & 0xFFFFFFFFFFFFULL) ==
              (((uint64_t)target) & 0xFFFFFFFFFFFFULL));
}

static std::string trimGroupToken(const std::string &input) {
  std::string s = input;
  size_t first = s.find_first_not_of(" \t\n\r");
  if (first == std::string::npos)
    return "";
  size_t last = s.find_last_not_of(" \t\n\r");
  return s.substr(first, last - first + 1);
}

static bool isWildcardGroupToken(const std::string &s) {
  return s == "*" || s == "?";
}

static bool parseGroupSkipToken(const std::string &s, uint64_t &skipBytes) {
  std::string lower = s;
  std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
  if (lower.rfind("w:", 0) != 0)
    return false;
  std::string num = lower.substr(2);
  try {
    skipBytes = (num.rfind("0x", 0) == 0) ? std::stoull(num, nullptr, 16)
                                          : std::stoull(num);
    return true;
  } catch (...) {
    skipBytes = 0;
    return true;
  }
}

static bool dataTypeFromBytePrefix(const std::string &prefix, DataType &type) {
  if (prefix == "1") {
    type = DataType::Int8;
    return true;
  }
  if (prefix == "2") {
    type = DataType::Int16;
    return true;
  }
  if (prefix == "4") {
    type = DataType::Int32;
    return true;
  }
  if (prefix == "8") {
    type = DataType::Int64;
    return true;
  }
  return false;
}

static bool stripGroupBytePrefix(std::string &valStr, DataType &type) {
  size_t colon = valStr.find(':');
  if (colon == std::string::npos)
    return false;
  std::string prefix = trimGroupToken(valStr.substr(0, colon));
  if (prefix.empty() ||
      prefix.find_first_not_of("0123456789") != std::string::npos)
    return false;
  DataType parsedType = type;
  if (!dataTypeFromBytePrefix(prefix, parsedType))
    return false;
  type = parsedType;
  valStr = trimGroupToken(valStr.substr(colon + 1));
  return true;
}

static bool groupUsesLayoutMode(const std::vector<GroupItem> &items) {
  for (const GroupItem &item : items) {
    if (item.isWildcard || item.skipBytes > 0)
      return true;
  }
  return false;
}

static bool matchGroupLayoutAt(uint8_t *memBuffer, size_t readSize,
                               size_t startOffset,
                               const std::vector<GroupItem> &items,
                               double floatTolerance,
                               std::vector<std::pair<uint64_t, size_t>> &matches,
                               uint64_t chunkBase) {
  size_t cursor = startOffset;
  matches.clear();
  for (size_t i = 0; i < items.size(); ++i) {
    const GroupItem &item = items[i];
    if (item.skipBytes > 0) {
      if (cursor + item.skipBytes > readSize)
        return false;
      cursor += (size_t)item.skipBytes;
      continue;
    }

    size_t itemSize = getSizeForType(item.type);
    if (cursor + itemSize > readSize)
      return false;
    if (!item.isWildcard &&
        !matchGroupItemValue(memBuffer + cursor, item, floatTolerance))
      return false;
    if (!item.isWildcard)
      matches.push_back({chunkBase + cursor, i});
    cursor += itemSize;
  }
  return !matches.empty();
}

MemoryCore::MemoryCore() : _pid(0), _task(MACH_PORT_NULL), _resultLimit(0), _floatTolerance(0.001), _groupSearchRange(0x100), _groupAnchorMode(false) {}

MemoryCore::~MemoryCore() {
  clearFastFuzzySnapshot();
  if (_task != MACH_PORT_NULL) {
    mach_port_deallocate(mach_task_self(), _task);
  }
}

bool MemoryCore::attach(pid_t pid) {
  
  if (_task != MACH_PORT_NULL && _task != mach_task_self()) {
    mach_port_deallocate(mach_task_self(), _task);
    _task = MACH_PORT_NULL;
  }
  
  _pid = pid;
  if (pid == getpid()) {
    _task = mach_task_self();
    return true;
  }
  
  kern_return_t kr = task_for_pid(mach_task_self(), pid, &_task);
  if (kr != KERN_SUCCESS) {
    _task = MACH_PORT_NULL;
    return false;
  }
  return true;
}

bool MemoryCore::readMemory(uint64_t address, void *buffer, size_t size) {
  if (_task == MACH_PORT_NULL)
    return false;
  mach_vm_size_t readSize = 0;
  kern_return_t kr = mach_vm_read_overwrite(
      _task, address, size, (mach_vm_address_t)buffer, &readSize);
  return (kr == KERN_SUCCESS && readSize == size);
}

bool MemoryCore::writeMemory(uint64_t address, const void *buffer,
                             size_t size) {
  if (_task == MACH_PORT_NULL)
    return false;
  kern_return_t kr = mach_vm_write(_task, address, (vm_offset_t)buffer,
                                   (mach_msg_type_number_t)size);
  if (kr != KERN_SUCCESS) {
    mach_vm_protect(_task, address, size, FALSE,
                    VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    kr = mach_vm_write(_task, address, (vm_offset_t)buffer,
                       (mach_msg_type_number_t)size);
    mach_vm_protect(_task, address, size, FALSE,
                    VM_PROT_READ | VM_PROT_EXECUTE);
  }
  return (kr == KERN_SUCCESS);
}

void MemoryCore::parseValue(const std::string &valStr, DataType type,
                            void *outVal) {
  try {
    switch (type) {
    case DataType::Int8:
      *(int8_t *)outVal = (int8_t)std::stoi(valStr);
      break;
    case DataType::Int16:
      *(int16_t *)outVal = (int16_t)std::stoi(valStr);
      break;
    case DataType::Int32:
      *(int32_t *)outVal = std::stoi(valStr);
      break;
    case DataType::Int64:
      *(int64_t *)outVal = std::stoll(valStr);
      break;
    case DataType::UInt8:
      *(uint8_t *)outVal = (uint8_t)std::stoul(valStr);
      break;
    case DataType::UInt16:
      *(uint16_t *)outVal = (uint16_t)std::stoul(valStr);
      break;
    case DataType::UInt32:
      *(uint32_t *)outVal = (uint32_t)std::stoul(valStr);
      break;
    case DataType::UInt64:
      *(uint64_t *)outVal = std::stoull(valStr);
      break;
    case DataType::Float:
      *(float *)outVal = std::stof(valStr);
      break;
    case DataType::Double:
      *(double *)outVal = std::stod(valStr);
      break;
    default:
      break;
    }
  } catch (...) {
    memset(outVal, 0, 8);
  }
}

static DataType getTypeFromSuffix(std::string &valStr, DataType defaultType) {
  size_t spacePos = valStr.find_last_of(' ');
  if (spacePos != std::string::npos) {
    std::string suffix = valStr.substr(spacePos + 1);
    suffix.erase(0, suffix.find_first_not_of("\t\n\v\f\r "));
    std::transform(suffix.begin(), suffix.end(), suffix.begin(), ::tolower);
    DataType type = defaultType;
    bool found = true;
    if (suffix == "i8")
      type = DataType::Int8;
    else if (suffix == "i16")
      type = DataType::Int16;
    else if (suffix == "i32")
      type = DataType::Int32;
    else if (suffix == "i64")
      type = DataType::Int64;
    else if (suffix == "f32")
      type = DataType::Float;
    else if (suffix == "f64")
      type = DataType::Double;
    else if (suffix == "u8")
      type = DataType::UInt8;
    else if (suffix == "u16")
      type = DataType::UInt16;
    else if (suffix == "u32")
      type = DataType::UInt32;
    else if (suffix == "u64")
      type = DataType::UInt64;
    else
      found = false;
    if (found) {
      valStr = valStr.substr(0, spacePos);
      return type;
    }
  }
  return defaultType;
}

std::vector<GroupItem> MemoryCore::parseGroupString(const std::string &groupStr,
                                                    DataType defaultType,
                                                    uint64_t &outRange) {
  std::vector<GroupItem> items;
  std::string parseStr = groupStr;
  size_t rangePos = groupStr.find("::");
  if (rangePos != std::string::npos) {
    std::string rangePart = groupStr.substr(rangePos + 2);
    try {
      if (rangePart.find("0x") == 0)
        outRange = std::stoull(rangePart, nullptr, 16);
      else
        outRange = std::stoull(rangePart);
    } catch (...) {
      
    }
    parseStr = groupStr.substr(0, rangePos);
  }
  
  std::vector<std::string> rawItems;
  if (parseStr.find(';') != std::string::npos) {
    
    std::stringstream ss2(parseStr);
    std::string s;
    while (std::getline(ss2, s, ';'))
      rawItems.push_back(s);
  } else {
    
    std::string current;
    for (size_t i = 0; i < parseStr.size(); ++i) {
      char c = parseStr[i];
      if (c == ' ' || c == '\t') {
        if (!current.empty()) {
          rawItems.push_back(current);
          current.clear();
        }
      } else if (c == '-') {
        
        if (current.empty()) {
          current += c;
        } else {
          
          rawItems.push_back(current);
          current = "-";
        }
      } else {
        current += c;
      }
    }
    if (!current.empty()) {
      rawItems.push_back(current);
    }
  }
  for (auto &raw : rawItems) {
    raw = trimGroupToken(raw);
    if (raw.empty())
      continue;
    DataType itemType = getTypeFromSuffix(raw, defaultType);
    stripGroupBytePrefix(raw, itemType);
    GroupItem item;
    item.type = itemType;
    item.relative = false;
    item.isRange = false;
    item.isWildcard = false;
    item.skipBytes = 0;
    memset(&item.value, 0, sizeof(item.value));
    memset(&item.minValue, 0, sizeof(item.minValue));
    memset(&item.maxValue, 0, sizeof(item.maxValue));
    uint64_t skipBytes = 0;
    if (parseGroupSkipToken(raw, skipBytes)) {
      item.skipBytes = skipBytes;
    } else if (isWildcardGroupToken(raw)) {
      item.isWildcard = true;
    } else if (hasRangeSeparator(raw)) {
      item.isRange = true;
      parseRangeString(raw, itemType, &item.minValue, &item.maxValue);
    } else {
      parseValue(raw, itemType, &item.value);
    }
    items.push_back(item);
  }
  return items;
}

void MemoryCore::parseRangeString(const std::string &rangeStr, DataType type,
                                  void *minVal, void *maxVal) {
  std::string s = rangeStr;
  
  size_t sep = std::string::npos;
  // Check ',' first
  size_t pos = s.find(',');
  if (pos != std::string::npos) {
    sep = pos;
  } else {
    // Check Chinese comma U+FF0C (UTF-8: 0xEF 0xBC 0x8C)
    pos = s.find("\xEF\xBC\x8C");
    if (pos != std::string::npos) {
      // Erase the extra 2 bytes of the 3-byte UTF-8 char, leave 1 as separator position
      s.erase(pos + 1, 2);
      sep = pos;
    } else {
      // Check '~'
      pos = s.find('~');
      if (pos != std::string::npos) {
        sep = pos;
      } else {
        // Check Chinese tilde U+FF5E (UTF-8: 0xEF 0xBD 0x9E)
        pos = s.find("\xEF\xBD\x9E");
        if (pos != std::string::npos) {
          s.erase(pos + 1, 2);
          sep = pos;
        }
      }
    }
  }
  
  if (sep != std::string::npos) {
    std::string v1 = s.substr(0, sep);
    std::string v2 = s.substr(sep + 1);
    
    // For integer types with decimal input, use ceil for min and floor for max
    bool isIntType = (type != DataType::Float && type != DataType::Double && type != DataType::String);
    bool v1HasDot = (v1.find('.') != std::string::npos);
    bool v2HasDot = (v2.find('.') != std::string::npos);
    
    if (isIntType && (v1HasDot || v2HasDot)) {
      double dMin = 0, dMax = 0;
      try { dMin = std::stod(v1); } catch (...) {}
      try { dMax = std::stod(v2); } catch (...) {}
      // ceil min, floor max so range is strictly within user's intent
      int64_t iMin = (int64_t)std::ceil(dMin);
      int64_t iMax = (int64_t)std::floor(dMax);
      std::string sMin = std::to_string(iMin);
      std::string sMax = std::to_string(iMax);
      parseValue(sMin, type, minVal);
      parseValue(sMax, type, maxVal);
    } else {
      parseValue(v1, type, minVal);
      parseValue(v2, type, maxVal);
    }
  } else {
    parseValue(s, type, minVal);
    parseValue(s, type, maxVal);
  }
}

std::vector<ScanResult> MemoryCore::scan(DataType type,
                                         const std::string &valueStr,
                                         int searchMode, uint64_t start,
                                         uint64_t end) {
  _resultCount = 0;
  std::vector<ScanResult> emptyRes;
  if (_task == MACH_PORT_NULL || _storagePath.empty())
    return emptyRes;
  FILE *outFile = fopen(_storagePath.c_str(), "wb");
  if (!outFile)
    return emptyRes;

  vm_map_size_t size = 0;

  int sMode = (int)searchMode;
  
  uint64_t endAddress = end;
  if (endAddress == 0) {
    if (sMode == 1) {
      
      endAddress = 0x800000000;
    } else {
      
      std::string userEndAddr =
          VMCore::StorageCore::shared().getString("endAddr", "");
      if (!userEndAddr.empty()) {
        endAddress = std::stoull(userEndAddr, nullptr, 16);
      } else {
        endAddress = 0x400000000; 
      }
    }
  }

  union {
    int8_t i8;
    int16_t i16;
    int32_t i32;
    int64_t i64;
    uint8_t u8;
    uint16_t u16;
    uint32_t u32;
    uint64_t u64;
    float f;
    double d;
  } target, minVal, maxVal;
  memset(&target, 0, sizeof(target));
  memset(&minVal, 0, sizeof(minVal));
  memset(&maxVal, 0, sizeof(maxVal));

  DataType dType = type;
  size_t dSize = getSizeForType(type);

  std::vector<GroupItem> gItems;
  uint64_t groupRange = _groupSearchRange; 

  if (sMode == 2) { 
    gItems = parseGroupString(valueStr, type, groupRange);
    if (gItems.empty())
      sMode = 0; 
  } else if (sMode == 3) { 
    parseRangeString(valueStr, type, &minVal, &maxVal);
  } else { 
    parseValue(valueStr, type, &target);
  }

  struct Region {
    uint64_t start;
    uint64_t size;
  };
  std::vector<Region> regions;

  vm_map_offset_t address = (start > 0) ? start : 0x100000000;
  uint32_t depth = 0;
  mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
  vm_region_submap_info_data_64_t info;

  while (true) {
    if (endAddress > 0 && address >= endAddress)
      break;
    kern_return_t kr =
        mach_vm_region_recurse(_task, &address, &size, &depth,
                               (vm_region_recurse_info_t)&info, &count);
    if (kr != KERN_SUCCESS)
      break;

    if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE)) {
      if (size <= 1024 * 1024 * 1024) { 
        regions.push_back({address, size});
      }
    }
    address += size;
  }

  std::sort(regions.begin(), regions.end(),
            [](const Region &a, const Region &b) { return a.start < b.start; });

  bool isFloatType = (type == DataType::Float || type == DataType::Double);

  if (sMode == 1) { 
    size_t chunkBufferSize = 1024 * 1024;
    uint8_t *memBuffer = (uint8_t *)malloc(chunkBufferSize);
    if (memBuffer) {
      for (const auto &r : regions) {
        uint64_t rEnd = std::min(r.start + r.size, endAddress);
        uint64_t curr = r.start;
        while (curr < rEnd) {
          uint64_t chunkSize = std::min(chunkBufferSize, (size_t)(rEnd - curr));
          mach_vm_size_t readSize = chunkSize;
          if (mach_vm_read_overwrite(_task, curr, chunkSize,
                                     (mach_vm_address_t)memBuffer,
                                     &readSize) == KERN_SUCCESS) {
            size_t limit = readSize >= dSize ? readSize - dSize : 0;
            std::vector<RawResult> chunkResults;
            for (size_t k = 0; k <= limit; k += dSize) {
              uint64_t val = 0;
              memcpy(&val, memBuffer + k, std::min((size_t)8, dSize));
              
              chunkResults.push_back(makeRawResult(curr + k, val, dType));
            }
            if (!chunkResults.empty()) {
              fwrite(chunkResults.data(), sizeof(RawResult),
                     chunkResults.size(), outFile);
              _resultCount += chunkResults.size();
            }
          }
          curr += chunkSize;
        }
      }
      free(memBuffer);
    }
  } else {
    
    std::vector<std::vector<RawResult>> perRegionResults(regions.size());
    std::vector<RawResult> *perRegionResultsPtr = perRegionResults.data();

    double floatTolerance = _floatTolerance;
    mach_port_t task = _task;
    
    int dataTypeInt = (int)dType;
    bool isFloat = (dType == DataType::Float);
    bool isFloatTypeLocal = isFloatType;  
    size_t dataSizeLocal = dSize;         
    int searchModeLocal = sMode;          
    
    std::vector<GroupItem> gItemsCopy = gItems;
    uint64_t groupRangeLocal = groupRange;
    bool groupAnchorModeLocal = _groupAnchorMode;  
    bool groupLayoutModeLocal = groupUsesLayoutMode(gItemsCopy);
    
    bool isStringType = (dType == DataType::String);
    std::string targetString = valueStr;
    size_t targetStringLen = targetString.length();
    
    float targetFloat = target.f;
    double targetDouble = target.d;
    int64_t targetInt64 = target.i64;
    
    uint64_t targetUInt64 = 0;
    switch (dType) {
      case DataType::Int8:   targetUInt64 = (uint64_t)(uint8_t)target.i8; break;
      case DataType::Int16:  targetUInt64 = (uint64_t)(uint16_t)target.i16; break;
      case DataType::Int32:  targetUInt64 = (uint64_t)(uint32_t)target.i32; break;
      case DataType::Int64:  targetUInt64 = (uint64_t)target.i64; break;
      case DataType::UInt8:  targetUInt64 = target.u8; break;
      case DataType::UInt16: targetUInt64 = target.u16; break;
      case DataType::UInt32: targetUInt64 = target.u32; break;
      case DataType::UInt64: targetUInt64 = target.u64; break;
      default: targetUInt64 = target.u64; break;
    }
    
    float minFloat = minVal.f;
    float maxFloat = maxVal.f;
    double minDouble = minVal.d;
    double maxDouble = maxVal.d;
    int64_t minInt64 = minVal.i64;
    int64_t maxInt64 = maxVal.i64;
    
    uint64_t minUInt64 = 0, maxUInt64 = 0;
    switch (dType) {
      case DataType::Int8:
        minUInt64 = (uint64_t)(uint8_t)minVal.i8;
        maxUInt64 = (uint64_t)(uint8_t)maxVal.i8;
        break;
      case DataType::Int16:
        minUInt64 = (uint64_t)(uint16_t)minVal.i16;
        maxUInt64 = (uint64_t)(uint16_t)maxVal.i16;
        break;
      case DataType::Int32:
        minUInt64 = (uint64_t)(uint32_t)minVal.i32;
        maxUInt64 = (uint64_t)(uint32_t)maxVal.i32;
        break;
      case DataType::Int64:
        minUInt64 = (uint64_t)minVal.i64;
        maxUInt64 = (uint64_t)maxVal.i64;
        break;
      case DataType::UInt8:
        minUInt64 = minVal.u8;
        maxUInt64 = maxVal.u8;
        break;
      case DataType::UInt16:
        minUInt64 = minVal.u16;
        maxUInt64 = maxVal.u16;
        break;
      case DataType::UInt32:
        minUInt64 = minVal.u32;
        maxUInt64 = maxVal.u32;
        break;
      default:
        minUInt64 = minVal.u64;
        maxUInt64 = maxVal.u64;
        break;
    }

    dispatch_apply(
        regions.size(),
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
        ^(size_t i) {
          Region r = regions[i];
          uint64_t rEnd = std::min(r.start + r.size, endAddress);
          size_t chunkBufferSize = 1024 * 1024;
          uint8_t *memBuffer = (uint8_t *)malloc(chunkBufferSize);
          if (!memBuffer)
            return;

          std::vector<RawResult> &localResults = perRegionResultsPtr[i];
          uint64_t curr = r.start;
          DataType alignmentType = dType;
          if (searchModeLocal == 2 && !gItemsCopy.empty()) {
            alignmentType = gItemsCopy[0].type;
          }
          int alignmentTypeInt = (int)alignmentType;
          if ((alignmentTypeInt == (int)DataType::Int64 ||
               alignmentTypeInt == (int)DataType::UInt64 ||
               alignmentTypeInt == (int)DataType::Double) && (curr % 8 != 0)) {
            uint64_t diff = 8 - (curr % 8);
            curr += diff;
          }
          while (curr < rEnd) {
            uint64_t chunkSize =
                std::min(chunkBufferSize, (size_t)(rEnd - curr));
            mach_vm_size_t readSize = chunkSize;
            if (mach_vm_read_overwrite(task, curr, chunkSize,
                                       (mach_vm_address_t)memBuffer,
                                       &readSize) == KERN_SUCCESS) {
              
              size_t limit;
              if (isStringType && targetStringLen > 0) {
                limit = readSize >= targetStringLen ? readSize - targetStringLen : 0;
              } else {
                size_t scanItemSize = dataSizeLocal;
                if (searchModeLocal == 2 && groupLayoutModeLocal) {
                  limit = readSize > 0 ? readSize - 1 : 0;
                } else if (searchModeLocal == 2 && !gItemsCopy.empty()) {
                  scanItemSize = getSizeForType(gItemsCopy[0].type);
                  limit = readSize >= scanItemSize ? readSize - scanItemSize : 0;
                } else {
                  limit = readSize >= scanItemSize ? readSize - scanItemSize : 0;
                }
              }
              
              size_t step;
              if (searchModeLocal == 2 && groupLayoutModeLocal) {
                step = 1;
                for (const auto &item : gItemsCopy) {
                  if (item.skipBytes == 0) {
                    step = item.isWildcard ? 1 : getSizeForType(item.type);
                    break;
                  }
                }
              } else if (searchModeLocal == 2 && !gItemsCopy.empty()) {
                step = getSizeForType(gItemsCopy[0].type);
              } else if (dataTypeInt == (int)DataType::String) {
                step = 1;
              } else {
                step = dataSizeLocal;
              }

              for (size_t k = 0; k <= limit; k += step) {
                bool match = false;
                uint64_t valBits = 0;
                void *ptr = memBuffer + k;

                if (searchModeLocal == 2 && groupLayoutModeLocal) {
                  std::vector<std::pair<uint64_t, size_t>> matchedItems;
                  if (matchGroupLayoutAt(memBuffer, readSize, k, gItemsCopy,
                                         floatTolerance, matchedItems, curr)) {
                    for (const auto &matchedItem : matchedItems) {
                      uint64_t addr = matchedItem.first;
                      size_t itemIndex = matchedItem.second;
                      size_t valueSize = getSizeForType(gItemsCopy[itemIndex].type);
                      RawResult res;
                      res.address = addr;
                      res.value = 0;
                      memcpy(&res.value, memBuffer + (addr - curr),
                             std::min((size_t)8, valueSize));
                      res.type = (uint8_t)gItemsCopy[itemIndex].type;
                      res.padding1 = 0;
                      res.padding2 = 0;
                      memset(res.padding, 0, sizeof(res.padding));
                      localResults.push_back(res);
                    }
                  }
                } else if (searchModeLocal == 2) {
                  const auto &firstItem = gItemsCopy[0];
                  bool firstMatch = matchGroupItemValue(ptr, firstItem, floatTolerance);

                  if (firstMatch) {
                    bool allMatched = true;
                    std::vector<std::pair<uint64_t, size_t>> matchedItems;
                    matchedItems.push_back({curr + k, 0});
                    size_t anchorOffset = k; 
                    size_t lastMatchOffset = k; 

                    for (size_t g = 1; g < gItemsCopy.size(); ++g) {
                      const auto &nextItem = gItemsCopy[g];
                      bool foundNext = false;
                      size_t nextSz = getSizeForType(nextItem.type);
                      
                      size_t minOff, maxOff;
                      if (groupAnchorModeLocal) {
                        
                        minOff = (k > groupRangeLocal) ? k - groupRangeLocal : 0;
                        maxOff = std::min((size_t)(readSize), (size_t)(k + groupRangeLocal + 1));
                      } else {
                        
                        minOff = lastMatchOffset + 1;
                        maxOff = std::min((size_t)(readSize), (size_t)(lastMatchOffset + groupRangeLocal + 1));
                      }
                      
                      for (size_t off = minOff; off < maxOff; ++off) {
                        
                        if (groupAnchorModeLocal && off == anchorOffset)
                          continue;
                        if (off + nextSz > readSize)
                          continue;
                        void *nPtr = memBuffer + off;
                        if (matchGroupItemValue(nPtr, nextItem, floatTolerance)) {
                          foundNext = true;
                          matchedItems.push_back({curr + off, g});
                          lastMatchOffset = off;  
                          break;
                        }
                      }
                      if (!foundNext) {
                        allMatched = false;
                        break;
                      }
                    }

                    if (allMatched) {
                      
                      std::sort(matchedItems.begin(), matchedItems.end(),
                                [](const std::pair<uint64_t, size_t> &a,
                                   const std::pair<uint64_t, size_t> &b) {
                                  return a.first < b.first;
                                });
                      
                      for (const auto &matchedItem : matchedItems) {
                        uint64_t addr = matchedItem.first;
                        size_t itemIndex = matchedItem.second;
                        size_t valueSize = getSizeForType(gItemsCopy[itemIndex].type);
                        RawResult res;
                        res.address = addr;
                        res.value = 0;
                        memcpy(&res.value, memBuffer + (addr - curr),
                               std::min((size_t)8, valueSize));
                        res.type = (uint8_t)gItemsCopy[itemIndex].type;
                        res.padding1 = 0;
                        res.padding2 = 0;
                        memset(res.padding, 0, sizeof(res.padding));
                        localResults.push_back(res);
                      }
                    }
                  }
                } else if (searchModeLocal == 3) { 
                  if (isFloatTypeLocal) {
                    double v = isFloat ? (double)(*(float *)ptr)
                                       : *(double *)ptr;
                    double minV = isFloat ? (double)minFloat : minDouble;
                    double maxV = isFloat ? (double)maxFloat : maxDouble;
                    match = (v >= minV && v <= maxV);
                    valBits = isFloat ? *(uint32_t *)ptr
                                      : *(uint64_t *)ptr;
                  } else {
                    uint64_t v = 0;
                    memcpy(&v, ptr, dataSizeLocal > 8 ? 8 : dataSizeLocal);
                    uint64_t stripped = v & 0xFFFFFFFFFFFF;
                    if (dataTypeInt == (int)DataType::Int64) {
                      match = (v >= (uint64_t)minInt64 &&
                               v <= (uint64_t)maxInt64) ||
                              (stripped >= (uint64_t)minInt64 &&
                               stripped <= (uint64_t)maxInt64);
                    } else {
                      match = (v >= minUInt64 && v <= maxUInt64);
                    }
                    valBits = v;
                  }
                } else { 
                  
                  if (isStringType) {
                    if (targetStringLen > 0 && k + targetStringLen <= readSize) {
                      if (memcmp(ptr, targetString.c_str(), targetStringLen) == 0) {
                        match = true;
                        valBits = 0; 
                      }
                    }
                  } else if (isFloatTypeLocal) {
                    double v = isFloat ? (double)(*(float *)ptr)
                                       : *(double *)ptr;
                    double tgtVal = isFloat ? (double)targetFloat : targetDouble;
                    match = (std::abs(v - tgtVal) <= floatTolerance);
                    valBits = isFloat ? *(uint32_t *)ptr
                                      : *(uint64_t *)ptr;
                  } else {
                    uint64_t v = 0;
                    memcpy(&v, ptr, dataSizeLocal > 8 ? 8 : dataSizeLocal);
                    uint64_t stripped = v & 0xFFFFFFFFFFFF;
                    if (dataTypeInt == (int)DataType::Int64) {
                      match = (v == (uint64_t)targetInt64 ||
                               stripped == (uint64_t)targetInt64);
                    } else {
                      match = (v == targetUInt64);
                    }
                    valBits = v;
                  }
                }

                if (match) {
                  localResults.push_back(makeRawResult(curr + k, valBits, dType));
                }
              }
            }
            curr += chunkSize;
          }
          free(memBuffer);
        });

    if (sMode == 2 && !gItems.empty()) {
      
      std::vector<RawResult> allResults;
      for (size_t i = 0; i < perRegionResults.size(); ++i) {
        allResults.insert(allResults.end(), 
                         perRegionResults[i].begin(), 
                         perRegionResults[i].end());
      }
      
      size_t groupSize = gItems.size();
      if (groupUsesLayoutMode(gItems)) {
        std::sort(allResults.begin(), allResults.end(),
                  [](const RawResult &a, const RawResult &b) {
                    return a.address < b.address;
                  });
      } else if (groupSize > 0 && allResults.size() >= groupSize) {
        
        std::vector<std::vector<RawResult>> groups;
        for (size_t i = 0; i + groupSize <= allResults.size(); i += groupSize) {
          std::vector<RawResult> group(allResults.begin() + i, 
                                       allResults.begin() + i + groupSize);
          groups.push_back(group);
        }
        
        std::sort(groups.begin(), groups.end(),
                  [](const std::vector<RawResult> &a, const std::vector<RawResult> &b) {
                    return a[0].address < b[0].address;
                  });
        
        allResults.clear();
        for (const auto &group : groups) {
          allResults.insert(allResults.end(), group.begin(), group.end());
        }
      }
      
      if (!allResults.empty()) {
        fwrite(allResults.data(), sizeof(RawResult), allResults.size(), outFile);
        _resultCount = allResults.size();
      }
    } else {
      for (size_t i = 0; i < perRegionResults.size(); ++i) {
        if (!perRegionResults[i].empty()) {
          fwrite(perRegionResults[i].data(), sizeof(RawResult),
                 perRegionResults[i].size(), outFile);
          _resultCount += perRegionResults[i].size();
        }
      }
    }
  }

  fclose(outFile);
  return getResults(0, 100);
}

std::vector<ScanResult>
MemoryCore::nextScan(const std::vector<ScanResult> &ignored, DataType type,
                     const std::string &valueStr, int searchMode) {
  std::vector<ScanResult> emptyRes;
  
  if (_task == MACH_PORT_NULL)
    return emptyRes;
  
  if (_resultCount == 0 || _storagePath.empty() || _swapPath.empty())
    return emptyRes;

  FILE *inFileVerify = fopen(_storagePath.c_str(), "rb");
  if (!inFileVerify)
    return emptyRes;
  fclose(inFileVerify);

  size_t totalResults = _resultCount;
  FILE *outFile = fopen(_swapPath.c_str(), "wb");
  if (!outFile)
    return emptyRes;

  bool useIncrementalOptimization = false;
  std::vector<DiffRegion> diffRegions;
  
  if (hasBaselineSnapshot() && (searchMode == 0 || searchMode == 1 || searchMode == 5)) {
    
    diffRegions = compareWithBaseline(8);
    if (!diffRegions.empty()) {
      useIncrementalOptimization = true;
    }
  }

  union {
    int8_t i8;
    int16_t i16;
    int32_t i32;
    int64_t i64;
    float f;
    double d;
  } target;
  memset(&target, 0, sizeof(target));
  
  parseValue(valueStr, type, &target);
  
  // Parse range for between mode (101)
  union {
    int8_t i8; int16_t i16; int32_t i32; int64_t i64;
    float f; double d;
  } rangeMin, rangeMax;
  memset(&rangeMin, 0, sizeof(rangeMin));
  memset(&rangeMax, 0, sizeof(rangeMax));
  if (searchMode == 101) {
    parseRangeString(valueStr, type, &rangeMin, &rangeMax);
  }
  
  bool isStringType = (type == DataType::String);
  std::string targetString = valueStr;
  size_t targetStringLen = targetString.length();

  std::atomic<size_t> newCount(0);
  mach_port_t task = _task;
  
  float targetFloat = target.f;
  double targetDouble = target.d;
  
  int8_t targetI8 = target.i8;
  int16_t targetI16 = target.i16;
  int32_t targetI32 = target.i32;
  int64_t targetI64 = target.i64;
  double floatTolerance = _floatTolerance;
  
  std::vector<DiffRegion> diffRegionsCopy = diffRegions;
  bool useIncremental = useIncrementalOptimization;
  
  // Range variables for between mode (101)
  float rangeMinFloat = rangeMin.f, rangeMaxFloat = rangeMax.f;
  double rangeMinDouble = rangeMin.d, rangeMaxDouble = rangeMax.d;
  int64_t rangeMinI64 = rangeMin.i64, rangeMaxI64 = rangeMax.i64;
  
  DataType requestedType = type;  

  const size_t chunkSizeInResults = 500000;
  size_t processed = 0;

  while (processed < totalResults) {
    size_t currentBatchSize =
        std::min(chunkSizeInResults, totalResults - processed);
    std::vector<RawResult> batch(currentBatchSize);

    FILE *batchFile = fopen(_storagePath.c_str(), "rb");
    if (!batchFile)
      break;
    fseek(batchFile, processed * sizeof(RawResult), SEEK_SET);
    fread(batch.data(), sizeof(RawResult), currentBatchSize, batchFile);
    fclose(batchFile);

    const RawResult *batchPtr = batch.data();

    size_t numInnerBatches = currentBatchSize / 1000 + 1;
    std::vector<std::vector<RawResult>> perBatchResults(numInnerBatches);
    std::vector<RawResult> *perBatchResultsPtr = perBatchResults.data();

    dispatch_apply(
        numInnerBatches,
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
        ^(size_t innerIdx) {
          size_t startIdx = innerIdx * 1000;
          size_t endIdx = std::min(startIdx + 1000, currentBatchSize);
          if (startIdx >= endIdx)
            return;

          std::vector<RawResult> &localBuffer = perBatchResultsPtr[innerIdx];
          localBuffer.reserve(1000);
          uint64_t cachedPage = (uint64_t)-1;
          uint8_t pageBuffer[4096];
          
          uint8_t stringBuffer[64];

          for (size_t i = startIdx; i < endIdx; ++i) {
            const RawResult &raw = batchPtr[i];
            
            if (useIncremental) {
              bool inChangedRegion = false;
              for (const auto &diff : diffRegionsCopy) {
                if (raw.address >= diff.address && 
                    raw.address < diff.address + diff.size) {
                  inChangedRegion = true;
                  break;
                }
              }
              if (!inChangedRegion) {
                
                continue;
              }
            }
            
            uint8_t buf[8];
            
            if (isStringType) {
              mach_vm_size_t rSz = 64;
              if (mach_vm_read_overwrite(task, raw.address, 64,
                                         (mach_vm_address_t)stringBuffer,
                                         &rSz) == KERN_SUCCESS) {
                bool match = false;
                if (targetStringLen > 0) {
                  
                  char *strPtr = (char *)stringBuffer;
                  size_t maxLen = rSz;
                  
                  size_t actualLen = 0;
                  while (actualLen < maxLen && strPtr[actualLen] != '\0') actualLen++;
                  if (actualLen == 0) actualLen = maxLen;
                  
                  if (actualLen >= targetStringLen) {
                    for (size_t j = 0; j <= actualLen - targetStringLen; ++j) {
                      if (memcmp(strPtr + j, targetString.c_str(), targetStringLen) == 0) {
                        match = true;
                        break;
                      }
                    }
                  }
                } else {
                  
                  match = true;
                }
                
                if (match) {
                  RawResult resSub;
                  resSub.address = raw.address;
                  resSub.value = 0;
                  resSub.type = raw.type;  
                  memset(resSub.padding, 0, sizeof(resSub.padding));
                  localBuffer.push_back(resSub);
                }
              }
              continue; 
            }

            uint64_t pageAddr = raw.address & ~0xFFF;
            if (pageAddr != cachedPage) {
              cachedPage = pageAddr;
              mach_vm_size_t readSz = 4096;
              if (mach_vm_read_overwrite(task, pageAddr, 4096,
                                         (mach_vm_address_t)pageBuffer,
                                         &readSz) != KERN_SUCCESS) {
                cachedPage = (uint64_t)-1;
              }
            }

            DataType storedType = (DataType)raw.type;
            DataType actualType = storedType;
            size_t actualSize = getSizeForType(actualType);
            
            if (storedType != requestedType) {
              continue;
            }

            bool readSuccess = false;
            if (cachedPage != (uint64_t)-1) {
              size_t offset = raw.address - cachedPage;
              if (offset + actualSize <= 4096) {
                memcpy(buf, pageBuffer + offset, actualSize);
                readSuccess = true;
              }
            }

            if (!readSuccess) {
              mach_vm_size_t rSz = actualSize;
              if (mach_vm_read_overwrite(task, raw.address, actualSize,
                                         (mach_vm_address_t)buf,
                                         &rSz) == KERN_SUCCESS) {
                readSuccess = true;
              }
            }

            if (readSuccess) {
              bool match = false;
              
              if (actualType == DataType::Float) {
                float oldVal = 0, newVal = 0;
                memcpy(&oldVal, &raw.value, 4);
                memcpy(&newVal, buf, 4);
                
                if (searchMode == 0)
                  match = (newVal < oldVal - (float)floatTolerance);
                else if (searchMode == 1)
                  match = (newVal > oldVal + (float)floatTolerance);
                else if (searchMode == 5)  
                  match = (fabs(newVal - oldVal) >= (float)floatTolerance);
                else if (searchMode == 6)  
                  match = (fabs(newVal - oldVal) <= (float)floatTolerance);
                else if (searchMode == 101)
                  match = ((double)newVal >= (double)rangeMinFloat && (double)newVal <= (double)rangeMaxFloat);
                else
                  match = (fabs(newVal - targetFloat) <= (float)floatTolerance);
              } else if (actualType == DataType::Double) {
                double oldVal = 0, newVal = 0;
                memcpy(&oldVal, &raw.value, 8);
                memcpy(&newVal, buf, 8);
                
                if (searchMode == 0)
                  match = (newVal < oldVal - floatTolerance);
                else if (searchMode == 1)
                  match = (newVal > oldVal + floatTolerance);
                else if (searchMode == 5)  
                  match = (fabs(newVal - oldVal) >= floatTolerance);
                else if (searchMode == 6)  
                  match = (fabs(newVal - oldVal) <= floatTolerance);
                else if (searchMode == 101)
                  match = (newVal >= rangeMinDouble && newVal <= rangeMaxDouble);
                else
                  match = (fabs(newVal - targetDouble) <= floatTolerance);
              } else {
                int64_t oldV = 0, newV = 0, targetV = 0;
                
                switch (actualSize) {
                case 1:
                  oldV = (int8_t)raw.value;
                  newV = *(int8_t *)buf;
                  targetV = targetI8;
                  break;
                case 2:
                  oldV = (int16_t)raw.value;
                  newV = *(int16_t *)buf;
                  targetV = targetI16;
                  break;
                case 8:
                  oldV = (int64_t)raw.value;
                  newV = *(int64_t *)buf;
                  targetV = targetI64;
                  break;
                default:
                  oldV = (int64_t)*(int32_t *)&raw.value;
                  newV = (int64_t)*(int32_t *)buf;
                  targetV = targetI32;
                  break;
                }
                if (searchMode == 0)
                  match = (newV < oldV);
                else if (searchMode == 1)
                  match = (newV > oldV);
                else if (searchMode == 3)
                  match = (newV == oldV + targetV);
                else if (searchMode == 4)
                  match = (newV == oldV - targetV);
                else if (searchMode == 5)
                  match = (newV != oldV);
                else if (searchMode == 6)
                  match = (newV == oldV);
                else if (searchMode == 101)
                  match = (newV >= rangeMinI64 && newV <= rangeMaxI64);
                else {
                  match = (newV == targetV);
                  
                  if (!match && actualType == DataType::Int64) {
                    match =
                        ((newV & 0xFFFFFFFFFFFF) == (targetV & 0xFFFFFFFFFFFF));
                  }
                }
              }
              if (match) {
                RawResult resSub;
                resSub.address = raw.address;
                memcpy(&resSub.value, buf, 8);
                resSub.type = raw.type;  
                memset(resSub.padding, 0, sizeof(resSub.padding));
                localBuffer.push_back(resSub);
              }
            }
          }
        });

    for (size_t b = 0; b < numInnerBatches; ++b) {
      auto &localBuffer = perBatchResults[b];
      if (!localBuffer.empty()) {
        fwrite(localBuffer.data(), sizeof(RawResult), localBuffer.size(),
               outFile);
        newCount += localBuffer.size();
      }
    }

    processed += currentBatchSize;
  }

  fclose(outFile);

  if (newCount == 0) {
    _resultCount = 0;
    remove(_swapPath.c_str());
    return emptyRes;
  }

  {
    FILE *readFile = fopen(_swapPath.c_str(), "rb");
    if (readFile) {
      std::vector<RawResult> allResults(newCount);
      size_t actualRead = fread(allResults.data(), sizeof(RawResult), newCount, readFile);
      fclose(readFile);
      
      if (actualRead == newCount && newCount > 1) {
        
        std::unordered_set<uint64_t> seenAddresses;
        std::vector<RawResult> uniqueResults;
        uniqueResults.reserve(newCount);
        
        for (const auto &res : allResults) {
          if (seenAddresses.find(res.address) == seenAddresses.end()) {
            seenAddresses.insert(res.address);
            uniqueResults.push_back(res);
          }
        }
        
        if (uniqueResults.size() < newCount) {
          FILE *writeFile = fopen(_swapPath.c_str(), "wb");
          if (writeFile) {
            fwrite(uniqueResults.data(), sizeof(RawResult), uniqueResults.size(), writeFile);
            fclose(writeFile);
            newCount = uniqueResults.size();
          }
        }
      }
    }
  }

  _resultCount = (size_t)newCount;
  remove(_storagePath.c_str());
  rename(_swapPath.c_str(), _storagePath.c_str());
  
  return getResults(0, 100);
}

std::vector<ScanResult> MemoryCore::getResults(size_t start, size_t count) {
  std::vector<ScanResult> results;
  if (_storagePath.empty())
    return results;
  FILE *f = fopen(_storagePath.c_str(), "rb");
  if (!f)
    return results;
  if (fseek(f, start * sizeof(RawResult), SEEK_SET) == 0) {
    RawResult raw;
    size_t read = 0;
    while (read < count && fread(&raw, sizeof(RawResult), 1, f) == 1) {
      ScanResult res;
      res.address = raw.address;
      res.value.u64 = raw.value;
      res.type = (DataType)raw.type;
      results.push_back(res);
      read++;
    }
  }
  fclose(f);
  return results;
}

void MemoryCore::setStoragePath(const std::string &path,
                                const std::string &swapPath) {
  _storagePath = path;
  _swapPath = swapPath;
  _fastFuzzySnapshotPath = path + ".fuzzy";
}

bool MemoryCore::restoreResultsFromFile(const std::string &filePath,
                                        size_t resultCount) {
  if (_storagePath.empty())
    return false;

  std::remove(_storagePath.c_str());
  if (filePath.empty() || resultCount == 0) {
    _resultCount = 0;
    return true;
  }

  if (std::rename(filePath.c_str(), _storagePath.c_str()) != 0)
    return false;

  _resultCount = resultCount;
  return true;
}

std::vector<ScanResult>
MemoryCore::scanNearby(const std::vector<ScanResult> &baseResults,
                       DataType type, const std::string &valueStr,
                       uint64_t range) {
  std::vector<ScanResult> results;
  if (_task == MACH_PORT_NULL)
    return results;

  std::unordered_set<uint64_t> seenAddresses;

  size_t dataSize = getSizeForType(type);
  union {
    int8_t i8;
    int16_t i16;
    int32_t i32;
    int64_t i64;
    float f;
    double d;
  } target;
  memset(&target, 0, sizeof(target));
  parseValue(valueStr, type, &target);

  auto scanRange = [&](uint64_t start, uint64_t len) {
    if (len > 65536)
      len = 65536; 
    if (len < dataSize)
      return true; 
    std::vector<uint8_t> buf(len);
    if (readMemory(start, buf.data(), len)) {
      size_t maxOffset = len - dataSize;
      for (size_t i = 0; i <= maxOffset; i++) {
        bool match = false;
        void *ptr = buf.data() + i;
        if (type == DataType::Float) {
          match = (fabs(*(float *)ptr - target.f) <= (float)_floatTolerance);
        } else if (type == DataType::Double) {
          match = (fabs(*(double *)ptr - target.d) <= _floatTolerance);
        } else {
          
          if (dataSize == 4)
            match = (*(int32_t *)ptr == target.i32);
          else if (dataSize == 8)
            match = (*(int64_t *)ptr == target.i64);
          else if (dataSize == 2)
            match = (*(int16_t *)ptr == target.i16);
          else if (dataSize == 1)
            match = (*(int8_t *)ptr == target.i8);
        }

        if (match) {
          uint64_t addr = start + i;
          
          if (seenAddresses.find(addr) != seenAddresses.end()) {
            continue;
          }
          seenAddresses.insert(addr);

          ScanResult res;
          res.address = addr;
          res.type = type;
          memcpy(&res.value.u64, ptr, dataSize);
          results.push_back(res);
          if (_resultLimit > 0 && results.size() >= _resultLimit)
            return false;
        }
      }
    }
    return true;
  };

  if (!baseResults.empty()) {
    for (const auto &base : baseResults) {
      uint64_t start = (base.address > range) ? (base.address - range) : 0;
      if (!scanRange(start, range * 2))
        break;
    }
  }
  
  else if (!_storagePath.empty() && _resultCount > 0) {
    FILE *f = fopen(_storagePath.c_str(), "rb");
    if (f) {
      RawResult raw;
      while (fread(&raw, sizeof(RawResult), 1, f) == 1) {
        uint64_t start = (raw.address > range) ? (raw.address - range) : 0;
        if (!scanRange(start, range * 2))
          break;
      }
      fclose(f);
    }
  }

  if (!_swapPath.empty()) {
    if (results.empty()) {
      
      std::remove(_storagePath.c_str());
      _resultCount = 0;
    } else {
      FILE *fOut = fopen(_swapPath.c_str(), "wb");
      if (fOut) {
        for (const auto &res : results) {
          RawResult raw;
          raw.address = res.address;
          raw.value = res.value.u64;
          fwrite(&raw, sizeof(RawResult), 1, fOut);
        }
        fclose(fOut);
        std::remove(_storagePath.c_str());
        std::rename(_swapPath.c_str(), _storagePath.c_str());
        _resultCount = results.size();
      }
    }
  }
  
  std::sort(results.begin(), results.end(),
            [](const ScanResult &a, const ScanResult &b) {
              return a.address < b.address;
            });

  return results;
}

void MemoryCore::runSecurityChecks() {
  ptrace(31, 0, 0, 0);
  int mib[4];
  struct kinfo_proc info;
  size_t size = sizeof(info);
  mib[0] = CTL_KERN;
  mib[1] = KERN_PROC;
  mib[2] = KERN_PROC_PID;
  mib[3] = getpid();
  if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
    if ((info.kp_proc.p_flag & P_TRACED) != 0)
      exit(1);
  }
}

std::vector<PointerResult>
MemoryCore::scanPointers(const std::vector<uint64_t> &targets, uint64_t start,
                         uint64_t end, uint32_t maxOffset, size_t limit) {
  
  if (_snapshot.empty()) {
    return {};
  }

  std::atomic<size_t> totalMatches{0};
  std::atomic<size_t> *atomPtr = &totalMatches;

  size_t bufferCap = limit + 10000;

  std::vector<PointerResult> rawBuffer(bufferCap);
  PointerResult *rawBufferPtr = rawBuffer.data();

  const uint64_t *sortedTargets = targets.data();
  size_t targetCount = targets.size();
  
  uint64_t minTarget = targets.empty() ? 0 : targets.front();
  uint64_t maxTarget = targets.empty() ? 0 : targets.back();

  dispatch_apply(
      _snapshot.size(),
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t i) {
        const auto &region = _snapshot[i];

        uint64_t rStart = region.start;
        uint64_t rEnd = rStart + region.size;

        uint64_t effectiveStart = std::max(rStart, start);
        uint64_t effectiveEnd = (end > 0) ? std::min(rEnd, end) : rEnd;

        if (effectiveStart >= effectiveEnd)
          return;

        const uint64_t *ptrData = (const uint64_t *)region.data.data();
        size_t startIdx = (effectiveStart - rStart) / 8;
        size_t endIdx = (effectiveEnd - rStart) / 8;

        for (size_t k = startIdx; k < endIdx; ++k) {
          uint64_t val = ptrData[k];
          
          uint64_t stripped = val & 0xFFFFFFFFFFFF;
          
          if (stripped < 0x100000000 || stripped > 0x800000000000ULL)
            continue;
          
          if ((stripped & 0x1) != 0)
            continue;
          
          uint64_t searchMin = (minTarget > maxOffset) ? (minTarget - maxOffset) : 0;
          uint64_t searchMax = maxTarget + maxOffset;
          if (stripped < searchMin || stripped > searchMax)
            continue;

          uint64_t lowerBound = (stripped > maxOffset) ? (stripped - maxOffset) : 0;
          auto it = std::lower_bound(sortedTargets, sortedTargets + targetCount, lowerBound);
          
          bool matched = false;
          int64_t signedOffset = 0;
          
          while (it != (sortedTargets + targetCount)) {
            uint64_t target = *it;
            
            if (target > stripped + maxOffset)
              break;
            
            signedOffset = (int64_t)target - (int64_t)stripped;
            
            if (signedOffset >= -(int64_t)maxOffset && signedOffset <= (int64_t)maxOffset) {
              matched = true;
              break;
            }
            ++it;
          }
          
          if (matched) {
            
            size_t idx = atomPtr->fetch_add(1, std::memory_order_relaxed);

            uint64_t ptrAddr = rStart + (k * 8);
            if (idx < bufferCap) {
              rawBufferPtr[idx] = {ptrAddr, stripped, signedOffset};  
            } else {
              if (idx > bufferCap + 10000)
                return;
            }
          }
        }
      });

  size_t foundCount = totalMatches.load(std::memory_order_relaxed);
  size_t validCount = (foundCount > bufferCap) ? bufferCap : foundCount;
  rawBuffer.resize(validCount);

  return rawBuffer;
}

SignatureData MemoryCore::parseSignature(const std::string &sig) {
  SignatureData data;
  data.length = 0;
  data.firstValidIndex = -1;
  data.firstValidByte = 0;

  std::string clean = "";
  for (char c : sig)
    if (c != ' ')
      clean += toupper(c);

  if (clean.empty() || clean.length() % 2 != 0)
    return data;

  size_t len = clean.length() / 2;
  data.bytes.resize(len);
  data.mask.resize(len);
  data.length = len;

  for (size_t i = 0; i < len; i++) {
    std::string byteStr = clean.substr(i * 2, 2);

    if (byteStr == "??" || byteStr == "**" || byteStr == "--") {
      data.mask[i] = false;
      data.bytes[i] = 0;
    } else {
      data.mask[i] = true;
      data.bytes[i] = (uint8_t)strtoull(byteStr.c_str(), NULL, 16);

      if (data.firstValidIndex == -1) {
        data.firstValidIndex = (int)i;
        data.firstValidByte = data.bytes[i];
      }
    }
  }
  return data;
}

std::vector<ScanResult> MemoryCore::scanSignature(const std::string &sig,
                                                  uint64_t start,
                                                  uint64_t end) {
  std::vector<ScanResult> results;
  if (_task == MACH_PORT_NULL)
    return results;

  SignatureData sData = parseSignature(sig);
  if (sData.length == 0)
    return results;

  mach_vm_address_t address = (start > 0) ? start : 0x100000000;
  mach_vm_address_t endLimit = (end > 0) ? end : 0x400000000ULL;

  struct MemRegion {
    uint64_t start;
    uint64_t size;
  };
  std::vector<MemRegion> regions;

  mach_vm_size_t size = 0;
  vm_region_basic_info_data_64_t info;
  mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object_name;

  while (address < endLimit) {
    kern_return_t kr =
        mach_vm_region(_task, &address, &size, VM_REGION_BASIC_INFO_64,
                       (vm_region_info_t)&info, &infoCount, &object_name);
    if (kr != KERN_SUCCESS)
      break;

    if ((info.protection & VM_PROT_READ) && size > 0 &&
        size <= 128 * 1024 * 1024) {
      regions.push_back({address, size});
    }
    address += size;
  }

  if (regions.empty()) {
    return results;
  }

  std::vector<uint8_t> fastMask(sData.length);
  for (size_t i = 0; i < sData.length; i++)
    fastMask[i] = sData.mask[i] ? 1 : 0;

  int anchorIndex = sData.firstValidIndex;
  uint8_t anchorByte = sData.firstValidByte;
  bool useFastPath = (anchorIndex != -1);

  const uint8_t *sigBytes = sData.bytes.data();
  const uint8_t *maskPtr = fastMask.data();
  size_t sigLen = sData.length;
  mach_port_t task = _task;

  std::vector<std::vector<ScanResult>> perRegionResults(regions.size());
  std::atomic<size_t> globalCount{0};
  const size_t kMaxResults = 200;

  std::vector<std::vector<ScanResult>> *resultsPtr = &perRegionResults;
  std::atomic<size_t> *countPtr = &globalCount;
  const std::vector<MemRegion> *regionsPtr = &regions;

  dispatch_apply(
      regions.size(),
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
      ^(size_t idx) {
        
        if (countPtr->load(std::memory_order_relaxed) >= kMaxResults)
          return;

        const MemRegion &reg = (*regionsPtr)[idx];

        if (reg.size < sigLen)
          return;

        uint8_t *buffer = (uint8_t *)malloc(reg.size);
        if (!buffer)
          return;

        mach_vm_size_t readSz = reg.size;
        if (mach_vm_read_overwrite(task, reg.start, reg.size,
                                   (mach_vm_address_t)buffer,
                                   &readSz) != KERN_SUCCESS) {
          free(buffer);
          return;
        }

        if (readSz < sigLen) {
          free(buffer);
          return;
        }

        std::vector<ScanResult> localResults;
        localResults.reserve(64); 

        size_t scanLimit = readSz - sigLen + 1;
        size_t i = 0;

        while (i < scanLimit) {
          
          if (localResults.size() >= 50)
            break;

          if (useFastPath) {
            
            void *found = memchr(buffer + i + anchorIndex, anchorByte,
                                 readSz - (i + anchorIndex));
            if (!found)
              break; 

            size_t foundPos = (uint8_t *)found - buffer;

            if (foundPos < (size_t)anchorIndex) {
              i++;
              continue;
            }

            size_t potentialStart = foundPos - anchorIndex;

            if (potentialStart < i) {
              i = foundPos + 1;
              continue;
            }

            if (potentialStart >= scanLimit)
              break;

            bool match = true;
            for (size_t k = 0; k < sigLen; k++) {
              if (maskPtr[k] && buffer[potentialStart + k] != sigBytes[k]) {
                match = false;
                break;
              }
            }

            if (match) {
              ScanResult res;
              res.address = reg.start + potentialStart;
              res.type = DataType::Int8;
              localResults.push_back(res);
            }

            i = potentialStart + 1;

          } else {
            
            ScanResult res;
            res.address = reg.start + i;
            res.type = DataType::Int8;
            localResults.push_back(res);
            i++;
          }
        }

        free(buffer);

        if (!localResults.empty()) {
          size_t count = localResults.size();
          (*resultsPtr)[idx] = std::move(localResults);
          countPtr->fetch_add(count, std::memory_order_relaxed);
        }
      });

  for (auto &localRes : perRegionResults) {
    for (auto &res : localRes) {
      if (results.size() >= kMaxResults)
        break;
      results.push_back(res);
    }
    if (results.size() >= kMaxResults)
      break;
  }

  std::sort(results.begin(), results.end(),
            [](const ScanResult &a, const ScanResult &b) {
              return a.address < b.address;
            });

  return results;
}

size_t MemoryCore::filterResults(FilterMode mode, DataType type,
                                 const std::string &v1, const std::string &v2) {
  if (_storagePath.empty() || _swapPath.empty() || _resultCount == 0)
    return 0;
  FILE *fSrc = fopen(_storagePath.c_str(), "rb");
  FILE *fDst = fopen(_swapPath.c_str(), "wb");
  if (!fSrc || !fDst) {
    if (fSrc)
      fclose(fSrc);
    if (fDst)
      fclose(fDst);
    return 0;
  }
  double t1 = 0, t2 = 0;
  try {
    t1 = std::stod(v1);
    t2 = std::stod(v2);
  } catch (...) {
  }
  RawResult item;
  size_t newCount = 0;
  size_t dataSize = getSizeForType(type);

  uint64_t cachedPage = (uint64_t)-1;
  uint8_t pageBuffer[4096];

  while (fread(&item, sizeof(RawResult), 1, fSrc) == 1) {
    uint8_t buf[8];
    memset(buf, 0, 8);

    uint64_t pageAddr = item.address & ~0xFFF; 
    if (pageAddr != cachedPage) {
      cachedPage = pageAddr;
      mach_vm_size_t readSz = 4096;
      if (mach_vm_read_overwrite(_task, pageAddr, 4096,
                                 (mach_vm_address_t)pageBuffer,
                                 &readSz) != KERN_SUCCESS) {
        cachedPage = (uint64_t)-1; 
      }
    }

    bool readSuccess = false;
    if (cachedPage != (uint64_t)-1) {
      
      size_t offset = item.address - cachedPage;
      if (offset + dataSize <= 4096) {
        memcpy(buf, pageBuffer + offset, dataSize);
        readSuccess = true;
      }
    }

    if (!readSuccess) {
      mach_vm_size_t rSz = dataSize;
      if (mach_vm_read_overwrite(_task, item.address, dataSize,
                                 (mach_vm_address_t)buf,
                                 &rSz) == KERN_SUCCESS) {
        readSuccess = true;
      }
    }

    if (readSuccess) {
      double currentVal = 0;
      if (type == DataType::Float)
        currentVal = *(float *)buf;
      else if (type == DataType::Double)
        currentVal = *(double *)buf;
      else if (dataSize == 1)
        currentVal = *(int8_t *)buf;
      else if (dataSize == 2)
        currentVal = *(int16_t *)buf;
      else if (dataSize == 8)
        currentVal = *(int64_t *)buf;
      else
        currentVal = *(int32_t *)buf;
      bool keep = false;
      if (mode == FilterMode::Less)
        keep = (currentVal < t1);
      else if (mode == FilterMode::Greater)
        keep = (currentVal > t1);
      else if (mode == FilterMode::Between)
        keep = (currentVal >= t1 && currentVal <= t2);
      if (keep) {
        fwrite(&item, sizeof(RawResult), 1, fDst);
        newCount++;
      }
    }
  }
  fclose(fSrc);
  fclose(fDst);
  std::remove(_storagePath.c_str());
  std::rename(_swapPath.c_str(), _storagePath.c_str());
  _resultCount = newCount;
  return newCount;
}

bool MemoryCore::removeResult(size_t index) {
  if (index >= _resultCount || _storagePath.empty())
    return false;
  FILE *f = fopen(_storagePath.c_str(), "rb");
  if (!f)
    return false;
  fseek(f, 0, SEEK_END);
  long fileSize = ftell(f);
  size_t totalItems = fileSize / sizeof(RawResult);
  if (index >= totalItems) {
    fclose(f);
    return false;
  }
  size_t beforeSize = index * sizeof(RawResult);
  size_t afterSize = (totalItems - index - 1) * sizeof(RawResult);
  std::string tempPath = _storagePath + ".tmp";
  FILE *fTmp = fopen(tempPath.c_str(), "wb");
  if (!fTmp) {
    fclose(f);
    return false;
  }
  fseek(f, 0, SEEK_SET);
  if (beforeSize > 0) {
    void *buf = malloc(beforeSize);
    fread(buf, beforeSize, 1, f);
    fwrite(buf, beforeSize, 1, fTmp);
    free(buf);
  }
  fseek(f, sizeof(RawResult), SEEK_CUR);
  if (afterSize > 0) {
    void *buf = malloc(afterSize);
    fread(buf, afterSize, 1, f);
    fwrite(buf, afterSize, 1, fTmp);
    free(buf);
  }
  fclose(f);
  fclose(fTmp);
  std::remove(_storagePath.c_str());
  std::rename(tempPath.c_str(), _storagePath.c_str());
  _resultCount--;
  return true;
}

void MemoryCore::batchModify(const std::string &input, int limit, DataType type,
                             int mode) {
  if (_storagePath.empty() || _resultCount == 0)
    return;
  FILE *f = fopen(_storagePath.c_str(), "rb");
  if (!f)
    return;
  double inputD = std::stod(input);
  long long inputI = std::stoll(input);
  RawResult raw;
  int processed = 0;
  int maxProcess = (limit > 0) ? limit : 2147483647;
  while (processed < maxProcess && fread(&raw, sizeof(RawResult), 1, f) == 1) {
    double finalD = inputD;
    long long finalI = inputI;
    if (mode == 1) {
      finalD += (double)processed;
      finalI += (long long)processed;
    }
    size_t sz = getSizeForType(type);
    uint8_t buf[8];
    if (type == DataType::Float) {
      float v = (float)finalD;
      memcpy(buf, &v, 4);
    } else if (type == DataType::Double)
      memcpy(buf, &finalD, 8);
    else if (sz == 1) {
      int8_t v = (int8_t)finalI;
      memcpy(buf, &v, 1);
    } else if (sz == 2) {
      int16_t v = (int16_t)finalI;
      memcpy(buf, &v, 2);
    } else if (sz == 8)
      memcpy(buf, &finalI, 8);
    else {
      int32_t v = (int32_t)finalI;
      memcpy(buf, &v, 4);
    }
    writeMemory(raw.address, buf, sz);
    processed++;
  }
  fclose(f);
}

std::vector<std::vector<uint64_t>>
MemoryCore::autoSearchChain(uint64_t target, uint64_t hStart, uint64_t hEnd,
                            uint64_t bStart, uint64_t bEnd, int maxL,
                            size_t maxPL, uint32_t maxO,
                            ProgressCallback progress, void *userData,
                            IsBaseAddressCallback isBaseCallback) {
  std::vector<std::vector<uint64_t>> paths;
  if (_task == MACH_PORT_NULL)
    return paths;

  if (_snapshot.empty()) {
    takeSnapshot(1024 * 1024 * 1024, bStart, bEnd);
  }

  struct Lvl {
    std::vector<PointerChainNode> ns;
    std::unordered_set<uint64_t> addrSet;
  };
  std::vector<Lvl> lvls(maxL + 1);
  lvls[0].ns.push_back({target, -1});
  lvls[0].addrSet.insert(target);

  for (int l = 0; l < maxL; l++) {
    if (lvls[l].ns.empty())
      break;
    std::vector<uint64_t> ts;
    ts.reserve(lvls[l].ns.size());
    for (const auto &n : lvls[l].ns)
      ts.push_back(n.address);
    std::sort(ts.begin(), ts.end());
    
    uint64_t sS = hStart;
    uint64_t sE = hEnd;

    auto found = scanPointers(ts, sS, sE, maxO, maxPL + 10000);

    if (progress) {
      SearchProgress sp;
      sp.level = l + 1;
      sp.foundCount = found.size();
      progress(sp, userData);
    }
    
    std::unordered_map<uint64_t, int> parentMap;
    parentMap.reserve(lvls[l].ns.size());
    for (size_t i = 0; i < lvls[l].ns.size(); i++) {
      parentMap[lvls[l].ns[i].address] = (int)i;
    }

    bool isLastLevel = (l == maxL - 1);

    for (const auto &p : found) {
      
      uint64_t targetPtr = (uint64_t)((int64_t)p.value + p.offset);
      auto it = parentMap.find(targetPtr);
      if (it == parentMap.end())
        continue;

      int pIdx = it->second;

      bool isStaticBase = false;
      if (isBaseCallback) {
        if (isBaseCallback(p.address))
          isStaticBase = true;
      }

      bool isValidHeapAddr = (p.address >= hStart && p.address < hEnd);

      if (isStaticBase || (isLastLevel && isValidHeapAddr)) {
        std::vector<uint64_t> path;
        path.reserve(l + 2);
        path.push_back(p.address);
        int curIdx = pIdx;
        for (int k = l; k >= 0; k--) {
          path.push_back(lvls[k].ns[curIdx].address);
          curIdx = lvls[k].ns[curIdx].parentIndex;
        }
        paths.push_back(std::move(path));

        if (paths.size() >= 1000000) {
          goto search_finished;
        }
      } 
      
      if (!isStaticBase && l < maxL - 1) {
        if (lvls[l + 1].addrSet.find(p.address) == lvls[l + 1].addrSet.end()) {
          if (lvls[l + 1].ns.size() < maxPL) {
            lvls[l + 1].ns.push_back({p.address, pIdx});
            lvls[l + 1].addrSet.insert(p.address);
          }
        }
      }
    }
    
    lvls[l].addrSet.clear();
    
    if (lvls[l + 1].ns.empty() && paths.empty())
      break;
  }
search_finished:
  return paths;
}

static uint32_t calculatePointerScore(uint64_t address, uint64_t value, 
                                       int64_t offset, int level,
                                       const std::vector<SnapshotRegion> &snapshot) {
  uint32_t score = 1000;  
  
  uint64_t absOffset = (offset >= 0) ? offset : -offset;
  if (absOffset == 0) {
    score += 500;  
  } else if (absOffset <= 0x10) {
    score += 400;
  } else if (absOffset <= 0x100) {
    score += 300;
  } else if (absOffset <= 0x400) {
    score += 200;
  } else if (absOffset <= 0x1000) {
    score += 100;
  }
  
  if (offset == 0) {
    score += 200;
  } else if ((offset & 0x7) == 0) {
    score += 150;  
  } else if ((offset & 0x3) == 0) {
    score += 100;  
  } else if ((offset & 0x1) == 0) {
    score += 50;   
  }
  
  if ((address & 0x7) == 0) {
    score += 100;  
  }
  
  if (level == 0) {
    score += 300;
  } else if (level == 1) {
    score += 200;
  } else if (level == 2) {
    score += 100;
  }
  
  bool pointsToValidMemory = false;
  for (const auto &region : snapshot) {
    if (value >= region.start && value < region.start + region.size) {
      pointsToValidMemory = true;
      break;
    }
  }
  if (pointsToValidMemory) {
    score += 200;
  }
  
  return score;
}

std::vector<MemoryCore::ScoredPointerResult>
MemoryCore::scanPointersScored(const std::vector<uint64_t> &targets, 
                                uint64_t start, uint64_t end,
                                uint32_t maxOffset, int level, size_t limit) {
  if (_snapshot.empty()) {
    return {};
  }

  std::atomic<size_t> totalMatches{0};
  std::atomic<size_t> *atomPtr = &totalMatches;
  size_t bufferCap = (limit > 0) ? limit + 10000 : 500000;

  std::vector<ScoredPointerResult> rawBuffer(bufferCap);
  ScoredPointerResult *rawBufferPtr = rawBuffer.data();

  const uint64_t *sortedTargets = targets.data();
  size_t targetCount = targets.size();
  
  uint64_t minTarget = targets.empty() ? 0 : targets.front();
  uint64_t maxTarget = targets.empty() ? 0 : targets.back();
  
  const std::vector<SnapshotRegion> *snapshotPtr = &_snapshot;
  int levelCapture = level;

  dispatch_apply(
      _snapshot.size(),
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t i) {
        const auto &region = (*snapshotPtr)[i];

        uint64_t rStart = region.start;
        uint64_t rEnd = rStart + region.size;

        uint64_t effectiveStart = std::max(rStart, start);
        uint64_t effectiveEnd = (end > 0) ? std::min(rEnd, end) : rEnd;

        if (effectiveStart >= effectiveEnd)
          return;

        const uint64_t *ptrData = (const uint64_t *)region.data.data();
        size_t startIdx = (effectiveStart - rStart) / 8;
        size_t endIdx = (effectiveEnd - rStart) / 8;

        for (size_t k = startIdx; k < endIdx; ++k) {
          uint64_t val = ptrData[k];
          uint64_t stripped = val & 0xFFFFFFFFFFFF;
          
          if (stripped < 0x100000000 || stripped > 0x800000000000ULL)
            continue;
          
          if ((stripped & 0x1) != 0)
            continue;
          
          uint64_t searchMin = (minTarget > maxOffset) ? (minTarget - maxOffset) : 0;
          uint64_t searchMax = maxTarget + maxOffset;
          if (stripped < searchMin || stripped > searchMax)
            continue;

          uint64_t lowerBound = (stripped > maxOffset) ? (stripped - maxOffset) : 0;
          auto it = std::lower_bound(sortedTargets, sortedTargets + targetCount, lowerBound);
          
          bool matched = false;
          int64_t signedOffset = 0;
          
          while (it != (sortedTargets + targetCount)) {
            uint64_t target = *it;
            if (target > stripped + maxOffset)
              break;
            
            signedOffset = (int64_t)target - (int64_t)stripped;
            if (signedOffset >= -(int64_t)maxOffset && signedOffset <= (int64_t)maxOffset) {
              matched = true;
              break;
            }
            ++it;
          }
          
          if (matched) {
            uint64_t ptrAddr = rStart + (k * 8);
            uint32_t score = calculatePointerScore(ptrAddr, stripped, signedOffset, 
                                                    levelCapture, *snapshotPtr);
            
            size_t idx = atomPtr->fetch_add(1, std::memory_order_relaxed);
            if (idx < bufferCap) {
              rawBufferPtr[idx] = {ptrAddr, stripped, signedOffset, score};
            }
          }
        }
      });

  size_t foundCount = totalMatches.load(std::memory_order_relaxed);
  size_t validCount = (foundCount > bufferCap) ? bufferCap : foundCount;
  rawBuffer.resize(validCount);
  
  std::sort(rawBuffer.begin(), rawBuffer.end(),
            [](const ScoredPointerResult &a, const ScoredPointerResult &b) {
              return a.score > b.score;
            });

  return rawBuffer;
}

std::vector<MemoryCore::EnhancedChainResult>
MemoryCore::autoSearchChainEnhanced(uint64_t target, uint64_t heapStart, uint64_t heapEnd,
                                     const PointerSearchConfig &config, int maxLevels,
                                     ProgressCallback progress, void *userData,
                                     IsBaseAddressCallback isBaseCallback) {
  std::vector<EnhancedChainResult> results;
  if (_task == MACH_PORT_NULL)
    return results;

  if (_snapshot.empty()) {
    takeSnapshot(1024 * 1024 * 1024, 0, 0);
  }

  struct EnhancedNode {
    uint64_t address;
    int32_t parentIndex;
    int64_t offsetFromParent;  
    uint32_t accumulatedScore; 
  };

  struct Level {
    std::vector<EnhancedNode> nodes;
    std::unordered_set<uint64_t> addrSet;
  };
  
  std::vector<Level> levels(maxLevels + 1);
  levels[0].nodes.push_back({target, -1, 0, 1000});
  levels[0].addrSet.insert(target);

  for (int l = 0; l < maxLevels; l++) {
    if (levels[l].nodes.empty())
      break;
      
    std::vector<uint64_t> targets;
    targets.reserve(levels[l].nodes.size());
    for (const auto &n : levels[l].nodes)
      targets.push_back(n.address);
    std::sort(targets.begin(), targets.end());
    
    uint32_t currentMaxOffset = (l == 0) ? config.firstLevelMaxOffset : config.subsequentMaxOffset;
    
    auto found = scanPointersScored(targets, heapStart, heapEnd, 
                                     currentMaxOffset, l, config.maxResultsPerLevel);

    if (progress) {
      SearchProgress sp;
      sp.level = l + 1;
      sp.foundCount = found.size();
      progress(sp, userData);
    }
    
    std::unordered_map<uint64_t, int> parentMap;
    parentMap.reserve(levels[l].nodes.size());
    for (size_t i = 0; i < levels[l].nodes.size(); i++) {
      parentMap[levels[l].nodes[i].address] = (int)i;
    }

    bool isLastLevel = (l == maxLevels - 1);
    
    for (const auto &p : found) {
      uint64_t targetPtr = (uint64_t)((int64_t)p.value + p.offset);
      auto it = parentMap.find(targetPtr);
      if (it == parentMap.end())
        continue;

      int pIdx = it->second;
      uint32_t parentScore = levels[l].nodes[pIdx].accumulatedScore;
      uint32_t newScore = parentScore + p.score;

      bool isStaticBase = false;
      if (isBaseCallback && isBaseCallback(p.address)) {
        isStaticBase = true;
      }

      if (isStaticBase || isLastLevel) {
        EnhancedChainResult result;
        result.totalScore = newScore;
        result.isStatic = isStaticBase;
        
        result.path.reserve(l + 2);
        result.offsets.reserve(l + 1);
        
        result.path.push_back(p.address);
        result.offsets.push_back(p.offset);
        
        int curIdx = pIdx;
        for (int k = l; k >= 0; k--) {
          result.path.push_back(levels[k].nodes[curIdx].address);
          if (k > 0) {
            result.offsets.push_back(levels[k].nodes[curIdx].offsetFromParent);
          }
          curIdx = levels[k].nodes[curIdx].parentIndex;
        }
        
        results.push_back(std::move(result));
        
        if (results.size() >= 100000) {
          goto search_done;
        }
      }
      
      if (!isStaticBase && l < maxLevels - 1) {
        if (levels[l + 1].addrSet.find(p.address) == levels[l + 1].addrSet.end()) {
          if (levels[l + 1].nodes.size() < config.maxResultsPerLevel) {
            levels[l + 1].nodes.push_back({p.address, pIdx, p.offset, newScore});
            levels[l + 1].addrSet.insert(p.address);
          }
        }
      }
    }
    
    levels[l].addrSet.clear();
    
    if (levels[l + 1].nodes.empty() && results.empty())
      break;
  }
  
search_done:
  
  std::sort(results.begin(), results.end(),
            [](const EnhancedChainResult &a, const EnhancedChainResult &b) {
              
              if (a.isStatic != b.isStatic)
                return a.isStatic > b.isStatic;
              return a.totalScore > b.totalScore;
            });

  return results;
}

void MemoryCore::takeSnapshot(uint64_t maxTotalSize) {
  takeSnapshot(maxTotalSize, 0, 0);
}

void MemoryCore::takeSnapshot(uint64_t maxTotalSize, uint64_t priorityStart,
                              uint64_t priorityEnd) {
  clearSnapshot();
  if (_task == MACH_PORT_NULL)
    return;

  uint64_t totalCaptured = 0;
  if (priorityStart > 0 && priorityEnd > priorityStart) {
    mach_vm_address_t address = priorityStart;
    while (address < priorityEnd) {
      mach_vm_size_t size;
      vm_region_basic_info_data_64_t info;
      mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
      mach_port_t object_name;
      kern_return_t kr =
          mach_vm_region(_task, &address, &size, VM_REGION_BASIC_INFO_64,
                         (vm_region_info_t)&info, &count, &object_name);
      if (kr != KERN_SUCCESS)
        break;

      if ((info.protection & VM_PROT_READ) && size <= 512 * 1024 * 1024) {
        SnapshotRegion region;
        region.start = address;
        region.data.resize(size);
        mach_vm_size_t readSize = size;
        if (mach_vm_read_overwrite(_task, address, size,
                                   (mach_vm_address_t)region.data.data(),
                                   &readSize) == KERN_SUCCESS) {
          region.size = (uint32_t)readSize;
          if (readSize != size)
            region.data.resize(readSize);
          _snapshot.push_back(std::move(region));
          totalCaptured += readSize;
        }
      }
      address += size;
    }
  }

  mach_vm_address_t address = 0x100000000;

  mach_vm_address_t endLimit = 0x8000000000;
  while (address < endLimit) {
    if (totalCaptured > maxTotalSize)
      break;

    mach_vm_size_t size;
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object_name;
    kern_return_t kr =
        mach_vm_region(_task, &address, &size, VM_REGION_BASIC_INFO_64,
                       (vm_region_info_t)&info, &count, &object_name);
    if (kr != KERN_SUCCESS)
      break;

    bool alreadyCaptured = false;
    for (const auto &sr : _snapshot) {
      if (address >= sr.start && address < (sr.start + sr.size)) {
        alreadyCaptured = true;
        break;
      }
    }

    if (!alreadyCaptured && (info.protection & VM_PROT_READ) &&
        size <= 200 * 1024 * 1024) {
      SnapshotRegion region;
      region.start = address;
      region.data.resize(size);
      mach_vm_size_t readSize = size;
      if (mach_vm_read_overwrite(_task, address, size,
                                 (mach_vm_address_t)region.data.data(),
                                 &readSize) == KERN_SUCCESS) {
        region.size = (uint32_t)readSize;
        if (readSize != size)
          region.data.resize(readSize);
        _snapshot.push_back(std::move(region));
        totalCaptured += readSize;
      }
    }
    address += size;
  }
}

void MemoryCore::clearSnapshot() {
  _snapshot.clear();
  _snapshot.shrink_to_fit();
}

bool MemoryCore::readFromSnapshot(uint64_t address, void *buffer, size_t size) {
  if (_snapshot.empty() || !buffer || size == 0)
    return false;
  
  auto it = std::upper_bound(
      _snapshot.begin(), _snapshot.end(), address,
      [](uint64_t addr, const SnapshotRegion &r) {
        return addr < r.start;
      });
  
  if (it != _snapshot.begin()) {
    --it;
    uint64_t regionEnd = it->start + it->size;
    if (address >= it->start && address + size <= regionEnd) {
      
      size_t offset = address - it->start;
      memcpy(buffer, it->data.data() + offset, size);
      return true;
    }
  }
  
  return false;
}

void MemoryCore::saveBaselineSnapshot() {
  
  if (_snapshot.empty()) {
    takeSnapshot(1024 * 1024 * 1024);  
  }
  
  _baselineSnapshot = _snapshot;
}

void MemoryCore::clearBaselineSnapshot() {
  _baselineSnapshot.clear();
  _baselineSnapshot.shrink_to_fit();
}

std::vector<MemoryCore::DiffRegion> MemoryCore::compareWithBaseline(uint64_t minChangeSize) {
  std::vector<DiffRegion> diffs;
  
  if (_baselineSnapshot.empty()) {
    return diffs;
  }
  
  if (_snapshot.empty()) {
    takeSnapshot(1024 * 1024 * 1024);
  }
  
  std::unordered_map<uint64_t, size_t> baselineIndex;
  for (size_t i = 0; i < _baselineSnapshot.size(); i++) {
    baselineIndex[_baselineSnapshot[i].start] = i;
  }
  
  for (const auto &currentRegion : _snapshot) {
    auto it = baselineIndex.find(currentRegion.start);
    if (it == baselineIndex.end()) {
      
      if (currentRegion.size >= minChangeSize) {
        diffs.push_back({currentRegion.start, currentRegion.size});
      }
      continue;
    }
    
    const auto &baselineRegion = _baselineSnapshot[it->second];
    
    size_t compareSize = std::min((size_t)currentRegion.size, (size_t)baselineRegion.size);
    compareSize = std::min(compareSize, currentRegion.data.size());
    compareSize = std::min(compareSize, baselineRegion.data.size());
    
    size_t diffStart = 0;
    bool inDiff = false;
    
    for (size_t i = 0; i < compareSize; i++) {
      bool isDifferent = (currentRegion.data[i] != baselineRegion.data[i]);
      
      if (isDifferent && !inDiff) {
        
        diffStart = i;
        inDiff = true;
      } else if (!isDifferent && inDiff) {
        
        size_t diffSize = i - diffStart;
        if (diffSize >= minChangeSize) {
          diffs.push_back({currentRegion.start + diffStart, (uint32_t)diffSize});
        }
        inDiff = false;
      }
    }
    
    if (inDiff) {
      size_t diffSize = compareSize - diffStart;
      if (diffSize >= minChangeSize) {
        diffs.push_back({currentRegion.start + diffStart, (uint32_t)diffSize});
      }
    }
  }
  
  return diffs;
}

std::vector<MemoryCore::ForwardSearchResult>
MemoryCore::forwardSearchChain(uint64_t target,
                               const std::vector<std::pair<uint64_t, uint64_t>> &dataSegments,
                               int maxDepth, uint32_t maxOffset, size_t maxResults,
                               ProgressCallback progress, void *userData) {
  std::vector<ForwardSearchResult> results;
  
  if (_task == MACH_PORT_NULL || dataSegments.empty() || maxDepth <= 0) {
    return results;
  }
  
  uint64_t targetStripped = target & 0xFFFFFFFFFFFF;
  mach_port_t task = _task;
  
  struct BFSNode {
    uint64_t baseAddr;              
    uint64_t currentAddr;           
    std::vector<int32_t> offsets;   
  };
  
  std::vector<BFSNode> currentLevel;
  currentLevel.reserve(100000);  
  
  std::unordered_set<uint64_t> visitedAddrs;
  visitedAddrs.reserve(500000);
  
  auto isValidPointer = [](uint64_t val) -> bool {
    return val >= 0x100000000 && val < 0x800000000;
  };
  
  for (const auto &seg : dataSegments) {
    uint64_t segStart = seg.first;
    uint64_t segSize = seg.second - seg.first;
    
    const uint64_t chunkSize = 0x100000;  
    for (uint64_t offset = 0; offset < segSize; offset += chunkSize) {
      uint64_t readStart = segStart + offset;
      uint64_t readSize = (segSize - offset < chunkSize) ? (segSize - offset) : chunkSize;
      
      std::vector<uint8_t> buffer(readSize);
      mach_vm_size_t actualRead = 0;
      kern_return_t kr = mach_vm_read_overwrite(
          task, readStart, readSize, (mach_vm_address_t)buffer.data(), &actualRead);
      
      if (kr != KERN_SUCCESS) continue;
      
      const uint64_t *ptrData = (const uint64_t *)buffer.data();
      size_t numPtrs = actualRead / 8;
      
      for (size_t i = 0; i < numPtrs; i++) {
        uint64_t val = ptrData[i] & 0xFFFFFFFFFFFF;
        if (!isValidPointer(val)) continue;
        
        uint64_t baseAddr = readStart + i * 8;
        
        int64_t diff = (int64_t)targetStripped - (int64_t)val;
        if (diff >= 0 && diff <= (int64_t)maxOffset) {
          ForwardSearchResult result;
          result.baseAddress = baseAddr;
          result.offsets = {diff};
          result.finalAddress = targetStripped;
          results.push_back(result);
          
          if (results.size() >= maxResults) {
            goto search_done;
          }
          continue;
        }
        
        if (visitedAddrs.find(val) == visitedAddrs.end()) {
          visitedAddrs.insert(val);
          BFSNode node;
          node.baseAddr = baseAddr;
          node.currentAddr = val;
          currentLevel.push_back(std::move(node));
        }
      }
    }
  }
  
  if (progress) {
    SearchProgress sp;
    sp.level = 1;
    sp.foundCount = results.size();
    progress(sp, userData);
  }
  
  for (int depth = 1; depth < maxDepth && !currentLevel.empty(); depth++) {
    std::vector<BFSNode> nextLevel;
    nextLevel.reserve(std::min(currentLevel.size() * 2, (size_t)500000));
    
    size_t maxNodesPerLevel = 500000;
    if (currentLevel.size() > maxNodesPerLevel) {
      currentLevel.resize(maxNodesPerLevel);
    }
    
    auto resultMutexPtr = std::make_shared<std::mutex>();
    auto nextLevelMutexPtr = std::make_shared<std::mutex>();
    auto shouldStopPtr = std::make_shared<std::atomic<bool>>(false);
    auto resultsPtr = std::make_shared<std::vector<ForwardSearchResult>>(std::move(results));
    auto nextLevelPtr = std::make_shared<std::vector<BFSNode>>();
    nextLevelPtr->reserve(500000);
    
    const size_t batchSize = 500;  
    size_t numBatches = (currentLevel.size() + batchSize - 1) / batchSize;
    
    auto currentLevelPtr = std::make_shared<std::vector<BFSNode>>(std::move(currentLevel));
    uint32_t maxOffsetLocal = maxOffset;
    int maxDepthLocal = maxDepth;
    int depthLocal = depth;
    
    dispatch_apply(numBatches, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
                   ^(size_t batchIdx) {
      if (shouldStopPtr->load(std::memory_order_relaxed)) return;
      
      size_t startIdx = batchIdx * batchSize;
      size_t endIdx = startIdx + batchSize;
      if (endIdx > currentLevelPtr->size()) endIdx = currentLevelPtr->size();
      
      std::vector<BFSNode> localNextLevel;
      localNextLevel.reserve(batchSize * 10);
      std::vector<ForwardSearchResult> localResults;
      
      const size_t readBufSize = maxOffsetLocal + 8;
      std::vector<uint8_t> readBuf(readBufSize);
      
      for (size_t i = startIdx; i < endIdx; i++) {
        if (shouldStopPtr->load(std::memory_order_relaxed)) break;
        
        const BFSNode &node = (*currentLevelPtr)[i];
        
        mach_vm_size_t actualRead = 0;
        kern_return_t kr = mach_vm_read_overwrite(
            task, node.currentAddr, readBufSize, 
            (mach_vm_address_t)readBuf.data(), &actualRead);
        
        if (kr != KERN_SUCCESS || actualRead < 8) continue;
        
        size_t numPtrs = (actualRead - 7) / 8;  
        const uint8_t *bufPtr = readBuf.data();
        
        for (size_t j = 0; j < numPtrs; j++) {
          int64_t offset = (int64_t)(j * 8);
          
          uint64_t val = 0;
          memcpy(&val, bufPtr + j * 8, 8);
          val &= 0xFFFFFFFFFFFF;
          
          if (!isValidPointer(val)) continue;
          
          int64_t diff = (int64_t)targetStripped - (int64_t)val;
          if (diff >= 0 && diff <= (int64_t)maxOffsetLocal) {
            ForwardSearchResult result;
            result.baseAddress = node.baseAddr;
            result.offsets.reserve(node.offsets.size() + 2);
            for (int32_t o : node.offsets) result.offsets.push_back(o);
            result.offsets.push_back(offset);
            result.offsets.push_back(diff);
            result.finalAddress = targetStripped;
            localResults.push_back(std::move(result));
            continue;
          }
          
          if (depthLocal < maxDepthLocal - 1) {
            BFSNode nextNode;
            nextNode.baseAddr = node.baseAddr;
            nextNode.currentAddr = val;
            nextNode.offsets = node.offsets;
            nextNode.offsets.push_back((int32_t)offset);
            localNextLevel.push_back(std::move(nextNode));
          }
        }
      }
      
      if (!localResults.empty()) {
        std::lock_guard<std::mutex> lock(*resultMutexPtr);
        for (auto &r : localResults) {
          if (resultsPtr->size() < maxResults) {
            resultsPtr->push_back(std::move(r));
          }
        }
        if (resultsPtr->size() >= maxResults) {
          shouldStopPtr->store(true, std::memory_order_relaxed);
        }
      }
      
      if (!localNextLevel.empty() && !shouldStopPtr->load(std::memory_order_relaxed)) {
        std::lock_guard<std::mutex> lock(*nextLevelMutexPtr);
        for (auto &n : localNextLevel) {
          if (nextLevelPtr->size() < maxNodesPerLevel) {
            nextLevelPtr->push_back(std::move(n));
          }
        }
      }
    });
    
    results = std::move(*resultsPtr);
    currentLevel = std::move(*nextLevelPtr);
    
    if (results.size() >= maxResults) break;
    
    if (progress) {
      SearchProgress sp;
      sp.level = depth + 1;
      sp.foundCount = results.size();
      progress(sp, userData);
    }
  }
  
search_done:
  
  if (progress) {
    SearchProgress sp;
    sp.level = maxDepth;
    sp.foundCount = results.size();
    progress(sp, userData);
  }
  
  return results;
}

void MemoryCore::fastFuzzyInit() {

  clearFastFuzzySnapshot();

  if (_task == MACH_PORT_NULL) return;

  if (_fastFuzzySnapshotPath.empty()) {
    _fastFuzzySnapshotPath = _storagePath + ".fuzzy";
  }
  if (_fastFuzzySnapshotPath.empty()) return;

  FILE *snapshotFile = fopen(_fastFuzzySnapshotPath.c_str(), "wb");
  if (!snapshotFile) return;

  _fastFuzzyAddressCount = 0;
  const uint64_t endAddress = 0x800000000;
  mach_vm_address_t address = 0x100000000;
  uint64_t totalCaptured = 0;
  const uint64_t maxTotalSize = 8ULL * 1024 * 1024 * 1024;
  const size_t chunkBufferSize = 32ULL * 1024 * 1024;

  while (address < endAddress && totalCaptured < maxTotalSize) {
    mach_vm_size_t size = 0;
    uint32_t depth = 0;
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    vm_region_submap_info_data_64_t info;

    kern_return_t kr = mach_vm_region_recurse(
        _task, &address, &size, &depth,
        (vm_region_recurse_info_t)&info, &count);
    if (kr != KERN_SUCCESS) break;

    if ((info.protection & VM_PROT_READ) && (info.protection & VM_PROT_WRITE)) {
      uint64_t regionStart = address;
      uint64_t regionEnd = std::min<uint64_t>(address + size, endAddress);
      for (uint64_t cursor = regionStart;
           cursor < regionEnd && totalCaptured < maxTotalSize;) {
        uint64_t remainingRegion = regionEnd - cursor;
        uint64_t remainingBudget = maxTotalSize - totalCaptured;
        size_t chunkSize = (size_t)std::min<uint64_t>(
            std::min<uint64_t>(remainingRegion, remainingBudget),
            chunkBufferSize);
        if (chunkSize == 0) break;

        std::vector<uint8_t> buffer(chunkSize);
        mach_vm_size_t readSize = chunkSize;
        if (mach_vm_read_overwrite(_task, cursor, chunkSize,
                                   (mach_vm_address_t)buffer.data(),
                                   &readSize) == KERN_SUCCESS && readSize > 0) {
          uint64_t fileOffset = (uint64_t)ftello(snapshotFile);
          size_t written = fwrite(buffer.data(), 1, (size_t)readSize, snapshotFile);
          if (written == (size_t)readSize) {
            FastFuzzySnapshotRegion region;
            region.start = cursor;
            region.size = (uint64_t)readSize;
            region.fileOffset = fileOffset;
            _fastFuzzySnapshot.push_back(region);
            if (readSize >= 4) {
              _fastFuzzyAddressCount += (size_t)readSize - 3;
            }
            totalCaptured += readSize;
          }
        }
        cursor += chunkSize;
      }
    }
    address += size;
  }

  fclose(snapshotFile);

  if (_fastFuzzySnapshot.empty()) {
    std::remove(_fastFuzzySnapshotPath.c_str());
  }
}

void MemoryCore::clearFastFuzzySnapshot() {
  _fastFuzzySnapshot.clear();
  _fastFuzzySnapshot.shrink_to_fit();
  _fastFuzzyAddressCount = 0;
  if (!_fastFuzzySnapshotPath.empty()) {
    std::remove(_fastFuzzySnapshotPath.c_str());
  }
}

size_t MemoryCore::getFastFuzzyAddressCount() const {
  return _fastFuzzyAddressCount;
}

std::vector<ScanResult> MemoryCore::fastFuzzyFilter(DataType type, int filterMode,
                                                    uint64_t start, uint64_t end) {
  std::vector<ScanResult> emptyRes;
  
  bool hasSnapshot = !_fastFuzzySnapshot.empty();
  bool hasStoredResults = (_resultCount > 0 && !_storagePath.empty());
  
  if (_task == MACH_PORT_NULL) {
    return emptyRes;
  }
  
  if (!hasSnapshot && !hasStoredResults) {
    return emptyRes;
  }
  
  size_t dSize = getSizeForType(type);
  mach_port_t task = _task;
  
  int filterModeLocal = filterMode;
  size_t dSizeLocal = dSize;
  bool isFloatType = (type == DataType::Float || type == DataType::Double);
  bool isFloat = (type == DataType::Float);
  double floatTolerance = _floatTolerance;
  
  bool hasExistingResults = (_resultCount > 0 && !_storagePath.empty());
  
  FILE *outFile = fopen(_swapPath.c_str(), "wb");
  if (!outFile) {
    return emptyRes;
  }
  
  size_t newResultCount = 0;
  
  if (hasExistingResults) {
    
    FILE *inFile = fopen(_storagePath.c_str(), "rb");
    if (!inFile) {
      fclose(outFile);
      return emptyRes;
    }
    
    fseek(inFile, 0, SEEK_END);
    size_t fileSize = ftell(inFile);
    fseek(inFile, 0, SEEK_SET);
    
    size_t totalResults = fileSize / sizeof(RawResult);
    std::vector<RawResult> allResults(totalResults);
    fread(allResults.data(), sizeof(RawResult), totalResults, inFile);
    fclose(inFile);
    
    std::sort(allResults.begin(), allResults.end(), 
              [](const RawResult &a, const RawResult &b) { return a.address < b.address; });
    
    std::vector<uint64_t> currentValues(totalResults, 0);
    std::vector<uint8_t> readSuccess(totalResults, 0);  
    
    uint64_t *currentValuesPtr = currentValues.data();
    uint8_t *readSuccessPtr = readSuccess.data();
    const RawResult *allResultsPtr = allResults.data();
    
    const size_t readBatchSize = 10000;
    size_t numBatches = (totalResults + readBatchSize - 1) / readBatchSize;
    
    dispatch_apply(numBatches, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
        ^(size_t batchIdx) {
          size_t startIdx = batchIdx * readBatchSize;
          size_t endIdx = std::min(startIdx + readBatchSize, totalResults);
          
          for (size_t i = startIdx; i < endIdx; i++) {
            uint8_t buf[8] = {0};
            mach_vm_size_t sz = dSizeLocal;
            if (mach_vm_read_overwrite(task, allResultsPtr[i].address, dSizeLocal,
                                       (mach_vm_address_t)buf, &sz) == KERN_SUCCESS) {
              uint64_t val = 0;
              memcpy(&val, buf, dSizeLocal > 8 ? 8 : dSizeLocal);
              currentValuesPtr[i] = val;
              readSuccessPtr[i] = 1;
            }
          }
        });
    
    std::vector<std::vector<RawResult>> perBatchResults(numBatches);
    std::vector<std::vector<RawResult>> *perBatchResultsPtr = &perBatchResults;
    
    dispatch_apply(numBatches, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0),
        ^(size_t batchIdx) {
          size_t startIdx = batchIdx * readBatchSize;
          size_t endIdx = std::min(startIdx + readBatchSize, totalResults);
          
          std::vector<RawResult> &localResults = (*perBatchResultsPtr)[batchIdx];
          localResults.reserve(readBatchSize / 2);  
          
          for (size_t i = startIdx; i < endIdx; i++) {
            if (!readSuccessPtr[i]) continue;
            
            uint64_t oldValBits = allResultsPtr[i].value;
            uint64_t newValBits = currentValuesPtr[i];
            
            bool match = false;
            if (isFloatType) {
              double oldVal = 0, newVal = 0;
              if (isFloat) {
                oldVal = *(float*)&oldValBits;
                newVal = *(float*)&newValBits;
              } else {
                oldVal = *(double*)&oldValBits;
                newVal = *(double*)&newValBits;
              }
              
              if (filterModeLocal == 0) match = (newVal < oldVal - floatTolerance);
              else if (filterModeLocal == 1) match = (newVal > oldVal + floatTolerance);
              else if (filterModeLocal == 5) match = (fabs(newVal - oldVal) > floatTolerance);
              else if (filterModeLocal == 6) match = (fabs(newVal - oldVal) <= floatTolerance);
            } else {
              int64_t oldVal = 0, newVal = 0;
              switch (dSizeLocal) {
                case 1: 
                  oldVal = (int8_t)oldValBits; 
                  newVal = (int8_t)newValBits; 
                  break;
                case 2: 
                  oldVal = (int16_t)oldValBits; 
                  newVal = (int16_t)newValBits; 
                  break;
                case 8: 
                  oldVal = (int64_t)oldValBits; 
                  newVal = (int64_t)newValBits; 
                  break;
                default: 
                  oldVal = (int32_t)oldValBits; 
                  newVal = (int32_t)newValBits; 
                  break;
              }
              
              if (filterModeLocal == 0) match = (newVal < oldVal);
              else if (filterModeLocal == 1) match = (newVal > oldVal);
              else if (filterModeLocal == 5) match = (newVal != oldVal);
              else if (filterModeLocal == 6) match = (newVal == oldVal);
            }
            
            if (match) {
              localResults.push_back(makeRawResult(allResultsPtr[i].address, newValBits, type));
            }
          }
        });
    
    for (const auto &localResults : perBatchResults) {
      if (!localResults.empty()) {
        fwrite(localResults.data(), sizeof(RawResult), localResults.size(), outFile);
        newResultCount += localResults.size();
      }
    }
    
  } else {
    
    const uint64_t endAddress = 0x800000000;
    uint64_t startAddr = start;
    uint64_t endAddr = endAddress;

    FILE *snapshotFile = fopen(_fastFuzzySnapshotPath.c_str(), "rb");
    if (!snapshotFile) {
      fclose(outFile);
      return emptyRes;
    }

    std::vector<RawResult> localResults;
    localResults.reserve(65536);
    auto flushLocalResults = [&]() {
      if (!localResults.empty()) {
        fwrite(localResults.data(), sizeof(RawResult), localResults.size(), outFile);
        newResultCount += localResults.size();
        localResults.clear();
      }
    };

    for (const auto &oldRegion : _fastFuzzySnapshot) {
      if (oldRegion.start >= endAddr) continue;
      uint64_t regionEnd = oldRegion.start + oldRegion.size;
      if (regionEnd <= startAddr) continue;
      if (oldRegion.size < dSizeLocal) continue;

      std::vector<uint8_t> oldData((size_t)oldRegion.size);
      std::vector<uint8_t> currentData((size_t)oldRegion.size);
      if (fseeko(snapshotFile, (off_t)oldRegion.fileOffset, SEEK_SET) != 0) continue;
      size_t oldRead = fread(oldData.data(), 1, (size_t)oldRegion.size, snapshotFile);
      if (oldRead == 0) continue;

      mach_vm_size_t readSize = oldRegion.size;
      if (mach_vm_read_overwrite(task, oldRegion.start, oldRegion.size,
                                 (mach_vm_address_t)currentData.data(),
                                 &readSize) != KERN_SUCCESS) {
        continue;
      }

      size_t compareSize = std::min(oldRead, (size_t)readSize);
      if (compareSize < dSizeLocal) continue;

      const uint8_t *oldBytes = oldData.data();
      const uint8_t *newBytes = currentData.data();

      for (size_t offset = 0; offset + dSizeLocal <= compareSize; offset += dSizeLocal) {
        uint64_t addr = oldRegion.start + offset;
        if (addr < startAddr || addr >= endAddr) continue;

        bool match = false;
        uint64_t newValBits = 0;

        if (isFloatType) {
          double oldVal = 0, newVal = 0;
          if (isFloat) {
            oldVal = *(float *)(oldBytes + offset);
            newVal = *(float *)(newBytes + offset);
            memcpy(&newValBits, newBytes + offset, 4);
          } else {
            oldVal = *(double *)(oldBytes + offset);
            newVal = *(double *)(newBytes + offset);
            memcpy(&newValBits, newBytes + offset, 8);
          }

          if (filterModeLocal == 0) match = (newVal < oldVal - floatTolerance);
          else if (filterModeLocal == 1) match = (newVal > oldVal + floatTolerance);
          else if (filterModeLocal == 5) match = (fabs(newVal - oldVal) > floatTolerance);
          else if (filterModeLocal == 6) match = (fabs(newVal - oldVal) <= floatTolerance);
        } else {
          int64_t oldVal = 0, newVal = 0;
          switch (dSizeLocal) {
            case 1: oldVal = *(int8_t *)(oldBytes + offset); newVal = *(int8_t *)(newBytes + offset); break;
            case 2: oldVal = *(int16_t *)(oldBytes + offset); newVal = *(int16_t *)(newBytes + offset); break;
            case 8: oldVal = *(int64_t *)(oldBytes + offset); newVal = *(int64_t *)(newBytes + offset); break;
            default: oldVal = *(int32_t *)(oldBytes + offset); newVal = *(int32_t *)(newBytes + offset); break;
          }

          memcpy(&newValBits, newBytes + offset, dSizeLocal > 8 ? 8 : dSizeLocal);

          if (filterModeLocal == 0) match = (newVal < oldVal);
          else if (filterModeLocal == 1) match = (newVal > oldVal);
          else if (filterModeLocal == 5) match = (newVal != oldVal);
          else if (filterModeLocal == 6) match = (newVal == oldVal);
        }

        if (match) {
          localResults.push_back(makeRawResult(addr, newValBits, type));
          if (localResults.size() >= 65536) {
            flushLocalResults();
          }
        }
      }
    }
    flushLocalResults();
    fclose(snapshotFile);
  }
  
  fclose(outFile);
  
  if (newResultCount == 0) {
    remove(_swapPath.c_str());
    _resultCount = 0;
  } else {
    remove(_storagePath.c_str());
    rename(_swapPath.c_str(), _storagePath.c_str());
    _resultCount = newResultCount;
  }
  
  if (!_fastFuzzySnapshot.empty()) {
    clearFastFuzzySnapshot();
  }
  
  return getResults(0, 100);
}

} 
#endif
