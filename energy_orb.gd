extends CharacterBody2D
class_name EnergyOrb

signal stats_changed(bounces: int, speed: float, damage: int)
signal orb_removed()

@export var base_speed: float = 440.0
@export var speed_per_bounce: float = 95.0
@export var max_speed: float = 1400.0
@export var base_damage: int = 15
@export var damage_per_bounce: int = 20
@export var max_bounces: int = 25

var direction: Vector2 = Vector2.RIGHT
var current_speed: float = 440.0
var current_damage: int = 15
var bounce_count: int = 0
var trail_points: Array[Vector2] = []

var _orb_color: Color = Color(0.2, 0.95, 1.0)
var _pulse_time: float = 0.0
var _is_destroyed: bool = false
var _temp_exceptions: Array[Dictionary] = []

@onready var _trail: Line2D = $Trail


func _ready() -> void:
	collision_layer = 0
	collision_mask = 5
	current_speed = base_speed
	current_damage = base_damage
	_update_visual_color()
	if _trail != null:
		_trail.top_level = true
		_trail.width = 10.0
		_trail.default_color = _orb_color
	_record_trail_point()
	emit_signal("stats_changed", bounce_count, current_speed, current_damage)


func launch(aim_dir: Vector2) -> void:
	if aim_dir.length_squared() > 0.0001:
		direction = aim_dir.normalized()
	else:
		direction = Vector2.RIGHT
	bounce_count = 0
	current_speed = base_speed
	current_damage = base_damage
	collision_mask = 5
	_update_visual_color()
	_record_trail_point()
	emit_signal("stats_changed", bounce_count, current_speed, current_damage)


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return

	_pulse_time += delta
	_tick_temp_exceptions(delta)

	var remaining: Vector2 = direction * current_speed * delta
	for _i in range(6):
		if remaining.length_squared() < 0.0001:
			break
		var collision: KinematicCollision2D = move_and_collide(remaining)
		if collision == null:
			break

		var collider: Object = collision.get_collider()
		var normal: Vector2 = collision.get_normal()
		direction = direction.bounce(normal).normalized()
		remaining = collision.get_remainder().bounce(normal)

		if collider != null and collider.is_in_group("enemies"):
			if collider.has_method("take_damage"):
				collider.take_damage(current_damage, bounce_count)
			if collider is PhysicsBody2D:
				add_collision_exception_with(collider)
				_temp_exceptions.append({"body": collider, "timer": 0.06})
			emit_signal("stats_changed", bounce_count, current_speed, current_damage)
		elif collider != null and collider.is_in_group("player"):
			if collider.has_method("take_self_damage"):
				collider.take_self_damage(1, bounce_count)
			destroy_orb()
			return
		else:
			bounce_count += 1
			current_speed = minf(base_speed + bounce_count * speed_per_bounce, max_speed)
			current_damage = base_damage + bounce_count * damage_per_bounce
			collision_mask = 1 | 2 | 4
			_update_visual_color()
			_record_trail_point()

			var host: Node = get_parent() if get_parent() != null else self
			spawn_popup(
				host,
				global_position + Vector2(0, -18),
				"x%d BOUNCE! (%d DMG)" % [bounce_count, current_damage],
				_orb_color
			)
			emit_signal("stats_changed", bounce_count, current_speed, current_damage)

			if bounce_count > max_bounces:
				destroy_orb()
				return

	_record_trail_point()
	queue_redraw()


func destroy_orb() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	emit_signal("orb_removed")
	queue_free()


func get_orb_color() -> Color:
	return _orb_color


func _update_visual_color() -> void:
	if bounce_count == 0:
		_orb_color = Color(0.2, 0.95, 1.0)
	elif bounce_count <= 2:
		_orb_color = Color(1.0, 0.9, 0.2)
	else:
		_orb_color = Color(1.0, 0.25, 0.4)
	if _trail != null:
		_trail.default_color = Color(_orb_color.r, _orb_color.g, _orb_color.b, 0.65)


func _record_trail_point() -> void:
	trail_points.append(global_position)
	if trail_points.size() > 16:
		trail_points.remove_at(0)
	if _trail != null:
		_trail.points = PackedVector2Array(trail_points)


func _tick_temp_exceptions(delta: float) -> void:
	for idx in range(_temp_exceptions.size() - 1, -1, -1):
		var entry: Dictionary = _temp_exceptions[idx]
		entry["timer"] = float(entry["timer"]) - delta
		if entry["timer"] <= 0.0:
			var body: Variant = entry["body"]
			if is_instance_valid(body) and body is PhysicsBody2D:
				remove_collision_exception_with(body)
			_temp_exceptions.remove_at(idx)


func _draw() -> void:
	var pulse: float = 1.0 + sin(_pulse_time * 16.0) * 0.14
	var outer_radius: float = 13.0 * pulse
	draw_circle(Vector2.ZERO, outer_radius + 4.0, Color(_orb_color.r, _orb_color.g, _orb_color.b, 0.25))
	draw_arc(Vector2.ZERO, outer_radius, 0.0, TAU, 24, _orb_color, 3.0, true)
	draw_circle(Vector2.ZERO, 7.5, _orb_color)
	draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
	if bounce_count >= 1:
		draw_arc(Vector2.ZERO, outer_radius + 2.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.55), 1.5, true)


static func spawn_popup(host: Node, world_pos: Vector2, text: String, color: Color) -> void:
	if host == null or not is_instance_valid(host):
		return
	var label := Label.new()
	label.text = text
	label.position = world_pos - Vector2(60, 12)
	label.z_index = 50
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	host.add_child(label)

	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 34.0, 0.65)
	tween.tween_property(label, "modulate:a", 0.0, 0.65)
	tween.chain().tween_callback(label.queue_free)
