# 存档系统 (Save System)

> **Status**: Approved
> **Author**: user + agents
> **Last Updated**: 2026-04-30
> **Approved**: 2026-04-30 (Solo mode — no design-review)
> **Implements Pillar**: 稳定成长 + 掌控节奏

## Overview

存档系统是游戏的持久化基础设施层，负责将所有玩家进度数据持久化到本地存储。它为依赖系统（物品数据库、时间追踪系统、离线收益系统等）提供统一的存取接口，确保玩家离开游戏后进度不会丢失。

从玩家视角，存档系统是"不可见但不可或缺"的底层支撑。玩家不会直接与存档系统交互，但每次打开游戏时看到的装备、金币、地牢进度、离线收益，都依赖存档系统的正确运作。存档系统的失败会导致支柱"稳定成长"崩溃 — 玩家进度丢失意味着所有努力付诸东流。

该系统存储的数据包括：
- 玩家装备状态（已获得装备、已强化等级、装备槽配置）
- 货币数据（金币数量）
- 材料数据（材料类型和数量）
- 地牢进度（当前层级、已解锁层级）
- 时间数据（上次离开时间，用于离线收益计算）

存档系统使用 Godot 的 `user://` 目录作为存储位置，采用 JSON 格式序列化数据，适配移动端iOS/Android平台。

## Player Fantasy

存档系统是纯基础设施系统，玩家不直接与之交互，因此没有传统意义上的"Player Fantasy"。

然而，存档系统支撑的**隐性玩家体验**是：

> **"我的进步永远属于我"** — 每次离开游戏，玩家安心知道进度已保存；每次回来，玩家看到的是完整的装备、金币、进度状态，而不是空白。这种感觉支撑支柱"稳定成长"的核心承诺。

存档系统的失败会破坏这种隐性体验：如果存档损坏或丢失，玩家会感到"一切努力白费"，这违反了游戏"无失败风险"的设计原则。因此，存档系统虽然是不可见的，但其可靠性直接决定玩家对游戏的信任。

**参考**: 梦幻西游手游 — 离线挂机后回来，进度完整呈现，玩家感到"我的角色一直在这里等我"。

## Detailed Design

### Core Rules

#### Rule 1: Save Timing — Event-Triggered with Periodic Backup

**Rule**: The save system writes to disk at three types of triggers:

| Trigger Type | Events | Priority |
|--------------|--------|----------|
| **Critical** | Currency change, equipment acquisition, equipment enhancement, dungeon floor unlock | Immediate |
| **Periodic** | Every 60 seconds of gameplay | Background |
| **Lifecycle** | App pause, app focus loss (mobile lifecycle signals) | Immediate |

**Specifics**:
- Critical events MUST trigger a save within 100ms of the event completing
- Periodic saves run on a timer, not tied to game events
- Lifecycle saves use Godot's `NOTIFICATION_WM_GO_BACK_REQUEST` and `NOTIFICATION_APPLICATION_PAUSED`
- Mobile OS can kill the app without warning — periodic saves mitigate data loss

**Testability**:
- Unit test: Acquire currency → verify save file timestamp updated within 100ms
- Unit test: Simulate 60 seconds of gameplay → verify save occurred
- Integration test: Send app to background on mobile → verify save file updated

---

#### Rule 2: Data Structure — Dual File with Checksum

**Rule**: Save data is stored in exactly two files in `user://`:

```
user://save/
├── current.json      # Active save file
└── backup.json       # Previous valid save (rotated on each successful save)
```

**File Format**:
```json
{
  "version": 1,
  "checksum": "sha256_hash_of_data",
  "timestamp": 1714483200,
  "data": {
    "player": { ... },
    "equipment": { ... },
    "currency": { ... },
    "dungeon": { ... }
  }
}
```

