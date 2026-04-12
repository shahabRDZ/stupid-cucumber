extends ParallaxBackground

## Multi-biome parallax background system for Stupid Cucumber
## Supports GARDEN, KITCHEN, and FRIDGE biomes with smooth transitions

var camera: Camera2D = null
var current_draw_biome: int = 0

# Sky color transition
var sky_color_top: Color = Color(0.4, 0.7, 0.95)
var sky_color_bottom: Color = Color(0.85, 0.92, 0.98)
var target_sky_top: Color = Color(0.4, 0.7, 0.95)
var target_sky_bottom: Color = Color(0.85, 0.92, 0.98)
var transition_timer: float = 0.0
const TRANSITION_DURATION: float = 2.0

# Layer references
var sky_layer: ParallaxLayer
var far_layer: ParallaxLayer
var mid_layer: ParallaxLayer

var sky_drawer: SkyDrawer
var far_drawer: FarBGDrawer
var mid_drawer: MidBGDrawer


func _ready() -> void:
	# Sky layer (static)
	sky_layer = ParallaxLayer.new()
	sky_layer.motion_scale = Vector2(0.0, 0.0)
	sky_drawer = SkyDrawer.new()
	sky_drawer.bg = self
	sky_layer.add_child(sky_drawer)
	add_child(sky_layer)

	# Far background layer
	far_layer = ParallaxLayer.new()
	far_layer.motion_scale = Vector2(0.2, 0.3)
	far_layer.motion_mirroring = Vector2(1600, 0)
	far_drawer = FarBGDrawer.new()
	far_drawer.bg = self
	far_layer.add_child(far_drawer)
	add_child(far_layer)

	# Mid background layer
	mid_layer = ParallaxLayer.new()
	mid_layer.motion_scale = Vector2(0.5, 0.5)
	mid_layer.motion_mirroring = Vector2(1600, 0)
	mid_drawer = MidBGDrawer.new()
	mid_drawer.bg = self
	mid_layer.add_child(mid_drawer)
	add_child(mid_layer)

	# Connect biome signal
	GameManager.biome_changed.connect(_on_biome_changed)
	_apply_biome(GameManager.current_biome)


func _process(delta: float) -> void:
	if transition_timer > 0.0:
		transition_timer -= delta
		var t: float = 1.0 - clampf(transition_timer / TRANSITION_DURATION, 0.0, 1.0)
		sky_color_top = sky_color_top.lerp(target_sky_top, t * delta * 3.0)
		sky_color_bottom = sky_color_bottom.lerp(target_sky_bottom, t * delta * 3.0)
		sky_drawer.queue_redraw()

		if transition_timer <= 0.0:
			sky_color_top = target_sky_top
			sky_color_bottom = target_sky_bottom
			sky_drawer.queue_redraw()


func _on_biome_changed(biome: int) -> void:
	_apply_biome(biome)


func _apply_biome(biome: int) -> void:
	current_draw_biome = biome

	var colors: Dictionary = GameManager.biome_colors[biome]
	target_sky_top = colors["sky_top"]
	target_sky_bottom = colors["sky_bottom"]
	transition_timer = TRANSITION_DURATION

	# Redraw element layers immediately with new biome
	far_drawer.queue_redraw()
	mid_drawer.queue_redraw()


# ============================================================
# SKY DRAWER
# ============================================================

