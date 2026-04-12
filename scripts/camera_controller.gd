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


func _ready() -> void:
	zoom = base_zoom
	GameManager.chili_activated.connect(_on_chili_activated)
	GameManager.player_died.connect(_on_player_died)


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

	# Dynamic zoom - zoom out when going fast
	var speed_factor := absf(target.velocity.x) * ZOOM_SPEED_FACTOR
	target_zoom = Vector2.ONE * clampf(base_zoom.x - speed_factor, MIN_ZOOM, MAX_ZOOM)
	zoom = zoom.lerp(target_zoom, 2.0 * delta)


func trigger_shake(intensity: float = 8.0, duration: float = 0.3) -> void:
	shake_intensity = intensity
	shake_decay = intensity / duration


func _on_chili_activated(_duration: float) -> void:
	var stacks := GameManager.chili_stacks
	trigger_shake(5.0 * stacks, 0.5)


func _on_player_died() -> void:
	trigger_shake(15.0, 0.8)
