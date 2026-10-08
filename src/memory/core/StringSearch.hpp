#ifndef VM_STRING_SEARCH_HPP
#define VM_STRING_SEARCH_HPP

#include "MemoryTypes.hpp"
#include "UnicodeCaseFoldData.hpp"
#include <algorithm>
#include <array>
#include <cstring>
#include <limits>

namespace VMCore {
namespace StringSearchDetail {

// Strict decoding excludes overlong UTF-8, surrogate scalars and partial units.
inline bool decodeScalar(const uint8_t *bytes, size_t length,
                         StringEncoding encoding, uint32_t &scalar,
                         size_t &consumed) {
  consumed = 0;
  if (!length) return false;
  if (encoding != StringEncoding::UTF8) {
    if (length < 2) return false;
    const bool little = encoding == StringEncoding::UTF16LE;
    auto unit = [little](const uint8_t *p) -> uint32_t {
      return little ? (uint32_t)p[0] | ((uint32_t)p[1] << 8)
                    : ((uint32_t)p[0] << 8) | (uint32_t)p[1];
    };
    const uint32_t first = unit(bytes);
    if (first >= 0xD800 && first <= 0xDBFF) {
      if (length < 4) return false;
      const uint32_t second = unit(bytes + 2);
      if (second < 0xDC00 || second > 0xDFFF) return false;
      scalar = 0x10000 + ((first - 0xD800) << 10) + second - 0xDC00;
      consumed = 4;
    } else {
      if (first >= 0xDC00 && first <= 0xDFFF) return false;
      scalar = first;
      consumed = 2;
    }
    return true;
  }
  const uint8_t first = bytes[0];
  if (first < 0x80) { scalar = first; consumed = 1; return true; }
  const size_t count = first >= 0xC2 && first <= 0xDF ? 2 :
                       first >= 0xE0 && first <= 0xEF ? 3 :
                       first >= 0xF0 && first <= 0xF4 ? 4 : 0;
  if (!count || length < count) return false;
  scalar = first & ((1U << (7 - count)) - 1);
  for (size_t index = 1; index < count; ++index) {
    if ((bytes[index] & 0xC0) != 0x80) return false;
    scalar = (scalar << 6) | (bytes[index] & 0x3F);
  }
  const uint32_t minimum = count == 2 ? 0x80 : count == 3 ? 0x800 : 0x10000;
  if (scalar < minimum || scalar > 0x10FFFF ||
      (scalar >= 0xD800 && scalar <= 0xDFFF)) return false;
  consumed = count;
  return true;
}

inline std::array<uint32_t, 3> foldScalar(uint32_t scalar) {
  if (scalar < 128)
    return {{scalar >= 'A' && scalar <= 'Z' ? scalar + 32 : scalar, 0, 0}};
  const auto *end = caseFoldTable + sizeof(caseFoldTable) / sizeof(caseFoldTable[0]);
  const auto *entry = std::lower_bound(caseFoldTable, end, scalar,
      [](const CaseFoldEntry &item, uint32_t value) { return item.scalar < value; });
  if (entry == end || entry->scalar != scalar) return {{scalar, 0, 0}};
  return {{entry->folded[0], entry->folded[1], entry->folded[2]}};
}

} // namespace StringSearchDetail

inline size_t validStringPrefixLength(const uint8_t *bytes, size_t length,
                                     StringEncoding encoding,
                                     bool stopAtNUL = true) {
  if (static_cast<uint8_t>(encoding) > 2) return 0;
  size_t offset = 0;
  while (offset < length) {
    uint32_t scalar;
    size_t consumed;
    if (!StringSearchDetail::decodeScalar(bytes + offset, length - offset,
                                          encoding, scalar, consumed) ||
        (stopAtNUL && scalar == 0)) break;
    offset += consumed;
  }
  return offset;
}

// Immutable per-search pattern. Case folding is Unicode 16.0 default full folding;
// normalization, diacritic removal and locale-specific Turkic folding are separate
// operations and intentionally do not participate in a memory substring search.
class StringSearchPattern {
public:
  StringSearchPattern(const std::string &utf8, StringSearchOptions options)
      : _options(options) {
    if (utf8.empty() || static_cast<uint8_t>(options.encoding) > 2) return;
    const auto *input = reinterpret_cast<const uint8_t *>(utf8.data());
    for (size_t offset = 0; offset < utf8.size();) {
      uint32_t scalar;
      size_t consumed;
      if (!StringSearchDetail::decodeScalar(input + offset, utf8.size() - offset,
                                            StringEncoding::UTF8, scalar, consumed))
        return;
      if (options.encoding == StringEncoding::UTF8) {
        _bytes.insert(_bytes.end(), input + offset, input + offset + consumed);
      } else {
        auto appendUnit = [&](uint16_t unit) {
          if (options.encoding == StringEncoding::UTF16LE) {
            _bytes.push_back(static_cast<uint8_t>(unit));
            _bytes.push_back(static_cast<uint8_t>(unit >> 8));
          } else {
            _bytes.push_back(static_cast<uint8_t>(unit >> 8));
            _bytes.push_back(static_cast<uint8_t>(unit));
          }
        };
        if (scalar <= 0xFFFF) appendUnit(static_cast<uint16_t>(scalar));
        else {
          appendUnit(static_cast<uint16_t>(0xD800 + ((scalar - 0x10000) >> 10)));
          appendUnit(static_cast<uint16_t>(0xDC00 + ((scalar - 0x10000) & 0x3FF)));
        }
      }
      if (!options.caseSensitive) {
        const auto folded = StringSearchDetail::foldScalar(scalar);
        _folded.push_back(folded[0]);
        if (folded[1]) _folded.push_back(folded[1]);
        if (folded[2]) _folded.push_back(folded[2]);
      }
      offset += consumed;
    }
    if (_folded.size() > std::numeric_limits<size_t>::max() / 4) return;
    _maxBytes = options.caseSensitive ? _bytes.size() : _folded.size() * 4;
    _valid = _maxBytes > 0 &&
             _maxBytes <= std::numeric_limits<size_t>::max() - 1024 * 1024;
    if (_valid && options.caseSensitive) {
      // Pick an uncommon query byte for the vectorized prefilter. UTF-16's zero
      // high bytes and long repeated prefixes otherwise cause avoidable compares.
      std::array<size_t, 256> counts{};
      for (uint8_t byte : _bytes) ++counts[byte];
      size_t frequency = std::numeric_limits<size_t>::max();
      for (size_t index = 0; index < _bytes.size(); ++index) {
        const uint8_t byte = _bytes[index];
        if (byte != 0 && counts[byte] <= frequency) {
          _anchor = index;
          frequency = counts[byte];
        }
      }
    }
  }

