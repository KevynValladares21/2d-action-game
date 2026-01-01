extends CharacterBody2D

@onready var sprite_pivot: Node2D = $SpritePivot
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# --- Tunables ---
@export var SPEED: float = 50.0
@export var ATTACK_RANGE: float = 50.0
@export var STOP_DISTANCE: float = 10.0
@export var ATTACK_COOLDOWN_TIME: float = 2.0

# Knockback / hitstun
@export var KNOCKBACK_SPEED: float = 160.0
@export var HITSTUN_TIME: float = 0.18
@export var KNOCKBACK_FRICTION: float = 900.0

# --- Targeting ---
var player: Node2D = null

# --- FSM ---
enum State { IDLE, CHASE, ATTACK, DAMAGED, DEAD }
var state: State = State.IDLE

# --- Combat ---
var attack_cooldown: float = 0.0
var hitstun_left: float = 0.0
var knockback_vx: float = 0.0

# --- Outputs ---
var desired_vx: float = 0.0
var desired_anim: StringName = &"Idle"
var facing_right: bool = true

# --- Internal ---
var _current_anim: StringName = &""
var _to_player: Vector2 = Vector2.ZERO
var _distance: float = INF


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	if state == State.DAMAGED:
		hitstun_left = maxf(0.0, hitstun_left - delta)

	_sense()
	_decide()
	_act()

	if state != State.ATTACK and state != State.DAMAGED:
		_apply_facing()

	_play_if_changed(desired_anim)
	_apply_physics(delta)


# ------------------------------------------------
# Damage / Knockback
# ------------------------------------------------
func apply_hit(from_global_pos: Vector2) -> void:
	if state == State.DEAD:
		return

	var dir := signf(global_position.x - from_global_pos.x)
	if dir == 0.0:
		dir = -1.0 if facing_right else 1.0

	hitstun_left = HITSTUN_TIME
	knockback_vx = dir * KNOCKBACK_SPEED
	_set_state(State.DAMAGED)


# ------------------------------------------------
# Sense / Decide / Act
# ------------------------------------------------
func _sense() -> void:
	if player != null and not is_instance_valid(player):
		player = null

	if player == null:
		_distance = INF
		return

	_to_player = player.global_position - global_position
	_distance = _to_player.length()


func _decide() -> void:
	if state == State.DEAD:
		return

	if state == State.ATTACK or state == State.DAMAGED:
		return

	if player == null:
		_set_state(State.IDLE)
		return

	if _distance <= ATTACK_RANGE and attack_cooldown <= 0.0:
		_set_state(State.ATTACK)
	else:
		_set_state(State.CHASE)


func _act() -> void:
	desired_vx = 0.0
	desired_anim = &"Idle"

	match state:
		State.IDLE:
			pass

		State.CHASE:
			if _distance > STOP_DISTANCE:
				desired_vx = signf(_to_player.x) * SPEED
				desired_anim = &"Run"

		State.ATTACK:
			desired_anim = &"Combo"

		State.DAMAGED:
			desired_anim = &"Damaged"

		State.DEAD:
			desired_anim = &"Death"


# ------------------------------------------------
# State handling
# ------------------------------------------------
func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	_on_enter_state(state)


func _on_enter_state(s: State) -> void:
	match s:
		State.ATTACK:
			attack_cooldown = ATTACK_COOLDOWN_TIME

		State.DEAD:
			velocity = Vector2.ZERO

			# STOP EVERYTHING
			set_physics_process(false)
			set_process(false)

			# Disable ALL collisions safely
			_disable_all_collisions()

			_play_if_changed(&"Death")


# ------------------------------------------------
# Physics + Outputs
# ------------------------------------------------
func _apply_physics(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if state == State.DAMAGED:
		velocity.x = knockback_vx
		knockback_vx = move_toward(knockback_vx, 0.0, KNOCKBACK_FRICTION * delta)

		if hitstun_left <= 0.0:
			_set_state(State.CHASE if player != null else State.IDLE)
	else:
		velocity.x = desired_vx

	move_and_slide()


func _apply_facing() -> void:
	if player == null or absf(_to_player.x) < 2.0:
		return

	var want_right := _to_player.x > 0.0
	if want_right == facing_right:
		return

	facing_right = want_right
	sprite_pivot.scale.x = 1.0 if facing_right else -1.0


func _play_if_changed(anim: StringName) -> void:
	if anim == _current_anim:
		return
	_current_anim = anim
	animation_player.play(anim)


# ------------------------------------------------
# Collision disabling (death-safe)
# ------------------------------------------------
func _disable_all_collisions() -> void:
	_disable_collisions_recursive(self)

func _disable_collisions_recursive(node: Node) -> void:
	if node is CollisionShape2D:
		node.set_deferred("disabled", true)

	for child in node.get_children():
		_disable_collisions_recursive(child)


# ------------------------------------------------
# Signals
# ------------------------------------------------
func _on_player_detection_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body
		if state == State.IDLE:
			_set_state(State.CHASE)


func _on_player_detection_body_exited(body: Node2D) -> void:
	if body.name == "Player" and player == body:
		player = null


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Combo" and state == State.ATTACK:
		_set_state(State.CHASE if player != null else State.IDLE)

	elif anim_name == &"Damaged" and state == State.DAMAGED:
		_set_state(State.CHASE if player != null else State.IDLE)

	elif anim_name == &"Death":
		queue_free()


func _on_health_health_depleted() -> void:
	_set_state(State.DEAD)
