extends Node2D

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

@onready var _player: CharacterBody2D = $Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	_music_player.volume_db = -8.0
	_music_player.finished.connect(_on_music_finished)
	add_child(_music_player)

	if _player != null:
		_player.process_mode = Node.PROCESS_MODE_PAUSABLE
		_player.hp_changed.connect(_on_player_hp_changed)
		_player.player_died.connect(_on_player_died)

	_current_level_node = get_node_or_null("Level1") as Node2D
	if _current_level_node != null:
		_current_level_node.process_mode = Node.PROCESS_MODE_PAUSABLE
	_bind_current_level(1, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R or event.keycode == KEY_R:
			get_tree().paused = false
			_load_level(1, true)


func _load_level(level_idx: int, reset_hp: bool = false) -> void:
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
	next_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(next_level)
	move_child(next_level, 0)
	_current_level_node = next_level
	_bind_current_level(level_idx, reset_hp)


func _bind_current_level(level_idx: int, reset_hp: bool = false) -> void:
	current_level_index = level_idx
	_level_cleared = false
	_game_over = false
	_won_game = false

	if _current_level_node == null:
		return

	var spawn := _current_level_node.get_node_or_null("PlayerSpawn") as Node2D
	var spawn_pos := spawn.global_position if spawn != null else Vector2(1020, 636)
	if _player != null:
		_player.reset_for_level(spawn_pos, reset_hp)

	var enemies_container := _current_level_node.get_node_or_null("Enemies")
	_remaining_enemies = 0
	if enemies_container != null:
		for enemy_node in enemies_container.get_children():
			if enemy_node.has_signal("enemy_died"):
				if not enemy_node.enemy_died.is_connected(_on_enemy_died):
					enemy_node.enemy_died.connect(_on_enemy_died)
				_remaining_enemies += 1

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
		if current_level_index < LEVEL_PATHS.size():
			_play_sfx("res://assets/Sounds/Level completed.wav", -1.0)
			_play_sfx("res://assets/Sounds/NewLevel.wav", -1.0)
			call_deferred("_load_level", current_level_index + 1, false)
		else:
			_play_sfx("res://assets/Sounds/Level completed.wav", -1.0)
			_game_over = true
			_won_game = true
			_music_player.stop()
			if _player != null:
				_player.recall_active_orb()
				_player.set_physics_process(false)
				_player.set_process_unhandled_input(false)
			get_tree().paused = true


func _on_player_hp_changed(current_hp: int, max_hp: int) -> void:
	var hearts := ""
	for i in range(max_hp):
		hearts += "♥ " if i < current_hp else "♡ "
	_hp_label.text = "HP: %s(%d/%d)" % [hearts.strip_edges(), current_hp, max_hp]
	var col := Color(0.45, 1.0, 0.55) if current_hp >= 3 else (Color(1.0, 0.8, 0.25) if current_hp == 2 else Color(1.0, 0.35, 0.35))
	_hp_label.add_theme_color_override("font_color", col)


func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	_music_player.stop()
	if _player != null:
		_player.recall_active_orb()
		_player.set_physics_process(false)
		_player.set_process_unhandled_input(false)
	get_tree().paused = true


func _play_sfx(path: String, volume_db: float = 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	var sfx := AudioStreamPlayer.new()
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	sfx.stream = stream
	sfx.volume_db = volume_db
	add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	var bottom_panel := PanelContainer.new()
	bottom_panel.position = Vector2(24, 676)
	bottom_panel.size = Vector2(240, 36)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.10, 0.90)
	style.border_color = Color(0.25, 0.70, 0.90, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	bottom_panel.add_theme_stylebox_override("panel", style)
	hud.add_child(bottom_panel)

	_hp_label = _make_label("HP: ♥ ♥ ♥ ♥ ♥ (5/5)", Color(0.45, 1.0, 0.55), 14)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_panel.add_child(_hp_label)


func _make_label(text: String, color: Color, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl
