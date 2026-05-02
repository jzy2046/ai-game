# ADR-0004: Audio System Pooling

## Status
Accepted

## Context
Audio system provides sound effects for game events (combat, enhancement, UI). Mobile platform requires efficient resource usage. Audio API stable in Godot 4.4-4.6.

Key constraints from GDD:
- SFX pool size: 8 concurrent sounds
- UI pool size: 2 concurrent UI sounds
- Bus layout: Master/Music/SFX/UI
- Layered audio for boss events (base + boss sound with delay)
- Performance: No runtime AudioStreamPlayer creation

## Decision

### Pool Strategy: Pre-instantiated Players

```gdscript
class_name AudioPool extends Node

const SFX_POOL_SIZE: int = 8
const UI_POOL_SIZE: int = 2

var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _sfx_library: Dictionary = {}  # {name: AudioStream}

func _ready():
    # SFX pool
    for i in range(SFX_POOL_SIZE):
        var player := AudioStreamPlayer.new()
        player.bus = &"SFX"
        add_child(player)
        _sfx_pool.append(player)
    
    # UI pool
    for i in range(UI_POOL_SIZE):
        var player := AudioStreamPlayer.new()
        player.bus = &"UI"
        add_child(player)
        _ui_pool.append(player)
    
    # Music player (single instance)
    _music_player = AudioStreamPlayer.new()
    _music_player.bus = &"Music"
    add_child(_music_player)
    
    # Load SFX library
    _sfx_library = {
        "hit_light": preload("res://assets/audio/sfx/hit_light.wav"),
        "hit_heavy": preload("res://assets/audio/sfx/hit_heavy.wav"),
        "gold_collect": preload("res://assets/audio/sfx/gold_collect.wav"),
        "enhance_success": preload("res://assets/audio/sfx/enhance_success.wav"),
        "victory": preload("res://assets/audio/sfx/victory.wav"),
        "defeat": preload("res://assets/audio/sfx/defeat.wav"),
        "button_click": preload("res://assets/audio/ui/button_click.wav"),
        "floor_complete": preload("res://assets/audio/sfx/floor_complete.wav"),
    }
```

### Bus Layout Configuration

Separate resource file: `res://assets/audio/audio_bus_layout.tres`

```
Master (volume: 0 dB)
├── Music (volume: -6 dB)  # Quieter than SFX
├── SFX (volume: 0 dB)
└── UI (volume: -3 dB)     # Medium volume for clicks
```

**Rationale**: Independent volume control per category. Players can mute music without affecting SFX.

### Play Pattern

```gdscript
func play_sfx(name: String, volume_db: float = 0.0) -> void:
    var stream: AudioStream = _sfx_library.get(name)
    if stream == null:
        push_warning("SFX not found: " + name)
        return
    
    # Find idle player from pool
    for player in _sfx_pool:
        if not player.playing:
            player.stream = stream
            player.volume_db = volume_db
            player.play()
            return
    
    # Pool exhausted: skip (SFX is non-critical)
    push_warning("SFX pool exhausted, skipping: " + name)

func play_ui(name: String) -> void:
    # Same pattern with _ui_pool
    for player in _ui_pool:
        if not player.playing:
            player.stream = _sfx_library[name]
            player.play()
            return
```

### Layered Audio (Boss Events)

```gdscript
func play_layered(base_sfx: String, boss_sfx: String, delay_ms: float) -> void:
    # Play base immediately
    play_sfx(base_sfx)
    
    # Schedule boss sound after delay
    var timer := Timer.new()
    timer.wait_time = delay_ms / 1000.0
    timer.one_shot = true
    timer.timeout.connect(func(): play_sfx(boss_sfx))
    add_child(timer)
    timer.start()
```

### Music Management

```gdscript
func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
    if _music_player.playing:
        # Fade out current music
        var tween := create_tween()
        tween.tween_property(_music_player, "volume_db", -80.0, fade_time)
        await tween.finished
    
    _music_player.stream = stream
    _music_player.volume_db = -80.0  # Start silent
    _music_player.play()
    
    # Fade in new music
    var tween := create_tween()
    tween.tween_property(_music_player, "volume_db", 0.0, fade_time)

func stop_all() -> void:
    for player in _sfx_pool + _ui_pool:
        player.stop()
    _music_player.stop()
```

## Consequences

### Positive
- Zero runtime allocation (pool pre-created)
- Bus layout enables per-category volume/mute
- Layered audio supports boss feedback
- Music fade transitions smooth

### Negative
- Fixed pool size (8 SFX may limit concurrent sounds)
- Pool exhaustion skips SFX (acceptable for gameplay)
- Fade adds Tween overhead (minimal)

### Risks
- **Audio API stability**: Verified in audio.md, no breaking changes in 4.4-4.6 ✅
- **Pool exhaustion during feedback burst**: Multiple simultaneous events
  - Mitigation: Priority system (critical sounds first) if needed post-MVP

## ADR Dependencies
- None (Foundation layer)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| AudioStreamPlayer | Godot 4.x | LOW | ✅ audio.md (stable) |
| AudioServer/Buses | Godot 4.x | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-audio-001 | AudioStreamPlayer pool sizing | 8 SFX + 2 UI players |
| TR-audio-002 | Bus layout configuration | Master/Music/SFX/UI in separate .tres |