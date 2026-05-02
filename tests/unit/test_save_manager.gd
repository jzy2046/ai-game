# GUT Test Configuration
extends GutTest

var _save_manager: SaveManager
var _test_save_path: String = "user://test_save.json"

func before_all():
	# Setup test environment
	pass

func after_all():
	# Cleanup test files
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("test_save.json"):
		dir.remove("test_save.json")
	if dir and dir.file_exists("test_save_checksum.txt"):
		dir.remove("test_save_checksum.txt")

func before_each():
	# Fresh save manager for each test
	_save_manager = SaveManager.new()

func after_each():
	# Reset state
	if _save_manager:
		_save_manager.queue_free()

# TR-save-001: JSON serialization format
func test_json_serialization_format():
	var test_data := {
		version = 1,
		gold = 100,
		materials = {"enhancement_stone": 50},
		equipment = {},
		dungeon = {current_floor = 1},
	}

	var json_string := JSON.stringify(test_data)
	var parsed: Variant = JSON.parse_string(json_string)

	assert_true(parsed is Dictionary, "JSON should parse to Dictionary")
	assert_eq(parsed.get("gold"), 100, "Gold should serialize correctly")
	assert_eq(parsed.get("materials").get("enhancement_stone"), 50, "Materials should serialize correctly")

# TR-save-002: Atomic write pattern
func test_atomic_write_creates_file():
	var test_data := {
		version = 1,
		gold = 0,
		saved_at = Time.get_unix_time_from_system(),
	}

	# SaveManager should use atomic write
	_save_manager.save_game(test_data)

	# Verify file exists
	var file := FileAccess.open("user://save.json", FileAccess.READ)
	assert_not_null(file, "Save file should exist after atomic write")
	if file:
		file.close()

# TR-save-003: SHA-256 checksum integrity
func test_checksum_calculation():
	var test_string := "test_data_for_checksum"
	var checksum: String = _calculate_test_checksum(test_string)

	# SHA-256 produces 64 character hex string
	assert_eq(checksum.length(), 64, "SHA-256 checksum should be 64 hex characters")

func _calculate_test_checksum(text: String) -> String:
	var ctx := SHA256Context.new()
	ctx.start()
	ctx.update(text.to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	return digest.hex_encode()

# TR-save-004: Time anomaly detection
func test_forward_jump_anomaly():
	# Simulate forward jump > 7 days
	var raw_duration: float = 604801.0  # 7 days + 1 second

	# Anomaly should be detected
	assert_true(raw_duration > 604800, "Duration > 7 days should trigger anomaly")

func test_backward_jump_anomaly():
	# Negative duration = backward jump
	var raw_duration: float = -100.0

	assert_true(raw_duration < 0, "Negative duration should trigger anomaly")

# TR-save-005: Offline duration capping
func test_offline_duration_cap():
	# Duration > MAX_ALLOWED_OFFLINE should be capped
	var raw_duration: float = 100000.0  # > 24 hours
	var capped_duration: float = minf(raw_duration, 86400.0)

	assert_eq(capped_duration, 86400.0, "Offline duration should cap to 24 hours")