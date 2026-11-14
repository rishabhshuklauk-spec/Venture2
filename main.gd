extends Node2D

const OrbScript := preload("res://scripts/energy_orb.gd")

const LEVEL_PATHS: Array[String] = [
	"res://level1.tscn",
	"res://level2.tscn",
	"res://level3.tscn",
	"res://level4.tscn"
]

const MUSIC_PATHS: Array[String] = [
	"res://assets/Sounds/Level1.mp3",
	"res://assets/Sounds/Level2.mp3",
	"res://assets/Sounds/Level3.mp3",
	"res://assets/Sounds/Level4.mp3"
]

var current_level_index: int = 1
var _remaining_enemies: int = 0
var _level_cleared: bool = false
var _game_over: bool = false
var _won_game: bool = false
var _current_level_node: Node2D = null

var _music_player: AudioStreamPlayer
var _hp_label: Label
var _status_label: Label
var _enemies_label: Label
var _banner_panel: PanelContainer
var _banner_label: Label

@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	_build_hud()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = -8.0
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	if _player != null:
		_player.hp_changed.connect(_on_player_hp_changed)
		_player.player_died.connect(_on_player_died)

	_current_level_node = get_node_or_null("Level1") as Node2D
	_bind_current_level(1)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			if _won_game:
				get_tree().reload_current_scene()
			else:
				_load_level(current_level_index)


func _load_level(level_idx: int) -> void:
	if level_idx < 1 or level_idx > LEVEL_PATHS.size():
		return

	if is_instance_valid(_current_level_node):
		remove_child(_current_level_node)
		_current_level_node.queue_free()
		_current_level_node = null

	var packed := load(LEVEL_PATHS[level_idx - 1]) as PackedScene
	if packed == null:
		push_error("Failed to load level: " + LEVEL_PATHS[level_idx - 1])
		return

	var next_level := packed.instantiate() as Node2D
	next_level.name = "Level%d" % level_idx
	add_child(next_level)
	move_child(next_level, 0)
	_current_level_node = next_level
	_bind_current_level(level_idx)


func _bind_current_level(level_idx: int) -> void:
	current_level_index = level_idx
	_level_cleared = false
	_game_over = false
	_won_game = false
	_banner_panel.visible = false

	if _current_level_node == null:
		return

	var spawn := _current_level_node.get_node_or_null("PlayerSpawn") as Node2D
	var spawn_pos := spawn.global_position if spawn != null else Vector2(1020, 636)
	if _player != null:
		_player.reset_for_level(spawn_pos)

	var enemies_container := _current_level_node.get_node_or_null("Enemies")
	_remaining_enemies = 0
	if enemies_container != null:
		for enemy_node in enemies_container.get_children():
			if enemy_node.has_signal("enemy_died"):
				if not enemy_node.enemy_died.is_connected(_on_enemy_died):
					enemy_node.enemy_died.connect(_on_enemy_died)
				_remaining_enemies += 1

	var flag := _current_level_node.get_node_or_null("CheckpointFlag") as Area2D
	if flag != null:
		if not flag.body_entered.is_connected(_on_checkpoint_body_entered):
			flag.body_entered.connect(_on_checkpoint_body_entered)
		_set_flag_visual(flag, false)

	_update_hud_labels()
	_play_level_music(level_idx)


func _play_level_music(level_idx: int) -> void:
	var path := MUSIC_PATHS[clampi(level_idx - 1, 0, MUSIC_PATHS.size() - 1)]
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_music_player.stream = stream
	_music_player.play()


func _on_music_finished() -> void:
	if not _won_game and _music_player.stream != null:
		_music_player.play()


func _on_enemy_died(_enemy: Node2D) -> void:
	_remaining_enemies = maxi(0, _remaining_enemies - 1)
	if _remaining_enemies == 0 and not _level_cleared:
		_level_cleared = true
		OrbScript.play_sfx(self, "res://assets/Sounds/Level completed.wav", -1.0)
		if _player != null:
			_player.unlock_movement()
		if _current_level_node != null:
			var flag := _current_level_node.get_node_or_null("CheckpointFlag") as Area2D
			if flag != null:
				_set_flag_visual(flag, true)
	_update_hud_labels()


