extends CharacterBody2D
class_name Player

signal orb_fired(orb: EnergyOrb)
signal orb_recalled()
signal hp_changed(current: int, maximum: int)
signal player_died()

const SPEED: float = 310.0
const ACCEL: float = 2400.0
const FRICTION: float = 2000.0
const JUMP_VELOCITY: float = -680.0
const GRAVITY: float = 1350.0
const COYOTE_TIME: float = 0.12
const ORB_SCENE: PackedScene = preload("res://energy_orb.tscn")

@export var max_hp: int = 3

var current_hp: int = 3
var invuln_timer: float = 0.0
var active_orb: EnergyOrb = null

var _coyote_timer: float = 0.0
var _hit_anim_timer: float = 0.0
var _aim_dir: Vector2 = Vector2.LEFT
var _is_dead: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	current_hp = max_hp
	_ensure_input_actions()
	emit_signal("hp_changed", current_hp, max_hp)


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event.is_action_pressed("fire_orb"):
		_try_fire_orb()
	elif event.is_action_pressed("recall_orb"):
		recall_active_orb()


func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		move_and_slide()
		return

	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
		_sprite.modulate.a = 0.45 if int(invuln_timer * 18.0) % 2 == 0 else 1.0
	else:
		_sprite.modulate.a = 1.0

	if _hit_anim_timer > 0.0:
		_hit_anim_timer = maxf(0.0, _hit_anim_timer - delta)

	# Gravity & coyote time
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - delta)
		velocity.y += GRAVITY * delta

	# Jump with variable jump cut
	if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0
	elif Input.is_action_just_released("jump") and velocity.y < -180.0:
		velocity.y *= 0.5

	# Horizontal movement
	var move_axis: float = Input.get_axis("move_left", "move_right")
	if not is_zero_approx(move_axis):
		velocity.x = move_toward(velocity.x, move_axis * SPEED, ACCEL * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	move_and_slide()

	# Aim toward mouse
	var to_mouse: Vector2 = get_global_mouse_position() - _get_muzzle_origin()
	if to_mouse.length_squared() > 1.0:
		_aim_dir = to_mouse.normalized()

	_update_animation()
	queue_redraw()


func fire_orb_toward(target_world_pos: Vector2) -> EnergyOrb:
	var origin := _get_muzzle_origin()
	var dir := target_world_pos - origin
	if dir.length_squared() > 0.01:
		_aim_dir = dir.normalized()
	return _try_fire_orb()


func recall_active_orb() -> void:
	if is_instance_valid(active_orb):
		active_orb.destroy_orb()
		active_orb = null
		emit_signal("orb_recalled")


func take_self_damage(amount: int, _bounces: int) -> void:
	if _is_dead or invuln_timer > 0.0:
		return
	current_hp = maxi(0, current_hp - amount)
	invuln_timer = 1.0
	_hit_anim_timer = 0.35

	var host: Node = get_parent() if get_parent() != null else self
	EnergyOrb.spawn_popup(host, global_position + Vector2(0, -40), "-%d HP! DODGE YOUR ORB!" % amount, Color(1.0, 0.25, 0.3))
	emit_signal("hp_changed", current_hp, max_hp)

	if current_hp <= 0:
		_is_dead = true
		_sprite.modulate = Color(1.0, 0.45, 0.45, 0.85)
		emit_signal("player_died")


func _try_fire_orb() -> EnergyOrb:
	if is_instance_valid(active_orb):
		var host: Node = get_parent() if get_parent() != null else self
		EnergyOrb.spawn_popup(host, global_position + Vector2(0, -42), "ORB ACTIVE! (Right-Click / E to Recall)", Color(1.0, 0.85, 0.3))
		return null

	var spawn_pos: Vector2 = _get_safe_muzzle_spawn()
	var orb := ORB_SCENE.instantiate() as EnergyOrb
	var parent_node: Node = get_parent() if get_parent() != null else self
	parent_node.add_child(orb)
	orb.global_position = spawn_pos
	orb.launch(_aim_dir)
	orb.orb_removed.connect(_on_active_orb_removed)
	active_orb = orb
	emit_signal("orb_fired", orb)
	return orb


func _on_active_orb_removed() -> void:
	active_orb = null
	emit_signal("orb_recalled")


func _get_muzzle_origin() -> Vector2:
	return global_position + Vector2(0.0, 2.0)


func _get_safe_muzzle_spawn() -> Vector2:
	var origin: Vector2 = _get_muzzle_origin()
	var desired: Vector2 = origin + _aim_dir * 18.0
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return desired
	var query := PhysicsRayQueryParameters2D.create(origin, desired, 1)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	return origin + _aim_dir * maxf(2.0, origin.distance_to(hit.position) - 11.0)


func _update_animation() -> void:
	if _sprite == null:
		return
	if absf(_aim_dir.x) > 0.05:
		_sprite.flip_h = _aim_dir.x < 0.0
	elif absf(velocity.x) > 10.0:
		_sprite.flip_h = velocity.x < 0.0

	var target_anim := "idle"
	if _hit_anim_timer > 0.0:
		target_anim = "hit"
	elif not is_on_floor():
		target_anim = "jump"
	elif absf(velocity.x) > 18.0:
		target_anim = "run"

	if _sprite.animation != target_anim:
		_sprite.play(target_anim)


func _draw() -> void:
	if _is_dead:
		return

	# Weapon barrel / aim pointer
	var muzzle_local: Vector2 = Vector2(0.0, 2.0) + _aim_dir * 22.0
	draw_line(Vector2(0.0, 2.0) + _aim_dir * 10.0, muzzle_local, Color(0.75, 0.9, 1.0), 4.0, true)
	var tip_color := Color(0.25, 0.95, 1.0) if not is_instance_valid(active_orb) else Color(1.0, 0.6, 0.25)
	draw_circle(muzzle_local, 4.0, tip_color)

	# Draw multi-bounce trajectory preview when orb is ready to fire
	if not is_instance_valid(active_orb):
		_draw_ricochet_preview()


func _draw_ricochet_preview() -> void:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return

	var ray_origin: Vector2 = _get_safe_muzzle_spawn()
	var ray_dir: Vector2 = _aim_dir
	var segment_colors: Array[Color] = [
		Color(0.2, 0.95, 1.0, 0.75),
		Color(1.0, 0.9, 0.2, 0.65),
		Color(1.0, 0.45, 0.2, 0.55),
		Color(1.0, 0.25, 0.45, 0.45)
	]

	for bounce_idx in range(4):
		var col: Color = segment_colors[mini(bounce_idx, segment_colors.size() - 1)]
		var query := PhysicsRayQueryParameters2D.create(ray_origin, ray_origin + ray_dir * 1800.0, 1 | 4)
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			_draw_dashed_line(to_local(ray_origin), to_local(ray_origin + ray_dir * 700.0), col)
			break

		var hit_pos: Vector2 = hit.position
		var hit_normal: Vector2 = hit.normal
		var collider: Object = hit.collider

		_draw_dashed_line(to_local(ray_origin), to_local(hit_pos), col)

		if collider != null and collider.is_in_group("enemies"):
			draw_arc(to_local(hit_pos), 10.0, 0.0, TAU, 20, Color(1.0, 0.3, 0.3, 0.95), 2.5, true)
			draw_circle(to_local(hit_pos), 4.0, Color(1.0, 0.3, 0.3, 0.95))
			break

		draw_circle(to_local(hit_pos), 4.0, col)
		ray_dir = ray_dir.bounce(hit_normal).normalized()
		ray_origin = hit_pos + hit_normal * 1.5


func _draw_dashed_line(from_local: Vector2, to_local_pos: Vector2, color: Color) -> void:
	var delta_vec := to_local_pos - from_local
	var total_len := delta_vec.length()
	if total_len < 2.0:
		return
	var step_dir := delta_vec / total_len
	var dash_len: float = 10.0
	var gap_len: float = 8.0
	var dist: float = 0.0
	while dist < total_len:
		var seg_end := minf(dist + dash_len, total_len)
		draw_line(from_local + step_dir * dist, from_local + step_dir * seg_end, color, 2.0, true)
		dist += dash_len + gap_len


func _ensure_input_actions() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("jump", [KEY_W, KEY_SPACE, KEY_UP])
	_add_key_action("recall_orb", [KEY_E])
	_add_mouse_action("fire_orb", MOUSE_BUTTON_LEFT)
	_add_mouse_action("recall_orb", MOUSE_BUTTON_RIGHT)


func _add_key_action(action_name: String, keys: Array[Key]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		if not InputMap.action_has_event(action_name, ev):
			InputMap.action_add_event(action_name, ev)


func _add_mouse_action(action_name: String, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	if not InputMap.action_has_event(action_name, ev):
		InputMap.action_add_event(action_name, ev)
