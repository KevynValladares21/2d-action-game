extends CharacterBody2D

# -------------------------
# Tunables
# -------------------------
@export var SPEED: float = 130.0
@export var JUMP_VELOCITY: float = -300.0

# Knockback / hitstun
@export var HITSTUN_TIME: float = 0.12
@export var KNOCKBACK_FRICTION: float = 2200.0

# Ground friction (when no input)
@export var GROUND_DECEL: float = 1200.0
@export var AIR_DECEL: float = 600.0

# -------------------------
# Nodes
# -------------------------
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_pivot: Node2D = $SpritePivot
@onready var healthbar = $CanvasLayer/Healthbar
@onready var hurtbox = $HurtBox

# -------------------------
# FSM
# -------------------------
enum State { IDLE, RUN, JUMP, FALL, ATTACK, HIT, DEAD }
var state: State = State.IDLE

var facing_right: bool = true

# Combo
var attack_switch: bool = false
var attack_anim: StringName = &"Attack1" # currently playing attack anim (Attack1/Attack2)

# Knockback channel
var knockback_vx: float = 0.0
var hitstun_left: float = 0.0

# Animation control (prevents restarting every frame)
var _current_anim: StringName = &""

# Cached input each physics tick
var _move_axis: float = 0.0
var _jump_pressed: bool = false
var _attack_pressed: bool = false


func _ready() -> void:
	hurtbox.received_damage.connect(_on_player_damaged)
	healthbar.init_health(hurtbox.health.health)


func _physics_process(delta: float) -> void:
	# 1) Gather input (one place)
	_move_axis = Input.get_axis("move_left", "move_right")
	_jump_pressed = Input.is_action_just_pressed("jump")
	_attack_pressed = Input.is_action_just_pressed("primary-attack")

	# 2) Gravity (unless you want corpse physics, keep it; otherwise gate on DEAD)
	if state != State.DEAD and not is_on_floor():
		velocity += get_gravity() * delta

	# 3) Tick hitstun timer
	if state == State.HIT:
		hitstun_left = maxf(0.0, hitstun_left - delta)

	# 4) Decide transitions (state changes)
	_decide_state()

	# 5) Apply facing (don’t flip during attack/hit/death)
	if state != State.ATTACK and state != State.HIT and state != State.DEAD:
		_apply_facing_from_input()

	# 6) Act (movement + animation)
	_act(delta)

	# 7) Move
	move_and_slide()


# -------------------------
# Decide
# -------------------------
func _decide_state() -> void:
	# DEAD is terminal
	if state == State.DEAD:
		return

	# HIT is “committed” until timer (or animation, but timer is more reliable)
	if state == State.HIT:
		if hitstun_left <= 0.0:
			# Return to locomotion state based on current physics
			_set_state(_locomotion_state())
		return

	# ATTACK is “committed” until animation_finished
	if state == State.ATTACK:
		return

	# Start attack
	if _attack_pressed and state != State.ATTACK and state != State.HIT:
		_start_attack()
		return

	# Jump (only if not attacking/hit)
	if _jump_pressed and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_set_state(State.JUMP)
		return

	# Otherwise locomotion
	_set_state(_locomotion_state())


func _locomotion_state() -> State:
	if not is_on_floor():
		return State.JUMP if velocity.y < 0.0 else State.FALL
	return State.IDLE if is_zero_approx(_move_axis) else State.RUN


# -------------------------
# Act
# -------------------------
func _act(delta: float) -> void:
	match state:
		State.IDLE:
			_play_if_changed(&"Idle")
			velocity.x = move_toward(velocity.x, 0.0, GROUND_DECEL * delta)

		State.RUN:
			_play_if_changed(&"Run")
			velocity.x = _move_axis * SPEED

		State.JUMP:
			_play_if_changed(&"Jump")
			# Air control (keep it simple; same speed as ground)
			if not is_zero_approx(_move_axis):
				velocity.x = _move_axis * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0.0, AIR_DECEL * delta)

		State.FALL:
			_play_if_changed(&"Fall")
			if not is_zero_approx(_move_axis):
				velocity.x = _move_axis * SPEED
			else:
				velocity.x = move_toward(velocity.x, 0.0, AIR_DECEL * delta)

		State.ATTACK:
			_play_if_changed(attack_anim)
			# Lock movement during attack (like your original)
			if is_on_floor():
				velocity.x = 0.0
			else:
				# Optional: allow tiny air drift if you want; otherwise keep 0
				velocity.x = 0.0

		State.HIT:
			_play_if_changed(&"Hit")
			# Knockback channel drives vx; decay it
			velocity.x = knockback_vx
			knockback_vx = move_toward(knockback_vx, 0.0, KNOCKBACK_FRICTION * delta)

		State.DEAD:
			_play_if_changed(&"Death")
			# Optional: keep physics on death; if not, hard stop x:
			velocity.x = 0.0


# -------------------------
# Attack
# -------------------------
func _start_attack() -> void:
	_set_state(State.ATTACK)

	# Choose which attack animation to play
	if attack_switch:
		attack_switch = false
		attack_anim = &"Attack2"
	else:
		attack_switch = true
		attack_anim = &"Attack1"

	_play_if_changed(attack_anim)


# -------------------------
# Facing + animations
# -------------------------
func _apply_facing_from_input() -> void:
	if is_zero_approx(_move_axis):
		return

	facing_right = _move_axis > 0.0
	sprite_pivot.scale.x = 1.0 if facing_right else -1.0


func _play_if_changed(anim: StringName) -> void:
	if anim == _current_anim:
		return
	_current_anim = anim
	animation_player.play(anim)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state


# -------------------------
# Damage / death hooks
# -------------------------
func apply_hit(from_pos: Vector2, strength := 150.0) -> void:
	if state == State.DEAD:
		return

	# Interrupt attacks on hit (feels better in most action games)
	_set_state(State.HIT)

	# Decide knockback direction away from attacker
	var sx := global_position.x - from_pos.x
	var dir_sign := 0.0
	if sx > 0.0:
		dir_sign = 1.0
	elif sx < 0.0:
		dir_sign = -1.0
	else:
		dir_sign = 1.0 if facing_right else -1.0

	# Start hitstun + knockback channel
	hitstun_left = HITSTUN_TIME
	knockback_vx = dir_sign * strength

	_play_if_changed(&"Hit")


func _on_health_health_depleted() -> void:
	_set_state(State.DEAD)
	_play_if_changed(&"Death")
	# If you want lethal hits to still shove, don't zero velocity here.


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	# End attack when its animation ends
	if (anim_name == &"Attack1" or anim_name == &"Attack2") and state == State.ATTACK:
		_set_state(_locomotion_state())

	elif anim_name == &"Death":
		queue_free()

func _on_player_damaged(amount: int) -> void:
	healthbar.health = hurtbox.health.health
