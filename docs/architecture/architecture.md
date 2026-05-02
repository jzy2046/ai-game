# 爽刷地牢 (Idle Dungeon Clicker) — Master Architecture

## Document Status
- Version: 1.0
- Last Updated: 2026-05-02
- Engine: Godot 4.6
- GDDs Covered: 24 (23 MVP + 1 Vertical Slice)
- ADRs Referenced: None yet (15 required, see Required ADRs)
- Technical Director Sign-Off: 2026-05-02 — APPROVED (Foundation ADRs required before implementation)
- Lead Programmer Feasibility: Skipped — Solo mode

## Engine Knowledge Gap Summary

Engine: Godot 4.6 (LLM cutoff ~4.3)
Post-Cutoff Versions: 4.4 (MEDIUM), 4.5 (HIGH), 4.6 (HIGH)

### HIGH RISK Domains (verified against engine reference)
- **Core (FileAccess)**: 4.4 changed `FileAccess.open()` return type — now returns `FileAccess`, use `get_error()` for failure (not null check)
- **Rendering (Glow)**: 4.6 glow processes BEFORE tonemapping — particle shaders must adapt

### MEDIUM RISK Domains (verified, stable)
- **Audio**: Stable in 4.4-4.6 — no breaking changes, pooling patterns work
- **Particles**: 4.4 added `.restart(keep_seed)` optional param — update call sites

### LOW RISK Domains (in training data, reliable)
- **UI/Control**: Stable since 4.0
- **Input**: Touch events stable
- **Timer/Process**: Stable

### Systems touching HIGH/MEDIUM risk domains
| System | Domain | Risk | Resolution |
|--------|--------|------|------------|
| save-system | Core (FileAccess) | HIGH | Use `get_error()` pattern, verified in breaking-changes.md |
| particle-system | Rendering | MEDIUM | Account for glow timing change, use `.restart(keep_seed)` |
| audio-system | Audio | MEDIUM → LOW | Verified stable, no changes needed |

### Documentation Gap
⚠️ `docs/engine-reference/godot/modules/core.md` missing — create before implementation.

## System Layer Map

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  POLISH LAYER                                                               │
│  └─ audio-system (Vertical Slice)                                           │
│    • Depends on: combat-system, equipment-enhancement-system                │
│    • Engine: AudioStreamPlayer pool (stable)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  PRESENTATION LAYER                                                         │
│  └─ visual-feedback-system                                                  │
│    • Depends on: particle-system, stat-display-system, vibration-feedback   │
│    • Engine: Node orchestration, signal routing                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                              │
│  ├─ combat-system                                                           │
│  │   • Depends on: enemy-system, item-database                              │
│  │   • Engine: Timer (stable), Node                                         │
│  ├─ drop-table-system                                                       │
│  │   • Depends on: enemy-system, item-database                              │
│  │   • Engine: RandomNumberGenerator                                       │
│  ├─ yield-calculation-system                                                │
│  │   • Depends on: combat-system, time-tracking-system                      │
│  │   • Engine: Pure math, no engine APIs                                    │
│  ├─ dungeon-advancement-system                                              │
│  │   • Depends on: dungeon-structure-system, combat-system, enemy-system    │
│  │   • Engine: Node, Signal                                                 │
│  ├─ equipment-drop-system                                                   │
│  │   • Depends on: combat-system, drop-table-system, item-database          │
│  │   • Engine: Control, Popup                                               │
│  ├─ equipment-enhancement-system                                            │
│  │   • Depends on: equipment-slot-system, material-system, currency-system, │
│  │   │          enhancement-formula-system                                  │
│  │   • Engine: Control, Signal                                              │
│  ├─ offline-yield-system                                                    │
│  │   • Depends on: yield-calculation-system, save-system                    │
│  │   • Engine: Node, Dictionary                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                                 │
│  ├─ item-database                                                           │
│  │   • Depends on: save-system                                              │
│  │   • Engine: Resource, Dictionary                                         │
│  ├─ time-tracking-system                                                    │
│  │   • Depends on: save-system                                              │
│  │   • Engine: Time.get_ticks_usec(), OS.get_system_time_msecs()            │
│  ├─ material-system                                                         │
│  │   • Depends on: save-system, item-database                               │
│  │   • Engine: Dictionary                                                   │
│  ├─ currency-system                                                         │
│  │   • Depends on: save-system                                              │
│  │   • Engine: Dictionary                                                   │
│  ├─ dungeon-structure-system                                                │
│  │   • Depends on: save-system                                              │
│  │   • Engine: Dictionary                                                   │
│  ├─ enemy-system                                                            │
│  │   • Depends on: item-database                                            │
│  │   • Engine: Node, AnimationPlayer, Timer                                 │
│  ├─ equipment-slot-system                                                   │
│  │   • Depends on: item-database, save-system                               │
│  │   • Engine: Dictionary                                                   │
│  ├─ enhancement-formula-system                                              │
│  │   • Depends on: item-database                                            │
│  │   • Engine: Pure math, no engine APIs                                    │
│  ├─ stat-display-system                                                     │
│  │   • Depends on: item-database, currency-system                           │
│  │   • Engine: RichTextLabel, Label                                         │
│  ├─ touch-input-system                                                      │
│  │   • Depends on: ui-layout-system                                         │
│  │   • Engine: InputEvent, Control (stable)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                                           │
│  ├─ save-system                                                             │
│  │   • Depends on: none                                                     │
│  │   • Engine: FileAccess ⚠️ HIGH RISK, ConfigFile                          │
│  ├─ particle-system                                                         │
│  │   • Depends on: none                                                     │
│  │   • Engine: GPUParticles2D, ProcessMaterial ⚠️ MEDIUM RISK               │
│  ├─ vibration-feedback-system                                               │
│  │   • Depends on: none                                                     │
│  │   • Engine: OS.vibrate() (mobile)                                        │
│  ├─ ui-layout-system                                                        │
│  │   • Depends on: none                                                     │
│  │   • Engine: Control, AnchorPreset (stable)                               │
├─────────────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                                             │
│  └─ Godot 4.6 Engine API Surface                                            │
│  └─ OS/Hardware (iOS, Android)                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Module Boundary Definitions

