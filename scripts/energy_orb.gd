extends CharacterBody2D

signal orb_removed()

@export var base_speed: float = 480.0
@export var speed_per_bounce: float = 95.0
@export var max_speed: float = 900.0
@export var base_damage: int = 25
@export var damage_per_bounce: int = 15
@export var max_bounces: int = 3

var direction: Vector2 = Vector2.RIGHT
var current_speed: float = 480.0
var current_damage: int = 25
var bounce_count: int = 0

var _orb_color: Color = Color(0.2, 0.95, 1.0)
var _is_destroyed: bool = false
var _temp_exceptions: Array[Dictionary] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 4
	current_speed = base_speed
	current_damage = base_damage
	_ensure_nodes()
	_update_visual_color()
	queue_redraw()


func launch(aim_dir: Vector2) -> void:
	if aim_dir.length_squared() > 0.0001:
		direction = aim_dir.normalized()
	else:
		direction = Vector2.RIGHT
	bounce_count = 0
	current_speed = base_speed
	current_damage = base_damage
	collision_mask = 1 | 4
	_update_visual_color()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return

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
		else:
			bounce_count += 1
			if bounce_count > max_bounces:
				destroy_orb()
				return
			current_speed = minf(base_speed + bounce_count * speed_per_bounce, max_speed)
			current_damage = base_damage + bounce_count * damage_per_bounce
			_update_visual_color()
			queue_redraw()
			_play_sfx("res://assets/Sounds/Shot Bouncing.mp3", -3.0)


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
		shape.radius = 9.0
		col.shape = shape
		add_child(col)


func _update_visual_color() -> void:
	if bounce_count == 0:
		_orb_color = Color(0.2, 0.95, 1.0)
	elif bounce_count == 1:
		_orb_color = Color(1.0, 0.9, 0.2)
	elif bounce_count == 2:
		_orb_color = Color(1.0, 0.55, 0.2)
	else:
		_orb_color = Color(1.0, 0.25, 0.4)


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
	draw_circle(Vector2.ZERO, 9.0, _orb_color)
	draw_circle(Vector2.ZERO, 4.5, Color.WHITE)


func _play_sfx(path: String, volume_db: float = 0.0) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = volume_db
	var host: Node = self
	if is_inside_tree():
		if get_tree().current_scene != null:
			host = get_tree().current_scene
		elif get_tree().root.get_node_or_null("Main") != null:
			host = get_tree().root.get_node("Main")
		else:
			host = get_tree().root
	host.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
