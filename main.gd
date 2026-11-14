extends Node2D

var _total_enemies: int = 0
var _remaining_enemies: int = 0
var _flag_unlocked: bool = false
var _level_finished: bool = false

var _hp_label: Label
var _orb_label: Label
var _enemies_label: Label
var _banner_panel: PanelContainer
var _banner_label: Label

@onready var _player: Player = $Player
@onready var _checkpoint_flag: Area2D = $Level1/CheckpointFlag


func _ready() -> void:
	_build_hud()

	if _player != null:
		_player.orb_fired.connect(_on_orb_fired)
		_player.orb_recalled.connect(_on_orb_recalled)
		_player.hp_changed.connect(_on_player_hp_changed)
		_player.player_died.connect(_on_player_died)
		_on_player_hp_changed(_player.current_hp, _player.max_hp)

	var enemies := get_tree().get_nodes_in_group("enemies")
	_total_enemies = enemies.size()
	_remaining_enemies = _total_enemies
	for enemy_node in enemies:
		if enemy_node.has_signal("enemy_died"):
			enemy_node.enemy_died.connect(_on_enemy_died)
	_update_enemies_label()

	if _checkpoint_flag != null:
		_checkpoint_flag.body_entered.connect(_on_checkpoint_body_entered)
		_update_flag_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			get_tree().reload_current_scene()


func _on_orb_fired(orb: EnergyOrb) -> void:
	if orb != null and not orb.stats_changed.is_connected(_on_orb_stats_changed):
		orb.stats_changed.connect(_on_orb_stats_changed)
	_on_orb_stats_changed(orb.bounce_count, orb.current_speed, orb.current_damage)


func _on_orb_recalled() -> void:
	_orb_label.text = "ORB: READY  |  BOUNCES: 0  |  SPEED: 440 px/s  |  DMG: 15"
	_orb_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))


func _on_orb_stats_changed(bounces: int, speed: float, damage: int) -> void:
	var status := "LIVE (DODGE!)" if bounces >= 1 else "ARMING..."
	_orb_label.text = "ORB: %s  |  BOUNCES: %d  |  SPEED: %d px/s  |  DMG: %d" % [
		status,
		bounces,
		int(roundf(speed)),
		damage
	]
	var col := Color(0.45, 0.95, 1.0)
	if bounces >= 3:
		col = Color(1.0, 0.35, 0.45)
	elif bounces >= 1:
		col = Color(1.0, 0.9, 0.25)
	_orb_label.add_theme_color_override("font_color", col)


func _on_player_hp_changed(current: int, maximum: int) -> void:
	var hearts := ""
	for i in range(maximum):
		hearts += "♥ " if i < current else "♡ "
	_hp_label.text = "HP: %s(%d/%d)" % [hearts.strip_edges(), current, maximum]
	var col := Color(0.45, 1.0, 0.55) if current >= 2 else Color(1.0, 0.35, 0.35)
	_hp_label.add_theme_color_override("font_color", col)


func _on_player_died() -> void:
	_level_finished = true
	_show_banner("HIT BY YOUR OWN RICOCHET ORB!\nPress [R] to Restart Level 1", Color(1.0, 0.35, 0.4))


func _on_enemy_died(_enemy: Node2D) -> void:
	_remaining_enemies = maxi(0, _remaining_enemies - 1)
	_update_enemies_label()
	if _remaining_enemies == 0:
		_flag_unlocked = true
		_update_flag_state()
		if not _level_finished:
			_show_banner("ALL TARGETS CLEARED!\nTouch the Flag on the bottom-right to finish (or press [R] to Replay)", Color(0.35, 1.0, 0.65))


func _on_checkpoint_body_entered(body: Node2D) -> void:
	if body != _player or _level_finished:
		return
	if _flag_unlocked:
		_level_finished = true
		_show_banner("LEVEL 1 COMPLETE!\nKinetic Ricochet Mastery — Press [R] to Play Again", Color(0.35, 1.0, 0.75))