| Module | Class Name | Owns | Exposes | Engine APIs |
|--------|-----------|------|---------|-------------|
| **save-system** | `SaveManager` | Save data JSON, checksum, migration state | `load_save()`, `save_game(data)`, `get_checksum()` | FileAccess ⚠️, ConfigFile |
| **particle-system** | `ParticlePool` | GPUParticles2D pool, presets, tier configs | `spawn_preset(name, pos, tier)`, `clear_all()` | GPUParticles2D ⚠️, ProcessMaterial |
| **vibration-feedback-system** | `VibrationController` | Vibration pattern definitions, platform caps | `vibrate(pattern_name, tier)` | OS.vibrate() |
| **ui-layout-system** | `UILayoutManager` | Anchor presets, safe area margins | `apply_anchor(node, preset)`, `get_safe_area()` | Control |
| **item-database** | `ItemRegistry` | Equipment definitions, material definitions | `get_item(id)`, `get_rarity_stats(rarity)` | Resource |
| **time-tracking-system** | `TimeTracker` | Session timestamps, offline duration calc | `get_session_duration()`, `detect_anomaly()` | Time, OS |
| **material-system** | `MaterialInventory` | Material stacks, overflow policy | `add_material(id, count)`, `can_remove_bulk()` | — |
| **currency-system** | `GoldVault` | Gold amount, overflow policy | `get_gold()`, `add_gold(amount)` | — |
| **dungeon-structure-system** | `DungeonProgress` | Current floor, checkpoint, unlocked floors | `get_current_floor()`, `advance_floor()` | — |
| **enemy-system** | `EnemyController` | Enemy instances, state machine, spawn params | `spawn_enemy(floor)`, `get_state()` | Node, AnimationPlayer |
| **equipment-slot-system** | `EquipmentManager` | 6-slot equipment, slot compatibility | `equip(slot, item)`, `get_total_stats()` | — |
| **enhancement-formula-system** | `EnhancementCalculator` | Cost formulas, material formulas | `calc_cost(level)`, `calc_materials(level)` | — (pure math) |
| **stat-display-system** | `StatHUD` | HUD labels, comparison display | `update_stats(stats)`, `show_comparison()` | RichTextLabel, Label |
| **touch-input-system** | `TouchRouter` | Gesture detection, layer routing, modal state | `get_active_layer()`, `is_modal_active()` | InputEvent, Control |
| **combat-system** | `CombatEngine` | Battle loop, damage calc, skip state | `start_battle(enemy)`, `skip_battle()` | Timer |
| **drop-table-system** | `DropGenerator` | Drop tables, RNG selection | `generate_drops(enemy_id, floor)` | RandomNumberGenerator |
| **yield-calculation-system** | `YieldEstimator` | Offline yield formulas | `estimate_yield(duration)` | — (pure math) |
| **dungeon-advancement-system** | `DungeonDriver` | Floor progression logic, boss checks | `advance_to_next()`, `is_floor_complete()` | Node, Signal |
| **equipment-drop-system** | `DropHandler` | Post-combat drop UI | `display_drops(drops)`, `collect_selected()` | Control, Popup |
| **equipment-enhancement-system** | `EnhancementWorkflow` | Enhancement UI flow, preview | `start_enhancement(slot)`, `confirm_enhancement()` | Control, Signal |
| **offline-yield-system** | `OfflineReward` | Return reward calculation, claim UI | `calculate_reward()`, `claim_reward()` | Node |
| **visual-feedback-system** | `FeedbackCoordinator` | Multi-system feedback orchestration | `trigger_feedback(event, tier)`, `queue_layered()` | Node, Signal |
| **audio-system** | `AudioPool` | SFX pool, layered audio, bus config | `play_sfx(name)`, `play_layered(base, boss)` | AudioStreamPlayer |

## Module Ownership

### Foundation Layer — Module Ownership

