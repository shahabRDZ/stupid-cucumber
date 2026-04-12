extends Node2D

## Procedural level generator - "Stupid Cucumber" endless side-scroller
## Generates biome-aware platform chunks, obstacles, enemies, and collectibles

const CHUNK_WIDTH: float = 800.0
const CLEANUP_DISTANCE: float = 1500.0
const GENERATE_AHEAD: float = 2000.0

var player: CharacterBody2D = null
var last_generated_x: float = 0.0
var chunk_count: int = 0

# Ground level
const GROUND_Y: float = 500.0
const MIN_PLATFORM_Y: float = 150.0

# Platform themes per biome -----------------------------------------------
var garden_themes: Array[Dictionary] = [
	{"name": "watermelon", "color": Color(0.2, 0.7, 0.3), "stripe": Color(0.15, 0.55, 0.2), "accent": Color(0.9, 0.3, 0.3)},
	{"name": "carrot", "color": Color(1.0, 0.6, 0.2), "stripe": Color(0.9, 0.5, 0.1), "accent": Color(0.3, 0.7, 0.2)},
	{"name": "eggplant", "color": Color(0.4, 0.2, 0.5), "stripe": Color(0.3, 0.15, 0.4), "accent": Color(0.5, 0.3, 0.6)},
]

var kitchen_themes: Array[Dictionary] = [
	{"name": "cutting_board", "color": Color(0.55, 0.35, 0.18), "stripe": Color(0.45, 0.28, 0.12), "accent": Color(0.65, 0.45, 0.25)},
	{"name": "plate", "color": Color(0.92, 0.92, 0.95), "stripe": Color(0.82, 0.82, 0.88), "accent": Color(0.7, 0.75, 0.85)},
	{"name": "pot", "color": Color(0.55, 0.55, 0.6), "stripe": Color(0.45, 0.45, 0.5), "accent": Color(0.72, 0.72, 0.75)},
]

var fridge_themes: Array[Dictionary] = [
	{"name": "ice_cube", "color": Color(0.6, 0.82, 0.95, 0.8), "stripe": Color(0.5, 0.72, 0.88, 0.6), "accent": Color(0.85, 0.93, 1.0, 0.9)},
	{"name": "frozen_pea", "color": Color(0.35, 0.7, 0.3), "stripe": Color(0.25, 0.55, 0.22), "accent": Color(0.6, 0.85, 0.55)},
	{"name": "cheese", "color": Color(1.0, 0.85, 0.3), "stripe": Color(0.9, 0.75, 0.2), "accent": Color(1.0, 0.92, 0.5)},
]


func _get_biome_themes() -> Array[Dictionary]:
	match GameManager.current_biome:
		GameManager.Biome.KITCHEN:
			return kitchen_themes
		GameManager.Biome.FRIDGE:
			return fridge_themes
		_:
			return garden_themes


func _pick_theme() -> Dictionary:
	var themes: Array[Dictionary] = _get_biome_themes()
	return themes[randi() % themes.size()]


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	_generate_starting_area()


func _process(_delta: float) -> void:
	if player == null:
		return

	while last_generated_x < player.global_position.x + GENERATE_AHEAD:
		_generate_chunk(last_generated_x)
		last_generated_x += CHUNK_WIDTH
		chunk_count += 1

	for child in get_children():
		if child.global_position.x < player.global_position.x - CLEANUP_DISTANCE:
			child.queue_free()


# ============================================================
# CHUNK GENERATION
# ============================================================

func _generate_starting_area() -> void:
	_create_ground_platform(-200, 1200, GROUND_Y)
	for i in range(5):
		_create_salt(Vector2(200 + i * 80, GROUND_Y - 50))
	last_generated_x = 1000.0


func _generate_chunk(start_x: float) -> void:
	var difficulty: float = GameManager.difficulty
	var rng: float = randf()

	if rng < 0.7:
		_generate_ground_section(start_x, difficulty)
	elif rng < 0.85:
		_generate_gap_section(start_x, difficulty)
	else:
		_generate_elevated_section(start_x, difficulty)

	_scatter_collectibles(start_x, difficulty)
	_scatter_obstacles(start_x, difficulty)
	_scatter_enemies(start_x, difficulty)


func _generate_ground_section(start_x: float, difficulty: float) -> void:
	var segments: int = randi_range(2, 4)
	var current_x: float = start_x
	var segment_width: float = CHUNK_WIDTH / segments

	for i in range(segments):
		var height_offset: float = randf_range(-60, 30) * difficulty
		var ground_y: float = GROUND_Y + height_offset
		_create_ground_platform(current_x, segment_width + 20, ground_y)

		if randf() < 0.3 * difficulty:
			var plat_y: float = ground_y - randf_range(80, 160)
			var plat_w: float = randf_range(80, 160)
			_create_platform(current_x + segment_width * 0.3, plat_w, plat_y)

		current_x += segment_width

	if randf() < 0.4:
		_create_ramp(start_x + CHUNK_WIDTH * 0.5, GROUND_Y)


func _generate_gap_section(start_x: float, difficulty: float) -> void:
	var gap_start: float = start_x + 200
	var gap_width: float = randf_range(150, 300) * difficulty

	_create_ground_platform(start_x, 200, GROUND_Y)
	_create_ground_platform(gap_start + gap_width, CHUNK_WIDTH - 200 - gap_width, GROUND_Y)

	var plat_count: int = randi_range(1, 3)
	for i in range(plat_count):
		var px: float = gap_start + (gap_width / (plat_count + 1)) * (i + 1)
		var py: float = GROUND_Y - randf_range(40, 140)
		_create_platform(px - 40, randf_range(60, 120), py)


func _generate_elevated_section(start_x: float, _difficulty: float) -> void:
	var step_count: int = randi_range(3, 6)
	var step_height: float = 60.0
	var step_width: float = CHUNK_WIDTH / (step_count + 1)

	_create_ground_platform(start_x, step_width, GROUND_Y)

	for i in range(step_count):
		var is_ascending: bool = i < step_count / 2
		var height_index: int = i if is_ascending else step_count - i
		var px: float = start_x + step_width * (i + 1)
		var py: float = GROUND_Y - height_index * step_height
		var pw: float = randf_range(80, 140)
		_create_platform(px, pw, py)

	_create_ground_platform(start_x + CHUNK_WIDTH - step_width, step_width + 100, GROUND_Y)


# ============================================================
# OBSTACLES
# ============================================================

