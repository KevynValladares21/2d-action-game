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

# --- Outputs (computed each tick) ---
var desired_vx: float = 0.0
var desired_anim: StringName = &"Idle"
var facing_right: bool = true

# --- Internal helpers ---
var _current_anim: StringName = &""
var _to_player: Vector2 = Vector2.ZERO
var _distance: float = INF


func _physics_process(delta: float) -> void:
	# Tick cooldown
	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	# Tick hitstun timer (even if no target)
	if state == State.DAMAGED:
		hitstun_left = maxf(0.0, hitstun_left - delta)

	# Sense
	_sense()

	# Decide (transitions)
	_decide()

	# Act (compute outputs for current state)
	_act()

	# Apply facing (only if not attacking or damaged)
	if state != State.ATTACK and state != State.DAMAGED:
		_apply_facing()

	# Apply animation (only changes when needed)
	_play_if_changed(desired_anim)

	# Apply movement in physics time
	_apply_physics(delta)


# -------------------------
# Hit / Knockback entry point
# -------------------------
# Call this from your hurtbox/health logic when the enemy is hit.
# Example: enemy.apply_hit(attacker.global_position)
func apply_hit(from_global_pos: Vector2) -> void:
	if state == State.DEAD:
		return

	var dir := signf(global_position.x - from_global_pos.x)
	if dir == 0.0:
		dir = -1.0 if facing_right else 1.0

	hitstun_left = HITSTUN_TIME
	knockback_vx = dir * KNOCKBACK_SPEED
	_set_state(State.DAMAGED)


# -------------------------
# Sense / Decide / Act
# -------------------------

func _sense() -> void:
	# Validate target reference (prevents stale pointers)
	if player != null and not is_instance_valid(player):
		player = null

	if player == null:
		_to_player = Vector2.ZERO
		_distance = INF
		return

	_to_player = player.global_position - global_position
	_distance = _to_player.length()


func _decide() -> void:
	# Dead is terminal
	if state == State.DEAD:
		return

	# If we're in a committed action, don't re-decide mid-action
	if state == State.ATTACK or state == State.DAMAGED:
		return

	# No target -> Idle
	if player == null:
		_set_state(State.IDLE)
		return

	var in_attack_range := _distance <= ATTACK_RANGE
	var can_attack := attack_cooldown <= 0.0

	if in_attack_range and can_attack:
		_set_state(State.ATTACK)
	else:
		_set_state(State.CHASE)


func _act() -> void:
	# Default outputs (so every tick is deterministic)
	desired_vx = 0.0
	desired_anim = &"Idle"

	match state:
		State.IDLE:
			desired_vx = 0.0
			desired_anim = &"Idle"

		State.CHASE:
			# If close enough, stop and idle (prevents boundary jitter)
			if _distance <= STOP_DISTANCE:
				desired_vx = 0.0
				desired_anim = &"Idle"
			else:
				desired_vx = signf(_to_player.x) * SPEED
				desired_anim = &"Run"

		State.ATTACK:
			# Attack commits: no movement until animation finishes
			desired_vx = 0.0
			desired_anim = &"Combo"

		State.DAMAGED:
			# Hitstun commits briefly: knockback handled in physics (don’t overwrite vx)
			desired_vx = 0.0
			desired_anim = &"Damaged"

		State.DEAD:
			desired_vx = 0.0
			desired_anim = &"Death"


# -------------------------
# State transitions
# -------------------------

func _set_state(new_state: State) -> void:
	if new_state == state:
		return

	state = new_state
	_on_enter_state(state)


func _on_enter_state(s: State) -> void:
	match s:
		State.ATTACK:
			# Start cooldown when attack starts (simple + consistent)
			attack_cooldown = ATTACK_COOLDOWN_TIME
		State.DEAD:
			# Hard stop
			velocity = Vector2.ZERO


# -------------------------
# Outputs
# -------------------------

func _apply_facing() -> void:
	# Only update facing if target direction is meaningful
	if player == null:
		return
	if absf(_to_player.x) < 2.0:
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


func _apply_physics(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if state == State.DAMAGED:
		# Use knockback channel + decay it
		velocity.x = knockback_vx
		knockback_vx = move_toward(knockback_vx, 0.0, KNOCKBACK_FRICTION * delta)

		# End by timer (this avoids animation-length problems)
		if hitstun_left <= 0.0:
			if player != null and is_instance_valid(player):
				_set_state(State.CHASE)
			else:
				_set_state(State.IDLE)
	else:
		velocity.x = desired_vx

	move_and_slide()


# -------------------------
# Signals
# -------------------------

func _on_player_detection_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player = body
		# If we were idle, wake up immediately (don’t override ATTACK/DAMAGED)
		if state == State.IDLE:
			_set_state(State.CHASE)


func _on_player_detection_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		# Clear target; decision layer will go IDLE next tick (unless attacking/damaged)
		if player == body:
			player = null


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"Combo" and state == State.ATTACK:
		# After attack, resume chasing if target still exists
		if player != null and is_instance_valid(player):
			_set_state(State.CHASE)
		else:
			_set_state(State.IDLE)

	elif anim_name == &"Damaged" and state == State.DAMAGED:
		# End hitstun on animation finish (time-based end also exists in physics)
		if player != null and is_instance_valid(player):
			_set_state(State.CHASE)
		else:
			_set_state(State.IDLE)

	elif anim_name == &"Death":
		queue_free()


func _on_health_health_depleted() -> void:
	_set_state(State.DEAD)