| Module | Owns | Exposes | Consumes | Engine APIs (Verified) |
|--------|------|---------|----------|------------------------|
| **SaveManager** | `save_data: Dictionary`, `checksum: String`, `save_version: int`, `migration_state` | `load_save() → Dictionary`, `save_game(data: Dictionary) → bool`, `get_checksum() → String`, `validate_integrity() → bool` | None (root) | `FileAccess.open()` ⚠️ 4.4 HIGH — use `get_error()`; `FileAccess.store_string()`, `FileAccess.get_as_text()`, `SHA256Context` |
| **ParticlePool** | `_particle_pool: Array[GPUParticles2D]`, `_preset_configs: Dictionary`, `_active_particles: Dictionary` | `spawn_preset(preset: String, pos: Vector2, tier: int) → void`, `clear_all() → void`, `set_layer_delay(preset: String, delay: float) → void` | None (root) | `GPUParticles2D` ⚠️ 4.4 MEDIUM — `.restart(keep_seed: bool)`; `ProcessMaterial`, `CanvasItem.modulate` |
| **VibrationController** | `_vibration_capable: bool`, `_pattern_library: Dictionary`, `_last_vibration_time: float` | `vibrate(pattern_name: String, tier: int) → void`, `is_supported() → bool`, `merge_patterns(patterns: Array) → void` | None (root) | `OS.vibrate(duration_ms: int)` — mobile only; `OS.has_feature("mobile")` |
| **UILayoutManager** | `_anchor_presets: Dictionary`, `_safe_area: Rect2`, `_screen_size: Vector2` | `apply_anchor(node: Control, preset: String) → void`, `get_safe_area() → Rect2`, `get_screen_orientation() → String` | None (root) | `Control.set_anchors_preset()`, `Control.set_grow_direction()`, `DisplayServer.screen_get_size()`, `DisplayServer.get_safe_area()` ✅ Stable |

### Core Layer — Module Ownership

| Module | Owns | Exposes | Consumes | Engine APIs (Verified) |
|--------|------|---------|----------|------------------------|
| **ItemRegistry** | `_equipment_db: Dictionary`, `_material_db: Dictionary`, `_rarity_modifiers: Dictionary` | `get_equipment(id: String) → Dictionary`, `get_material(id: String) → Dictionary`, `get_enhanced_stats(base: Dictionary, level: int) → Dictionary` | SaveManager (for persistence) | `ResourceLoader.load()`, `Resource` ✅ Stable |
| **TimeTracker** | `_session_start: int`, `_last_save_time: int`, `_anomaly_log: Array` | `get_session_duration() → float`, `get_offline_duration() → float`, `detect_anomaly() → bool`, `log_anomaly(type: String) → void` | SaveManager (`_last_save_time`) | `Time.get_ticks_usec()` ✅ Stable; `OS.get_system_time_msecs()` ✅ Stable |
| **MaterialInventory** | `_material_stacks: Dictionary`, `_overflow_log: Array`, `MAX_STACK_CAP: int` | `get_stack(material_id: String) → int`, `add_material(id: String, count: int) → int`, `can_remove_bulk(requirements: Dictionary) → bool`, `remove_bulk(requirements: Dictionary) → bool` | ItemRegistry (`get_material()`), SaveManager (persistence) | None — pure Dictionary |
| **GoldVault** | `_gold_amount: int`, `_overflow_policy: String` | `get_gold() → int`, `add_gold(amount: int) → int`, `can_spend(amount: int) → bool`, `spend(amount: int) → bool` | SaveManager (persistence) | None — pure int |
| **DungeonProgress** | `_current_floor: int`, `_checkpoint_floor: int`, `_unlocked_floors: Array`, `_boss_defeated: Dictionary` | `get_current_floor() → int`, `get_checkpoint() → int`, `advance_floor() → void`, `set_checkpoint(floor: int) → void` | SaveManager (persistence) | None — pure Dictionary |
| **EnemyController** | `_active_enemies: Dictionary`, `_enemy_state: Dictionary`, `_spawn_config: Dictionary` | `spawn_enemy(floor: int) → Dictionary`, `get_enemy_state(enemy_id: String) → int`, `defeat_enemy(enemy_id: String) → void`, `get_rewards(enemy_id: String) → Dictionary` | ItemRegistry (`get_equipment()` for stats), DungeonProgress (`get_current_floor()` for scaling) | `Node`, `AnimationPlayer.play()`, `Timer.start()` ✅ Stable |
| **EquipmentManager** | `_equipped_slots: Dictionary`, `_slot_compatibility: Dictionary` | `equip(slot: int, item_id: String) → bool`, `unequip(slot: int) → void`, `get_equipped(slot: int) → String`, `get_total_stats() → Dictionary` | ItemRegistry (`get_equipment()`), SaveManager (persistence) | None — pure Dictionary |
| **EnhancementCalculator** | No state (pure math) | `calc_gold_cost(base: int, level: int) → int`, `calc_material_cost(level: int) → Dictionary`, `calc_enhanced_stat(base: int, level: int, multiplier: float) → int` | ItemRegistry (`ENHANCEMENT_ATTACK_MULTIPLIER=0.1`) | None — pure math |
| **StatHUD** | `_stat_labels: Dictionary`, `_comparison_panel: Control`, `_last_stats: Dictionary` | `update_stats(stats: Dictionary) → void`, `show_comparison(new_stats: Dictionary) → void`, `hide_comparison() → void` | ItemRegistry (stat formulas), GoldVault (`get_gold()` for display) | `RichTextLabel.text`, `Label.text`, `Control.visible` ✅ Stable |
| **TouchRouter** | `_gesture_state: Dictionary`, `_active_layer: int`, `_modal_stack: Array`, `_tap_callbacks: Dictionary` | `register_layer(layer: int, nodes: Array) → void`, `set_modal(modal: Control) → void`, `get_active_layer() → int`, `process_touch(event: InputEvent) → void` | UILayoutManager (`get_safe_area()` for bounds) | `InputEventScreenTouch`, `InputEventScreenDrag`, `Control.get_global_rect()` ✅ Stable |