class SkyDrawer extends Node2D:
	var bg: Node = null

	func _draw() -> void:
		if bg == null:
			return
		var top_col: Color = bg.sky_color_top
		var bot_col: Color = bg.sky_color_bottom
		var biome: int = bg.current_draw_biome

		# Gradient sky
		var rect_pos := Vector2(-1000, -600)
		var rect_size := Vector2(4000, 1600)
		var steps: int = 30
		var step_h: float = rect_size.y / float(steps)
		for i in range(steps):
			var t: float = float(i) / float(steps)
			var color: Color = top_col.lerp(bot_col, t)
			draw_rect(Rect2(rect_pos.x, rect_pos.y + i * step_h, rect_size.x, step_h + 1), color)

		match biome:
			GameManager.Biome.GARDEN:
				_draw_garden_sky()
			GameManager.Biome.KITCHEN:
				_draw_kitchen_sky()
			GameManager.Biome.FRIDGE:
				_draw_fridge_sky()

	# --- GARDEN SKY ---
	func _draw_garden_sky() -> void:
		# Sun with glow layers
		var sun_pos := Vector2(400, -280)
		draw_circle(sun_pos, 80, Color(1.0, 0.95, 0.4, 0.08))
		draw_circle(sun_pos, 65, Color(1.0, 0.95, 0.5, 0.15))
		draw_circle(sun_pos, 50, Color(1.0, 0.95, 0.5, 0.5))
		draw_circle(sun_pos, 40, Color(1.0, 0.97, 0.6, 0.9))
		# Sun rays
		for i in range(12):
			var angle: float = float(i) * TAU / 12.0
			var from: Vector2 = sun_pos + Vector2(cos(angle), sin(angle)) * 45
			var to: Vector2 = sun_pos + Vector2(cos(angle), sin(angle)) * 70
			draw_line(from, to, Color(1.0, 0.95, 0.5, 0.2), 2.0)

		# Clouds
		_draw_fluffy_cloud(Vector2(80, -200), 1.0)
		_draw_fluffy_cloud(Vector2(550, -320), 0.7)
		_draw_fluffy_cloud(Vector2(900, -180), 1.3)
		_draw_fluffy_cloud(Vector2(1300, -350), 0.9)
		_draw_fluffy_cloud(Vector2(1500, -220), 0.6)

		# Butterflies (small colored dots with tiny wings)
		_draw_butterfly(Vector2(250, -150), Color(1.0, 0.4, 0.6))
		_draw_butterfly(Vector2(700, -280), Color(0.4, 0.6, 1.0))
		_draw_butterfly(Vector2(1100, -200), Color(1.0, 0.8, 0.2))
		_draw_butterfly(Vector2(1400, -300), Color(0.7, 0.3, 0.9))

	func _draw_fluffy_cloud(pos: Vector2, s: float) -> void:
		var col := Color(1, 1, 1, 0.85)
		var shadow := Color(0.85, 0.88, 0.92, 0.4)
		# Shadow underneath
		draw_circle(pos + Vector2(2, 6) * s, 26 * s, shadow)
		draw_circle(pos + Vector2(22, 8) * s, 20 * s, shadow)
		draw_circle(pos + Vector2(-16, 9) * s, 18 * s, shadow)
		# Main cloud body
		draw_circle(pos, 28 * s, col)
		draw_circle(pos + Vector2(22, -4) * s, 22 * s, col)
		draw_circle(pos + Vector2(-20, 2) * s, 20 * s, col)
		draw_circle(pos + Vector2(10, 10) * s, 18 * s, col)
		draw_circle(pos + Vector2(-8, -12) * s, 24 * s, col)
		draw_circle(pos + Vector2(30, 5) * s, 15 * s, col)

	func _draw_butterfly(pos: Vector2, col: Color) -> void:
		# Body
		draw_circle(pos, 2, Color(0.2, 0.15, 0.1))
		# Wings
		draw_circle(pos + Vector2(-4, -2), 4, Color(col.r, col.g, col.b, 0.7))
		draw_circle(pos + Vector2(4, -2), 4, Color(col.r, col.g, col.b, 0.7))
		draw_circle(pos + Vector2(-3, 2), 3, Color(col.r, col.g, col.b, 0.5))
		draw_circle(pos + Vector2(3, 2), 3, Color(col.r, col.g, col.b, 0.5))

	# --- KITCHEN SKY ---
	func _draw_kitchen_sky() -> void:
		# Ceiling line
		draw_line(Vector2(-1000, -400), Vector2(4000, -400), Color(0.75, 0.68, 0.58, 0.3), 3.0)

		# Hanging lamps
		_draw_hanging_lamp(Vector2(200, -350), 1.0)
		_draw_hanging_lamp(Vector2(700, -370), 0.8)
		_draw_hanging_lamp(Vector2(1200, -340), 1.1)

		# Steam wisps
		_draw_steam(Vector2(400, -100), 1.0)
		_draw_steam(Vector2(900, -150), 0.7)
		_draw_steam(Vector2(1400, -120), 0.9)

		# Subtle wall texture lines
		for i in range(8):
			var x: float = float(i) * 200.0 - 100.0
			draw_line(Vector2(x, -400), Vector2(x, 600), Color(0.8, 0.75, 0.65, 0.06), 1.0)

	func _draw_hanging_lamp(pos: Vector2, s: float) -> void:
		# Wire
		draw_line(pos + Vector2(0, -200), pos, Color(0.3, 0.28, 0.25, 0.5), 2.0)
		# Lamp shade (trapezoid)
		var shade := PackedVector2Array([
			pos + Vector2(-18, 0) * s,
			pos + Vector2(18, 0) * s,
			pos + Vector2(12, -15) * s,
			pos + Vector2(-12, -15) * s,
		])
		draw_colored_polygon(shade, Color(0.85, 0.78, 0.55, 0.7))
		# Bulb
		draw_circle(pos + Vector2(0, 8) * s, 6 * s, Color(1.0, 0.95, 0.7, 0.9))
		# Glow
		draw_circle(pos + Vector2(0, 8) * s, 30 * s, Color(1.0, 0.95, 0.7, 0.08))
		draw_circle(pos + Vector2(0, 8) * s, 50 * s, Color(1.0, 0.95, 0.7, 0.04))

	func _draw_steam(pos: Vector2, s: float) -> void:
		for i in range(5):
			var offset := Vector2(sin(float(i) * 1.5) * 15, float(i) * -20) * s
			draw_circle(pos + offset, (8.0 - float(i)) * s, Color(1, 1, 1, 0.06 - float(i) * 0.01))

	# --- FRIDGE SKY ---
	func _draw_fridge_sky() -> void:
		# Frost crystals
		_draw_frost_crystal(Vector2(150, -250), 1.0)
		_draw_frost_crystal(Vector2(500, -350), 0.6)
		_draw_frost_crystal(Vector2(850, -200), 0.8)
		_draw_frost_crystal(Vector2(1200, -300), 1.2)
		_draw_frost_crystal(Vector2(1450, -250), 0.5)

		# Cold fog layers
		for i in range(4):
			var y: float = -100.0 + float(i) * 120.0
			var alpha: float = 0.05 - float(i) * 0.01
			draw_rect(Rect2(-1000, y, 4000, 80), Color(0.85, 0.92, 1.0, alpha))

		# Tiny ice sparkles
		var sparkle_col := Color(1, 1, 1, 0.4)
		var sparkle_positions: Array[Vector2] = [
			Vector2(100, -180), Vector2(300, -320), Vector2(600, -150),
			Vector2(800, -380), Vector2(1000, -220), Vector2(1300, -280),
			Vector2(1500, -160), Vector2(200, -400), Vector2(700, -300),
		]
		for sp in sparkle_positions:
			draw_circle(sp, 2, sparkle_col)
			draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), Color(1, 1, 1, 0.25), 1.0)
			draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), Color(1, 1, 1, 0.25), 1.0)

	func _draw_frost_crystal(pos: Vector2, s: float) -> void:
		var col := Color(0.9, 0.95, 1.0, 0.3)
		# Six-pointed crystal
		for i in range(6):
			var angle: float = float(i) * TAU / 6.0
			var tip: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 15 * s
			draw_line(pos, tip, col, 1.5)
			# Branch tips
			var mid: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 9 * s
			var perp: float = angle + PI / 2.0
			draw_line(mid, mid + Vector2(cos(perp), sin(perp)) * 5 * s, col, 1.0)
			draw_line(mid, mid - Vector2(cos(perp), sin(perp)) * 5 * s, col, 1.0)


# ============================================================
# FAR BACKGROUND DRAWER
# ============================================================