func _scatter_obstacles(start_x: float, difficulty: float) -> void:
	var obstacle_chance: float = 0.15 + difficulty * 0.1
	# Biome weights
	var biome: int = GameManager.current_biome
	var knife_weight: float = 1.0
	var fork_weight: float = 1.0
	var spike_weight: float = 1.0

	if biome == GameManager.Biome.KITCHEN:
		knife_weight = 2.5
		fork_weight = 2.0
	elif biome == GameManager.Biome.FRIDGE:
		spike_weight = 2.5
	elif biome == GameManager.Biome.GARDEN:
		spike_weight = 1.5

	if randf() < obstacle_chance:
		var total_w: float = knife_weight + fork_weight + spike_weight
		var roll: float = randf() * total_w
		var ox: float = start_x + randf_range(150, CHUNK_WIDTH - 100)
		if roll < knife_weight:
			_create_knife(Vector2(ox, GROUND_Y))
		elif roll < knife_weight + fork_weight:
			_create_fork(Vector2(ox, GROUND_Y))
		else:
			_create_spikes(Vector2(ox, GROUND_Y))


func _create_knife(pos: Vector2) -> void:
	var knife := KnifeObstacle.new()
	knife.position = pos
	add_child(knife)


func _create_fork(pos: Vector2) -> void:
	var fork := ForkObstacle.new()
	fork.position = pos
	add_child(fork)


func _create_spikes(pos: Vector2) -> void:
	var spikes := SpikeObstacle.new()
	spikes.position = pos
	add_child(spikes)


# ============================================================
# ENEMIES
# ============================================================

func _scatter_enemies(start_x: float, difficulty: float) -> void:
	var enemy_chance: float = 0.12 + difficulty * 0.08
	if randf() < enemy_chance:
		var ex: float = start_x + randf_range(200, CHUNK_WIDTH - 150)
		var ey: float = GROUND_Y  # spawn on ground level; gravity will handle landing
		if randf() < 0.6:
			_create_angry_tomato(Vector2(ex, ey - 20))
		else:
			_create_crying_onion(Vector2(ex, ey - 22))


func _create_angry_tomato(pos: Vector2) -> void:
	var tomato := AngryTomato.new()
	tomato.position = pos
	add_child(tomato)


func _create_crying_onion(pos: Vector2) -> void:
	var onion := CryingOnion.new()
	onion.position = pos
	add_child(onion)


# ============================================================
# COLLECTIBLES
# ============================================================

func _scatter_collectibles(start_x: float, difficulty: float) -> void:
	var pattern: int = randi() % 4

	match pattern:
		0:  # Horizontal line
			var count: int = randi_range(3, 8)
			var y: float = GROUND_Y - randf_range(40, 120)
			for i in range(count):
				_create_salt(Vector2(start_x + 100 + i * 50, y))
		1:  # Arc
			var count: int = randi_range(5, 10)
			var center_x: float = start_x + CHUNK_WIDTH * 0.5
			var base_y: float = GROUND_Y - 60
			for i in range(count):
				var t: float = float(i) / float(count - 1) - 0.5
				var x: float = center_x + t * 300
				var y: float = base_y - (1.0 - t * t * 4) * 80
				_create_salt(Vector2(x, y))
		2:  # Vertical stack
			var count: int = randi_range(3, 5)
			var x: float = start_x + randf_range(200, 600)
			for i in range(count):
				_create_salt(Vector2(x, GROUND_Y - 40 - i * 40))
		3:  # Circle pattern
			var center := Vector2(start_x + CHUNK_WIDTH * 0.5, GROUND_Y - 120)
			var count: int = randi_range(6, 10)
			for i in range(count):
				var angle: float = float(i) / float(count) * TAU
				var pos: Vector2 = center + Vector2(cos(angle) * 60, sin(angle) * 40)
				_create_salt(pos)

	# Chili pepper
	if randf() < 0.15 + difficulty * 0.05:
		var chili_x: float = start_x + randf_range(200, 600)
		var chili_y: float = GROUND_Y - randf_range(50, 150)
		_create_chili(Vector2(chili_x, chili_y))

	# Yogurt (rarer)
	if randf() < 0.08 + difficulty * 0.03:
		var yog_x: float = start_x + randf_range(100, 700)
		var yog_y: float = GROUND_Y - randf_range(60, 160)
		_create_yogurt(Vector2(yog_x, yog_y))

	# Olive oil (rarer)
	if randf() < 0.08 + difficulty * 0.03:
		var oil_x: float = start_x + randf_range(100, 700)
		var oil_y: float = GROUND_Y - randf_range(60, 160)
		_create_olive_oil(Vector2(oil_x, oil_y))


# ============================================================
# FACTORY HELPERS
# ============================================================

func _create_ground_platform(x: float, width: float, y: float) -> void:
	var platform := StaticBody2D.new()
	platform.position = Vector2(x, y)
	platform.collision_layer = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 40)
	shape.shape = rect
	shape.position = Vector2(width / 2, 20)
	platform.add_child(shape)

	var visual := PlatformVisual.new()
	visual.platform_width = width
	visual.platform_height = 40
	visual.is_ground = true
	visual.theme_data = _pick_theme()
	visual.biome = GameManager.current_biome
	platform.add_child(visual)

	add_child(platform)


func _create_platform(x: float, width: float, y: float) -> void:
	var platform := StaticBody2D.new()
	platform.position = Vector2(x, y)
	platform.collision_layer = 2

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 24)
	shape.shape = rect
	shape.position = Vector2(width / 2, 12)
	platform.add_child(shape)

	var visual := PlatformVisual.new()
	visual.platform_width = width
	visual.platform_height = 24
	visual.is_ground = false
	visual.theme_data = _pick_theme()
	visual.biome = GameManager.current_biome
	platform.add_child(visual)

	add_child(platform)


func _create_ramp(x: float, y: float) -> void:
	var ramp := StaticBody2D.new()
	ramp.position = Vector2(x, y)
	ramp.collision_layer = 2

	var shape := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([
		Vector2(0, 0),
		Vector2(120, 0),
		Vector2(120, -60),
	])
	shape.shape = poly
	ramp.add_child(shape)

	var visual := RampVisual.new()
	visual.biome = GameManager.current_biome
	ramp.add_child(visual)

	add_child(ramp)


func _create_salt(pos: Vector2) -> void:
	var salt := Area2D.new()
	salt.position = pos
	salt.collision_layer = 4
	salt.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14
	shape.shape = circle
	salt.add_child(shape)

	var visual := SaltVisual.new()
	salt.add_child(visual)

	salt.body_entered.connect(_on_salt_collected.bind(salt))
	add_child(salt)


func _create_chili(pos: Vector2) -> void:
	var chili := Area2D.new()
	chili.position = pos
	chili.collision_layer = 4
	chili.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 28)
	shape.shape = rect
	chili.add_child(shape)

	var visual := ChiliVisual.new()
	chili.add_child(visual)

	chili.body_entered.connect(_on_chili_collected.bind(chili))
	add_child(chili)


