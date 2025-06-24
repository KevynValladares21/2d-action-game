extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
var is_attacking = false
var attack_switch = false
var is_dead = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $SpritePivot/Sprite2D
@onready var sprite_pivot: Node2D = $SpritePivot

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if is_dead:
		move_and_slide()  # if you want to ensure gravity still acts during death animation
		return
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY
	
	_handle_attacking()
	_handle_movement_and_animation()
	
	move_and_slide()
	
func _handle_attacking():
	# Handle Attacking
	if Input.is_action_just_pressed("primary-attack") and not is_attacking:
		is_attacking = true
		if attack_switch:
			attack_switch = false
			animation_player.play("Attack2")
		else:
			attack_switch = true
			animation_player.play("Attack1")
	
func _handle_movement_and_animation():
	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("move_left", "move_right")
	
	if not is_attacking:
		# Flip the sprite
		if direction > 0:
			sprite_pivot.scale.x = 1
		elif direction < 0:
			sprite_pivot.scale.x = -1
	
	# Play animations and handle movements
	if not is_attacking:
		if is_on_floor():
			if direction == 0:
				animation_player.play("Idle")
			else:
				animation_player.play("Run")
		else:
			if (velocity.y < 0):
				animation_player.play("Jump")
			else:
				animation_player.play("Fall")
		
		# Handle Horizontal movements
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	elif is_on_floor():
		velocity.x = 0

func _on_health_health_depleted() -> void:
	is_dead = true
	animation_player.play("Death")
	velocity = Vector2.ZERO

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Attack1" or anim_name == "Attack2":
		is_attacking = false
	elif anim_name == "Death":
		queue_free()
