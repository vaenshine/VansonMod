 
#include "VMDebugCore.hpp"
#include "SystemCore.hpp"
#include <mach/arm/exception.h>
#include <mach/exception_types.h>
#include <mach/mach.h>
#include <mach/mach_types.h>
#include <mach/thread_act.h>
#include <mach/thread_status.h>
#include <sys/time.h>
#include <unistd.h>
#include <cstdio>
#include <cstring>
#include <dispatch/dispatch.h>

extern "C" {
kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t,
                                     mach_vm_size_t, mach_vm_address_t,
                                     mach_vm_size_t *);
}

namespace VMDebug {

const std::vector<WatchHit> DebugCore::_emptyHits;

DebugCore &DebugCore::inst() {
    static DebugCore instance;
    return instance;
}

DebugCore::~DebugCore() {
    detach();
}

#pragma mark - Lifecycle

bool DebugCore::attach(mach_port_t externalTask) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (_attached) {
        
        if (_task == externalTask) return true;
        
    }
    _task = externalTask;
    return attachLocked();
}

bool DebugCore::attachLocked() {
    if (_attached) return true;
    if (_task == MACH_PORT_NULL) return false;

    _slots.clear();
    for (uint32_t i = 0; i < MAX_SLOTS; i++) {
        WatchSlot slot{};
        slot.index = i;
        slot.active = false;
        _slots.push_back(slot);
    }

    if (!setupExceptionPort()) {
        return false;
    }

    refreshRemoteModules();

    _attached = true;
    return true;
}

void DebugCore::detach() {
    _listening = false;

    if (_attached) {
        std::lock_guard<std::mutex> lock(_mutex);
        for (auto &slot : _slots) {
            if (slot.active) {
                clearHardware(slot.index);
                slot.active = false;
            }
        }
        _attached = false;
    }

    if (_exceptionPort != MACH_PORT_NULL) {
        mach_msg_header_t msg{};
        msg.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_MAKE_SEND, 0);
        msg.msgh_size = sizeof(msg);
        msg.msgh_remote_port = _exceptionPort;
        msg.msgh_local_port = MACH_PORT_NULL;
        mach_msg(&msg, MACH_SEND_MSG | MACH_SEND_TIMEOUT, sizeof(msg), 0,
                 MACH_PORT_NULL, 100, MACH_PORT_NULL);
    }

    if (_listenerThread.joinable()) {
        _listenerThread.join();
    }

    if (_exceptionPort != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), _exceptionPort);
        _exceptionPort = MACH_PORT_NULL;
    }

    _task = MACH_PORT_NULL;
}

#pragma mark - Exception Port

bool DebugCore::setupExceptionPort() {
    kern_return_t kr;

    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &_exceptionPort);
    if (kr != KERN_SUCCESS) return false;

    kr = mach_port_insert_right(mach_task_self(), _exceptionPort, _exceptionPort,
                                 MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), _exceptionPort);
        _exceptionPort = MACH_PORT_NULL;
        return false;
    }

    kr = task_set_exception_ports(_task, EXC_MASK_BREAKPOINT,
                                  _exceptionPort,
                                  (exception_behavior_t)(EXCEPTION_DEFAULT |
                                                         MACH_EXCEPTION_CODES),
                                  ARM_THREAD_STATE64);
    if (kr != KERN_SUCCESS) {
        mach_port_deallocate(mach_task_self(), _exceptionPort);
        _exceptionPort = MACH_PORT_NULL;
        return false;
    }

    _listening = true;
    _listenerThread = std::thread(&DebugCore::listenerThread, this);
    return true;
}

#pragma mark - Exception Listener

#pragma pack(push, 4)
struct ExceptionMsg {
    mach_msg_header_t head;
    mach_msg_body_t body;
    mach_msg_port_descriptor_t thread;
    mach_msg_port_descriptor_t task;
    NDR_record_t NDR;
    exception_type_t exception;
    mach_msg_type_number_t codeCnt;
    mach_exception_data_type_t code[2];
    mach_msg_trailer_t trailer;
    char _pad[256];
};

struct ExceptionReply {
    mach_msg_header_t head;
    NDR_record_t NDR;
    kern_return_t retCode;
};
#pragma pack(pop)