### Feature Layer — Module Ownership

| Module | Owns | Exposes | Consumes | Engine APIs (Verified) |
|--------|------|---------|----------|------------------------|
| **CombatEngine** | `_battle_state: int`, `_active_timer: Timer`, `_damage_queue: Array`, `_skip_mode: bool` | `start_battle(enemy: Dictionary) → void`, `get_battle_state() → int`, `skip_battle() → void`, `calculate_damage(attacker: Dictionary, defender: Dictionary) → int` | EnemyController (`spawn_enemy()`, `get_rewards()`), ItemRegistry (equipment stats) | `Timer.wait_time`, `Timer.start()`, `Timer.timeout` signal ✅ Stable |
| **DropGenerator** | `_drop_tables: Dictionary`, `_rng: RandomNumberGenerator` | `generate_drops(enemy_id: String, floor: int) → Array`, `set_rng_seed(seed: int) → void` | EnemyController (enemy type), ItemRegistry (`get_equipment()` for drops) | `RandomNumberGenerator.randf()`, `RandomNumberGenerator.randi_range()` ✅ Stable |
| **YieldEstimator** | No state (pure math) | `estimate_yield(duration: float, floor: int) → Dictionary`, `calc_gold_yield(base: int, duration: float) → int`, `calc_material_yield(duration: float) → Dictionary` | CombatEngine (yield constants), TimeTracker (`get_offline_duration()` input) | None — pure math |
| **DungeonDriver** | `_floor_state: int`, `_floor_timer: Timer`, `_completion_signal: Signal` | `advance_to_next() → void`, `is_floor_complete() → bool`, `on_enemy_defeated(enemy_id: String) → void` | DungeonProgress (`get_current_floor()`), CombatEngine (`start_battle()`), EnemyController (`defeat_enemy()`), Signal routing | `Node`, `Timer`, Signal `emit()` ✅ Stable |
| **DropHandler** | `_drop_panel: Control`, `_pending_drops: Array`, `_selected_indices: Array` | `display_drops(drops: Array) → void`, `collect_selected() → void`, `on_drop_selected(index: int) → void` | CombatEngine (post-battle trigger), DropGenerator (`generate_drops()`), ItemRegistry (item display) | `Control.visible`, `Popup.popup()`, `Button.pressed` signal ✅ Stable |
| **EnhancementWorkflow** | `_enhancement_panel: Control`, `_preview_data: Dictionary`, `_current_slot: int` | `start_enhancement(slot: int) → void`, `confirm_enhancement() → bool`, `cancel_enhancement() → void`, `get_preview(slot: int, new_level: int) → Dictionary` | EquipmentManager (`get_equipped()`), MaterialInventory (`can_remove_bulk()`), GoldVault (`can_spend()`), EnhancementCalculator (`calc_gold_cost()`, `calc_material_cost()`) | `Control.visible`, Signal custom, `Button.pressed` ✅ Stable |
| **OfflineReward** | `_reward_panel: Control`, `_calculated_reward: Dictionary`, `_claimed: bool` | `calculate_reward() → void`, `display_reward() → void`, `claim_reward() → void` | YieldEstimator (`estimate_yield()`), TimeTracker (`get_offline_duration()`), SaveManager (save claimed state) | `Control.visible`, `Popup.popup_centered()` ✅ Stable |

### Presentation Layer — Module Ownership

| Module | Owns | Exposes | Consumes | Engine APIs (Verified) |
|--------|------|---------|----------|------------------------|
| **FeedbackCoordinator** | `_event_queue: Array`, `_layered_queue: Array`, `_active_feedback: Dictionary` | `trigger_feedback(event: String, tier: int, data: Dictionary) → void`, `queue_layered(events: Array, base_delay: float) → void`, `cancel_feedback(event: String) → void` | ParticlePool (`spawn_preset()`), VibrationController (`vibrate()`), StatHUD (`update_stats()` for flash) | `Node`, Signal routing, `Timer` for delays ✅ Stable |

### Polish Layer — Module Ownership