func _on_checkpoint_body_entered(body: Node2D) -> void:
	if body != _player or not _level_cleared or _game_over:
		return
	OrbScript.play_sfx(self, "res://assets/Sounds/NewLevel.wav", -1.0)
	if current_level_index < LEVEL_PATHS.size():
		call_deferred("_load_level", current_level_index + 1)
	else:
		_game_over = true
		_won_game = true
		_music_player.stop()
		_show_banner("ALL AI BOSSES DEFEATED! YOU WIN!\nPress [R] to Play Again", Color(0.35, 1.0, 0.7))


func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	var hearts := ""
	for i in range(max_hp):
		hearts += "♥ " if i < current_hp else "♡ "
	_hp_label.text = "HP: %s(%d/%d)" % [hearts.strip_edges(), current_hp, max_hp]
	var col := Color(0.45, 1.0, 0.55) if current_hp >= 3 else (Color(1.0, 0.8, 0.25) if current_hp == 2 else Color(1.0, 0.35, 0.35))
	_hp_label.add_theme_color_override("font_color", col)


func _on_player_died() -> void:
	_game_over = true
	_show_banner("DEFEATED! Out of HP (0/5)\nPress [R] to Restart Level %d" % current_level_index, Color(1.0, 0.35, 0.4))


func _update_hud_labels() -> void:
	if _level_cleared:
		_status_label.text = "MOVEMENT: UNLOCKED! Walk to the Flag!"
		_status_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	else:
		_status_label.text = "MOVEMENT: LOCKED (Defeat all AI to unlock!)"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))

	_enemies_label.text = "ENEMIES LEFT: %d" % _remaining_enemies
	_enemies_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65) if _remaining_enemies == 0 else Color(1.0, 0.55, 0.35))


func _set_flag_visual(flag: Area2D, unlocked: bool) -> void:
	var flag_sprite := flag.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	var flag_lbl := flag.get_node_or_null("FlagLabel") as Label
	if unlocked:
		if flag_sprite != null:
			flag_sprite.modulate = Color.WHITE
		if flag_lbl != null:
			flag_lbl.text = "WALK HERE!"
			flag_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	else:
		if flag_sprite != null:
			flag_sprite.modulate = Color(0.45, 0.45, 0.55, 0.55)
		if flag_lbl != null:
			flag_lbl.text = "LOCKED"
			flag_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.9))


func _show_banner(message: String, accent: Color) -> void:
	_banner_label.text = message
	_banner_label.add_theme_color_override("font_color", accent)
	_banner_panel.visible = true


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	var bottom_panel := PanelContainer.new()
	bottom_panel.position = Vector2(24, 674)
	bottom_panel.size = Vector2(1232, 42)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.90)
	style.border_color = Color(0.25, 0.70, 0.90, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	bottom_panel.add_theme_stylebox_override("panel", style)
	hud.add_child(bottom_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	bottom_panel.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	vbox.add_child(top_row)

	_hp_label = _make_label("HP: ♥ ♥ ♥ ♥ ♥ (5/5)", Color(0.45, 1.0, 0.55), 14)
	_hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(_hp_label)

	_status_label = _make_label("MOVEMENT: LOCKED (Defeat all AI to unlock!)", Color(1.0, 0.85, 0.35), 14)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_row.add_child(_status_label)

	_enemies_label = _make_label("ENEMIES LEFT: 3", Color(1.0, 0.55, 0.35), 14)
	_enemies_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_enemies_label)

	var controls_lbl := _make_label(
		"Left-Click: Shoot  |  Right-Click / E: Recall  |  A/D & Space: Walk to Flag (once unlocked)  |  R: Restart",
		Color(0.82, 0.90, 1.0),
		11
	)
	controls_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls_lbl)

	_banner_panel = PanelContainer.new()
	_banner_panel.visible = false
	_banner_panel.position = Vector2(340, 82)
	_banner_panel.size = Vector2(600, 74)
	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.05, 0.07, 0.13, 0.94)
	banner_style.border_color = Color(0.35, 0.95, 0.75, 0.9)
	banner_style.set_border_width_all(2)
	banner_style.set_corner_radius_all(8)
	_banner_panel.add_theme_stylebox_override("panel", banner_style)
	hud.add_child(_banner_panel)

	_banner_label = _make_label("", Color.WHITE, 16)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_panel.add_child(_banner_label)


func _make_label(text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl
