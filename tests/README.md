# String editor checks

Run on macOS with Xcode command-line tools:

```sh
bash tests/run_string_memory_tests.sh
```

The tests use a bounded in-memory fixture, independent of a target process.
They cover UTF-8 byte limits, null termination, exact-length range writes,
address parsing, context paging, stale snapshots, partial failures, readback,
and conflict-checked undo.

## Device checks for 3.4.1

1. Open a known string and confirm that nearby candidate strings show their
   individual addresses. Load earlier/later pages while a draft and caret
   selection are active.
2. Hide/reopen the keyboard. Test portrait, landscape, long strings and a small
   screen. Compact keyboard layouts temporarily collapse the context header.
3. Shorten a null-terminated string, save, and undo. Verify neighboring bytes
   stay unchanged. Unterminated fragments require equal byte counts.
4. Attempt a longer string and confirm saving is disabled. Byte counts use
   UTF-8, including multibyte Chinese characters and emoji.
5. Switch strings with an unsaved draft; exercise cancel, discard, and save.
6. Select an explicit hexadecimal start/end range (end inclusive, max 8192 bytes).
   Range mode displays raw separators/bytes as `\0`, `\n`, `\r`, `\t`,
   `\\`, and `\xNN`. Entering a different byte count must block saving.
   Confirm an equal-length replacement, inspect its preview, save and undo.
7. Change the original bytes externally before saving or undoing; the editor
   should report a conflict. Disconnect/switch the VM target and confirm reads
   and writes fail with an explicit message.

Context is cached in 1 KB pages, capped at 64 KB; selected addresses are kept
independent of row positions. Each editor retains up to 10 original byte
snapshots for undo. Saves compare the source snapshot, write the selected bytes,
and compare the readback. This cannot make live target memory updates atomic
or validate application-specific object invariants.
