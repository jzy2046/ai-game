extends Control
class_name OfflineReward

## OfflineReward - Feature Layer
## Implements offline reward display and claim

## Signals
signal offline_reward_calculated(rewards: Dictionary)
signal offline_reward_claimed(rewards: Dictionary)

## State
var _reward_panel: Control
var _calculated_reward: Dictionary = {}
var _claimed: bool = false

#region Public API

func calculate_reward() -> void:
	## Calculate offline yield based on duration
	var duration: float = TimeTracker.get_offline_duration()
	if duration <= 0:
		return  # No offline time

	var floor: int = DungeonProgress.get_current_floor()
	_calculated_reward = YieldEstimator.estimate_yield(duration, floor)
	_calculated_reward["duration_hours"] = duration / 3600.0

	emit_signal("offline_reward_calculated", _calculated_reward)

func display_reward() -> void:
	## Show reward claim panel
	if _calculated_reward.is_empty():
		calculate_reward()

	if _calculated_reward.is_empty():
		return  # No reward

	if _reward_panel == null:
		_create_reward_panel()

	_update_panel_content()
	_reward_panel.visible = true
	TouchRouter.push_modal(self)

func claim_reward() -> void:
	## Award rewards to player
	if _claimed or _calculated_reward.is_empty():
		return

	# Award gold
	var gold: int = _calculated_reward.get("gold", 0)
	GoldVault.add_gold(gold)

	# Award materials
	var materials: Dictionary = _calculated_reward.get("materials", {})
	for material_id in materials:
		var count: int = materials[material_id]
		MaterialInventory.add_material(material_id, count)

	emit_signal("offline_reward_claimed", _calculated_reward)

	# Feedback
	FeedbackCoordinator.trigger_feedback("gold_gain", gold, {})

	_claimed = true
	hide_reward()

func hide_reward() -> void:
	if _reward_panel:
		_reward_panel.visible = false
	TouchRouter.pop_modal()

#endregion

#region Lifecycle

func _ready():
	# Check for offline time on boot
	var offline_duration: float = TimeTracker.get_offline_duration()
	if offline_duration > 60:  # More than 1 minute
		calculate_reward()
		display_reward()

#endregion

#region Internal

func _create_reward_panel() -> void:
	_reward_panel = Control.new()
	_reward_panel.name = "OfflineRewardPanel"
	_reward_panel.size = Vector2(500, 300)
	_reward_panel.position = Vector2(110, 450)
	add_child(_reward_panel)

func _update_panel_content() -> void:
	if _calculated_reward.is_empty():
		return

	var y_offset: int = 20

	var title := Label.new()
	title.text = "Welcome Back!"
	title.position = Vector2(180, y_offset)
	_reward_panel.add_child(title)
	y_offset += 40

	var duration_label := Label.new()
	var hours: float = _calculated_reward.get("duration_hours", 0)
	duration_label.text = "Offline: %.1f hours" % hours
	duration_label.position = Vector2(180, y_offset)
	_reward_panel.add_child(duration_label)
	y_offset += 30

	var gold_label := Label.new()
	gold_label.text = "Gold: +%d" % _calculated_reward.get("gold", 0)
	gold_label.position = Vector2(180, y_offset)
	_reward_panel.add_child(gold_label)
	y_offset += 30

	var material_label := Label.new()
	material_label.text = "Materials: +%d" % _calculated_reward.get("enhancement_stone", 0)
	material_label.position = Vector2(180, y_offset)
	_reward_panel.add_child(material_label)
	y_offset += 50

	var claim_btn := Button.new()
	claim_btn.text = "Claim"
	claim_btn.position = Vector2(200, y_offset)
	claim_btn.pressed.connect(claim_reward)
	_reward_panel.add_child(claim_btn)

#endregion