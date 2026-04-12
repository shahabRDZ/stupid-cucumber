extends Node2D

## Procedural level generator - "Stupid Cucumber" Phase 3
## Biome-aware chunks, obstacles, enemies, bosses, collectibles

const CHUNK_WIDTH: float = 800.0
const CLEANUP_DISTANCE: float = 1500.0
const GENERATE_AHEAD: float = 2000.0
const GROUND_Y: float = 500.0
const MIN_PLATFORM_Y: float = 150.0

var player: CharacterBody2D = null
var last_generated_x: float = 0.0
var chunk_count: int = 0

# Platform themes per biome -----------------------------------------------

var garden_themes: Array[Dictionary] = [
	{"name": "grass_dirt", "color": Color(0.35, 0.55, 0.2), "stripe": Color(0.45, 0.32, 0.18), "accent": Color(0.5, 0.72, 0.3)},
	{"name": "mossy_stone", "color": Color(0.45, 0.48, 0.42), "stripe": Color(0.3, 0.42, 0.28), "accent": Color(0.55, 0.65, 0.45)},
	{"name": "flower_bed", "color": Color(0.42, 0.3, 0.2), "stripe": Color(0.35, 0.25, 0.15), "accent": Color(0.9, 0.45, 0.55)},
]

var kitchen_themes: Array[Dictionary] = [
	{"name": "cutting_board", "color": Color(0.55, 0.35, 0.18), "stripe": Color(0.45, 0.28, 0.12), "accent": Color(0.65, 0.45, 0.25)},
	{"name": "ceramic_plate", "color": Color(0.92, 0.92, 0.95), "stripe": Color(0.82, 0.82, 0.88), "accent": Color(0.7, 0.75, 0.85)},
	{"name": "copper_pot", "color": Color(0.72, 0.45, 0.2), "stripe": Color(0.6, 0.35, 0.15), "accent": Color(0.85, 0.6, 0.35)},
]

var fridge_themes: Array[Dictionary] = [
	{"name": "ice_block", "color": Color(0.6, 0.82, 0.95, 0.8), "stripe": Color(0.5, 0.72, 0.88, 0.6), "accent": Color(0.85, 0.93, 1.0, 0.9)},
	{"name": "frozen_peas", "color": Color(0.35, 0.7, 0.3), "stripe": Color(0.25, 0.55, 0.22), "accent": Color(0.6, 0.85, 0.55)},
	{"name": "cheese_wedge", "color": Color(1.0, 0.85, 0.3), "stripe": Color(0.9, 0.75, 0.2), "accent": Color(1.0, 0.92, 0.5)},
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

	_update_weather(_delta)

	for child in get_children():
		if child.global_position.x < player.global_position.x - CLEANUP_DISTANCE:
			child.queue_free()


# ============================================================
# WEATHER PARTICLES
# ============================================================

var weather_spawn_timer: float = 0.0

func _update_weather(delta: float) -> void:
	if player == null:
		return
	weather_spawn_timer -= delta
	if weather_spawn_timer > 0.0:
		return
	weather_spawn_timer = randf_range(0.05, 0.2)
	var cam_x: float = player.global_position.x
	var spawn_x: float = cam_x + randf_range(-500, 500)
	match GameManager.current_biome:
		GameManager.Biome.GARDEN:
			if randf() < 0.3:
				var leaf := WeatherLeafParticle.new()
				leaf.global_position = Vector2(spawn_x, player.global_position.y - 300)
				add_child(leaf)
		GameManager.Biome.KITCHEN:
			if randf() < 0.4:
				var steam := WeatherSteamParticle.new()
				steam.global_position = Vector2(spawn_x, player.global_position.y + 200)
				add_child(steam)
		GameManager.Biome.FRIDGE:
			var snow := WeatherSnowParticle.new()
			snow.global_position = Vector2(spawn_x, player.global_position.y - 300)
			add_child(snow)


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

	# Track biome chunks for boss spawning
	GameManager.chunks_since_biome_change += 1

	# Boss arena check
	if not GameManager.is_boss_active and GameManager.chunks_since_biome_change >= GameManager.BOSS_SPAWN_CHUNKS:
		_generate_boss_arena(start_x)
		return

	# Skip normal enemies/obstacles if boss is active
	if GameManager.is_boss_active:
		_create_ground_platform(start_x, CHUNK_WIDTH, GROUND_Y)
		return

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
# BOSS ARENA
# ============================================================

func _generate_boss_arena(start_x: float) -> void:
	# Flat arena platform
	_create_ground_platform(start_x, 1200, GROUND_Y)
	# Walls at edges to contain fight
	_create_platform(start_x - 20, 30, GROUND_Y - 200)
	_create_platform(start_x + 1200 - 10, 30, GROUND_Y - 200)

	GameManager.spawn_boss()

	var boss_x: float = start_x + 600.0
	var boss_y: float = GROUND_Y

	match GameManager.current_biome:
		GameManager.Biome.GARDEN:
			_create_pumpkin_boss(Vector2(boss_x, boss_y))
		GameManager.Biome.KITCHEN:
			_create_cleaver_boss(Vector2(boss_x, boss_y))
		GameManager.Biome.FRIDGE:
			_create_icecream_boss(Vector2(boss_x, boss_y))
		_:
			_create_pumpkin_boss(Vector2(boss_x, boss_y))


func _create_pumpkin_boss(pos: Vector2) -> void:
	var boss := PumpkinBoss.new()
	boss.position = pos
	add_child(boss)


func _create_cleaver_boss(pos: Vector2) -> void:
	var boss := CleaverBoss.new()
	boss.position = pos
	add_child(boss)


func _create_icecream_boss(pos: Vector2) -> void:
	var boss := IceCreamBoss.new()
	boss.position = pos
	add_child(boss)


# ============================================================
# OBSTACLES
# ============================================================

func _scatter_obstacles(start_x: float, difficulty: float) -> void:
	var enemy_mult: float = GameManager.difficulty_settings[GameManager.current_difficulty]["enemy_mult"]
	var obstacle_chance: float = (0.15 + difficulty * 0.1) * enemy_mult
	var biome: int = GameManager.current_biome
	var knife_weight: float = 1.0
	var fork_weight: float = 1.0
	var spike_weight: float = 1.0
	var flying_knife_weight: float = 0.0

	if biome == GameManager.Biome.KITCHEN:
		knife_weight = 2.5
		fork_weight = 2.0
	elif biome == GameManager.Biome.FRIDGE:
		spike_weight = 2.5
	elif biome == GameManager.Biome.GARDEN:
		spike_weight = 1.5

	# Flying knife appears at higher difficulty
	if difficulty > 0.4:
		flying_knife_weight = 0.5 + difficulty * 0.8

	if randf() < obstacle_chance:
		var total_w: float = knife_weight + fork_weight + spike_weight + flying_knife_weight
		var roll: float = randf() * total_w
		var ox: float = start_x + randf_range(150, CHUNK_WIDTH - 100)
		if roll < knife_weight:
			_create_knife(Vector2(ox, GROUND_Y))
		elif roll < knife_weight + fork_weight:
			_create_fork(Vector2(ox, GROUND_Y))
		elif roll < knife_weight + fork_weight + spike_weight:
			_create_spikes(Vector2(ox, GROUND_Y))
		else:
			_create_flying_knife(Vector2(ox, GROUND_Y - randf_range(60, 180)))


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


func _create_flying_knife(pos: Vector2) -> void:
	var fk := FlyingKnife.new()
	fk.position = pos
	add_child(fk)


# ============================================================
# ENEMIES
# ============================================================

func _scatter_enemies(start_x: float, difficulty: float) -> void:
	var enemy_mult: float = GameManager.difficulty_settings[GameManager.current_difficulty]["enemy_mult"]
	var enemy_chance: float = (0.12 + difficulty * 0.08) * enemy_mult
	if randf() < enemy_chance:
		var ex: float = start_x + randf_range(200, CHUNK_WIDTH - 150)
		var ey: float = GROUND_Y
		var roll: float = randf()
		if difficulty > 0.5 and roll < 0.25:
			_create_mixer_robot(Vector2(ex, ey - 24))
		elif roll < 0.65:
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


func _create_mixer_robot(pos: Vector2) -> void:
	var mixer := MixerRobot.new()
	mixer.position = pos
	add_child(mixer)


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

	# Magnet
	if randf() < 0.06 + difficulty * 0.02:
		var mag_x: float = start_x + randf_range(100, 700)
		var mag_y: float = GROUND_Y - randf_range(60, 160)
		_create_magnet(Vector2(mag_x, mag_y))

	# Double Score
	if randf() < 0.05 + difficulty * 0.02:
		var ds_x: float = start_x + randf_range(100, 700)
		var ds_y: float = GROUND_Y - randf_range(60, 160)
		_create_double_score(Vector2(ds_x, ds_y))

	# Extra Life (very rare)
	if randf() < 0.03:
		var el_x: float = start_x + randf_range(100, 700)
		var el_y: float = GROUND_Y - randf_range(60, 160)
		_create_extra_life(Vector2(el_x, el_y))


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
	salt.add_to_group("salt_collectible")

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


func _create_magnet(pos: Vector2) -> void:
	var magnet := Area2D.new()
	magnet.position = pos
	magnet.collision_layer = 4
	magnet.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16
	shape.shape = circle
	magnet.add_child(shape)

	var visual := MagnetVisual.new()
	magnet.add_child(visual)

	magnet.body_entered.connect(_on_magnet_collected.bind(magnet))
	add_child(magnet)


func _create_double_score(pos: Vector2) -> void:
	var ds := Area2D.new()
	ds.position = pos
	ds.collision_layer = 4
	ds.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	ds.add_child(shape)

	var visual := DoubleScoreVisual.new()
	ds.add_child(visual)

	ds.body_entered.connect(_on_double_score_collected.bind(ds))
	add_child(ds)


func _create_extra_life(pos: Vector2) -> void:
	var el := Area2D.new()
	el.position = pos
	el.collision_layer = 4
	el.collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16
	shape.shape = circle
	el.add_child(shape)

	var visual := ExtraLifeVisual.new()
	el.add_child(visual)

	el.body_entered.connect(_on_extra_life_collected.bind(el))
	add_child(el)


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


func _on_magnet_collected(body: Node2D, magnet: Area2D) -> void:
	if body is CharacterBody2D and body.has_method("collect_magnet"):
		body.collect_magnet()
		_spawn_collect_effect(magnet.global_position, Color(0.6, 0.2, 0.8))
		magnet.queue_free()


func _on_double_score_collected(body: Node2D, ds: Area2D) -> void:
	if body is CharacterBody2D and body.has_method("collect_double_score"):
		body.collect_double_score()
		_spawn_collect_effect(ds.global_position, Color(1.0, 0.85, 0.2))
		ds.queue_free()


func _on_extra_life_collected(body: Node2D, el: Area2D) -> void:
	if body is CharacterBody2D and body.has_method("collect_extra_life"):
		body.collect_extra_life()
		_spawn_collect_effect(el.global_position, Color(0.3, 0.85, 0.2))
		el.queue_free()


func _spawn_collect_effect(pos: Vector2, color: Color) -> void:
	var effect := CollectEffect.new()
	effect.position = pos
	effect.effect_color = color
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
	var biome: int = 0

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

		if biome == 0:  # GARDEN
			# Grass blades on top - varied greens
			for i in range(int(platform_width / 12)):
				var gx: float = i * 12.0 + randf_range(0, 6)
				var gh: float = randf_range(5, 14)
				var g_color: Color = Color(0.2, 0.65, 0.15).lerp(Color(0.35, 0.8, 0.25), randf())
				draw_line(Vector2(gx, 0), Vector2(gx - 2, -gh), g_color, 1.5)
				if randf() < 0.3:
					draw_line(Vector2(gx, 0), Vector2(gx + 2, -gh * 0.7), g_color.darkened(0.15), 1.2)
			# Dirt texture dots and stripes
			for i in range(int(platform_width / 20)):
				var sx: float = i * 20.0 + randf_range(0, 10)
				draw_rect(Rect2(sx, 14, 12, 4), stripe)
				draw_circle(Vector2(sx + 6, 22), 2, stripe.darkened(0.15))
			# Small pebbles
			for i in range(int(platform_width / 60)):
				var px: float = i * 60.0 + randf_range(10, 50)
				draw_circle(Vector2(px, 28), randf_range(2, 4), color.darkened(0.25))
			# Flower bed accent - occasional small flowers
			if theme_name == "flower_bed":
				for i in range(int(platform_width / 40)):
					var fx: float = i * 40.0 + randf_range(5, 35)
					var fc: Color = [Color(1, 0.4, 0.5), Color(0.9, 0.8, 0.2), Color(0.7, 0.4, 0.9)][randi() % 3]
					draw_circle(Vector2(fx, -4), 3, fc)
					draw_circle(Vector2(fx, -4), 1.5, fc.lightened(0.3))
					draw_line(Vector2(fx, -1), Vector2(fx, 0), Color(0.2, 0.5, 0.15), 1.5)
		elif biome == 1:  # KITCHEN
			# Tile grout lines
			for i in range(int(platform_width / 50)):
				var lx: float = i * 50.0
				draw_line(Vector2(lx, 0), Vector2(lx, platform_height), stripe.darkened(0.2), 1.0)
			# Top edge - metallic trim
			draw_rect(Rect2(0, 0, platform_width, 3), accent.lightened(0.2))
			# Small tile reflection highlights
			for i in range(int(platform_width / 50)):
				var rx: float = i * 50.0 + 10
				draw_rect(Rect2(rx, 4, 8, 2), Color(1, 1, 1, 0.15))
			# Copper pot accent
			if theme_name == "copper_pot":
				draw_rect(Rect2(0, 0, platform_width, 2), Color(0.9, 0.55, 0.25, 0.5))
				for i in range(int(platform_width / 40)):
					draw_circle(Vector2(i * 40.0 + 20, platform_height * 0.5), 2, accent.darkened(0.2))
		elif biome == 2:  # FRIDGE
			# Frost crystals on surface
			for i in range(int(platform_width / 16)):
				var fx: float = i * 16.0 + randf_range(0, 8)
				var fr: float = randf_range(2, 5)
				draw_circle(Vector2(fx, 3), fr, Color(0.9, 0.95, 1.0, 0.5))
				# Crystal spikes
				if randf() < 0.4:
					draw_line(Vector2(fx, 0), Vector2(fx - 2, -randf_range(3, 7)), Color(0.85, 0.92, 1.0, 0.35), 1.0)
					draw_line(Vector2(fx, 0), Vector2(fx + 2, -randf_range(3, 7)), Color(0.85, 0.92, 1.0, 0.35), 1.0)
			# Icy sheen
			draw_rect(Rect2(0, 0, platform_width, 4), Color(0.8, 0.92, 1.0, 0.45))
			# Frozen condensation drips
			for i in range(int(platform_width / 35)):
				var dx: float = i * 35.0 + randf_range(5, 30)
				draw_line(Vector2(dx, platform_height), Vector2(dx, platform_height + randf_range(3, 8)), Color(0.7, 0.85, 0.95, 0.3), 1.5)

	func _draw_floating(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		if biome == 0:
			_draw_garden_platform(color, stripe, accent, theme_name)
		elif biome == 1:
			_draw_kitchen_platform(color, stripe, accent, theme_name)
		else:
			_draw_fridge_platform(color, stripe, accent, theme_name)

	func _draw_garden_platform(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		# Rounded organic look
		draw_rect(Rect2(0, 0, platform_width, platform_height), color)
		draw_rect(Rect2(0, 0, platform_width, 4), color.lightened(0.3))
		draw_rect(Rect2(0, platform_height - 3, platform_width, 3), color.darkened(0.2))
		# Rounded ends
		draw_circle(Vector2(2, platform_height * 0.5), platform_height * 0.45, color.lightened(0.05))
		draw_circle(Vector2(platform_width - 2, platform_height * 0.5), platform_height * 0.45, color.lightened(0.05))

		if theme_name == "grass_dirt":
			# Grass tufts on top
			for i in range(int(platform_width / 14)):
				var gx: float = i * 14.0 + randf_range(0, 6)
				var gh: float = randf_range(4, 10)
				draw_line(Vector2(gx, 0), Vector2(gx - 1, -gh), Color(0.3, 0.7, 0.2, 0.8), 1.5)
			# Dirt specks
			for i in range(int(platform_width / 20)):
				var dx: float = i * 20.0 + randf_range(2, 16)
				draw_circle(Vector2(dx, platform_height * 0.6), 1.5, stripe.darkened(0.1))
		elif theme_name == "mossy_stone":
			# Stone crack lines
			for i in range(int(platform_width / 30)):
				var cx: float = i * 30.0 + randf_range(5, 25)
				draw_line(Vector2(cx, 2), Vector2(cx + randf_range(-5, 5), platform_height - 2), stripe.darkened(0.2), 0.8)
			# Moss patches
			for i in range(int(platform_width / 25)):
				var mx: float = i * 25.0 + randf_range(0, 15)
				draw_circle(Vector2(mx, 2), randf_range(3, 6), Color(0.3, 0.55, 0.2, 0.6))
		elif theme_name == "flower_bed":
			# Rich brown soil with flowers
			for i in range(int(platform_width / 25)):
				var fx: float = i * 25.0 + randf_range(3, 20)
				var fc: Color = [Color(1, 0.3, 0.5), Color(0.95, 0.9, 0.2), Color(0.7, 0.3, 0.85), Color(1, 0.6, 0.2)][randi() % 4]
				# Flower petals
				for p in range(5):
					var pa: float = float(p) / 5.0 * TAU
					draw_circle(Vector2(fx + cos(pa) * 3, -3 + sin(pa) * 3), 2, fc)
				draw_circle(Vector2(fx, -3), 1.5, Color(1, 0.9, 0.3))
				draw_line(Vector2(fx, 0), Vector2(fx, -1), Color(0.2, 0.5, 0.15), 1.5)

	func _draw_kitchen_platform(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		if theme_name == "cutting_board":
			# Wood grain board
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			for i in range(int(platform_width / 10)):
				var gx: float = i * 10.0 + randf_range(0, 4)
				draw_line(Vector2(gx, 1), Vector2(gx + randf_range(-2, 2), platform_height - 1), stripe, 0.8)
			# Knife marks (scratches)
			for i in range(int(platform_width / 35)):
				var sx: float = i * 35.0 + randf_range(5, 30)
				draw_line(Vector2(sx, randf_range(4, 10)), Vector2(sx + randf_range(-4, 4), randf_range(14, 20)), Color(0.35, 0.22, 0.1, 0.4), 0.6)
			# Top bevel
			draw_rect(Rect2(0, 0, platform_width, 2), accent)
			draw_rect(Rect2(0, platform_height - 2, platform_width, 2), color.darkened(0.3))
			# Edge grain detail
			draw_rect(Rect2(0, 0, 3, platform_height), color.lightened(0.1))
			draw_rect(Rect2(platform_width - 3, 0, 3, platform_height), color.darkened(0.15))
		elif theme_name == "ceramic_plate":
			# White ceramic
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Rim highlight
			draw_rect(Rect2(0, 0, platform_width, 3), Color(1.0, 1.0, 1.0, 0.8))
			# Blue decorative ring
			draw_rect(Rect2(4, platform_height * 0.4, platform_width - 8, 2), accent.lerp(Color.WHITE, 0.4))
			# Inner gold line
			draw_rect(Rect2(6, platform_height * 0.55, platform_width - 12, 1), Color(0.8, 0.7, 0.4, 0.4))
			# Bottom shadow
			draw_rect(Rect2(2, platform_height - 3, platform_width - 4, 3), stripe)
			# Subtle shine spots
			draw_circle(Vector2(platform_width * 0.3, platform_height * 0.3), 4, Color(1, 1, 1, 0.15))
		elif theme_name == "copper_pot":
			# Copper metallic body
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Metallic gradient sheen
			draw_rect(Rect2(0, 2, platform_width, 5), accent.lerp(Color.WHITE, 0.3))
			# Patina spots
			for i in range(int(platform_width / 25)):
				var px: float = i * 25.0 + randf_range(5, 20)
				draw_circle(Vector2(px, platform_height * 0.6), randf_range(2, 4), Color(0.3, 0.5, 0.4, 0.2))
			# Rivets
			draw_circle(Vector2(8, platform_height * 0.5), 2.5, color.darkened(0.3))
			draw_circle(Vector2(platform_width - 8, platform_height * 0.5), 2.5, color.darkened(0.3))
			# Handle nub
			draw_rect(Rect2(-6, 4, 8, platform_height - 8), color.darkened(0.15))
			# Rivet highlights
			draw_circle(Vector2(7, platform_height * 0.5 - 1), 1, accent.lightened(0.3))
			draw_circle(Vector2(platform_width - 9, platform_height * 0.5 - 1), 1, accent.lightened(0.3))

	func _draw_fridge_platform(color: Color, stripe: Color, accent: Color, theme_name: String) -> void:
		if theme_name == "ice_block":
			# Translucent blue ice
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Internal cracks / bubbles
			for i in range(int(platform_width / 25)):
				var cx: float = i * 25.0 + randf_range(5, 15)
				draw_line(
					Vector2(cx, randf_range(2, 6)),
					Vector2(cx + randf_range(-8, 8), platform_height - randf_range(2, 6)),
					Color(1.0, 1.0, 1.0, 0.25), 1.0
				)
				# Trapped air bubbles
				if randf() < 0.5:
					draw_circle(Vector2(cx + randf_range(-5, 5), randf_range(5, platform_height - 5)), randf_range(1, 3), Color(1, 1, 1, 0.2))
			# Surface glint
			draw_rect(Rect2(0, 0, platform_width, 3), accent)
			# Frost edge
			draw_rect(Rect2(0, platform_height - 2, platform_width, 2), stripe)
			# Refraction highlight
			draw_rect(Rect2(platform_width * 0.2, 3, platform_width * 0.15, 2), Color(1, 1, 1, 0.3))
		elif theme_name == "frozen_peas":
			# Bumpy green surface (pea pod)
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			for i in range(int(platform_width / 14)):
				var px: float = 7 + i * 14.0
				# Individual pea spheres
				draw_circle(Vector2(px, platform_height * 0.5), 6, stripe.lerp(color, 0.5))
				draw_circle(Vector2(px - 1, platform_height * 0.35), 2.5, accent.lerp(Color.WHITE, 0.4))
				# Pea shadow
				draw_arc(Vector2(px, platform_height * 0.5), 5.5, 0.5, 2.5, 8, color.darkened(0.2), 0.8)
			# Frost dusting
			draw_rect(Rect2(0, 0, platform_width, 2), Color(0.9, 0.95, 1.0, 0.35))
			# Pod edges
			draw_line(Vector2(0, 0), Vector2(platform_width, 0), Color(0.25, 0.5, 0.2), 1.5)
			draw_line(Vector2(0, platform_height), Vector2(platform_width, platform_height), Color(0.25, 0.5, 0.2), 1.5)
		elif theme_name == "cheese_wedge":
			# Yellow cheese with holes
			draw_rect(Rect2(0, 0, platform_width, platform_height), color)
			# Cheese holes - varying sizes
			for i in range(int(platform_width / 22)):
				var hx: float = 11 + i * 22.0
				var hy: float = platform_height * randf_range(0.3, 0.7)
				var hr: float = randf_range(3, 7)
				# Hole shadow
				draw_circle(Vector2(hx + 1, hy + 1), hr, stripe.darkened(0.15))
				# Hole
				draw_circle(Vector2(hx, hy), hr, stripe)
				# Hole highlight
				draw_circle(Vector2(hx - 1, hy - 1), hr * 0.4, accent.lerp(Color.WHITE, 0.3))
			# Shiny waxy top
			draw_rect(Rect2(0, 0, platform_width, 3), accent)
			# Cheese rind edge
			draw_rect(Rect2(0, platform_height - 2, platform_width, 2), Color(0.85, 0.7, 0.2))


# ============================================================
# RAMP VISUAL
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

		if biome == 1:
			fill_color = Color(0.55, 0.38, 0.2)
			edge_color = Color(0.4, 0.28, 0.12)
		elif biome == 2:
			fill_color = Color(0.6, 0.82, 0.95, 0.75)
			edge_color = Color(0.45, 0.65, 0.85)

		draw_colored_polygon(points, fill_color)
		draw_polyline(points, edge_color, 2.0)

		# Surface detail
		if biome == 0:
			# Grass on slope
			for i in range(6):
				var t: float = float(i) / 6.0
				var bx: float = 120.0 * t + 20
				var by: float = -60.0 * t
				draw_line(Vector2(bx, by), Vector2(bx - 2, by - randf_range(4, 8)), Color(0.3, 0.7, 0.2, 0.6), 1.2)
		elif biome == 1:
			# Wood grain on ramp
			for i in range(4):
				var gy: float = -i * 14.0
				draw_line(Vector2(50, gy - 2), Vector2(110, gy - 30), Color(0.4, 0.25, 0.12, 0.4), 0.8)
		elif biome == 2:
			# Ice glint
			draw_line(Vector2(40, -10), Vector2(100, -40), Color(1, 1, 1, 0.25), 1.5)


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

		# Outer glow
		draw_circle(center, 16, Color(0.9, 0.92, 1.0, 0.08 + sin(sparkle_timer * 2.5) * 0.04))

		# Main crystal body - diamond
		var points := PackedVector2Array([
			center + Vector2(0, -12),
			center + Vector2(10, 0),
			center + Vector2(0, 12),
			center + Vector2(-10, 0),
		])
		draw_colored_polygon(points, crystal_color)

		# Facet lines
		draw_line(center + Vector2(0, -12), center + Vector2(0, 12), Color(1, 1, 1, 0.2), 0.8)
		draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color(1, 1, 1, 0.15), 0.8)

		# Inner shine
		var inner := PackedVector2Array([
			center + Vector2(0, -7),
			center + Vector2(5, 0),
			center + Vector2(0, 7),
			center + Vector2(-5, 0),
		])
		draw_colored_polygon(inner, shine_color)

		# Sparkle rays
		var sparkle_phase: float = fmod(sparkle_timer * 2.0, 1.0)
		if sparkle_phase < 0.3:
			var s: float = sparkle_phase / 0.3
			draw_line(center + Vector2(-6, -6), center + Vector2(-6 - 5 * s, -6 - 5 * s), Color.WHITE, 1.5)
			draw_line(center + Vector2(5, -8), center + Vector2(5 + 4 * s, -8 - 4 * s), Color.WHITE, 1.5)
			draw_line(center + Vector2(6, 4), center + Vector2(6 + 3 * s, 4 + 3 * s), Color(1, 1, 1, 0.7), 1.2)
			draw_line(center + Vector2(-5, 6), center + Vector2(-5 - 3 * s, 6 + 3 * s), Color(1, 1, 1, 0.6), 1.0)


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

		# Outer heat glow
		var glow_alpha: float = 0.12 + sin(glow_timer * 3.0) * 0.08
		draw_circle(Vector2.ZERO, 22 * pulse, Color(1.0, 0.2, 0.0, glow_alpha * 0.5))
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

		# Darker red shading on right side
		var shade_pts := PackedVector2Array([
			Vector2(2, -12), Vector2(5, -10), Vector2(7, -4),
			Vector2(6, 4), Vector2(4, 10), Vector2(2, 14),
			Vector2(0, 14), Vector2(0, -12),
		])
		draw_colored_polygon(shade_pts, chili_red.darkened(0.15))

		# Highlight stripe
		var highlight := PackedVector2Array([
			Vector2(-2, -10), Vector2(0, -6), Vector2(1, 0),
			Vector2(-1, 0), Vector2(-3, -6),
		])
		draw_colored_polygon(highlight, chili_red.lightened(0.3))

		# Wrinkle lines
		draw_line(Vector2(-3, 2), Vector2(3, 3), chili_red.darkened(0.2), 0.7)
		draw_line(Vector2(-2, 7), Vector2(2, 8), chili_red.darkened(0.2), 0.7)

		# Stem
		draw_rect(Rect2(-2, -18, 4, 5), Color(0.2, 0.6, 0.15))
		draw_circle(Vector2(0, -18), 3, Color(0.25, 0.65, 0.2))
		# Stem highlight
		draw_circle(Vector2(-1, -18), 1.5, Color(0.35, 0.75, 0.3))

		# Heat shimmer particles
		var heat_phase: float = fmod(glow_timer * 1.5, 1.0)
		if heat_phase < 0.5:
			var ha: float = (0.5 - heat_phase) * 2.0
			draw_circle(Vector2(-3, -16 - heat_phase * 12), 1.5, Color(1, 0.5, 0.1, ha * 0.4))
			draw_circle(Vector2(4, -14 - heat_phase * 10), 1.2, Color(1, 0.4, 0.0, ha * 0.3))


# ============================================================
# YOGURT VISUAL
# ============================================================

class YogurtVisual extends Node2D:
	var bob_offset: float = 0.0
	var sparkle_timer: float = 0.0

	func _ready() -> void:
		bob_offset = randf() * TAU

	func _process(delta: float) -> void:
		bob_offset += delta * 2.5
		sparkle_timer += delta
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(bob_offset) * 3.0

		# Subtle glow
		draw_circle(Vector2(0, bob), 16, Color(0.85, 0.9, 1.0, 0.08 + sin(sparkle_timer * 2.0) * 0.04))

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

		# Cup shadow side
		var shadow_pts := PackedVector2Array([
			cup_top + Vector2(4, 0),
			cup_top + Vector2(9, 0),
			cup_bot + Vector2(7, 0),
			cup_bot + Vector2(3, 0),
		])
		draw_colored_polygon(shadow_pts, cup_color.darkened(0.08))

		# Blue label band with text line
		draw_rect(Rect2(-8, bob - 3, 16, 7), Color(0.45, 0.6, 0.9))
		draw_rect(Rect2(-5, bob - 1, 10, 1), Color(1, 1, 1, 0.4))
		draw_rect(Rect2(-4, bob + 1, 8, 1), Color(1, 1, 1, 0.25))

		# Lid / foil top with crinkle
		draw_rect(Rect2(-10, bob - 12, 20, 3), Color(0.75, 0.78, 0.85))
		draw_line(Vector2(-8, bob - 11), Vector2(-4, bob - 10.5), Color(0.85, 0.88, 0.92), 0.8)
		draw_line(Vector2(2, bob - 11), Vector2(7, bob - 10.5), Color(0.85, 0.88, 0.92), 0.8)

		# Yogurt cream swirl on top
		draw_circle(Vector2(0, bob - 11), 4.5, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(Vector2(2, bob - 12), 2.5, Color(0.95, 0.95, 1.0))
		draw_arc(Vector2(0, bob - 11), 3, 0, PI, 6, Color(0.9, 0.9, 0.95, 0.5), 0.8)

		# Spoon sticking out
		draw_line(Vector2(4, bob - 12), Vector2(12, bob - 20), Color(0.75, 0.75, 0.78), 2.0)
		var spoon_pts := PackedVector2Array([
			Vector2(11, bob - 20), Vector2(15, bob - 22),
			Vector2(14, bob - 18), Vector2(10, bob - 19),
		])
		draw_colored_polygon(spoon_pts, Color(0.78, 0.78, 0.82))
		# Spoon highlight
		draw_circle(Vector2(12.5, bob - 20), 1, Color(0.9, 0.9, 0.92, 0.5))

		# Sparkle
		var sp: float = fmod(sparkle_timer * 1.8, 1.0)
		if sp < 0.25:
			var sa: float = (0.25 - sp) * 4.0
			draw_line(Vector2(-8, bob - 8), Vector2(-11, bob - 11), Color(1, 1, 1, sa * 0.5), 1.0)


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

		# Golden glow
		draw_circle(center, 18, Color(0.95, 0.85, 0.3, 0.08 + sin(shimmer_timer * 2.0) * 0.04))

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

		# Glass highlight on left
		var hl_pts := PackedVector2Array([
			center + Vector2(-6, -7),
			center + Vector2(-3, -7),
			center + Vector2(-3, 7),
			center + Vector2(-6, 7),
		])
		draw_colored_polygon(hl_pts, Color(1, 0.95, 0.6, 0.2))

		# Bottle neck
		draw_rect(Rect2(-3, center.y - 14, 6, 7), Color(0.8, 0.68, 0.18, 0.9))

		# Cap / cork with detail
		draw_rect(Rect2(-4, center.y - 17, 8, 4), Color(0.5, 0.35, 0.15))
		draw_line(Vector2(-3, center.y - 15), Vector2(3, center.y - 15), Color(0.6, 0.45, 0.2), 0.8)

		# Label area
		draw_rect(Rect2(-5, center.y - 2, 10, 8), Color(0.95, 0.92, 0.82))
		# Label border
		draw_rect(Rect2(-5, center.y - 2, 10, 1), Color(0.7, 0.6, 0.3, 0.5))
		draw_rect(Rect2(-5, center.y + 5, 10, 1), Color(0.7, 0.6, 0.3, 0.5))

		# Olive branch on label
		draw_line(Vector2(-2, center.y + 1), Vector2(3, center.y - 1), Color(0.3, 0.55, 0.2), 1.0)
		draw_circle(Vector2(3, center.y - 1), 2, Color(0.35, 0.5, 0.15))
		draw_circle(Vector2(0, center.y + 1), 2, Color(0.35, 0.5, 0.15))
		# Olive highlights
		draw_circle(Vector2(2.5, center.y - 1.5), 0.8, Color(0.5, 0.65, 0.3))

		# Liquid shimmer
		var shimmer: float = sin(shimmer_timer * 3.0) * 0.15
		draw_rect(Rect2(-4, center.y + 2, 3, 5), Color(1.0, 0.9, 0.4, 0.25 + shimmer))

		# Sparkle
		var sp: float = fmod(shimmer_timer * 1.5, 1.2)
		if sp < 0.2:
			var sa: float = (0.2 - sp) * 5.0
			draw_circle(center + Vector2(4, -6), 2, Color(1, 1, 0.8, sa * 0.4))


# ============================================================
# COLLECT EFFECT
# ============================================================

class CollectEffect extends Node2D:
	var lifetime: float = 0.5
	var timer: float = 0.0
	var effect_color: Color = Color.WHITE
	var particles: Array[Dictionary] = []
	var ring_radius: float = 0.0

	func _ready() -> void:
		for i in range(12):
			var angle: float = float(i) / 12.0 * TAU
			particles.append({
				"pos": Vector2.ZERO,
				"vel": Vector2(cos(angle), sin(angle)) * randf_range(70, 140),
				"size": randf_range(2, 5),
			})

	func _process(delta: float) -> void:
		timer += delta
		ring_radius += delta * 120.0
		if timer >= lifetime:
			queue_free()
			return
		for p in particles:
			p["pos"] += p["vel"] * delta
			p["vel"] *= 0.94
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - timer / lifetime
		# Expanding ring
		if ring_radius < 60:
			draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 24, Color(effect_color.r, effect_color.g, effect_color.b, alpha * 0.5), 2.0)
		# Particles
		for p in particles:
			var ppos: Vector2 = p["pos"]
			var psize: float = p["size"]
			draw_circle(ppos, psize * alpha, Color(effect_color.r, effect_color.g, effect_color.b, alpha))
			# Particle trail
			var trail_pos: Vector2 = ppos - p["vel"].normalized() * psize * 2
			draw_circle(trail_pos, psize * alpha * 0.5, Color(effect_color.r, effect_color.g, effect_color.b, alpha * 0.3))


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
		draw_rect(Rect2(-5, -8, 10, 22), handle_color)
		# Wood grain texture lines
		draw_line(Vector2(-3, -6), Vector2(-3, 11), handle_dark, 1.0)
		draw_line(Vector2(0, -6), Vector2(0, 11), handle_dark, 0.8)
		draw_line(Vector2(3, -6), Vector2(3, 11), handle_dark, 1.0)
		# Extra grain detail
		draw_line(Vector2(-1.5, -4), Vector2(-1.5, 9), Color(0.5, 0.35, 0.18, 0.5), 0.6)
		draw_line(Vector2(1.5, -4), Vector2(1.5, 9), Color(0.5, 0.35, 0.18, 0.5), 0.6)

		# Handle rivets (2 metal rivets)
		draw_circle(Vector2(0, -2), 2.0, Color(0.65, 0.65, 0.6))
		draw_circle(Vector2(0, -2), 1.0, Color(0.75, 0.75, 0.72))
		draw_circle(Vector2(0, 8), 2.0, Color(0.65, 0.65, 0.6))
		draw_circle(Vector2(0, 8), 1.0, Color(0.75, 0.75, 0.72))

		# Leather wrap detail between rivets
		for i in range(3):
			var wy: float = 1.0 + i * 3.0
			draw_line(Vector2(-4, wy), Vector2(4, wy), Color(0.4, 0.25, 0.1, 0.4), 1.0)

		# Guard / bolster
		draw_rect(Rect2(-7, -10, 14, 3), Color(0.6, 0.6, 0.62))
		draw_rect(Rect2(-7, -10, 14, 1), Color(0.72, 0.72, 0.74))

		# Blade - silver, pointing up
		var blade_color := Color(0.78, 0.8, 0.82)
		var blade_pts := PackedVector2Array([
			Vector2(-4, -10),
			Vector2(4, -10),
			Vector2(3, -35),
			Vector2(0, -52),
			Vector2(-1, -35),
		])
		draw_colored_polygon(blade_pts, blade_color)

		# Blade edge highlight (sharp edge)
		draw_line(Vector2(0, -52), Vector2(4, -10), Color(0.92, 0.93, 0.95), 1.2)

		# Blade center reflection line
		draw_line(Vector2(0, -12), Vector2(1, -48), Color(0.88, 0.9, 0.93, 0.6), 1.2)

		# Serrated edge detail on one side
		for i in range(6):
			var sy: float = -15.0 - i * 5.5
			var sx: float = lerpf(-3.5, -1.5, float(i) / 6.0)
			draw_line(Vector2(sx, sy), Vector2(sx - 1.5, sy - 2.5), blade_color.lightened(0.1), 1.0)

		# Blade gradient darkening at base
		draw_rect(Rect2(-3.5, -14, 7.5, 3), blade_color.darkened(0.08))

		# Occasional glint animation (white flash)
		var glint_phase: float = fmod(gt * 0.8, 3.0)
		if glint_phase < 0.3:
			var ga: float = (0.3 - glint_phase) / 0.3
			draw_circle(Vector2(2, -32), 4, Color(1.0, 1.0, 1.0, ga * 0.7))
			draw_line(Vector2(-1, -35), Vector2(5, -29), Color(1.0, 1.0, 1.0, ga * 0.5), 1.5)
			# Secondary glint
			draw_circle(Vector2(1, -44), 2.5, Color(1.0, 1.0, 1.0, ga * 0.4))


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
		rotation = sin(wobble_timer * 3.5) * 0.04

	func _on_body_entered(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()


class ForkVisual extends Node2D:
	func _draw() -> void:
		var metal := Color(0.7, 0.72, 0.75)
		var metal_light := Color(0.85, 0.87, 0.9)
		var metal_dark := Color(0.55, 0.55, 0.58)

		# Handle with decorative pattern
		draw_rect(Rect2(-3, -4, 6, 20), metal)
		draw_line(Vector2(0, -2), Vector2(0, 14), metal_light, 1.0)
		# Handle pattern - dots
		for i in range(3):
			draw_circle(Vector2(0, 1 + i * 5), 1, metal_dark)
		# Handle end - oval cap
		draw_rect(Rect2(-4, 14, 8, 4), metal_dark)
		draw_rect(Rect2(-3, 14, 6, 1), metal_light)

		# Neck (tapers)
		var neck_pts := PackedVector2Array([
			Vector2(-3, -4), Vector2(3, -4),
			Vector2(5, -12), Vector2(-5, -12),
		])
		draw_colored_polygon(neck_pts, metal)
		# Neck highlight
		draw_line(Vector2(0, -5), Vector2(0, -11), metal_light, 0.8)

		# Three prongs with rounded tips
		var prong_positions: Array[float] = [-6.0, 0.0, 6.0]
		for px in prong_positions:
			# Prong body
			draw_rect(Rect2(px - 1.8, -50, 3.6, 38), metal)
			# Metallic gradient - lighter center
			draw_rect(Rect2(px - 0.5, -48, 1.0, 34), metal_light)
			# Rounded tip (circle at top)
			draw_circle(Vector2(px, -50), 2.2, metal_light)
			# Tip highlight
			draw_circle(Vector2(px - 0.5, -50.5), 1.0, Color(0.92, 0.93, 0.95, 0.6))
			# Prong shadow edges
			draw_line(Vector2(px - 1.8, -48), Vector2(px - 1.8, -13), metal_dark, 0.6)
			draw_line(Vector2(px + 1.8, -48), Vector2(px + 1.8, -13), metal_dark, 0.6)

		# Cross bar connecting prongs at base
		draw_rect(Rect2(-7.8, -13, 15.6, 2.5), metal_dark)
		draw_rect(Rect2(-7.8, -13, 15.6, 1), metal_light)


# ============================================================
# SPIKE OBSTACLE (toothpick row)
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
				Vector2(sx - 2.2, 0),
				Vector2(sx + 2.2, 0),
				Vector2(sx + 1.2, -sh + 5),
				Vector2(sx, -sh),
				Vector2(sx - 1.2, -sh + 5),
			])
			draw_colored_polygon(pts, wood_color)

			# Wood grain texture lines
			draw_line(Vector2(sx - 0.5, 0), Vector2(sx - 0.5, -sh + 3), wood_dark, 0.5)
			draw_line(Vector2(sx + 0.5, 0), Vector2(sx + 0.5, -sh + 3), Color(0.88, 0.78, 0.52, 0.5), 0.5)

			# Center grain line
			draw_line(Vector2(sx, 0), Vector2(sx, -sh + 2), wood_dark, 0.6)

			# Tip highlight - pointed top
			draw_line(Vector2(sx, -sh), Vector2(sx + 1, -sh + 6), wood_tip.lightened(0.25), 0.8)

			# Tiny shadow at base
			draw_circle(Vector2(sx, 2), 2, Color(0, 0, 0, 0.1))

		# Base - small wooden holder block with detail
		var total_w: float = spike_count * 10.0
		draw_rect(Rect2(-3, 0, total_w + 6, 6), wood_dark)
		draw_rect(Rect2(-2, 0, total_w + 4, 2), wood_color.lightened(0.1))
		# Holder edge detail
		draw_rect(Rect2(-3, 5, total_w + 6, 1), wood_dark.darkened(0.2))
		# Holder grain
		for i in range(int(total_w / 8)):
			draw_line(Vector2(-2 + i * 8.0, 2), Vector2(-2 + i * 8.0, 5), wood_color.darkened(0.1), 0.5)


# ============================================================
# FLYING KNIFE (NEW)
# ============================================================

class FlyingKnife extends Area2D:
	var fly_speed: float = 250.0
	var fly_direction: float = -1.0
	var spin_timer: float = 0.0
	var trail_positions: Array[Vector2] = []
	var lifetime: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 1

		fly_speed = randf_range(200, 320)
		fly_direction = [-1.0, 1.0].pick_random()

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, 10)
		shape.shape = rect
		add_child(shape)

		var visual := FlyingKnifeVisual.new()
		visual.name = "Visual"
		add_child(visual)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		spin_timer += delta * 8.0
		lifetime += delta
		position.x += fly_speed * fly_direction * delta

		# Store trail positions
		trail_positions.append(global_position)
		if trail_positions.size() > 6:
			trail_positions.remove_at(0)

		# Self-destruct after traveling far
		if lifetime > 8.0:
			queue_free()

	func _on_body_entered(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()


class FlyingKnifeVisual extends Node2D:
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var parent_node: Node = get_parent()
		var st: float = 0.0
		var trail: Array[Vector2] = []
		if parent_node and "spin_timer" in parent_node:
			st = parent_node.spin_timer
		if parent_node and "trail_positions" in parent_node:
			trail = parent_node.trail_positions

		# Afterimage trail
		for i in range(trail.size()):
			var t_alpha: float = float(i) / float(trail.size()) * 0.25
			var t_offset: Vector2 = trail[i] - parent_node.global_position
			var local_offset: Vector2 = t_offset
			draw_rect(Rect2(local_offset.x - 15, local_offset.y - 3, 30, 6), Color(0.78, 0.8, 0.82, t_alpha))

		# Spinning rotation visual
		var spin_scale: float = cos(st)

		# Blade body (horizontal flying knife)
		var blade_color := Color(0.78, 0.8, 0.82)
		var blade_pts := PackedVector2Array([
			Vector2(-20, -3 * spin_scale),
			Vector2(15, -2 * spin_scale),
			Vector2(20, 0),
			Vector2(15, 2 * spin_scale),
			Vector2(-20, 3 * spin_scale),
		])
		draw_colored_polygon(blade_pts, blade_color)

		# Edge highlight
		draw_line(Vector2(-18, -2.5 * spin_scale), Vector2(18, 0), Color(0.92, 0.93, 0.96), 1.0)

		# Handle stub
		draw_rect(Rect2(-25, -4 * abs(spin_scale), 7, 8 * abs(spin_scale)), Color(0.45, 0.28, 0.12))

		# Motion blur lines
		draw_line(Vector2(-30, 0), Vector2(-40, 0), Color(0.8, 0.8, 0.85, 0.3), 1.5)
		draw_line(Vector2(-28, -3), Vector2(-38, -3), Color(0.8, 0.8, 0.85, 0.2), 1.0)
		draw_line(Vector2(-28, 3), Vector2(-38, 3), Color(0.8, 0.8, 0.85, 0.2), 1.0)

		# Glint
		var glint_phase: float = fmod(st * 0.3, 2.0)
		if glint_phase < 0.2:
			var ga: float = (0.2 - glint_phase) * 5.0
			draw_circle(Vector2(10, -1), 3, Color(1, 1, 1, ga * 0.6))


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
		collision_mask = 2

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
			GameManager.on_enemy_killed("tomato")
			body.velocity.y = -300.0
			var visual_node: Node = get_node_or_null("Visual")
			if visual_node and visual_node is AngryTomatoVisual:
				visual_node.squashed = true
		else:
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
		_draw_filled_ellipse(Rect2(-14, 13, 28, 7), Color(0, 0, 0, 0.18))

		# Main body - red tomato with gradient
		var body_color := Color(0.85, 0.15, 0.1)
		var body_dark := Color(0.7, 0.1, 0.05)
		draw_circle(Vector2(0, -bounce), 15, body_color)
		# Bottom shadow for 3D effect
		draw_arc(Vector2(0, -bounce), 14, 0.8, 2.35, 10, body_dark, 3.0)

		# Tomato ridges (segment lines)
		draw_arc(Vector2(0, -bounce), 13, 0.3, 1.2, 8, body_dark, 1.5)
		draw_arc(Vector2(0, -bounce), 13, 2.0, 2.9, 8, body_dark, 1.5)
		draw_arc(Vector2(0, -bounce), 13, 3.8, 4.7, 8, body_dark, 1.5)
		draw_arc(Vector2(0, -bounce), 13, 5.2, 6.0, 8, body_dark, 1.2)

		# Highlight (specular)
		draw_circle(Vector2(-4, -7 - bounce), 5, Color(1.0, 0.4, 0.35, 0.45))
		draw_circle(Vector2(-3, -8 - bounce), 2.5, Color(1.0, 0.7, 0.65, 0.35))

		# Seed texture dots
		draw_circle(Vector2(-6, 2 - bounce), 1, Color(0.95, 0.8, 0.4, 0.3))
		draw_circle(Vector2(5, -2 - bounce), 1, Color(0.95, 0.8, 0.4, 0.3))
		draw_circle(Vector2(2, 6 - bounce), 0.8, Color(0.95, 0.8, 0.4, 0.25))

		# Green stem on top with 3 leaves
		draw_rect(Rect2(-1.5, -18 - bounce, 3, 6), Color(0.2, 0.55, 0.15))
		# Leaf 1 - right
		var leaf1 := PackedVector2Array([
			Vector2(0, -18 - bounce),
			Vector2(8, -21 - bounce),
			Vector2(6, -17 - bounce),
			Vector2(3, -16 - bounce),
		])
		draw_colored_polygon(leaf1, Color(0.25, 0.6, 0.18))
		# Leaf 2 - left
		var leaf2 := PackedVector2Array([
			Vector2(0, -18 - bounce),
			Vector2(-7, -20 - bounce),
			Vector2(-5, -16 - bounce),
			Vector2(-2, -16 - bounce),
		])
		draw_colored_polygon(leaf2, Color(0.22, 0.55, 0.16))
		# Leaf 3 - center-back
		var leaf3 := PackedVector2Array([
			Vector2(0, -19 - bounce),
			Vector2(2, -24 - bounce),
			Vector2(-2, -24 - bounce),
		])
		draw_colored_polygon(leaf3, Color(0.2, 0.5, 0.14))
		# Leaf veins
		draw_line(Vector2(1, -18 - bounce), Vector2(6, -19 - bounce), Color(0.18, 0.45, 0.12, 0.5), 0.6)
		draw_line(Vector2(-1, -18 - bounce), Vector2(-5, -18 - bounce), Color(0.18, 0.45, 0.12, 0.5), 0.6)

		# Face ---
		var eye_y: float = -4 - bounce

		# Thick angry V-eyebrows
		draw_line(Vector2(-10, eye_y - 6), Vector2(-4, eye_y - 2), Color(0.15, 0.02, 0.0), 2.8)
		draw_line(Vector2(10, eye_y - 6), Vector2(4, eye_y - 2), Color(0.15, 0.02, 0.0), 2.8)

		# Square angry eyes - white with dark pupils
		draw_rect(Rect2(-8, eye_y - 3, 7, 6), Color.WHITE)
		draw_rect(Rect2(1, eye_y - 3, 7, 6), Color.WHITE)
		# Pupils
		draw_rect(Rect2(-6, eye_y - 1, 4, 4), Color(0.1, 0.05, 0.0))
		draw_rect(Rect2(3, eye_y - 1, 4, 4), Color(0.1, 0.05, 0.0))
		# Pupil highlights
		draw_circle(Vector2(-5, eye_y - 0.5), 1.0, Color(1, 1, 1, 0.7))
		draw_circle(Vector2(4, eye_y - 0.5), 1.0, Color(1, 1, 1, 0.7))

		# Jagged angry frown with teeth
		var mouth_y: float = 5 - bounce
		var mouth_pts := PackedVector2Array([
			Vector2(-7, mouth_y), Vector2(-4, mouth_y + 3),
			Vector2(-1, mouth_y + 1), Vector2(2, mouth_y + 3),
			Vector2(5, mouth_y + 1), Vector2(7, mouth_y + 2),
			Vector2(7, mouth_y), Vector2(5, mouth_y - 1),
			Vector2(2, mouth_y + 1), Vector2(-1, mouth_y - 1),
			Vector2(-4, mouth_y + 1), Vector2(-7, mouth_y - 1),
		])
		draw_colored_polygon(mouth_pts, Color(0.15, 0.02, 0.0))
		# Teeth
		draw_rect(Rect2(-4, mouth_y - 1, 3, 2), Color(0.95, 0.92, 0.85))
		draw_rect(Rect2(1, mouth_y - 1, 3, 2), Color(0.95, 0.92, 0.85))

	func _draw_squashed() -> void:
		# Flattened tomato with juice splash
		_draw_filled_ellipse(Rect2(-20, -5, 40, 10), Color(0.85, 0.15, 0.1))
		_draw_filled_ellipse(Rect2(-16, -3, 32, 6), Color(0.75, 0.12, 0.08))
		# Juice splatters
		draw_circle(Vector2(-14, 3), 4, Color(0.9, 0.2, 0.1, 0.7))
		draw_circle(Vector2(12, 4), 3, Color(0.9, 0.2, 0.1, 0.7))
		draw_circle(Vector2(6, -4), 2.5, Color(0.9, 0.2, 0.1, 0.5))
		draw_circle(Vector2(-8, -3), 2, Color(0.9, 0.2, 0.1, 0.5))
		# Juice streams
		draw_line(Vector2(-10, 2), Vector2(-18, 5), Color(0.9, 0.2, 0.1, 0.4), 2.0)
		draw_line(Vector2(8, 2), Vector2(16, 6), Color(0.9, 0.2, 0.1, 0.4), 2.0)
		# Seeds
		draw_circle(Vector2(-6, 0), 1.8, Color(0.95, 0.85, 0.5))
		draw_circle(Vector2(4, 1), 1.5, Color(0.95, 0.85, 0.5))
		draw_circle(Vector2(0, -2), 1.2, Color(0.95, 0.85, 0.5))
		# Stem remains
		draw_rect(Rect2(-2, -4, 3, 2), Color(0.2, 0.5, 0.15, 0.6))

	func _draw_filled_ellipse(rect: Rect2, color: Color) -> void:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		var rx: float = rect.size.x * 0.5
		var ry: float = rect.size.y * 0.5
		var pts := PackedVector2Array()
		var segments: int = 24
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
		for i in range(6):
			tear_offsets.append(randf() * 25.0)

	func _process(delta: float) -> void:
		anim_timer += delta
		for i in range(tear_offsets.size()):
			tear_offsets[i] += delta * 35.0
			if tear_offsets[i] > 30.0:
				tear_offsets[i] = 0.0
		queue_redraw()

	func _draw() -> void:
		if squashed:
			_draw_squashed()
			return

		var wobble: float = sin(anim_timer * 4.0) * 2.0

		# Tear zone indicator (subtle)
		draw_circle(Vector2(0, 0), 58, Color(0.5, 0.6, 0.9, 0.03))

		# Shadow
		_draw_filled_ellipse(Rect2(-12, 14, 24, 6), Color(0, 0, 0, 0.15))

		# Outer layer - deep purple
		var outer_color := Color(0.55, 0.3, 0.55)
		_draw_filled_ellipse(Rect2(-14 + wobble * 0.3, -15, 28, 32), outer_color)

		# Second layer - purple
		var mid_color := Color(0.65, 0.42, 0.62)
		_draw_filled_ellipse(Rect2(-12 + wobble * 0.2, -13, 24, 28), mid_color)

		# Third layer - lighter
		var light_color := Color(0.78, 0.58, 0.75)
		_draw_filled_ellipse(Rect2(-10 + wobble * 0.1, -11, 20, 24), light_color)

		# Inner layer - white/cream
		var inner_color := Color(0.92, 0.88, 0.82)
		_draw_filled_ellipse(Rect2(-8, -9, 16, 20), inner_color)

		# Concentric layer ring lines
		draw_arc(Vector2(0, 1), 12, 0.4, 2.7, 12, outer_color.darkened(0.2), 1.2)
		draw_arc(Vector2(0, 1), 10, 0.4, 2.7, 12, mid_color.darkened(0.15), 1.0)
		draw_arc(Vector2(0, 1), 7, 0.5, 2.6, 10, light_color.darkened(0.1), 0.8)

		# Wobbly animation - slight squash/stretch
		var squash: float = 1.0 + sin(anim_timer * 5.0) * 0.03

		# Top green sprouts
		draw_line(Vector2(-2, -15), Vector2(-4, -24 + wobble), Color(0.3, 0.62, 0.2), 2.2)
		draw_line(Vector2(0, -15), Vector2(1, -26 + wobble * 0.8), Color(0.28, 0.58, 0.18), 2.0)
		draw_line(Vector2(2, -15), Vector2(5, -23 + wobble * 1.2), Color(0.32, 0.65, 0.22), 2.2)
		# Sprout tips (tiny leaves)
		draw_circle(Vector2(-4, -24 + wobble), 2, Color(0.35, 0.68, 0.25))
		draw_circle(Vector2(1, -26 + wobble * 0.8), 1.8, Color(0.32, 0.62, 0.22))
		draw_circle(Vector2(5, -23 + wobble * 1.2), 2, Color(0.38, 0.7, 0.28))

		# Root wisps at bottom
		draw_line(Vector2(-3, 16), Vector2(-5, 21), Color(0.7, 0.6, 0.45), 1.2)
		draw_line(Vector2(-1, 16), Vector2(-2, 22), Color(0.65, 0.55, 0.4), 1.0)
		draw_line(Vector2(1, 16), Vector2(2, 22), Color(0.65, 0.55, 0.4), 1.0)
		draw_line(Vector2(3, 16), Vector2(5, 21), Color(0.7, 0.6, 0.45), 1.2)

		# Face ---
		var eye_y: float = -2.0

		# Huge watery eyes with highlights
		_draw_filled_ellipse(Rect2(-9, eye_y - 5, 10, 11), Color.WHITE)
		_draw_filled_ellipse(Rect2(-1, eye_y - 5, 10, 11), Color.WHITE)
		# Water film effect
		_draw_filled_ellipse(Rect2(-8.5, eye_y - 4, 9, 10), Color(0.85, 0.9, 0.98))
		_draw_filled_ellipse(Rect2(-0.5, eye_y - 4, 9, 10), Color(0.85, 0.9, 0.98))

		# Pupils (looking down sadly)
		draw_circle(Vector2(-4, eye_y + 2), 3, Color(0.15, 0.1, 0.2))
		draw_circle(Vector2(4, eye_y + 2), 3, Color(0.15, 0.1, 0.2))
		# Large pupil highlights (watery look)
		draw_circle(Vector2(-3, eye_y), 1.5, Color(1.0, 1.0, 1.0, 0.85))
		draw_circle(Vector2(5, eye_y), 1.5, Color(1.0, 1.0, 1.0, 0.85))
		draw_circle(Vector2(-5, eye_y + 3), 0.8, Color(1.0, 1.0, 1.0, 0.5))
		draw_circle(Vector2(3, eye_y + 3), 0.8, Color(1.0, 1.0, 1.0, 0.5))

		# Sad eyebrows (curved up in middle = worried)
		draw_line(Vector2(-9, eye_y - 6), Vector2(-3, eye_y - 9), Color(0.35, 0.2, 0.35), 1.8)
		draw_line(Vector2(9, eye_y - 6), Vector2(3, eye_y - 9), Color(0.35, 0.2, 0.35), 1.8)

		# Quivering lip / wobbly frown
		var lip_wobble: float = sin(anim_timer * 7.0) * 0.5
		var mouth_y: float = 7.0
		draw_arc(Vector2(0, mouth_y + 3 + lip_wobble), 4.5, PI + 0.3, TAU - 0.3, 10, Color(0.35, 0.2, 0.35), 1.8)

		# Runny nose
		var nose_y: float = 4.0
		draw_circle(Vector2(0, nose_y), 1.5, Color(0.88, 0.65, 0.7))
		# Drip
		var drip_phase: float = fmod(anim_timer * 1.5, 2.0)
		if drip_phase < 1.5:
			var drip_len: float = drip_phase * 3.0
			draw_line(Vector2(0, nose_y + 1), Vector2(0, nose_y + 1 + drip_len), Color(0.65, 0.8, 0.9, 0.5), 1.5)

		# Streaming tears
		var tear_color := Color(0.55, 0.72, 0.95, 0.75)
		for i in range(tear_offsets.size()):
			if i >= tear_offsets.size():
				break
			var tx: float
			if i < 3:
				tx = -6.0 + float(i % 3) * 1.5
			else:
				tx = 6.0 - float(i % 3) * 1.5
			var base_ty: float = eye_y + 5
			var ty: float = base_ty + tear_offsets[i]
			var tear_alpha: float = 1.0 - tear_offsets[i] / 30.0
			if tear_alpha > 0:
				draw_circle(Vector2(tx, ty), 2.0, Color(tear_color.r, tear_color.g, tear_color.b, tear_alpha * 0.75))
				# Tear trail
				draw_line(Vector2(tx, ty - 2), Vector2(tx, ty), Color(tear_color.r, tear_color.g, tear_color.b, tear_alpha * 0.3), 1.5)

	func _draw_squashed() -> void:
		# Flattened onion rings
		_draw_filled_ellipse(Rect2(-20, -5, 40, 10), Color(0.55, 0.3, 0.55))
		_draw_filled_ellipse(Rect2(-16, -4, 32, 8), Color(0.72, 0.5, 0.7))
		_draw_filled_ellipse(Rect2(-12, -3, 24, 6), Color(0.92, 0.88, 0.82))
		# Onion juice/tears splash
		draw_circle(Vector2(-12, 3), 3, Color(0.55, 0.7, 0.95, 0.5))
		draw_circle(Vector2(10, 4), 2.5, Color(0.55, 0.7, 0.95, 0.5))
		draw_circle(Vector2(0, 5), 2, Color(0.55, 0.7, 0.95, 0.4))
		draw_circle(Vector2(-6, -3), 1.5, Color(0.55, 0.7, 0.95, 0.3))

	func _draw_filled_ellipse(rect: Rect2, color: Color) -> void:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		var rx: float = rect.size.x * 0.5
		var ry: float = rect.size.y * 0.5
		var pts := PackedVector2Array()
		var segments: int = 24
		for i in range(segments):
			var angle: float = float(i) / float(segments) * TAU
			pts.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
		draw_colored_polygon(pts, color)


# ============================================================
# MIXER ROBOT (NEW)
# ============================================================

class MixerRobot extends CharacterBody2D:
	var walk_speed: float = 90.0
	var patrol_range: float = 200.0
	var start_x: float = 0.0
	var direction: float = 1.0
	var gravity: float = 600.0
	var is_dead: bool = false
	var squash_timer: float = 0.0
	var hp: int = 2
	var shoot_timer: float = 0.0
	var shoot_interval: float = 3.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 2

		walk_speed = randf_range(80, 100)
		start_x = global_position.x
		direction = [-1.0, 1.0].pick_random()

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24, 30)
		shape.shape = rect
		add_child(shape)

		var visual := MixerRobotVisual.new()
		visual.name = "Visual"
		add_child(visual)

		# Hitbox
		var hitbox := Area2D.new()
		hitbox.collision_layer = 8
		hitbox.collision_mask = 1
		var hshape := CollisionShape2D.new()
		var hcircle := CircleShape2D.new()
		hcircle.radius = 18
		hshape.shape = hcircle
		hitbox.add_child(hshape)
		hitbox.body_entered.connect(_on_player_contact)
		add_child(hitbox)

	func _physics_process(delta: float) -> void:
		if is_dead:
			squash_timer += delta
			if squash_timer > 0.5:
				queue_free()
			return

		velocity.y += gravity * delta
		velocity.x = direction * walk_speed

		if abs(global_position.x - start_x) > patrol_range:
			direction *= -1.0

		move_and_slide()

		if is_on_wall():
			direction *= -1.0

		# Shooting
		shoot_timer += delta
		if shoot_timer >= shoot_interval:
			shoot_timer = 0.0
			_shoot_projectile()

	func _shoot_projectile() -> void:
		var proj := TomatoChunk.new()
		proj.position = global_position + Vector2(direction * 15, -10)
		proj.fly_direction = direction
		get_parent().add_child(proj)

	func _on_player_contact(body: Node2D) -> void:
		if is_dead:
			return
		if not body is CharacterBody2D:
			return
		if not body.has_method("take_hit"):
			return

		if body.velocity.y > 0 and body.global_position.y < global_position.y - 10:
			# Stomped
			hp -= 1
			body.velocity.y = -300.0
			if hp <= 0:
				is_dead = true
				GameManager.on_enemy_killed("mixer")
				var visual_node: Node = get_node_or_null("Visual")
				if visual_node and visual_node is MixerRobotVisual:
					visual_node.destroyed = true
			else:
				# Flash/damage feedback
				var visual_node: Node = get_node_or_null("Visual")
				if visual_node and visual_node is MixerRobotVisual:
					visual_node.hit_flash = 0.3
		else:
			body.take_hit()


class MixerRobotVisual extends Node2D:
	var destroyed: bool = false
	var anim_timer: float = 0.0
	var blade_angle: float = 0.0
	var hit_flash: float = 0.0

	func _process(delta: float) -> void:
		anim_timer += delta
		blade_angle += delta * 12.0
		if hit_flash > 0:
			hit_flash -= delta
		queue_redraw()

	func _draw() -> void:
		if destroyed:
			_draw_destroyed()
			return

		var flash_mod: Color = Color.WHITE if hit_flash > 0 and fmod(hit_flash * 20, 1.0) > 0.5 else Color(1, 1, 1, 0)
		var bob: float = sin(anim_timer * 4.0) * 1.0

		# Shadow
		_draw_filled_ellipse(Rect2(-14, 16, 28, 6), Color(0, 0, 0, 0.18))

		# Body - metallic silver/gray box
		var body_color := Color(0.65, 0.67, 0.7)
		if hit_flash > 0 and fmod(hit_flash * 20, 1.0) > 0.5:
			body_color = Color(1, 0.8, 0.8)
		var body_dark := Color(0.5, 0.52, 0.55)

		# Main body rectangle
		draw_rect(Rect2(-12, -12 + bob, 24, 26), body_color)
		# Metal sheen highlight
		draw_rect(Rect2(-10, -10 + bob, 8, 22), body_color.lightened(0.12))
		# Dark side shadow
		draw_rect(Rect2(6, -10 + bob, 6, 22), body_dark)
		# Bottom edge
		draw_rect(Rect2(-12, 12 + bob, 24, 3), body_dark.darkened(0.15))

		# Rivets on body
		var rivet_color := Color(0.5, 0.5, 0.53)
		draw_circle(Vector2(-9, -8 + bob), 1.5, rivet_color)
		draw_circle(Vector2(9, -8 + bob), 1.5, rivet_color)
		draw_circle(Vector2(-9, 8 + bob), 1.5, rivet_color)
		draw_circle(Vector2(9, 8 + bob), 1.5, rivet_color)
		# Rivet highlights
		for rv in [Vector2(-9, -8), Vector2(9, -8), Vector2(-9, 8), Vector2(9, 8)]:
			draw_circle(Vector2(rv.x - 0.5, rv.y - 0.5 + bob), 0.6, Color(0.75, 0.75, 0.78))

		# Control panel (small colored buttons)
		draw_rect(Rect2(-6, -2 + bob, 12, 8), Color(0.35, 0.35, 0.38))
		draw_rect(Rect2(-5, -1 + bob, 10, 6), Color(0.25, 0.25, 0.28))
		# Buttons
		draw_circle(Vector2(-3, 2 + bob), 1.5, Color(0.2, 0.8, 0.2))
		draw_circle(Vector2(0, 2 + bob), 1.5, Color(0.9, 0.8, 0.1))
		draw_circle(Vector2(3, 2 + bob), 1.5, Color(0.8, 0.2, 0.2))

		# LED eyes - red angry
		draw_circle(Vector2(-5, -7 + bob), 2.5, Color(0.9, 0.1, 0.1))
		draw_circle(Vector2(5, -7 + bob), 2.5, Color(0.9, 0.1, 0.1))
		# LED glow
		draw_circle(Vector2(-5, -7 + bob), 4, Color(1, 0.1, 0.05, 0.15))
		draw_circle(Vector2(5, -7 + bob), 4, Color(1, 0.1, 0.05, 0.15))
		# LED inner highlight
		draw_circle(Vector2(-4.5, -7.5 + bob), 1, Color(1, 0.4, 0.3))
		draw_circle(Vector2(5.5, -7.5 + bob), 1, Color(1, 0.4, 0.3))

		# Digital frown on small screen
		draw_rect(Rect2(-4, -3 + bob, 8, 1), Color(0.9, 0.3, 0.1))
		draw_line(Vector2(-3, -3 + bob), Vector2(-4, -4 + bob), Color(0.9, 0.3, 0.1), 1.0)
		draw_line(Vector2(3, -3 + bob), Vector2(4, -4 + bob), Color(0.9, 0.3, 0.1), 1.0)

		# Mixer blade spinning on top
		var blade_y: float = -16 + bob
		# Blade hub
		draw_circle(Vector2(0, blade_y), 3, Color(0.6, 0.6, 0.63))
		draw_circle(Vector2(0, blade_y), 1.5, body_dark)
		# Spinning blades (4 arms)
		for i in range(4):
			var ba: float = blade_angle + float(i) * PI * 0.5
			var bx: float = cos(ba) * 10
			var by: float = sin(ba) * 4  # Perspective squash
			draw_line(Vector2(0, blade_y), Vector2(bx, blade_y + by), Color(0.72, 0.72, 0.75), 2.5)
			draw_circle(Vector2(bx, blade_y + by), 1.5, Color(0.8, 0.8, 0.83))

		# Legs/treads at bottom
		draw_rect(Rect2(-10, 14 + bob, 7, 4), body_dark)
		draw_rect(Rect2(3, 14 + bob, 7, 4), body_dark)
		# Tread detail
		draw_line(Vector2(-9, 16 + bob), Vector2(-4, 16 + bob), Color(0.4, 0.4, 0.43), 1.0)
		draw_line(Vector2(4, 16 + bob), Vector2(9, 16 + bob), Color(0.4, 0.4, 0.43), 1.0)

	func _draw_destroyed() -> void:
		# Exploded robot parts
		draw_rect(Rect2(-10, -5, 8, 10), Color(0.5, 0.52, 0.55))
		draw_rect(Rect2(2, -3, 8, 8), Color(0.6, 0.62, 0.65))
		# Sparks
		draw_circle(Vector2(-4, -2), 2, Color(1, 0.8, 0.2, 0.7))
		draw_circle(Vector2(6, 1), 1.5, Color(1, 0.9, 0.3, 0.5))
		# Smoke
		draw_circle(Vector2(0, -8), 5, Color(0.3, 0.3, 0.3, 0.3))
		draw_circle(Vector2(3, -12), 4, Color(0.4, 0.4, 0.4, 0.2))
		# Scattered screws
		draw_circle(Vector2(-8, 5), 1, rivet_color())
		draw_circle(Vector2(10, 3), 1, rivet_color())

	func rivet_color() -> Color:
		return Color(0.5, 0.5, 0.53)

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
# TOMATO CHUNK PROJECTILE (for MixerRobot)
# ============================================================

class TomatoChunk extends Area2D:
	var fly_direction: float = 1.0
	var speed: float = 180.0
	var lifetime: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 1

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 5
		shape.shape = circle
		add_child(shape)

		var visual := TomatoChunkVisual.new()
		add_child(visual)

		body_entered.connect(_on_body_entered)

	func _process(delta: float) -> void:
		position.x += speed * fly_direction * delta
		position.y += 30.0 * delta  # slight gravity arc
		lifetime += delta
		if lifetime > 4.0:
			queue_free()

	func _on_body_entered(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()
		queue_free()


class TomatoChunkVisual extends Node2D:
	var spin: float = 0.0

	func _process(delta: float) -> void:
		spin += delta * 10.0
		queue_redraw()

	func _draw() -> void:
		# Spinning tomato chunk
		var r: float = 5.0
		draw_circle(Vector2.ZERO, r, Color(0.85, 0.2, 0.1))
		draw_circle(Vector2(-1, -1), r * 0.5, Color(1, 0.4, 0.3, 0.5))
		# Seed
		draw_circle(Vector2(cos(spin) * 2, sin(spin) * 2), 1, Color(0.95, 0.85, 0.5))
		# Juice trail
		draw_line(Vector2.ZERO, Vector2(-8, 2), Color(0.9, 0.2, 0.1, 0.3), 1.5)


# ############################################################
# BOSS INNER CLASSES
# ############################################################


# ============================================================
# PUMPKIN BOSS (Garden)
# ============================================================

class PumpkinBoss extends CharacterBody2D:
	var gravity: float = 600.0
	var hp: int = 0
	var shake_timer: float = 0.0
	var attack_timer: float = 0.0
	var attack_interval: float = 2.5
	var crack_count: int = 0
	var is_dead: bool = false

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 2
		hp = GameManager.boss_max_hp

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 50
		shape.shape = circle
		shape.position = Vector2(0, -50)
		add_child(shape)

		var visual := PumpkinBossVisual.new()
		visual.name = "Visual"
		add_child(visual)

		# Stomp hitbox on top
		var hitbox := Area2D.new()
		hitbox.collision_layer = 8
		hitbox.collision_mask = 1
		var hshape := CollisionShape2D.new()
		var hrect := RectangleShape2D.new()
		hrect.size = Vector2(60, 20)
		hshape.shape = hrect
		hshape.position = Vector2(0, -95)
		hitbox.add_child(hshape)
		hitbox.body_entered.connect(_on_stomp)
		add_child(hitbox)

		# Body damage hitbox (sides)
		var body_hitbox := Area2D.new()
		body_hitbox.collision_layer = 8
		body_hitbox.collision_mask = 1
		var bshape := CollisionShape2D.new()
		var bcircle := CircleShape2D.new()
		bcircle.radius = 48
		bshape.shape = bcircle
		bshape.position = Vector2(0, -50)
		body_hitbox.add_child(bshape)
		body_hitbox.body_entered.connect(_on_body_contact)
		add_child(body_hitbox)

	func _physics_process(delta: float) -> void:
		if is_dead:
			return

		velocity.y += gravity * delta
		move_and_slide()

		if shake_timer > 0:
			shake_timer -= delta

		attack_timer += delta
		if attack_timer >= attack_interval:
			attack_timer = 0.0
			_drop_seeds()

	func _drop_seeds() -> void:
		for i in range(3 + crack_count):
			var seed_proj := PumpkinSeed.new()
			seed_proj.position = global_position + Vector2(randf_range(-40, 40), -90)
			get_parent().add_child(seed_proj)

	func _on_stomp(body: Node2D) -> void:
		if is_dead:
			return
		if not body is CharacterBody2D:
			return
		if body.velocity.y > 0 and body.global_position.y < global_position.y - 60:
			GameManager.damage_boss(1)
			hp -= 1
			crack_count += 1
			shake_timer = 0.4
			body.velocity.y = -350.0

			var visual_node: Node = get_node_or_null("Visual")
			if visual_node and visual_node is PumpkinBossVisual:
				visual_node.crack_level = crack_count

			if hp <= 0:
				is_dead = true
				GameManager.on_enemy_killed("pumpkin_boss")
				queue_free()

	func _on_body_contact(body: Node2D) -> void:
		if is_dead:
			return
		if body is CharacterBody2D and body.has_method("take_hit"):
			if not (body.velocity.y > 0 and body.global_position.y < global_position.y - 60):
				body.take_hit()


class PumpkinBossVisual extends Node2D:
	var anim_timer: float = 0.0
	var crack_level: int = 0

	func _process(delta: float) -> void:
		anim_timer += delta
		queue_redraw()

	func _draw() -> void:
		var parent_node: Node = get_parent()
		var shake_offset := Vector2.ZERO
		if parent_node and "shake_timer" in parent_node and parent_node.shake_timer > 0:
			shake_offset = Vector2(randf_range(-4, 4), randf_range(-2, 2))

		var center := Vector2(0, -50) + shake_offset

		# Shadow
		_draw_filled_ellipse(Rect2(-45, 5, 90, 15), Color(0, 0, 0, 0.2))

		# Massive orange pumpkin body
		var pumpkin_color := Color(0.9, 0.55, 0.1)
		var pumpkin_dark := Color(0.75, 0.4, 0.05)
		draw_circle(center, 50, pumpkin_color)

		# Pumpkin ridges (vertical curved lines)
		for i in range(8):
			var ridge_angle: float = float(i) / 8.0 * TAU
			var rx1: float = cos(ridge_angle) * 48
			var ry1: float = sin(ridge_angle) * 10
			draw_arc(center + Vector2(rx1 * 0.1, 0), 48, ridge_angle - 0.2, ridge_angle + 0.2, 6, pumpkin_dark, 2.0)

		# Vertical ridge lines across body
		for i in range(6):
			var t: float = float(i) / 5.0
			var rx: float = lerpf(-40.0, 40.0, t)
			var curve: float = sqrt(maxf(0, 1.0 - (rx / 48.0) * (rx / 48.0))) * 48
			draw_line(center + Vector2(rx, -curve), center + Vector2(rx, curve), pumpkin_dark, 1.5)

		# Bottom darker area
		draw_arc(center, 48, 0.3, PI - 0.3, 16, pumpkin_dark.darkened(0.15), 4.0)

		# Highlight
		draw_circle(center + Vector2(-15, -20), 12, Color(1, 0.7, 0.3, 0.3))
		draw_circle(center + Vector2(-12, -25), 6, Color(1, 0.8, 0.5, 0.25))

		# Evil carved face - glowing yellow eyes
		var eye_glow: float = 0.7 + sin(anim_timer * 3.0) * 0.3
		var eye_color := Color(1, 0.9, 0.2, eye_glow)

		# Left eye - triangular carved
		var left_eye := PackedVector2Array([
			center + Vector2(-20, -15),
			center + Vector2(-10, -15),
			center + Vector2(-15, -5),
		])
		draw_colored_polygon(left_eye, Color(0.15, 0.08, 0.0))
		draw_colored_polygon(left_eye, eye_color)
		# Right eye
		var right_eye := PackedVector2Array([
			center + Vector2(10, -15),
			center + Vector2(20, -15),
			center + Vector2(15, -5),
		])
		draw_colored_polygon(right_eye, Color(0.15, 0.08, 0.0))
		draw_colored_polygon(right_eye, eye_color)

		# Evil nose triangle
		var nose := PackedVector2Array([
			center + Vector2(-3, -2),
			center + Vector2(3, -2),
			center + Vector2(0, 5),
		])
		draw_colored_polygon(nose, Color(0.15, 0.08, 0.0))

		# Evil mouth - jagged
		var mouth := PackedVector2Array([
			center + Vector2(-25, 10), center + Vector2(-18, 18),
			center + Vector2(-12, 10), center + Vector2(-6, 18),
			center + Vector2(0, 10), center + Vector2(6, 18),
			center + Vector2(12, 10), center + Vector2(18, 18),
			center + Vector2(25, 10), center + Vector2(25, 20),
			center + Vector2(-25, 20),
		])
		draw_colored_polygon(mouth, Color(0.15, 0.08, 0.0))
		# Mouth glow
		draw_colored_polygon(mouth, Color(1, 0.7, 0.1, 0.2))

		# Green vine crown on top
		for i in range(5):
			var vx: float = -20.0 + i * 10.0
			var vy: float = -48.0 - randf_range(5, 15)
			draw_line(center + Vector2(vx, -48), center + Vector2(vx + randf_range(-5, 5), vy), Color(0.2, 0.55, 0.15), 2.5)
			# Tiny leaves on vines
			draw_circle(center + Vector2(vx + randf_range(-3, 3), vy), 3, Color(0.25, 0.6, 0.2))

		# Stem on top
		draw_rect(Rect2(center.x - 4, center.y - 55, 8, 10), Color(0.3, 0.5, 0.15))
		draw_rect(Rect2(center.x - 3, center.y - 55, 3, 8), Color(0.35, 0.55, 0.2))

		# Crack damage visuals
		if crack_level >= 1:
			draw_line(center + Vector2(-15, 0), center + Vector2(-10, 20), Color(0.2, 0.1, 0.0, 0.7), 2.0)
			draw_line(center + Vector2(-10, 20), center + Vector2(-18, 30), Color(0.2, 0.1, 0.0, 0.6), 1.5)
		if crack_level >= 2:
			draw_line(center + Vector2(12, -5), center + Vector2(18, 15), Color(0.2, 0.1, 0.0, 0.7), 2.0)
			draw_line(center + Vector2(18, 15), center + Vector2(10, 28), Color(0.2, 0.1, 0.0, 0.6), 1.5)
		if crack_level >= 3:
			draw_line(center + Vector2(0, -30), center + Vector2(-8, -10), Color(0.2, 0.1, 0.0, 0.8), 2.5)
			draw_line(center + Vector2(-8, -10), center + Vector2(5, 5), Color(0.2, 0.1, 0.0, 0.7), 2.0)
		if crack_level >= 4:
			# Heavy damage - pieces falling off look
			draw_line(center + Vector2(20, -20), center + Vector2(30, 0), Color(0.2, 0.1, 0.0, 0.8), 3.0)
			draw_circle(center + Vector2(25, -10), 4, Color(0.2, 0.1, 0.0, 0.3))

	func _draw_filled_ellipse(rect: Rect2, color: Color) -> void:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		var rx: float = rect.size.x * 0.5
		var ry: float = rect.size.y * 0.5
		var pts := PackedVector2Array()
		var segments: int = 24
		for i in range(segments):
			var angle: float = float(i) / float(segments) * TAU
			pts.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
		draw_colored_polygon(pts, color)


class PumpkinSeed extends Area2D:
	var fall_speed: float = 0.0
	var lateral_speed: float = 0.0
	var lifetime: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 1
		fall_speed = randf_range(20, 60)
		lateral_speed = randf_range(-50, 50)

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 4
		shape.shape = circle
		add_child(shape)

		var visual := PumpkinSeedVisual.new()
		add_child(visual)

		body_entered.connect(_on_hit)

	func _process(delta: float) -> void:
		fall_speed += 200.0 * delta
		position.y += fall_speed * delta
		position.x += lateral_speed * delta
		lifetime += delta
		if lifetime > 5.0:
			queue_free()

	func _on_hit(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()
		queue_free()


class PumpkinSeedVisual extends Node2D:
	var spin: float = 0.0

	func _process(delta: float) -> void:
		spin += delta * 6.0
		queue_redraw()

	func _draw() -> void:
		# Pumpkin seed shape
		var seed_pts := PackedVector2Array([
			Vector2(0, -5), Vector2(3, -2), Vector2(3, 2),
			Vector2(0, 5), Vector2(-3, 2), Vector2(-3, -2),
		])
		draw_colored_polygon(seed_pts, Color(0.95, 0.88, 0.65))
		draw_circle(Vector2(0, 0), 2, Color(0.85, 0.78, 0.5))
		# Rotation visual
		var rx: float = cos(spin) * 2
		draw_line(Vector2(rx, -3), Vector2(rx, 3), Color(0.8, 0.7, 0.4, 0.5), 0.8)


# ============================================================
# CLEAVER BOSS (Kitchen)
# ============================================================

class CleaverBoss extends StaticBody2D:
	var hp: int = 0
	var slam_timer: float = 0.0
	var slam_interval: float = 3.0
	var is_slamming: bool = false
	var slam_progress: float = 0.0
	var is_stuck: bool = false
	var stuck_timer: float = 0.0
	var stuck_duration: float = 2.0
	var is_dead: bool = false
	var shake_timer: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		hp = GameManager.boss_max_hp

		var visual := CleaverBossVisual.new()
		visual.name = "Visual"
		add_child(visual)

		# Handle stomp zone (when stuck in ground)
		var stomp_zone := Area2D.new()
		stomp_zone.collision_layer = 8
		stomp_zone.collision_mask = 1
		var sshape := CollisionShape2D.new()
		var srect := RectangleShape2D.new()
		srect.size = Vector2(30, 20)
		sshape.shape = srect
		sshape.position = Vector2(0, -100)
		stomp_zone.add_child(sshape)
		stomp_zone.body_entered.connect(_on_handle_stomp)
		stomp_zone.name = "StompZone"
		add_child(stomp_zone)

		# Shockwave damage zone
		var shock_zone := Area2D.new()
		shock_zone.collision_layer = 8
		shock_zone.collision_mask = 1
		var shkshape := CollisionShape2D.new()
		var shkrect := RectangleShape2D.new()
		shkrect.size = Vector2(200, 20)
		shkshape.shape = shkrect
		shkshape.position = Vector2(0, -5)
		shock_zone.add_child(shkshape)
		shock_zone.body_entered.connect(_on_shockwave_hit)
		shock_zone.name = "ShockZone"
		shock_zone.monitoring = false
		add_child(shock_zone)

	func _process(delta: float) -> void:
		if is_dead:
			return

		if shake_timer > 0:
			shake_timer -= delta

		if is_stuck:
			stuck_timer += delta
			if stuck_timer >= stuck_duration:
				is_stuck = false
				stuck_timer = 0.0
				is_slamming = false
				slam_progress = 0.0
			return

		if is_slamming:
			slam_progress += delta * 3.0
			if slam_progress >= 1.0:
				slam_progress = 1.0
				is_stuck = true
				stuck_timer = 0.0
				_create_shockwave()
			return

		slam_timer += delta
		if slam_timer >= slam_interval:
			slam_timer = 0.0
			is_slamming = true
			slam_progress = 0.0

	func _create_shockwave() -> void:
		# Enable shockwave detection briefly
		var shock: Node = get_node_or_null("ShockZone")
		if shock and shock is Area2D:
			shock.monitoring = true
			# Disable after a short delay via a timer approach
			var t := Timer.new()
			t.wait_time = 0.3
			t.one_shot = true
			t.timeout.connect(_disable_shockwave)
			add_child(t)
			t.start()

		# Visual shockwave effect
		var effect := ShockwaveEffect.new()
		effect.position = Vector2(0, 0)
		get_parent().add_child(effect)

	func _disable_shockwave() -> void:
		var shock: Node = get_node_or_null("ShockZone")
		if shock and shock is Area2D:
			shock.monitoring = false

	func _on_handle_stomp(body: Node2D) -> void:
		if is_dead or not is_stuck:
			return
		if not body is CharacterBody2D:
			return
		if body.velocity.y > 0 and body.global_position.y < global_position.y - 80:
			GameManager.damage_boss(1)
			hp -= 1
			shake_timer = 0.3
			body.velocity.y = -350.0
			if hp <= 0:
				is_dead = true
				GameManager.on_enemy_killed("cleaver_boss")
				queue_free()

	func _on_shockwave_hit(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()


class CleaverBossVisual extends Node2D:
	var anim_timer: float = 0.0

	func _process(delta: float) -> void:
		anim_timer += delta
		queue_redraw()

	func _draw() -> void:
		var parent_node: Node = get_parent()
		var slam_prog: float = 0.0
		var stuck: bool = false
		var shake_off := Vector2.ZERO

		if parent_node and "slam_progress" in parent_node:
			slam_prog = parent_node.slam_progress
		if parent_node and "is_stuck" in parent_node:
			stuck = parent_node.is_stuck
		if parent_node and "shake_timer" in parent_node and parent_node.shake_timer > 0:
			shake_off = Vector2(randf_range(-3, 3), randf_range(-2, 2))

		# Calculate blade position based on slam state
		var blade_y_offset: float = -120.0 + slam_prog * 120.0  # Raised -> slammed down
		var base := Vector2(0, blade_y_offset) + shake_off

		# Massive silver blade
		var blade_color := Color(0.8, 0.82, 0.85)
		var blade_dark := Color(0.65, 0.67, 0.7)

		# Blade body - large rectangle tapering to edge
		var blade_pts := PackedVector2Array([
			base + Vector2(-35, 0),
			base + Vector2(35, 0),
			base + Vector2(30, 60),
			base + Vector2(35, 80),
			base + Vector2(-35, 80),
			base + Vector2(-30, 60),
		])
		draw_colored_polygon(blade_pts, blade_color)

		# Blade edge (bottom sharp edge)
		draw_line(base + Vector2(-35, 80), base + Vector2(35, 80), Color(0.9, 0.92, 0.95), 2.0)

		# Blade face gradient
		draw_rect(Rect2(base.x - 30, base.y + 5, 25, 70), blade_color.lightened(0.08))
		draw_rect(Rect2(base.x + 5, base.y + 5, 25, 70), blade_dark)

		# Blade gleam line
		draw_line(base + Vector2(-10, 5), base + Vector2(-10, 75), Color(1, 1, 1, 0.2), 2.0)

		# Wooden handle at top
		var handle_y: float = base.y - 30
		draw_rect(Rect2(base.x - 15, handle_y, 30, 35), Color(0.5, 0.32, 0.15))
		# Handle wood grain
		for i in range(4):
			var gy: float = handle_y + 5 + i * 8.0
			draw_line(Vector2(base.x - 12, gy), Vector2(base.x + 12, gy), Color(0.4, 0.25, 0.1, 0.4), 0.8)
		# Handle metal band
		draw_rect(Rect2(base.x - 16, handle_y + 30, 32, 4), Color(0.6, 0.6, 0.63))

		# Red angry eye on handle
		var eye_center := Vector2(base.x, handle_y + 15)
		draw_circle(eye_center, 6, Color.WHITE)
		draw_circle(eye_center, 4, Color(0.9, 0.15, 0.1))
		draw_circle(eye_center, 2, Color(0.2, 0.0, 0.0))
		draw_circle(eye_center + Vector2(-1, -1), 1.5, Color(1, 0.4, 0.3))
		# Angry eyebrow
		draw_line(eye_center + Vector2(-8, -8), eye_center + Vector2(-2, -5), Color(0.3, 0.15, 0.05), 2.0)
		draw_line(eye_center + Vector2(8, -8), eye_center + Vector2(2, -5), Color(0.3, 0.15, 0.05), 2.0)

		# Sparks when stuck in ground
		if stuck:
			for i in range(4):
				var sx: float = randf_range(-30, 30)
				var spark_alpha: float = sin(anim_timer * 8.0 + float(i)) * 0.5 + 0.5
				draw_circle(Vector2(base.x + sx, base.y + 82), 2, Color(1, 0.8, 0.3, spark_alpha * 0.6))
				draw_line(
					Vector2(base.x + sx, base.y + 80),
					Vector2(base.x + sx + randf_range(-5, 5), base.y + 85),
					Color(1, 0.9, 0.4, spark_alpha * 0.4), 1.0
				)


class ShockwaveEffect extends Node2D:
	var timer: float = 0.0
	var lifetime: float = 0.5
	var radius: float = 0.0

	func _process(delta: float) -> void:
		timer += delta
		radius += delta * 300.0
		if timer >= lifetime:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - timer / lifetime
		# Ground-level shockwave ring
		draw_arc(Vector2.ZERO, radius, 0, PI, 16, Color(0.7, 0.5, 0.2, alpha * 0.5), 3.0)
		draw_arc(Vector2.ZERO, radius * 0.7, 0, PI, 12, Color(0.8, 0.6, 0.3, alpha * 0.3), 2.0)
		# Dust particles
		for i in range(6):
			var a: float = float(i) / 6.0 * PI
			var px: float = cos(a) * radius * 0.9
			var py: float = sin(a) * 8
			draw_circle(Vector2(px, py), 3 * alpha, Color(0.6, 0.5, 0.3, alpha * 0.4))


# ============================================================
# ICE CREAM GOLEM BOSS (Fridge)
# ============================================================

class IceCreamBoss extends CharacterBody2D:
	var gravity: float = 600.0
	var hp: int = 0
	var attack_timer: float = 0.0
	var attack_interval: float = 2.0
	var is_dead: bool = false
	var shake_timer: float = 0.0
	var ice_patch_timer: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 2
		hp = GameManager.boss_max_hp

		var shape := CollisionShape2D.new()
		var capsule := CapsuleShape2D.new()
		capsule.radius = 30
		capsule.height = 90
		shape.shape = capsule
		shape.position = Vector2(0, -55)
		add_child(shape)

		var visual := IceCreamBossVisual.new()
		visual.name = "Visual"
		add_child(visual)

		# Cherry stomp zone (top)
		var cherry_zone := Area2D.new()
		cherry_zone.collision_layer = 8
		cherry_zone.collision_mask = 1
		var cshape := CollisionShape2D.new()
		var ccircle := CircleShape2D.new()
		ccircle.radius = 12
		cshape.shape = ccircle
		cshape.position = Vector2(0, -105)
		cherry_zone.add_child(cshape)
		cherry_zone.body_entered.connect(_on_cherry_stomp)
		add_child(cherry_zone)

		# Body damage zone
		var body_zone := Area2D.new()
		body_zone.collision_layer = 8
		body_zone.collision_mask = 1
		var bshape := CollisionShape2D.new()
		var bcapsule := CapsuleShape2D.new()
		bcapsule.radius = 28
		bcapsule.height = 80
		bshape.shape = bcapsule
		bshape.position = Vector2(0, -50)
		body_zone.add_child(bshape)
		body_zone.body_entered.connect(_on_body_contact)
		add_child(body_zone)

	func _physics_process(delta: float) -> void:
		if is_dead:
			return

		velocity.y += gravity * delta
		move_and_slide()

		if shake_timer > 0:
			shake_timer -= delta

		attack_timer += delta
		if attack_timer >= attack_interval:
			attack_timer = 0.0
			_attack()

		ice_patch_timer += delta
		if ice_patch_timer >= 5.0:
			ice_patch_timer = 0.0
			_create_ice_patch()

	func _attack() -> void:
		# Throw frozen projectiles
		for i in range(2):
			var proj := FrozenProjectile.new()
			var dir: float = [-1.0, 1.0][i]
			proj.position = global_position + Vector2(dir * 20, -60)
			proj.fly_direction = dir
			get_parent().add_child(proj)

	func _create_ice_patch() -> void:
		var patch := IcePatch.new()
		patch.position = global_position + Vector2(randf_range(-80, 80), 0)
		get_parent().add_child(patch)

	func _on_cherry_stomp(body: Node2D) -> void:
		if is_dead:
			return
		if not body is CharacterBody2D:
			return
		if body.velocity.y > 0 and body.global_position.y < global_position.y - 80:
			GameManager.damage_boss(1)
			hp -= 1
			shake_timer = 0.4
			body.velocity.y = -350.0

			var visual_node: Node = get_node_or_null("Visual")
			if visual_node and visual_node is IceCreamBossVisual:
				visual_node.melt_level += 1

			if hp <= 0:
				is_dead = true
				GameManager.on_enemy_killed("icecream_boss")
				queue_free()

	func _on_body_contact(body: Node2D) -> void:
		if is_dead:
			return
		if body is CharacterBody2D and body.has_method("take_hit"):
			if not (body.velocity.y > 0 and body.global_position.y < global_position.y - 80):
				body.take_hit()


class IceCreamBossVisual extends Node2D:
	var anim_timer: float = 0.0
	var melt_level: int = 0
	var drip_offsets: Array[float] = []

	func _ready() -> void:
		for i in range(8):
			drip_offsets.append(randf() * 20.0)

	func _process(delta: float) -> void:
		anim_timer += delta
		for i in range(drip_offsets.size()):
			drip_offsets[i] += delta * (8.0 + float(melt_level) * 4.0)
			if drip_offsets[i] > 25.0:
				drip_offsets[i] = 0.0
		queue_redraw()

	func _draw() -> void:
		var parent_node: Node = get_parent()
		var shake_off := Vector2.ZERO
		if parent_node and "shake_timer" in parent_node and parent_node.shake_timer > 0:
			shake_off = Vector2(randf_range(-4, 4), randf_range(-2, 2))

		var base := shake_off

		# Shadow
		_draw_filled_ellipse(Rect2(-35 + base.x, 5 + base.y, 70, 12), Color(0, 0, 0, 0.2))

		# Waffle cone legs
		var cone_color := Color(0.75, 0.55, 0.25)
		var cone_dark := Color(0.6, 0.4, 0.15)

		# Left leg
		var left_leg := PackedVector2Array([
			base + Vector2(-20, -10),
			base + Vector2(-10, -10),
			base + Vector2(-8, 5),
			base + Vector2(-22, 5),
		])
		draw_colored_polygon(left_leg, cone_color)
		# Waffle pattern
		draw_line(base + Vector2(-19, -8), base + Vector2(-9, 3), cone_dark, 0.8)
		draw_line(base + Vector2(-11, -8), base + Vector2(-21, 3), cone_dark, 0.8)

		# Right leg
		var right_leg := PackedVector2Array([
			base + Vector2(10, -10),
			base + Vector2(20, -10),
			base + Vector2(22, 5),
			base + Vector2(8, 5),
		])
		draw_colored_polygon(right_leg, cone_color)
		draw_line(base + Vector2(11, -8), base + Vector2(21, 3), cone_dark, 0.8)
		draw_line(base + Vector2(19, -8), base + Vector2(9, 3), cone_dark, 0.8)

		# Waffle cone body (main cone)
		var cone_pts := PackedVector2Array([
			base + Vector2(-25, -15),
			base + Vector2(25, -15),
			base + Vector2(20, -35),
			base + Vector2(-20, -35),
		])
		draw_colored_polygon(cone_pts, cone_color)
		# Waffle cross-hatch pattern
		for i in range(5):
			var cy: float = -17 - i * 4.0
			draw_line(base + Vector2(-23, cy), base + Vector2(23, cy), cone_dark, 0.7)
		for i in range(6):
			var cx: float = -20 + i * 8.0
			draw_line(base + Vector2(cx, -16), base + Vector2(cx, -33), cone_dark, 0.7)

		# Bottom scoop (chocolate)
		var scoop1_center := base + Vector2(0, -45)
		var scoop1_color := Color(0.45, 0.25, 0.12)
		draw_circle(scoop1_center, 28, scoop1_color)
		draw_circle(scoop1_center + Vector2(-8, -5), 8, scoop1_color.lightened(0.12))

		# Middle scoop (strawberry)
		var scoop2_center := base + Vector2(0, -72)
		var scoop2_color := Color(0.9, 0.5, 0.6)
		var melt_offset_2: float = float(melt_level) * 2.0
		draw_circle(scoop2_center + Vector2(0, melt_offset_2 * 0.5), 25, scoop2_color)
		draw_circle(scoop2_center + Vector2(-6, -4 + melt_offset_2 * 0.5), 7, scoop2_color.lightened(0.15))
		# Strawberry bits
		draw_circle(scoop2_center + Vector2(8, 3), 2, Color(0.8, 0.2, 0.2, 0.5))
		draw_circle(scoop2_center + Vector2(-5, 6), 1.5, Color(0.8, 0.2, 0.2, 0.4))

		# Top scoop (vanilla)
		var scoop3_center := base + Vector2(0, -95)
		var scoop3_color := Color(0.95, 0.92, 0.8)
		var melt_offset_3: float = float(melt_level) * 3.0
		draw_circle(scoop3_center + Vector2(0, melt_offset_3 * 0.5), 22, scoop3_color)
		draw_circle(scoop3_center + Vector2(-5, -3 + melt_offset_3 * 0.5), 6, Color(1, 0.98, 0.9, 0.6))
		# Vanilla specks
		draw_circle(scoop3_center + Vector2(5, 2), 1, Color(0.3, 0.2, 0.1, 0.3))
		draw_circle(scoop3_center + Vector2(-8, 4), 0.8, Color(0.3, 0.2, 0.1, 0.3))

		# Cherry on top (weak point)
		var cherry_center := scoop3_center + Vector2(0, -24 + melt_offset_3 * 0.3)
		# Cherry stem
		draw_line(cherry_center, cherry_center + Vector2(3, -8), Color(0.3, 0.5, 0.15), 1.5)
		# Cherry body
		draw_circle(cherry_center, 8, Color(0.85, 0.1, 0.15))
		draw_circle(cherry_center + Vector2(-2, -2), 3, Color(1, 0.3, 0.35, 0.5))
		draw_circle(cherry_center + Vector2(-1.5, -2.5), 1.5, Color(1, 0.6, 0.6, 0.4))

		# Melting drips (increase with damage)
		for i in range(drip_offsets.size()):
			if i >= drip_offsets.size():
				break
			var drip_x: float = -22 + float(i) * 7.0
			var drip_base_y: float = -35.0
			var drip_len: float = drip_offsets[i]
			var drip_alpha: float = 0.6 - drip_len / 25.0 * 0.4
			var drip_color: Color
			if i % 3 == 0:
				drip_color = scoop1_color
			elif i % 3 == 1:
				drip_color = scoop2_color
			else:
				drip_color = scoop3_color
			if drip_alpha > 0:
				draw_line(
					base + Vector2(drip_x, drip_base_y),
					base + Vector2(drip_x, drip_base_y + drip_len),
					Color(drip_color.r, drip_color.g, drip_color.b, drip_alpha), 2.0
				)
				draw_circle(
					base + Vector2(drip_x, drip_base_y + drip_len),
					1.5, Color(drip_color.r, drip_color.g, drip_color.b, drip_alpha)
				)

		# Eyes on middle scoop (angry)
		var eye_y: float = scoop2_center.y + melt_offset_2 * 0.5
		draw_circle(Vector2(-8 + base.x, eye_y - 2), 4, Color.WHITE)
		draw_circle(Vector2(8 + base.x, eye_y - 2), 4, Color.WHITE)
		draw_circle(Vector2(-8 + base.x, eye_y - 1), 2.5, Color(0.1, 0.1, 0.3))
		draw_circle(Vector2(8 + base.x, eye_y - 1), 2.5, Color(0.1, 0.1, 0.3))
		# Angry brows
		draw_line(Vector2(-13 + base.x, eye_y - 7), Vector2(-6 + base.x, eye_y - 4), Color(0.3, 0.1, 0.15), 2.0)
		draw_line(Vector2(13 + base.x, eye_y - 7), Vector2(6 + base.x, eye_y - 4), Color(0.3, 0.1, 0.15), 2.0)
		# Frown
		draw_arc(Vector2(base.x, eye_y + 8), 6, PI + 0.4, TAU - 0.4, 8, Color(0.3, 0.1, 0.15), 2.0)

	func _draw_filled_ellipse(rect: Rect2, color: Color) -> void:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var cy: float = rect.position.y + rect.size.y * 0.5
		var rx: float = rect.size.x * 0.5
		var ry: float = rect.size.y * 0.5
		var pts := PackedVector2Array()
		var segments: int = 24
		for i in range(segments):
			var angle: float = float(i) / float(segments) * TAU
			pts.append(Vector2(cx + cos(angle) * rx, cy + sin(angle) * ry))
		draw_colored_polygon(pts, color)


class FrozenProjectile extends Area2D:
	var fly_direction: float = 1.0
	var speed: float = 160.0
	var lifetime: float = 0.0

	func _ready() -> void:
		collision_layer = 8
		collision_mask = 1

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 6
		shape.shape = circle
		add_child(shape)

		var visual := FrozenProjectileVisual.new()
		add_child(visual)

		body_entered.connect(_on_hit)

	func _process(delta: float) -> void:
		position.x += speed * fly_direction * delta
		position.y += 20.0 * delta
		lifetime += delta
		if lifetime > 5.0:
			queue_free()

	func _on_hit(body: Node2D) -> void:
		if body.has_method("take_hit"):
			body.take_hit()
		queue_free()


class FrozenProjectileVisual extends Node2D:
	var spin: float = 0.0

	func _process(delta: float) -> void:
		spin += delta * 5.0
		queue_redraw()

	func _draw() -> void:
		# Ice chunk
		draw_circle(Vector2.ZERO, 6, Color(0.6, 0.85, 0.95, 0.8))
		draw_circle(Vector2(-1, -1), 3, Color(0.8, 0.93, 1.0, 0.6))
		# Frost particles
		var fx: float = cos(spin) * 4
		var fy: float = sin(spin) * 4
		draw_circle(Vector2(fx, fy), 1.5, Color(1, 1, 1, 0.4))
		# Crystal edges
		draw_line(Vector2(-4, -4), Vector2(-6, -6), Color(0.85, 0.95, 1, 0.3), 1.0)
		draw_line(Vector2(3, -3), Vector2(5, -5), Color(0.85, 0.95, 1, 0.3), 1.0)


class IcePatch extends Area2D:
	var lifetime: float = 0.0
	var max_lifetime: float = 6.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 10)
		shape.shape = rect
		add_child(shape)

		var visual := IcePatchVisual.new()
		add_child(visual)

		body_entered.connect(_on_player_enter)
		body_exited.connect(_on_player_exit)

	func _process(delta: float) -> void:
		lifetime += delta
		if lifetime >= max_lifetime:
			queue_free()

	func _on_player_enter(body: Node2D) -> void:
		if body.has_method("apply_ice"):
			body.apply_ice()
		elif body.has_method("apply_slow"):
			body.apply_slow(0.3)

	func _on_player_exit(body: Node2D) -> void:
		if body.has_method("remove_ice"):
			body.remove_ice()
		elif body.has_method("remove_slow"):
			body.remove_slow()


class IcePatchVisual extends Node2D:
	var shimmer: float = 0.0

	func _process(delta: float) -> void:
		shimmer += delta
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 0.5 + sin(shimmer * 2.0) * 0.1
		# Ice patch on ground
		_draw_filled_ellipse(Rect2(-30, -5, 60, 10), Color(0.6, 0.85, 0.95, alpha))
		_draw_filled_ellipse(Rect2(-25, -3, 50, 6), Color(0.75, 0.92, 1.0, alpha * 0.7))
		# Frost crystals
		draw_circle(Vector2(-15, -2), 2, Color(1, 1, 1, alpha * 0.4))
		draw_circle(Vector2(10, -1), 1.5, Color(1, 1, 1, alpha * 0.3))
		draw_circle(Vector2(0, 0), 1.8, Color(1, 1, 1, alpha * 0.35))

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
# MAGNET VISUAL
# ============================================================

class MagnetVisual extends Node2D:
	var pulse_timer: float = 0.0
	var bob_offset: float = 0.0

	func _ready() -> void:
		bob_offset = randf() * TAU

	func _process(delta: float) -> void:
		pulse_timer += delta
		bob_offset += delta * 3.0
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(bob_offset) * 4.0
		var center := Vector2(0, bob)
		var purple := Color(0.6, 0.15, 0.75)
		var light_purple := Color(0.75, 0.35, 0.9)

		# Outer magnetic field glow
		var glow_alpha: float = 0.1 + sin(pulse_timer * 3.0) * 0.06
		draw_circle(center, 22, Color(0.6, 0.2, 0.8, glow_alpha))

		# Horseshoe magnet body - U shape using lines
		# Left arm
		draw_line(center + Vector2(-8, -12), center + Vector2(-8, 6), purple, 5.0)
		# Right arm
		draw_line(center + Vector2(8, -12), center + Vector2(8, 6), purple, 5.0)
		# Bottom curve (arc approximation with lines)
		draw_line(center + Vector2(-8, 6), center + Vector2(-4, 10), purple, 5.0)
		draw_line(center + Vector2(-4, 10), center + Vector2(4, 10), purple, 5.0)
		draw_line(center + Vector2(4, 10), center + Vector2(8, 6), purple, 5.0)

		# Red and blue tips
		draw_line(center + Vector2(-8, -12), center + Vector2(-8, -6), Color(0.9, 0.2, 0.2), 5.0)
		draw_line(center + Vector2(8, -12), center + Vector2(8, -6), Color(0.2, 0.4, 0.9), 5.0)

		# Magnetic field lines (animated)
		var field_phase: float = fmod(pulse_timer * 2.0, TAU)
		for i in range(3):
			var offset_y: float = -14.0 - float(i) * 6.0
			var spread: float = 12.0 + float(i) * 4.0
			var alpha: float = (0.4 - float(i) * 0.1) * (0.7 + sin(field_phase + float(i)) * 0.3)
			draw_arc(center + Vector2(0, offset_y), spread, 0, PI, 8, light_purple * Color(1, 1, 1, alpha), 1.0)


# ============================================================
# DOUBLE SCORE VISUAL
# ============================================================

class DoubleScoreVisual extends Node2D:
	var glow_timer: float = 0.0
	var bob_offset: float = 0.0
	var spin_timer: float = 0.0

	func _ready() -> void:
		bob_offset = randf() * TAU

	func _process(delta: float) -> void:
		glow_timer += delta
		bob_offset += delta * 3.0
		spin_timer += delta
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(bob_offset) * 4.0
		var center := Vector2(0, bob)
		var gold := Color(1.0, 0.85, 0.2)
		var bright_gold := Color(1.0, 0.95, 0.5)

		# Outer glow
		var glow_alpha: float = 0.15 + sin(glow_timer * 3.5) * 0.08
		draw_circle(center, 24, Color(1.0, 0.9, 0.3, glow_alpha))

		# Star shape (5-pointed)
		var star_pts := PackedVector2Array()
		for i in range(10):
			var angle: float = float(i) / 10.0 * TAU - PI / 2.0
			var r: float = 16.0 if i % 2 == 0 else 8.0
			star_pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
		draw_colored_polygon(star_pts, gold)

		# Inner star highlight
		var inner_pts := PackedVector2Array()
		for i in range(10):
			var angle: float = float(i) / 10.0 * TAU - PI / 2.0
			var r: float = 10.0 if i % 2 == 0 else 5.0
			inner_pts.append(center + Vector2(cos(angle) * r, sin(angle) * r))
		draw_colored_polygon(inner_pts, bright_gold)

		# "2" shape
		draw_line(center + Vector2(-6, -4), center + Vector2(-1, -4), Color.WHITE, 1.5)
		draw_line(center + Vector2(-1, -4), center + Vector2(-1, -1), Color.WHITE, 1.5)
		draw_line(center + Vector2(-1, -1), center + Vector2(-6, -1), Color.WHITE, 1.5)
		draw_line(center + Vector2(-6, -1), center + Vector2(-6, 3), Color.WHITE, 1.5)
		draw_line(center + Vector2(-6, 3), center + Vector2(-1, 3), Color.WHITE, 1.5)
		# "X" shape
		draw_line(center + Vector2(1, -4), center + Vector2(6, 3), Color.WHITE, 1.5)
		draw_line(center + Vector2(6, -4), center + Vector2(1, 3), Color.WHITE, 1.5)

		# Sparkle rays
		var sparkle_phase: float = fmod(glow_timer * 1.5, 1.0)
		if sparkle_phase < 0.4:
			var s: float = sparkle_phase / 0.4
			for i in range(5):
				var angle: float = float(i) / 5.0 * TAU + spin_timer
				var from: Vector2 = center + Vector2(cos(angle) * 16, sin(angle) * 16)
				var to: Vector2 = center + Vector2(cos(angle) * (16 + 6 * s), sin(angle) * (16 + 6 * s))
				draw_line(from, to, Color(1, 1, 1, 0.7 * (1.0 - s)), 1.0)


# ============================================================
# EXTRA LIFE VISUAL
# ============================================================

class ExtraLifeVisual extends Node2D:
	var bob_offset: float = 0.0
	var pulse_timer: float = 0.0

	func _ready() -> void:
		bob_offset = randf() * TAU

	func _process(delta: float) -> void:
		bob_offset += delta * 3.0
		pulse_timer += delta
		queue_redraw()

	func _draw() -> void:
		var bob: float = sin(bob_offset) * 4.0
		var center := Vector2(0, bob)
		var cucumber_green := Color(0.3, 0.75, 0.2)
		var light_green := Color(0.45, 0.85, 0.35)

		# Outer glow
		var glow_alpha: float = 0.1 + sin(pulse_timer * 2.5) * 0.05
		draw_circle(center, 20, Color(0.3, 0.85, 0.2, glow_alpha))

		# Small cucumber head (oval)
		var head_pts := PackedVector2Array()
		for i in range(16):
			var angle: float = float(i) / 16.0 * TAU
			head_pts.append(center + Vector2(cos(angle) * 10, sin(angle) * 12))
		draw_colored_polygon(head_pts, cucumber_green)

		# Highlight
		var hl_pts := PackedVector2Array()
		for i in range(16):
			var angle: float = float(i) / 16.0 * TAU
			hl_pts.append(center + Vector2(-2 + cos(angle) * 5, -2 + sin(angle) * 7))
		draw_colored_polygon(hl_pts, light_green)

		# Tiny eyes
		draw_circle(center + Vector2(-3, -3), 2.5, Color(0.97, 0.97, 0.97))
		draw_circle(center + Vector2(3, -3), 2.5, Color(0.97, 0.97, 0.97))
		draw_circle(center + Vector2(-3, -3), 1.2, Color(0.08, 0.08, 0.08))
		draw_circle(center + Vector2(3, -3), 1.2, Color(0.08, 0.08, 0.08))

		# "+" sign
		var plus_color := Color(1.0, 1.0, 1.0, 0.9)
		draw_line(center + Vector2(0, 6), center + Vector2(0, 14), plus_color, 2.5)
		draw_line(center + Vector2(-4, 10), center + Vector2(4, 10), plus_color, 2.5)


# ============================================================
# WEATHER PARTICLES
# ============================================================

class WeatherLeafParticle extends Node2D:
	var vel := Vector2(0, 0)
	var lifetime: float = 0.0
	var sway_offset: float = 0.0
	var leaf_rotation: float = 0.0

	func _ready() -> void:
		vel = Vector2(randf_range(-20, 20), randf_range(30, 60))
		sway_offset = randf() * TAU
		leaf_rotation = randf() * TAU

	func _process(delta: float) -> void:
		lifetime += delta
		sway_offset += delta * 2.0
		leaf_rotation += delta * 1.5
		global_position += vel * delta
		global_position.x += sin(sway_offset) * 30.0 * delta
		if lifetime > 6.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - (lifetime / 6.0)
		var leaf_green := Color(0.3, 0.7, 0.15, alpha)
		# Small rectangle leaf
		var r: float = leaf_rotation
		var hw: float = 4.0
		var hh: float = 2.0
		var pts := PackedVector2Array([
			Vector2(cos(r) * hw - sin(r) * hh, sin(r) * hw + cos(r) * hh),
			Vector2(cos(r) * -hw - sin(r) * hh, sin(r) * -hw + cos(r) * hh),
			Vector2(cos(r) * -hw - sin(r) * -hh, sin(r) * -hw + cos(r) * -hh),
			Vector2(cos(r) * hw - sin(r) * -hh, sin(r) * hw + cos(r) * -hh),
		])
		draw_colored_polygon(pts, leaf_green)


class WeatherSteamParticle extends Node2D:
	var vel := Vector2(0, 0)
	var lifetime: float = 0.0
	var max_lifetime: float = 3.0

	func _ready() -> void:
		vel = Vector2(randf_range(-15, 15), randf_range(-40, -70))
		max_lifetime = randf_range(2.0, 4.0)

	func _process(delta: float) -> void:
		lifetime += delta
		global_position += vel * delta
		vel.x += randf_range(-10, 10) * delta
		if lifetime > max_lifetime:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t: float = lifetime / max_lifetime
		var alpha: float = (1.0 - t) * 0.4
		var radius: float = 3.0 + t * 5.0
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, alpha))


class WeatherSnowParticle extends Node2D:
	var vel := Vector2(0, 0)
	var lifetime: float = 0.0
	var sway_offset: float = 0.0
	var snow_size: float = 2.0

	func _ready() -> void:
		vel = Vector2(0, randf_range(25, 50))
		sway_offset = randf() * TAU
		snow_size = randf_range(1.5, 3.0)

	func _process(delta: float) -> void:
		lifetime += delta
		sway_offset += delta * 1.5
		global_position += vel * delta
		global_position.x += sin(sway_offset) * 25.0 * delta
		if lifetime > 8.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var alpha: float = 1.0 - (lifetime / 8.0)
		draw_circle(Vector2.ZERO, snow_size, Color(1.0, 1.0, 1.0, alpha * 0.7))
