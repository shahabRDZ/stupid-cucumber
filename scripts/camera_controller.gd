extends Camera2D

## Smooth camera follow with screen shake and dynamic zoom

@export var target: CharacterBody2D = null

# Follow settings
const FOLLOW_SPEED: float = 5.0
const LOOK_AHEAD: float = 120.0
const VERTICAL_OFFSET: float = -80.0

# Screen shake
var shake_intensity: float = 0.0
var shake_decay: float = 5.0
var shake_timer: float = 0.0

# Dynamic zoom
var base_zoom: Vector2 = Vector2(1.8, 1.8)
var target_zoom: Vector2 = Vector2(1.8, 1.8)
const ZOOM_SPEED_FACTOR: float = 0.0005
const MIN_ZOOM: float = 1.4
const MAX_ZOOM: float = 2.0

# Slow-motion effects
var slow_mo_zoom_offset: float = 0.0
var slow_mo_active: bool = false


func _ready() -> void:
	zoom = base_zoom
	GameManager.chili_activated.connect(_on_chili_activated)
	GameManager.player_died.connect(_on_player_died)
	GameManager.slow_mo_started.connect(_on_slow_mo_started)
	GameManager.slow_mo_ended.connect(_on_slow_mo_ended)
	GameManager.boss_spawned.connect(_on_boss_spawned)


func _process(delta: float) -> void:
	if target == null:
		return

	# Calculate target position with look-ahead
	var look_ahead_x := target.velocity.x * 0.15
	look_ahead_x = clampf(look_ahead_x, -LOOK_AHEAD, LOOK_AHEAD)

	var target_pos := Vector2(
		target.global_position.x + look_ahead_x,
		target.global_position.y + VERTICAL_OFFSET
	)

	# Smooth follow
	global_position = global_position.lerp(target_pos, FOLLOW_SPEED * delta)

	# Screen shake
	if shake_intensity > 0:
		shake_intensity = maxf(shake_intensity - shake_decay * delta, 0)
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		offset = Vector2.ZERO

	# Ease slow-mo zoom offset back toward 0
	slow_mo_zoom_offset = lerpf(slow_mo_zoom_offset, 0.0, 3.0 * delta)

	# Dynamic zoom - zoom out when going fast
	var speed_factor := absf(target.velocity.x) * ZOOM_SPEED_FACTOR
	target_zoom = Vector2.ONE * clampf(base_zoom.x - speed_factor + slow_mo_zoom_offset, MIN_ZOOM, MAX_ZOOM)
	zoom = zoom.lerp(target_zoom, 2.0 * delta)

	# Chromatic-aberration-like offset during slow-mo
	if slow_mo_active:
		offset += Vector2(randf_range(-1.0, 1.0), randf_range(-0.5, 0.5))


func trigger_shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	shake_intensity = intensity
	shake_decay = intensity / duration


func _on_chili_activated(_duration: float) -> void:
	var stacks := GameManager.chili_stacks
	trigger_shake(5.0 * stacks, 0.5)


func _on_player_died() -> void:
	trigger_shake(15.0, 0.8)


func _on_slow_mo_started() -> void:
	slow_mo_active = true
	slow_mo_zoom_offset = 0.3  # temporary zoom in


func _on_slow_mo_ended() -> void:
	slow_mo_active = false
	slow_mo_zoom_offset = 0.0


func _on_boss_spawned() -> void:
	# Dramatic zoom out when boss appears
	slow_mo_zoom_offset = -0.4
	trigger_shake(10.0, 0.6)
