extends Control
# Main scene coordinator - bridges UI to autoload systems

# Cached autoload references
var _combat_engine: Node = null
var _enemy_controller: Node = null
var _dungeon_driver: Node = null
var _equipment_manager: Node = null
var _dungeon_progress: Node = null
var _gold_vault: Node = null
var _enhancement_workflow: Node = null

# UI references
@onready var _gold_label: Label = $LeftPanel/GoldLabel
@onready var _attack_label: Label = $LeftPanel/AttackLabel
@onready var _defense_label: Label = $LeftPanel/DefenseLabel
@onready var _power_label: Label = $LeftPanel/PowerLabel
@onready var _floor_label: Label = $LeftPanel/FloorLabel
@onready var _enemy_name_label: Label = $EnemyArea/EnemyNameLabel
@onready var _enemy_hp_bar: ProgressBar = $EnemyArea/EnemyHPBar
@onready var _skip_button: Button = $SkipButton
@onready var _enhance_button: Button = $LeftPanel/EnhanceButton

func _ready():
	# Cache autoloads
	_combat_engine = get_node("/root/CombatEngine")
	_enemy_controller = get_node("/root/EnemyController")
	_dungeon_driver = get_node("/root/DungeonDriver")
	_equipment_manager = get_node("/root/EquipmentManager")
	_dungeon_progress = get_node("/root/DungeonProgress")
	_gold_vault = get_node("/root/GoldVault")
	_enhancement_workflow = get_node("/root/EnhancementWorkflow")

	# Connect button signals
	_skip_button.pressed.connect(_on_skip_pressed)
	_enhance_button.pressed.connect(_on_enhance_pressed)

	# Connect autoload signals
	if _combat_engine:
		_combat_engine.battle_started.connect(_on_battle_started)
		_combat_engine.damage_dealt.connect(_on_damage_dealt)
		_combat_engine.battle_victory.connect(_on_battle_victory)

	if _enemy_controller:
		_enemy_controller.enemy_spawned.connect(_on_enemy_spawned)
		_enemy_controller.enemy_health_changed.connect(_on_enemy_health_changed)

	if _dungeon_progress:
		_dungeon_progress.floor_changed.connect(_on_floor_changed)

	if _equipment_manager:
		_equipment_manager.stats_updated.connect(_on_stats_updated)

	if _gold_vault:
		_gold_vault.gold_changed.connect(_on_gold_changed)

	# Initial UI update
	_update_ui()

func _on_skip_pressed():
	if _combat_engine and _combat_engine.has_method("skip_battle"):
		_combat_engine.skip_battle()

func _on_enhance_pressed():
	if _enhancement_workflow and _enhancement_workflow.has_method("start_enhancement"):
		_enhancement_workflow.start_enhancement(0)

func _on_battle_started(enemy_data: Dictionary):
	_enemy_name_label.text = "Enemy Floor %d" % enemy_data.get("floor", 1)
	_enemy_hp_bar.max_value = enemy_data.get("max_hp", 100)
	_enemy_hp_bar.value = enemy_data.get("current_hp", 100)

func _on_enemy_spawned(enemy_id: String, enemy_data: Dictionary):
	_enemy_name_label.text = "Enemy Floor %d" % enemy_data.get("floor", 1)
	_enemy_hp_bar.max_value = enemy_data.get("max_hp", 100)
	_enemy_hp_bar.value = enemy_data.get("current_hp", 100)

func _on_enemy_health_changed(enemy_id: String, new_hp: int):
	_enemy_hp_bar.value = new_hp

func _on_damage_dealt(damage: int, target_id: String):
	pass

func _on_battle_victory(enemy_id: String, rewards: Dictionary):
	_enemy_name_label.text = "Victory!"

func _on_floor_changed(new_floor: int):
	_floor_label.text = "Floor: %d" % new_floor

func _on_stats_updated(new_stats: Dictionary):
	_attack_label.text = "ATK: %d" % new_stats.get("attack", 0)
	_defense_label.text = "DEF: %d" % new_stats.get("defense", 0)
	_power_label.text = "PWR: %d" % new_stats.get("power", 0)

func _on_gold_changed(new_amount: int):
	_gold_label.text = "Gold: %d" % new_amount

func _update_ui():
	if _gold_vault and _gold_vault.has_method("get_gold"):
		_gold_label.text = "Gold: %d" % _gold_vault.get_gold()

	if _equipment_manager and _equipment_manager.has_method("get_total_stats"):
		var stats: Dictionary = _equipment_manager.get_total_stats()
		_attack_label.text = "ATK: %d" % stats.get("attack", 0)
		_defense_label.text = "DEF: %d" % stats.get("defense", 0)
		_power_label.text = "PWR: %d" % stats.get("power", 0)

	if _dungeon_progress and _dungeon_progress.has_method("get_current_floor"):
		_floor_label.text = "Floor: %d" % _dungeon_progress.get_current_floor()