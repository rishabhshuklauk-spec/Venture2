extends CharacterBody2D
class_name Enemy

signal enemy_died(enemy: Node2D)

const GRAVITY: float = 1200.0

@export var max_hp: int = 80
@export var enemy_title: String = "Target Core"
@export var patrol_distance: float = 64.0
@export var patrol_speed: float = 55.0

var hp: int = 80
var hit_flash_timer: float = 0.0

var _spawn_pos: Vector2 = Vector2.ZERO
var _patrol_dir: float = 1.0
var _anim_time: float = 0.0
var _is_dead: bool = false

@onready var _info_label: Label = $InfoLabel


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	hp = max_hp
	_spawn_pos = global_position
	_update_label()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_anim_time += delta
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	if patrol_distance > 0.0 and patrol_speed > 0.0:
		if is_on_wall():
			_patrol_dir *= -1.0
		elif absf(global_position.x - _spawn_pos.x) >= patrol_distance:
			if (global_position.x > _spawn_pos.x and _patrol_dir > 0.0) or (global_position.x < _spawn_pos.x and _patrol_dir < 0.0):
				_patrol_dir *= -1.0
		elif is_on_floor():
			var ahead_transform := global_transform.translated(Vector2(_patrol_dir * 20.0, 0.0))
			if not test_move(ahead_transform, Vector2(0.0, 10.0)):
				_patrol_dir *= -1.0

		velocity.x = _patrol_dir * patrol_speed
	else:
		velocity.x = 0.0

	move_and_slide()
	queue_redraw()


func take_damage(amount: int, bounces: int) -> void:
	if _is_dead:
		return
	hp = maxi(0, hp - amount)
	hit_flash_timer = 0.18
	_update_label()
	queue_redraw()

	var host: Node = get_parent() if get_parent() != null else self
	var popup_color := Color(1.0, 0.4, 0.25) if bounces > 0 else Color(0.75, 0.9, 1.0)
	var popup_text := "-%d HP (x%d Bounce!)" % [amount, bounces] if bounces > 0 else "-%d HP (Direct)" % amount
	EnergyOrb.spawn_popup(host, global_position + Vector2(0, -34), popup_text, popup_color)

	if hp <= 0:
		_is_dead = true
		emit_signal("enemy_died", self)
		queue_free()


func _update_label() -> void:
	if _info_label != null:
		_info_label.text = "%s\n%d / %d HP" % [enemy_title, hp, max_hp]


func _draw() -> void:
	var flash: bool = hit_flash_timer > 0.0
	var hull_color: Color = Color.WHITE if flash else Color(0.18, 0.2, 0.28)
	var trim_color: Color = Color(1.0, 0.35, 0.35) if flash else Color(0.95, 0.28, 0.38)
	var core_color: Color = Color.WHITE if flash else Color(1.0, 0.55, 0.18)

	# Rotating/pulsing shield ring
	var ring_r: float = 24.0 + sin(_anim_time * 4.0) * 1.5
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 28, Color(trim_color.r, trim_color.g, trim_color.b, 0.45), 2.0, true)
	var arc_start: float = _anim_time * 2.2
	draw_arc(Vector2.ZERO, ring_r + 4.0, arc_start, arc_start + 1.4, 16, trim_color, 2.5, true)
	draw_arc(Vector2.ZERO, ring_r + 4.0, arc_start + PI, arc_start + PI + 1.4, 16, trim_color, 2.5, true)

	# Sci-fi drone/turret chassis
	var body_rect := Rect2(Vector2(-17, -19), Vector2(34, 38))
	draw_rect(body_rect, hull_color, true)
	draw_rect(body_rect, trim_color, false, 2.5)

	# Inner glowing core & visor
	draw_circle(Vector2(0, -2), 9.0, Color(core_color.r, core_color.g, core_color.b, 0.35))
	draw_circle(Vector2(0, -2), 5.5, core_color)
	draw_rect(Rect2(Vector2(-10, 10), Vector2(20, 5)), trim_color, true)

	# Overhead HP bar
	var bar_width: float = 48.0
	var bar_height: float = 6.0
	var bar_pos := Vector2(-bar_width * 0.5, -34.0)
	draw_rect(Rect2(bar_pos - Vector2(1, 1), Vector2(bar_width + 2, bar_height + 2)), Color(0.05, 0.05, 0.08, 0.9), true)
	var ratio: float = clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	var hp_color := Color(0.25, 0.95, 0.45) if ratio > 0.5 else (Color(1.0, 0.8, 0.2) if ratio > 0.25 else Color(1.0, 0.25, 0.3))
	draw_rect(Rect2(bar_pos, Vector2(bar_width * ratio, bar_height)), hp_color, true)
