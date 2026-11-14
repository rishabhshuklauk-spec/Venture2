extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var direction: int = -1 # Start moving left (-1)

# Timer variables
var direction_change_timer: float = 0.0
const CHANGE_INTERVAL: float = 3.0 # Change direction every 3 seconds

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta



	direction_change_timer += delta
	if direction_change_timer >= CHANGE_INTERVAL:
		direction_change_timer = 0.0 # Reset the timer
		direction *= -1              # Flip direction (-1 becomes 1, 1 becomes -1)

	if is_on_wall():
		direction *= -1
		direction_change_timer = 0.0

	velocity.x = direction * SPEED

	move_and_slide()
