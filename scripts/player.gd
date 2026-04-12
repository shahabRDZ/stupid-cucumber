extends CharacterBody2D

## Stupid Cucumber - Main character controller
## Sonic-style momentum physics + clumsy cucumber personality
## Enhanced visuals with detailed _draw, particles, and powerup effects

signal died

# ---------------------------------------------------------------------------
# Movement constants - Sonic-style momentum
# ---------------------------------------------------------------------------
const GROUND_ACCEL: float = 600.0
const GROUND_DECEL: float = 800.0
const AIR_ACCEL: float = 400.0
const MAX_SPEED: float = 450.0
const MAX_SPEED_CHILI: float = 900.0
const JUMP_VELOCITY: float = -520.0
const GRAVITY: float = 1200.0
const MAX_FALL_SPEED: float = 800.0

# Oil boost
const OIL_SPEED_MULT: float = 1.3
const OIL_FRICTION_MULT: float = 0.4

# Clumsy mechanics
const STUMBLE_CHANCE: float = 0.003
const STUMBLE_FORCE: float = 80.0
const SLIP_FACTOR: float = 0.15

# Timing
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER_TIME: float = 0.1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
enum State { IDLE, RUN, JUMP, FALL, STUMBLE, BURNED, DEAD }
var current_state: State = State.IDLE
var facing_right: bool = true
var stumble_timer: float = 0.0
var is_on_ground_last_frame: bool = false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

# Chili burn state
var burn_speed_mult: float = 1.0
var burn_control_penalty: float = 1.0
var burn_wobble: float = 0.0

# ---------------------------------------------------------------------------
# Visual state
# ---------------------------------------------------------------------------
var body_color: Color = Color(0.3, 0.75, 0.2)
var dark_green: Color = Color(0.2, 0.55, 0.12)
var light_green: Color = Color(0.45, 0.85, 0.35)
var belly_color: Color = Color(0.5, 0.88, 0.42)
var eye_white: Color = Color(0.97, 0.97, 0.97)
var iris_color: Color = Color(0.15, 0.55, 0.15)
var pupil_color: Color = Color(0.08, 0.08, 0.08)
var burn_color: Color = Color(1.0, 0.3, 0.1)
var shoe_color: Color = Color(0.55, 0.22, 0.08)
var bandaid_color: Color = Color(0.92, 0.78, 0.6)

var base_scale: Vector2 = Vector2(1.0, 1.0)
var squash_stretch: Vector2 = Vector2(1.0, 1.0)
var eye_offset: Vector2 = Vector2.ZERO
var rotation_wobble: float = 0.0

# Animation timing
var anim_time: float = 0.0
var blink_timer: float = 0.0
var blink_duration: float = 0.12
var is_blinking: bool = false
var blush_timer: float = 0.0
var landing_dust_timer: float = 0.0
var leaf_bounce: float = 0.0

# Stumble stars
var stumble_star_angle: float = 0.0

# ---------------------------------------------------------------------------
# Particles
# ---------------------------------------------------------------------------
var fire_particles: GPUParticles2D = null
var dust_particles: GPUParticles2D = null
var star_particles: GPUParticles2D = null

# ---------------------------------------------------------------------------
# Touch controls (set by HUD)
# ---------------------------------------------------------------------------
var touch_left: bool = false
var touch_right: bool = false
var touch_jump: bool = false


# ===========================================================================
# LIFECYCLE
# ===========================================================================

func _ready() -> void:
	GameManager.chili_activated.connect(_on_chili_activated)
	GameManager.chili_ended.connect(_on_chili_ended)
	GameManager.shield_activated.connect(_on_shield_activated)
	GameManager.shield_ended.connect(_on_shield_ended)
	GameManager.oil_activated.connect(_on_oil_activated)
	GameManager.oil_ended.connect(_on_oil_ended)

	_create_fire_particles()
	_create_dust_particles()
	_create_star_particles()

	# Start first blink cycle
	blink_timer = randf_range(2.0, 5.0)


