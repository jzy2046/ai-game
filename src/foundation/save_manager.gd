extends Node
# SaveManager - Foundation Layer
# Implements: ADR-0001 Save System Architecture
# TR IDs: TR-save-001 through TR-save-005, TR-fileaccess-001
# NOTE: No class_name - autoload singleton, accessed via SaveManager globally

## Signals
signal save_completed(checksum: String)
signal save_failed(error: String)

## Constants
const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save_temp.json"
const CHECKSUM_PATH: String = "user://save_checksum.txt"
const SAVE_VERSION: int = 1
const MAX_FORWARD_JUMP: int = 604800  # 7 days in seconds
const MAX_ALLOWED_OFFLINE: int = 86400  # 24 hours in seconds

## State
var _save_data: Dictionary = {}
var _checksum: String = ""
var _auto_save_timer: Timer

#region Public API

func load_save() -> Dictionary:
	## Load save from disk, validate integrity, return state
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_error() != OK:
		# No save or error - return empty (first boot)
		_initialize_default_state()
		return _save_data

	var json_text: String = file.get_as_text()
	file.close()

	# Validate checksum
	if not _validate_checksum(json_text):
		push_warning("Save checksum mismatch - possible corruption")
		_initialize_default_state()
		return _save_data

	# Parse JSON
	var parsed: Variant = JSON.parse_string(json_text)
	if parsed == null or not parsed is Dictionary:
		push_warning("Save JSON parse failed")
		_initialize_default_state()
		return _save_data

	_save_data = parsed as Dictionary

	# Version migration
	var loaded_version: int = _save_data.get("version", 1)
	if loaded_version < SAVE_VERSION:
		_migrate_save(loaded_version)

	return _save_data

func save_game(data: Dictionary) -> bool:
	## Atomic write save to disk with checksum
	_save_data = data
	_save_data["version"] = SAVE_VERSION
	_save_data["saved_at"] = Time.get_unix_time_from_system()

	var json_text: String = JSON.stringify(_save_data)

	# Atomic write: temp → verify → rename
	var temp_file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp_file == null or temp_file.get_error() != OK:
		push_error("Failed to open temp file for writing")
		emit_signal("save_failed", "temp_file_open_failed")
		return false

	temp_file.store_string(json_text)
	temp_file.close()

	# Verify write
	var verify_file := FileAccess.open(TEMP_PATH, FileAccess.READ)
	if verify_file == null or verify_file.get_error() != OK:
		push_error("Failed to verify temp file")
		emit_signal("save_failed", "temp_file_verify_failed")
		return false

	var verified_text: String = verify_file.get_as_text()
	verify_file.close()

	if verified_text != json_text:
		push_error("Write verification mismatch")
		emit_signal("save_failed", "write_verification_failed")
		return false

	# Rename temp to final (Godot doesn't have atomic rename, use copy)
	var final_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if final_file == null or final_file.get_error() != OK:
		push_error("Failed to open final file")
		emit_signal("save_failed", "final_file_open_failed")
		return false

	final_file.store_string(json_text)
	final_file.close()

	# Calculate and store checksum
	_checksum = _calculate_checksum(json_text)
	var checksum_file := FileAccess.open(CHECKSUM_PATH, FileAccess.WRITE)
	if checksum_file != null and checksum_file.get_error() == OK:
		checksum_file.store_string(_checksum)
		checksum_file.close()

	emit_signal("save_completed", _checksum)
	return true

func get_checksum() -> String:
	return _checksum

func validate_integrity() -> bool:
	## Validate current save against stored checksum
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null or file.get_error() != OK:
		return false

	var json_text: String = file.get_as_text()
	file.close()

	return _validate_checksum(json_text)

func get_save_data() -> Dictionary:
	return _save_data

#endregion

#region Lifecycle

func _ready():
	# Load or initialize
	load_save()

	# Setup auto-save timer (60s interval)
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = 60.0
	_auto_save_timer.one_shot = false
	_auto_save_timer.timeout.connect(_on_auto_save)
	add_child(_auto_save_timer)
	_auto_save_timer.start()

func _on_auto_save():
	# Collect state from all modules and save
	var state := _collect_state()
	save_game(state)

#endregion

#region Internal

func _initialize_default_state() -> void:
	_save_data = {
		version = SAVE_VERSION,
		saved_at = Time.get_unix_time_from_system(),
		time = {
			session_start = Time.get_ticks_usec(),
			last_save = Time.get_ticks_msec(),
		},
		gold = 0,
		materials = {},
		equipment = {},
		dungeon = {
			current_floor = 1,
			checkpoint = 1,
			unlocked_floors = [1],
			boss_defeated = {},
		},
		enemies = {
			active = [],
			defeated = [],
		},
	}

func _collect_state() -> Dictionary:
	## Collect state from all registered autoloads
	# Autoloads are always available - no null check needed
	var state := {
		version = SAVE_VERSION,
		saved_at = Time.get_unix_time_from_system(),
	}
	# Access autoloads via get_node("/root/AutoloadName") for safety
	if has_node("/root/TimeTracker"):
		state["time"] = get_node("/root/TimeTracker").get_state()
	if has_node("/root/GoldVault"):
		state["gold"] = get_node("/root/GoldVault").get_gold()
	if has_node("/root/MaterialInventory"):
		state["materials"] = get_node("/root/MaterialInventory").get_all_stacks()
	if has_node("/root/EquipmentManager"):
		state["equipment"] = get_node("/root/EquipmentManager").get_all_equipped()
	if has_node("/root/DungeonProgress"):
		state["dungeon"] = get_node("/root/DungeonProgress").get_state()
	if has_node("/root/EnemyController"):
		state["enemies"] = get_node("/root/EnemyController").get_state()
	return state

func _validate_checksum(json_text: String) -> bool:
	var stored_checksum: String = ""
	var checksum_file := FileAccess.open(CHECKSUM_PATH, FileAccess.READ)
	if checksum_file != null and checksum_file.get_error() == OK:
		stored_checksum = checksum_file.get_as_text()
		checksum_file.close()

	if stored_checksum.is_empty():
		return true  # No checksum yet, accept

	var calculated: String = _calculate_checksum(json_text)
	return calculated == stored_checksum

func _calculate_checksum(text: String) -> String:
	## SHA-256 checksum using HashingContext
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode()

func _migrate_save(from_version: int) -> void:
	## Run migration chain from from_version to SAVE_VERSION
	# Currently version 1 only, no migrations needed
	# Future: v1→v2, v2→v3 migration functions
	pass

#endregion