func _create_yogurt(pos: Vector2) -> void:
	var yogurt := Area2D.new()
	yogurt.position = pos
	yogurt.collision_layer = 4
	yogurt.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 22)
	shape.shape = rect
	yogurt.add_child(shape)

	var visual := YogurtVisual.new()
	yogurt.add_child(visual)

	yogurt.body_entered.connect(_on_yogurt_collected.bind(yogurt))
	add_child(yogurt)


func _create_olive_oil(pos: Vector2) -> void:
	var oil := Area2D.new()
	oil.position = pos
	oil.collision_layer = 4
	oil.collision_mask = 1

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 26)
	shape.shape = rect
	oil.add_child(shape)

	var visual := OliveOilVisual.new()
	oil.add_child(visual)

	oil.body_entered.connect(_on_oil_collected.bind(oil))
	add_child(oil)


# ============================================================
# COLLECTIBLE CALLBACKS
# ============================================================

func _on_salt_collected(body: Node2D, salt: Area2D) -> void:
	if body is CharacterBody2D and body.has_method("collect_salt"):
		body.collect_salt()
		_spawn_collect_effect(salt.global_position, Color(0.9, 0.9, 1.0))
		salt.queue_free()


func _on_chili_collected(body: Node2D, chili: Area2D) -> void:
	if body is CharacterBody2D and body.has_method("collect_chili"):
		body.collect_chili()
		_spawn_collect_effect(chili.global_position, Color(1.0, 0.3, 0.1))
		chili.queue_free()


func _on_yogurt_collected(body: Node2D, yogurt: Area2D) -> void:
	if body is CharacterBody2D and body.has_method("collect_yogurt"):
		body.collect_yogurt()
		_spawn_collect_effect(yogurt.global_position, Color(0.85, 0.9, 1.0))
		yogurt.queue_free()


func _on_oil_collected(body: Node2D, oil: Area2D) -> void:
	if body is CharacterBody2D and body.has_method("collect_oil"):
		body.collect_oil()
		_spawn_collect_effect(oil.global_position, Color(0.95, 0.85, 0.3))
		oil.queue_free()


func _spawn_collect_effect(pos: Vector2, color: Color) -> void:
	var effect := CollectEffect.new()
	effect.position = pos
	effect.color = color
	add_child(effect)


# ############################################################
# INNER CLASSES
# ############################################################

# ============================================================
# PLATFORM VISUAL (biome-aware)
# ============================================================