  bool valid() const { return _valid; }
  size_t maxByteLength() const { return _maxBytes; }
  size_t minByteLength() const {
    if (!_valid) return 0;
    return _options.caseSensitive ? _bytes.size() :
           _options.encoding == StringEncoding::UTF8 ? 1 : 2;
  }
  bool caseSensitive() const { return _options.caseSensitive; }
  size_t anchorOffset() const { return _anchor; }
  uint8_t anchorByte() const { return _bytes.empty() ? 0 : _bytes[_anchor]; }

  // A successful result is anchored at bytes[0] and includes whole input scalars.
  size_t match(const uint8_t *bytes, size_t available) const {
    if (!_valid) return 0;
    if (_options.caseSensitive)
      return available >= _bytes.size() &&
                     std::memcmp(bytes, _bytes.data(), _bytes.size()) == 0
                 ? _bytes.size() : 0;
    size_t offset = 0, target = 0;
    while (target < _folded.size()) {
      uint32_t scalar;
      size_t consumed;
      if (!StringSearchDetail::decodeScalar(bytes + offset, available - offset,
                                            _options.encoding, scalar, consumed))
        return 0;
      const auto folded = StringSearchDetail::foldScalar(scalar);
      const size_t count = folded[2] ? 3 : folded[1] ? 2 : 1;
      if (count > _folded.size() - target) return 0;
      for (size_t index = 0; index < count; ++index)
        if (folded[index] != _folded[target++]) return 0;
      offset += consumed;
    }
    return offset;
  }

private:
  StringSearchOptions _options;
  std::vector<uint8_t> _bytes;
  std::vector<uint32_t> _folded;
  size_t _maxBytes = 0;
  size_t _anchor = 0;
  bool _valid = false;
};
} // namespace VMCore
#endif