**Specifics**:
- `version`: Schema version integer, starts at 1
- `checksum`: SHA-256 hash of the JSON string of the `data` object only
- `timestamp`: Unix epoch seconds (UTC) at save time
- `data`: All game state nested under this key
- Backup file is rotated: before writing to `current.json`, copy existing `current.json` to `backup.json`
- If `current.json` fails checksum validation on load, attempt restore from `backup.json`

**Testability**:
- Unit test: Save game → verify both files exist and `backup.json` matches previous `current.json`
- Unit test: Corrupt `current.json` → verify system restores from `backup.json`
- Unit test: Modify any byte in `data` → verify checksum fails validation

---

#### Rule 3: Atomic Write Pattern

**Rule**: Save writes MUST use atomic write-and-rename to prevent corruption from interrupted writes.

**Write Sequence**:
1. Serialize data to JSON in memory
2. Calculate checksum and build full save object
3. Write to temporary file: `user://save/temp_[random_id].json`
4. Flush and sync file to disk (`file.flush()`)
5. Rename temp file to target (`current.json` or `backup.json`)
6. Delete temp file if rename fails

**Specifics**:
- Godot's `FileAccess.open()` with `FileAccess.WRITE` followed by `flush()` ensures disk sync
- Rename is atomic on most file systems; if interrupted, either old or new file exists, never partial
- If app crashes during write, temp file is orphaned but main files remain intact
- On next load, orphan temp files are cleaned up

**Testability**:
- Unit test: Simulate crash mid-write (kill process) → verify `current.json` is either old or new, never partial
- Unit test: Verify no temp files remain after successful save
- Unit test: Introduce orphan temp file → verify cleanup on next load

---

#### Rule 4: Load Sequence — Validation and Recovery

**Rule**: On load, the system MUST validate data integrity before returning any state to the game.

**Load Sequence**:
1. Check if `user://save/current.json` exists
   - If no: Create new save with defaults → proceed to step 6
   - If yes: Proceed to step 2
2. Read and parse `current.json`
   - If parse fails (invalid JSON): Mark as corrupted, proceed to step 5
3. Validate checksum
   - Calculate SHA-256 of `data` object
   - Compare to stored `checksum`
   - If mismatch: Mark as corrupted, proceed to step 5
4. Validate schema version
   - If version > current code version: Log error, load with defaults (forward compatibility not required for MVP)
   - If version < current code version: Run migration (Rule 6), then proceed to step 6
5. If corrupted, attempt restore from `backup.json`
   - Repeat steps 2-4 on backup file
   - If backup also corrupted: Create new save with defaults, log data loss event
6. Return validated data to game systems

**Testability**:
- Unit test: No save files → verify returns new game state
- Unit test: Valid save → verify returns correct data
- Unit test: Corrupt `current.json` checksum → verify restore from backup
- Unit test: Corrupt both files → verify returns new game state
- Unit test: Version mismatch → verify migration runs or defaults load

---

#### Rule 5: Time Integrity — Multi-Source Validation

**Rule**: The save system MUST detect and mitigate system time manipulation for offline reward calculation.

**Time Sources Tracked**:

| Source | Field | Purpose |
|--------|-------|---------|
| `system_time` | Unix timestamp from `Time.get_unix_time_from_system()` | Primary time reference |
| `monotonic_time` | Ticks from `Time.get_ticks_msec()` | Session-relative, immune to system clock changes |
| `accumulated_playtime` | Total playtime in seconds | Cross-session consistency check |

**Data Structure**:
```json
{
  "time_tracking": {
    "last_save_system_time": 1714483200,
    "last_save_monotonic_offset": 3600000,
    "accumulated_playtime_seconds": 86400,
    "anomaly_count": 0,
    "last_anomaly_timestamp": null
  }
}
```

**Anomaly Detection Rules**:

| Anomaly Type | Detection | Mitigation |
|--------------|-----------|-------------|
| **Time went backward** | `current_system_time < last_save_system_time` | Cap offline duration to 0, log anomaly, increment `anomaly_count` |
| **Time jumped forward > 7 days** | `current_system_time - last_save_system_time > 604800` | Cap offline duration to 7 days max, log anomaly |
| **Playtime inconsistency** | `accumulated_playtime` doesn't match session duration | Reset playtime to 0, log anomaly |

