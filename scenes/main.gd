extends Control
# Main scene - Desktop horizontal layout with visual feedback

# Autoload references
var _combat: Node = null
var _enemy_ctrl: Node = null
var _dungeon: Node = null
var _equip: Node = null
var _progress: Node = null
var _gold: Node = null
var _enhance_flow: Node = null

# UI nodes
@onready var gold_lbl: Label = $LeftPanel/GoldLabel
@onready var atk_lbl: Label = $LeftPanel/AttackLabel
@onready var def_lbl: Label = $LeftPanel/DefenseLabel
@onready var pwr_lbl: Label = $LeftPanel/PowerLabel
@onready var floor_lbl: Label = $LeftPanel/FloorLabel
@onready var enemy_name: Label = $EnemyArea/EnemyNameLabel
@onready var enemy_hp: ProgressBar = $EnemyArea/EnemyHPBar
@onready var skip_btn: Button = $SkipButton
@onready var enhance_btn: Button = $LeftPanel/EnhanceButton

# Visual nodes
@onready var player_sprite: ColorRect = $BattleArea/PlayerSprite
@onready var enemy_sprite: ColorRect = $BattleArea/EnemySprite
@onready var damage_container: Control = $BattleArea/DamageContainer

# State
var _damage_labels: Array = []
var _enemy_max_hp: int = 100

func _ready():
	# Get autoloads
	_combat = get_node("/root/CombatEngine")
	_enemy_ctrl = get_node("/root/EnemyController")
	_dungeon = get_node("/root/DungeonDriver")
	_equip = get_node("/root/EquipmentManager")
	_progress = get_node("/root/DungeonProgress")
	_gold = get_node("/root/GoldVault")
	_enhance_flow = get_node("/root/EnhancementWorkflow")

	# Connect buttons
	skip_btn.pressed.connect(_skip)
	enhance_btn.pressed.connect(_enhance)

	# Connect signals
	if _combat:
		_combat.battle_started.connect(_on_start)
		_combat.damage_dealt.connect(_on_damage)
		_combat.battle_victory.connect(_on_win)
	if _enemy_ctrl:
		_enemy_ctrl.enemy_spawned.connect(_on_spawn)
		_enemy_ctrl.enemy_health_changed.connect(_on_hp)
	if _gold:
		_gold.gold_changed.connect(_on_gold)
	if _equip:
		_equip.stats_updated.connect(_on_stats)

	_update_ui()

func _skip():
	if _combat and _combat.has_method("skip_battle"):
		_combat.skip_battle()

func _enhance():
	if _enhance_flow and _enhance_flow.has_method("start_enhancement"):
		_enhance_flow.start_enhancement(0)

func _on_start(data: Dictionary):
	enemy_name.text = "Floor %d Enemy" % data.get("floor", 1)
	_enemy_max_hp = data.get("max_hp", 100)
	enemy_hp.max_value = _enemy_max_hp
	enemy_hp.value = data.get("current_hp", 100)
	# Pulse enemy sprite
	_pulse_sprite(enemy_sprite)

func _on_spawn(id: String, data: Dictionary):
	enemy_name.text = "Floor %d Enemy" % data.get("floor", 1)
	_enemy_max_hp = data.get("max_hp", 100)
	enemy_hp.max_value = _enemy_max_hp
	enemy_hp.value = data.get("current_hp", 100)
	# Color enemy by floor difficulty
	var difficulty: float = clamp(data.get("floor", 1) / 10.0, 0.0, 1.0)
	enemy_sprite.color = Color(0.8 - difficulty * 0.3, 0.2, 0.2 + difficulty * 0.3)

func _on_hp(id: String, hp: int):
	enemy_hp.value = hp
	# Flash red when damaged
	if hp < enemy_hp.value:
		_flash_sprite(enemy_sprite, Color.RED)

func _on_damage(dmg: int, target: String):
	# Show floating damage number
	_show_damage(dmg)
	# Flash player when dealing damage
	_flash_sprite(player_sprite, Color.YELLOW)

func _on_win(id: String, rewards: Dictionary):
	enemy_name.text = "Victory!"
	# Flash green
	_flash_sprite(enemy_sprite, Color.GREEN)
	# Give rewards
	if _gold and rewards.get("gold", 0) > 0:
		_gold.add_gold(rewards.gold)

func _on_gold(amount: int):
	gold_lbl.text = "Gold: %d" % amount
	_flash_sprite(player_sprite, Color.GOLD)

func _on_stats(stats: Dictionary):
	atk_lbl.text = "ATK: %d" % stats.get("attack", 0)
	def_lbl.text = "DEF: %d" % stats.get("defense", 0)
	pwr_lbl.text = "PWR: %d" % stats.get("power", 0)

func _on_floor(f: int):
	floor_lbl.text = "Floor: %d" % f

func _update_ui():
	if _gold and _gold.has_method("get_gold"):
		gold_lbl.text = "Gold: %d" % _gold.get_gold()
	if _equip and _equip.has_method("get_total_stats"):
		var s = _equip.get_total_stats()
		atk_lbl.text = "ATK: %d" % s.get("attack", 0)
		def_lbl.text = "DEF: %d" % s.get("defense", 0)
		pwr_lbl.text = "PWR: %d" % s.get("power", 0)
	if _progress and _progress.has_method("get_current_floor"):
		floor_lbl.text = "Floor: %d" % _progress.get_current_floor()

# Visual effects
func _show_damage(amount: int):
	var lbl = Label.new()
	lbl.text = "-%d" % amount
	lbl.position = Vector2(
		enemy_sprite.position.x + randf_range(-50, 50),
		enemy_sprite.position.y - 50
	)
	lbl.modulate = Color.RED
	lbl.add_theme_font_size_override("font_size", 24)
	damage_container.add_child(lbl)

	# Animate up and fade
	var tween = create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 80, 0.5)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)

func _flash_sprite(sprite: ColorRect, color: Color):
	var original: Color = sprite.color
	sprite.color = color
	await get_tree().create_timer(0.1).timeout
	sprite.color = original

func _pulse_sprite(sprite: ColorRect):
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)