func _physics_process(delta: float) -> void:
	anim_time += delta

	if current_state == State.DEAD:
		velocity.y += GRAVITY * delta
		move_and_slide()
		queue_redraw()
		return

	# Input
	var input_dir: float = _get_input_direction()
	var jump_pressed: bool = _is_jump_pressed()

	# Coyote time
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer -= delta

	# Jump buffer
	if jump_pressed:
		jump_buffer_timer = JUMP_BUFFER_TIME
	else:
		jump_buffer_timer -= delta

	# Gravity
	if not is_on_floor():
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)

	# Max speed calculation
	var current_max_speed: float = MAX_SPEED * burn_speed_mult
	if GameManager.is_oil_active:
		current_max_speed *= OIL_SPEED_MULT

	# Horizontal movement - Sonic-style momentum
	if input_dir != 0:
		var accel: float = GROUND_ACCEL if is_on_floor() else AIR_ACCEL
		accel *= burn_control_penalty

		if sign(velocity.x) == sign(input_dir) or velocity.x == 0:
			velocity.x = move_toward(velocity.x, input_dir * current_max_speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, GROUND_DECEL * 1.5 * delta)
	else:
		var decel: float = GROUND_DECEL if is_on_floor() else GROUND_DECEL * 0.3
		if GameManager.is_oil_active:
			decel *= OIL_FRICTION_MULT
		velocity.x = move_toward(velocity.x, 0, decel * delta)

	# Jump
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0
		squash_stretch = Vector2(0.7, 1.3)

	# Variable jump height
	if not _is_jump_held() and velocity.y < 0:
		velocity.y *= 0.92

	# Clumsy stumble
	if is_on_floor() and abs(velocity.x) > 100 and current_state != State.STUMBLE:
		if randf() < STUMBLE_CHANCE:
			_trigger_stumble()

	# Stumble timer
	if current_state == State.STUMBLE:
		stumble_timer -= delta
		stumble_star_angle += delta * 6.0
		if stumble_timer <= 0:
			current_state = State.RUN if abs(velocity.x) > 10 else State.IDLE
			star_particles.emitting = false

	# Landing detection
	if is_on_floor() and not is_on_ground_last_frame:
		if abs(velocity.x) > 200:
			squash_stretch = Vector2(1.3, 0.7)
		landing_dust_timer = 0.25

	is_on_ground_last_frame = is_on_floor()

	# Landing dust countdown
	if landing_dust_timer > 0:
		landing_dust_timer -= delta

	# Facing
	if velocity.x > 10:
		facing_right = true
	elif velocity.x < -10:
		facing_right = false

	# Chili burn wobble
	if GameManager.is_chili_active:
		burn_wobble += delta * 20.0
		rotation_wobble = sin(burn_wobble) * 0.15 * GameManager.chili_stacks

	# Squash/stretch recovery
	squash_stretch = squash_stretch.lerp(Vector2(1.0, 1.0), delta * 8.0)

	# Eye tracking
	var target_eye_x: float = sign(velocity.x) * 3.0
	var target_eye_y: float = 0.0
	if velocity.y < -100:
		target_eye_y = -2.0
	elif velocity.y > 100:
		target_eye_y = 2.0
	eye_offset = eye_offset.lerp(Vector2(target_eye_x, target_eye_y), delta * 5.0)

	# Blink
	if is_blinking:
		blink_duration -= delta
		if blink_duration <= 0:
			is_blinking = false
			blink_timer = randf_range(2.0, 5.0)
	else:
		blink_timer -= delta
		if blink_timer <= 0:
			is_blinking = true
			blink_duration = 0.12

	# Blush fade
	if blush_timer > 0:
		blush_timer -= delta

	# Leaf bounce
	var leaf_target: float = sin(anim_time * 3.0) * 0.15
	if abs(velocity.x) > 100:
		leaf_target = sin(anim_time * 8.0) * 0.3
	leaf_bounce = lerpf(leaf_bounce, leaf_target, delta * 6.0)

	# Dust particles
	var moving_fast_on_ground: bool = is_on_floor() and abs(velocity.x) > 150
	dust_particles.emitting = moving_fast_on_ground

	# Update state
	_update_state()

	# Move
	move_and_slide()

	# Track distance
	if velocity.x > 0:
		GameManager.add_distance(velocity.x * delta * 0.01)

	# Fell off screen
	if global_position.y > 1000:
		die()

	queue_redraw()


# ===========================================================================
# STATE
# ===========================================================================

func _update_state() -> void:
	if current_state == State.DEAD or current_state == State.STUMBLE:
		return

	if not is_on_floor():
		current_state = State.JUMP if velocity.y < 0 else State.FALL
	elif abs(velocity.x) > 10:
		current_state = State.BURNED if GameManager.is_chili_active else State.RUN
	else:
		current_state = State.IDLE


func _trigger_stumble() -> void:
	current_state = State.STUMBLE
	stumble_timer = 0.4
	stumble_star_angle = 0.0
	velocity.x *= 0.5
	velocity.y = -150
	rotation_wobble = 0.3 * (1 if randf() > 0.5 else -1)
	squash_stretch = Vector2(1.2, 0.8)
	star_particles.emitting = true


# ===========================================================================
# INPUT
# ===========================================================================

func _get_input_direction() -> float:
	var dir: float = Input.get_axis("move_left", "move_right")
	if touch_left:
		dir -= 1.0
	if touch_right:
		dir += 1.0
	return clampf(dir, -1.0, 1.0)


func _is_jump_pressed() -> bool:
	var pressed: bool = Input.is_action_just_pressed("jump") or touch_jump
	return pressed


func _is_jump_held() -> bool:
	return Input.is_action_pressed("jump")


# ===========================================================================
# CALLBACKS
# ===========================================================================

func _on_chili_activated(_duration: float) -> void:
	var stacks: int = GameManager.chili_stacks
	burn_speed_mult = 1.0 + stacks * 0.5
	burn_control_penalty = 1.0 - stacks * 0.15
	fire_particles.emitting = true
	fire_particles.amount = 10 + stacks * 10


func _on_chili_ended() -> void:
	burn_speed_mult = 1.0
	burn_control_penalty = 1.0
	burn_wobble = 0.0
	rotation_wobble = 0.0
	fire_particles.emitting = false


func _on_shield_activated() -> void:
	pass


func _on_shield_ended() -> void:
	pass


func _on_oil_activated() -> void:
	pass


func _on_oil_ended() -> void:
	pass


# ===========================================================================
# PUBLIC METHODS (called by collectibles / obstacles)
# ===========================================================================

func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	velocity = Vector2(0, JUMP_VELOCITY * 0.7)
	dust_particles.emitting = false
	star_particles.emitting = false
	died.emit()
	GameManager.trigger_game_over()


func collect_salt() -> void:
	GameManager.add_salt(1)
	squash_stretch = Vector2(0.85, 1.15)
	blush_timer = 0.6


func collect_chili() -> void:
	GameManager.activate_chili()
	squash_stretch = Vector2(0.6, 1.4)


