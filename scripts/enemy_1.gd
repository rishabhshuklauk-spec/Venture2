extends CharacterBody2D

const OrbScript := preload("res://scripts/energy_orb.gd")

signal enemy_died(enemy: Node2D)

@export var enemy_name: String = "AI Enemy"
@export var is_boss: bool = false
@export var max_hp: int = 60
@export var speed: float = 65.0
@export var jump_velocity: float = -480.0
@export var change_interval: float = 3.5
@export var auto_texture_path: String = ""

var hp: int = 60
var direction: int = -1
var direction_change_timer: float = 0.0
var jump_timer: float = 2.0

var _contact_cooldown: float = 0.0
var _hit_flash_timer: float = 0.0
var _is_dead: bool = false
var _base_modulate: Color = Color.WHITE

@onready var _sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	hp = max_hp
	direction = -1 if randf() < 0.5 else 1
	jump_timer = randf_range(1.4, 3.4)

	if _sprite != null:
		_base_modulate = _sprite.modulate
		if auto_texture_path != "" and ResourceLoader.exists(auto_texture_path):
			var tex := load(auto_texture_path) as Texture2D
			if tex != null:
				_sprite.texture = tex
				_base_modulate = Color.WHITE
				_sprite.modulate = Color.WHITE
				if not is_boss and tex.get_width() <= 32:
					_sprite.scale = Vector2(2.0, 2.0)
				elif is_boss and tex.get_width() >= 48:
					_sprite.scale = Vector2(1.15, 1.15)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _contact_cooldown > 0.0:
		_contact_cooldown = maxf(0.0, _contact_cooldown - delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if _sprite != null:
			_sprite.modulate = Color(1.0, 0.35, 0.35) if _hit_flash_timer > 0.0 else _base_modulate

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Slow horizontal patrol
	direction_change_timer += delta
	if direction_change_timer >= change_interval:
		direction_change_timer = 0.0
		direction *= -1

	if is_on_wall():
		direction *= -1
		direction_change_timer = 0.0
		if is_on_floor() and randf() < 0.5:
			velocity.y = jump_velocity

	# Random jumps
	jump_timer -= delta
	if jump_timer <= 0.0:
		if is_on_floor():
			velocity.y = jump_velocity
		jump_timer = randf_range(1.6, 3.8)

	velocity.x = float(direction) * speed
	if _sprite != null:
		_sprite.flip_h = direction > 0

	move_and_slide()
	_check_player_contact()


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	hp = maxi(0, hp - amount)
	_hit_flash_timer = 0.15
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.35, 0.35)
	OrbScript.play_sfx(self, "res://assets/Sounds/EnemyHit.wav", -1.0)
	queue_redraw()

	if hp <= 0:
		_is_dead = true
		emit_signal("enemy_died", self)
		queue_free()


func _check_player_contact() -> void:
	if _contact_cooldown > 0.0:
		return
	var hit_rx: float = 54.0 if is_boss else 36.0
	var hit_ry: float = 78.0 if is_boss else 46.0
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		var diff: Vector2 = p.global_position - global_position
		if absf(diff.x) <= hit_rx and absf(diff.y) <= hit_ry:
			if p.has_method("take_damage"):
				p.take_damage(1)
			_contact_cooldown = 0.8
			direction *= -1
			direction_change_timer = 0.0
			break


func _draw() -> void:
	var bar_w: float = 76.0 if is_boss else 44.0
	var bar_h: float = 7.0 if is_boss else 5.0
	var bar_y: float = -74.0 if is_boss else -42.0
	var bar_pos := Vector2(-bar_w * 0.5, bar_y)

	draw_rect(Rect2(bar_pos - Vector2(1.0, 1.0), Vector2(bar_w + 2.0, bar_h + 2.0)), Color(0.04, 0.04, 0.07, 0.92), true)
	var ratio: float = clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	var fill_color := Color(0.95, 0.28, 0.35) if is_boss else Color(1.0, 0.65, 0.25)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_color, true)

	var font := ThemeDB.fallback_font
	if font != null:
		var text_str := "%s %d/%d" % [enemy_name, hp, max_hp]
		var font_size: int = 12 if is_boss else 10
		var text_size := font.get_string_size(text_str, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos := Vector2(-text_size.x * 0.5, bar_y - 4.0)
		draw_string(font, text_pos + Vector2(1, 1), text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, 0.9))
		draw_string(font, text_pos, text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.96, 0.98, 1.0, 0.95))