class FarBGDrawer extends Node2D:
	var bg: Node = null

	func _ready() -> void:
		z_index = -10

	func _draw() -> void:
		if bg == null:
			return
		match bg.current_draw_biome:
			GameManager.Biome.GARDEN:
				_draw_garden_far()
			GameManager.Biome.KITCHEN:
				_draw_kitchen_far()
			GameManager.Biome.FRIDGE:
				_draw_fridge_far()

	# --- GARDEN FAR ---
	func _draw_garden_far() -> void:
		# Distant veggie-shaped mountains
		_draw_veggie_mountain(Vector2(-100, 400), 500, 350, Color(0.35, 0.55, 0.3, 0.3))
		_draw_veggie_mountain(Vector2(400, 430), 400, 280, Color(0.3, 0.5, 0.25, 0.35))
		_draw_veggie_mountain(Vector2(900, 410), 450, 320, Color(0.32, 0.52, 0.28, 0.3))
		_draw_veggie_mountain(Vector2(1400, 440), 380, 260, Color(0.28, 0.48, 0.22, 0.35))

		# Rolling green hills
		_draw_hill(Vector2(200, 500), 280, 180, Color(0.3, 0.58, 0.22, 0.55))
		_draw_hill(Vector2(600, 510), 320, 200, Color(0.25, 0.52, 0.18, 0.55))
		_draw_hill(Vector2(1000, 495), 260, 170, Color(0.32, 0.6, 0.24, 0.55))
		_draw_hill(Vector2(1400, 505), 300, 190, Color(0.28, 0.55, 0.2, 0.55))

		# Broccoli trees
		_draw_broccoli(Vector2(120, 360), 1.3)
		_draw_broccoli(Vector2(380, 340), 1.0)
		_draw_broccoli(Vector2(550, 370), 0.8)
		_draw_broccoli(Vector2(780, 350), 1.1)
		_draw_broccoli(Vector2(1050, 345), 1.4)
		_draw_broccoli(Vector2(1250, 375), 0.9)
		_draw_broccoli(Vector2(1450, 355), 1.0)

		# Flower patches (colored dots on hills)
		var flower_colors: Array[Color] = [
			Color(1.0, 0.3, 0.4, 0.5), Color(1.0, 0.85, 0.2, 0.5),
			Color(0.9, 0.4, 0.7, 0.5), Color(0.4, 0.5, 1.0, 0.5),
		]
		var flower_positions: Array[Vector2] = [
			Vector2(160, 440), Vector2(180, 450), Vector2(200, 445),
			Vector2(450, 460), Vector2(470, 465), Vector2(485, 458),
			Vector2(750, 445), Vector2(770, 450), Vector2(790, 442),
			Vector2(1100, 455), Vector2(1120, 460), Vector2(1140, 452),
			Vector2(1350, 448), Vector2(1370, 455), Vector2(1390, 445),
		]
		for i in range(flower_positions.size()):
			var col: Color = flower_colors[i % flower_colors.size()]
			draw_circle(flower_positions[i], 3, col)
			draw_circle(flower_positions[i], 1.5, Color(1, 1, 0.8, 0.6))

		# Birds (V shapes in distance)
		_draw_bird(Vector2(300, 200))
		_draw_bird(Vector2(700, 150))
		_draw_bird(Vector2(1100, 180))
		_draw_bird(Vector2(1400, 130))

	func _draw_veggie_mountain(center: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts: PackedVector2Array = []
		for i in range(30):
			var angle: float = PI + float(i) / 29.0 * PI
			var bump: float = sin(float(i) * 0.8) * 15.0
			pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry + bump))
		pts.append(center + Vector2(rx, 300))
		pts.append(center + Vector2(-rx, 300))
		draw_colored_polygon(pts, col)

	func _draw_hill(center: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts: PackedVector2Array = []
		for i in range(25):
			var angle: float = PI + float(i) / 24.0 * PI
			pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		pts.append(center + Vector2(rx, 200))
		pts.append(center + Vector2(-rx, 200))
		draw_colored_polygon(pts, col)

	func _draw_broccoli(pos: Vector2, s: float) -> void:
		# Trunk
		draw_rect(Rect2(pos.x - 5 * s, pos.y, 10 * s, 45 * s), Color(0.5, 0.38, 0.22, 0.45))
		# Canopy puffs
		var canopy := Color(0.22, 0.52, 0.18, 0.5)
		var canopy_light := Color(0.3, 0.6, 0.22, 0.45)
		draw_circle(pos + Vector2(0, -8) * s, 20 * s, canopy)
		draw_circle(pos + Vector2(14, 0) * s, 16 * s, canopy)
		draw_circle(pos + Vector2(-12, 3) * s, 15 * s, canopy)
		draw_circle(pos + Vector2(6, -15) * s, 14 * s, canopy_light)
		draw_circle(pos + Vector2(-6, -12) * s, 13 * s, canopy_light)

	func _draw_bird(pos: Vector2) -> void:
		var col := Color(0.2, 0.2, 0.3, 0.35)
		draw_line(pos, pos + Vector2(-8, -6), col, 1.5)
		draw_line(pos, pos + Vector2(8, -6), col, 1.5)

	# --- KITCHEN FAR ---
	func _draw_kitchen_far() -> void:
		# Kitchen counter silhouette
		draw_rect(Rect2(-100, 400, 1800, 300), Color(0.55, 0.45, 0.35, 0.4))
		draw_rect(Rect2(-100, 395, 1800, 5), Color(0.65, 0.55, 0.42, 0.5))

		# Tiled wall pattern (subtle grid)
		for row in range(8):
			for col in range(20):
				var x: float = float(col) * 90.0 - 50.0
				var y: float = float(row) * 55.0 + 50.0
				draw_rect(Rect2(x, y, 85, 50), Color(0.88, 0.83, 0.76, 0.08))
				draw_rect(Rect2(x, y, 85, 50), Color(0.7, 0.65, 0.55, 0.05), false, 1.0)

		# Shelves with jars/bottles
		_draw_shelf(Vector2(100, 200), 300)
		_draw_shelf(Vector2(700, 180), 250)
		_draw_shelf(Vector2(1200, 210), 280)

		# Jars on shelves
		_draw_jar(Vector2(130, 185), Color(0.8, 0.3, 0.2, 0.35), 0.8)
		_draw_jar(Vector2(200, 180), Color(0.2, 0.6, 0.3, 0.35), 1.0)
		_draw_jar(Vector2(280, 185), Color(0.9, 0.75, 0.2, 0.35), 0.9)
		_draw_jar(Vector2(350, 182), Color(0.6, 0.2, 0.5, 0.35), 0.7)

		_draw_jar(Vector2(730, 165), Color(0.3, 0.5, 0.7, 0.35), 0.9)
		_draw_jar(Vector2(800, 160), Color(0.8, 0.5, 0.2, 0.35), 1.1)
		_draw_jar(Vector2(870, 165), Color(0.4, 0.7, 0.3, 0.35), 0.8)

		_draw_jar(Vector2(1230, 195), Color(0.7, 0.3, 0.3, 0.35), 1.0)
		_draw_jar(Vector2(1310, 190), Color(0.3, 0.4, 0.7, 0.35), 0.85)
		_draw_jar(Vector2(1400, 195), Color(0.8, 0.7, 0.3, 0.35), 0.95)

		# Spice rack silhouette
		_draw_spice_rack(Vector2(500, 260))
		_draw_spice_rack(Vector2(1050, 280))

		# Window with light
		_draw_window(Vector2(1500, 120))

	func _draw_shelf(pos: Vector2, width: float) -> void:
		draw_rect(Rect2(pos.x, pos.y, width, 6), Color(0.5, 0.4, 0.3, 0.5))
		# Shelf brackets
		var bracket_col := Color(0.45, 0.35, 0.28, 0.4)
		draw_rect(Rect2(pos.x + 10, pos.y + 6, 4, 15), bracket_col)
		draw_rect(Rect2(pos.x + width - 14, pos.y + 6, 4, 15), bracket_col)

	func _draw_jar(pos: Vector2, col: Color, s: float) -> void:
		# Jar body
		draw_rect(Rect2(pos.x - 10 * s, pos.y - 28 * s, 20 * s, 28 * s), col)
		# Jar neck
		draw_rect(Rect2(pos.x - 6 * s, pos.y - 34 * s, 12 * s, 6 * s), Color(col.r, col.g, col.b, col.a * 0.8))
		# Lid
		draw_rect(Rect2(pos.x - 8 * s, pos.y - 37 * s, 16 * s, 4 * s), Color(0.6, 0.55, 0.5, 0.5))
		# Highlight
		draw_rect(Rect2(pos.x - 6 * s, pos.y - 26 * s, 3 * s, 18 * s), Color(1, 1, 1, 0.08))

	func _draw_spice_rack(pos: Vector2) -> void:
		draw_rect(Rect2(pos.x, pos.y, 120, 5), Color(0.5, 0.4, 0.3, 0.35))
		# Small spice bottles
		for i in range(5):
			var x: float = pos.x + 10 + float(i) * 22
			var h: float = 18.0 + float(i % 3) * 5.0
			draw_rect(Rect2(x, pos.y - h, 12, h), Color(0.7, 0.55, 0.35, 0.3))
			draw_rect(Rect2(x + 2, pos.y - h - 4, 8, 4), Color(0.6, 0.5, 0.4, 0.35))

	func _draw_window(pos: Vector2) -> void:
		# Window frame
		draw_rect(Rect2(pos.x - 50, pos.y - 60, 100, 120), Color(0.6, 0.52, 0.4, 0.4))
		# Glass (bright)
		draw_rect(Rect2(pos.x - 44, pos.y - 54, 40, 50), Color(0.85, 0.9, 1.0, 0.2))
		draw_rect(Rect2(pos.x + 4, pos.y - 54, 40, 50), Color(0.85, 0.9, 1.0, 0.2))
		draw_rect(Rect2(pos.x - 44, pos.y + 4, 40, 50), Color(0.8, 0.85, 0.95, 0.15))
		draw_rect(Rect2(pos.x + 4, pos.y + 4, 40, 50), Color(0.8, 0.85, 0.95, 0.15))
		# Cross bar
		draw_rect(Rect2(pos.x - 2, pos.y - 54, 4, 108), Color(0.55, 0.48, 0.38, 0.45))
		draw_rect(Rect2(pos.x - 44, pos.y - 2, 88, 4), Color(0.55, 0.48, 0.38, 0.45))
		# Light glow from window
		draw_circle(pos, 70, Color(1.0, 0.97, 0.85, 0.04))

	# --- FRIDGE FAR ---
	func _draw_fridge_far() -> void:
		# Ice shelf background
		draw_rect(Rect2(-100, 350, 1800, 350), Color(0.7, 0.8, 0.9, 0.3))

		# Frozen shelves
		_draw_ice_shelf(Vector2(-50, 200), 1700)
		_draw_ice_shelf(Vector2(-50, 380), 1700)

		# Ice formations / mountains
		_draw_ice_mountain(Vector2(100, 500), 200, 250, Color(0.75, 0.88, 0.98, 0.35))
		_draw_ice_mountain(Vector2(500, 510), 180, 200, Color(0.7, 0.85, 0.95, 0.3))
		_draw_ice_mountain(Vector2(900, 490), 220, 270, Color(0.72, 0.86, 0.96, 0.35))
		_draw_ice_mountain(Vector2(1300, 505), 190, 220, Color(0.68, 0.82, 0.94, 0.3))

		# Icicles hanging from top
		for i in range(18):
			var x: float = float(i) * 95.0 + 20.0
			var length: float = 25.0 + fmod(float(i) * 37.0, 40.0)
			_draw_icicle(Vector2(x, 195), length)

		# Frozen food box silhouettes on shelves
		_draw_frozen_box(Vector2(200, 345), 40, 30, Color(0.5, 0.65, 0.8, 0.3))
		_draw_frozen_box(Vector2(350, 340), 50, 35, Color(0.55, 0.6, 0.75, 0.3))
		_draw_frozen_box(Vector2(600, 348), 45, 28, Color(0.48, 0.62, 0.78, 0.3))
		_draw_frozen_box(Vector2(800, 342), 35, 33, Color(0.52, 0.67, 0.82, 0.3))
		_draw_frozen_box(Vector2(1050, 346), 48, 30, Color(0.5, 0.63, 0.76, 0.3))
		_draw_frozen_box(Vector2(1300, 340), 42, 35, Color(0.53, 0.68, 0.8, 0.3))

		# Ice cube mountains in the back
		_draw_ice_cubes(Vector2(300, 460))
		_draw_ice_cubes(Vector2(750, 470))
		_draw_ice_cubes(Vector2(1150, 455))

	func _draw_ice_shelf(pos: Vector2, width: float) -> void:
		draw_rect(Rect2(pos.x, pos.y, width, 8), Color(0.8, 0.88, 0.95, 0.4))
		draw_rect(Rect2(pos.x, pos.y + 8, width, 3), Color(0.7, 0.78, 0.88, 0.2))
		# Frost on shelf edge
		for i in range(int(width / 30)):
			var x: float = pos.x + float(i) * 30.0
			draw_circle(Vector2(x + 15, pos.y + 2), 5, Color(0.9, 0.95, 1.0, 0.15))

	func _draw_ice_mountain(center: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts: PackedVector2Array = []
		for i in range(20):
			var angle: float = PI + float(i) / 19.0 * PI
			var jagged: float = sin(float(i) * 2.3) * 10.0
			pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry + jagged))
		pts.append(center + Vector2(rx, 200))
		pts.append(center + Vector2(-rx, 200))
		draw_colored_polygon(pts, col)
		# Highlight edge
		if pts.size() > 2:
			for i in range(pts.size() - 3):
				draw_line(pts[i], pts[i + 1], Color(0.9, 0.95, 1.0, 0.1), 1.0)

	func _draw_icicle(pos: Vector2, length: float) -> void:
		var pts := PackedVector2Array([
			pos + Vector2(-4, 0),
			pos + Vector2(4, 0),
			pos + Vector2(0, length),
		])
		draw_colored_polygon(pts, Color(0.8, 0.9, 1.0, 0.35))
		# Highlight line
		draw_line(pos + Vector2(-1, 2), pos + Vector2(-1, length * 0.6), Color(1, 1, 1, 0.15), 1.0)

	func _draw_frozen_box(pos: Vector2, w: float, h: float, col: Color) -> void:
		draw_rect(Rect2(pos.x, pos.y - h, w, h), col)
		# Frost on box
		draw_rect(Rect2(pos.x + 2, pos.y - h + 2, w - 4, 4), Color(0.9, 0.95, 1.0, 0.15))
		# Label line
		draw_rect(Rect2(pos.x + 5, pos.y - h * 0.5, w - 10, 3), Color(0.6, 0.7, 0.85, 0.2))

	func _draw_ice_cubes(pos: Vector2) -> void:
		var col := Color(0.75, 0.88, 0.98, 0.25)
		var highlight := Color(0.9, 0.95, 1.0, 0.15)
		# Stack of ice cubes
		draw_rect(Rect2(pos.x, pos.y - 25, 30, 25), col)
		draw_rect(Rect2(pos.x + 2, pos.y - 23, 5, 15), highlight)
		draw_rect(Rect2(pos.x + 35, pos.y - 20, 25, 20), col)
		draw_rect(Rect2(pos.x + 37, pos.y - 18, 4, 12), highlight)
		draw_rect(Rect2(pos.x + 10, pos.y - 45, 28, 22), col)
		draw_rect(Rect2(pos.x + 12, pos.y - 43, 5, 14), highlight)


# ============================================================
# MID BACKGROUND DRAWER
# ============================================================

class MidBGDrawer extends Node2D:
	var bg: Node = null

	func _ready() -> void:
		z_index = -5

	func _draw() -> void:
		if bg == null:
			return
		match bg.current_draw_biome:
			GameManager.Biome.GARDEN:
				_draw_garden_mid()
			GameManager.Biome.KITCHEN:
				_draw_kitchen_mid()
			GameManager.Biome.FRIDGE:
				_draw_fridge_mid()

	# --- GARDEN MID ---
	func _draw_garden_mid() -> void:
		# Ground fill
		draw_rect(Rect2(-100, 530, 1800, 200), Color(0.35, 0.55, 0.2, 0.3))

		# Giant mushrooms
		_draw_mushroom(Vector2(200, 490), 1.2)
		_draw_mushroom(Vector2(600, 500), 0.8)
		_draw_mushroom(Vector2(1050, 485), 1.0)
		_draw_mushroom(Vector2(1400, 495), 0.7)

		# Carrot patches sticking from ground
		_draw_carrot(Vector2(100, 520), 1.0)
		_draw_carrot(Vector2(350, 525), 0.7)
		_draw_carrot(Vector2(700, 518), 0.9)
		_draw_carrot(Vector2(950, 522), 0.6)
		_draw_carrot(Vector2(1200, 520), 1.1)
		_draw_carrot(Vector2(1500, 525), 0.8)

		# Tomato bushes
		_draw_tomato_bush(Vector2(450, 510))
		_draw_tomato_bush(Vector2(850, 515))
		_draw_tomato_bush(Vector2(1300, 508))

		# Sunflowers
		_draw_sunflower(Vector2(150, 470), 1.0)
		_draw_sunflower(Vector2(520, 475), 0.8)
		_draw_sunflower(Vector2(900, 465), 1.1)
		_draw_sunflower(Vector2(1350, 472), 0.9)

		# Fence posts
		for i in range(8):
			var x: float = float(i) * 200.0 + 50.0
			_draw_fence_post(Vector2(x, 530))

		# Garden signs
		_draw_garden_sign(Vector2(300, 480), "Carrots")
		_draw_garden_sign(Vector2(1100, 485), "Veggies")

	func _draw_mushroom(pos: Vector2, s: float) -> void:
		# Stem
		draw_rect(Rect2(pos.x - 10 * s, pos.y - 25 * s, 20 * s, 30 * s), Color(0.92, 0.88, 0.78, 0.55))
		# Stem ring
		draw_rect(Rect2(pos.x - 12 * s, pos.y - 5 * s, 24 * s, 3 * s), Color(0.85, 0.82, 0.72, 0.4))
		# Cap
		var cap_pts: PackedVector2Array = []
		for i in range(15):
			var angle: float = PI + float(i) / 14.0 * PI
			cap_pts.append(pos + Vector2(0, -25 * s) + Vector2(cos(angle) * 30 * s, sin(angle) * 20 * s))
		draw_colored_polygon(cap_pts, Color(0.82, 0.22, 0.18, 0.55))
		# Spots
		draw_circle(pos + Vector2(-10, -32) * s, 5 * s, Color(1, 1, 1, 0.45))
		draw_circle(pos + Vector2(8, -38) * s, 4 * s, Color(1, 1, 1, 0.45))
		draw_circle(pos + Vector2(-2, -42) * s, 3.5 * s, Color(1, 1, 1, 0.4))
		draw_circle(pos + Vector2(15, -28) * s, 3 * s, Color(1, 1, 1, 0.35))

	func _draw_carrot(pos: Vector2, s: float) -> void:
		var pts := PackedVector2Array([
			pos + Vector2(-9, 0) * s,
			pos + Vector2(9, 0) * s,
			pos + Vector2(0, -55) * s,
		])
		draw_colored_polygon(pts, Color(1.0, 0.55, 0.15, 0.55))
		# Horizontal lines on carrot
		for i in range(3):
			var y: float = pos.y - (15.0 + float(i) * 12.0) * s
			var half_w: float = (6.0 - float(i) * 1.5) * s
			draw_line(Vector2(pos.x - half_w, y), Vector2(pos.x + half_w, y), Color(0.85, 0.45, 0.1, 0.3), 1.0)
		# Leafy top
		var leaf_col := Color(0.22, 0.6, 0.18, 0.5)
		draw_circle(pos + Vector2(0, -55) * s, 10 * s, leaf_col)
		draw_circle(pos + Vector2(8, -60) * s, 7 * s, leaf_col)
		draw_circle(pos + Vector2(-7, -58) * s, 8 * s, leaf_col)

	func _draw_tomato_bush(pos: Vector2) -> void:
		# Bush body
		draw_circle(pos + Vector2(0, -12), 22, Color(0.28, 0.52, 0.22, 0.45))
		draw_circle(pos + Vector2(16, -8), 16, Color(0.25, 0.48, 0.2, 0.45))
		draw_circle(pos + Vector2(-14, -6), 15, Color(0.25, 0.5, 0.2, 0.45))
		# Tomatoes (red dots)
		draw_circle(pos + Vector2(-6, -18), 7, Color(0.88, 0.18, 0.12, 0.55))
		draw_circle(pos + Vector2(10, -14), 6, Color(0.92, 0.22, 0.14, 0.55))
		draw_circle(pos + Vector2(2, -6), 5, Color(0.85, 0.15, 0.1, 0.5))
		draw_circle(pos + Vector2(-12, -10), 5.5, Color(0.9, 0.2, 0.12, 0.5))
		# Tomato highlights
		draw_circle(pos + Vector2(-7, -20), 2, Color(1, 1, 1, 0.2))
		draw_circle(pos + Vector2(9, -16), 2, Color(1, 1, 1, 0.2))

	func _draw_sunflower(pos: Vector2, s: float) -> void:
		# Stem
		draw_line(pos + Vector2(0, 50) * s, pos, Color(0.3, 0.5, 0.2, 0.5), 3.0 * s)
		# Leaves on stem
		draw_circle(pos + Vector2(8, 30) * s, 6 * s, Color(0.3, 0.55, 0.2, 0.4))
		draw_circle(pos + Vector2(-7, 20) * s, 5 * s, Color(0.3, 0.55, 0.2, 0.4))
		# Petals
		var petal_col := Color(1.0, 0.85, 0.15, 0.55)
		for i in range(10):
			var angle: float = float(i) * TAU / 10.0
			var petal_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 10 * s
			draw_circle(petal_pos, 5 * s, petal_col)
		# Center
		draw_circle(pos, 7 * s, Color(0.45, 0.3, 0.1, 0.6))
		draw_circle(pos, 5 * s, Color(0.55, 0.35, 0.12, 0.55))

	func _draw_fence_post(pos: Vector2) -> void:
		var col := Color(0.55, 0.42, 0.28, 0.35)
		draw_rect(Rect2(pos.x - 4, pos.y - 40, 8, 45), col)
		# Pointed top
		var top_pts := PackedVector2Array([
			pos + Vector2(-4, -40),
			pos + Vector2(4, -40),
			pos + Vector2(0, -50),
		])
		draw_colored_polygon(top_pts, col)
		# Horizontal rails
		draw_rect(Rect2(pos.x - 4, pos.y - 30, 100, 4), Color(0.55, 0.42, 0.28, 0.25))
		draw_rect(Rect2(pos.x - 4, pos.y - 15, 100, 4), Color(0.55, 0.42, 0.28, 0.25))

	func _draw_garden_sign(pos: Vector2, _text: String) -> void:
		# Post
		draw_rect(Rect2(pos.x - 3, pos.y, 6, 50), Color(0.5, 0.4, 0.28, 0.4))
		# Sign board
		draw_rect(Rect2(pos.x - 25, pos.y - 20, 50, 22), Color(0.6, 0.5, 0.32, 0.45))
		draw_rect(Rect2(pos.x - 25, pos.y - 20, 50, 22), Color(0.45, 0.38, 0.25, 0.3), false, 1.5)
		# Simple text line decoration
		draw_rect(Rect2(pos.x - 15, pos.y - 13, 30, 3), Color(0.35, 0.3, 0.2, 0.3))
		draw_rect(Rect2(pos.x - 10, pos.y - 7, 20, 2), Color(0.35, 0.3, 0.2, 0.2))

	# --- KITCHEN MID ---
	func _draw_kitchen_mid() -> void:
		# Counter surface
		draw_rect(Rect2(-100, 480, 1800, 250), Color(0.6, 0.5, 0.4, 0.35))
		draw_rect(Rect2(-100, 475, 1800, 6), Color(0.65, 0.55, 0.42, 0.5))

		# Pots and pans on shelf
		_draw_pot(Vector2(150, 460), 1.0)
		_draw_pot(Vector2(800, 465), 0.8)
		_draw_pan(Vector2(450, 470), 1.0)
		_draw_pan(Vector2(1100, 465), 0.85)

		# Hanging utensils
		_draw_hanging_ladle(Vector2(300, 300))
		_draw_hanging_whisk(Vector2(500, 310))
		_draw_hanging_spatula(Vector2(700, 295))
		_draw_hanging_ladle(Vector2(1000, 305))
		_draw_hanging_whisk(Vector2(1200, 300))
		_draw_hanging_spatula(Vector2(1400, 310))

		# Recipe book
		_draw_recipe_book(Vector2(600, 460))

		# Salt and pepper shakers
		_draw_shaker(Vector2(350, 458), Color(0.9, 0.9, 0.88), true)
		_draw_shaker(Vector2(380, 460), Color(0.2, 0.2, 0.2), false)

		_draw_shaker(Vector2(950, 460), Color(0.9, 0.9, 0.88), true)
		_draw_shaker(Vector2(980, 462), Color(0.2, 0.2, 0.2), false)

		# Microwave outline
		_draw_microwave(Vector2(1300, 400))

		# Stacked plates
		_draw_plates(Vector2(200, 470))
		_draw_plates(Vector2(1050, 468))

	func _draw_pot(pos: Vector2, s: float) -> void:
		# Body
		draw_rect(Rect2(pos.x - 20 * s, pos.y - 25 * s, 40 * s, 25 * s), Color(0.45, 0.45, 0.5, 0.45))
		# Rim
		draw_rect(Rect2(pos.x - 22 * s, pos.y - 27 * s, 44 * s, 4 * s), Color(0.5, 0.5, 0.55, 0.5))
		# Handles
		draw_rect(Rect2(pos.x - 28 * s, pos.y - 20 * s, 8 * s, 5 * s), Color(0.4, 0.4, 0.45, 0.4))
		draw_rect(Rect2(pos.x + 20 * s, pos.y - 20 * s, 8 * s, 5 * s), Color(0.4, 0.4, 0.45, 0.4))
		# Lid handle
		draw_circle(pos + Vector2(0, -30) * s, 4 * s, Color(0.35, 0.35, 0.4, 0.45))
		# Lid
		var lid_pts := PackedVector2Array([
			pos + Vector2(-22, -27) * s,
			pos + Vector2(22, -27) * s,
			pos + Vector2(15, -32) * s,
			pos + Vector2(-15, -32) * s,
		])
		draw_colored_polygon(lid_pts, Color(0.48, 0.48, 0.52, 0.4))

	func _draw_pan(pos: Vector2, s: float) -> void:
		# Pan body
		draw_rect(Rect2(pos.x - 18 * s, pos.y - 8 * s, 36 * s, 10 * s), Color(0.35, 0.35, 0.38, 0.45))
		# Pan base (rounded)
		var base_pts: PackedVector2Array = []
		for i in range(13):
			var angle: float = float(i) / 12.0 * PI
			base_pts.append(pos + Vector2(cos(angle) * 18 * s - 0 * s, sin(angle) * 6 * s + 2 * s))
		draw_colored_polygon(base_pts, Color(0.35, 0.35, 0.38, 0.4))
		# Handle
		draw_rect(Rect2(pos.x + 18 * s, pos.y - 5 * s, 30 * s, 5 * s), Color(0.3, 0.28, 0.25, 0.45))
		draw_circle(pos + Vector2(50, -3) * s, 3 * s, Color(0.25, 0.22, 0.2, 0.4))

	func _draw_hanging_ladle(pos: Vector2) -> void:
		var col := Color(0.5, 0.48, 0.45, 0.35)
		# Hook
		draw_arc(pos, 5, 0, PI, 8, col, 2.0)
		# Handle
		draw_line(pos + Vector2(0, 5), pos + Vector2(0, 55), col, 2.5)
		# Ladle bowl
		var bowl_pts: PackedVector2Array = []
		for i in range(13):
			var angle: float = float(i) / 12.0 * PI
			bowl_pts.append(pos + Vector2(cos(angle) * 10 + 0, sin(angle) * 8 + 60))
		draw_colored_polygon(bowl_pts, Color(0.48, 0.46, 0.43, 0.4))

	func _draw_hanging_whisk(pos: Vector2) -> void:
		var col := Color(0.5, 0.48, 0.45, 0.35)
		draw_arc(pos, 5, 0, PI, 8, col, 2.0)
		# Handle
		draw_line(pos + Vector2(0, 5), pos + Vector2(0, 35), col, 2.5)
		# Whisk wires
		for i in range(5):
			var offset: float = float(i - 2) * 4.0
			var ctrl := Vector2(pos.x + offset * 2, pos.y + 50)
			draw_line(pos + Vector2(0, 35), ctrl, col, 1.5)
			draw_line(ctrl, pos + Vector2(0, 65), col, 1.5)

	func _draw_hanging_spatula(pos: Vector2) -> void:
		var col := Color(0.5, 0.48, 0.45, 0.35)
		draw_arc(pos, 5, 0, PI, 8, col, 2.0)
		draw_line(pos + Vector2(0, 5), pos + Vector2(0, 40), col, 2.5)
		# Spatula head
		draw_rect(Rect2(pos.x - 8, pos.y + 40, 16, 25), Color(0.48, 0.46, 0.43, 0.4))
		# Slots in spatula
		draw_rect(Rect2(pos.x - 4, pos.y + 45, 8, 3), Color(0.55, 0.52, 0.48, 0.2))
		draw_rect(Rect2(pos.x - 4, pos.y + 52, 8, 3), Color(0.55, 0.52, 0.48, 0.2))

	func _draw_recipe_book(pos: Vector2) -> void:
		# Book body
		draw_rect(Rect2(pos.x - 18, pos.y - 25, 36, 25), Color(0.65, 0.25, 0.2, 0.45))
		# Pages (white edge)
		draw_rect(Rect2(pos.x - 16, pos.y - 23, 32, 21), Color(0.95, 0.92, 0.85, 0.35))
		# Spine
		draw_rect(Rect2(pos.x - 18, pos.y - 25, 3, 25), Color(0.55, 0.2, 0.15, 0.5))
		# Page lines
		for i in range(3):
			var y: float = pos.y - 18.0 + float(i) * 6.0
			draw_line(Vector2(pos.x - 10, y), Vector2(pos.x + 12, y), Color(0.6, 0.55, 0.5, 0.2), 1.0)

	func _draw_shaker(pos: Vector2, col: Color, is_salt: bool) -> void:
		# Body
		draw_rect(Rect2(pos.x - 6, pos.y - 22, 12, 22), Color(col.r, col.g, col.b, 0.45))
		# Cap
		var cap_pts := PackedVector2Array([
			pos + Vector2(-6, -22),
			pos + Vector2(6, -22),
			pos + Vector2(4, -28),
			pos + Vector2(-4, -28),
		])
		draw_colored_polygon(cap_pts, Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, 0.45))
		# Holes on top
		if is_salt:
			draw_circle(pos + Vector2(-1, -27), 1, Color(0.3, 0.3, 0.3, 0.3))
			draw_circle(pos + Vector2(1, -26), 1, Color(0.3, 0.3, 0.3, 0.3))
		else:
			for i in range(3):
				draw_circle(pos + Vector2(float(i - 1) * 2, -27), 0.8, Color(0.8, 0.8, 0.8, 0.3))

	func _draw_microwave(pos: Vector2) -> void:
		# Body
		draw_rect(Rect2(pos.x - 45, pos.y - 35, 90, 70), Color(0.55, 0.55, 0.58, 0.4))
		# Door glass
		draw_rect(Rect2(pos.x - 38, pos.y - 28, 55, 52), Color(0.25, 0.28, 0.3, 0.3))
		draw_rect(Rect2(pos.x - 36, pos.y - 26, 51, 48), Color(0.15, 0.18, 0.2, 0.2))
		# Control panel
		draw_rect(Rect2(pos.x + 22, pos.y - 25, 18, 45), Color(0.5, 0.5, 0.52, 0.35))
		# Buttons
		draw_circle(pos + Vector2(31, -15), 3, Color(0.4, 0.6, 0.4, 0.4))
		draw_circle(pos + Vector2(31, -5), 3, Color(0.6, 0.4, 0.4, 0.4))
		draw_rect(Rect2(pos.x + 25, pos.y + 5, 12, 6), Color(0.3, 0.5, 0.3, 0.3))
		# Handle
		draw_rect(Rect2(pos.x + 17, pos.y - 15, 3, 25), Color(0.45, 0.45, 0.48, 0.45))

	func _draw_plates(pos: Vector2) -> void:
		# Stack of plates (ellipses)
		for i in range(4):
			var y: float = pos.y - float(i) * 4.0
			var col := Color(0.92, 0.9, 0.85, 0.35 - float(i) * 0.03)
			# Plate as oval
			var pts: PackedVector2Array = []
			for j in range(20):
				var angle: float = float(j) / 19.0 * TAU
				pts.append(Vector2(pos.x + cos(angle) * 18, y + sin(angle) * 5))
			if pts.size() >= 3:
				draw_colored_polygon(pts, col)
			# Rim highlight
			draw_arc(Vector2(pos.x, y), 18, PI, TAU, 12, Color(0.8, 0.78, 0.72, 0.2), 1.0)

	# --- FRIDGE MID ---
	func _draw_fridge_mid() -> void:
		# Fridge floor
		draw_rect(Rect2(-100, 500, 1800, 200), Color(0.72, 0.82, 0.92, 0.25))

		# Frozen vegetables in ice blocks
		_draw_frozen_veggie(Vector2(100, 480), Color(0.3, 0.6, 0.2, 0.4), "round")
		_draw_frozen_veggie(Vector2(400, 485), Color(1.0, 0.5, 0.15, 0.4), "long")
		_draw_frozen_veggie(Vector2(750, 478), Color(0.8, 0.2, 0.15, 0.4), "round")
		_draw_frozen_veggie(Vector2(1100, 482), Color(0.3, 0.7, 0.3, 0.4), "long")
		_draw_frozen_veggie(Vector2(1400, 480), Color(0.9, 0.8, 0.2, 0.4), "round")

		# Milk carton
		_draw_milk_carton(Vector2(250, 470))
		_draw_milk_carton(Vector2(900, 475))

		# Frozen juice boxes
		_draw_juice_box(Vector2(550, 475), Color(1.0, 0.6, 0.2, 0.4))
		_draw_juice_box(Vector2(1000, 478), Color(0.7, 0.2, 0.5, 0.4))
		_draw_juice_box(Vector2(1300, 472), Color(0.3, 0.6, 0.8, 0.4))

		# Ice cream containers
		_draw_ice_cream(Vector2(350, 465), Color(0.9, 0.7, 0.8, 0.4))
		_draw_ice_cream(Vector2(850, 470), Color(0.6, 0.4, 0.25, 0.4))
		_draw_ice_cream(Vector2(1200, 468), Color(0.95, 0.9, 0.7, 0.4))

		# Frost patterns on edges
		_draw_frost_edge(Vector2(-50, 450), 1700)
		_draw_frost_edge(Vector2(-50, 500), 1700)

		# Condensation drops
		for i in range(25):
			var x: float = float(i) * 65.0 + 20.0
			var y: float = 440.0 + fmod(float(i) * 23.0, 60.0)
			_draw_water_drop(Vector2(x, y))

	func _draw_frozen_veggie(pos: Vector2, col: Color, shape: String) -> void:
		# Ice block around veggie
		draw_rect(Rect2(pos.x - 18, pos.y - 28, 36, 28), Color(0.8, 0.9, 1.0, 0.2))
		draw_rect(Rect2(pos.x - 18, pos.y - 28, 36, 28), Color(0.7, 0.85, 0.95, 0.15), false, 1.5)
		# Veggie inside
		if shape == "round":
			draw_circle(pos + Vector2(0, -14), 10, col)
			draw_circle(pos + Vector2(0, -14), 4, Color(col.r + 0.1, col.g + 0.1, col.b + 0.1, col.a * 0.8))
		else:
			draw_rect(Rect2(pos.x - 4, pos.y - 25, 8, 20), col)
			# Leaf top
			draw_circle(pos + Vector2(0, -25), 5, Color(0.2, 0.5, 0.15, 0.35))
		# Frost on ice block
		draw_circle(pos + Vector2(-10, -22), 3, Color(1, 1, 1, 0.15))
		draw_circle(pos + Vector2(8, -8), 2, Color(1, 1, 1, 0.12))

	func _draw_milk_carton(pos: Vector2) -> void:
		# Body
		draw_rect(Rect2(pos.x - 14, pos.y - 45, 28, 45), Color(0.95, 0.95, 0.98, 0.4))
		# Top fold
		var top_pts := PackedVector2Array([
			pos + Vector2(-14, -45),
			pos + Vector2(14, -45),
			pos + Vector2(5, -55),
			pos + Vector2(-5, -55),
		])
		draw_colored_polygon(top_pts, Color(0.9, 0.9, 0.95, 0.4))
		# Label area
		draw_rect(Rect2(pos.x - 10, pos.y - 35, 20, 20), Color(0.3, 0.5, 0.8, 0.3))
		# "MILK" decoration lines
		draw_rect(Rect2(pos.x - 6, pos.y - 30, 12, 3), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(pos.x - 4, pos.y - 24, 8, 2), Color(1, 1, 1, 0.2))
		# Frost coating
		draw_rect(Rect2(pos.x - 14, pos.y - 45, 28, 8), Color(0.85, 0.92, 1.0, 0.15))

	func _draw_juice_box(pos: Vector2, col: Color) -> void:
		# Box body
		draw_rect(Rect2(pos.x - 10, pos.y - 30, 20, 30), col)
		# Lighter front face
		draw_rect(Rect2(pos.x - 8, pos.y - 28, 16, 26), Color(col.r + 0.1, col.g + 0.1, col.b + 0.1, col.a))
		# Straw hole
		draw_circle(pos + Vector2(3, -30), 2, Color(0.2, 0.2, 0.2, 0.3))
		# Straw
		draw_line(pos + Vector2(3, -30), pos + Vector2(5, -42), Color(0.9, 0.9, 0.2, 0.4), 1.5)
		# Frost
		draw_rect(Rect2(pos.x - 10, pos.y - 5, 20, 5), Color(0.85, 0.92, 1.0, 0.2))
		# Label lines
		draw_rect(Rect2(pos.x - 5, pos.y - 20, 10, 2), Color(1, 1, 1, 0.2))

	func _draw_ice_cream(pos: Vector2, col: Color) -> void:
		# Container (rounded rectangle shape)
		draw_rect(Rect2(pos.x - 22, pos.y - 22, 44, 22), col)
		# Lid
		draw_rect(Rect2(pos.x - 24, pos.y - 26, 48, 5), Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, col.a))
		# Lid handle
		draw_rect(Rect2(pos.x - 5, pos.y - 29, 10, 4), Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a))
		# Label decoration
		draw_rect(Rect2(pos.x - 15, pos.y - 18, 30, 10), Color(col.r + 0.1, col.g + 0.05, col.b + 0.05, col.a * 0.7))
		# Frost coating
		draw_circle(pos + Vector2(-15, -15), 4, Color(0.9, 0.95, 1.0, 0.15))
		draw_circle(pos + Vector2(12, -10), 3, Color(0.9, 0.95, 1.0, 0.12))

	func _draw_frost_edge(pos: Vector2, width: float) -> void:
		for i in range(int(width / 20)):
			var x: float = pos.x + float(i) * 20.0
			var size: float = 3.0 + fmod(float(i) * 7.0, 5.0)
			draw_circle(Vector2(x, pos.y), size, Color(0.9, 0.95, 1.0, 0.1))
			# Tiny crystal arms
			if i % 3 == 0:
				draw_line(
					Vector2(x, pos.y - size),
					Vector2(x, pos.y - size - 4),
					Color(0.85, 0.92, 1.0, 0.08), 1.0
				)

	func _draw_water_drop(pos: Vector2) -> void:
		# Teardrop shape
		draw_circle(pos, 2.5, Color(0.7, 0.82, 0.95, 0.2))
		draw_circle(pos + Vector2(0, -1), 1, Color(0.85, 0.92, 1.0, 0.25))
		# Trail
		draw_line(pos, pos + Vector2(0, 6), Color(0.7, 0.82, 0.95, 0.08), 1.0)
