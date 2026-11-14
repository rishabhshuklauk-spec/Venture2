extends CharacterBody2D
class_name EnergyOrb

signal orb_removed()

@export var base_speed: float = 460.0
@export var speed_per_bounce: float = 85.0
@export var max_speed: float = 1350.0
@export var base_damage: int = 20
@export var damage_per_bounce: int = 15
@export var max_bounces: int = 25

var direction: Vector2 = Vector2.RIGHT
var current_speed: float = 460.0
var current_damage: int = 20
var bounce_count: int = 0
var trail_points: Array[Vector2] = []

var _orb_color: Color = Color(0.2, 0.95, 1.0)
var _pulse_time: float = 0.0
var _is_destroyed: bool = false
var _temp_exceptions: Array[Dictionary] = []
var _trail: Line2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 5
	current_speed = base_speed
	current_damage = base_damage
	_ensure_nodes()
	_update_visual_color()
	_record_trail_point()


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
				collider.take_damage(current_damage)
			if collider is PhysicsBody2D:
				add_collision_exception_with(collider)
				_temp_exceptions.append({"body": collider, "timer": 0.06})
		elif collider != null and collider.is_in_group("player"):
			if collider.has_method("take_damage"):
				collider.take_damage(1)
			destroy_orb()
			return
		else:
			bounce_count += 1
			current_speed = minf(base_speed + bounce_count * speed_per_bounce, max_speed)
			current_damage = base_damage + bounce_count * damage_per_bounce
			collision_mask = 1 | 2 | 4
			_update_visual_color()
			_record_trail_point()
			play_sfx(self, "res://assets/Sounds/Shot Bouncing.mp3", -3.0)

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


func _ensure_nodes() -> void:
	if get_node_or_null("CollisionShape2D") == null:
		var col := CollisionShape2D.new()
		col.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = 10.0
		col.shape = shape
		add_child(col)

	_trail = get_node_or_null("Trail") as Line2D
	if _trail == null:
		_trail = Line2D.new()
		_trail.name = "Trail"
		_trail.top_level = true
		_trail.width = 9.0
		_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		_trail.antialiased = true
		add_child(_trail)


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


static func play_sfx(host: Node, path: String, volume_db: float = 0.0) -> void:
	if host == null or not is_instance_valid(host):
		return
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	var attach_target: Node = host
	if host.is_inside_tree() and host.get_tree().current_scene != null:
		attach_target = host.get_tree().current_scene
	attach_target.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