func collect_yogurt() -> void:
	GameManager.activate_shield()
	squash_stretch = Vector2(0.9, 1.1)
	blush_timer = 0.8


func collect_oil() -> void:
	GameManager.activate_oil()
	squash_stretch = Vector2(1.1, 0.9)


func take_hit() -> void:
	if GameManager.is_shield_active:
		GameManager.use_shield_hit()
		squash_stretch = Vector2(1.3, 0.7)
	else:
		die()


# ===========================================================================
# PARTICLE SETUP
# ===========================================================================

func _create_fire_particles() -> void:
	fire_particles = GPUParticles2D.new()
	fire_particles.emitting = false
	fire_particles.amount = 20
	fire_particles.lifetime = 0.6
	fire_particles.position = Vector2(0, -10)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, -50, 0)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 0.4, 0.0, 0.8)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.8, 0.0, 1.0))
	gradient.set_color(1, Color(1.0, 0.1, 0.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	fire_particles.process_material = mat
	add_child(fire_particles)


func _create_dust_particles() -> void:
	dust_particles = GPUParticles2D.new()
	dust_particles.emitting = false
	dust_particles.amount = 8
	dust_particles.lifetime = 0.5
	dust_particles.position = Vector2(0, 30)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 35.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.5
	mat.damping_min = 10.0
	mat.damping_max = 20.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.75, 0.65, 0.5, 0.6))
	gradient.set_color(1, Color(0.8, 0.7, 0.55, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	dust_particles.process_material = mat
	add_child(dust_particles)


func _create_star_particles() -> void:
	star_particles = GPUParticles2D.new()
	star_particles.emitting = false
	star_particles.amount = 6
	star_particles.lifetime = 0.8
	star_particles.position = Vector2(0, -30)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 1.5
	mat.scale_max = 3.0

	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 0.3, 1.0))
	gradient.set_color(1, Color(1.0, 0.8, 0.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	star_particles.process_material = mat
	add_child(star_particles)


# ===========================================================================
# DRAWING
# ===========================================================================

func _draw() -> void:
	var flip: float = -1.0 if not facing_right else 1.0

	draw_set_transform(Vector2.ZERO, rotation_wobble, squash_stretch)

	# --- SHADOW ---
	_draw_filled_ellipse(Vector2(0, 32), Vector2(20, 6), Color(0, 0, 0, 0.18))

	# Body tint from status effects
	var cur_body: Color = body_color
	var cur_dark: Color = dark_green
	var cur_light: Color = light_green
	var cur_belly: Color = belly_color

	if GameManager.is_chili_active:
		var burn_t: float = float(GameManager.chili_stacks) / float(GameManager.MAX_CHILI_STACKS)
		cur_body = body_color.lerp(burn_color, burn_t * 0.55)
		cur_dark = dark_green.lerp(burn_color.darkened(0.2), burn_t * 0.5)
		cur_light = light_green.lerp(Color(1.0, 0.5, 0.2), burn_t * 0.4)
		cur_belly = belly_color.lerp(Color(1.0, 0.6, 0.3), burn_t * 0.3)

	if GameManager.is_oil_active:
		var oil_sheen: Color = Color(0.95, 0.88, 0.4, 0.15)
		cur_body = cur_body.lerp(oil_sheen, 0.2)
		cur_light = cur_light.lerp(Color(1.0, 0.95, 0.6), 0.25)

	# -----------------------------------------------------------------------
	# OIL GLOW (drawn behind body)
	# -----------------------------------------------------------------------
	if GameManager.is_oil_active:
		var oil_alpha: float = 0.08 + sin(anim_time * 4.0) * 0.04
		_draw_filled_ellipse(Vector2(0, 0), Vector2(28, 36), Color(0.95, 0.85, 0.3, oil_alpha))

	# -----------------------------------------------------------------------
	# LEGS (behind body)
	# -----------------------------------------------------------------------
	_draw_legs(flip, cur_body)

	# -----------------------------------------------------------------------
	# CUCUMBER BODY
	# -----------------------------------------------------------------------
	# Outer dark edge (gives depth)
	_draw_filled_ellipse(Vector2(0, 0), Vector2(19, 27), cur_dark)
	# Main body
	_draw_filled_ellipse(Vector2(0, 0), Vector2(17, 25), cur_body)
	# Left highlight band (gives cylindrical look)
	_draw_filled_ellipse(Vector2(-5 * flip, -2), Vector2(7, 18), cur_light)
	# Center belly (lighter area)
	_draw_filled_ellipse(Vector2(2 * flip, 3), Vector2(9, 14), cur_belly)
	# Top highlight (round top)
	_draw_filled_ellipse(Vector2(-2 * flip, -14), Vector2(8, 6), cur_light.lightened(0.1))
	# Bottom darker area
	_draw_filled_ellipse(Vector2(0, 16), Vector2(12, 7), cur_dark.lerp(cur_body, 0.5))

	# Bumps / warts
	var bump_c: Color = cur_body.darkened(0.12)
	var bump_h: Color = cur_body.lightened(0.1)
	# Right side bumps
	draw_circle(Vector2(10 * flip, -10), 3.0, bump_c)
	draw_circle(Vector2(10 * flip, -10) + Vector2(-0.8, -0.8), 1.2, bump_h)
	draw_circle(Vector2(12 * flip, 2), 2.5, bump_c)
	draw_circle(Vector2(12 * flip, 2) + Vector2(-0.6, -0.6), 1.0, bump_h)
	draw_circle(Vector2(8 * flip, 12), 2.2, bump_c)
	draw_circle(Vector2(8 * flip, 12) + Vector2(-0.5, -0.5), 0.8, bump_h)
	# Left side bumps
	draw_circle(Vector2(-9 * flip, -5), 2.0, bump_c)
	draw_circle(Vector2(-11 * flip, 7), 2.5, bump_c)
	draw_circle(Vector2(-11 * flip, 7) + Vector2(-0.6, -0.6), 1.0, bump_h)
	draw_circle(Vector2(-7 * flip, 15), 1.8, bump_c)
	# Extra scattered small bumps
	draw_circle(Vector2(5 * flip, -17), 1.5, bump_c)
	draw_circle(Vector2(-4 * flip, -16), 1.3, bump_c)
	draw_circle(Vector2(14 * flip, -3), 1.8, bump_c)

	# -----------------------------------------------------------------------
	# BANDAID (clumsy detail!)
	# -----------------------------------------------------------------------
	_draw_bandaid(Vector2(-8 * flip, 8), 0.4 * flip)

	# -----------------------------------------------------------------------
	# STEM & LEAF on top
	# -----------------------------------------------------------------------
	_draw_stem_and_leaf(flip)

	# -----------------------------------------------------------------------
	# ARMS
	# -----------------------------------------------------------------------
	_draw_arms(flip, cur_body)

	# -----------------------------------------------------------------------
	# FACE
	# -----------------------------------------------------------------------
	_draw_face(flip)

	# -----------------------------------------------------------------------
	# SHIELD (yogurt bubble)
	# -----------------------------------------------------------------------
	if GameManager.is_shield_active:
		_draw_shield()

	# -----------------------------------------------------------------------
	# OIL DRIP TRAIL (small drops on body)
	# -----------------------------------------------------------------------
	if GameManager.is_oil_active:
		_draw_oil_drips()

	# -----------------------------------------------------------------------
	# STUMBLE STARS
	# -----------------------------------------------------------------------
	if current_state == State.STUMBLE:
		_draw_stumble_stars()

	# -----------------------------------------------------------------------
	# SWEAT DROPS (when going fast)
	# -----------------------------------------------------------------------
	if abs(velocity.x) > 300 and current_state != State.DEAD:
		_draw_sweat_drops(flip)

	# -----------------------------------------------------------------------
	# CHILI STEAM FROM EARS
	# -----------------------------------------------------------------------
	if GameManager.is_chili_active:
		_draw_chili_steam(flip)

	# -----------------------------------------------------------------------
	# LANDING DUST RING
	# -----------------------------------------------------------------------
	if landing_dust_timer > 0:
		_draw_landing_dust()

	# -----------------------------------------------------------------------
	# BLUSH (after collecting items)
	# -----------------------------------------------------------------------
	if blush_timer > 0:
		_draw_blush(flip)

	# Reset
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# ===========================================================================
# DRAW HELPERS - BODY PARTS
# ===========================================================================

func _draw_stem_and_leaf(flip: float) -> void:
	var stem_base: Vector2 = Vector2(0, -26)
	var stem_top: Vector2 = Vector2(2 * flip, -34)
	var stem_color: Color = Color(0.2, 0.5, 0.1)
	var leaf_color: Color = Color(0.25, 0.65, 0.15)

	# Stem
	draw_line(stem_base, stem_top, stem_color, 3.0)

	# Leaf (bounces with movement)
	var leaf_rot: float = leaf_bounce
	var leaf_tip: Vector2 = stem_top + Vector2(cos(leaf_rot) * 10 * flip, sin(leaf_rot) * -6 - 4)
	var leaf_mid: Vector2 = stem_top + Vector2(cos(leaf_rot) * 5 * flip, sin(leaf_rot) * -3 - 5)

	var leaf_points: PackedVector2Array = PackedVector2Array()
	leaf_points.append(stem_top)
	leaf_points.append(leaf_mid + Vector2(0, 3))
	leaf_points.append(leaf_tip)
	leaf_points.append(leaf_mid + Vector2(0, -3))
	if leaf_points.size() >= 3:
		draw_colored_polygon(leaf_points, leaf_color)
	# Leaf vein
	draw_line(stem_top, leaf_tip, stem_color, 1.0)


func _draw_bandaid(pos: Vector2, angle: float) -> void:
	# Simple cross-shaped bandaid
	var bw: float = 8.0
	var bh: float = 3.5
	var c: float = cos(angle)
	var s: float = sin(angle)

	# Horizontal strip
	var h_points: PackedVector2Array = PackedVector2Array()
	h_points.append(pos + Vector2(-bw * c - (-bh) * s, -bw * s + (-bh) * c))
	h_points.append(pos + Vector2(bw * c - (-bh) * s, bw * s + (-bh) * c))
	h_points.append(pos + Vector2(bw * c - bh * s, bw * s + bh * c))
	h_points.append(pos + Vector2(-bw * c - bh * s, -bw * s + bh * c))
	draw_colored_polygon(h_points, bandaid_color)

	# Little dots on bandaid
	draw_circle(pos + Vector2(-3 * c, -3 * s), 0.7, bandaid_color.darkened(0.2))
	draw_circle(pos + Vector2(3 * c, 3 * s), 0.7, bandaid_color.darkened(0.2))
	draw_circle(pos, 0.7, bandaid_color.darkened(0.2))


func _draw_legs(flip: float, body_col: Color) -> void:
	var speed_ratio: float = clampf(abs(velocity.x) / MAX_SPEED, 0.0, 1.0)
	var leg_cycle: float = anim_time * (6.0 + speed_ratio * 10.0)
	var leg_swing: float = sin(leg_cycle) * (4.0 + speed_ratio * 10.0) if abs(velocity.x) > 10 else 0.0
	var leg_y: float = 22.0
	var leg_color: Color = body_col.darkened(0.18)

	# Left leg
	var l_hip: Vector2 = Vector2(-6, leg_y)
	var l_knee: Vector2 = Vector2(-7 + leg_swing * 0.5, leg_y + 8)
	var l_foot: Vector2 = Vector2(-8 + leg_swing, leg_y + 16)
	# Thigh
	draw_line(l_hip, l_knee, leg_color, 4.0)
	# Shin
	draw_line(l_knee, l_foot, leg_color, 3.5)
	# Shoe
	_draw_shoe(l_foot, flip, leg_swing > 0)

	# Right leg (opposite phase)
	var r_hip: Vector2 = Vector2(6, leg_y)
	var r_knee: Vector2 = Vector2(7 - leg_swing * 0.5, leg_y + 8)
	var r_foot: Vector2 = Vector2(8 - leg_swing, leg_y + 16)
	draw_line(r_hip, r_knee, leg_color, 4.0)
	draw_line(r_knee, r_foot, leg_color, 3.5)
	_draw_shoe(r_foot, flip, leg_swing < 0)


func _draw_shoe(pos: Vector2, flip: float, is_forward: bool) -> void:
	var shoe_w: float = 6.0
	var shoe_h: float = 4.0
	var offset_x: float = 2.0 * flip if is_forward else -1.0 * flip
	# Shoe body
	_draw_filled_ellipse(pos + Vector2(offset_x, 1), Vector2(shoe_w, shoe_h), shoe_color)
	# Shoe sole (darker)
	_draw_filled_ellipse(pos + Vector2(offset_x, 3), Vector2(shoe_w + 0.5, 2), shoe_color.darkened(0.3))
	# Shoe highlight
	_draw_filled_ellipse(pos + Vector2(offset_x - 1, -0.5), Vector2(3, 2), shoe_color.lightened(0.15))


func _draw_arms(flip: float, body_col: Color) -> void:
	var arm_color: Color = body_col.darkened(0.12)
	var hand_color: Color = body_col.lightened(0.05)
	var speed_ratio: float = clampf(abs(velocity.x) / MAX_SPEED, 0.0, 1.0)
	var arm_cycle: float = anim_time * (5.0 + speed_ratio * 8.0)

	var l_shoulder: Vector2 = Vector2(-15, -2)
	var r_shoulder: Vector2 = Vector2(15, -2)

	var l_swing: float = 0.0
	var r_swing: float = 0.0
	var l_vert: float = 0.0
	var r_vert: float = 0.0

	match current_state:
		State.FALL:
			# Arms flailing up
			l_swing = sin(anim_time * 12.0) * 8.0
			r_swing = sin(anim_time * 12.0 + PI) * 8.0
			l_vert = -12.0 + sin(anim_time * 10.0) * 4.0
			r_vert = -12.0 + sin(anim_time * 10.0 + PI) * 4.0
		State.JUMP:
			# Arms reaching up
			l_swing = -4.0
			r_swing = 4.0
			l_vert = -10.0
			r_vert = -10.0
		State.STUMBLE:
			# Arms out for balance
			l_swing = -10.0 + sin(anim_time * 8.0) * 5.0
			r_swing = 10.0 + sin(anim_time * 8.0 + 1.0) * 5.0
			l_vert = -5.0
			r_vert = -5.0
		State.RUN, State.BURNED:
			l_swing = sin(arm_cycle) * (5.0 + speed_ratio * 8.0)
			r_swing = sin(arm_cycle + PI) * (5.0 + speed_ratio * 8.0)
			l_vert = 4.0 + sin(arm_cycle) * 3.0
			r_vert = 4.0 + sin(arm_cycle + PI) * 3.0
		_:
			# Idle: gentle sway
			l_swing = sin(anim_time * 1.5) * 2.0
			r_swing = sin(anim_time * 1.5 + 0.5) * 2.0
			l_vert = 6.0
			r_vert = 6.0

	# Left arm
	var l_elbow: Vector2 = l_shoulder + Vector2(-4 + l_swing * 0.5, 6 + l_vert * 0.5)
	var l_hand: Vector2 = l_shoulder + Vector2(-6 + l_swing, 10 + l_vert)
	draw_line(l_shoulder, l_elbow, arm_color, 3.0)
	draw_line(l_elbow, l_hand, arm_color, 2.5)
	_draw_hand(l_hand, hand_color, -1.0)

	# Right arm
	var r_elbow: Vector2 = r_shoulder + Vector2(4 + r_swing * 0.5, 6 + r_vert * 0.5)
	var r_hand: Vector2 = r_shoulder + Vector2(6 + r_swing, 10 + r_vert)
	draw_line(r_shoulder, r_elbow, arm_color, 3.0)
	draw_line(r_elbow, r_hand, arm_color, 2.5)
	_draw_hand(r_hand, hand_color, 1.0)


func _draw_hand(pos: Vector2, color: Color, side: float) -> void:
	# Palm
	draw_circle(pos, 3.0, color)
	# Three fingers
	var finger_len: float = 3.0
	draw_line(pos, pos + Vector2(-1.5 * side, -finger_len), color, 1.5)
	draw_line(pos, pos + Vector2(0.5 * side, -finger_len - 1.0), color, 1.5)
	draw_line(pos, pos + Vector2(2.0 * side, -finger_len + 0.5), color, 1.5)


# ===========================================================================
# DRAW HELPERS - FACE
# ===========================================================================

func _draw_face(flip: float) -> void:
	var face_y: float = -4.0

	var left_eye_pos: Vector2 = Vector2(-7 * flip, face_y) + eye_offset
	var right_eye_pos: Vector2 = Vector2(7 * flip, face_y) + eye_offset

	# ----- EYES -----
	if current_state == State.DEAD:
		# X eyes
		_draw_x_eye(left_eye_pos, 5.0)
		_draw_x_eye(right_eye_pos, 4.0)
	elif current_state == State.STUMBLE:
		# Spiral dizzy eyes
		_draw_spiral_eye(left_eye_pos, 5.0, anim_time * 6.0)
		_draw_spiral_eye(right_eye_pos, 4.0, anim_time * 6.0 + PI)
	elif is_blinking:
		# Closed eyes (lines)
		draw_line(left_eye_pos + Vector2(-5, 0), left_eye_pos + Vector2(5, 0), pupil_color, 2.0)
		draw_line(right_eye_pos + Vector2(-4, 0), right_eye_pos + Vector2(4, 0), pupil_color, 2.0)
	else:
		# Normal eyes
		# Whites
		_draw_filled_ellipse(left_eye_pos, Vector2(7, 8), eye_white)
		_draw_filled_ellipse(right_eye_pos, Vector2(6, 7), eye_white)

		# Eyelid shading (top of eye, darker)
		var lid_col: Color = Color(0.85, 0.85, 0.85, 0.3)
		_draw_filled_ellipse(left_eye_pos + Vector2(0, -3), Vector2(7, 4), lid_col)
		_draw_filled_ellipse(right_eye_pos + Vector2(0, -3), Vector2(6, 3.5), lid_col)

		# Irises
		var pupil_shift: Vector2 = Vector2(sign(velocity.x) * 2.0, 0)
		_draw_filled_ellipse(left_eye_pos + pupil_shift, Vector2(4.0, 4.5), iris_color)
		_draw_filled_ellipse(right_eye_pos + pupil_shift + Vector2(0.5, 0.5), Vector2(3.0, 3.5), iris_color)

		# Pupils (different sizes for goofy look)
		draw_circle(left_eye_pos + pupil_shift, 2.5, pupil_color)
		draw_circle(right_eye_pos + pupil_shift + Vector2(0.5, 0.5), 1.8, pupil_color)

		# Shine highlights
		draw_circle(left_eye_pos + pupil_shift + Vector2(-1.5, -2.0), 1.5, Color.WHITE)
		draw_circle(left_eye_pos + pupil_shift + Vector2(1.0, 1.0), 0.6, Color(1, 1, 1, 0.6))
		draw_circle(right_eye_pos + pupil_shift + Vector2(-1.0, -1.5), 1.0, Color.WHITE)

		# Eyelids that change with state
		_draw_eyelids(left_eye_pos, right_eye_pos, flip)

	# ----- EYEBROWS -----
	_draw_eyebrows(left_eye_pos, right_eye_pos, flip)

	# ----- MOUTH -----
	_draw_mouth(flip, face_y)


func _draw_eyelids(l_pos: Vector2, r_pos: Vector2, _flip: float) -> void:
	var lid_col: Color = body_color.darkened(0.05)
	if GameManager.is_chili_active:
		lid_col = burn_color.lerp(body_color, 0.5)

	match current_state:
		State.FALL:
			# Wide open -- no extra lids, eyes already drawn big
			pass
		State.IDLE:
			# Slightly droopy
			var droop: float = sin(anim_time * 0.8) * 0.5 + 1.5
			_draw_filled_ellipse(l_pos + Vector2(0, -6), Vector2(8, droop), lid_col)
			_draw_filled_ellipse(r_pos + Vector2(0, -5.5), Vector2(7, droop), lid_col)
		_:
			# Minimal
			_draw_filled_ellipse(l_pos + Vector2(0, -6.5), Vector2(8, 1.5), lid_col)
			_draw_filled_ellipse(r_pos + Vector2(0, -6), Vector2(7, 1.5), lid_col)


func _draw_eyebrows(l_pos: Vector2, r_pos: Vector2, flip: float) -> void:
	var brow_col: Color = pupil_color.lightened(0.15)
	var brow_thick: float = 2.0

	match current_state:
		State.FALL:
			# Scared - raised and curved up
			draw_line(l_pos + Vector2(-5 * flip, -10), l_pos + Vector2(3 * flip, -14), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-3 * flip, -14), r_pos + Vector2(5 * flip, -10), brow_col, brow_thick)
		State.STUMBLE:
			# Dizzy - wavy
			var wave: float = sin(anim_time * 8.0) * 2.0
			draw_line(l_pos + Vector2(-5, -10 + wave), l_pos + Vector2(4, -11 - wave), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-4, -11 + wave), r_pos + Vector2(5, -10 - wave), brow_col, brow_thick)
		State.RUN:
			# Happy - slight angle
			draw_line(l_pos + Vector2(-5 * flip, -10), l_pos + Vector2(3 * flip, -11), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-3 * flip, -11), r_pos + Vector2(5 * flip, -10), brow_col, brow_thick)
		State.BURNED:
			# Angry/panicked - steep V
			draw_line(l_pos + Vector2(-5 * flip, -12), l_pos + Vector2(3 * flip, -8), brow_col, 2.5)
			draw_line(r_pos + Vector2(-3 * flip, -8), r_pos + Vector2(5 * flip, -12), brow_col, 2.5)
		State.DEAD:
			# Sad - drooping
			draw_line(l_pos + Vector2(-5, -8), l_pos + Vector2(4, -11), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-4, -11), r_pos + Vector2(5, -8), brow_col, brow_thick)
		_:
			# Idle - worried/confused default
			draw_line(l_pos + Vector2(-4 * flip, -9), l_pos + Vector2(4 * flip, -11), brow_col, 1.5)
			draw_line(r_pos + Vector2(-4 * flip, -11), r_pos + Vector2(4 * flip, -9), brow_col, 1.5)


func _draw_mouth(flip: float, face_y: float) -> void:
	var mouth_y: float = face_y + 12.0

	match current_state:
		State.DEAD:
			# Sad wavy line
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(9):
				var t: float = float(i) / 8.0
				pts.append(Vector2(lerpf(-7, 7, t), mouth_y + 4 + sin(t * TAU) * 1.5))
			draw_polyline(pts, pupil_color, 2.0)
		State.STUMBLE:
			# Dizzy wobbly mouth
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(10):
				var t: float = float(i) / 9.0
				pts.append(Vector2(lerpf(-6, 6, t), mouth_y + sin(t * TAU * 2.0 + anim_time * 5.0) * 2.5))
			draw_polyline(pts, pupil_color, 1.5)
		State.BURNED:
			# Screaming open mouth
			_draw_filled_ellipse(Vector2(0, mouth_y + 3), Vector2(7, 9), Color(0.15, 0.05, 0.05))
			# Tongue
			_draw_filled_ellipse(Vector2(0, mouth_y + 8), Vector2(4, 4), Color(0.85, 0.25, 0.2))
			# Teeth at top
			draw_line(Vector2(-3, mouth_y - 1), Vector2(-3, mouth_y + 2), Color.WHITE, 1.5)
			draw_line(Vector2(0, mouth_y - 1), Vector2(0, mouth_y + 2.5), Color.WHITE, 1.5)
			draw_line(Vector2(3, mouth_y - 1), Vector2(3, mouth_y + 2), Color.WHITE, 1.5)
		State.RUN:
			if abs(velocity.x) > 300:
				# Big excited grin
				draw_arc(Vector2(0, mouth_y - 2), 7.0, 0.15, PI - 0.15, 12, pupil_color, 2.0)
				# Teeth
				draw_line(Vector2(-2, mouth_y - 2), Vector2(-2, mouth_y), Color.WHITE, 1.5)
				draw_line(Vector2(2, mouth_y - 2), Vector2(2, mouth_y), Color.WHITE, 1.5)
			else:
				# Running smile
				draw_arc(Vector2(0, mouth_y - 1), 5.0, 0.2, PI - 0.2, 10, pupil_color, 1.8)
		State.JUMP:
			# Excited O mouth
			_draw_filled_ellipse(Vector2(0, mouth_y + 1), Vector2(4, 5), Color(0.15, 0.05, 0.05))
		State.FALL:
			# Worried open mouth
			_draw_filled_ellipse(Vector2(0, mouth_y + 2), Vector2(5, 6), Color(0.15, 0.05, 0.05))
			# Tongue visible
			_draw_filled_ellipse(Vector2(1 * flip, mouth_y + 5), Vector2(3, 2.5), Color(0.8, 0.35, 0.3))
		_:
			# Idle - wobbly derpy smile
			var wobble: float = sin(anim_time * 2.0) * 0.3
			draw_arc(Vector2(wobble, mouth_y), 4.5, 0.1 + wobble * 0.1, PI - 0.1 + wobble * 0.1, 10, pupil_color, 1.5)


func _draw_x_eye(pos: Vector2, sz: float) -> void:
	draw_line(pos + Vector2(-sz, -sz), pos + Vector2(sz, sz), pupil_color, 2.5)
	draw_line(pos + Vector2(sz, -sz), pos + Vector2(-sz, sz), pupil_color, 2.5)


func _draw_spiral_eye(pos: Vector2, sz: float, offset: float) -> void:
	var segments: int = 20
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var a: float = t * TAU * 2.0 + offset
		var r: float = t * sz
		pts.append(pos + Vector2(cos(a) * r, sin(a) * r))
	draw_polyline(pts, pupil_color, 1.5)


# ===========================================================================
# DRAW HELPERS - EFFECTS
# ===========================================================================

func _draw_shield() -> void:
	# Translucent blue yogurt bubble
	var shield_pulse: float = sin(anim_time * 3.0) * 2.0
	var shield_alpha: float = 0.18 + sin(anim_time * 2.0) * 0.05
	var shield_color: Color = Color(0.6, 0.8, 1.0, shield_alpha)
	var shield_edge: Color = Color(0.5, 0.75, 1.0, 0.35)

	# Outer glow
	_draw_filled_ellipse(Vector2(0, 0), Vector2(30 + shield_pulse, 38 + shield_pulse), Color(0.6, 0.85, 1.0, 0.06))
	# Main bubble
	_draw_filled_ellipse(Vector2(0, 0), Vector2(26 + shield_pulse, 34 + shield_pulse), shield_color)
	# Edge ring
	draw_arc(Vector2(0, 0), 28.0 + shield_pulse, 0, TAU, 32, shield_edge, 1.5)

	# Yogurt drip effects (hanging from bottom)
	var drip_y: float = 30.0 + shield_pulse
	for i in range(3):
		var dx: float = -8.0 + float(i) * 8.0
		var drip_len: float = 4.0 + sin(anim_time * 2.5 + float(i) * 1.5) * 3.0
		var drip_col: Color = Color(0.7, 0.85, 1.0, 0.3)
		_draw_filled_ellipse(Vector2(dx, drip_y + drip_len * 0.5), Vector2(2.5, drip_len), drip_col)
		# Drip droplet at tip
		draw_circle(Vector2(dx, drip_y + drip_len), 2.0, Color(0.65, 0.82, 1.0, 0.35))

	# Highlight shine
	_draw_filled_ellipse(Vector2(-10, -14), Vector2(6, 4), Color(1, 1, 1, 0.2))