void DebugCore::listenerThread() {
    while (_listening) {
        ExceptionMsg msg{};
        kern_return_t kr = mach_msg(&msg.head, MACH_RCV_MSG | MACH_RCV_LARGE,
                                     0, sizeof(msg), _exceptionPort,
                                     MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

        if (kr != KERN_SUCCESS) {
            if (!_listening) break;
            usleep(100000);
            continue;
        }

        if (msg.exception == EXC_BREAKPOINT) {
            mach_port_t excThread = msg.thread.name;

            arm_thread_state64_t threadState{};
            mach_msg_type_number_t tsCount = ARM_THREAD_STATE64_COUNT;
            thread_get_state(excThread, ARM_THREAD_STATE64,
                             (thread_state_t)&threadState, &tsCount);

            uint64_t pc = arm_thread_state64_get_pc(threadState);
            uint64_t lr = arm_thread_state64_get_lr(threadState);

            arm_debug_state64_t dbgState{};
            mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;
            kern_return_t getKr = thread_get_state(excThread, ARM_DEBUG_STATE64,
                                                    (thread_state_t)&dbgState, &dbgCount);

            RawHitContext raw{};
            raw.pc = pc;
            raw.lr = lr;
            uint64_t exceptionCode = (msg.codeCnt > 0) ? (uint64_t)msg.code[0] : 0;
            uint64_t exceptionSubcode = (msg.codeCnt > 1) ? (uint64_t)msg.code[1] : 0;
            raw.exceptionCode = exceptionCode;
            raw.exceptionSubcode = exceptionSubcode;
            raw.wpIndex = resolveHitSlot(exceptionCode, exceptionSubcode);
            raw.address = 0;

            if (getKr == KERN_SUCCESS) {
                slotAddressForIndex(raw.wpIndex, raw.address);

                for (int i = 0; i < 16; i++) {
                    if (dbgState.__wcr[i] & 1) {
                        dbgState.__wcr[i] = 0;
                    }
                }
                thread_set_state(excThread, ARM_DEBUG_STATE64,
                                 (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
            }

            mach_port_t replyPort = msg.head.msgh_remote_port;
            ExceptionReply reply{};
            reply.head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(msg.head.msgh_bits), 0);
            reply.head.msgh_remote_port = replyPort;
            reply.head.msgh_local_port = MACH_PORT_NULL;
            reply.head.msgh_size = sizeof(reply);
            reply.head.msgh_id = msg.head.msgh_id + 100;
            reply.NDR = NDR_record;
            reply.retCode = KERN_SUCCESS;

            kr = mach_msg(&reply.head, MACH_SEND_MSG, sizeof(reply), 0,
                          MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);

            if (kr == KERN_SUCCESS) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    this->safeProcessHit(raw);
                    usleep(5000);
                    std::lock_guard<std::mutex> lock(this->_mutex);
                    for (auto &slot : this->_slots) {
                        if (slot.active) {
                            this->applyToHardware(slot);
                        }
                    }
                });
            }
            continue;
        }

        {
            ExceptionReply reply{};
            reply.head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(msg.head.msgh_bits), 0);
            reply.head.msgh_remote_port = msg.head.msgh_remote_port;
            reply.head.msgh_local_port = MACH_PORT_NULL;
            reply.head.msgh_size = sizeof(reply);
            reply.head.msgh_id = msg.head.msgh_id + 100;
            reply.NDR = NDR_record;
            reply.retCode = KERN_SUCCESS;
            mach_msg(&reply.head, MACH_SEND_MSG, sizeof(reply), 0,
                     MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        }
    }
}

