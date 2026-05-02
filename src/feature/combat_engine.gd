extends Node
# CombatEngine - Feature Layer
# NOTE: No class_name - autoload singleton, accessed via CombatEngine globally
# Implements: ADR-0007 Combat Loop Architecture
# TR IDs: TR-combat-001, TR-combat-002, TR-combat-003

## Signals
signal battle_started(enemy_data: Dictionary)
signal damage_dealt(damage: int, target_id: String)
signal enemy_health_changed(enemy_id: String, new_hp: int)
signal battle_victory(enemy_id: String, rewards: Dictionary)
signal battle_defeated()

## Constants
const HITS_PER_SECOND: float = 2.0
const HIT_INTERVAL: float = 1.0 / HITS_PER_SECOND  # 0.5s
const SKIP_BATCH_INTERVAL: float = 0.3
const SKIP_BATCH_SIZE: int = 5
const DAMAGE_VARIANCE_MIN: float = 0.9
const DAMAGE_VARIANCE_MAX: float = 1.1

## State enum
enum CombatState { IDLE, COMBAT, SKIPPING, VICTORY, DEFEATED }

## State
var _state: CombatState = CombatState.IDLE
var _hit_timer: Timer
var _enemy: Dictionary = {}
var _player_stats: Dictionary = {}
var _rng: RandomNumberGenerator
# Cached autoload references
var _equipment_manager: Node = null
var _enemy_controller: Node = null

#region Public API

func start_battle(enemy_data: Dictionary) -> void:
	## Initialize combat with enemy
	if _state != CombatState.IDLE:
		push_warning("Cannot start battle while in state: %d" % _state)
		return

	_enemy = enemy_data
	if _equipment_manager and _equipment_manager.has_method("get_total_stats"):
		_player_stats = _equipment_manager.get_total_stats()
	_state = CombatState.COMBAT

	_hit_timer.start()
	emit_signal("battle_started", enemy_data)

func get_battle_state() -> CombatState:
	return _state

func skip_battle() -> void:
	## Compress remaining combat to 0.3s batches
	if _state != CombatState.COMBAT:
		return

	_state = CombatState.SKIPPING
	_hit_timer.stop()

	# Calculate remaining hits
	var avg_damage: int = _calc_base_damage()
	var remaining_hp: int = _enemy.current_hp
	var hits_needed: int = ceili(remaining_hp / avg_damage)

	# Start batch processing
	_process_skip_batch(hits_needed)

func calculate_damage(attacker_stats: Dictionary, defender_stats: Dictionary) -> int:
	## Calculate damage with variance
	var base: int = maxi(1, attacker_stats.power - defender_stats.get("defense", 0))
	var variance: float = _rng.randf_range(DAMAGE_VARIANCE_MIN, DAMAGE_VARIANCE_MAX)
	return floori(base * variance)

#endregion

#region Lifecycle

func _ready():
	# Cache autoload references
	_equipment_manager = get_node("/root/EquipmentManager")
	_enemy_controller = get_node("/root/EnemyController")

	_hit_timer = Timer.new()
	_hit_timer.wait_time = HIT_INTERVAL
	_hit_timer.one_shot = false
	_hit_timer.timeout.connect(_on_hit_timer)
	add_child(_hit_timer)

	_rng = RandomNumberGenerator.new()
	_rng.randomize()

#endregion

#region Internal

func _on_hit_timer() -> void:
	if _state != CombatState.COMBAT:
		return

	var damage: int = calculate_damage(_player_stats, _enemy)
	_enemy.current_hp -= damage

	emit_signal("damage_dealt", damage, _enemy.id)
	emit_signal("enemy_health_changed", _enemy.id, _enemy.current_hp)

	if _enemy_controller and _enemy_controller.has_method("apply_damage"):
		_enemy_controller.apply_damage(_enemy.id, damage)

	if _enemy.current_hp <= 0:
		_end_battle(CombatState.VICTORY)

func _process_skip_batch(remaining_hits: int) -> void:
	var batch_size: int = mini(SKIP_BATCH_SIZE, remaining_hits)

	for i in range(batch_size):
		var damage: int = calculate_damage(_player_stats, _enemy)
		_enemy.current_hp -= damage
		emit_signal("damage_dealt", damage, _enemy.id)

	if _enemy_controller and _enemy_controller.has_method("apply_damage"):
		_enemy_controller.apply_damage(_enemy.id, 0)  # Sync state

	if _enemy.current_hp <= 0:
		_end_battle(CombatState.VICTORY)
	else:
		var new_remaining: int = remaining_hits - batch_size
		var timer := Timer.new()
		timer.wait_time = SKIP_BATCH_INTERVAL
		timer.one_shot = true
		timer.timeout.connect(_process_skip_batch.bind(new_remaining))
		add_child(timer)
		timer.start()

func _end_battle(final_state: CombatState) -> void:
	_state = final_state
	_hit_timer.stop()

	if final_state == CombatState.VICTORY:
		if _enemy_controller and _enemy_controller.has_method("get_rewards"):
			var rewards: Dictionary = _enemy_controller.get_rewards(_enemy.id)
			emit_signal("battle_victory", _enemy.id, rewards)
		# Reset to IDLE after brief delay for next battle
		await get_tree().create_timer(0.3).timeout
		_state = CombatState.IDLE

func _calc_base_damage() -> int:
	## Calculate average damage without variance
	return maxi(1, _player_stats.power - _enemy.get("recommended_power", 0) / 2)

#endregion