extends Control
class_name DropHandler

## DropHandler - Feature Layer
## Implements post-combat drop display and collection

## Signals
signal drops_collected(drops: Array)

## State
var _drop_panel: Control
var _pending_drops: Array = []
var _selected_indices: Array = []

#region Public API

func display_drops(drops: Array) -> void:
	## Show drop panel with equipment comparison
	_pending_drops = drops
	_selected_indices.clear()

	if _drop_panel == null:
		_create_drop_panel()

	_drop_panel.visible = true
	TouchRouter.push_modal(self)

	# Populate drop items
	_populate_drop_panel()

func collect_selected() -> void:
	## Award selected items to player
	if _selected_indices.is_empty():
		# Auto-select all if none selected
		for i in range(_pending_drops.size()):
			_selected_indices.append(i)

	var collected: Array = []
	for index in _selected_indices:
		if index < _pending_drops.size():
			var drop: Dictionary = _pending_drops[index]
			collected.append(drop)

			# Award to equipment manager (auto-equip if slot empty)
			var equipment_id: String = drop.equipment_id
			var equipment_def: Dictionary = ItemRegistry.get_equipment(equipment_id)
			var slot: int = equipment_def.get("slot", 0)

			if EquipmentManager.get_equipped(slot).is_empty():
				EquipmentManager.equip(slot, equipment_id)
			# Else: item stored in inventory (post-MVP feature)

	emit_signal("drops_collected", collected)

	# Close panel
	hide_drops()

func hide_drops() -> void:
	_drop_panel.visible = false
	TouchRouter.pop_modal()
	_pending_drops.clear()

#endregion

#region Internal

func _create_drop_panel() -> void:
	_drop_panel = Control.new()
	_drop_panel.name = "DropPanel"
	_drop_panel.size = Vector2(600, 400)
	_drop_panel.position = Vector2(60, 400)
	add_child(_drop_panel)

	# MVP: Simple panel with text labels
	var label := Label.new()
	label.name = "DropTitle"
	label.text = "Equipment Drops"
	label.position = Vector2(200, 20)
	_drop_panel.add_child(label)

func _populate_drop_panel() -> void:
	## Fill panel with drop items
	# MVP: Simple text display
	var y_offset: int = 60
	for i in range(_pending_drops.size()):
		var drop: Dictionary = _pending_drops[i]
		var equipment_id: String = drop.equipment_id
		var equipment_def: Dictionary = ItemRegistry.get_equipment(equipment_id)

		var label := Label.new()
		label.text = "%s (Rarity %d)" % [equipment_def.get("name", "Unknown"), drop.rarity]
		label.position = Vector2(50, y_offset)
		_drop_panel.add_child(label)

		y_offset += 30

	# Collect button
	var button := Button.new()
	button.text = "Collect"
	button.position = Vector2(200, y_offset + 20)
	button.pressed.connect(collect_selected)
	_drop_panel.add_child(button)

#endregion