void DebugCore::safeProcessHit(RawHitContext raw) {
    if (!slotAddressForIndex(raw.wpIndex, raw.address)) {
        raw.wpIndex = resolveHitSlot(raw.exceptionCode, raw.exceptionSubcode);
        if (!slotAddressForIndex(raw.wpIndex, raw.address)) {
            return;
        }
    }

    struct timeval tv;
    gettimeofday(&tv, nullptr);
    double now = tv.tv_sec + tv.tv_usec / 1000000.0;
    {
        std::lock_guard<std::mutex> lock(_hitMutex);
        if (_lastHitIndex == raw.wpIndex && _lastHitPc == raw.pc &&
            _lastHitAddress == raw.address &&
            (now - _lastHitTimestamp) < 0.08) {
            return;
        }
        _lastHitIndex = raw.wpIndex;
        _lastHitPc = raw.pc;
        _lastHitAddress = raw.address;
        _lastHitTimestamp = now;
    }

    WatchHit hit{};
    hit.wpIndex = raw.wpIndex;
    hit.pc = raw.pc;
    hit.lr = raw.lr;
    hit.address = raw.address;

    StackFrame pcFrame = symbolicateRemote(raw.pc);
    hit.imageName = pcFrame.imageName;
    hit.offset = pcFrame.offset;

    uint64_t val = 0;
    if (raw.wpIndex < MAX_SLOTS && raw.wpIndex < _slots.size()) {
        size_t readSize = 4;
        {
            std::lock_guard<std::mutex> lock(_mutex);
            if (raw.wpIndex < _slots.size()) {
                readSize = byteCountForSize(_slots[raw.wpIndex].size);
            }
        }
        if (readRemote(raw.address, &val, readSize)) {
            hit.newValue = val;
            std::lock_guard<std::mutex> lock(_mutex);
            if (raw.wpIndex < _slots.size()) {
                _slots[raw.wpIndex].lastValue = val;
                _slots[raw.wpIndex].lastValueValid = true;
            }
        }
    }

    hit.timestamp = now;
    hit.stackTrace = {};

    {
        std::lock_guard<std::mutex> lock(_hitMutex);
        if (raw.wpIndex < _slots.size()) {
            _slots[raw.wpIndex].hits.push_back(hit);
        }
    }

    WatchHitCallback cb;
    {
        std::lock_guard<std::mutex> lock(_hitMutex);
        cb = _hitCallback;
    }
    if (cb) {
        cb(hit);
    }
}

#pragma mark - Watchpoint Management

int DebugCore::addWatch(uint64_t address, WatchType type, WatchSize size) {
    std::lock_guard<std::mutex> lock(_mutex);

    if (!_attached) return -1;

    int freeSlot = -1;
    for (uint32_t i = 0; i < MAX_SLOTS; i++) {
        if (!_slots[i].active) {
            freeSlot = (int)i;
            break;
        }
    }
    if (freeSlot < 0) return -1;

    _slots[freeSlot].type = type;
    _slots[freeSlot].size = size;
    _slots[freeSlot].address = address;
    _slots[freeSlot].lastValue = 0;
    _slots[freeSlot].lastValueValid = readSlotValueLocked(_slots[freeSlot], _slots[freeSlot].lastValue);
    _slots[freeSlot].active = true;
    _slots[freeSlot].hits.clear();

    if (!applyToHardware(_slots[freeSlot])) {
        _slots[freeSlot].active = false;
        _slots[freeSlot].lastValueValid = false;
        return -1;
    }

    return freeSlot;
}

bool DebugCore::removeWatch(uint32_t index) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (index >= MAX_SLOTS || !_slots[index].active) return false;
    clearHardware(index);
    _slots[index].active = false;
    _slots[index].lastValueValid = false;
    return true;
}

void DebugCore::removeAll() {
    std::lock_guard<std::mutex> lock(_mutex);
    for (auto &slot : _slots) {
        if (slot.active) {
            clearHardware(slot.index);
            slot.active = false;
            slot.lastValueValid = false;
        }
    }
}

uint32_t DebugCore::activeCount() const {
    uint32_t count = 0;
    for (auto &slot : _slots) {
        if (slot.active) count++;
    }
    return count;
}

const std::vector<WatchHit> &DebugCore::getHits(uint32_t slotIndex) const {
    if (slotIndex < _slots.size()) return _slots[slotIndex].hits;
    return _emptyHits;
}

void DebugCore::clearHits(uint32_t slotIndex) {
    std::lock_guard<std::mutex> lock(_hitMutex);
    if (slotIndex < _slots.size()) _slots[slotIndex].hits.clear();
}