func _update_enemies_label() -> void:
	_enemies_label.text = "ENEMIES: %d / %d" % [_remaining_enemies, _total_enemies]
	var col := Color(0.35, 1.0, 0.65) if _remaining_enemies == 0 else Color(1.0, 0.6, 0.35)
	_enemies_label.add_theme_color_override("font_color", col)


func _update_flag_state() -> void:
	if _checkpoint_flag == null:
		return
	var flag_sprite := _checkpoint_flag.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var flag_label := _checkpoint_flag.get_node_or_null("FlagLabel") as Label
	if _flag_unlocked:
		if flag_sprite != null:
			flag_sprite.modulate = Color.WHITE
		if flag_label != null:
			flag_label.text = "EXIT OPEN!"
			flag_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	else:
		if flag_sprite != null:
			flag_sprite.modulate = Color(0.45, 0.45, 0.55, 0.55)
		if flag_label != null:
			flag_label.text = "LOCKED (%d)" % _remaining_enemies
			flag_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.9))


func _show_banner(message: String, accent: Color) -> void:
	_banner_label.text = message
	_banner_label.add_theme_color_override("font_color", accent)
	_banner_panel.visible = true


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	# Top telemetry bar tucked neatly over the top wall (y=4..44)
	var top_panel := PanelContainer.new()
	top_panel.position = Vector2(24, 6)
	top_panel.size = Vector2(1232, 36)
	var top_style := StyleBoxFlat.new()
	top_style.bg_color = Color(0.05, 0.07, 0.12, 0.88)
	top_style.border_color = Color(0.2, 0.65, 0.85, 0.7)
	top_style.set_border_width_all(1)
	top_style.set_corner_radius_all(6)
	top_panel.add_theme_stylebox_override("panel", top_style)
	hud.add_child(top_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	top_panel.add_child(hbox)

	_hp_label = _make_hud_label("HP: ♥ ♥ ♥ (3/3)", Color(0.45, 1.0, 0.55), 15)
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_hp_label)

	_orb_label = _make_hud_label("ORB: READY  |  BOUNCES: 0  |  SPEED: 440 px/s  |  DMG: 15", Color(0.45, 0.95, 1.0), 15)
	_orb_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_orb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_orb_label)

	_enemies_label = _make_hud_label("ENEMIES: 3 / 3", Color(1.0, 0.6, 0.35), 15)
	_enemies_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(_enemies_label)

	# Bottom controls bar tucked over the bottom floor wall (y=678..714)
	var bottom_panel := PanelContainer.new()
	bottom_panel.position = Vector2(24, 678)
	bottom_panel.size = Vector2(1232, 36)
	bottom_panel.add_theme_stylebox_override("panel", top_style)
	hud.add_child(bottom_panel)

	var controls_label := _make_hud_label(
		"A/D: Move  |  W/Space: Jump  |  Left-Click: Fire Ricochet Orb  |  Right-Click / E: Recall Orb  |  R: Restart   —   TIP: Bank shots off the Ramp & Ceiling into the Top-Left Alcove!",
		Color(0.85, 0.92, 1.0),
		13
	)
	controls_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_panel.add_child(controls_label)

	# Center status/victory/gameover banner
	_banner_panel = PanelContainer.new()
	_banner_panel.visible = false
	_banner_panel.position = Vector2(360, 74)
	_banner_panel.size = Vector2(560, 76)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.05, 0.08, 0.14, 0.92)
	banner_style.border_color = Color(0.35, 0.95, 0.75, 0.9)
	banner_style.set_border_width_all(2)
	banner_style.set_corner_radius_all(8)
	_banner_panel.add_theme_stylebox_override("panel", banner_style)
	hud.add_child(_banner_panel)

	_banner_label = _make_hud_label("", Color.WHITE, 16)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_panel.add_child(_banner_label)


func _make_hud_label(initial_text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = initial_text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl
