extends CharacterBody2D

## Stupid Cucumber - Main character controller
## Sonic-style momentum physics + clumsy cucumber personality
## Phase 3: ULTRA detailed hand-drawn graphics

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
var highlight_color: Color = Color(0.45, 0.85, 0.35)
var dark_green: Color = Color(0.2, 0.55, 0.12)
var light_green: Color = Color(0.45, 0.85, 0.35)
var belly_color: Color = Color(0.5, 0.88, 0.42)
var eye_white: Color = Color(0.97, 0.97, 0.97)
var iris_color: Color = Color(0.15, 0.55, 0.15)
var pupil_color: Color = Color(0.08, 0.08, 0.08)
var burn_color: Color = Color(1.0, 0.3, 0.1)
var shoe_color: Color = Color(0.55, 0.22, 0.08)
var bandaid_color: Color = Color(0.92, 0.78, 0.6)
var tongue_color: Color = Color(0.85, 0.3, 0.3)
var tooth_color: Color = Color(0.98, 0.96, 0.9)
var stem_color: Color = Color(0.2, 0.5, 0.1)
var leaf_color: Color = Color(0.25, 0.65, 0.15)

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
var damage_flash_timer: float = 0.0
var landing_dust_timer: float = 0.0
var leaf_bounce: float = 0.0
var idle_wave_timer: float = 0.0
var idle_wave_active: bool = false

# Stumble stars
var stumble_star_angle: float = 0.0

# Death fade
var death_gray_t: float = 0.0

# Flower bud
var flower_visible: bool = false
var flower_timer: float = 0.0

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

	# Apply equipped colors
	var colors: Dictionary = GameManager.get_equipped_colors()
	if colors.has("body"):
		body_color = colors["body"]
	if colors.has("highlight"):
		highlight_color = colors["highlight"]
		light_green = highlight_color

	# Derive secondary colors from body
	dark_green = body_color.darkened(0.3)
	belly_color = body_color.lightened(0.25)

	# Start first blink cycle
	blink_timer = randf_range(2.0, 5.0)
	# Flower bud timer
	flower_timer = randf_range(8.0, 20.0)


func _physics_process(delta: float) -> void:
	anim_time += delta

	if current_state == State.DEAD:
		velocity.y += GRAVITY * delta
		death_gray_t = minf(death_gray_t + delta * 0.8, 1.0)
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

	# Damage flash fade
	if damage_flash_timer > 0:
		damage_flash_timer -= delta

	# Leaf bounce
	var leaf_target: float = sin(anim_time * 3.0) * 0.15
	if abs(velocity.x) > 100:
		leaf_target = sin(anim_time * 8.0) * 0.3
	leaf_bounce = lerpf(leaf_bounce, leaf_target, delta * 6.0)

	# Flower bud timer
	flower_timer -= delta
	if flower_timer <= 0:
		flower_visible = not flower_visible
		flower_timer = randf_range(6.0, 15.0) if not flower_visible else randf_range(3.0, 6.0)

	# Idle wave (occasional arm wave when idle)
	if current_state == State.IDLE:
		if not idle_wave_active:
			idle_wave_timer -= delta
			if idle_wave_timer <= 0:
				idle_wave_active = true
				idle_wave_timer = 1.5
		else:
			idle_wave_timer -= delta
			if idle_wave_timer <= 0:
				idle_wave_active = false
				idle_wave_timer = randf_range(4.0, 8.0)
	else:
		idle_wave_active = false
		idle_wave_timer = randf_range(3.0, 6.0)

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
	death_gray_t = 0.0
	velocity = Vector2(0, JUMP_VELOCITY * 0.7)
	dust_particles.emitting = false
	star_particles.emitting = false
	died.emit()
	GameManager.lose_life()


func respawn() -> void:
	current_state = State.IDLE
	death_gray_t = 0.0
	velocity = Vector2.ZERO
	global_position = GameManager.respawn_position
	squash_stretch = Vector2(1.0, 1.0)
	burn_speed_mult = 1.0
	burn_control_penalty = 1.0
	burn_wobble = 0.0
	rotation_wobble = 0.0
	facing_right = true
	if fire_particles:
		fire_particles.emitting = false


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
		damage_flash_timer = 0.15
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
# DRAWING - ULTRA DETAILED
# ===========================================================================

func _draw() -> void:
	var flip: float = -1.0 if not facing_right else 1.0

	draw_set_transform(Vector2.ZERO, rotation_wobble, squash_stretch)

	# --- Compute body colors with status effects ---
	var cur_body: Color = body_color
	var cur_dark: Color = dark_green
	var cur_light: Color = light_green
	var cur_belly: Color = belly_color

	# Death: fade entire palette toward gray
	if current_state == State.DEAD and death_gray_t > 0.0:
		var gray: Color = Color(0.45, 0.45, 0.45)
		cur_body = cur_body.lerp(gray, death_gray_t)
		cur_dark = cur_dark.lerp(gray.darkened(0.2), death_gray_t)
		cur_light = cur_light.lerp(gray.lightened(0.1), death_gray_t)
		cur_belly = cur_belly.lerp(gray.lightened(0.05), death_gray_t)

	if GameManager.is_chili_active:
		var burn_t: float = float(GameManager.chili_stacks) / float(GameManager.MAX_CHILI_STACKS)
		cur_body = cur_body.lerp(burn_color, burn_t * 0.55)
		cur_dark = cur_dark.lerp(burn_color.darkened(0.2), burn_t * 0.5)
		cur_light = cur_light.lerp(Color(1.0, 0.5, 0.2), burn_t * 0.4)
		cur_belly = cur_belly.lerp(Color(1.0, 0.6, 0.3), burn_t * 0.3)

	if GameManager.is_oil_active:
		var oil_sheen: Color = Color(0.95, 0.88, 0.4, 0.15)
		cur_body = cur_body.lerp(oil_sheen, 0.2)
		cur_light = cur_light.lerp(Color(1.0, 0.95, 0.6), 0.25)

	# Damage flash (red tint)
	if damage_flash_timer > 0:
		var flash_t: float = clampf(damage_flash_timer / 0.15, 0.0, 1.0)
		cur_body = cur_body.lerp(Color(1.0, 0.2, 0.2), flash_t * 0.6)
		cur_light = cur_light.lerp(Color(1.0, 0.4, 0.4), flash_t * 0.4)

	# -----------------------------------------------------------------------
	# GROUND SHADOW
	# -----------------------------------------------------------------------
	_draw_filled_ellipse(Vector2(0, 34), Vector2(22, 7), Color(0, 0, 0, 0.16))
	_draw_filled_ellipse(Vector2(0, 34), Vector2(16, 5), Color(0, 0, 0, 0.08))

	# -----------------------------------------------------------------------
	# CHILI RED AURA (behind everything)
	# -----------------------------------------------------------------------
	if GameManager.is_chili_active:
		var aura_pulse: float = sin(anim_time * 6.0) * 3.0
		var aura_alpha: float = 0.06 + sin(anim_time * 4.0) * 0.03
		aura_alpha *= float(GameManager.chili_stacks) / float(GameManager.MAX_CHILI_STACKS)
		_draw_filled_ellipse(Vector2(0, 0), Vector2(34 + aura_pulse, 42 + aura_pulse), Color(1.0, 0.15, 0.0, aura_alpha))
		_draw_filled_ellipse(Vector2(0, 0), Vector2(28 + aura_pulse, 36 + aura_pulse), Color(1.0, 0.25, 0.05, aura_alpha * 1.3))

	# -----------------------------------------------------------------------
	# OIL GLOW (behind body)
	# -----------------------------------------------------------------------
	if GameManager.is_oil_active:
		var oil_alpha: float = 0.08 + sin(anim_time * 4.0) * 0.04
		_draw_filled_ellipse(Vector2(0, 0), Vector2(30, 38), Color(0.95, 0.85, 0.3, oil_alpha))
		# Shiny surface reflection arcs
		var ref_a: float = anim_time * 1.5
		draw_arc(Vector2(-6, -10), 20.0, ref_a, ref_a + 0.8, 8, Color(1.0, 0.95, 0.5, 0.12), 2.0)
		draw_arc(Vector2(4, 5), 16.0, ref_a + PI, ref_a + PI + 0.6, 6, Color(1.0, 0.95, 0.5, 0.08), 1.5)

	# -----------------------------------------------------------------------
	# SPEED LINES (oil boost)
	# -----------------------------------------------------------------------
	if GameManager.is_oil_active and abs(velocity.x) > 200:
		_draw_speed_lines(flip)

	# -----------------------------------------------------------------------
	# LEGS (behind body)
	# -----------------------------------------------------------------------
	_draw_legs(flip, cur_body)

	# -----------------------------------------------------------------------
	# CUCUMBER BODY - Multi-layered for depth
	# -----------------------------------------------------------------------

	# Layer 1: Outer dark edge (shadow/outline for depth)
	_draw_filled_ellipse(Vector2(0, 0), Vector2(20, 28), cur_dark.darkened(0.15))

	# Layer 2: Main body fill
	_draw_filled_ellipse(Vector2(0, 0), Vector2(18, 26), cur_body)

	# Layer 3: Vertical lighter stripes (cucumber texture)
	_draw_body_stripes(flip, cur_body, cur_light)

	# Layer 4: Belly area (lighter oval in center-front)
	_draw_filled_ellipse(Vector2(2 * flip, 3), Vector2(10, 15), cur_belly.lerp(cur_body, 0.3))
	_draw_filled_ellipse(Vector2(2 * flip, 3), Vector2(7, 12), cur_belly)

	# Layer 5: Left highlight band (cylindrical 3D look)
	_draw_filled_ellipse(Vector2(-6 * flip, -2), Vector2(7, 19), cur_light.lerp(cur_body, 0.4))

	# Layer 6: Top specular highlight (upper-left, subtle)
	_draw_filled_ellipse(Vector2(-4 * flip, -15), Vector2(9, 7), cur_light.lightened(0.12))
	# Bright specular dot
	_draw_filled_ellipse(Vector2(-5 * flip, -17), Vector2(4, 3), Color(1.0, 1.0, 1.0, 0.18))

	# Layer 7: Bottom darker area (ground shadow on body)
	_draw_filled_ellipse(Vector2(0, 17), Vector2(13, 8), cur_dark.lerp(cur_body, 0.45))

	# Layer 8: Subtle rim light on right edge
	var rim_points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var t: float = float(i) / 9.0
		var angle: float = lerpf(-0.8, 0.8, t)
		rim_points.append(Vector2(17.5 * flip * cos(angle * 0.3 + 0.3), -20.0 + t * 40.0))
	if rim_points.size() >= 2:
		draw_polyline(rim_points, Color(1, 1, 1, 0.08), 2.0)

	# -----------------------------------------------------------------------
	# BUMPS / WARTS (8-10 with individual highlights and shadows)
	# -----------------------------------------------------------------------
	_draw_bumps(flip, cur_body)

	# -----------------------------------------------------------------------
	# BANDAID (clumsy detail!)
	# -----------------------------------------------------------------------
	_draw_bandaid(Vector2(-8 * flip, 8), 0.4 * flip)

	# -----------------------------------------------------------------------
	# STEM, LEAF & FLOWER BUD on top
	# -----------------------------------------------------------------------
	_draw_stem_and_leaf(flip)

	# -----------------------------------------------------------------------
	# ARMS (with full joint detail)
	# -----------------------------------------------------------------------
	_draw_arms(flip, cur_body)

	# -----------------------------------------------------------------------
	# FACE (state-dependent, ultra detailed)
	# -----------------------------------------------------------------------
	_draw_face(flip)

	# -----------------------------------------------------------------------
	# SHIELD (yogurt bubble with hex pattern)
	# -----------------------------------------------------------------------
	if GameManager.is_shield_active:
		_draw_shield()

	# -----------------------------------------------------------------------
	# OIL DRIP TRAIL
	# -----------------------------------------------------------------------
	if GameManager.is_oil_active:
		_draw_oil_drips()

	# -----------------------------------------------------------------------
	# STUMBLE STARS (5-pointed)
	# -----------------------------------------------------------------------
	if current_state == State.STUMBLE:
		_draw_stumble_stars()

	# -----------------------------------------------------------------------
	# SWEAT DROPS (when going fast >300)
	# -----------------------------------------------------------------------
	if abs(velocity.x) > 300 and current_state != State.DEAD:
		_draw_sweat_drops(flip)

	# -----------------------------------------------------------------------
	# CHILI STEAM FROM EARS + TEARS
	# -----------------------------------------------------------------------
	if GameManager.is_chili_active:
		_draw_chili_steam(flip)
		if current_state == State.BURNED:
			_draw_chili_tears(flip)

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

	# Reset transform
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# ===========================================================================
# DRAW HELPERS - BODY DETAILS
# ===========================================================================

func _draw_body_stripes(flip: float, base: Color, lighter: Color) -> void:
	# 3 vertical lighter stripes to give cucumber texture
	var stripe_col: Color = base.lerp(lighter, 0.35)
	var stripe_col2: Color = base.lerp(lighter, 0.25)

	# Center stripe
	var s1: PackedVector2Array = PackedVector2Array()
	for i in range(12):
		var t: float = float(i) / 11.0
		var y: float = lerpf(-22.0, 22.0, t)
		var w: float = 3.0 * sin(t * PI)
		s1.append(Vector2(-1 * flip + w, y))
	for i in range(12):
		var t: float = float(11 - i) / 11.0
		var y: float = lerpf(-22.0, 22.0, t)
		var w: float = 3.0 * sin(t * PI)
		s1.append(Vector2(-1 * flip - w, y))
	if s1.size() >= 3:
		draw_colored_polygon(s1, stripe_col)

	# Left stripe
	var s2: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var t: float = float(i) / 9.0
		var y: float = lerpf(-18.0, 18.0, t)
		var base_x: float = -8.0 * flip
		var w: float = 2.5 * sin(t * PI)
		s2.append(Vector2(base_x + w, y))
	for i in range(10):
		var t: float = float(9 - i) / 9.0
		var y: float = lerpf(-18.0, 18.0, t)
		var base_x: float = -8.0 * flip
		var w: float = 2.5 * sin(t * PI)
		s2.append(Vector2(base_x - w, y))
	if s2.size() >= 3:
		draw_colored_polygon(s2, stripe_col2)

	# Right stripe
	var s3: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var t: float = float(i) / 9.0
		var y: float = lerpf(-16.0, 16.0, t)
		var base_x: float = 8.0 * flip
		var w: float = 2.0 * sin(t * PI)
		s3.append(Vector2(base_x + w, y))
	for i in range(10):
		var t: float = float(9 - i) / 9.0
		var y: float = lerpf(-16.0, 16.0, t)
		var base_x: float = 8.0 * flip
		var w: float = 2.0 * sin(t * PI)
		s3.append(Vector2(base_x - w, y))
	if s3.size() >= 3:
		draw_colored_polygon(s3, stripe_col2.lerp(base, 0.2))


func _draw_bumps(flip: float, base: Color) -> void:
	# 10 bumps with 3D shading (shadow + highlight per bump)
	var bump_positions: Array = [
		Vector2(11 * flip, -12), Vector2(13 * flip, 0), Vector2(10 * flip, 10),
		Vector2(14 * flip, -5), Vector2(8 * flip, 18),
		Vector2(-10 * flip, -7), Vector2(-12 * flip, 5), Vector2(-8 * flip, 14),
		Vector2(5 * flip, -20), Vector2(-5 * flip, -18),
	]
	var bump_sizes: Array = [3.2, 2.8, 2.5, 2.0, 2.2, 2.3, 2.8, 2.0, 1.8, 1.6]

	for idx in range(bump_positions.size()):
		var pos: Vector2 = bump_positions[idx]
		var sz: float = bump_sizes[idx]
		var shadow_col: Color = base.darkened(0.18)
		var highlight_col: Color = base.lightened(0.15)
		var mid_col: Color = base.darkened(0.08)

		# Shadow (bottom-right offset)
		draw_circle(pos + Vector2(0.8, 0.8), sz, shadow_col)
		# Bump body
		draw_circle(pos, sz, mid_col)
		# Highlight (top-left offset)
		draw_circle(pos + Vector2(-0.7, -0.7), sz * 0.45, highlight_col)
		# Tiny specular dot
		draw_circle(pos + Vector2(-0.5, -0.9), sz * 0.2, Color(1, 1, 1, 0.2))


func _draw_stem_and_leaf(flip: float) -> void:
	var stem_base: Vector2 = Vector2(0, -27)
	var stem_mid: Vector2 = Vector2(1 * flip, -31)
	var stem_top: Vector2 = Vector2(2 * flip, -36)
	var s_color: Color = stem_color
	var s_dark: Color = stem_color.darkened(0.25)

	if current_state == State.DEAD:
		s_color = s_color.lerp(Color(0.4, 0.4, 0.4), death_gray_t)
		s_dark = s_dark.lerp(Color(0.3, 0.3, 0.3), death_gray_t)

	# Thick stem with darker ridges
	draw_line(stem_base, stem_mid, s_color, 4.0)
	draw_line(stem_mid, stem_top, s_color, 3.5)
	# Ridge lines on stem for texture
	draw_line(stem_base + Vector2(-1, 0), stem_mid + Vector2(-1, 0), s_dark, 1.0)
	draw_line(stem_base + Vector2(1, 0), stem_mid + Vector2(1, 0), s_dark, 1.0)
	draw_line(stem_mid + Vector2(-0.5, 0), stem_top + Vector2(-0.5, 0), s_dark, 0.8)
	# Stem cap (small ellipse)
	_draw_filled_ellipse(stem_top, Vector2(3.5, 2.0), s_color.lightened(0.1))

	# --- Leaf 1 (main, bounces with movement) ---
	var l_color: Color = leaf_color
	if current_state == State.DEAD:
		l_color = l_color.lerp(Color(0.4, 0.4, 0.4), death_gray_t)

	var leaf_rot: float = leaf_bounce
	var leaf1_tip: Vector2 = stem_top + Vector2(cos(leaf_rot) * 12 * flip, sin(leaf_rot) * -7 - 5)
	var leaf1_ctrl1: Vector2 = stem_top + Vector2(cos(leaf_rot) * 4 * flip, sin(leaf_rot) * -2 - 7)
	var leaf1_ctrl2: Vector2 = stem_top + Vector2(cos(leaf_rot) * 8 * flip, sin(leaf_rot) * -5 - 3)

	var leaf1_pts: PackedVector2Array = PackedVector2Array()
	leaf1_pts.append(stem_top + Vector2(-2 * flip, 2))
	leaf1_pts.append(leaf1_tip)
	leaf1_pts.append(stem_top + Vector2(2 * flip, -2))
	draw_colored_polygon(leaf1_pts, l_color)
	# Leaf vein (main)
	draw_line(stem_top, leaf1_tip, s_dark, 1.0)
	# Side veins
	var vein_mid: Vector2 = stem_top.lerp(leaf1_tip, 0.4)
	draw_line(vein_mid, vein_mid + Vector2(2 * flip, -3), s_dark, 0.6)
	draw_line(vein_mid, vein_mid + Vector2(2 * flip, 2), s_dark, 0.6)
	var vein_mid2: Vector2 = stem_top.lerp(leaf1_tip, 0.65)
	draw_line(vein_mid2, vein_mid2 + Vector2(1.5 * flip, -2.5), s_dark, 0.5)
	draw_line(vein_mid2, vein_mid2 + Vector2(1.5 * flip, 1.5), s_dark, 0.5)

	# --- Leaf 2 (smaller, opposite side) ---
	var leaf2_rot: float = leaf_bounce * 0.7 + 0.3
	var leaf2_base: Vector2 = stem_mid + Vector2(-1 * flip, 0)
	var leaf2_tip: Vector2 = leaf2_base + Vector2(cos(leaf2_rot) * -9 * flip, sin(leaf2_rot) * -4 - 4)
	var leaf2_ctrl: Vector2 = leaf2_base + Vector2(cos(leaf2_rot) * -5 * flip, sin(leaf2_rot) * -2 - 5)

	var leaf2_pts: PackedVector2Array = PackedVector2Array()
	leaf2_pts.append(leaf2_base + Vector2(2 * flip, 2))
	leaf2_pts.append(leaf2_tip)
	leaf2_pts.append(leaf2_base + Vector2(-2 * flip, -2))
	draw_colored_polygon(leaf2_pts, l_color.darkened(0.05))
	# Leaf 2 vein
	draw_line(leaf2_base, leaf2_tip, s_dark, 0.7)

	# --- Flower bud (appears occasionally) ---
	if flower_visible and current_state != State.DEAD:
		_draw_flower_bud(stem_top + Vector2(-3 * flip, -4))


func _draw_flower_bud(pos: Vector2) -> void:
	var bud_pulse: float = sin(anim_time * 2.0) * 0.5
	# Tiny yellow/white petals
	for i in range(5):
		var a: float = float(i) / 5.0 * TAU + anim_time * 0.5
		var petal_pos: Vector2 = pos + Vector2(cos(a) * (3.0 + bud_pulse), sin(a) * (3.0 + bud_pulse))
		draw_circle(petal_pos, 1.5, Color(1.0, 0.95, 0.7, 0.8))
	# Center
	draw_circle(pos, 1.5, Color(1.0, 0.85, 0.2, 0.9))


func _draw_bandaid(pos: Vector2, angle: float) -> void:
	var bw: float = 9.0
	var bh: float = 4.0
	var c: float = cos(angle)
	var s: float = sin(angle)

	# Horizontal strip
	var h_points: PackedVector2Array = PackedVector2Array()
	h_points.append(pos + Vector2(-bw * c - (-bh) * s, -bw * s + (-bh) * c))
	h_points.append(pos + Vector2(bw * c - (-bh) * s, bw * s + (-bh) * c))
	h_points.append(pos + Vector2(bw * c - bh * s, bw * s + bh * c))
	h_points.append(pos + Vector2(-bw * c - bh * s, -bw * s + bh * c))
	draw_colored_polygon(h_points, bandaid_color)

	# Vertical strip (cross)
	var vw: float = 4.0
	var vh: float = 7.0
	var v_points: PackedVector2Array = PackedVector2Array()
	v_points.append(pos + Vector2(-vw * c - (-vh) * s, -vw * s + (-vh) * c))
	v_points.append(pos + Vector2(vw * c - (-vh) * s, vw * s + (-vh) * c))
	v_points.append(pos + Vector2(vw * c - vh * s, vw * s + vh * c))
	v_points.append(pos + Vector2(-vw * c - vh * s, -vw * s + vh * c))
	draw_colored_polygon(v_points, bandaid_color.lightened(0.05))

	# Red cross in center
	var cross_col: Color = Color(0.85, 0.2, 0.2, 0.7)
	draw_line(pos + Vector2(-2.5 * c, -2.5 * s), pos + Vector2(2.5 * c, 2.5 * s), cross_col, 1.2)
	draw_line(pos + Vector2(2.5 * s, -2.5 * c), pos + Vector2(-2.5 * s, 2.5 * c), cross_col, 1.2)

	# Texture dots on bandaid
	draw_circle(pos + Vector2(-4 * c, -4 * s), 0.6, bandaid_color.darkened(0.15))
	draw_circle(pos + Vector2(4 * c, 4 * s), 0.6, bandaid_color.darkened(0.15))
	draw_circle(pos + Vector2(-4 * s, 4 * c), 0.6, bandaid_color.darkened(0.15))
	draw_circle(pos + Vector2(4 * s, -4 * c), 0.6, bandaid_color.darkened(0.15))


func _draw_speed_lines(flip: float) -> void:
	var line_col: Color = Color(1.0, 0.9, 0.4, 0.2)
	var back_x: float = -20.0 * flip
	for i in range(5):
		var y_off: float = -15.0 + float(i) * 8.0
		var phase: float = fmod(anim_time * 8.0 + float(i) * 1.3, 3.0)
		var line_len: float = 8.0 + phase * 6.0
		var alpha: float = 0.3 * (1.0 - phase / 3.0)
		var start_x: float = back_x - flip * phase * 5.0
		draw_line(
			Vector2(start_x, y_off),
			Vector2(start_x - flip * line_len, y_off),
			Color(line_col.r, line_col.g, line_col.b, alpha),
			1.5
		)


# ===========================================================================
# DRAW HELPERS - LEGS
# ===========================================================================

func _draw_legs(flip: float, body_col: Color) -> void:
	var speed_ratio: float = clampf(abs(velocity.x) / MAX_SPEED, 0.0, 1.0)
	var leg_cycle: float = anim_time * (6.0 + speed_ratio * 10.0)
	var leg_swing: float = sin(leg_cycle) * (4.0 + speed_ratio * 10.0) if abs(velocity.x) > 10 else 0.0
	var leg_y: float = 23.0
	var leg_color: Color = body_col.darkened(0.18)
	var joint_color: Color = body_col.darkened(0.25)

	# Squish effect on landing
	var squish: float = 0.0
	if landing_dust_timer > 0.15:
		squish = (landing_dust_timer - 0.15) / 0.1 * 3.0

	# --- Left leg ---
	var l_hip: Vector2 = Vector2(-6, leg_y)
	var l_knee: Vector2 = Vector2(-7 + leg_swing * 0.5, leg_y + 9 - squish)
	var l_foot: Vector2 = Vector2(-8 + leg_swing, leg_y + 17 - squish)
	# Thigh
	draw_line(l_hip, l_knee, leg_color, 4.5)
	# Knee joint circle
	draw_circle(l_knee, 2.5, joint_color)
	draw_circle(l_knee, 1.5, leg_color.lightened(0.08))
	# Shin
	draw_line(l_knee, l_foot, leg_color, 3.8)
	# Shoe
	_draw_shoe(l_foot, flip, leg_swing > 0)

	# --- Right leg (opposite phase) ---
	var r_hip: Vector2 = Vector2(6, leg_y)
	var r_knee: Vector2 = Vector2(7 - leg_swing * 0.5, leg_y + 9 - squish)
	var r_foot: Vector2 = Vector2(8 - leg_swing, leg_y + 17 - squish)
	draw_line(r_hip, r_knee, leg_color, 4.5)
	draw_circle(r_knee, 2.5, joint_color)
	draw_circle(r_knee, 1.5, leg_color.lightened(0.08))
	draw_line(r_knee, r_foot, leg_color, 3.8)
	_draw_shoe(r_foot, flip, leg_swing < 0)


func _draw_shoe(pos: Vector2, flip: float, is_forward: bool) -> void:
	var shoe_w: float = 7.0
	var shoe_h: float = 4.5
	var offset_x: float = 2.5 * flip if is_forward else -1.0 * flip

	# Shoe body
	_draw_filled_ellipse(pos + Vector2(offset_x, 1), Vector2(shoe_w, shoe_h), shoe_color)
	# Shoe sole (darker bottom)
	_draw_filled_ellipse(pos + Vector2(offset_x, 3.5), Vector2(shoe_w + 0.5, 2), shoe_color.darkened(0.35))
	# Shoe upper highlight
	_draw_filled_ellipse(pos + Vector2(offset_x - 1.5 * flip, -0.5), Vector2(3.5, 2.2), shoe_color.lightened(0.18))
	# Shine dot
	draw_circle(pos + Vector2(offset_x - 2 * flip, -1), 1.0, Color(1, 1, 1, 0.15))
	# Lace detail
	draw_line(
		pos + Vector2(offset_x - 2, 0),
		pos + Vector2(offset_x + 2, 0),
		shoe_color.lightened(0.3), 0.8
	)


# ===========================================================================
# DRAW HELPERS - ARMS
# ===========================================================================

func _draw_arms(flip: float, body_col: Color) -> void:
	var arm_color: Color = body_col.darkened(0.12)
	var hand_color: Color = body_col.lightened(0.05)
	var joint_color: Color = body_col.darkened(0.22)
	var speed_ratio: float = clampf(abs(velocity.x) / MAX_SPEED, 0.0, 1.0)
	var arm_cycle: float = anim_time * (5.0 + speed_ratio * 8.0)

	var l_shoulder: Vector2 = Vector2(-16, -2)
	var r_shoulder: Vector2 = Vector2(16, -2)

	var l_swing: float = 0.0
	var r_swing: float = 0.0
	var l_vert: float = 0.0
	var r_vert: float = 0.0

	match current_state:
		State.FALL:
			# Arms flailing wildly
			l_swing = sin(anim_time * 14.0) * 10.0
			r_swing = sin(anim_time * 14.0 + PI) * 10.0
			l_vert = -14.0 + sin(anim_time * 12.0) * 5.0
			r_vert = -14.0 + sin(anim_time * 12.0 + PI) * 5.0
		State.JUMP:
			# Arms reaching up
			l_swing = -5.0 + sin(anim_time * 3.0) * 1.5
			r_swing = 5.0 + sin(anim_time * 3.0 + PI) * 1.5
			l_vert = -14.0
			r_vert = -14.0
		State.STUMBLE:
			# Arms out for balance, wobbling
			l_swing = -12.0 + sin(anim_time * 8.0) * 6.0
			r_swing = 12.0 + sin(anim_time * 8.0 + 1.0) * 6.0
			l_vert = -6.0 + sin(anim_time * 6.0) * 3.0
			r_vert = -6.0 + sin(anim_time * 6.0 + PI) * 3.0
		State.RUN, State.BURNED:
			l_swing = sin(arm_cycle) * (6.0 + speed_ratio * 10.0)
			r_swing = sin(arm_cycle + PI) * (6.0 + speed_ratio * 10.0)
			l_vert = 4.0 + sin(arm_cycle) * 3.0
			r_vert = 4.0 + sin(arm_cycle + PI) * 3.0
		State.DEAD:
			# Arms dangling limp
			l_swing = sin(anim_time * 1.0) * 2.0 - 3.0
			r_swing = sin(anim_time * 1.0 + 0.5) * 2.0 + 3.0
			l_vert = 10.0
			r_vert = 10.0
		_:
			# Idle: gentle sway or wave
			if idle_wave_active:
				# Wave the right arm
				var wave_t: float = fmod(anim_time * 4.0, TAU)
				r_swing = 6.0 + sin(wave_t) * 4.0
				r_vert = -10.0 + sin(wave_t * 2.0) * 3.0
				l_swing = sin(anim_time * 1.5) * 2.0
				l_vert = 6.0
			else:
				l_swing = sin(anim_time * 1.5) * 2.0
				r_swing = sin(anim_time * 1.5 + 0.5) * 2.0
				l_vert = 6.0
				r_vert = 6.0

	# --- Left arm ---
	var l_elbow: Vector2 = l_shoulder + Vector2(-5 + l_swing * 0.5, 7 + l_vert * 0.5)
	var l_hand: Vector2 = l_shoulder + Vector2(-7 + l_swing, 12 + l_vert)
	# Upper arm
	draw_line(l_shoulder, l_elbow, arm_color, 3.5)
	# Elbow joint
	draw_circle(l_elbow, 2.2, joint_color)
	draw_circle(l_elbow, 1.3, arm_color.lightened(0.06))
	# Forearm
	draw_line(l_elbow, l_hand, arm_color, 3.0)
	# Hand
	_draw_hand(l_hand, hand_color, -1.0)

	# --- Right arm ---
	var r_elbow: Vector2 = r_shoulder + Vector2(5 + r_swing * 0.5, 7 + r_vert * 0.5)
	var r_hand: Vector2 = r_shoulder + Vector2(7 + r_swing, 12 + r_vert)
	draw_line(r_shoulder, r_elbow, arm_color, 3.5)
	draw_circle(r_elbow, 2.2, joint_color)
	draw_circle(r_elbow, 1.3, arm_color.lightened(0.06))
	draw_line(r_elbow, r_hand, arm_color, 3.0)
	_draw_hand(r_hand, hand_color, 1.0)


func _draw_hand(pos: Vector2, color: Color, side: float) -> void:
	# Palm (slightly oval)
	_draw_filled_ellipse(pos, Vector2(3.5, 3.0), color)
	# Three fingers (small circles at tips)
	var finger_offsets: Array = [
		Vector2(-2.0 * side, -3.5),
		Vector2(0.0, -4.5),
		Vector2(2.0 * side, -3.0),
	]
	for offset in finger_offsets:
		var tip: Vector2 = pos + offset
		draw_line(pos, tip, color, 2.0)
		draw_circle(tip, 1.3, color.lightened(0.08))


# ===========================================================================
# DRAW HELPERS - FACE (ULTRA DETAILED, STATE-DEPENDENT)
# ===========================================================================

func _draw_face(flip: float) -> void:
	var face_y: float = -4.0

	var left_eye_pos: Vector2 = Vector2(-7 * flip, face_y) + eye_offset
	var right_eye_pos: Vector2 = Vector2(7 * flip, face_y) + eye_offset

	# ----- EYES -----
	match current_state:
		State.DEAD:
			_draw_dead_eyes(left_eye_pos, right_eye_pos)
		State.STUMBLE:
			_draw_spiral_eye(left_eye_pos, 5.5, anim_time * 6.0)
			_draw_spiral_eye(right_eye_pos, 4.5, anim_time * 6.0 + PI)
		State.BURNED:
			_draw_burned_eyes(left_eye_pos, right_eye_pos, flip)
		_:
			if is_blinking:
				# Closed eyes (curved lines)
				draw_arc(left_eye_pos, 4.0, 0.2, PI - 0.2, 8, pupil_color, 2.0)
				draw_arc(right_eye_pos, 3.5, 0.2, PI - 0.2, 8, pupil_color, 2.0)
			else:
				_draw_normal_eyes(left_eye_pos, right_eye_pos, flip)

	# ----- EYEBROWS -----
	_draw_eyebrows(left_eye_pos, right_eye_pos, flip)

	# ----- MOUTH -----
	_draw_mouth(flip, face_y)

	# ----- CHEEK BLUSH (permanent subtle on idle) -----
	if current_state == State.IDLE:
		_draw_filled_ellipse(Vector2(-10 * flip, 5), Vector2(3.5, 2.0), Color(1.0, 0.5, 0.5, 0.12))
		_draw_filled_ellipse(Vector2(10 * flip, 5), Vector2(3.5, 2.0), Color(1.0, 0.5, 0.5, 0.12))


func _draw_normal_eyes(l_pos: Vector2, r_pos: Vector2, flip: float) -> void:
	var pupil_shift: Vector2 = Vector2(sign(velocity.x) * 2.0, 0)

	# --- Left eye (larger for goofy asymmetry) ---
	# White
	_draw_filled_ellipse(l_pos, Vector2(7.5, 8.5), eye_white)
	# Subtle shadow at top of eyeball
	_draw_filled_ellipse(l_pos + Vector2(0, -4), Vector2(7.5, 3.5), Color(0.88, 0.88, 0.92, 0.3))
	# Iris
	_draw_filled_ellipse(l_pos + pupil_shift, Vector2(4.5, 5.0), iris_color)
	# Iris ring (darker edge)
	draw_arc(l_pos + pupil_shift, 4.2, 0, TAU, 16, iris_color.darkened(0.3), 0.8)
	# Pupil
	draw_circle(l_pos + pupil_shift, 2.8, pupil_color)
	# Shine highlight 1 (main)
	draw_circle(l_pos + pupil_shift + Vector2(-1.5, -2.0), 1.6, Color.WHITE)
	# Shine highlight 2 (secondary)
	draw_circle(l_pos + pupil_shift + Vector2(1.2, 1.2), 0.7, Color(1, 1, 1, 0.5))

	# --- Right eye (slightly smaller) ---
	_draw_filled_ellipse(r_pos, Vector2(6.5, 7.5), eye_white)
	_draw_filled_ellipse(r_pos + Vector2(0, -3.5), Vector2(6.5, 3.0), Color(0.88, 0.88, 0.92, 0.3))
	_draw_filled_ellipse(r_pos + pupil_shift + Vector2(0.5, 0.5), Vector2(3.5, 4.0), iris_color)
	draw_arc(r_pos + pupil_shift + Vector2(0.5, 0.5), 3.3, 0, TAU, 16, iris_color.darkened(0.3), 0.7)
	draw_circle(r_pos + pupil_shift + Vector2(0.5, 0.5), 2.0, pupil_color)
	draw_circle(r_pos + pupil_shift + Vector2(-0.8, -1.3), 1.2, Color.WHITE)
	draw_circle(r_pos + pupil_shift + Vector2(0.8, 0.8), 0.5, Color(1, 1, 1, 0.4))

	# Eyelids based on state
	_draw_eyelids(l_pos, r_pos, flip)

	# Eye looking direction for JUMP (looking up)
	if current_state == State.JUMP:
		# Pupils shifted up slightly more
		pass  # Already handled by eye_offset


func _draw_burned_eyes(l_pos: Vector2, r_pos: Vector2, _flip: float) -> void:
	# Wide open eyes with TINY pupils (panicking)
	# Left eye - wide
	_draw_filled_ellipse(l_pos, Vector2(8.5, 9.5), eye_white)
	# Bloodshot lines
	for i in range(4):
		var a: float = float(i) / 4.0 * TAU + 0.3
		var inner: Vector2 = l_pos + Vector2(cos(a) * 3.5, sin(a) * 4.0)
		var outer: Vector2 = l_pos + Vector2(cos(a) * 7.0, sin(a) * 8.0)
		draw_line(inner, outer, Color(0.9, 0.2, 0.15, 0.4), 0.6)
	# Iris (smaller than normal)
	_draw_filled_ellipse(l_pos, Vector2(3.5, 4.0), iris_color)
	# Tiny pupil!
	draw_circle(l_pos, 1.2, pupil_color)
	# Shine
	draw_circle(l_pos + Vector2(-1.0, -1.5), 1.0, Color.WHITE)

	# Right eye
	_draw_filled_ellipse(r_pos, Vector2(7.5, 8.5), eye_white)
	for i in range(3):
		var a: float = float(i) / 3.0 * TAU + 0.8
		var inner: Vector2 = r_pos + Vector2(cos(a) * 3.0, sin(a) * 3.5)
		var outer: Vector2 = r_pos + Vector2(cos(a) * 6.0, sin(a) * 7.0)
		draw_line(inner, outer, Color(0.9, 0.2, 0.15, 0.4), 0.6)
	_draw_filled_ellipse(r_pos, Vector2(3.0, 3.5), iris_color)
	draw_circle(r_pos, 1.0, pupil_color)
	draw_circle(r_pos + Vector2(-0.8, -1.2), 0.8, Color.WHITE)


func _draw_dead_eyes(l_pos: Vector2, r_pos: Vector2) -> void:
	# X eyes with gray tint
	var x_col: Color = pupil_color.lerp(Color(0.4, 0.4, 0.4), death_gray_t * 0.5)

	# Left X (larger)
	var sz1: float = 5.5
	draw_line(l_pos + Vector2(-sz1, -sz1), l_pos + Vector2(sz1, sz1), x_col, 3.0)
	draw_line(l_pos + Vector2(sz1, -sz1), l_pos + Vector2(-sz1, sz1), x_col, 3.0)

	# Right X (smaller)
	var sz2: float = 4.5
	draw_line(r_pos + Vector2(-sz2, -sz2), r_pos + Vector2(sz2, sz2), x_col, 2.5)
	draw_line(r_pos + Vector2(sz2, -sz2), r_pos + Vector2(-sz2, sz2), x_col, 2.5)


func _draw_eyelids(l_pos: Vector2, r_pos: Vector2, _flip: float) -> void:
	var lid_col: Color = body_color.darkened(0.05)
	if GameManager.is_chili_active:
		lid_col = burn_color.lerp(body_color, 0.5)
	if current_state == State.DEAD:
		lid_col = lid_col.lerp(Color(0.45, 0.45, 0.45), death_gray_t)

	match current_state:
		State.FALL:
			# Wide open -- eyes scared, minimal lids
			_draw_filled_ellipse(l_pos + Vector2(0, -7.5), Vector2(8, 1.0), lid_col)
			_draw_filled_ellipse(r_pos + Vector2(0, -6.5), Vector2(7, 1.0), lid_col)
		State.IDLE:
			# Gently droopy, relaxed quarter-closed
			var droop: float = sin(anim_time * 0.8) * 0.5 + 2.0
			_draw_filled_ellipse(l_pos + Vector2(0, -6), Vector2(8, droop), lid_col)
			_draw_filled_ellipse(r_pos + Vector2(0, -5.5), Vector2(7, droop * 0.9), lid_col)
		State.RUN:
			# Excited - eyes wider
			_draw_filled_ellipse(l_pos + Vector2(0, -7), Vector2(8, 1.5), lid_col)
			_draw_filled_ellipse(r_pos + Vector2(0, -6.5), Vector2(7, 1.5), lid_col)
		_:
			# Minimal
			_draw_filled_ellipse(l_pos + Vector2(0, -7), Vector2(8, 1.5), lid_col)
			_draw_filled_ellipse(r_pos + Vector2(0, -6.5), Vector2(7, 1.5), lid_col)


func _draw_eyebrows(l_pos: Vector2, r_pos: Vector2, flip: float) -> void:
	var brow_col: Color = pupil_color.lightened(0.15)
	var brow_thick: float = 2.2

	if current_state == State.DEAD:
		brow_col = brow_col.lerp(Color(0.4, 0.4, 0.4), death_gray_t * 0.5)

	match current_state:
		State.FALL:
			# Worried - angled up at center
			draw_line(l_pos + Vector2(-6 * flip, -10), l_pos + Vector2(2 * flip, -15), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-2 * flip, -15), r_pos + Vector2(6 * flip, -10), brow_col, brow_thick)
		State.STUMBLE:
			# Dizzy - wavy
			var wave: float = sin(anim_time * 8.0) * 2.5
			draw_line(l_pos + Vector2(-5, -10 + wave), l_pos + Vector2(4, -12 - wave), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-4, -12 + wave), r_pos + Vector2(5, -10 - wave), brow_col, brow_thick)
		State.JUMP:
			# Raised high (surprised/excited)
			draw_line(l_pos + Vector2(-5 * flip, -13), l_pos + Vector2(3 * flip, -14), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-3 * flip, -14), r_pos + Vector2(5 * flip, -13), brow_col, brow_thick)
		State.RUN:
			# Slightly raised, excited
			draw_line(l_pos + Vector2(-5 * flip, -11), l_pos + Vector2(3 * flip, -12.5), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-3 * flip, -12.5), r_pos + Vector2(5 * flip, -11), brow_col, brow_thick)
		State.BURNED:
			# Angry/panicked - steep V shape
			draw_line(l_pos + Vector2(-6 * flip, -14), l_pos + Vector2(3 * flip, -8), brow_col, 2.8)
			draw_line(r_pos + Vector2(-3 * flip, -8), r_pos + Vector2(6 * flip, -14), brow_col, 2.8)
		State.DEAD:
			# Sad - drooping down at sides
			draw_line(l_pos + Vector2(-5, -8), l_pos + Vector2(4, -12), brow_col, brow_thick)
			draw_line(r_pos + Vector2(-4, -12), r_pos + Vector2(5, -8), brow_col, brow_thick)
		_:
			# Idle - slightly raised, relaxed
			draw_line(l_pos + Vector2(-4 * flip, -10), l_pos + Vector2(4 * flip, -11.5), brow_col, 1.8)
			draw_line(r_pos + Vector2(-4 * flip, -11.5), r_pos + Vector2(4 * flip, -10), brow_col, 1.8)


