extends Control
# StatHUD - Core Layer
# NOTE: No class_name - autoload singleton, accessed via StatHUD globally
# Implements stat display and comparison
# Depends on: ItemRegistry, GoldVault

## Signals

## State
var _stat_labels: Dictionary = {}
var _gold_label: Label
var _comparison_panel: Control
var _last_stats: Dictionary = {}
var _gold_vault: Node = null  # Cached reference

#region Public API

func update_stats(stats: Dictionary) -> void:
	## Update stat labels from stats dictionary
	_last_stats = stats

	# Update attack label
	if _stat_labels.has("attack"):
		var label: Label = _stat_labels["attack"]
		label.text = str(stats.get("attack", 0))

	# Update defense label
	if _stat_labels.has("defense"):
		var label: Label = _stat_labels["defense"]
		label.text = str(stats.get("defense", 0))

	# Update power label
	if _stat_labels.has("power"):
		var label: Label = _stat_labels["power"]
		label.text = str(stats.get("power", 0))

	# Update gold
	if _gold_label and _gold_vault and _gold_vault.has_method("get_gold"):
		_gold_label.text = str(_gold_vault.get_gold())

func show_comparison(new_stats: Dictionary) -> void:
	## Display comparison panel with +N/-N indicators
	if _comparison_panel == null:
		return

	_comparison_panel.visible = true

	# Calculate deltas
	var attack_delta: int = new_stats.get("attack", 0) - _last_stats.get("attack", 0)
	var defense_delta: int = new_stats.get("defense", 0) - _last_stats.get("defense", 0)

	# Update comparison labels
	if _stat_labels.has("attack_delta"):
		var label: Label = _stat_labels["attack_delta"]
		label.text = "%+d" % attack_delta
		label.modulate = Color.GREEN if attack_delta > 0 else Color.RED

	if _stat_labels.has("defense_delta"):
		var label: Label = _stat_labels["defense_delta"]
		label.text = "%+d" % defense_delta
		label.modulate = Color.GREEN if defense_delta > 0 else Color.RED

func hide_comparison() -> void:
	if _comparison_panel:
		_comparison_panel.visible = false

#endregion

#region Lifecycle

func _ready():
	# Cache GoldVault reference
	_gold_vault = get_node("/root/GoldVault")
	# Get labels from scene tree (will be created in main.tscn)
	# MVP: Create minimal labels dynamically if not in scene
	_setup_labels()

func _setup_labels() -> void:
	# Dynamic setup for MVP
	if not has_node("AttackLabel"):
		var label := Label.new()
		label.name = "AttackLabel"
		label.position = Vector2(50, 100)
		add_child(label)
		_stat_labels["attack"] = label

	if not has_node("DefenseLabel"):
		var label := Label.new()
		label.name = "DefenseLabel"
		label.position = Vector2(50, 140)
		add_child(label)
		_stat_labels["defense"] = label

	if not has_node("PowerLabel"):
		var label := Label.new()
		label.name = "PowerLabel"
		label.position = Vector2(50, 180)
		add_child(label)
		_stat_labels["power"] = label

	if not has_node("GoldLabel"):
		_gold_label = Label.new()
		_gold_label.name = "GoldLabel"
		_gold_label.position = Vector2(50, 220)
		add_child(_gold_label)

#endregion