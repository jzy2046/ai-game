extends Control
class_name EnhancementWorkflow

## EnhancementWorkflow - Feature Layer
## Implements enhancement UI flow

## Signals
signal enhancement_started(slot: int, current_level: int)
signal enhancement_complete(slot: int, new_level: int, new_stats: Dictionary)
signal enhancement_cancelled()

## State
var _enhancement_panel: Control
var _current_slot: int = -1
var _preview_data: Dictionary = {}

#region Public API

func start_enhancement(slot: int) -> void:
	## Display enhancement panel with preview
	var equipment_id: String = EquipmentManager.get_equipped(slot)
	if equipment_id.is_empty():
		push_warning("No equipment in slot %d" % slot)
		return

	var current_level: int = EquipmentManager.get_equipped_level(slot)
	if not EnhancementCalculator.can_enhance(current_level):
		push_warning("Equipment at max level")
		return

	_current_slot = slot
	_preview_data = get_preview(slot, current_level + 1)

	if _enhancement_panel == null:
		_create_enhancement_panel()

	_update_panel_content()
	_enhancement_panel.visible = true
	TouchRouter.push_modal(self)

	emit_signal("enhancement_started", slot, current_level)

func confirm_enhancement() -> bool:
	## Execute enhancement if resources sufficient
	if _current_slot < 0:
		return false

	var current_level: int = EquipmentManager.get_equipped_level(_current_slot)
	var gold_cost: int = EnhancementCalculator.calc_gold_cost(current_level)
	var material_cost: Dictionary = EnhancementCalculator.calc_material_cost(current_level)

	# Check resources
	if not GoldVault.can_spend(gold_cost):
		push_warning("Insufficient gold: need %d" % gold_cost)
		return false

	if not MaterialInventory.can_remove_bulk(material_cost):
		push_warning("Insufficient materials")
		return false

	# Spend resources
	GoldVault.spend(gold_cost)
	MaterialInventory.remove_bulk(material_cost)

	# Increase level
	var new_level: int = current_level + 1
	EquipmentManager.set_equipped_level(_current_slot, new_level)

	var new_stats: Dictionary = EquipmentManager.get_total_stats()
	emit_signal("enhancement_complete", _current_slot, new_level, new_stats)

	# Feedback
	FeedbackCoordinator.trigger_feedback("enhancement", new_level, {})
	AudioPool.play_sfx("enhance_success")

	hide_enhancement()
	return true

func cancel_enhancement() -> void:
	emit_signal("enhancement_cancelled")
	hide_enhancement()

func hide_enhancement() -> void:
	if _enhancement_panel:
		_enhancement_panel.visible = false
	TouchRouter.pop_modal()
	_current_slot = -1

func get_preview(slot: int, new_level: int) -> Dictionary:
	## Calculate preview data for enhancement
	var equipment_id: String = EquipmentManager.get_equipped(slot)
	if equipment_id.is_empty():
		return {}

	var current_level: int = EquipmentManager.get_equipped_level(slot)
	var base_def: Dictionary = ItemRegistry.get_equipment(equipment_id)

	var current_stats: Dictionary = ItemRegistry.get_enhanced_stats(equipment_id, current_level)
	var new_stats: Dictionary = ItemRegistry.get_enhanced_stats(equipment_id, new_level)

	var gold_cost: int = EnhancementCalculator.calc_gold_cost(current_level)
	var material_cost: Dictionary = EnhancementCalculator.calc_material_cost(current_level)

	return {
		equipment_name = base_def.get("name", "Unknown"),
		current_level = current_level,
		new_level = new_level,
		current_stats = current_stats,
		new_stats = new_stats,
		gold_cost = gold_cost,
		material_cost = material_cost,
	}

#endregion

#region Internal

func _create_enhancement_panel() -> void:
	_enhancement_panel = Control.new()
	_enhancement_panel.name = "EnhancementPanel"
	_enhancement_panel.size = Vector2(500, 350)
	_enhancement_panel.position = Vector2(110, 400)
	add_child(_enhancement_panel)

func _update_panel_content() -> void:
	## Update panel with current preview data
	if _preview_data.is_empty():
		return

	# MVP: Simple text display
	var y_offset: int = 20

	var title := Label.new()
	title.text = "Enhance: %s" % _preview_data.equipment_name
	title.position = Vector2(150, y_offset)
	_enhancement_panel.add_child(title)
	y_offset += 40

	var level_label := Label.new()
	level_label.text = "Level: %d → %d" % [_preview_data.current_level, _preview_data.new_level]
	level_label.position = Vector2(150, y_offset)
	_enhancement_panel.add_child(level_label)
	y_offset += 30

	var attack_label := Label.new()
	attack_label.text = "Attack: %d → %d (+%d)" % [
		_preview_data.current_stats.attack,
		_preview_data.new_stats.attack,
		_preview_data.new_stats.attack - _preview_data.current_stats.attack
	]
	attack_label.position = Vector2(150, y_offset)
	_enhancement_panel.add_child(attack_label)
	y_offset += 30

	var cost_label := Label.new()
	cost_label.text = "Cost: %d Gold" % _preview_data.gold_cost
	cost_label.position = Vector2(150, y_offset)
	_enhancement_panel.add_child(cost_label)
	y_offset += 50

	# Buttons
	var confirm_btn := Button.new()
	confirm_btn.text = "Enhance"
	confirm_btn.position = Vector2(100, y_offset)
	confirm_btn.pressed.connect(confirm_enhancement)
	_enhancement_panel.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.position = Vector2(300, y_offset)
	cancel_btn.pressed.connect(cancel_enhancement)
	_enhancement_panel.add_child(cancel_btn)

#endregion