func _draw_oil_drips() -> void:
	var oil_col: Color = Color(0.85, 0.78, 0.2, 0.4)
	# Small oil drops rolling down body
	for i in range(4):
		var phase: float = anim_time * 1.2 + float(i) * 1.8
		var drop_y: float = fmod(phase * 12.0, 40.0) - 20.0
		var drop_x: float = sin(float(i) * 2.3) * 10.0
		var drop_sz: float = 1.5 + sin(phase) * 0.5
		draw_circle(Vector2(drop_x, drop_y), drop_sz, oil_col)


func _draw_stumble_stars() -> void:
	var star_radius: float = 22.0
	var star_y: float = -32.0
	var num_stars: int = 4
	for i in range(num_stars):
		var a: float = stumble_star_angle + float(i) * (TAU / float(num_stars))
		var sx: float = cos(a) * star_radius
		var sy: float = star_y + sin(a) * 6.0
		_draw_star(Vector2(sx, sy), 3.0, Color(1.0, 0.95, 0.2, 0.9))


func _draw_star(pos: Vector2, sz: float, color: Color) -> void:
	# 4-pointed star
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU - PI / 2.0
		var r: float = sz if i % 2 == 0 else sz * 0.4
		pts.append(pos + Vector2(cos(a) * r, sin(a) * r))
	if pts.size() >= 3:
		draw_colored_polygon(pts, color)