| Module | Owns | Exposes | Consumes | Engine APIs (Verified) |
|--------|------|---------|----------|------------------------|
| **AudioPool** | `_sfx_pool: Array[AudioStreamPlayer]`, `_music_player: AudioStreamPlayer`, `_bus_layout: AudioBusLayout` | `play_sfx(name: String) → void`, `play_music(stream: AudioStream) → void`, `play_layered(base: String, boss: String, delay: float) → void`, `stop_all() → void` | CombatEngine (event triggers), EnhancementWorkflow (event triggers) | `AudioStreamPlayer.stream`, `AudioStreamPlayer.play()`, `AudioStreamPlayer.finished` signal ✅ Stable (verified in audio.md) |

### Dependency Diagram

```
                    ┌────────────────────────────────────────────────────────────────────┐
                    │  POLISH LAYER                                                      │
                    │  ┌─────────────────┐                                               │
                    │  │   AudioPool     │──► CombatEngine (events)                      │
                    │  │                 │──► EnhancementWorkflow (events)               │
                    │  └─────────────────┘                                               │
                    └────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
                    ┌────────────────────────────────────────────────────────────────────┐
                    │  PRESENTATION LAYER                                                │
                    │  ┌─────────────────────────┐                                       │
                    │  │  FeedbackCoordinator    │──► ParticlePool                       │
                    │  │                         │──► VibrationController                │
                    │  │                         │──► StatHUD                            │
                    │  └─────────────────────────┘                                       │
                    └────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  FEATURE LAYER                                                                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  CombatEngine   │  │  DropGenerator  │  │  YieldEstimator │  │  DungeonDriver  │    │
│  │                 │  │                 │  │                 │  │                 │    │
│  │ ─►EnemyCtrl     │  │ ─►EnemyCtrl     │  │ ─►CombatEngine  │  │ ─►DungeonProg   │    │
│  │ ─►ItemRegistry  │  │ ─►ItemRegistry  │  │ ─►TimeTracker   │  │ ─►CombatEngine  │    │
│  │ ─►Timer         │  │ ─►RNG           │  │                 │  │ ─►EnemyCtrl     │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                         │
│  │  DropHandler    │  │ EnhanceWorkflow │  │  OfflineReward  │                         │
│  │                 │  │                 │  │                 │                         │
│  │ ─►CombatEngine  │  │ ─►EquipManager  │  │ ─►YieldEstim    │                         │
│  │ ─►DropGenerator │  │ ─►MaterialInv   │  │ ─►TimeTracker   │                         │
│  │ ─►ItemRegistry  │  │ ─►GoldVault     │  │ ─►SaveManager   │                         │
│  │ ─►Control/Popup │  │ ─►EnhanceCalc   │  │ ─►Control       │                         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  CORE LAYER                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  ItemRegistry   │  │  TimeTracker    │  │  MaterialInv    │  │   GoldVault     │    │
│  │                 │  │                 │  │                 │  │                 │    │
│  │ ─►SaveManager   │  │ ─►SaveManager   │  │ ─►SaveManager   │  │ ─►SaveManager   │    │
│  │ ─►Resource      │  │ ─►Time/OS APIs  │  │ ─►ItemRegistry  │  │                 │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  DungeonProg    │  │  EnemyCtrl      │  │  EquipManager   │  │  EnhanceCalc    │    │
│  │                 │  │                 │  │                 │  │                 │    │
│  │ ─►SaveManager   │  │ ─►ItemRegistry  │  │ ─►ItemRegistry  │  │ ─►ItemRegistry  │    │
│  │                 │  │ ─►DungeonProg   │  │ ─►SaveManager   │  │ (pure math)     │    │
│  │                 │  │ ─►Node/Anim     │  │                 │  │                 │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
│  ┌─────────────────┐  ┌─────────────────┐                                                   │
│  │    StatHUD      │  │   TouchRouter   │                                                   │
│  │                 │  │                 │                                                   │
│  │ ─►ItemRegistry  │  │ ─►UILayoutMgr   │                                                   │
│  │ ─►GoldVault     │  │ ─►InputEvent    │                                                   │
│  │ ─►RichTextLabel │  │ ─►Control       │                                                   │
│  └─────────────────┘  └─────────────────┘                                                   │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  FOUNDATION LAYER                                                                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐    │
│  │  SaveManager    │  │  ParticlePool   │  │ VibrationCtrl   │  │  UILayoutMgr    │    │
│  │                 │  │                 │  │                 │  │                 │    │
│  │ ─►FileAccess ⚠️ │  │ ─►GPUParticles2D│  │ ─►OS.vibrate()  │  │ ─►Control       │    │
│  │ ─►SHA256Context │  │ ─►ProcessMat    │  │ ─►OS.has_feat   │  │ ─►DisplayServer │    │
│  │                 │  │ ⚠️ .restart()   │  │                 │  │                 │    │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  PLATFORM LAYER                                                                          │
│  Godot 4.6 Engine API Surface                                                            │
│  iOS / Android OS                                                                        │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Frame Update Path

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  FRAME UPDATE CYCLE (60 fps target, 16.6ms budget)                           │
│                                                                              │
│  1. INPUT COLLECTION                                                         │
│     Platform Layer                                                           │
│     └─► OS._input_event(event: InputEvent)                                  │
│        └─► TouchRouter._input(event)                                        │
│           └─► Gesture detection (tap/hold/swipe)                            │
│              └─► Emit: touch_tap(pos, target)                               │
│                 └─► If target is Button → Emit: button_clicked(pos)         │
│                                                                              │
│  2. GAME STATE UPDATE                                                        │
│     Feature Layer                                                            │
│     └─► CombatEngine._process(delta)                                        │
│        └─► Timer-driven hit queue (HITS_PER_SECOND=2.0)                     │
│           └─► calculate_damage(attacker_stats, defender_stats)              │
│              └─► Apply variance (0.9-1.1)                                   │
│              └─► Emit: damage_dealt(damage, target)                         │
│              └─► Emit: enemy_health_changed(enemy_id, new_hp)               │
│        └─► If skip_mode: compress timeline (0.3s per hit batch)             │
│                                                                              │
│  3. STATE PROPAGATION                                                        │
│     Core Layer                                                               │
│     └─► EnemyController.on_damage_dealt(damage, enemy_id)                   │
│        └─► Update _active_enemies[enemy_id].current_hp                      │
│        └─► If hp <= 0: transition state SPAWNING → ALIVE → DEFEATED         │
│           └─► Emit: enemy_defeated(enemy_id, rewards)                       │
│     └─► StatHUD.on_enemy_health_changed(enemy_id, new_hp)                   │
│        └─► Update enemy HP bar display                                      │
│                                                                              │
│  4. VISUAL RENDERING                                                         │
│     Presentation Layer                                                       │
│     └─► FeedbackCoordinator.on_damage_dealt(damage, target)                 │
│        └─► trigger_feedback("hit", damage_tier, {position: target.pos})     │
│           └─► ParticlePool.spawn_preset("Hit Flash", pos, tier)             │
│           └─► VibrationController.vibrate("Light Impact", tier)             │
│     └─► ParticlePool._process(delta)                                        │
│        └─► GPUParticles2D.emitting = true for active presets                │
│        └─► Engine renders particles via Forward+ renderer                   │
│                                                                              │
│  5. LATE FRAME CLEANUP                                                       │
│     Foundation Layer                                                         │
│     └─► SaveManager.auto_save_check()                                       │
│        └─► Every 60s: save_game(current_data)                               │
│           └─► Atomic write + checksum update                                │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Signal Architecture

| Signal Name | Emitter | Consumer(s) | Data Payload |
|-------------|---------|-------------|--------------|
| `touch_tap(position, target)` | TouchRouter | UI layers | `Vector2`, `String` |
| `button_clicked(position)` | TouchRouter | AudioPool, FeedbackCoordinator | `Vector2` |
| `battle_started(enemy_data)` | CombatEngine | AudioPool, FeedbackCoordinator, EnemyController | `Dictionary` |
| `damage_dealt(damage, target_id)` | CombatEngine | FeedbackCoordinator, EnemyController, StatHUD | `int`, `String` |
| `enemy_health_changed(enemy_id, new_hp)` | EnemyController | StatHUD | `String`, `int` |
| `enemy_defeated(enemy_id, rewards)` | EnemyController | DropGenerator, DropHandler, FeedbackCoordinator, DungeonDriver | `String`, `Dictionary` |
| `boss_defeated(boss_id, gold, drops)` | EnemyController | FeedbackCoordinator, AudioPool, DungeonProgress | `String`, `int`, `Array` |
| `floor_complete(floor_num)` | DungeonDriver | DungeonProgress, FeedbackCoordinator | `int` |
| `floor_advanced(new_floor)` | DungeonDriver | DungeonProgress, EnemyController, CombatEngine | `int` |
| `equipment_dropped(item_data)` | DropHandler | EquipmentManager, FeedbackCoordinator | `Dictionary` |
| `enhancement_complete(slot, new_level, new_stats)` | EnhancementWorkflow | EquipmentManager, FeedbackCoordinator, AudioPool, StatHUD | `int`, `int`, `Dictionary` |
| `gold_changed(new_amount)` | GoldVault | StatHUD | `int` |
| `material_changed(material_id, new_stack)` | MaterialInventory | StatHUD | `String`, `int` |
| `offline_reward_calculated(rewards)` | OfflineReward | FeedbackCoordinator | `Dictionary` |

**Pattern**: Direct node-to-node subscription via Godot signals. No global EventBus.

### Save/Load Path

**Save Trigger**: Timer (60s) or explicit call
```
1. Collect state: TimeTracker, GoldVault, MaterialInventory, EquipmentManager, DungeonProgress, EnemyController
2. Serialize: Dictionary → JSON + version + timestamp
3. Atomic write: temp file → verify → rename → checksum
```

**Load Trigger**: Game startup
```
1. Validate: Read save + checksum → SHA-256 compare
2. Deserialize: JSON → Dictionary → version check → migration if needed
3. Distribute: Set state in each module via setter APIs
4. Offline calc: TimeTracker.get_offline_duration() → YieldEstimator → display
```

### Initialization Order

Boot sequence (bottom-up):

```
1. PLATFORM    → Engine init, DisplayServer, OS features
2. FOUNDATION  → UILayoutManager, VibrationController, ParticlePool, SaveManager (load or default)
3. CORE        → ItemRegistry, TimeTracker, GoldVault, MaterialInventory, DungeonProgress, EnemyController, EquipmentManager, StatHUD, TouchRouter
4. FEATURE     → CombatEngine, DropGenerator, DungeonDriver, DropHandler, EnhancementWorkflow, OfflineReward
5. PRESENTATION → FeedbackCoordinator
6. POLISH      → AudioPool
7. POST-BOOT   → Offline reward display OR start idle game loop
```

## API Boundaries

### Foundation Layer

```gdscript
# SaveManager
func load_save() -> Dictionary           # Returns saved state or empty dict
func save_game(data: Dictionary) -> bool # Atomic write + checksum
func get_checksum() -> String            # SHA-256 of current save
func validate_integrity() -> bool        # Corruption check