void DebugCore::clearAllHits() {
    std::lock_guard<std::mutex> lock(_hitMutex);
    for (auto &slot : _slots) slot.hits.clear();
}

void DebugCore::setHitCallback(WatchHitCallback cb) {
    std::lock_guard<std::mutex> lock(_hitMutex);
    _hitCallback = cb;
}

#pragma mark - Hardware Operations

bool DebugCore::applyToHardware(const WatchSlot &slot) {
    if (_task == MACH_PORT_NULL) return false;

    thread_act_array_t threads;
    mach_msg_type_number_t threadCount;
    if (task_threads(_task, &threads, &threadCount) != KERN_SUCCESS) return false;
    if (threadCount == 0) return false;

    bool success = false;

    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        
        thread_suspend(threads[t]);

        arm_debug_state64_t dbgState{};
        mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;

        kern_return_t kr = thread_get_state(threads[t], ARM_DEBUG_STATE64,
                                             (thread_state_t)&dbgState, &dbgCount);
        if (kr != KERN_SUCCESS) {
            thread_resume(threads[t]);
            continue;
        }

        dbgState.__wvr[slot.index] = slot.address;

        uint64_t wcr = 0;
        wcr |= 1;  

        switch (slot.type) {
            case WatchType::Write:     wcr |= (0x2 << 3); break;
            case WatchType::Read:      wcr |= (0x1 << 3); break;
            case WatchType::ReadWrite: wcr |= (0x3 << 3); break;
        }

        wcr |= ((uint64_t)basForSize(slot.size) << 5);

        dbgState.__wcr[slot.index] = wcr;

        kr = thread_set_state(threads[t], ARM_DEBUG_STATE64,
                               (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
        if (kr == KERN_SUCCESS && t == 0) success = true;

        thread_resume(threads[t]);
    }

    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        mach_port_deallocate(mach_task_self(), threads[t]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads,
                  threadCount * sizeof(thread_act_t));

    return success;
}

bool DebugCore::applyToHardwareSingle(const WatchSlot &slot, mach_port_t thread) {
    
    arm_debug_state64_t dbgState{};
    mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;

    kern_return_t kr = thread_get_state(thread, ARM_DEBUG_STATE64,
                                         (thread_state_t)&dbgState, &dbgCount);
    if (kr != KERN_SUCCESS) return false;

    dbgState.__wvr[slot.index] = slot.address;

    uint64_t wcr = 0;
    wcr |= 1;
    switch (slot.type) {
        case WatchType::Write:     wcr |= (0x2 << 3); break;
        case WatchType::Read:      wcr |= (0x1 << 3); break;
        case WatchType::ReadWrite: wcr |= (0x3 << 3); break;
    }
    wcr |= ((uint64_t)basForSize(slot.size) << 5);
    dbgState.__wcr[slot.index] = wcr;

    kr = thread_set_state(thread, ARM_DEBUG_STATE64,
                           (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
    return kr == KERN_SUCCESS;
}

bool DebugCore::clearHardware(uint32_t index) {
    if (_task == MACH_PORT_NULL || index >= MAX_SLOTS) return false;

    thread_act_array_t threads;
    mach_msg_type_number_t threadCount;
    if (task_threads(_task, &threads, &threadCount) != KERN_SUCCESS) return false;

    for (mach_msg_type_number_t t = 0; t < threadCount; t++) {
        arm_debug_state64_t dbgState{};
        mach_msg_type_number_t dbgCount = ARM_DEBUG_STATE64_COUNT;

        if (thread_get_state(threads[t], ARM_DEBUG_STATE64,
                              (thread_state_t)&dbgState, &dbgCount) == KERN_SUCCESS) {
            dbgState.__wvr[index] = 0;
            dbgState.__wcr[index] = 0;
            thread_set_state(threads[t], ARM_DEBUG_STATE64,
                              (thread_state_t)&dbgState, ARM_DEBUG_STATE64_COUNT);
        }
        mach_port_deallocate(mach_task_self(), threads[t]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads,
                  threadCount * sizeof(thread_act_t));
    return true;
}

uint8_t DebugCore::basForSize(WatchSize size) {
    switch (size) {
        case WatchSize::Byte1: return 0x01;
        case WatchSize::Byte2: return 0x03;
        case WatchSize::Byte4: return 0x0F;
        case WatchSize::Byte8: return 0xFF;
    }
    return 0x0F;
}

size_t DebugCore::byteCountForSize(WatchSize size) const {
    switch (size) {
        case WatchSize::Byte1: return 1;
        case WatchSize::Byte2: return 2;
        case WatchSize::Byte4: return 4;
        case WatchSize::Byte8: return 8;
    }
    return 4;
}

bool DebugCore::slotContainsAddress(const WatchSlot &slot, uint64_t address) const {
    if (!slot.active || address == 0) return false;
    uint64_t size = byteCountForSize(slot.size);
    return address >= slot.address && address < slot.address + size;
}

bool DebugCore::readSlotValueLocked(const WatchSlot &slot, uint64_t &value) {
    value = 0;
    return readRemote(slot.address, &value, byteCountForSize(slot.size));
}

bool DebugCore::slotAddressForIndex(uint32_t index, uint64_t &address) {
    std::lock_guard<std::mutex> lock(_mutex);
    if (index >= MAX_SLOTS || index >= _slots.size() || !_slots[index].active) {
        return false;
    }
    address = _slots[index].address;
    return true;
}

uint32_t DebugCore::resolveHitSlot(uint64_t exceptionCode,
                                   uint64_t exceptionSubcode) {
    std::lock_guard<std::mutex> lock(_mutex);

    for (const auto &slot : _slots) {
        if (slotContainsAddress(slot, exceptionSubcode)) {
            return slot.index;
        }
    }

    for (const auto &slot : _slots) {
        if (slotContainsAddress(slot, exceptionCode)) {
            return slot.index;
        }
    }

    for (const auto &slot : _slots) {
        if (!slot.active || !slot.lastValueValid) continue;
        uint64_t currentValue = 0;
        if (readSlotValueLocked(slot, currentValue) &&
            currentValue != slot.lastValue) {
            return slot.index;
        }
    }

    uint32_t activeSlot = MAX_SLOTS;
    uint32_t activeCount = 0;
    for (const auto &slot : _slots) {
        if (!slot.active) continue;
        activeSlot = slot.index;
        activeCount++;
    }
    return activeCount == 1 ? activeSlot : MAX_SLOTS;
}

#pragma mark - Cross-Process Helpers

bool DebugCore::readRemote(uint64_t address, void *buffer, size_t size) {
    if (_task == MACH_PORT_NULL) return false;
    mach_vm_size_t readSize = 0;
    kern_return_t kr = mach_vm_read_overwrite(
        _task, address, size, (mach_vm_address_t)buffer, &readSize);
    return (kr == KERN_SUCCESS && readSize == size);
}

void DebugCore::refreshRemoteModules() {
    std::lock_guard<std::mutex> lock(_moduleMutex);
    _remoteModules.clear();

    auto modules = VMCore::SystemCore::getInstance().getRemoteModules(_task);
    for (auto &m : modules) {
        RemoteModule rm;
        rm.loadAddress = m.loadAddress;
        rm.size = m.size;
        rm.name = m.name;
        _remoteModules.push_back(rm);
    }
}

StackFrame DebugCore::symbolicateRemote(uint64_t pc) {
    StackFrame frame{};
    frame.pc = pc;
    frame.imageName = "???";
    frame.offset = pc;

    {
        std::lock_guard<std::mutex> lock(_moduleMutex);
        for (auto &m : _remoteModules) {
            if (pc >= m.loadAddress && pc < m.loadAddress + m.size) {
                frame.imageName = m.name;
                frame.imageBase = m.loadAddress;
                frame.offset = pc - m.loadAddress;
                return frame;
            }
        }
    }

    if (_task != MACH_PORT_NULL) {
        refreshRemoteModules();
        std::lock_guard<std::mutex> lock(_moduleMutex);
        for (auto &m : _remoteModules) {
            if (pc >= m.loadAddress && pc < m.loadAddress + m.size) {
                frame.imageName = m.name;
                frame.imageBase = m.loadAddress;
                frame.offset = pc - m.loadAddress;
                return frame;
            }
        }
    }

    return frame;
}

} 