func _draw_sweat_drops(flip: float) -> void:
	var sweat_col: Color = Color(0.55, 0.8, 1.0, 0.65)
	# Two drops flying off the back side
	var back_x: float = -16.0 * flip
	var drop1_y: float = -8.0 + sin(anim_time * 6.0) * 3.0
	var drop2_y: float = -2.0 + sin(anim_time * 6.0 + 1.5) * 3.0

	# Teardrop shape (circle + triangle-ish)
	draw_circle(Vector2(back_x, drop1_y), 2.0, sweat_col)
	draw_circle(Vector2(back_x - 2 * flip, drop1_y - 2), 1.0, sweat_col)

	draw_circle(Vector2(back_x + 3 * flip, drop2_y), 1.5, sweat_col)
	draw_circle(Vector2(back_x + 1 * flip, drop2_y - 1.5), 0.8, sweat_col)


func _draw_chili_steam(flip: float) -> void:
	var steam_col: Color = Color(0.9, 0.9, 0.9, 0.3 + sin(anim_time * 4.0) * 0.1)
	# Steam puffs from the sides of the head ("ears")
	for side in [-1.0, 1.0]:
		var base_x: float = side * 16.0
		for j in range(3):
			var t: float = anim_time * 3.0 + float(j) * 0.8
			var offset_y: float = -sin(fmod(t, 2.0) * PI) * 10.0 - 5.0
			var offset_x: float = side * (3.0 + fmod(t, 2.0) * 4.0)
			var sz: float = 1.5 + fmod(t, 2.0) * 1.5
			var alpha: float = 0.4 * (1.0 - fmod(t, 2.0) / 2.0)
			draw_circle(Vector2(base_x + offset_x, -6.0 + offset_y), sz, Color(steam_col.r, steam_col.g, steam_col.b, alpha))