# ParticlePool
func spawn_preset(preset: String, pos: Vector2, tier: int) -> void  # Tier 1-6
func clear_all() -> void                 # Stop all particles
func set_layer_delay(preset: String, delay_ms: float) -> void       # Composite events

# VibrationController
func vibrate(pattern: String, tier: int) -> void  # Tier 1-4, mobile only
func is_supported() -> bool
func merge_patterns(patterns: Array[String]) -> void  # Sum durations

# UILayoutManager
func apply_anchor(node: Control, preset: String) -> void  # Preset: top_left, center, etc.
func get_safe_area() -> Rect2
func get_screen_orientation() -> String
```

### Core Layer

```gdscript
# ItemRegistry
func get_equipment(id: String) -> Dictionary    # {slot, rarity, base_attack, base_defense, ...}
func get_material(id: String) -> Dictionary     # {stackable, max_stack, rarity}
func get_enhanced_stats(base: Dictionary, level: int) -> Dictionary  # Enhancement formula

# TimeTracker
func get_session_duration() -> float    # Seconds since boot
func get_offline_duration() -> float    # Seconds since last save (capped to 86400)
func detect_anomaly() -> bool           # Forward/backward time jump

# MaterialInventory
func get_stack(material_id: String) -> int
func add_material(id: String, count: int) -> int   # Capped to max_stack
func can_remove_bulk(requirements: Dictionary) -> bool  # Pre-check
func remove_bulk(requirements: Dictionary) -> bool      # Atomic removal

