# ADR-0001: Save System Architecture

## Status
Accepted

## Context
Save system must persist all game state (gold, materials, equipment, dungeon progress) across sessions. Target platform is mobile (iOS/Android) with Godot 4.6. Key constraints:
- Offline yield requires accurate time tracking
- Mobile users may modify system time (cheating detection needed)
- Godot 4.4 changed FileAccess.open() return type (HIGH risk)
- Must handle save corruption gracefully

## Decision

### Save Format
- **JSON** for all persisted data
- Human-readable for debugging, forward-compatible for migration
- Structure: `{version, timestamp, time, gold, materials, equipment, dungeon, enemies}`

### Atomic Write Pattern
1. Write to temp file: `user://save_temp.json`
2. Verify write success via `FileAccess.get_error() == OK`
3. Rename temp → final: `user://save.json`
4. Calculate SHA-256 checksum → `user://save_checksum.txt`

**Rationale**: Prevents partial writes on crash/power-loss. Mobile OS may kill app mid-save.

### Integrity Validation
- SHA-256 checksum stored separately
- On load: recalculate checksum, compare against stored
- If mismatch: corruption detected → use defaults, log incident

### Time Anomaly Detection
- Dual-source time: `Time.get_ticks_usec()` (monotonic) + `OS.get_system_time_msecs()` (wall clock)
- **Forward jump threshold**: 7 days (MAX_FORWARD_JUMP) → anomaly
- **Backward jump**: any negative duration → anomaly
- **Offline cap**: MAX_ALLOWED_OFFLINE = 86400s (24 hours)
- On anomaly: cap offline yield, log to `_anomaly_log`

### Save Version Migration
- `save_version` field in JSON
- Current version: 1
- Migration strategy: version-specific upgrade functions
- If version > current: warn user, attempt forward-compatible load
- If version < current: run migration chain (v→v+1→...→current)

### FileAccess 4.4 Pattern (HIGH RISK)
```gdscript
# Godot 4.4+ pattern (NOT null check)
var file := FileAccess.open(path, FileAccess.WRITE)
if file.get_error() != OK:
    push_error("Save write failed: " + str(file.get_error()))
    return false
file.store_string(json_data)
file.close()
```

**Why NOT null check**: Godot 4.4 returns FileAccess object even on failure. Check `get_error()` instead.

## Consequences

### Positive
- Atomic write prevents corruption
- SHA-256 detects tampering/corruption
- Time anomaly detection caps excessive offline rewards
- Migration path supports future schema changes

### Negative
- JSON is larger than binary (trade-off: debuggability)
- Dual-time comparison adds complexity
- Cheating detection is heuristic (determined players can bypass)

### Risks
- **FileAccess 4.4**: Verified against breaking-changes.md, pattern documented
- **Mobile file system**: `user://` path is Godot-managed, platform-safe

## ADR Dependencies
- None (Foundation layer)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| Core (FileAccess) | Godot 4.4+ | HIGH | ✅ breaking-changes.md |
| Time API | Godot 4.x | LOW | ✅ stable |
| SHA256Context | Godot 4.x | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-save-001 | JSON serialization format | JSON format with version field |
| TR-save-002 | Atomic write pattern | Temp file → verify → rename |
| TR-save-003 | SHA-256 checksum integrity | Separate checksum file, validate on load |
| TR-save-004 | Time anomaly detection | Dual-source, thresholds, logging |
| TR-save-005 | Save version migration | Version field, migration chain |
| TR-fileaccess-001 | FileAccess error handling (4.4) | get_error() pattern, NOT null check |