func _draw_landing_dust() -> void:
	var t: float = 1.0 - (landing_dust_timer / 0.25)
	var dust_alpha: float = 0.4 * (1.0 - t)
	var dust_radius: float = 10.0 + t * 20.0
	var dust_col: Color = Color(0.7, 0.6, 0.45, dust_alpha)

	# Ring of small circles
	var num_puffs: int = 8
	for i in range(num_puffs):
		var a: float = float(i) / float(num_puffs) * TAU
		var px: float = cos(a) * dust_radius
		var py: float = 30.0 + sin(a) * 3.0 - t * 4.0
		var puff_sz: float = (2.0 + sin(float(i) * 1.7) * 1.0) * (1.0 - t * 0.5)
		draw_circle(Vector2(px, py), puff_sz, dust_col)


func _draw_blush(flip: float) -> void:
	var blush_alpha: float = 0.35 * clampf(blush_timer / 0.3, 0.0, 1.0)
	var blush_col: Color = Color(1.0, 0.45, 0.45, blush_alpha)
	# Two rosy circles on cheeks
	_draw_filled_ellipse(Vector2(-9 * flip, 4), Vector2(4, 2.5), blush_col)
	_draw_filled_ellipse(Vector2(9 * flip, 4), Vector2(4, 2.5), blush_col)


# ===========================================================================
# GEOMETRY HELPERS
# ===========================================================================

func _draw_filled_ellipse(center: Vector2, sz: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = 24
	for i in range(segments + 1):
		var angle: float = float(i) / float(segments) * TAU
		points.append(center + Vector2(cos(angle) * sz.x, sin(angle) * sz.y))
	draw_colored_polygon(points, color)