**Specifics**:
- `last_save_monotonic_offset`: Monotonic time at last save, used to detect in-session time changes
- During a session, if system time changes but monotonic time is continuous, flag as suspicious
- `anomaly_count`: Tracked but not acted upon for MVP (future: could reduce rewards)
- Offline duration for reward calculation: `min(current_system_time - last_save_system_time, 604800, MAX_ALLOWED_OFFLINE)`
- MAX_ALLOWED_OFFLINE is a tuning knob (default: 24 hours for MVP)

**Testability**:
- Unit test: Set system time backward by 1 hour → verify offline duration capped to 0
- Unit test: Set system time forward by 10 days → verify offline duration capped to 7 days
- Unit test: Normal save/load → verify `accumulated_playtime` increments correctly
- Unit test: Modify `accumulated_playtime` to invalid value → verify reset to 0

---

#### Rule 6: Version Migration — Schema Evolution

**Rule**: When save file version is lower than current code version, run migration pipeline before returning data.

**Migration Architecture**:
```gdscript
# Pseudocode structure
func migrate_save_data(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
    var current = from_version
    while current < to_version:
        data = call("migrate_%d_to_%d" % [current, current + 1], data)
        current += 1
    data["version"] = to_version
    return data
```

**Migration Rules**:
1. Each version bump has exactly one migration function: `migrate_X_to_Y(data) -> Dictionary`
2. Migration functions are pure: take old data, return new data
3. Missing fields get default values
4. Removed fields are silently dropped
5. Migration failures log error and return defaults (data loss preferred over crash)

**MVP Migration List**:
- Version 1 → 2: [Placeholder for future schema changes]

**Specifics**:
- Migration runs during load, before data validation
- After migration, checksum is recalculated
- Migration is one-way: no backward migration
- Version 0 is reserved for "new game" state (no migration needed)

**Testability**:
- Unit test: Load version 1 save with version 2 code → verify migration runs, version updated
- Unit test: Migration adds new field → verify default value applied
- Unit test: Migration removes old field → verify field absent after migration
- Unit test: Migration function throws error → verify defaults returned, no crash

---

#### Rule 7: Default State — New Game Initialization

**Rule**: When no valid save exists, the system MUST create a deterministic default state.

**Default Values**:

| Field | Default Value | Rationale |
|-------|--------------|-----------|
| `player.level` | 1 | Starting level |
| `currency.gold` | 0 | No starting currency (design decision) |
| `equipment.slots` | `{}` (empty) | No starting equipment |
| `equipment.inventory` | `[]` (empty) | No starting inventory |
| `materials` | `{}` (empty) | No starting materials |
| `dungeon.current_floor` | 1 | Start at floor 1 |
| `dungeon.highest_floor` | 1 | Start at floor 1 |
| `dungeon.unlocked_floors` | `[1]` | Only floor 1 unlocked |
| `time_tracking.accumulated_playtime_seconds` | 0 | New player |
| `version` | `CURRENT_SAVE_VERSION` | Matches code version |

**Specifics**:
- Default state is created in code, not read from a file
- After creating defaults, immediately save to `current.json` (no backup needed on first save)
- This ensures a clean state exists before any gameplay begins

**Testability**:
- Unit test: New game → verify all defaults applied correctly
- Unit test: New game → verify `current.json` created with correct version

---

#### Rule 8: Data Scope — What Is and Is Not Saved

**Rule**: Only persistent progress is saved. Ephemeral state is NOT saved.

**Saved Data**:

| Category | Fields | Notes |
|----------|--------|-------|
| **Player** | `level` | Player progression |
| **Currency** | `gold` | Primary currency |
| **Equipment** | `slots`, `inventory`, `enhancement_levels` | Equipment state |
| **Materials** | All material types and counts | For enhancement |
| **Dungeon** | `current_floor`, `highest_floor`, `unlocked_floors` | Dungeon progress |
| **Time** | Time tracking fields (Rule 5) | For offline rewards |
| **Settings** | Audio volume, language | Player preferences |

**NOT Saved** (Ephemeral):

| Category | Fields | Rationale |
|----------|--------|-----------|
| **Combat** | Current battle state, enemy HP | Recreated on load |
| **UI** | Menu state, scroll position | Recreated on load |
| **Particles** | Active effects | Recreated on load |
| **Session** | Time since last periodic save | Not meaningful across sessions |

**Specifics**:
- On load, game systems receive only persistent data
- UI and combat systems initialize to default states
- This reduces save file size and complexity

**Testability**:
- Unit test: Save during combat → verify enemy HP not in save file
- Unit test: Save with menu open → verify menu state not in save file
- Unit test: Load game → verify combat state is default (no active battle)

---

#### Rule 9: Save System Interface — Public API

**Rule**: Other systems interact with save system only through defined interface.

**Public Methods**:

```gdscript
# SaveManager.gd (singleton)
class_name SaveManager

# Signals
signal save_completed(success: bool)
signal save_failed(error_code: int)
signal load_completed(data: Dictionary)
signal load_failed(error_code: int)

# Methods
func save_game(trigger: String = "manual") -> void
func load_game() -> Dictionary
func get_save_info() -> Dictionary  # Returns {exists: bool, version: int, timestamp: int}
func delete_save() -> bool
func export_save() -> String  # Returns JSON string for backup
func import_save(json_string: String) -> bool
```

**Error Codes**:

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | File not found |
| 2 | Parse error (invalid JSON) |
| 3 | Checksum mismatch |
| 4 | Version migration failed |
| 5 | Write permission denied |
| 6 | Disk full |

**Specifics**:
- SaveManager is an autoload singleton
- Other systems never access `user://save/` directly
- `save_game(trigger)` accepts trigger type for logging: "critical", "periodic", "lifecycle", "manual"
- `export_save()` and `import_save()` support future cloud backup feature

**Testability**:
- Unit test: Call `save_game("critical")` → verify file written
- Unit test: Call `load_game()` after save → verify data matches
- Unit test: Call `get_save_info()` with no save → verify {exists: false}
- Unit test: Call `export_save()` → verify valid JSON string

---

### States and Transitions

The SaveManager operates in a simple state machine:

```
 ┌─────────┐     load_game()     ┌──────────┐
 │  Idle   │ ──────────────────► │  Loading │
 │         │                     │          │
 └─────────┘                     └──────────┘
     ▲   │                           │
     │   │ save_game()               │ success/failure
     │   ▼                           ▼
 ┌─────────┐                     ┌──────────┐
 │ Saving  │                     │  Ready   │
 │         │ ──────────────────► │          │
 └─────────┘   async complete    └──────────┘
                                     │
                                     │ get_save_info(), delete_save()
                                     ▼
                                 ┌──────────┐
                                 │  Error   │
                                 │          │
                                 └──────────┘
```

**States**:

| State | Description | Allowed Operations |
|-------|-------------|-------------------|
| **Idle** | Initial state, no save file loaded | `load_game()` |
| **Loading** | Reading and validating save file | None (blocking) |
| **Ready** | Save file loaded, data available | `save_game()`, `get_save_info()`, `delete_save()`, `export_save()` |
| **Saving** | Writing save file (async) | None (blocking) |
| **Error** | Critical error occurred | `load_game()` (retry), `delete_save()` (reset) |

**Transitions**:

| From | To | Trigger | Notes |
|------|----|---------|-------|
| Idle | Loading | `load_game()` called | Blocks until complete |
| Loading | Ready | Validation successful | Data returned to caller |
| Loading | Error | Both files corrupted | New game state created |
| Ready | Saving | `save_game()` called | Async write operation |
| Saving | Ready | Write successful | `save_completed` signal |
| Saving | Error | Write failed | `save_failed` signal |
| Error | Loading | `load_game()` retry | Attempt recovery |
| Error | Idle | `delete_save()` | Reset to fresh state |

