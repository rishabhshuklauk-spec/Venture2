extends CharacterBody2D

const OrbScript := preload("res://scripts/energy_orb.gd")

signal hp_changed(current_hp: int, max_hp: int)
signal player_died()
signal orb_fired(orb: CharacterBody2D)

const MAX_HP: int = 5

var hp: int = MAX_HP
var invuln_timer: float = 0.0
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

	velocity.x = 0.0
	move_and_slide()

	if _is_dead:
		return

	var to_mouse := get_global_mouse_position() - _get_muzzle_origin()
	if to_mouse.length_squared() > 1.0:
		_aim_dir = to_mouse.normalized()

	_update_animation()
	queue_redraw()


func reset_for_level(spawn_pos: Vector2) -> void:
	recall_active_orb()
	global_position = spawn_pos
	velocity = Vector2.ZERO
	hp = MAX_HP
	invuln_timer = 0.0
	_hit_anim_timer = 0.0
	_is_dead = false
	set_physics_process(true)
	set_process_unhandled_input(true)
	if _sprite != null:
		_sprite.modulate = Color.WHITE
	emit_signal("hp_changed", hp, MAX_HP)
	queue_redraw()


func fire_orb_toward(target_world_pos: Vector2) -> CharacterBody2D:
	var to_target := target_world_pos - _get_muzzle_origin()
	if to_target.length_squared() > 0.01:
		_aim_dir = to_target.normalized()
	queue_redraw()
	return _try_fire_orb()


func recall_active_orb() -> void:
	if is_instance_valid(active_orb):
		active_orb.destroy_orb()
		active_orb = null
	queue_redraw()


func take_damage(amount: int = 1) -> void:
	if _is_dead or invuln_timer > 0.0:
		return
	hp = maxi(0, hp - amount)
	invuln_timer = 1.0
	_hit_anim_timer = 0.35
	emit_signal("hp_changed", hp, MAX_HP)

	if hp <= 0:
		_is_dead = true
		if _sprite != null:
			_sprite.modulate = Color(1.0, 0.4, 0.4, 0.85)
		_play_sfx("res://assets/Sounds/PlayerDeath.mp3", 0.0)
		queue_redraw()
		emit_signal("player_died")
	else:
		_play_sfx("res://assets/Sounds/PlayerHit.wav", 0.0)


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
	_play_sfx("res://assets/Sounds/InitialShot.wav", -1.0)
	emit_signal("orb_fired", orb)
	queue_redraw()
	return orb


func _on_active_orb_removed() -> void:
	active_orb = null
	queue_redraw()


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
	return origin + _aim_dir * maxf(2.0, origin.distance_to(hit.position) - 10.0)


func _update_animation() -> void:
	if _sprite == null:
		return
	if absf(_aim_dir.x) > 0.05:
		_sprite.flip_h = _aim_dir.x < 0.0

	var target_anim := "idle"
	if _hit_anim_timer > 0.0:
		target_anim = "hit"
	elif not is_on_floor():
		target_anim = "jump"

	if _sprite.animation != target_anim:
		_sprite.play(target_anim)


func _draw() -> void:
	if _is_dead:
		return
	var origin := Vector2(0.0, 2.0)
	var start := origin + _aim_dir * 16.0
	var tip := origin + _aim_dir * 46.0
	var ortho := Vector2(-_aim_dir.y, _aim_dir.x)
	var arrow_color := Color(0.35, 0.95, 1.0, 0.9) if not is_instance_valid(active_orb) else Color(1.0, 0.65, 0.25, 0.6)
	draw_line(start, tip, arrow_color, 3.0, true)
	draw_line(tip, tip - _aim_dir * 10.0 + ortho * 6.0, arrow_color, 3.0, true)
	draw_line(tip, tip - _aim_dir * 10.0 - ortho * 6.0, arrow_color, 3.0, true)


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


func _ensure_input_actions() -> void:
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
