extends Control
# OfflineReward - Feature Layer
# NOTE: No class_name - autoload singleton, accessed via OfflineReward globally
# Implements offline reward display and claim

## Signals
signal offline_reward_calculated(rewards: Dictionary)
signal offline_reward_claimed(rewards: Dictionary)

## State
var _cached_rewards: Dictionary = {}
# Cached autoload references
var _gold_vault: Node = null
var _material_inventory: Node = null
var _dungeon_progress: Node = null

#region Public API

func calculate_rewards() -> Dictionary:
	## Calculate offline rewards based on absence duration
	if _dungeon_progress and _dungeon_progress.has_method("get_current_floor"):
		var floor: int = _dungeon_progress.get_current_floor()
		# Use YieldEstimator static class
		var duration: float = 3600.0  # MVP: 1 hour placeholder
		_cached_rewards = YieldEstimator.estimate_yield(duration, floor)
		emit_signal("offline_reward_calculated", _cached_rewards)
		return _cached_rewards
	return {}

func claim_rewards() -> void:
	## Add rewards to player resources
	if _cached_rewards.is_empty():
		return

	var gold: int = _cached_rewards.get("gold", 0)
	if gold > 0 and _gold_vault and _gold_vault.has_method("add_gold"):
		_gold_vault.add_gold(gold)

	var materials: Dictionary = _cached_rewards.get("materials", {})
	for material_id in materials:
		var amount: int = materials[material_id]
		if amount > 0 and _material_inventory and _material_inventory.has_method("add_material"):
			_material_inventory.add_material(material_id, amount)

	emit_signal("offline_reward_claimed", _cached_rewards)
	_cached_rewards.clear()
	hide()

#endregion

#region Lifecycle

func _ready():
	# Cache autoload references
	_gold_vault = get_node("/root/GoldVault")
	_material_inventory = get_node("/root/MaterialInventory")
	_dungeon_progress = get_node("/root/DungeonProgress")
	hide()

#endregion