---

### Interactions with Other Systems

| System | Interaction | Direction | Notes |
|--------|-------------|-----------|-------|
| **物品数据库** | Save/load equipment IDs and enhancement levels | Bidirectional | SaveManager stores IDs; ItemDatabase resolves to item definitions |
| **货币系统** | Save/load gold amount | Bidirectional | CurrencySystem notifies SaveManager on change |
| **材料系统** | Save/load material counts | Bidirectional | MaterialSystem notifies SaveManager on change |
| **地牢结构系统** | Save/load floor progress | Bidirectional | DungeonSystem notifies SaveManager on floor unlock |
| **时间追踪系统** | Provides time integrity data | Bidirectional | TimeTrackingSystem reads/writes time_tracking fields |
| **离线收益系统** | Reads last_save timestamp for calculation | Inbound | Uses time_tracking data to calculate offline rewards |
| **装备槽系统** | Save/load slot assignments | Bidirectional | EquipmentSlotSystem notifies SaveManager on slot change |
| **UI系统** | Displays save status (saving indicator) | Inbound | Receives `save_completed` and `save_failed` signals |

**Notification Pattern**:

Dependent systems do NOT call `save_game()` on every change. Instead:

1. System changes state (e.g., CurrencySystem adds gold)
2. System emits signal: `currency_changed(amount)`
3. SaveManager listens to all change signals
4. SaveManager queues save operation based on trigger type:
   - Critical signals → immediate save
   - Other signals → batched for periodic save

**Signal List**:

```gdscript
# Signals that trigger saves
signal currency_changed(new_amount: int)         # Critical
signal equipment_acquired(item_id: String)       # Critical
signal equipment_enhanced(item_id: String, level: int)  # Critical
signal floor_unlocked(floor: int)                # Critical
signal material_changed(type: String, amount: int)      # Periodic (batched)
```

---

## Formulas

### Checksum Calculation

```
checksum = SHA256(JSON.stringify(data))
```

- Only the `data` object is hashed
- `version`, `checksum`, `timestamp` fields are excluded
- JSON stringification uses deterministic ordering (sorted keys)

### Offline Duration Calculation

```
raw_offline_duration = current_system_time - last_save_system_time

# Anomaly detection
if raw_offline_duration < 0:
    offline_duration = 0  # Time went backward
    anomaly_logged = true
elif raw_offline_duration > MAX_OFFLINE_CAP:
    offline_duration = MAX_OFFLINE_CAP  # Time jumped too far
    anomaly_logged = true
else:
    offline_duration = raw_offline_duration
    anomaly_logged = false
```

Variables:
- `MAX_OFFLINE_CAP`: Tuning knob, default 86400 seconds (24 hours)
- `current_system_time`: From `Time.get_unix_time_from_system()`
- `last_save_system_time`: From save file

### Playtime Accumulation

```
session_start_monotonic = Time.get_ticks_msec() at load time
session_duration = (current_monotonic - session_start_monotonic) / 1000

accumulated_playtime_seconds = saved_accumulated_playtime + session_duration
```

---

## Edge Cases

### Edge Case 1: App Killed During Save Write

**Scenario**: Mobile OS kills app while write is in progress.

**Expected Behavior**:
- If killed before temp file rename: `current.json` remains intact (old state)
- If killed after rename but before backup rotation: `current.json` is new state, `backup.json` may be old or missing
- Either way, at least one valid file exists on next load

**Test**: Kill process mid-save → load game → verify state is either pre-save or post-save, never corrupted.

---

### Edge Case 2: Disk Full During Save

**Scenario**: Device storage is exhausted during write.

**Expected Behavior**:
- Temp file write fails
- Error code 6 (Disk full) emitted
- `current.json` remains unchanged
- Game continues with in-memory state (unsaved)
- User sees "Save failed - storage full" notification

**Test**: Simulate disk full condition → verify error code and notification.

---

### Edge Case 3: Player Modifies Save File Manually

**Scenario**: Player edits `current.json` with external tool to gain advantage.

**Expected Behavior**:
- If checksum modified but data unchanged: checksum mismatch → restore from backup
- If data modified: checksum mismatch → restore from backup
- If both modified correctly (checksum matches new data): load succeeds (unavoidable for offline MVP)
- Note: For MVP, we do not encrypt saves; server validation is deferred to future version

**Test**: Modify data and recalculate checksum → verify load succeeds (known limitation).

---

### Edge Case 4: Both Save Files Corrupted

**Scenario**: `current.json` and `backup.json` both have checksum mismatches.

**Expected Behavior**:
- Log data loss event with timestamp
- Create new game with defaults
- Emit `load_failed(3)` signal
- UI shows "Save corrupted - new game created" message
- Player loses all progress (unavoidable)

**Test**: Corrupt both files → verify defaults loaded, error message shown.

---

### Edge Case 5: Time Manipulation During Session

**Scenario**: Player changes system time while game is running.

**Expected Behavior**:
- Monotonic time continues incrementing (immune to clock change)
- System time change detected on next save: compare `current_monotonic - saved_monotonic` vs `current_system - saved_system`
- If delta mismatch > 60 seconds: log anomaly, increment `anomaly_count`
- Do NOT punish player for MVP (just log)

**Test**: Change system clock during gameplay → verify anomaly logged.

---

### Edge Case 6: Very Long Offline Duration

**Scenario**: Player returns after 30 days offline.

**Expected Behavior**:
- Offline duration capped to `MAX_OFFLINE_CAP` (default 24 hours)
- Rewards calculated only for capped duration
- Player receives 24 hours of offline rewards, not 30 days
- Prevents excessive accumulation and encourages regular play

**Test**: Set `last_save_system_time` to 30 days ago → verify offline_duration capped to MAX_OFFLINE_CAP.

---

### Edge Case 7: Version Downgrade (Rollback)

**Scenario**: Player updates game to newer version (v2), saves, then rolls back to older version (v1).

**Expected Behavior**:
- Load detects `version` field = 2, code version = 1
- Version is newer than code → cannot migrate backward
- Log error, load defaults (data loss)
- This is acceptable: rollback is unsupported for MVP

**Test**: Save with v2 code → load with v1 code → verify defaults loaded.

---

## Dependencies

### Depends On (None)

SaveSystem is a foundation system with no upstream dependencies.

### Dependents

| System | Dependency Type | Notes |
|--------|----------------|-------|
| 物品数据库 | Hard | Stores item IDs, relies on ItemDatabase to resolve |
| 时间追踪系统 | Hard | Uses time integrity data from TimeTrackingSystem |
| 货币系统 | Hard | Stores currency, receives change notifications |
| 材料系统 | Hard | Stores materials, receives change notifications |
| 地牢结构系统 | Hard | Stores floor progress, receives change notifications |
| 装备槽系统 | Hard | Stores slot assignments, receives change notifications |
| 离线收益系统 | Hard | Reads time_tracking for offline calculation |

---

## Tuning Knobs

| Knob | Default | Range | Effect |
|------|---------|-------|--------|
| `MAX_OFFLINE_CAP` | 86400 seconds (24 hours) | 3600 - 604800 (1h - 7d) | Maximum offline reward duration |
| `PERIODIC_SAVE_INTERVAL` | 60 seconds | 30 - 120 | Frequency of background saves |
| `ANOMALY_THRESHOLD` | 60 seconds | 30 - 300 | Time delta threshold to flag anomaly |
| `MAX_ANOMALY_COUNT` | 10 | 5 - 50 | Anomaly count before action (future: could warn user) |
| `BACKUP_RETENTION_COUNT` | 1 | 1 - 3 | Number of backup files to keep (MVP: 1) |

