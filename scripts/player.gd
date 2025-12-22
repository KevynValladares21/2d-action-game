extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
var is_attacking = false
var attack_switch = false
var is_dead = false

var knockback_velocity := Vector2.ZERO

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $SpritePivot/Sprite2D
@onready var sprite_pivot: Node2D = $SpritePivot
@onready var healthbar = $CanvasLayer/Healthbar
@onready var hurtbox = $HurtBox

func _ready():
	hurtbox.received_damage.connect(_on_player_damaged)
	healthbar.init_health(hurtbox.health.health)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if is_dead:
		move_and_slide()
		return
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY
	
	# integrate knockback into motion
	if knockback_velocity != Vector2.ZERO:
		velocity.x = knockback_velocity.x
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 2000.0 * delta)
	else:
		_handle_attacking()
		_handle_movement_and_animation()
	
	move_and_slide()
	
func _handle_attacking():
	if Input.is_action_just_pressed("primary-attack") and not is_attacking:
		is_attacking = true
		if attack_switch:
			attack_switch = false
			animation_player.play("Attack2")
		else:
			attack_switch = true
			animation_player.play("Attack1")
	
func _handle_movement_and_animation():
	var direction := Input.get_axis("move_left", "move_right")
	
	if not is_attacking:
		if direction > 0:
			sprite_pivot.scale.x = 1
		elif direction < 0:
			sprite_pivot.scale.x = -1
	
	if not is_attacking:
		if is_on_floor():
			if direction == 0:
				animation_player.play("Idle")
			else:
				animation_player.play("Run")
		else:
			if velocity.y < 0:
				animation_player.play("Jump")
			else:
				animation_player.play("Fall")
		
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	elif is_on_floor():
		velocity.x = 0

func _on_health_health_depleted() -> void:
	is_dead = true
	animation_player.play("Death")
	# velocity = Vector2.ZERO   # optional: comment this out so lethal hits still shove

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Attack1" or anim_name == "Attack2":
		is_attacking = false
	elif anim_name == "Death":
		queue_free()
		
func apply_hit(from_pos: Vector2, strength := 150.0) -> void:
	# decide which way to push the player based on where the enemy is
	var sx := global_position.x - from_pos.x
	var dir_sign := 0
	if sx > 0:
		dir_sign = 1
	elif sx < 0:
		dir_sign = -1
	else:
		dir_sign = int(sign($SpritePivot.scale.x))
		if dir_sign == 0:
			dir_sign = 1
	
	# instead of setting velocity directly, store it here
	knockback_velocity = Vector2(dir_sign * strength, 0)
	animation_player.play("Hit")

func _on_player_damaged(amount: int):
	healthbar.health = hurtbox.health.health
