extends SceneTree

var _main: Node2D
var _player: CharacterBody2D
var _step: int = 0


func _process(_delta: float) -> bool:
	_step += 1

	if _step == 1:
		var mp := load("res://main.tscn") as PackedScene
		assert(mp != null, "Failed to load main.tscn")
		_main = mp.instantiate() as Node2D
		root.add_child(_main)
		return false

	if _step == 4:
		_player = _main.get_node("Player") as CharacterBody2D
		for e in _main._current_level_node.get_node("Enemies").get_children():
			e.take_damage(999)
		return false

	if _step == 6:
		assert(_main.current_level_index == 2, "Expected level 2")
		_player.take_damage(5)
		return false

	if _step == 8:
		assert(_player.hp == 0, "Expected hp == 0")
		assert(_main._game_over == true, "Expected _game_over == true")
		assert(paused == true, "Expected SceneTree.paused == true")
		print("PAUSED ON DEATH AT L2 OK: hp=%d paused=%s" % [_player.hp, paused])

		var ev := InputEventKey.new()
		ev.pressed = true
		ev.physical_keycode = KEY_R
		ev.keycode = KEY_R
		root.push_input(ev)
		return false

	if _step == 10:
		assert(paused == false, "Expected R to unpause game")
		assert(_main.current_level_index == 1, "Expected R to restart at level 1 (got %d)" % _main.current_level_index)
		assert(_main._game_over == false, "Expected _game_over == false after restart")
		assert(_player.hp == 5, "Expected player hp == 5 after restart (got %d)" % _player.hp)
		assert(_main._remaining_enemies == 3, "Expected 3 enemies after restart (got %d)" % _main._remaining_enemies)
		assert(_player.is_physics_processing(), "Expected player physics enabled after restart")
		print("R RESTART OK: level=%d hp=%d enemies=%d paused=%s physics=%s" % [
			_main.current_level_index, _player.hp, _main._remaining_enemies, paused, _player.is_physics_processing()
		])
		print("ALL R RESTART TESTS PASSED")
		_main.queue_free()
		quit(0)
		return true

	if _step > 60:
		push_error("Verification timed out")
		quit(1)
		return true

	return false