# GoldVault
func get_gold() -> int
func add_gold(amount: int) -> int       # Unlimited stack
func can_spend(amount: int) -> bool
func spend(amount: int) -> bool

# DungeonProgress
func get_current_floor() -> int
func get_checkpoint() -> int
func advance_floor() -> void            # emit floor_advanced
func is_boss_floor(floor: int) -> bool

# EnemyController
func spawn_enemy(floor: int) -> Dictionary  # {enemy_id, stats, state, rewards}
func get_enemy_state(enemy_id: String) -> int  # SPAWNING/ALIVE/DEFEATED
func defeat_enemy(enemy_id: String) -> Dictionary  # emit enemy_defeated

# EquipmentManager
func equip(slot: int, equipment_id: String) -> bool  # Slot compatibility check
func unequip(slot: int) -> void
func get_equipped(slot: int) -> String
func get_total_stats() -> Dictionary  # Sum all equipped + enhancement

# EnhancementCalculator (static)
static func calc_gold_cost(base: int, level: int) -> int
static func calc_material_cost(level: int) -> Dictionary
static func calc_enhanced_stat(base: int, level: int, mult: float) -> int

# StatHUD
func update_stats(stats: Dictionary) -> void
func show_comparison(new_stats: Dictionary) -> void  # +N/-N indicators
func hide_comparison() -> void

# TouchRouter
func register_layer(layer: int, nodes: Array[Control]) -> void
func set_modal(modal: Control) -> void       # Blocks lower layers
func get_active_layer() -> int
func process_touch(event: InputEvent) -> void  # emit touch_tap, button_clicked
```

### Feature Layer

```gdscript
# CombatEngine
func start_battle(enemy: Dictionary) -> void  # emit battle_started
func get_battle_state() -> int  # IDLE/COMBAT/SKIPPING
func skip_battle() -> void      # Compress to 0.3s batches
func calculate_damage(attacker: Dictionary, defender: Dictionary) -> int

# DropGenerator
func generate_drops(enemy_id: String, floor: int) -> Array  # RNG per drop tables
func set_rng_seed(seed: int) -> void  # Testing reproducibility

# YieldEstimator (static)
static func estimate_yield(duration: float, floor: int) -> Dictionary  # Capped

# DungeonDriver
func advance_to_next() -> void      # emit floor_complete, floor_advanced
func is_floor_complete() -> bool
func on_enemy_defeated(enemy_id: String) -> void  # Signal handler

# DropHandler
func display_drops(drops: Array) -> void   # Show comparison panel
func collect_selected() -> void            # emit equipment_dropped