func _draw_mouth(flip: float, face_y: float) -> void:
	var mouth_y: float = face_y + 12.0

	match current_state:
		State.DEAD:
			# Flat line with tongue out sideways
			draw_line(Vector2(-7, mouth_y + 3), Vector2(7, mouth_y + 3), pupil_color, 2.0)
			# Tongue sticking out to one side
			_draw_filled_ellipse(Vector2(8 * flip, mouth_y + 4), Vector2(5, 3), tongue_color)
			_draw_filled_ellipse(Vector2(8 * flip, mouth_y + 4), Vector2(3, 2), tongue_color.lightened(0.15))

		State.STUMBLE:
			# Dizzy wobbly mouth
			var pts: PackedVector2Array = PackedVector2Array()
			for i in range(12):
				var t: float = float(i) / 11.0
				pts.append(Vector2(
					lerpf(-7, 7, t),
					mouth_y + sin(t * TAU * 2.5 + anim_time * 6.0) * 3.0
				))
			draw_polyline(pts, pupil_color, 1.8)

		State.BURNED:
			# SCREAMING wide open mouth showing throat
			# Outer mouth shape
			_draw_filled_ellipse(Vector2(0, mouth_y + 3), Vector2(8, 10), Color(0.12, 0.04, 0.04))
			# Inner throat (darker)
			_draw_filled_ellipse(Vector2(0, mouth_y + 5), Vector2(5, 6), Color(0.06, 0.02, 0.02))
			# Uvula hint
			draw_circle(Vector2(0, mouth_y + 8), 1.2, Color(0.7, 0.2, 0.2))
			# Tongue
			_draw_filled_ellipse(Vector2(0, mouth_y + 9), Vector2(5, 4), tongue_color)
			# Upper teeth
			for i in range(4):
				var tx: float = -4.5 + float(i) * 3.0
				var th: float = 2.5 if i % 2 == 0 else 3.0
				draw_line(Vector2(tx, mouth_y - 2), Vector2(tx, mouth_y - 2 + th), tooth_color, 1.8)
			# Lower teeth
			for i in range(3):
				var tx: float = -3.0 + float(i) * 3.0
				draw_line(Vector2(tx, mouth_y + 11), Vector2(tx, mouth_y + 9), tooth_color, 1.5)

		State.RUN:
			if abs(velocity.x) > 350:
				# Big excited grin with tongue out
				draw_arc(Vector2(0, mouth_y - 2), 7.5, 0.1, PI - 0.1, 14, pupil_color, 2.2)
				# Teeth
				draw_line(Vector2(-3, mouth_y - 2), Vector2(-3, mouth_y + 0.5), tooth_color, 1.8)
				draw_line(Vector2(0, mouth_y - 2), Vector2(0, mouth_y + 1), tooth_color, 1.8)
				draw_line(Vector2(3, mouth_y - 2), Vector2(3, mouth_y + 0.5), tooth_color, 1.8)
				# Tongue poking out
				_draw_filled_ellipse(Vector2(5 * flip, mouth_y + 2), Vector2(3.5, 2.5), tongue_color)
			elif abs(velocity.x) > 200:
				# Open grin showing teeth
				draw_arc(Vector2(0, mouth_y - 2), 7.0, 0.15, PI - 0.15, 12, pupil_color, 2.0)
				draw_line(Vector2(-2, mouth_y - 2), Vector2(-2, mouth_y), tooth_color, 1.5)
				draw_line(Vector2(2, mouth_y - 2), Vector2(2, mouth_y), tooth_color, 1.5)
			else:
				# Running smile
				draw_arc(Vector2(0, mouth_y - 1), 5.5, 0.2, PI - 0.2, 10, pupil_color, 1.8)
				# One tooth showing
				draw_line(Vector2(1, mouth_y - 1), Vector2(1, mouth_y + 1), tooth_color, 1.3)

		State.JUMP:
			# Surprised O mouth
			_draw_filled_ellipse(Vector2(0, mouth_y + 1), Vector2(4.5, 5.5), Color(0.12, 0.04, 0.04))
			# Tongue inside
			_draw_filled_ellipse(Vector2(0, mouth_y + 4), Vector2(3, 2), tongue_color.darkened(0.15))
			# Lip outline
			draw_arc(Vector2(0, mouth_y + 1), 4.5, 0, TAU, 16, pupil_color.lightened(0.1), 0.8)

		State.FALL:
			# Worried open mouth, wavy edges
			var mouth_pts: PackedVector2Array = PackedVector2Array()
			for i in range(16):
				var t: float = float(i) / 15.0
				var a: float = t * TAU
				var rx: float = 5.5 + sin(a * 3.0 + anim_time * 4.0) * 0.8
				var ry: float = 6.5 + cos(a * 2.0 + anim_time * 3.0) * 0.6
				mouth_pts.append(Vector2(mouth_y + 2, mouth_y + 2) + Vector2(cos(a) * rx - (mouth_y + 2), sin(a) * ry - (mouth_y + 2)))
			# Simplified worried mouth
			_draw_filled_ellipse(Vector2(0, mouth_y + 2), Vector2(5.5, 6.5), Color(0.12, 0.04, 0.04))
			# Tongue visible, scared
			_draw_filled_ellipse(Vector2(1 * flip, mouth_y + 5.5), Vector2(3.5, 2.5), tongue_color)

		_:
			# Idle - curved derpy smile with one tooth
			var wobble: float = sin(anim_time * 2.0) * 0.3
			draw_arc(Vector2(wobble, mouth_y), 5.0, 0.1 + wobble * 0.1, PI - 0.1 + wobble * 0.1, 12, pupil_color, 1.8)
			# One goofy tooth
			draw_line(Vector2(1 + wobble, mouth_y), Vector2(1 + wobble, mouth_y + 2.5), tooth_color, 1.5)
			draw_line(Vector2(1 + wobble - 1, mouth_y + 2.5), Vector2(1 + wobble + 1, mouth_y + 2.5), tooth_color, 1.0)


func _draw_spiral_eye(pos: Vector2, sz: float, offset: float) -> void:
	var segments: int = 24
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var a: float = t * TAU * 2.5 + offset
		var r: float = t * sz
		pts.append(pos + Vector2(cos(a) * r, sin(a) * r))
	draw_polyline(pts, pupil_color, 1.8)


# ===========================================================================
# DRAW HELPERS - EFFECTS
# ===========================================================================

func _draw_shield() -> void:
	var shield_pulse: float = sin(anim_time * 3.0) * 2.0
	var shield_alpha: float = 0.18 + sin(anim_time * 2.0) * 0.05
	var shield_color: Color = Color(0.6, 0.8, 1.0, shield_alpha)
	var shield_edge: Color = Color(0.5, 0.75, 1.0, 0.35)

	# Outer glow
	_draw_filled_ellipse(Vector2(0, 0), Vector2(32 + shield_pulse, 40 + shield_pulse), Color(0.6, 0.85, 1.0, 0.05))
	# Main translucent bubble
	_draw_filled_ellipse(Vector2(0, 0), Vector2(28 + shield_pulse, 36 + shield_pulse), shield_color)

	# Subtle hexagonal pattern inside
	_draw_hex_pattern(Vector2(0, 0), 24.0 + shield_pulse, Color(0.5, 0.75, 1.0, 0.06))

	# Edge ring
	draw_arc(Vector2(0, 0), 30.0 + shield_pulse, 0, TAU, 36, shield_edge, 1.8)
	# Inner ring
	draw_arc(Vector2(0, 0), 27.0 + shield_pulse, 0, TAU, 32, Color(0.6, 0.8, 1.0, 0.12), 0.8)

	# Yogurt drip effects (3-4 drips hanging from bottom)
	var drip_y: float = 32.0 + shield_pulse
	for i in range(4):
		var dx: float = -10.0 + float(i) * 7.0
		var drip_len: float = 4.0 + sin(anim_time * 2.5 + float(i) * 1.5) * 3.5
		var drip_col: Color = Color(0.75, 0.88, 1.0, 0.3)
		# Drip strand
		_draw_filled_ellipse(Vector2(dx, drip_y + drip_len * 0.5), Vector2(2.0, drip_len), drip_col)
		# Drip droplet at tip
		draw_circle(Vector2(dx, drip_y + drip_len), 2.2, Color(0.65, 0.82, 1.0, 0.35))
		# Tiny highlight on droplet
		draw_circle(Vector2(dx - 0.5, drip_y + drip_len - 0.8), 0.7, Color(1, 1, 1, 0.3))

	# Bubble shine highlight (white arc)
	draw_arc(Vector2(-8, -12), 10.0, -0.8, 0.6, 8, Color(1, 1, 1, 0.25), 2.0)
	_draw_filled_ellipse(Vector2(-10, -16), Vector2(7, 4), Color(1, 1, 1, 0.18))


func _draw_hex_pattern(center: Vector2, radius: float, color: Color) -> void:
	# Draw a subtle hexagonal grid inside the shield
	var hex_size: float = 8.0
	for row in range(-3, 4):
		for col in range(-3, 4):
			var offset_x: float = col * hex_size * 1.5
			var offset_y: float = row * hex_size * 0.866 * 2.0
			if col % 2 != 0:
				offset_y += hex_size * 0.866
			var pos: Vector2 = center + Vector2(offset_x, offset_y)
			if pos.distance_to(center) < radius - 4.0:
				_draw_hex(pos, hex_size * 0.5, color)


