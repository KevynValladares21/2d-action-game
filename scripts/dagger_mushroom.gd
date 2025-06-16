extends CharacterBody2D

var player
var chase = false
var SPEED = 50
var ATTACK_RANGE = 30
var is_attacking = false
var facing_right = true

@onready var sprite_pivot: Node2D = $SpritePivot
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _process(delta: float) -> void:
	if chase and player:
		var to_player = player.global_position - global_position
		var distance = to_player.length()

		# Only flip if not attacking and direction is clear
		if not is_attacking and abs(to_player.x) > 4:
			facing_right = to_player.x > 0
			sprite_pivot.scale.x = 1 if facing_right else -1

		if distance > ATTACK_RANGE:
			is_attacking = false
			_run(to_player)
		elif not is_attacking:
			is_attacking = true
			_attack()
	else:
		animation_player.play("Idle")
		velocity.x = 0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

func _run(to_player: Vector2):
	animation_player.play("Run")
	var dir = Vector2.ZERO
	if to_player.length() > 10:
		dir = to_player.normalized()
	velocity.x = dir.x * SPEED

func _attack():
	animation_player.play("Combo")
	velocity.x = 0

func _on_player_detection_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body
		chase = true

func _on_player_detection_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		chase = false


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Combo":
		is_attacking = false
