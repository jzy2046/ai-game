extends Node
class_name TimeTracker

## TimeTracker - Core Layer
## Implements: ADR-0010 Offline Yield Capping (time detection)
## TR IDs: TR-offline-001, TR-offline-002

## Signals
signal time_anomaly_detected(anomaly_type: String)

## Constants
const MAX_ALLOWED_OFFLINE: int = 86400  # 24 hours
const MAX_FORWARD_JUMP: int = 604800  # 7 days

## State
var _session_start: int = 0
var _last_save_time: int = 0
var _anomaly_log: Array = []

#region Public API

func get_session_duration() -> float:
	## Returns seconds since game started
	var now: int = Time.get_ticks_usec()
	var duration_us: int = now - _session_start
	return duration_us / 1000000.0

func get_offline_duration() -> float:
	## Returns seconds since last save (capped to MAX_ALLOWED_OFFLINE)
	var current_system_time: int = OS.get_system_time_msecs()
	var raw_offline_ms: int = current_system_time - _last_save_time
	var raw_offline_seconds: float = raw_offline_ms / 1000.0

	# Check anomaly
	if detect_anomaly(raw_offline_seconds):
		log_anomaly("forward_jump")
		return MAX_ALLOWED_OFFLINE

	# Cap to max
	return minf(raw_offline_seconds, MAX_ALLOWED_OFFLINE)

func detect_anomaly(raw_duration: float) -> bool:
	## Check for time anomaly (forward jump > 7 days or negative)
	if raw_duration > MAX_FORWARD_JUMP:
		return true
	if raw_duration < 0:
		log_anomaly("backward_jump")
		return true
	return false

func log_anomaly(anomaly_type: String) -> void:
	## Log anomaly for debugging
	_anomaly_log.append({
		type = anomaly_type,
		timestamp = Time.get_datetime_string_from_system(),
	})
	emit_signal("time_anomaly_detected", anomaly_type)

func set_last_save_time(time_ms: int) -> void:
	_last_save_time = time_ms

func get_state() -> Dictionary:
	return {
		session_start = _session_start,
		last_save = _last_save_time,
		anomalies = _anomaly_log,
	}

func set_state(state: Dictionary) -> void:
	_session_start = state.get("session_start", Time.get_ticks_usec())
	_last_save_time = state.get("last_save", OS.get_system_time_msecs())
	_anomaly_log = state.get("anomalies", [])

#endregion

#region Lifecycle

func _ready():
	_session_start = Time.get_ticks_usec()
	# _last_save_time loaded from SaveManager

#endregion