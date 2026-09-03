#ifndef MemoryCore_hpp
#define MemoryCore_hpp

#include "MemoryTypes.hpp"
#include <functional>
#include <mach/mach.h>
#include <string>
#include <vector>

namespace VMCore {

struct SignatureData {
  std::vector<uint8_t> bytes;
  std::vector<bool> mask;
  size_t length;
  int firstValidIndex;     
  uint8_t firstValidByte;  
};

struct PointerChainNode {
  uint64_t address;
  int32_t parentIndex;
};

struct SnapshotRegion {
  uint64_t start;
  uint32_t size;
  std::vector<uint8_t> data;
};

struct GroupItem {
  DataType type;
  union Value {
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
  } value, minValue, maxValue;
  bool relative; 
  bool isRange;
  bool isWildcard;
  uint64_t skipBytes;
};

enum class FilterMode {
  Less = 0,
  Greater = 1,
  Between = 2,
  Increased = 3,
  Decreased = 4,
  Changed = 5,
  Unchanged = 6
};

class MemoryCore {
public:
  MemoryCore();
  ~MemoryCore();

  bool attach(pid_t pid);
  pid_t getProcessId() const { return _pid; }

  bool readMemory(uint64_t address, void *buffer, size_t size);
  bool writeMemory(uint64_t address, const void *buffer, size_t size);

  void takeSnapshot(uint64_t maxTotalSize = 1024 * 1024 * 1024); 
  void takeSnapshot(uint64_t maxTotalSize, uint64_t priorityStart,
                    uint64_t priorityEnd);
  const std::vector<SnapshotRegion> &getSnapshot() const { return _snapshot; }
  void clearSnapshot();
  
  bool hasSnapshot() const { return !_snapshot.empty(); }
  size_t getSnapshotSize() const {
    size_t total = 0;
    for (const auto &r : _snapshot) total += r.size;
    return total;
  }

  std::vector<ScanResult> scan(DataType type, const std::string &valueStr,
                               int searchMode, uint64_t start = 0,
                               uint64_t end = 0);

  std::vector<ScanResult>
  nextScan(const std::vector<ScanResult> &previousResults, DataType type,
           const std::string &valueStr, int searchMode);

  std::vector<ScanResult> scanNearby(const std::vector<ScanResult> &baseResults,
                                     DataType type, const std::string &valueStr,
                                     uint64_t range);

  size_t filterResults(FilterMode mode, DataType type, const std::string &v1,
                       const std::string &v2);
  bool removeResult(size_t index);
  void batchModify(const std::string &input, int limit, DataType type,
                   int mode);

  void setResultLimit(size_t limit) { _resultLimit = limit; }
  size_t getResultLimit() const { return _resultLimit; }
  
  void setFloatTolerance(double tolerance) { _floatTolerance = tolerance; }
  double getFloatTolerance() const { return _floatTolerance; }
  
  void setGroupSearchRange(uint64_t range) { _groupSearchRange = range; }
  uint64_t getGroupSearchRange() const { return _groupSearchRange; }
  
  void setGroupAnchorMode(bool enabled) { _groupAnchorMode = enabled; }
  bool getGroupAnchorMode() const { return _groupAnchorMode; }

  void runSecurityChecks();

  std::vector<PointerResult> scanPointers(const std::vector<uint64_t> &targets,
                                          uint64_t start, uint64_t end,
                                          uint32_t maxOffset, size_t limit = 0);

  SignatureData parseSignature(const std::string &sig);
  std::vector<ScanResult> scanSignature(const std::string &sig, uint64_t start,
                                        uint64_t end);

  struct SearchProgress {
    int level;
    size_t foundCount;
  };
  typedef void (*ProgressCallback)(SearchProgress progress, void *userData);
  typedef std::function<bool(uint64_t)> IsBaseAddressCallback;

  std::vector<std::vector<uint64_t>>
  autoSearchChain(uint64_t target, uint64_t heapStart, uint64_t heapEnd,
                  uint64_t baseStart, uint64_t baseEnd, int maxLevels,
                  size_t maxPerLevel, uint32_t maxOffset,
                  ProgressCallback progress, void *userData,
                  IsBaseAddressCallback isBaseCallback = nullptr);