**Adjustment Guidelines**:
- Increase `MAX_OFFLINE_CAP` for games that encourage longer breaks
- Decrease `PERIODIC_SAVE_INTERVAL` for more aggressive data safety (more battery use)
- `ANOMALY_THRESHOLD` should be generous to avoid false positives from minor clock drift

---

## Acceptance Criteria

### AC-1: Save Persistence

**Criteria**: Save file survives app restart.

**Test**: 
1. Save game with known state (e.g., 100 gold)
2. Close app completely
3. Relaunch app
4. Verify gold = 100

**Pass**: State matches exactly.
**Fail**: State different or missing.

---

### AC-2: Critical Event Save

**Criteria**: Critical events save immediately.

**Test**:
1. Monitor `current.json` modification timestamp
2. Acquire equipment (critical event)
3. Verify file timestamp updated within 100ms

**Pass**: Timestamp updated within 100ms.
**Fail**: Timestamp unchanged or updated after 100ms.

---

### AC-3: Corruption Recovery

**Criteria**: Single file corruption is recoverable.

**Test**:
1. Save game with known state
2. Corrupt `current.json` (modify one byte in `data`)
3. Load game
4. Verify state restored from `backup.json`

**Pass**: State restored correctly from backup.
**Fail**: State corrupted or defaults loaded.

---

### AC-4: Time Manipulation Detection

**Criteria**: System time backward is detected and mitigated.

**Test**:
1. Save game with `last_save_system_time` = T
2. Set system time to T - 3600 (1 hour backward)
3. Load game, calculate offline duration
4. Verify offline_duration = 0, anomaly logged

**Pass**: Offline duration capped to 0, anomaly recorded.
**Fail**: Offline duration negative or not capped.

---

### AC-5: New Game Default

**Criteria**: New game creates clean default state.

**Test**:
1. Delete all save files
2. Start new game
3. Verify:
   - gold = 0
   - inventory empty
   - current_floor = 1
   - version = CURRENT_SAVE_VERSION

**Pass**: All defaults correct.
**Fail**: Any field incorrect or missing.

---

### AC-6: Version Migration

**Criteria**: Older save files migrate correctly.

**Test**:
1. Create save with `version = 1`, missing new field `new_field`
2. Load with code that expects `version = 2`
3. Verify migration runs, `new_field` has default value

**Pass**: Migration successful, new field present with default.
**Fail**: Save rejected or new field missing.

---

### AC-7: Signal-Based Save Trigger

**Criteria**: Save responds to change signals.

**Test**:
1. Emit `currency_changed(100)` signal
2. Verify save triggered with type = "critical"
3. Verify file timestamp updated

**Pass**: Save triggered immediately.
**Fail**: Save not triggered or delayed.

---

### AC-8: Error Handling

**Criteria**: Load failures return error codes, not crashes.

**Test**:
1. Corrupt both save files
2. Call `load_game()`
3. Verify returns defaults, error code = 3 (checksum mismatch)
4. Verify no crash or exception

**Pass**: Defaults returned, error code correct.
**Fail**: Crash, exception, or wrong error code.

---

## Open Questions

1. **Encryption for save files?**: MVP does not encrypt. Future version could add XOR obfuscation or AES encryption to deter casual tampering. Decision deferred.

2. **Cloud sync?**: MVP is offline-only. Future version could integrate with iCloud/Google Play Games for cloud backup. Architecture must support `export_save()` and `import_save()` for this.

3. **Multiple save slots?**: MVP has single slot. Future version could support multiple profiles. Architecture would need `slot_id` parameter.

4. **Compression?**: JSON files are uncompressed. If save size grows large (unlikely for MVP), could add gzip compression. Monitor save file size during testing.

5. **GDScript vs. FileAccess performance?**: For MVP, JSON + FileAccess is sufficient. If performance issues arise, consider binary serialization (Godot's `var2bytes()`). Measure serialization time for typical save data.