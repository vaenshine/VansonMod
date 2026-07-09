 
#ifndef VMDebugCore_hpp
#define VMDebugCore_hpp

#include <cstdint>
#include <string>
#include <vector>
#include <mutex>
#include <functional>
#include <thread>
#include <mach/mach.h>

namespace VMDebug {

enum class WatchType : uint8_t {
    Write = 0,
    Read = 1,
    ReadWrite = 2
};

enum class WatchSize : uint8_t {
    Byte1 = 0,
    Byte2 = 1,
    Byte4 = 2,
    Byte8 = 3
};

struct StackFrame {
    uint64_t pc;
    std::string imageName;
    uint64_t imageBase;
    uint64_t offset;
};

struct WatchHit {
    uint32_t wpIndex;
    uint64_t pc;
    uint64_t lr;
    uint64_t address;
    uint64_t newValue;
    std::string imageName;
    uint64_t offset;
    std::vector<StackFrame> stackTrace;
    double timestamp;
};

struct WatchSlot {
    uint32_t index;
    uint64_t address;
    uint64_t lastValue;
    WatchType type;
    WatchSize size;
    bool active;
    bool lastValueValid;
    std::vector<WatchHit> hits;
};

using WatchHitCallback = std::function<void(const WatchHit &hit)>;

struct RawHitContext {
    uint64_t pc;
    uint64_t lr;
    uint64_t address;
    uint64_t exceptionCode;
    uint64_t exceptionSubcode;
    uint32_t wpIndex;
};

class DebugCore {
public:
    static DebugCore &inst();
    static constexpr uint32_t MAX_SLOTS = 4;

    bool attach(mach_port_t externalTask);
    void detach();
    bool isAttached() const { return _attached; }
    mach_port_t currentTask() const { return _task; }

    int addWatch(uint64_t address, WatchType type = WatchType::Write,
                 WatchSize size = WatchSize::Byte4);
    bool removeWatch(uint32_t index);
    void removeAll();

    const std::vector<WatchSlot> &getSlots() const { return _slots; }
    uint32_t activeCount() const;

    const std::vector<WatchHit> &getHits(uint32_t slotIndex) const;
    void clearHits(uint32_t slotIndex);
    void clearAllHits();

    void setHitCallback(WatchHitCallback cb);

    StackFrame symbolicateRemote(uint64_t pc);

private:
    DebugCore() = default;
    ~DebugCore();

    bool attachLocked();
    bool setupExceptionPort();
    void listenerThread();
    void safeProcessHit(RawHitContext raw);

    bool applyToHardware(const WatchSlot &slot);
    bool applyToHardwareSingle(const WatchSlot &slot, mach_port_t thread);
    bool clearHardware(uint32_t index);
    uint8_t basForSize(WatchSize size);
    size_t byteCountForSize(WatchSize size) const;
    bool slotContainsAddress(const WatchSlot &slot, uint64_t address) const;
    bool readSlotValueLocked(const WatchSlot &slot, uint64_t &value);
    bool slotAddressForIndex(uint32_t index, uint64_t &address);
    uint32_t resolveHitSlot(uint64_t exceptionCode, uint64_t exceptionSubcode);

    bool readRemote(uint64_t address, void *buffer, size_t size);

    mach_port_t _task = MACH_PORT_NULL;
    mach_port_t _exceptionPort = MACH_PORT_NULL;
    bool _attached = false;
    bool _listening = false;

    std::vector<WatchSlot> _slots;
    std::mutex _mutex;
    std::mutex _hitMutex;
    std::thread _listenerThread;
    WatchHitCallback _hitCallback;
    uint32_t _lastHitIndex = UINT32_MAX;
    uint64_t _lastHitPc = 0;
    uint64_t _lastHitAddress = 0;
    double _lastHitTimestamp = 0;

    struct RemoteModule {
        uint64_t loadAddress;
        uint32_t size;
        std::string name;
    };
    std::vector<RemoteModule> _remoteModules;
    std::mutex _moduleMutex;
    void refreshRemoteModules();

    static const std::vector<WatchHit> _emptyHits;
};

} 

#endif /* VMDebugCore_hpp */