  struct PointerSearchConfig {
    uint32_t firstLevelMaxOffset = 0x200;    
    uint32_t subsequentMaxOffset = 0x1000;   
    bool preferAlignedOffsets = true;        
    bool validatePointerTarget = true;       
    uint32_t maxResultsPerLevel = 100000;    
    bool scoreAndSort = true;                
  };
  
  struct ScoredPointerResult {
    uint64_t address;
    uint64_t value;
    int64_t offset;
    uint32_t score;  
  };
  
  std::vector<ScoredPointerResult> scanPointersScored(const std::vector<uint64_t> &targets,
                                                       uint64_t start, uint64_t end,
                                                       uint32_t maxOffset, int level,
                                                       size_t limit = 0);
  
  struct EnhancedChainResult {
    std::vector<uint64_t> path;       
    std::vector<int64_t> offsets;     
    uint32_t totalScore;              
    bool isStatic;                    
  };
  
  std::vector<EnhancedChainResult>
  autoSearchChainEnhanced(uint64_t target, uint64_t heapStart, uint64_t heapEnd,
                          const PointerSearchConfig &config, int maxLevels,
                          ProgressCallback progress, void *userData,
                          IsBaseAddressCallback isBaseCallback = nullptr);

  struct ForwardSearchResult {
    uint64_t baseAddress;           
    std::vector<int64_t> offsets;   
    uint64_t finalAddress;          
  };
  
  std::vector<ForwardSearchResult>
  forwardSearchChain(uint64_t target, 
                     const std::vector<std::pair<uint64_t, uint64_t>> &dataSegments,
                     int maxDepth, uint32_t maxOffset, size_t maxResults,
                     ProgressCallback progress, void *userData);

  struct DiffRegion {
    uint64_t address;
    uint32_t size;
  };
  
  void saveBaselineSnapshot();  
  void clearBaselineSnapshot(); 
  bool hasBaselineSnapshot() const { return !_baselineSnapshot.empty(); }
  std::vector<DiffRegion> compareWithBaseline(uint64_t minChangeSize = 8);  

  struct FastFuzzyResult {
    uint64_t address;
    uint64_t oldValue;
    uint64_t newValue;
  };

  struct FastFuzzySnapshotRegion {
    uint64_t start;
    uint64_t size;
    uint64_t fileOffset;
  };
  
  void fastFuzzyInit(uint64_t start = 0, uint64_t end = 0);
  size_t getFastFuzzyAddressCount() const;  
  
  bool hasFastFuzzySnapshot() const { return !_fastFuzzySnapshot.empty() || _resultCount > 0; }
  
  std::vector<ScanResult> fastFuzzyFilter(DataType type, int filterMode, 
                                          uint64_t start = 0, uint64_t end = 0);
  
  void clearFastFuzzySnapshot();  

  std::vector<GroupItem> parseGroupString(const std::string &groupStr,
                                          DataType defaultType,
                                          uint64_t &outRange);
  void parseRangeString(const std::string &rangeStr, DataType type,
                        void *minVal, void *maxVal);

  void setStoragePath(const std::string &path, const std::string &swapPath);
  bool restoreResultsFromFile(const std::string &filePath, size_t resultCount);
  size_t restoreValuesFromFile(const std::string &filePath,
                               size_t resultCount, size_t maxCount);
  std::vector<ScanResult> getResults(size_t start, size_t count);
  size_t getResultCount() const { return _resultCount; }
  void clearResults() { _resultCount = 0; }  
  
  bool readFromSnapshot(uint64_t address, void *buffer, size_t size);

private:
  pid_t _pid;
  mach_port_t _task;
  size_t _resultLimit;
  double _floatTolerance = 0.001;
  uint64_t _groupSearchRange = 50;
  bool _groupAnchorMode = false;  

  std::string _storagePath;
  std::string _swapPath;
  std::string _fastFuzzySnapshotPath;
  size_t _resultCount = 0;
  size_t _fastFuzzyAddressCount = 0;
  
  std::vector<SnapshotRegion> _baselineSnapshot;
  
  std::vector<FastFuzzySnapshotRegion> _fastFuzzySnapshot;

  std::vector<SnapshotRegion> _snapshot;

  void parseValue(const std::string &valStr, DataType type, void *outVal);
};

} 

#endif /* MemoryCore_hpp */
