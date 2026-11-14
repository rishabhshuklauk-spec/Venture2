extends CharacterBody2D

const OrbScript := preload("res://scripts/energy_orb.gd")

signal hp_changed(current_hp: int, max_hp: int)
signal player_died()
signal orb_fired(orb: CharacterBody2D)

const MAX_HP: int = 5
const SPEED: float = 300.0
const JUMP_VELOCITY: float = -650.0

var hp: int = MAX_HP
var invuln_timer: float = 0.0
var movement_locked: bool = true
var active_orb: CharacterBody2D = null

var _hit_anim_timer: float = 0.0
var _aim_dir: Vector2 = Vector2.LEFT
var _is_dead: bool = false

@onready var _sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	hp = MAX_HP
	_ensure_input_actions()
	emit_signal("hp_changed", hp, MAX_HP)


func _unhandled_input(event: InputEvent) -> void:
	if _is_dead:
		return
	if event.is_action_pressed("fire_orb"):
		_try_fire_orb()
	elif event.is_action_pressed("recall_orb"):
		recall_active_orb()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if invuln_timer > 0.0:
		invuln_timer = maxf(0.0, invuln_timer - delta)
		if _sprite != null:
			_sprite.modulate.a = 0.4 if int(invuln_timer * 18.0) % 2 == 0 else 1.0
	elif _sprite != null and not _is_dead:
		_sprite.modulate.a = 1.0

	if _hit_anim_timer > 0.0:
		_hit_anim_timer = maxf(0.0, _hit_anim_timer - delta)

	if _is_dead:
		velocity.x = 0.0
		move_and_slide()
		return

	if movement_locked:
		velocity.x = 0.0
	else:
		if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")) and is_on_floor():
			velocity.y = JUMP_VELOCITY

		var direction := Input.get_axis("move_left", "move_right")
		if is_zero_approx(direction):
			direction = Input.get_axis("ui_left", "ui_right")

		if not is_zero_approx(direction):
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0.0, SPEED)

	move_and_slide()

	var to_mouse := get_global_mouse_position() - _get_muzzle_origin()
	if to_mouse.length_squared() > 1.0:
		_aim_dir = to_mouse.normalized()

	_update_animation()
	queue_redraw()


func lock_movement() -> void:
	movement_locked = true
	velocity.x = 0.0
	queue_redraw()


func unlock_movement() -> void:
	movement_locked = false
	queue_redraw()


func reset_for_level(spawn_pos: Vector2) -> void:
	recall_active_orb()
	global_position = spawn_pos
	velocity = Vector2.ZERO
	hp = MAX_HP
	invuln_timer = 0.0
	_hit_anim_timer = 0.0
	_is_dead = false
	movement_locked = true
	if _sprite != null:
		_sprite.modulate = Color.WHITE
	emit_signal("hp_changed", hp, MAX_HP)
	queue_redraw()


func fire_orb_toward(target_world_pos: Vector2) -> CharacterBody2D:
	var to_target := target_world_pos - _get_muzzle_origin()
	if to_target.length_squared() > 0.01:
		_aim_dir = to_target.normalized()
	return _try_fire_orb()


func recall_active_orb() -> void:
	if is_instance_valid(active_orb):
		active_orb.destroy_orb()
		active_orb = null


func take_damage(amount: int = 1) -> void:
	if _is_dead or invuln_timer > 0.0:
		return
	hp = maxi(0, hp - amount)
	invuln_timer = 1.0
	_hit_anim_timer = 0.35
	OrbScript.play_sfx(self, "res://assets/Sounds/PlayerHit.wav", 0.0)
	emit_signal("hp_changed", hp, MAX_HP)

	if hp <= 0:
		_is_dead = true
		if _sprite != null:
			_sprite.modulate = Color(1.0, 0.4, 0.4, 0.85)
		emit_signal("player_died")


func _try_fire_orb() -> CharacterBody2D:
	if is_instance_valid(active_orb):
		return null

	var spawn_pos := _get_safe_muzzle_spawn()
	var orb := OrbScript.new()
	var host := get_parent() if get_parent() != null else self
	host.add_child(orb)
	orb.global_position = spawn_pos
	orb.launch(_aim_dir)
	orb.orb_removed.connect(_on_active_orb_removed)
	active_orb = orb
	OrbScript.play_sfx(self, "res://assets/Sounds/InitialShot.wav", -1.0)
	emit_signal("orb_fired", orb)
	return orb


func _on_active_orb_removed() -> void:
	active_orb = null


func _get_muzzle_origin() -> Vector2:
	return global_position + Vector2(0.0, 2.0)


func _get_safe_muzzle_spawn() -> Vector2:
	var origin := _get_muzzle_origin()
	var desired := origin + _aim_dir * 18.0
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
	elif absf(velocity.x) > 12.0:
		target_anim = "run"

	if _sprite.animation != target_anim:
		_sprite.play(target_anim)


func _draw() -> void:
	if _is_dead:
		return

	var muzzle_local := Vector2(0.0, 2.0) + _aim_dir * 22.0
	draw_line(Vector2(0.0, 2.0) + _aim_dir * 10.0, muzzle_local, Color(0.75, 0.9, 1.0), 4.0, true)
	var tip_color := Color(0.25, 0.95, 1.0) if not is_instance_valid(active_orb) else Color(1.0, 0.6, 0.25)
	draw_circle(muzzle_local, 4.0, tip_color)

	if movement_locked and not is_instance_valid(active_orb):
		_draw_ricochet_preview()


func _draw_ricochet_preview() -> void:
	var space_state := get_world_2d().direct_space_state
	if space_state == null:
		return

	var ray_origin := _get_safe_muzzle_spawn()
	var ray_dir := _aim_dir
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