func _draw_hex(pos: Vector2, sz: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var a: float = float(i) / 6.0 * TAU + PI / 6.0
		pts.append(pos + Vector2(cos(a) * sz, sin(a) * sz))
	if pts.size() >= 3:
		draw_polyline(pts, color, 0.6)


func _draw_oil_drips() -> void:
	var oil_col: Color = Color(0.85, 0.78, 0.2, 0.45)
	var oil_highlight: Color = Color(1.0, 0.95, 0.5, 0.3)
	# Oil drops rolling down body
	for i in range(5):
		var phase: float = anim_time * 1.2 + float(i) * 1.6
		var drop_y: float = fmod(phase * 12.0, 45.0) - 22.0
		var drop_x: float = sin(float(i) * 2.3) * 11.0
		var drop_sz: float = 1.8 + sin(phase) * 0.6
		draw_circle(Vector2(drop_x, drop_y), drop_sz, oil_col)
		# Tiny highlight on each drop
		draw_circle(Vector2(drop_x - 0.4, drop_y - 0.5), drop_sz * 0.35, oil_highlight)


func _draw_stumble_stars() -> void:
	var star_radius: float = 24.0
	var star_y: float = -34.0
	var num_stars: int = 4
	for i in range(num_stars):
		var a: float = stumble_star_angle + float(i) * (TAU / float(num_stars))
		var sx: float = cos(a) * star_radius
		var sy: float = star_y + sin(a) * 7.0
		var star_pulse: float = 0.8 + sin(anim_time * 5.0 + float(i)) * 0.2
		_draw_five_pointed_star(Vector2(sx, sy), 3.5 * star_pulse, Color(1.0, 0.95, 0.2, 0.9))


func _draw_five_pointed_star(pos: Vector2, sz: float, color: Color) -> void:
	# 5-pointed star polygon
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var a: float = float(i) / 10.0 * TAU - PI / 2.0
		var r: float = sz if i % 2 == 0 else sz * 0.4
		pts.append(pos + Vector2(cos(a) * r, sin(a) * r))
	if pts.size() >= 3:
		draw_colored_polygon(pts, color)
		# Outline for crispness
		draw_polyline(pts, color.darkened(0.2), 0.6)


func _draw_sweat_drops(flip: float) -> void:
	var sweat_col: Color = Color(0.55, 0.82, 1.0, 0.7)
	var back_x: float = -17.0 * flip

	# 3 sweat drops with teardrop shape
	for i in range(3):
		var phase: float = anim_time * 6.0 + float(i) * 1.8
		var y_base: float = -10.0 + float(i) * 5.0 + sin(phase) * 3.0
		var x_off: float = back_x + sin(float(i) * 1.5) * 3.0 * flip
		var alpha: float = 0.5 + sin(phase * 0.7) * 0.2

		# Teardrop: circle + small pointed top
		draw_circle(Vector2(x_off, y_base), 2.0, Color(sweat_col.r, sweat_col.g, sweat_col.b, alpha))
		# Point going backward
		var tail: PackedVector2Array = PackedVector2Array()
		tail.append(Vector2(x_off - 1.5, y_base))
		tail.append(Vector2(x_off - 4.0 * flip, y_base - 3.0))
		tail.append(Vector2(x_off + 1.5, y_base))
		if tail.size() >= 3:
			draw_colored_polygon(tail, Color(sweat_col.r, sweat_col.g, sweat_col.b, alpha * 0.7))
		# Highlight
		draw_circle(Vector2(x_off - 0.5, y_base - 0.8), 0.7, Color(1, 1, 1, alpha * 0.5))


func _draw_chili_steam(flip: float) -> void:
	var base_alpha: float = 0.3 + sin(anim_time * 4.0) * 0.1
	# Steam puffs from both sides of the head ("ears")
	for side in [-1.0, 1.0]:
		var base_x: float = side * 17.0
		for j in range(4):
			var t: float = anim_time * 3.0 + float(j) * 0.7
			var life: float = fmod(t, 2.0) / 2.0
			var offset_y: float = -life * 14.0 - 5.0
			var offset_x: float = side * (3.0 + life * 5.0)
			var sz: float = 1.5 + life * 2.5
			var alpha: float = base_alpha * (1.0 - life)
			# Steam circle
			draw_circle(Vector2(base_x + offset_x, -6.0 + offset_y), sz, Color(0.92, 0.92, 0.92, alpha))
			# Slightly offset secondary puff
			if j % 2 == 0:
				draw_circle(
					Vector2(base_x + offset_x + side * 1.5, -6.0 + offset_y - 1.5),
					sz * 0.6,
					Color(0.95, 0.95, 0.95, alpha * 0.6)
				)


func _draw_chili_tears(flip: float) -> void:
	# Tears/sweat flying off when burned
	var tear_col: Color = Color(0.5, 0.75, 1.0, 0.6)
	for i in range(2):
		var side: float = -1.0 + float(i) * 2.0
		var phase: float = anim_time * 5.0 + float(i) * PI
		var tear_y: float = -2.0 + sin(phase) * 4.0
		var tear_x: float = side * (12.0 + sin(phase * 0.8) * 3.0)
		# Tear drop
		draw_circle(Vector2(tear_x, tear_y), 1.5, tear_col)
		# Tear trail
		var trail_end: Vector2 = Vector2(tear_x + side * 4.0, tear_y - 3.0)
		draw_line(Vector2(tear_x, tear_y), trail_end, Color(tear_col.r, tear_col.g, tear_col.b, 0.3), 1.0)


func _draw_landing_dust() -> void:
	var t: float = 1.0 - (landing_dust_timer / 0.25)
	var dust_alpha: float = 0.45 * (1.0 - t)
	var dust_radius: float = 10.0 + t * 25.0
	var dust_col: Color = Color(0.7, 0.6, 0.45, dust_alpha)

	# Ring of dust puffs that expand and fade
	var num_puffs: int = 10
	for i in range(num_puffs):
		var a: float = float(i) / float(num_puffs) * TAU
		var px: float = cos(a) * dust_radius
		var py: float = 32.0 + sin(a) * 3.5 - t * 5.0
		var puff_sz: float = (2.5 + sin(float(i) * 1.7) * 1.2) * (1.0 - t * 0.5)
		draw_circle(Vector2(px, py), puff_sz, dust_col)
		# Secondary smaller puffs
		if i % 2 == 0:
			draw_circle(
				Vector2(px * 0.7, py + 1.5),
				puff_sz * 0.5,
				Color(dust_col.r, dust_col.g, dust_col.b, dust_alpha * 0.5)
			)


func _draw_blush(flip: float) -> void:
	var blush_alpha: float = 0.4 * clampf(blush_timer / 0.3, 0.0, 1.0)
	var blush_col: Color = Color(1.0, 0.45, 0.55, blush_alpha)
	# Two rosy circles on cheeks
	_draw_filled_ellipse(Vector2(-10 * flip, 5), Vector2(4.5, 2.8), blush_col)
	_draw_filled_ellipse(Vector2(10 * flip, 5), Vector2(4.5, 2.8), blush_col)
	# Subtle inner highlight
	_draw_filled_ellipse(Vector2(-10 * flip, 4.5), Vector2(2.5, 1.5), Color(1.0, 0.55, 0.6, blush_alpha * 0.5))
	_draw_filled_ellipse(Vector2(10 * flip, 4.5), Vector2(2.5, 1.5), Color(1.0, 0.55, 0.6, blush_alpha * 0.5))


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
