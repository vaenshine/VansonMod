#ifndef MemoryTypes_hpp
#define MemoryTypes_hpp

#include <cstdint>
#include <string>
#include <vector>

namespace VMCore {

enum class DataType : uint8_t {
  Int8,
  Int16,
  Int32,
  Int64,
  UInt8,
  UInt16,
  UInt32,
  UInt64,
  Float,
  Double,
  String
};

enum class StringEncoding : uint8_t { UTF8 = 0, UTF16LE = 1, UTF16BE = 2 };

struct StringSearchOptions {
  StringEncoding encoding = StringEncoding::UTF8;
  bool caseSensitive = true;
};

struct ScanResult {
  uint64_t address;
  DataType type;
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
  } value;
  // For String results, value.u64 stores the matched byte length.
  
  ScanResult() : address(0), type(DataType::Int32) {
    value.i64 = 0;
  }
};

struct MemoryRegion {
  uint64_t start;
  uint64_t end;
  bool isWritable;
  bool isExecutable;
};

struct PointerResult {
  uint64_t address;   
  uint64_t value;     
  int64_t offset;     
};

} 

#endif /* MemoryTypes_hpp */