# EnhancementWorkflow
func start_enhancement(slot: int) -> void  # Show preview panel
func confirm_enhancement() -> bool         # emit enhancement_complete
func get_preview(slot: int, new_level: int) -> Dictionary

# OfflineReward
func calculate_reward() -> void            # emit offline_reward_calculated
func display_reward() -> void              # Show claim panel
func claim_reward() -> void                # Award gold/materials
```

### Presentation & Polish Layers

```gdscript
# FeedbackCoordinator
func trigger_feedback(event: String, tier: int, data: Dictionary) -> void
func queue_layered(events: Array, base_delay: float) -> void  # Sequential
func cancel_feedback(event: String) -> void

# AudioPool
func play_sfx(name: String) -> void        # From pool (8 SFX + 2 UI)
func play_music(stream: AudioStream) -> void
func play_layered(base: String, boss: String, delay: float) -> void
func stop_all() -> void
```

## ADR Audit

### Existing ADRs

**None** — No ADRs exist in docs/architecture/. All must be created fresh.

### Traceability Coverage

| Metric | Count |
|--------|-------|
| Technical Requirements (TR) | 96 |
| TR Covered by ADRs | 0 |
| TR Gaps | 96 |

All 96 technical requirements from 24 GDDs require ADR coverage. No legacy decisions to audit.

### Required ADRs (Prioritized by Layer)

**Foundation Layer (BLOCKING — must create before any coding):**

| ADR | Title | Covers TR IDs |
|-----|-------|---------------|
| ADR-0001 | Save System Architecture | TR-save-001 through TR-save-005, TR-fileaccess-001 |
| ADR-0002 | Signal Architecture Pattern | TR-signal-001, TR-signal-002 |
| ADR-0003 | Particle System Pooling | TR-particle-001, TR-particle-002, TR-particle-003 |
| ADR-0004 | Audio System Pooling | TR-audio-001, TR-audio-002 |
| ADR-0005 | UI Anchor and Safe Area Strategy | TR-ui-001, TR-ui-002 |

**Core Layer (BLOCKING — must create before feature implementation):**

| ADR | Title | Covers TR IDs |
|-----|-------|---------------|
| ADR-0006 | Touch Input Routing | TR-input-001, TR-input-002, TR-input-003 |
| ADR-0007 | Combat Loop Architecture | TR-combat-001, TR-combat-002, TR-combat-003 |
| ADR-0008 | Enemy State Machine | TR-state-001, TR-state-002 |
| ADR-0009 | Enhancement Formula Implementation | TR-enhance-001, TR-enhance-002 |
| ADR-0010 | Offline Yield Capping | TR-offline-001, TR-offline-002 |
| ADR-0011 | Item Registry Ownership Model | TR-regist-001 |

**Feature/Presentation Layer (Can defer to implementation):**

| ADR | Title | Covers |
|-----|-------|--------|
| ADR-0012 | Feedback Coordination Pattern | Event routing, layered feedback |
| ADR-0013 | Drop Generation RNG Strategy | Reproducible seeds |
| ADR-0014 | Dungeon Progression State | Floor/checkpoint persistence |
| ADR-0015 | Equipment Slot Compatibility Matrix | Slot type matching rules |

## Required ADRs

(See Phase 5 ADR Audit — 15 ADRs required, 11 blocking, 4 deferrable)

## Architecture Principles

1. **Single Source of Truth for Data** — Each module owns its state exclusively. No duplicate state storage.

2. **Signal-Driven Communication, No Singleton EventBus** — Direct node-to-node subscription. Owner emits, consumer subscribes.

3. **Pure Math Functions Over Stateful Calculators** — EnhancementCalculator, YieldEstimator are static. State lives in owner modules.

4. **Atomic Operations for Resource Modification** — GoldVault.spend() and MaterialInventory.remove_bulk() are atomic. No partial deductions.

5. **Mobile-First Input and Layout** — TouchRouter handles all input. UILayoutManager adapts to safe area and orientation.

6. **Offline Resilience Over Online Synchronization** — SaveManager handles anomalies, caps rewards, migrates versions. No server sync.

7. **Performance Budget Enforcement** — 60fps, 16.6ms, 50-100 draw calls, 200 particles. Pre-instantiate pools, no runtime spawning.

## Open Questions

1. **Save File Location** — `user://` (Godot default) vs platform-specific path? → ADR-0001
2. **Particle Pool Size** — 8 instances sufficient for worst-case burst? → ADR-0003 (prototype validation)
3. **Audio Bus Layout File** — Embedded in scene vs separate .tres? → ADR-0004
4. **Enhancement Preview Calculation** — Cache vs compute on-demand? → Implementation (not blocking)
5. **Touch Router Layer Count** — 3 layers sufficient for all screens? → ADR-0006
6. **Difficulty Curve Validation** — Enemy ×5.5 vs equipment ×2 mismatch? → Post-MVP playtest
7. **Engine Reference Core Module Missing** — Create `docs/engine-reference/godot/modules/core.md` before SaveManager implementation.