class PlatformVisual extends Node2D:
	var platform_width: float = 100
	var platform_height: float = 24
	var is_ground: bool = false
	var theme_data: Dictionary = {}
	var biome: int = 0  # GameManager.Biome value

	func _draw() -> void:
		var color: Color = theme_data.get("color", Color(0.4, 0.7, 0.3))
		var stripe: Color = theme_data.get("stripe", Color(0.3, 0.6, 0.2))
		var accent: Color = theme_data.get("accent", Color(0.9, 0.3, 0.3))
		var theme_name: String = theme_data.get("name", "")

		if is_ground:
			_draw_ground(color, stripe, accent, theme_name)
		else:
			_draw_floating(color, stripe, accent, theme_name)

	func _draw_ground(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		# Main body
		draw_rect(Rect2(0, 0, platform_width, platform_height), color)
		# Surface layer
		draw_rect(Rect2(0, 0, platform_width, 6), accent)
		# Underground depth
		draw_rect(Rect2(0, platform_height, platform_width, 200), color.darkened(0.4))

		# Biome-specific ground decorations
		if biome == 0:  # GARDEN
			# Grass blades on top
			for i in range(int(platform_width / 18)):
				var gx: float = i * 18.0 + randf_range(0, 6)
				var gh: float = randf_range(4, 10)
				draw_line(Vector2(gx, 0), Vector2(gx - 2, -gh), Color(0.25, 0.7, 0.2, 0.7), 1.5)
			# Dirt texture stripes
			for i in range(int(platform_width / 30)):
				var sx: float = i * 30.0 + randf_range(0, 10)
				draw_rect(Rect2(sx, 12, 15, 4), stripe)
		elif biome == 1:  # KITCHEN
			# Tile grout lines
			for i in range(int(platform_width / 50)):
				var lx: float = i * 50.0
				draw_line(Vector2(lx, 0), Vector2(lx, platform_height), stripe.darkened(0.2), 1.0)
			# Top edge - metallic trim
			draw_rect(Rect2(0, 0, platform_width, 3), accent.lightened(0.2))
		elif biome == 2:  # FRIDGE
			# Frost crystals on surface
			for i in range(int(platform_width / 22)):
				var fx: float = i * 22.0 + randf_range(0, 8)
				draw_circle(Vector2(fx, 3), randf_range(2, 4), Color(0.9, 0.95, 1.0, 0.5))
			# Icy sheen
			draw_rect(Rect2(0, 0, platform_width, 4), Color(0.8, 0.92, 1.0, 0.45))

	func _draw_floating(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		if biome == 0:  # GARDEN
			_draw_garden_platform(color, stripe, accent, theme_name)
		elif biome == 1:  # KITCHEN
			_draw_kitchen_platform(color, stripe, accent, theme_name)
		else:  # FRIDGE
			_draw_fridge_platform(color, stripe, accent, theme_name)

	func _draw_garden_platform(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		# Organic rounded look
		draw_rect(Rect2(0, 0, platform_width, platform_height), color)
		draw_rect(Rect2(0, 0, platform_width, 4), color.lightened(0.3))
		draw_rect(Rect2(0, platform_height - 3, platform_width, 3), color.darkened(0.2))

		if theme_name == "watermelon":
			# Seed dots
			for i in range(int(platform_width / 25)):
				var sx: float = 12 + i * 25.0
				draw_circle(Vector2(sx, platform_height * 0.5), 2.5, Color(0.15, 0.1, 0.05))
			# Stripes
			for i in range(int(platform_width / 40)):
				var lx: float = i * 40.0 + 10
				draw_rect(Rect2(lx, 2, 8, platform_height - 4), stripe.lerp(color, 0.5))
		elif theme_name == "carrot":
			# Horizontal lines like carrot ridges
			for i in range(3):
				var ly: float = 6 + i * 6.0
				draw_line(Vector2(4, ly), Vector2(platform_width - 4, ly), stripe, 1.0)
			# Small green leaf tufts at ends
			draw_circle(Vector2(platform_width - 4, -2), 5, accent)
			draw_circle(Vector2(platform_width + 1, -4), 4, accent.lightened(0.15))
		elif theme_name == "eggplant":
			# Glossy highlight
			draw_rect(Rect2(4, 3, platform_width * 0.4, 4), accent.lerp(Color.WHITE, 0.3))
			# Stem cap
			draw_rect(Rect2(0, -3, 14, 5), Color(0.25, 0.5, 0.15))

	func _draw_kitchen_platform(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		if theme_name == "cutting_board":
			# Wood grain
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			for i in range(int(platform_width / 12)):
				var gx: float = i * 12.0 + randf_range(0, 4)
				draw_line(Vector2(gx, 1), Vector2(gx + randf_range(-2, 2), platform_height - 1), stripe, 0.8)
			# Top bevel
			draw_rect(Rect2(0, 0, platform_width, 2), accent)
			# Bottom shadow
			draw_rect(Rect2(0, platform_height - 2, platform_width, 2), color.darkened(0.3))
		elif theme_name == "plate":
			# White ceramic with rim
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Curved rim effect (top highlight)
			draw_rect(Rect2(0, 0, platform_width, 3), Color(1.0, 1.0, 1.0, 0.8))
			# Subtle blue ring pattern
			draw_rect(Rect2(4, platform_height * 0.4, platform_width - 8, 2), accent.lerp(Color.WHITE, 0.4))
			# Bottom shadow
			draw_rect(Rect2(2, platform_height - 3, platform_width - 4, 3), stripe)
		elif theme_name == "pot":
			# Metallic pot body
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Metallic sheen highlight
			draw_rect(Rect2(0, 2, platform_width, 5), accent.lerp(Color.WHITE, 0.3))
			# Rivet dots
			draw_circle(Vector2(8, platform_height * 0.5), 2.5, color.darkened(0.3))
			draw_circle(Vector2(platform_width - 8, platform_height * 0.5), 2.5, color.darkened(0.3))
			# Handle nub on one side
			draw_rect(Rect2(-6, 4, 8, platform_height - 8), color.darkened(0.15))

	func _draw_fridge_platform(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		if theme_name == "ice_cube":
			# Translucent blue ice
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Internal cracks
			for i in range(int(platform_width / 35)):
				var cx: float = i * 35.0 + randf_range(5, 15)
				draw_line(
					Vector2(cx, randf_range(2, 6)),
					Vector2(cx + randf_range(-8, 8), platform_height - randf_range(2, 6)),
					Color(1.0, 1.0, 1.0, 0.25), 1.0
				)
			# Surface glint
			draw_rect(Rect2(0, 0, platform_width, 3), accent)
			# Frost edge
			draw_rect(Rect2(0, platform_height - 2, platform_width, 2), stripe)
		elif theme_name == "frozen_pea":
			# Bumpy green surface
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			for i in range(int(platform_width / 18)):
				var px: float = 9 + i * 18.0
				draw_circle(Vector2(px, platform_height * 0.5), 7, stripe.lerp(color, 0.6))
				draw_circle(Vector2(px, platform_height * 0.35), 3, accent.lerp(Color.WHITE, 0.3))
			# Frost dusting
			draw_rect(Rect2(0, 0, platform_width, 2), Color(0.9, 0.95, 1.0, 0.35))
		elif theme_name == "cheese":
			# Yellow cheese with holes
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Holes
			for i in range(int(platform_width / 30)):
				var hx: float = 15 + i * 30.0
				var hy: float = platform_height * randf_range(0.3, 0.7)
				var hr: float = randf_range(3, 6)
				draw_circle(Vector2(hx, hy), hr, stripe)
				draw_circle(Vector2(hx - 1, hy - 1), hr * 0.5, accent.lerp(Color.WHITE, 0.2))
			# Shiny top
			draw_rect(Rect2(0, 0, platform_width, 3), accent)


# ============================================================
# RAMP VISUAL (biome-aware)
# ============================================================

class RampVisual extends Node2D:
	var biome: int = 0

	func _draw() -> void:
		var points := PackedVector2Array([
			Vector2(0, 0),
			Vector2(120, 0),
			Vector2(120, -60),
		])
		var fill_color := Color(0.5, 0.8, 0.3)
		var edge_color := Color(0.3, 0.6, 0.2)

		if biome == 1:  # KITCHEN
			fill_color = Color(0.55, 0.38, 0.2)
			edge_color = Color(0.4, 0.28, 0.12)
		elif biome == 2:  # FRIDGE
			fill_color = Color(0.6, 0.82, 0.95, 0.75)
			edge_color = Color(0.45, 0.65, 0.85)

		draw_colored_polygon(points, fill_color)
		draw_polyline(points, edge_color, 2.0)


# ============================================================
# SALT VISUAL
# ============================================================

class SaltVisual extends Node2D:
	var bob_offset: float = 0.0
	var sparkle_timer: float = 0.0

	func _ready() -> void:
		bob_offset = randf() * TAU

	func _process(delta: float) -> void:
		bob_offset += delta * 3.0
		sparkle_timer += delta
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(bob_offset) * 4.0
		var center := Vector2(0, bob)

		var crystal_color := Color(0.85, 0.88, 0.95, 0.9)
		var shine_color := Color(1.0, 1.0, 1.0, 0.8)

		# Main crystal body - diamond
		var points := PackedVector2Array([
			center + Vector2(0, -12),
			center + Vector2(10, 0),
			center + Vector2(0, 12),
			center + Vector2(-10, 0),
		])
		draw_colored_polygon(points, crystal_color)

		# Inner shine
		var inner := PackedVector2Array([
			center + Vector2(0, -7),
			center + Vector2(5, 0),
			center + Vector2(0, 7),
			center + Vector2(-5, 0),
		])
		draw_colored_polygon(inner, shine_color)

		# Sparkle
		var sparkle_phase: float = fmod(sparkle_timer * 2.0, 1.0)
		if sparkle_phase < 0.3:
			var s: float = sparkle_phase / 0.3
			draw_line(center + Vector2(-6, -6), center + Vector2(-6 - 4 * s, -6 - 4 * s), Color.WHITE, 1.5)
			draw_line(center + Vector2(5, -8), center + Vector2(5 + 3 * s, -8 - 3 * s), Color.WHITE, 1.5)


# ============================================================
# CHILI VISUAL
# ============================================================

class ChiliVisual extends Node2D:
	var glow_timer: float = 0.0

	func _process(delta: float) -> void:
		glow_timer += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = sin(glow_timer * 4.0) * 0.15 + 1.0

		# Glow
		var glow_alpha: float = 0.15 + sin(glow_timer * 3.0) * 0.1
		draw_circle(Vector2.ZERO, 18 * pulse, Color(1.0, 0.3, 0.0, glow_alpha))

		# Chili body
		var chili_red := Color(0.85, 0.15, 0.1)

		var body_points := PackedVector2Array([
			Vector2(0, -14), Vector2(5, -10), Vector2(7, -4),
			Vector2(6, 4), Vector2(4, 10), Vector2(2, 14),
			Vector2(-2, 14), Vector2(-4, 10), Vector2(-6, 4),
			Vector2(-7, -4), Vector2(-5, -10),
		])
		draw_colored_polygon(body_points, chili_red)

		# Highlight
		var highlight := PackedVector2Array([
			Vector2(-2, -10), Vector2(0, -6), Vector2(1, 0),
			Vector2(-1, 0), Vector2(-3, -6),
		])
		draw_colored_polygon(highlight, chili_red.lightened(0.3))

		# Stem
		draw_rect(Rect2(-2, -18, 4, 5), Color(0.2, 0.6, 0.15))
		draw_circle(Vector2(0, -18), 3, Color(0.25, 0.65, 0.2))


# ============================================================
# YOGURT VISUAL
# ============================================================

class YogurtVisual extends Node2D:
	var bob_offset: float = 0.0

	func _ready() -> void:
		bob_offset = randf() * TAU

	func _process(delta: float) -> void:
		bob_offset += delta * 2.5
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(bob_offset) * 3.0

		# Cup body - white/blue
		var cup_color := Color(0.9, 0.92, 0.98)
		var cup_top := Vector2(0, bob - 10)
		var cup_bot := Vector2(0, bob + 10)

		# Cup shape (trapezoid)
		var cup_pts := PackedVector2Array([
			cup_top + Vector2(-9, 0),
			cup_top + Vector2(9, 0),
			cup_bot + Vector2(7, 0),
			cup_bot + Vector2(-7, 0),
		])
		draw_colored_polygon(cup_pts, cup_color)

		# Blue label band
		draw_rect(Rect2(-8, bob - 3, 16, 6), Color(0.45, 0.6, 0.9))

		# Lid / foil top
		draw_rect(Rect2(-10, bob - 12, 20, 3), Color(0.75, 0.78, 0.85))

		# Yogurt cream swirl on top
		draw_circle(Vector2(0, bob - 11), 4, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(Vector2(2, bob - 12), 2.5, Color(0.95, 0.95, 1.0))

		# Spoon sticking out
		draw_line(Vector2(4, bob - 12), Vector2(12, bob - 20), Color(0.75, 0.75, 0.78), 2.0)
		# Spoon bowl
		var spoon_pts := PackedVector2Array([
			Vector2(11, bob - 20), Vector2(15, bob - 22),
			Vector2(14, bob - 18), Vector2(10, bob - 19),
		])
		draw_colored_polygon(spoon_pts, Color(0.78, 0.78, 0.82))

		# Subtle glow
		draw_circle(Vector2(0, bob), 14, Color(0.85, 0.9, 1.0, 0.12))


# ============================================================
# OLIVE OIL VISUAL
# ============================================================

class OliveOilVisual extends Node2D:
	var bob_offset: float = 0.0
	var shimmer_timer: float = 0.0

	func _ready() -> void:
		bob_offset = randf() * TAU

	func _process(delta: float) -> void:
		bob_offset += delta * 2.5
		shimmer_timer += delta
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(bob_offset) * 3.0
		var center := Vector2(0, bob)

		# Bottle body - golden glass
		var bottle_color := Color(0.85, 0.72, 0.2, 0.85)
		var bottle_pts := PackedVector2Array([
			center + Vector2(-6, -8),
			center + Vector2(6, -8),
			center + Vector2(7, 8),
			center + Vector2(5, 12),
			center + Vector2(-5, 12),
			center + Vector2(-7, 8),
		])
		draw_colored_polygon(bottle_pts, bottle_color)

		# Bottle neck
		draw_rect(Rect2(-3, center.y - 14, 6, 7), Color(0.8, 0.68, 0.18, 0.9))

		# Cap / cork
		draw_rect(Rect2(-4, center.y - 17, 8, 4), Color(0.5, 0.35, 0.15))

		# Label area (cream colored)
		draw_rect(Rect2(-5, center.y - 2, 10, 8), Color(0.95, 0.92, 0.82))

		# Olive branch on label - tiny green circle + line
		draw_line(Vector2(-2, center.y + 1), Vector2(3, center.y - 1), Color(0.3, 0.55, 0.2), 1.0)
		draw_circle(Vector2(3, center.y - 1), 2, Color(0.35, 0.5, 0.15))
		draw_circle(Vector2(0, center.y + 1), 2, Color(0.35, 0.5, 0.15))

		# Liquid shimmer inside bottle
		var shimmer: float = sin(shimmer_timer * 3.0) * 0.15
		draw_rect(Rect2(-4, center.y + 2, 3, 5), Color(1.0, 0.9, 0.4, 0.25 + shimmer))

		# Glow
		draw_circle(center, 16, Color(0.95, 0.85, 0.3, 0.1))


# ============================================================
# COLLECT EFFECT
# ============================================================

class CollectEffect extends Node2D:
	var lifetime: float = 0.4
	var timer: float = 0.0
	var color: Color = Color.WHITE
	var particles: Array[Dictionary] = []

	func _ready() -> void:
		for i in range(8):
			var angle: float = float(i) / 8.0 * TAU
			particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(angle), sin(angle)) * randf_range(60, 120),
				"size": randf_range(2, 5),
			})

	func _process(delta: float) -> void:
		timer += delta
		if timer >= lifetime:
			queue_free()
			return
		for p in particles:
			p["pos"] += p["vel"] * delta
			p["vel"] *= 0.95
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - timer / lifetime
		for p in particles:
			var ppos: Vector2 = p["pos"]
			var psize: float = p["size"]
			draw_circle(ppos, psize * alpha, Color(color.r, color.g, color.b, alpha))


# ############################################################
# OBSTACLE INNER CLASSES
# ############################################################

# ============================================================
# KNIFE OBSTACLE
# ============================================================

class KnifeObstacle extends Area2D:
	var glint_timer: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 1

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(10, 50)
		shape.shape = rect
		shape.position = Vector2(0, -25)
		add_child(shape)

		var visual := KnifeVisual.new()
		add_child(visual)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		glint_timer += delta

	func _on_body_entered(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()


class KnifeVisual extends Node2D:
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var parent_node: Node = get_parent()
		var gt: float = 0.0
		if parent_node and "glint_timer" in parent_node:
			gt = parent_node.glint_timer

		# Handle - brown wooden grip
		var handle_color := Color(0.45, 0.28, 0.12)
		var handle_dark := Color(0.35, 0.2, 0.08)
		draw_rect(Rect2(-5, -8, 10, 20), handle_color)
		# Handle texture lines
		draw_line(Vector2(-3, -5), Vector2(-3, 9), handle_dark, 1.0)
		draw_line(Vector2(0, -5), Vector2(0, 9), handle_dark, 1.0)
		draw_line(Vector2(3, -5), Vector2(3, 9), handle_dark, 1.0)
		# Handle rivets
		draw_circle(Vector2(0, -2), 1.5, Color(0.65, 0.65, 0.6))
		draw_circle(Vector2(0, 6), 1.5, Color(0.65, 0.65, 0.6))

		# Guard / bolster
		draw_rect(Rect2(-6, -10, 12, 3), Color(0.6, 0.6, 0.62))

		# Blade - silver, pointing up
		var blade_color := Color(0.78, 0.8, 0.82)
		var blade_pts := PackedVector2Array([
			Vector2(-4, -10),
			Vector2(4, -10),
			Vector2(3, -35),
			Vector2(0, -50),
			Vector2(-1, -35),
		])
		draw_colored_polygon(blade_pts, blade_color)

		# Blade edge highlight
		draw_line(Vector2(0, -50), Vector2(4, -10), Color(0.92, 0.93, 0.95), 1.0)

		# Blade center line
		draw_line(Vector2(0, -12), Vector2(1, -45), Color(0.85, 0.87, 0.9, 0.6), 1.0)

		# Occasional glint
		var glint_phase: float = fmod(gt * 0.8, 3.0)
		if glint_phase < 0.25:
			var ga: float = (0.25 - glint_phase) * 4.0
			draw_circle(Vector2(2, -30), 3, Color(1.0, 1.0, 1.0, ga * 0.7))
			draw_line(Vector2(-1, -33), Vector2(5, -27), Color(1.0, 1.0, 1.0, ga * 0.5), 1.5)


# ============================================================
# FORK OBSTACLE
# ============================================================

class ForkObstacle extends Area2D:
	var wobble_timer: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 1

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(18, 50)
		shape.shape = rect
		shape.position = Vector2(0, -25)
		add_child(shape)

		var visual := ForkVisual.new()
		add_child(visual)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		wobble_timer += delta
		rotation = sin(wobble_timer * 3.5) * 0.04  # Slight wobble

	func _on_body_entered(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()


class ForkVisual extends Node2D:
	func _draw() -> void:
		var metal := Color(0.7, 0.72, 0.75)
		var metal_light := Color(0.85, 0.87, 0.9)
		var metal_dark := Color(0.55, 0.55, 0.58)

		# Handle
		draw_rect(Rect2(-3, -4, 6, 18), metal)
		draw_line(Vector2(0, -2), Vector2(0, 12), metal_light, 1.0)

		# Neck (tapers)
		var neck_pts := PackedVector2Array([
			Vector2(-3, -4), Vector2(3, -4),
			Vector2(5, -12), Vector2(-5, -12),
		])
		draw_colored_polygon(neck_pts, metal)

		# Three prongs
		var prong_positions: Array[float] = [-6.0, 0.0, 6.0]
		for px in prong_positions:
			# Prong body
			draw_rect(Rect2(px - 1.5, -50, 3, 38), metal)
			# Prong tip
			var tip_pts := PackedVector2Array([
				Vector2(px - 1.5, -50),
				Vector2(px + 1.5, -50),
				Vector2(px, -55),
			])
			draw_colored_polygon(tip_pts, metal_light)
			# Highlight down center of prong
			draw_line(Vector2(px, -50), Vector2(px, -14), metal_light, 0.8)

		# Cross bar connecting prongs at base
		draw_rect(Rect2(-7.5, -13, 15, 2), metal_dark)

		# Handle end cap
		draw_rect(Rect2(-4, 12, 8, 3), metal_dark)


# ============================================================
# SPIKE OBSTACLE (toothpicks)
# ============================================================

class SpikeObstacle extends Area2D:
	var spike_count: int = 0
	var spike_heights: Array[float] = []

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 1

		spike_count = randi_range(3, 6)
		for i in range(spike_count):
			spike_heights.append(randf_range(25, 50))

		var total_width: float = spike_count * 10.0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(total_width, 40)
		shape.shape = rect
		shape.position = Vector2(total_width * 0.5 - 5, -20)
		add_child(shape)

		var visual := SpikeVisual.new()
		visual.spike_count = spike_count
		visual.spike_heights = spike_heights
		add_child(visual)

		body_entered.connect(_on_body_entered)

	func _on_body_entered(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()


class SpikeVisual extends Node2D:
	var spike_count: int = 4
	var spike_heights: Array[float] = []

	func _draw() -> void:
		var wood_color := Color(0.82, 0.7, 0.45)
		var wood_tip := Color(0.75, 0.6, 0.35)
		var wood_dark := Color(0.6, 0.48, 0.28)

		for i in range(spike_count):
			if i >= spike_heights.size():
				break
			var sx: float = i * 10.0
			var sh: float = spike_heights[i]

			# Toothpick body (tapers to point)
			var pts := PackedVector2Array([
				Vector2(sx - 2, 0),
				Vector2(sx + 2, 0),
				Vector2(sx + 1, -sh + 5),
				Vector2(sx, -sh),
				Vector2(sx - 1, -sh + 5),
			])
			draw_colored_polygon(pts, wood_color)

			# Center grain line
			draw_line(Vector2(sx, 0), Vector2(sx, -sh + 2), wood_dark, 0.6)

			# Tip highlight
			draw_line(Vector2(sx, -sh), Vector2(sx + 1, -sh + 6), wood_tip.lightened(0.2), 0.8)

		# Base - small wooden holder block
		var total_w: float = spike_count * 10.0
		draw_rect(Rect2(-3, 0, total_w + 6, 5), wood_dark)
		draw_rect(Rect2(-2, 0, total_w + 4, 2), wood_color.lightened(0.1))


# ############################################################
# ENEMY INNER CLASSES
# ############################################################

# ============================================================
# ANGRY TOMATO
# ============================================================

class AngryTomato extends CharacterBody2D:
	var walk_speed: float = 70.0
	var patrol_range: float = 200.0
	var start_x: float = 0.0
	var direction: float = 1.0
	var gravity: float = 600.0
	var is_dead: bool = false
	var squash_timer: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 2  # collide with platforms

		walk_speed = randf_range(60, 80)
		start_x = global_position.x
		direction = [-1.0, 1.0].pick_random()

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 14
		shape.shape = circle
		add_child(shape)

		var visual := AngryTomatoVisual.new()
		visual.name = "Visual"
		add_child(visual)

		# Hitbox for player stomp detection / side hit
		var hitbox := Area2D.new()
		hitbox.collision_layer = 8
		hitbox.collision_mask = 1
		var hshape := CollisionShape2D.new()
		var hcircle := CircleShape2D.new()
		hcircle.radius = 16
		hshape.shape = hcircle
		hitbox.add_child(hshape)
		hitbox.body_entered.connect(_on_player_contact)
		add_child(hitbox)

	func _physics_process(delta: float) -> void:
		if is_dead:
			squash_timer += delta
			if squash_timer > 0.35:
				queue_free()
			return

		# Gravity
		velocity.y += gravity * delta

		# Patrol movement
		velocity.x = direction * walk_speed

		# Reverse at patrol edges
		if abs(global_position.x - start_x) > patrol_range:
			direction *= -1.0

		move_and_slide()

		# Reverse on wall
		if is_on_wall():
			direction *= -1.0

	func _on_player_contact(body: Node2D) -> void:
		if is_dead:
			return
		if not body is CharacterBody2D:
			return
		if not body.has_method("take_hit"):
			return

		# Check if player is stomping (falling down and above us)
		if body.velocity.y > 0 and body.global_position.y < global_position.y - 10:
			# Stomped!
			is_dead = true
			GameManager.on_enemy_killed("tomato")
			# Bounce player up
			body.velocity.y = -300.0
			# Visual squash
			var visual_node: Node = get_node_or_null("Visual")
			if visual_node and visual_node is AngryTomatoVisual:
				visual_node.squashed = true
		else:
			# Side collision - hurt player
			body.take_hit()


class AngryTomatoVisual extends Node2D:
	var squashed: bool = false
	var anim_timer: float = 0.0

	func _process(delta: float) -> void:
		anim_timer += delta
		queue_redraw()

	func _draw() -> void:
		if squashed:
			_draw_squashed()
			return

		var bounce: float = abs(sin(anim_timer * 6.0)) * 2.0

		# Shadow
		_draw_filled_ellipse(Rect2(-12, 12, 24, 6), Color(0, 0, 0, 0.15))

		# Main body - red tomato
		var body_color := Color(0.85, 0.15, 0.1)
		draw_circle(Vector2(0, -bounce), 14, body_color)

		# Darker red ridges
		draw_arc(Vector2(0, -bounce), 12, 0.3, 1.2, 8, Color(0.7, 0.1, 0.05), 1.5)
		draw_arc(Vector2(0, -bounce), 12, 2.0, 2.9, 8, Color(0.7, 0.1, 0.05), 1.5)
		draw_arc(Vector2(0, -bounce), 12, 3.8, 4.7, 8, Color(0.7, 0.1, 0.05), 1.5)

		# Highlight
		draw_circle(Vector2(-4, -6 - bounce), 4, Color(1.0, 0.4, 0.35, 0.45))

		# Green stem on top
		draw_rect(Rect2(-1.5, -17 - bounce, 3, 5), Color(0.2, 0.55, 0.15))
		# Leaf shapes
		var leaf_pts := PackedVector2Array([
			Vector2(0, -17 - bounce),
			Vector2(7, -20 - bounce),
			Vector2(4, -16 - bounce),
		])
		draw_colored_polygon(leaf_pts, Color(0.25, 0.6, 0.18))
		var leaf2 := PackedVector2Array([
			Vector2(0, -17 - bounce),
			Vector2(-6, -19 - bounce),
			Vector2(-3, -15 - bounce),
		])
		draw_colored_polygon(leaf2, Color(0.22, 0.55, 0.16))

		# Angry eyebrows (thick, angled down toward center)
		var eye_y: float = -4 - bounce
		# Left eyebrow
		draw_line(Vector2(-9, eye_y - 5), Vector2(-4, eye_y - 2), Color(0.2, 0.05, 0.0), 2.5)
		# Right eyebrow
		draw_line(Vector2(9, eye_y - 5), Vector2(4, eye_y - 2), Color(0.2, 0.05, 0.0), 2.5)

		# Eyes - white with dark pupils
		draw_circle(Vector2(-5, eye_y), 3.5, Color.WHITE)
		draw_circle(Vector2(5, eye_y), 3.5, Color.WHITE)
		draw_circle(Vector2(-5, eye_y + 0.5), 1.8, Color(0.1, 0.05, 0.0))
		draw_circle(Vector2(5, eye_y + 0.5), 1.8, Color(0.1, 0.05, 0.0))

		# Angry frown mouth
		draw_arc(Vector2(0, 4 - bounce), 5, 0.3, PI - 0.3, 10, Color(0.2, 0.05, 0.0), 2.0)

	func _draw_squashed() -> void:
		# Flattened tomato - splat!
		_draw_filled_ellipse(Rect2(-18, -5, 36, 10), Color(0.85, 0.15, 0.1))
		# Tomato juice splatter
		draw_circle(Vector2(-12, 2), 3, Color(0.9, 0.2, 0.1, 0.7))
		draw_circle(Vector2(10, 3), 2.5, Color(0.9, 0.2, 0.1, 0.7))
		draw_circle(Vector2(5, -3), 2, Color(0.9, 0.2, 0.1, 0.5))
		# Seeds
		draw_circle(Vector2(-6, 0), 1.5, Color(0.95, 0.85, 0.5))
		draw_circle(Vector2(4, 1), 1.2, Color(0.95, 0.85, 0.5))

	func _draw_filled_ellipse(rect: Rect2, color: Color) -> void:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		var rx: float = rect.size.x * 0.5
		var ry: float = rect.size.y * 0.5
		var pts := PackedVector2Array()
		var segments: int = 20
		for i in range(segments):
			var angle: float = float(i) / float(segments) * TAU
			pts.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
		draw_colored_polygon(pts, color)


# ============================================================
# CRYING ONION
# ============================================================

class CryingOnion extends CharacterBody2D:
	var walk_speed: float = 50.0
	var patrol_range: float = 200.0
	var start_x: float = 0.0
	var direction: float = 1.0
	var gravity: float = 600.0
	var is_dead: bool = false
	var squash_timer: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 2

		walk_speed = randf_range(40, 60)
		start_x = global_position.x
		direction = [-1.0, 1.0].pick_random()

		# Body collision
		var shape := CollisionShape2D.new()
		var capsule := CapsuleShape2D.new()
		capsule.radius = 12
		capsule.height = 30
		shape.shape = capsule
		add_child(shape)

		var visual := CryingOnionVisual.new()
		visual.name = "Visual"
		add_child(visual)

		# Hitbox
		var hitbox := Area2D.new()
		hitbox.collision_layer = 8
		hitbox.collision_mask = 1
		var hshape := CollisionShape2D.new()
		var hcircle := CircleShape2D.new()
		hcircle.radius = 16
		hshape.shape = hcircle
		hitbox.add_child(hshape)
		hitbox.body_entered.connect(_on_player_contact)
		add_child(hitbox)

		# Tear zone - slows player
		var tear_zone := Area2D.new()
		tear_zone.collision_layer = 0
		tear_zone.collision_mask = 1
		var tz_shape := CollisionShape2D.new()
		var tz_circle := CircleShape2D.new()
		tz_circle.radius = 60
		tz_shape.shape = tz_circle
		tear_zone.add_child(tz_shape)
		tear_zone.body_entered.connect(_on_tear_zone_entered)
		tear_zone.body_exited.connect(_on_tear_zone_exited)
		tear_zone.name = "TearZone"
		add_child(tear_zone)

	func _physics_process(delta: float) -> void:
		if is_dead:
			squash_timer += delta
			if squash_timer > 0.35:
				queue_free()
			return

		velocity.y += gravity * delta
		velocity.x = direction * walk_speed

		if abs(global_position.x - start_x) > patrol_range:
			direction *= -1.0

		move_and_slide()

		if is_on_wall():
			direction *= -1.0

	func _on_player_contact(body: Node2D) -> void:
		if is_dead:
			return
		if not body is CharacterBody2D:
			return
		if not body.has_method("take_hit"):
			return

		if body.velocity.y > 0 and body.global_position.y < global_position.y - 10:
			is_dead = true
			GameManager.on_enemy_killed("onion")
			body.velocity.y = -300.0
			var visual_node: Node = get_node_or_null("Visual")
			if visual_node and visual_node is CryingOnionVisual:
				visual_node.squashed = true
		else:
			body.take_hit()

	func _on_tear_zone_entered(body: Node2D) -> void:
		if body.has_method("apply_slow"):
			body.apply_slow(0.5)

	func _on_tear_zone_exited(body: Node2D) -> void:
		if body.has_method("remove_slow"):
			body.remove_slow()


class CryingOnionVisual extends Node2D:
	var squashed: bool = false
	var anim_timer: float = 0.0
	var tear_offsets: Array[float] = []

	func _ready() -> void:
		# Initialize tear drop positions
		for i in range(4):
			tear_offsets.append(randf() * 20.0)

	func _process(delta: float) -> void:
		anim_timer += delta
		# Animate tears falling
		for i in range(tear_offsets.size()):
			tear_offsets[i] += delta * 30.0
			if tear_offsets[i] > 25.0:
				tear_offsets[i] = 0.0
		queue_redraw()

	func _draw() -> void:
		if squashed:
			_draw_squashed()
			return

		var wobble: float = sin(anim_timer * 4.0) * 1.5

		# Tear zone indicator (subtle)
		draw_circle(Vector2(0, 0), 55, Color(0.5, 0.6, 0.9, 0.04))

		# Shadow
		__draw_filled_ellipse(Rect2(-10, 13, 20, 5), Color(0, 0, 0, 0.12))

		# Outer layer - purple
		var outer_color := Color(0.6, 0.35, 0.6)
		__draw_filled_ellipse(Rect2(-13 + wobble * 0.3, -14, 26, 30), outer_color)

		# Middle layer - lighter purple
		var mid_color := Color(0.72, 0.5, 0.7)
		__draw_filled_ellipse(Rect2(-11, -12 + wobble * 0.2, 22, 26), mid_color)

		# Inner layer - white/cream
		var inner_color := Color(0.92, 0.88, 0.82)
		__draw_filled_ellipse(Rect2(-9, -10, 18, 22), inner_color)

		# Layer lines (rings of onion)
		draw_arc(Vector2(0, 1), 11, 0.5, 2.6, 10, outer_color.darkened(0.15), 1.0)
		draw_arc(Vector2(0, 1), 8, 0.4, 2.7, 10, mid_color.darkened(0.1), 0.8)

		# Top sprout
		draw_line(Vector2(-1, -14), Vector2(-3, -22 + wobble), Color(0.3, 0.6, 0.2), 2.0)
		draw_line(Vector2(1, -14), Vector2(3, -21 + wobble), Color(0.35, 0.65, 0.22), 2.0)

		# Root wisps at bottom
		draw_line(Vector2(-2, 15), Vector2(-4, 19), Color(0.7, 0.6, 0.45), 1.0)
		draw_line(Vector2(2, 15), Vector2(4, 19), Color(0.7, 0.6, 0.45), 1.0)
		draw_line(Vector2(0, 16), Vector2(0, 20), Color(0.7, 0.6, 0.45), 1.0)

		# Big sad eyes
		var eye_y: float = -2.0
		# Eye whites (larger, droopy)
		__draw_filled_ellipse(Rect2(-8, eye_y - 4, 8, 9), Color.WHITE)
		__draw_filled_ellipse(Rect2(0, eye_y - 4, 8, 9), Color.WHITE)
		# Pupils (looking down sadly)
		draw_circle(Vector2(-4, eye_y + 1), 2.5, Color(0.15, 0.1, 0.2))
		draw_circle(Vector2(4, eye_y + 1), 2.5, Color(0.15, 0.1, 0.2))
		# Pupil highlights
		draw_circle(Vector2(-3, eye_y), 1.0, Color(1.0, 1.0, 1.0, 0.8))
		draw_circle(Vector2(5, eye_y), 1.0, Color(1.0, 1.0, 1.0, 0.8))

		# Sad eyebrows (curved up in middle = worried look)
		draw_line(Vector2(-8, eye_y - 6), Vector2(-3, eye_y - 8), Color(0.35, 0.2, 0.35), 1.5)
		draw_line(Vector2(8, eye_y - 6), Vector2(3, eye_y - 8), Color(0.35, 0.2, 0.35), 1.5)

		# Wobbly frown
		var mouth_y: float = 6.0
		draw_arc(Vector2(0, mouth_y + 3), 4, PI + 0.4, TAU - 0.4, 8, Color(0.35, 0.2, 0.35), 1.5)

		# Tears streaming down
		var tear_color := Color(0.55, 0.7, 0.95, 0.7)
		for i in range(tear_offsets.size()):
			if i >= tear_offsets.size():
				break
			var tx: float = -6.0 if i < 2 else 6.0
			var base_ty: float = eye_y + 4
			var ty: float = base_ty + tear_offsets[i]
			var tear_alpha: float = 1.0 - tear_offsets[i] / 25.0
			if tear_alpha > 0:
				draw_circle(Vector2(tx + (i % 2) * 2, ty), 1.8, Color(tear_color.r, tear_color.g, tear_color.b, tear_alpha * 0.7))

	func _draw_squashed() -> void:
		# Flattened onion
		__draw_filled_ellipse(Rect2(-18, -4, 36, 8), Color(0.72, 0.5, 0.7))
		__draw_filled_ellipse(Rect2(-14, -3, 28, 6), Color(0.92, 0.88, 0.82))
		# Onion juice/tears splash
		draw_circle(Vector2(-10, 3), 2.5, Color(0.55, 0.7, 0.95, 0.5))
		draw_circle(Vector2(8, 2), 2, Color(0.55, 0.7, 0.95, 0.5))
		draw_circle(Vector2(0, 4), 1.8, Color(0.55, 0.7, 0.95, 0.4))

	func _draw_ellipse(rect: Rect2, color: Color) -> void:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		var rx: float = rect.size.x * 0.5
		var ry: float = rect.size.y * 0.5
		var pts := PackedVector2Array()
		var segments: int = 20
		for i in range(segments):
			var angle: float = float(i) / float(segments) * TAU
			pts.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
		draw_colored_polygon(pts, color)
