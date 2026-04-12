extends ParallaxBackground

## Phase 3 ULTRA detailed multi-biome parallax background for Stupid Cucumber
## Biomes: GARDEN (0), KITCHEN (1), FRIDGE (2)

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

		# Gradient sky (20 horizontal strips)
		var rect_pos := Vector2(-1000, -600)
		var rect_size := Vector2(4000, 1600)
		var steps: int = 20
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

	# ---- GARDEN SKY ----
	func _draw_garden_sky() -> void:
		# === Faint rainbow arc ===
		var rainbow_center := Vector2(800, 200)
		var rainbow_colors: Array[Color] = [
			Color(0.9, 0.1, 0.1, 0.06), Color(0.9, 0.5, 0.0, 0.06),
			Color(0.9, 0.9, 0.0, 0.06), Color(0.1, 0.8, 0.1, 0.06),
			Color(0.1, 0.5, 0.9, 0.06), Color(0.3, 0.1, 0.7, 0.06),
			Color(0.6, 0.1, 0.8, 0.06),
		]
		for band_i in range(7):
			var r: float = 420.0 - float(band_i) * 14.0
			draw_arc(rainbow_center, r, PI * 0.15, PI * 0.85, 48, rainbow_colors[band_i], 12.0)

		# === Large detailed sun ===
		var sun_pos := Vector2(400, -280)
		# Outer glow rings
		draw_circle(sun_pos, 120, Color(1.0, 0.95, 0.4, 0.03))
		draw_circle(sun_pos, 100, Color(1.0, 0.95, 0.4, 0.05))
		draw_circle(sun_pos, 80, Color(1.0, 0.95, 0.5, 0.08))
		# Orange ring
		draw_circle(sun_pos, 60, Color(1.0, 0.75, 0.3, 0.2))
		# Yellow core layers
		draw_circle(sun_pos, 50, Color(1.0, 0.92, 0.45, 0.5))
		draw_circle(sun_pos, 42, Color(1.0, 0.95, 0.55, 0.7))
		draw_circle(sun_pos, 35, Color(1.0, 0.97, 0.65, 0.9))
		draw_circle(sun_pos, 28, Color(1.0, 0.98, 0.75, 0.95))
		# 8 radial rays with glow
		for i in range(8):
			var angle: float = float(i) * TAU / 8.0
			var dir := Vector2(cos(angle), sin(angle))
			# Ray core
			var from: Vector2 = sun_pos + dir * 48
			var to: Vector2 = sun_pos + dir * 95
			draw_line(from, to, Color(1.0, 0.92, 0.4, 0.35), 4.0)
			# Ray glow sides
			var perp := Vector2(-dir.y, dir.x)
			draw_line(from + perp * 3, to + perp * 6, Color(1.0, 0.9, 0.4, 0.1), 3.0)
			draw_line(from - perp * 3, to - perp * 6, Color(1.0, 0.9, 0.4, 0.1), 3.0)
			# Tapered tip glow
			draw_circle(to, 8, Color(1.0, 0.95, 0.5, 0.08))

		# === 6 fluffy clouds with shadows ===
		_draw_fluffy_cloud(Vector2(80, -200), 1.0)
		_draw_fluffy_cloud(Vector2(450, -340), 0.75)
		_draw_fluffy_cloud(Vector2(700, -180), 1.3)
		_draw_fluffy_cloud(Vector2(950, -310), 0.9)
		_draw_fluffy_cloud(Vector2(1200, -220), 1.1)
		_draw_fluffy_cloud(Vector2(1450, -350), 0.65)

		# === 3 colorful butterflies ===
		_draw_butterfly(Vector2(250, -150), Color(1.0, 0.35, 0.55), Color(0.9, 0.6, 0.8))
		_draw_butterfly(Vector2(700, -280), Color(0.3, 0.5, 1.0), Color(0.5, 0.8, 1.0))
		_draw_butterfly(Vector2(1100, -200), Color(1.0, 0.8, 0.15), Color(1.0, 0.6, 0.2))

		# === V-shaped birds ===
		_draw_bird_v(Vector2(300, -380))
		_draw_bird_v(Vector2(650, -420))
		_draw_bird_v(Vector2(1050, -400))

	func _draw_fluffy_cloud(pos: Vector2, s: float) -> void:
		# Gray undershadow layer
		var shadow := Color(0.75, 0.78, 0.85, 0.25)
		draw_circle(pos + Vector2(3, 10) * s, 30 * s, shadow)
		draw_circle(pos + Vector2(25, 12) * s, 24 * s, shadow)
		draw_circle(pos + Vector2(-18, 13) * s, 22 * s, shadow)
		draw_circle(pos + Vector2(12, 14) * s, 20 * s, shadow)
		draw_circle(pos + Vector2(-5, 15) * s, 18 * s, shadow)
		# Main cloud body (5+ overlapping circles)
		var col := Color(1, 1, 1, 0.88)
		var col_light := Color(1, 1, 1, 0.92)
		draw_circle(pos, 30 * s, col)
		draw_circle(pos + Vector2(24, -5) * s, 24 * s, col_light)
		draw_circle(pos + Vector2(-22, 3) * s, 22 * s, col)
		draw_circle(pos + Vector2(12, 8) * s, 20 * s, col)
		draw_circle(pos + Vector2(-10, -14) * s, 26 * s, col_light)
		draw_circle(pos + Vector2(34, 4) * s, 17 * s, col)
		draw_circle(pos + Vector2(-30, -4) * s, 16 * s, col)
		# Bright highlight on top
		draw_circle(pos + Vector2(-6, -18) * s, 14 * s, Color(1, 1, 1, 0.95))

	func _draw_butterfly(pos: Vector2, col_main: Color, col_accent: Color) -> void:
		# Body (elongated)
		draw_line(pos + Vector2(0, -4), pos + Vector2(0, 5), Color(0.15, 0.1, 0.08), 2.0)
		# Antennae
		draw_line(pos + Vector2(0, -4), pos + Vector2(-4, -9), Color(0.2, 0.15, 0.1, 0.7), 1.0)
		draw_line(pos + Vector2(0, -4), pos + Vector2(4, -9), Color(0.2, 0.15, 0.1, 0.7), 1.0)
		draw_circle(pos + Vector2(-4, -9), 1, Color(0.2, 0.15, 0.1, 0.6))
		draw_circle(pos + Vector2(4, -9), 1, Color(0.2, 0.15, 0.1, 0.6))
		# Upper wings (larger)
		var uw_col := Color(col_main.r, col_main.g, col_main.b, 0.7)
		draw_circle(pos + Vector2(-7, -3), 6, uw_col)
		draw_circle(pos + Vector2(7, -3), 6, uw_col)
		# Wing pattern circles
		draw_circle(pos + Vector2(-8, -4), 3, Color(col_accent.r, col_accent.g, col_accent.b, 0.5))
		draw_circle(pos + Vector2(8, -4), 3, Color(col_accent.r, col_accent.g, col_accent.b, 0.5))
		# Pattern dots
		draw_circle(pos + Vector2(-9, -2), 1.2, Color(1, 1, 1, 0.5))
		draw_circle(pos + Vector2(9, -2), 1.2, Color(1, 1, 1, 0.5))
		# Lower wings (smaller)
		var lw_col := Color(col_main.r, col_main.g, col_main.b, 0.55)
		draw_circle(pos + Vector2(-5, 3), 4.5, lw_col)
		draw_circle(pos + Vector2(5, 3), 4.5, lw_col)
		# Lower wing accent dots
		draw_circle(pos + Vector2(-5, 4), 1.5, Color(col_accent.r, col_accent.g, col_accent.b, 0.4))
		draw_circle(pos + Vector2(5, 4), 1.5, Color(col_accent.r, col_accent.g, col_accent.b, 0.4))

	func _draw_bird_v(pos: Vector2) -> void:
		var col := Color(0.15, 0.15, 0.25, 0.4)
		draw_line(pos, pos + Vector2(-10, -7), col, 2.0)
		draw_line(pos, pos + Vector2(10, -7), col, 2.0)
		# Body dot
		draw_circle(pos, 1.5, col)

	# ---- KITCHEN SKY ----
	func _draw_kitchen_sky() -> void:
		# Ceiling line
		draw_line(Vector2(-1000, -420), Vector2(4000, -420), Color(0.7, 0.63, 0.52, 0.35), 4.0)
		draw_line(Vector2(-1000, -418), Vector2(4000, -418), Color(0.75, 0.68, 0.58, 0.15), 2.0)

		# === Tile pattern on upper wall (subtle grid) ===
		for row in range(5):
			for col_i in range(25):
				var x: float = float(col_i) * 80.0 - 200.0
				var y: float = float(row) * 60.0 - 400.0
				draw_rect(Rect2(x, y, 76, 56), Color(0.88, 0.84, 0.78, 0.05))
				draw_rect(Rect2(x, y, 76, 56), Color(0.72, 0.66, 0.56, 0.04), false, 1.0)

		# === 3 hanging lamps ===
		_draw_hanging_lamp(Vector2(200, -320), 1.0)
		_draw_hanging_lamp(Vector2(750, -340), 0.85)
		_draw_hanging_lamp(Vector2(1300, -310), 1.1)

		# === Small window with light beam ===
		_draw_sky_window(Vector2(1050, -340))

		# === Clock on wall ===
		_draw_wall_clock(Vector2(500, -340))

		# === Steam wisps ===
		_draw_steam_wisp(Vector2(300, -100), 1.0)
		_draw_steam_wisp(Vector2(850, -140), 0.75)
		_draw_steam_wisp(Vector2(1400, -110), 0.9)

	func _draw_hanging_lamp(pos: Vector2, s: float) -> void:
		# Cord
		draw_line(pos + Vector2(0, -200), pos, Color(0.3, 0.28, 0.25, 0.5), 2.0)
		# Shade (trapezoid)
		var shade := PackedVector2Array([
			pos + Vector2(-20, 0) * s,
			pos + Vector2(20, 0) * s,
			pos + Vector2(14, -18) * s,
			pos + Vector2(-14, -18) * s,
		])
		draw_colored_polygon(shade, Color(0.82, 0.74, 0.5, 0.7))
		# Shade rim highlight
		draw_line(pos + Vector2(-20, 0) * s, pos + Vector2(20, 0) * s, Color(0.9, 0.82, 0.6, 0.4), 1.5)
		# Shade inner dark
		var shade_inner := PackedVector2Array([
			pos + Vector2(-16, -1) * s,
			pos + Vector2(16, -1) * s,
			pos + Vector2(12, -14) * s,
			pos + Vector2(-12, -14) * s,
		])
		draw_colored_polygon(shade_inner, Color(0.75, 0.67, 0.45, 0.3))
		# Bulb
		draw_circle(pos + Vector2(0, 8) * s, 7 * s, Color(1.0, 0.97, 0.75, 0.9))
		draw_circle(pos + Vector2(0, 8) * s, 5 * s, Color(1.0, 0.99, 0.9, 0.95))
		# Warm glow below
		draw_circle(pos + Vector2(0, 8) * s, 35 * s, Color(1.0, 0.95, 0.7, 0.06))
		draw_circle(pos + Vector2(0, 8) * s, 55 * s, Color(1.0, 0.93, 0.65, 0.03))
		draw_circle(pos + Vector2(0, 8) * s, 80 * s, Color(1.0, 0.9, 0.6, 0.015))

	func _draw_sky_window(pos: Vector2) -> void:
		# Window frame
		draw_rect(Rect2(pos.x - 40, pos.y - 35, 80, 70), Color(0.6, 0.52, 0.4, 0.45))
		# Glass panes
		draw_rect(Rect2(pos.x - 35, pos.y - 30, 32, 27), Color(0.82, 0.88, 1.0, 0.22))
		draw_rect(Rect2(pos.x + 3, pos.y - 30, 32, 27), Color(0.82, 0.88, 1.0, 0.22))
		draw_rect(Rect2(pos.x - 35, pos.y + 3, 32, 27), Color(0.78, 0.84, 0.95, 0.18))
		draw_rect(Rect2(pos.x + 3, pos.y + 3, 32, 27), Color(0.78, 0.84, 0.95, 0.18))
		# Cross bar
		draw_rect(Rect2(pos.x - 2, pos.y - 30, 4, 60), Color(0.55, 0.48, 0.38, 0.5))
		draw_rect(Rect2(pos.x - 35, pos.y - 2, 70, 4), Color(0.55, 0.48, 0.38, 0.5))
		# Curtain left
		var curtain_l := PackedVector2Array([
			pos + Vector2(-40, -35), pos + Vector2(-25, -35),
			pos + Vector2(-30, 35), pos + Vector2(-40, 35),
		])
		draw_colored_polygon(curtain_l, Color(0.7, 0.35, 0.3, 0.2))
		# Curtain right
		var curtain_r := PackedVector2Array([
			pos + Vector2(25, -35), pos + Vector2(40, -35),
			pos + Vector2(40, 35), pos + Vector2(30, 35),
		])
		draw_colored_polygon(curtain_r, Color(0.7, 0.35, 0.3, 0.2))
		# Light beam from window
		var beam := PackedVector2Array([
			pos + Vector2(-30, 35), pos + Vector2(30, 35),
			pos + Vector2(60, 250), pos + Vector2(-60, 250),
		])
		draw_colored_polygon(beam, Color(1.0, 0.97, 0.85, 0.025))

	func _draw_wall_clock(pos: Vector2) -> void:
		# Clock body
		draw_circle(pos, 22, Color(0.85, 0.78, 0.65, 0.4))
		draw_circle(pos, 20, Color(0.95, 0.92, 0.88, 0.5))
		# Rim
		draw_arc(pos, 21, 0, TAU, 32, Color(0.6, 0.52, 0.4, 0.4), 2.0)
		# Hour markers (12 ticks)
		for i in range(12):
			var angle: float = float(i) * TAU / 12.0 - PI / 2.0
			var outer: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 18
			var inner: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 15
			draw_line(inner, outer, Color(0.3, 0.25, 0.2, 0.4), 1.5)
		# Hour hand
		var h_angle: float = -PI / 4.0
		draw_line(pos, pos + Vector2(cos(h_angle), sin(h_angle)) * 11, Color(0.2, 0.18, 0.15, 0.5), 2.5)
		# Minute hand
		var m_angle: float = PI / 6.0
		draw_line(pos, pos + Vector2(cos(m_angle), sin(m_angle)) * 15, Color(0.2, 0.18, 0.15, 0.45), 1.8)
		# Center dot
		draw_circle(pos, 2, Color(0.3, 0.25, 0.2, 0.5))

	func _draw_steam_wisp(pos: Vector2, s: float) -> void:
		for i in range(7):
			var offset := Vector2(sin(float(i) * 1.3) * 18, float(i) * -22) * s
			var r: float = (10.0 - float(i) * 1.0) * s
			var a: float = 0.06 - float(i) * 0.007
			draw_circle(pos + offset, r, Color(1, 1, 1, a))

	# ---- FRIDGE SKY ----
	func _draw_fridge_sky() -> void:
		# === Fridge light glow from above ===
		draw_circle(Vector2(800, -500), 300, Color(0.9, 0.95, 1.0, 0.04))
		draw_circle(Vector2(800, -500), 200, Color(0.92, 0.96, 1.0, 0.06))
		draw_rect(Rect2(-200, -520, 2000, 30), Color(0.95, 0.97, 1.0, 0.08))

		# === 10 frost crystals ===
		_draw_frost_crystal(Vector2(80, -280), 1.0)
		_draw_frost_crystal(Vector2(250, -380), 0.7)
		_draw_frost_crystal(Vector2(420, -220), 0.9)
		_draw_frost_crystal(Vector2(600, -350), 1.2)
		_draw_frost_crystal(Vector2(780, -260), 0.6)
		_draw_frost_crystal(Vector2(950, -400), 1.1)
		_draw_frost_crystal(Vector2(1100, -300), 0.8)
		_draw_frost_crystal(Vector2(1250, -220), 1.0)
		_draw_frost_crystal(Vector2(1380, -360), 0.65)
		_draw_frost_crystal(Vector2(1520, -280), 0.85)

		# === 3 fog layers (slightly wavy translucent white) ===
		for layer_i in range(3):
			var base_y: float = -150.0 + float(layer_i) * 140.0
			var alpha: float = 0.045 - float(layer_i) * 0.01
			var pts: PackedVector2Array = []
			for xi in range(41):
				var x: float = -200.0 + float(xi) * 50.0
				var wave: float = sin(float(xi) * 0.4 + float(layer_i) * 1.5) * 12.0
				pts.append(Vector2(x, base_y + wave))
			for xi in range(40, -1, -1):
				var x: float = -200.0 + float(xi) * 50.0
				var wave: float = sin(float(xi) * 0.4 + float(layer_i) * 1.5) * 12.0
				pts.append(Vector2(x, base_y + wave + 60.0))
			if pts.size() >= 3:
				draw_colored_polygon(pts, Color(0.88, 0.93, 1.0, alpha))

		# === Ice sparkles (cross-shaped shines) ===
		var sparkle_positions: Array[Vector2] = [
			Vector2(100, -180), Vector2(280, -340), Vector2(440, -150),
			Vector2(590, -390), Vector2(730, -210), Vector2(870, -370),
			Vector2(1010, -240), Vector2(1160, -310), Vector2(1320, -180),
			Vector2(1470, -350), Vector2(180, -420), Vector2(680, -440),
		]
		for sp in sparkle_positions:
			var sparkle_a: float = 0.35
			draw_circle(sp, 2, Color(1, 1, 1, sparkle_a))
			draw_line(sp + Vector2(-5, 0), sp + Vector2(5, 0), Color(1, 1, 1, sparkle_a * 0.6), 1.0)
			draw_line(sp + Vector2(0, -5), sp + Vector2(0, 5), Color(1, 1, 1, sparkle_a * 0.6), 1.0)
			# Diagonal sparkle arms
			draw_line(sp + Vector2(-3, -3), sp + Vector2(3, 3), Color(1, 1, 1, sparkle_a * 0.3), 1.0)
			draw_line(sp + Vector2(3, -3), sp + Vector2(-3, 3), Color(1, 1, 1, sparkle_a * 0.3), 1.0)

		# === Condensation drops ===
		for i in range(15):
			var x: float = float(i) * 110.0 + 30.0
			var y: float = -100.0 + fmod(float(i) * 47.0, 200.0)
			draw_circle(Vector2(x, y), 3, Color(0.75, 0.85, 0.95, 0.12))
			draw_circle(Vector2(x, y - 1), 1.5, Color(0.9, 0.95, 1.0, 0.18))
			# Trail below
			draw_line(Vector2(x, y + 3), Vector2(x, y + 12), Color(0.75, 0.85, 0.95, 0.06), 1.0)

	func _draw_frost_crystal(pos: Vector2, s: float) -> void:
		var col := Color(0.88, 0.94, 1.0, 0.3)
		var col_light := Color(0.92, 0.96, 1.0, 0.2)
		# 6-pointed star with branches and sub-branches
		for i in range(6):
			var angle: float = float(i) * TAU / 6.0
			var dir := Vector2(cos(angle), sin(angle))
			var tip: Vector2 = pos + dir * 18 * s
			# Main arm
			draw_line(pos, tip, col, 1.8 * s)
			# Sub-branches at 1/3 and 2/3 distance
			var perp := Vector2(-dir.y, dir.x)
			for j in range(1, 3):
				var branch_pos: Vector2 = pos + dir * (6.0 * float(j)) * s
				var branch_len: float = (7.0 - float(j) * 2.0) * s
				draw_line(branch_pos, branch_pos + perp * branch_len, col_light, 1.2 * s)
				draw_line(branch_pos, branch_pos - perp * branch_len, col_light, 1.2 * s)
			# Tiny tip sub-branch
			var near_tip: Vector2 = pos + dir * 14 * s
			draw_line(near_tip, near_tip + perp * 4 * s, col_light, 0.8 * s)
			draw_line(near_tip, near_tip - perp * 4 * s, col_light, 0.8 * s)
		# Center dot
		draw_circle(pos, 2 * s, col)


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

	# ---- GARDEN FAR ----
	func _draw_garden_far() -> void:
		# === Distant purple mountains with snow caps ===
		_draw_purple_mountain(Vector2(100, 350), 350, 280, Color(0.42, 0.3, 0.52, 0.3))
		_draw_purple_mountain(Vector2(550, 370), 300, 240, Color(0.38, 0.28, 0.48, 0.25))
		_draw_purple_mountain(Vector2(1000, 340), 380, 300, Color(0.4, 0.3, 0.5, 0.28))
		_draw_purple_mountain(Vector2(1400, 360), 320, 260, Color(0.36, 0.26, 0.46, 0.25))

		# === 2-3 birds in sky ===
		_draw_bird(Vector2(300, 180))
		_draw_bird(Vector2(700, 140))
		_draw_bird(Vector2(1150, 160))

		# === 4 rolling hills with smooth curves and grass texture ===
		_draw_grassy_hill(Vector2(150, 480), 320, 200, Color(0.3, 0.58, 0.22, 0.55))
		_draw_grassy_hill(Vector2(550, 495), 280, 180, Color(0.25, 0.52, 0.18, 0.55))
		_draw_grassy_hill(Vector2(950, 475), 340, 210, Color(0.32, 0.6, 0.24, 0.55))
		_draw_grassy_hill(Vector2(1350, 490), 300, 190, Color(0.28, 0.55, 0.2, 0.55))

		# === 5 broccoli trees: thick trunk with bark lines, 6-8 canopy circles ===
		_draw_broccoli_tree(Vector2(100, 340), 1.2)
		_draw_broccoli_tree(Vector2(380, 330), 1.0)
		_draw_broccoli_tree(Vector2(700, 350), 0.85)
		_draw_broccoli_tree(Vector2(1050, 335), 1.3)
		_draw_broccoli_tree(Vector2(1400, 345), 1.0)

		# === Flower patches: clusters of 3-5 flowers ===
		_draw_flower_cluster(Vector2(200, 440), Color(1.0, 0.3, 0.4), 4)
		_draw_flower_cluster(Vector2(480, 455), Color(0.9, 0.4, 0.7), 5)
		_draw_flower_cluster(Vector2(760, 435), Color(1.0, 0.85, 0.2), 3)
		_draw_flower_cluster(Vector2(1100, 445), Color(0.5, 0.4, 1.0), 4)
		_draw_flower_cluster(Vector2(1350, 440), Color(1.0, 0.55, 0.2), 5)

		# === Fence posts along bottom ===
		for i in range(9):
			var x: float = float(i) * 180.0 + 30.0
			_draw_fence_post(Vector2(x, 520))

	func _draw_purple_mountain(center: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts: PackedVector2Array = []
		for i in range(35):
			var angle: float = PI + float(i) / 34.0 * PI
			var bump: float = sin(float(i) * 0.7) * 12.0
			pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry + bump))
		pts.append(center + Vector2(rx, 350))
		pts.append(center + Vector2(-rx, 350))
		draw_colored_polygon(pts, col)
		# Snow cap (white triangle near top)
		var peak: Vector2 = center + Vector2(0, -ry + 10)
		var snow_pts := PackedVector2Array([
			peak, peak + Vector2(-rx * 0.25, ry * 0.15), peak + Vector2(rx * 0.25, ry * 0.15),
		])
		draw_colored_polygon(snow_pts, Color(1, 1, 1, 0.2))
		# Snow edge highlight
		draw_line(peak + Vector2(-rx * 0.25, ry * 0.15), peak + Vector2(rx * 0.25, ry * 0.15), Color(1, 1, 1, 0.12), 1.5)

	func _draw_grassy_hill(center: Vector2, rx: float, ry: float, col: Color) -> void:
		# Smooth hill polygon with many points
		var pts: PackedVector2Array = []
		for i in range(40):
			var angle: float = PI + float(i) / 39.0 * PI
			pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
		pts.append(center + Vector2(rx, 250))
		pts.append(center + Vector2(-rx, 250))
		draw_colored_polygon(pts, col)
		# Grass texture: small vertical lines at top of hill
		var grass_col := Color(col.r + 0.08, col.g + 0.12, col.b + 0.02, col.a * 0.7)
		for i in range(30):
			var t: float = float(i) / 29.0
			var angle: float = PI + t * PI
			var base: Vector2 = center + Vector2(cos(angle) * rx, sin(angle) * ry)
			var grass_h: float = 6.0 + fmod(float(i) * 3.7, 8.0)
			draw_line(base, base + Vector2(0, -grass_h), grass_col, 1.0)

	func _draw_broccoli_tree(pos: Vector2, s: float) -> void:
		# Thick trunk
		draw_rect(Rect2(pos.x - 7 * s, pos.y, 14 * s, 55 * s), Color(0.5, 0.38, 0.22, 0.5))
		# Bark lines on trunk
		for i in range(4):
			var y: float = pos.y + (8.0 + float(i) * 12.0) * s
			draw_line(Vector2(pos.x - 4 * s, y), Vector2(pos.x + 3 * s, y), Color(0.4, 0.3, 0.18, 0.25), 1.0)
		# Bark vertical crack
		draw_line(Vector2(pos.x + 2 * s, pos.y + 5 * s), Vector2(pos.x + 1 * s, pos.y + 40 * s), Color(0.4, 0.3, 0.18, 0.2), 1.0)
		# Canopy: 8 overlapping circles of different greens
		var greens: Array[Color] = [
			Color(0.2, 0.5, 0.15, 0.5), Color(0.25, 0.55, 0.18, 0.5),
			Color(0.18, 0.48, 0.14, 0.48), Color(0.28, 0.58, 0.2, 0.47),
			Color(0.22, 0.52, 0.16, 0.5), Color(0.3, 0.6, 0.22, 0.45),
			Color(0.24, 0.54, 0.17, 0.48), Color(0.26, 0.56, 0.19, 0.46),
		]
		var offsets: Array[Vector2] = [
			Vector2(0, -10), Vector2(16, -2), Vector2(-14, 0),
			Vector2(8, -18), Vector2(-8, -15), Vector2(20, -10),
			Vector2(-18, -8), Vector2(4, -22),
		]
		var sizes: Array[float] = [22.0, 18.0, 17.0, 16.0, 15.0, 14.0, 13.0, 19.0]
		for i in range(8):
			draw_circle(pos + offsets[i] * s, sizes[i] * s, greens[i])

	func _draw_flower_cluster(center: Vector2, col: Color, count: int) -> void:
		for i in range(count):
			var offset := Vector2(float(i - count / 2) * 16.0, sin(float(i)) * 6.0)
			var flower_pos: Vector2 = center + offset
			# Stem
			draw_line(flower_pos + Vector2(0, 12), flower_pos, Color(0.22, 0.5, 0.15, 0.5), 1.5)
			# Leaves on stem
			draw_circle(flower_pos + Vector2(3, 7), 2.5, Color(0.25, 0.55, 0.18, 0.4))
			draw_circle(flower_pos + Vector2(-3, 9), 2.0, Color(0.25, 0.55, 0.18, 0.35))
			# 5-petal flower
			var petal_col := Color(col.r, col.g, col.b, 0.55)
			for p in range(5):
				var angle: float = float(p) * TAU / 5.0
				var petal_p: Vector2 = flower_pos + Vector2(cos(angle), sin(angle)) * 4.0
				draw_circle(petal_p, 3.0, petal_col)
			# Center dot
			draw_circle(flower_pos, 2.0, Color(1.0, 0.95, 0.3, 0.7))

	func _draw_fence_post(pos: Vector2) -> void:
		var col := Color(0.55, 0.42, 0.28, 0.35)
		# Vertical post
		draw_rect(Rect2(pos.x - 4, pos.y - 42, 8, 47), col)
		# Pointed top
		var top_pts := PackedVector2Array([
			pos + Vector2(-4, -42),
			pos + Vector2(4, -42),
			pos + Vector2(0, -52),
		])
		draw_colored_polygon(top_pts, col)
		# Wood grain lines
		draw_line(Vector2(pos.x - 1, pos.y - 38), Vector2(pos.x - 1, pos.y), Color(0.48, 0.36, 0.22, 0.2), 0.8)
		# Horizontal rails
		draw_rect(Rect2(pos.x - 4, pos.y - 32, 180, 4), Color(0.55, 0.42, 0.28, 0.22))
		draw_rect(Rect2(pos.x - 4, pos.y - 16, 180, 4), Color(0.55, 0.42, 0.28, 0.22))

	func _draw_bird(pos: Vector2) -> void:
		var col := Color(0.2, 0.2, 0.3, 0.35)
		draw_line(pos, pos + Vector2(-9, -7), col, 1.8)
		draw_line(pos, pos + Vector2(9, -7), col, 1.8)

	# ---- KITCHEN FAR ----
	func _draw_kitchen_far() -> void:
		# === Kitchen counter silhouette ===
		draw_rect(Rect2(-100, 400, 1800, 300), Color(0.55, 0.45, 0.35, 0.4))
		# Counter edge detail
		draw_rect(Rect2(-100, 395, 1800, 5), Color(0.65, 0.55, 0.42, 0.5))
		draw_rect(Rect2(-100, 400, 1800, 2), Color(0.5, 0.4, 0.3, 0.3))

		# === Tiled backsplash (grid of small squares with grout lines) ===
		for row in range(7):
			for col_i in range(22):
				var x: float = float(col_i) * 80.0 - 60.0
				var y: float = float(row) * 50.0 + 60.0
				# Tile body
				draw_rect(Rect2(x + 2, y + 2, 76, 46), Color(0.88, 0.83, 0.76, 0.08))
				# Grout line (darker border)
				draw_rect(Rect2(x, y, 80, 50), Color(0.72, 0.66, 0.56, 0.05), false, 1.0)
				# Subtle shine on some tiles
				if (row + col_i) % 5 == 0:
					draw_rect(Rect2(x + 5, y + 5, 20, 3), Color(1, 1, 1, 0.03))

		# === Shelves with jars/bottles ===
		_draw_shelf(Vector2(80, 200), 320)
		_draw_shelf(Vector2(650, 180), 280)
		_draw_shelf(Vector2(1150, 210), 300)

		# === 4-5 jars on shelves: glass body, lid, colored contents, label ===
		_draw_jar(Vector2(110, 185), Color(0.8, 0.25, 0.2, 0.4), 0.9)
		_draw_jar(Vector2(180, 180), Color(0.2, 0.6, 0.25, 0.4), 1.0)
		_draw_jar(Vector2(250, 185), Color(0.9, 0.75, 0.15, 0.4), 0.85)
		_draw_jar(Vector2(330, 182), Color(0.6, 0.2, 0.5, 0.35), 0.75)

		_draw_jar(Vector2(680, 165), Color(0.3, 0.5, 0.7, 0.35), 0.9)
		_draw_jar(Vector2(760, 160), Color(0.8, 0.5, 0.15, 0.4), 1.1)
		_draw_jar(Vector2(840, 165), Color(0.4, 0.7, 0.25, 0.35), 0.8)

		_draw_jar(Vector2(1180, 195), Color(0.7, 0.25, 0.25, 0.35), 1.0)
		_draw_jar(Vector2(1270, 190), Color(0.25, 0.4, 0.7, 0.35), 0.9)
		_draw_jar(Vector2(1370, 195), Color(0.8, 0.7, 0.25, 0.4), 0.95)

		# === Spice rack: wooden frame, 6-8 small bottles ===
		_draw_spice_rack(Vector2(460, 250))
		_draw_spice_rack(Vector2(1000, 270))

		# === Window with curtains, bright light ===
		_draw_window(Vector2(1480, 130))

		# === Knife block silhouette ===
		_draw_knife_block(Vector2(560, 380))

		# === Hanging pots ===
		_draw_hanging_pot(Vector2(300, 120))
		_draw_hanging_pot(Vector2(850, 110))

	func _draw_shelf(pos: Vector2, width: float) -> void:
		draw_rect(Rect2(pos.x, pos.y, width, 7), Color(0.5, 0.4, 0.3, 0.5))
		# Wood grain
		draw_line(Vector2(pos.x + 5, pos.y + 3), Vector2(pos.x + width - 5, pos.y + 3), Color(0.45, 0.35, 0.25, 0.15), 1.0)
		# Brackets
		var bracket_col := Color(0.45, 0.35, 0.28, 0.4)
		draw_rect(Rect2(pos.x + 15, pos.y + 7, 4, 18), bracket_col)
		draw_rect(Rect2(pos.x + width - 19, pos.y + 7, 4, 18), bracket_col)
		# Bracket diagonals
		draw_line(Vector2(pos.x + 17, pos.y + 7), Vector2(pos.x + 30, pos.y + 22), Color(0.42, 0.33, 0.25, 0.25), 1.0)
		draw_line(Vector2(pos.x + width - 17, pos.y + 7), Vector2(pos.x + width - 30, pos.y + 22), Color(0.42, 0.33, 0.25, 0.25), 1.0)

	func _draw_jar(pos: Vector2, col: Color, s: float) -> void:
		# Glass body
		draw_rect(Rect2(pos.x - 11 * s, pos.y - 30 * s, 22 * s, 30 * s), Color(0.85, 0.88, 0.9, 0.2))
		# Colored contents (lower portion)
		draw_rect(Rect2(pos.x - 9 * s, pos.y - 20 * s, 18 * s, 20 * s), col)
		# Jar neck
		draw_rect(Rect2(pos.x - 7 * s, pos.y - 36 * s, 14 * s, 6 * s), Color(0.85, 0.88, 0.9, 0.18))
		# Lid
		draw_rect(Rect2(pos.x - 9 * s, pos.y - 40 * s, 18 * s, 5 * s), Color(0.6, 0.55, 0.5, 0.5))
		# Label (white rectangle on body)
		draw_rect(Rect2(pos.x - 7 * s, pos.y - 18 * s, 14 * s, 10 * s), Color(0.95, 0.92, 0.88, 0.25))
		# Label text lines
		draw_rect(Rect2(pos.x - 5 * s, pos.y - 16 * s, 10 * s, 2 * s), Color(0.4, 0.35, 0.3, 0.2))
		draw_rect(Rect2(pos.x - 4 * s, pos.y - 12 * s, 8 * s, 1.5 * s), Color(0.4, 0.35, 0.3, 0.15))
		# Glass highlight
		draw_rect(Rect2(pos.x - 8 * s, pos.y - 28 * s, 3 * s, 22 * s), Color(1, 1, 1, 0.08))

	func _draw_spice_rack(pos: Vector2) -> void:
		# Wooden frame
		draw_rect(Rect2(pos.x, pos.y, 140, 6), Color(0.5, 0.4, 0.3, 0.4))
		draw_rect(Rect2(pos.x - 3, pos.y - 45, 3, 51), Color(0.5, 0.4, 0.3, 0.35))
		draw_rect(Rect2(pos.x + 140, pos.y - 45, 3, 51), Color(0.5, 0.4, 0.3, 0.35))
		# Top shelf
		draw_rect(Rect2(pos.x, pos.y - 42, 140, 4), Color(0.48, 0.38, 0.28, 0.35))
		# 7 small spice bottles
		for i in range(7):
			var x: float = pos.x + 8 + float(i) * 19
			var h: float = 16.0 + fmod(float(i) * 5.0, 10.0)
			var bottle_col := Color(0.7 + fmod(float(i) * 0.1, 0.2), 0.55, 0.35 + fmod(float(i) * 0.08, 0.15), 0.3)
			draw_rect(Rect2(x, pos.y - h, 12, h), bottle_col)
			# Cap
			draw_rect(Rect2(x + 1, pos.y - h - 4, 10, 4), Color(0.55, 0.45, 0.35, 0.35))

	func _draw_window(pos: Vector2) -> void:
		# Frame
		draw_rect(Rect2(pos.x - 55, pos.y - 65, 110, 130), Color(0.6, 0.52, 0.4, 0.45))
		# Glass panes
		draw_rect(Rect2(pos.x - 48, pos.y - 58, 43, 55), Color(0.85, 0.9, 1.0, 0.22))
		draw_rect(Rect2(pos.x + 5, pos.y - 58, 43, 55), Color(0.85, 0.9, 1.0, 0.22))
		draw_rect(Rect2(pos.x - 48, pos.y + 5, 43, 55), Color(0.8, 0.85, 0.95, 0.17))
		draw_rect(Rect2(pos.x + 5, pos.y + 5, 43, 55), Color(0.8, 0.85, 0.95, 0.17))
		# Cross bars
		draw_rect(Rect2(pos.x - 2, pos.y - 58, 4, 118), Color(0.55, 0.48, 0.38, 0.5))
		draw_rect(Rect2(pos.x - 48, pos.y - 2, 96, 4), Color(0.55, 0.48, 0.38, 0.5))
		# Curtains
		var curtain_col := Color(0.7, 0.35, 0.28, 0.2)
		var cl := PackedVector2Array([
			pos + Vector2(-55, -65), pos + Vector2(-38, -65),
			pos + Vector2(-42, 65), pos + Vector2(-55, 65),
		])
		draw_colored_polygon(cl, curtain_col)
		var cr := PackedVector2Array([
			pos + Vector2(38, -65), pos + Vector2(55, -65),
			pos + Vector2(55, 65), pos + Vector2(42, 65),
		])
		draw_colored_polygon(cr, curtain_col)
		# Light glow
		draw_circle(pos, 80, Color(1.0, 0.97, 0.85, 0.04))

	func _draw_knife_block(pos: Vector2) -> void:
		# Block body
		draw_rect(Rect2(pos.x - 15, pos.y - 40, 30, 40), Color(0.45, 0.35, 0.25, 0.45))
		# Knife handles sticking out
		draw_rect(Rect2(pos.x - 10, pos.y - 55, 5, 18), Color(0.3, 0.25, 0.2, 0.4))
		draw_rect(Rect2(pos.x - 2, pos.y - 60, 5, 22), Color(0.32, 0.27, 0.22, 0.4))
		draw_rect(Rect2(pos.x + 6, pos.y - 52, 5, 15), Color(0.28, 0.23, 0.18, 0.4))
		# Metal glint on top knife
		draw_line(Vector2(pos.x, pos.y - 60), Vector2(pos.x + 1, pos.y - 50), Color(0.8, 0.8, 0.85, 0.15), 1.0)

	func _draw_hanging_pot(pos: Vector2) -> void:
		# Hook
		draw_arc(pos, 6, 0, PI, 8, Color(0.4, 0.38, 0.35, 0.35), 2.0)
		# Chain
		draw_line(pos + Vector2(0, 6), pos + Vector2(0, 25), Color(0.4, 0.38, 0.35, 0.3), 1.5)
		# Pot circle
		draw_circle(pos + Vector2(0, 40), 18, Color(0.4, 0.38, 0.35, 0.3))
		draw_circle(pos + Vector2(0, 40), 15, Color(0.35, 0.33, 0.3, 0.25))
		# Handle
		draw_line(pos + Vector2(-18, 38), pos + Vector2(-25, 38), Color(0.38, 0.35, 0.32, 0.3), 2.0)
		draw_line(pos + Vector2(18, 38), pos + Vector2(25, 38), Color(0.38, 0.35, 0.32, 0.3), 2.0)

	# ---- FRIDGE FAR ----
	func _draw_fridge_far() -> void:
		# === Ice shelf background ===
		draw_rect(Rect2(-100, 350, 1800, 350), Color(0.7, 0.8, 0.9, 0.25))

		# === Metal shelves with brackets (3 levels) ===
		_draw_metal_shelf(Vector2(-50, 180), 1700)
		_draw_metal_shelf(Vector2(-50, 320), 1700)
		_draw_metal_shelf(Vector2(-50, 460), 1700)

		# === Ice formations: jagged triangular shapes ===
		_draw_ice_formation(Vector2(100, 500), 1.2)
		_draw_ice_formation(Vector2(450, 510), 0.9)
		_draw_ice_formation(Vector2(800, 490), 1.4)
		_draw_ice_formation(Vector2(1150, 505), 1.0)
		_draw_ice_formation(Vector2(1450, 495), 1.1)

		# === Icicles hanging from shelves ===
		for shelf_y in [180, 320]:
			for i in range(20):
				var x: float = float(i) * 85.0 + 10.0
				var length: float = 18.0 + fmod(float(i) * 31.0, 35.0)
				_draw_icicle(Vector2(x, shelf_y + 8), length)

		# === Frozen food boxes on shelves ===
		_draw_frozen_box(Vector2(150, 305), 48, 32, Color(0.5, 0.6, 0.8, 0.3))
		_draw_frozen_box(Vector2(320, 300), 55, 38, Color(0.55, 0.55, 0.75, 0.3))
		_draw_frozen_box(Vector2(550, 308), 42, 28, Color(0.48, 0.62, 0.78, 0.3))
		_draw_frozen_box(Vector2(780, 302), 50, 35, Color(0.52, 0.58, 0.82, 0.3))
		_draw_frozen_box(Vector2(1000, 306), 46, 30, Color(0.5, 0.63, 0.76, 0.3))
		_draw_frozen_box(Vector2(1250, 300), 52, 36, Color(0.53, 0.6, 0.8, 0.3))
		_draw_frozen_box(Vector2(1450, 304), 44, 32, Color(0.48, 0.58, 0.78, 0.3))

		# === Ice cube mountains (stacked translucent squares) ===
		_draw_ice_cubes(Vector2(250, 450))
		_draw_ice_cubes(Vector2(650, 460))
		_draw_ice_cubes(Vector2(1050, 445))
		_draw_ice_cubes(Vector2(1380, 455))

		# === Thermometer showing cold ===
		_draw_thermometer(Vector2(1520, 230))

		# === Frozen meat/fish silhouettes in back ===
		_draw_frozen_silhouette(Vector2(400, 165), "meat")
		_draw_frozen_silhouette(Vector2(900, 160), "fish")
		_draw_frozen_silhouette(Vector2(1300, 168), "meat")

	func _draw_metal_shelf(pos: Vector2, width: float) -> void:
		# Main shelf surface
		draw_rect(Rect2(pos.x, pos.y, width, 8), Color(0.78, 0.82, 0.88, 0.4))
		# Underside shadow
		draw_rect(Rect2(pos.x, pos.y + 8, width, 3), Color(0.6, 0.68, 0.78, 0.2))
		# Metal shine on top
		draw_rect(Rect2(pos.x, pos.y, width, 2), Color(0.9, 0.92, 0.95, 0.2))
		# Brackets
		for i in range(6):
			var bx: float = pos.x + float(i) * (width / 5.0)
			draw_rect(Rect2(bx, pos.y + 8, 3, 16), Color(0.7, 0.75, 0.82, 0.3))
			draw_rect(Rect2(bx + 3, pos.y + 20, 10, 3), Color(0.7, 0.75, 0.82, 0.25))
		# Frost on shelf edge
		for i in range(int(width / 25)):
			var x: float = pos.x + float(i) * 25.0
			draw_circle(Vector2(x + 12, pos.y + 3), 4, Color(0.9, 0.95, 1.0, 0.12))

	func _draw_ice_formation(center: Vector2, s: float) -> void:
		var base_col := Color(0.72, 0.86, 0.96, 0.3)
		var edge_col := Color(0.88, 0.94, 1.0, 0.2)
		# Multiple jagged triangular shapes
		var pts: PackedVector2Array = []
		pts.append(center + Vector2(-60, 0) * s)
		pts.append(center + Vector2(-40, -35) * s)
		pts.append(center + Vector2(-20, -15) * s)
		pts.append(center + Vector2(-5, -55) * s)
		pts.append(center + Vector2(10, -25) * s)
		pts.append(center + Vector2(30, -45) * s)
		pts.append(center + Vector2(50, -10) * s)
		pts.append(center + Vector2(60, 0) * s)
		draw_colored_polygon(pts, base_col)
		# White edge highlights
		for i in range(pts.size() - 1):
			draw_line(pts[i], pts[i + 1], edge_col, 1.5)

	func _draw_icicle(pos: Vector2, length: float) -> void:
		var pts := PackedVector2Array([
			pos + Vector2(-4, 0),
			pos + Vector2(4, 0),
			pos + Vector2(0, length),
		])
		draw_colored_polygon(pts, Color(0.8, 0.9, 1.0, 0.3))
		# Shine line
		draw_line(pos + Vector2(-1, 2), pos + Vector2(-1, length * 0.6), Color(1, 1, 1, 0.15), 1.0)
		# Drip at tip
		draw_circle(pos + Vector2(0, length), 1.5, Color(0.85, 0.92, 1.0, 0.2))

	func _draw_frozen_box(pos: Vector2, w: float, h: float, col: Color) -> void:
		# Box body
		draw_rect(Rect2(pos.x, pos.y - h, w, h), col)
		# Frost overlay (top portion)
		draw_rect(Rect2(pos.x, pos.y - h, w, h * 0.3), Color(0.9, 0.95, 1.0, 0.12))
		# Label area
		draw_rect(Rect2(pos.x + 4, pos.y - h * 0.65, w - 8, h * 0.3), Color(0.6, 0.7, 0.85, 0.15))
		# Tiny label text lines
		draw_rect(Rect2(pos.x + 6, pos.y - h * 0.58, w * 0.5, 2), Color(0.5, 0.6, 0.75, 0.15))
		draw_rect(Rect2(pos.x + 6, pos.y - h * 0.48, w * 0.35, 1.5), Color(0.5, 0.6, 0.75, 0.1))
		# Ice crystal on corner
		draw_circle(Vector2(pos.x + w - 5, pos.y - h + 5), 3, Color(0.92, 0.96, 1.0, 0.15))

	func _draw_ice_cubes(pos: Vector2) -> void:
		var col := Color(0.75, 0.88, 0.98, 0.22)
		var highlight := Color(0.9, 0.95, 1.0, 0.15)
		# Bottom row
		draw_rect(Rect2(pos.x, pos.y - 28, 32, 28), col)
		draw_rect(Rect2(pos.x + 2, pos.y - 26, 5, 18), highlight)
		draw_rect(Rect2(pos.x + 38, pos.y - 24, 28, 24), col)
		draw_rect(Rect2(pos.x + 40, pos.y - 22, 4, 14), highlight)
		# Middle row
		draw_rect(Rect2(pos.x + 8, pos.y - 52, 30, 26), col)
		draw_rect(Rect2(pos.x + 10, pos.y - 50, 5, 16), highlight)
		draw_rect(Rect2(pos.x + 42, pos.y - 46, 24, 22), col)
		draw_rect(Rect2(pos.x + 44, pos.y - 44, 4, 13), highlight)
		# Top
		draw_rect(Rect2(pos.x + 16, pos.y - 72, 26, 22), col)
		draw_rect(Rect2(pos.x + 18, pos.y - 70, 5, 14), highlight)

	func _draw_thermometer(pos: Vector2) -> void:
		# Body tube
		draw_rect(Rect2(pos.x - 3, pos.y - 40, 6, 55), Color(0.9, 0.92, 0.95, 0.4))
		# Bulb at bottom
		draw_circle(pos + Vector2(0, 20), 8, Color(0.9, 0.92, 0.95, 0.45))
		# Mercury (blue for cold)
		draw_rect(Rect2(pos.x - 1.5, pos.y - 10, 3, 28), Color(0.3, 0.5, 0.9, 0.5))
		draw_circle(pos + Vector2(0, 20), 5, Color(0.3, 0.5, 0.9, 0.55))
		# Temperature marks
		for i in range(6):
			var y: float = pos.y - 35.0 + float(i) * 10.0
			draw_line(Vector2(pos.x + 4, y), Vector2(pos.x + 8, y), Color(0.5, 0.55, 0.6, 0.3), 1.0)

	func _draw_frozen_silhouette(pos: Vector2, kind: String) -> void:
		var col := Color(0.55, 0.5, 0.48, 0.2)
		if kind == "fish":
			# Fish body (oval-ish)
			var pts: PackedVector2Array = []
			for i in range(20):
				var angle: float = float(i) / 19.0 * TAU
				pts.append(pos + Vector2(cos(angle) * 30, sin(angle) * 12))
			if pts.size() >= 3:
				draw_colored_polygon(pts, col)
			# Tail
			var tail := PackedVector2Array([
				pos + Vector2(28, 0), pos + Vector2(42, -10), pos + Vector2(42, 10),
			])
			draw_colored_polygon(tail, col)
			# Eye
			draw_circle(pos + Vector2(-18, -3), 2, Color(0.4, 0.38, 0.35, 0.2))
		else:
			# Meat chunk
			draw_rect(Rect2(pos.x - 25, pos.y - 15, 50, 30), col)
			# Bone shape
			draw_rect(Rect2(pos.x - 8, pos.y - 18, 4, 36), Color(0.7, 0.68, 0.65, 0.15))
			draw_circle(pos + Vector2(-6, -18), 4, Color(0.7, 0.68, 0.65, 0.12))
			draw_circle(pos + Vector2(-6, 18), 4, Color(0.7, 0.68, 0.65, 0.12))
		# Frost overlay
		draw_circle(pos + Vector2(-10, -5), 5, Color(0.9, 0.95, 1.0, 0.1))
		draw_circle(pos + Vector2(12, 3), 4, Color(0.9, 0.95, 1.0, 0.08))


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

	# ---- GARDEN MID ----
	func _draw_garden_mid() -> void:
		# Ground fill
		draw_rect(Rect2(-100, 530, 1800, 200), Color(0.35, 0.55, 0.2, 0.3))

		# === Stone path sections ===
		_draw_stone_path(Vector2(100, 540), 180)
		_draw_stone_path(Vector2(600, 545), 150)
		_draw_stone_path(Vector2(1100, 538), 200)

		# === Giant mushrooms: thick stem, texture, dome cap, spots, gills ===
		_draw_mushroom(Vector2(200, 490), 1.2)
		_draw_mushroom(Vector2(650, 500), 0.85)
		_draw_mushroom(Vector2(1050, 485), 1.0)
		_draw_mushroom(Vector2(1450, 495), 0.75)

		# === Carrot patches: orange body, lines, green leafy top ===
		_draw_carrot(Vector2(100, 520), 1.0)
		_draw_carrot(Vector2(350, 525), 0.75)
		_draw_carrot(Vector2(700, 518), 0.9)
		_draw_carrot(Vector2(950, 522), 0.65)
		_draw_carrot(Vector2(1250, 520), 1.1)
		_draw_carrot(Vector2(1500, 525), 0.8)

		# === Tomato bushes: green bush with 3-4 red tomatoes, leaves ===
		_draw_tomato_bush(Vector2(450, 510))
		_draw_tomato_bush(Vector2(850, 515))
		_draw_tomato_bush(Vector2(1300, 508))

		# === 3 tall sunflowers: thick stem, leaves, petals, seed center ===
		_draw_sunflower(Vector2(170, 465), 1.0)
		_draw_sunflower(Vector2(550, 470), 0.85)
		_draw_sunflower(Vector2(1000, 460), 1.15)

		# === Garden signs ===
		_draw_garden_sign(Vector2(300, 480), "Carrots")
		_draw_garden_sign(Vector2(1150, 485), "Veggies")

		# === Watering can ===
		_draw_watering_can(Vector2(780, 520))

	func _draw_stone_path(pos: Vector2, width: float) -> void:
		var stone_col := Color(0.6, 0.58, 0.52, 0.25)
		var stones: int = int(width / 28.0)
		for i in range(stones):
			var x: float = pos.x + float(i) * 28.0 + fmod(float(i) * 7.0, 8.0)
			var y: float = pos.y + fmod(float(i) * 11.0, 10.0) - 5.0
			var w: float = 22.0 + fmod(float(i) * 5.0, 8.0)
			var h: float = 14.0 + fmod(float(i) * 3.0, 6.0)
			draw_rect(Rect2(x, y, w, h), stone_col)
			draw_rect(Rect2(x, y, w, h), Color(0.5, 0.48, 0.42, 0.12), false, 1.0)

	func _draw_mushroom(pos: Vector2, s: float) -> void:
		# Thick stem
		draw_rect(Rect2(pos.x - 12 * s, pos.y - 28 * s, 24 * s, 35 * s), Color(0.92, 0.88, 0.78, 0.55))
		# Stem texture lines
		for i in range(5):
			var y: float = pos.y - 22.0 * s + float(i) * 8.0 * s
			draw_line(Vector2(pos.x - 8 * s, y), Vector2(pos.x + 6 * s, y), Color(0.85, 0.82, 0.72, 0.25), 1.0)
		# Stem ring
		draw_rect(Rect2(pos.x - 14 * s, pos.y - 5 * s, 28 * s, 3 * s), Color(0.88, 0.84, 0.74, 0.4))
		# Dome cap (semicircle polygon)
		var cap_pts: PackedVector2Array = []
		for i in range(20):
			var angle: float = PI + float(i) / 19.0 * PI
			cap_pts.append(pos + Vector2(0, -28 * s) + Vector2(cos(angle) * 35 * s, sin(angle) * 22 * s))
		draw_colored_polygon(cap_pts, Color(0.82, 0.22, 0.18, 0.55))
		# Cap highlight on top
		var cap_hi: PackedVector2Array = []
		for i in range(12):
			var angle: float = PI + float(i) / 11.0 * PI
			cap_hi.append(pos + Vector2(0, -30 * s) + Vector2(cos(angle) * 28 * s, sin(angle) * 12 * s))
		if cap_hi.size() >= 3:
			draw_colored_polygon(cap_hi, Color(0.88, 0.3, 0.22, 0.3))
		# Spots on cap
		draw_circle(pos + Vector2(-12, -35) * s, 6 * s, Color(1, 1, 1, 0.45))
		draw_circle(pos + Vector2(10, -42) * s, 5 * s, Color(1, 1, 1, 0.45))
		draw_circle(pos + Vector2(-3, -47) * s, 4.5 * s, Color(1, 1, 1, 0.42))
		draw_circle(pos + Vector2(18, -30) * s, 3.5 * s, Color(1, 1, 1, 0.38))
		draw_circle(pos + Vector2(-18, -30) * s, 3 * s, Color(1, 1, 1, 0.35))
		# Underside gills (short vertical lines under cap)
		var gill_col := Color(0.78, 0.65, 0.6, 0.25)
		for i in range(8):
			var gx: float = pos.x + (float(i) - 3.5) * 7.0 * s
			draw_line(Vector2(gx, pos.y - 28 * s), Vector2(gx, pos.y - 22 * s), gill_col, 1.0)

	func _draw_carrot(pos: Vector2, s: float) -> void:
		# Orange triangle body
		var pts := PackedVector2Array([
			pos + Vector2(-10, 0) * s,
			pos + Vector2(10, 0) * s,
			pos + Vector2(0, -58) * s,
		])
		draw_colored_polygon(pts, Color(1.0, 0.55, 0.15, 0.55))
		# Horizontal lines on carrot body
		for i in range(4):
			var y: float = pos.y - (12.0 + float(i) * 10.0) * s
			var half_w: float = (7.0 - float(i) * 1.5) * s
			draw_line(Vector2(pos.x - half_w, y), Vector2(pos.x + half_w, y), Color(0.88, 0.45, 0.1, 0.3), 1.0)
		# Green leafy top: 4-5 fronds
		var leaf_col := Color(0.22, 0.6, 0.18, 0.5)
		var leaf_light := Color(0.28, 0.65, 0.22, 0.4)
		draw_circle(pos + Vector2(0, -58) * s, 8 * s, leaf_col)
		draw_circle(pos + Vector2(7, -63) * s, 6 * s, leaf_light)
		draw_circle(pos + Vector2(-6, -62) * s, 7 * s, leaf_col)
		draw_circle(pos + Vector2(3, -67) * s, 5 * s, leaf_light)
		draw_circle(pos + Vector2(-4, -66) * s, 5.5 * s, leaf_col)

	func _draw_tomato_bush(pos: Vector2) -> void:
		# Bush body (overlapping circles)
		draw_circle(pos + Vector2(0, -14), 24, Color(0.28, 0.52, 0.22, 0.45))
		draw_circle(pos + Vector2(18, -10), 18, Color(0.25, 0.48, 0.2, 0.45))
		draw_circle(pos + Vector2(-16, -8), 17, Color(0.25, 0.5, 0.2, 0.45))
		draw_circle(pos + Vector2(8, -22), 14, Color(0.3, 0.55, 0.24, 0.4))
		# Leaf shapes
		draw_circle(pos + Vector2(-22, -16), 8, Color(0.22, 0.48, 0.18, 0.35))
		draw_circle(pos + Vector2(24, -18), 7, Color(0.22, 0.48, 0.18, 0.35))
		# 4 red tomatoes
		draw_circle(pos + Vector2(-7, -20), 7.5, Color(0.9, 0.18, 0.12, 0.55))
		draw_circle(pos + Vector2(10, -16), 6.5, Color(0.92, 0.22, 0.14, 0.55))
		draw_circle(pos + Vector2(2, -6), 5.5, Color(0.85, 0.15, 0.1, 0.5))
		draw_circle(pos + Vector2(-14, -12), 6.0, Color(0.88, 0.2, 0.12, 0.52))
		# Tomato highlights
		draw_circle(pos + Vector2(-8, -22), 2.2, Color(1, 1, 1, 0.22))
		draw_circle(pos + Vector2(9, -18), 2.0, Color(1, 1, 1, 0.2))
		draw_circle(pos + Vector2(1, -8), 1.8, Color(1, 1, 1, 0.18))
		# Tomato stems (tiny green dots)
		draw_circle(pos + Vector2(-7, -27), 2, Color(0.2, 0.45, 0.15, 0.4))
		draw_circle(pos + Vector2(10, -22), 1.8, Color(0.2, 0.45, 0.15, 0.4))

	func _draw_sunflower(pos: Vector2, s: float) -> void:
		# Thick stem
		draw_line(pos + Vector2(0, 60) * s, pos, Color(0.28, 0.48, 0.18, 0.55), 4.0 * s)
		# Stem texture (darker line)
		draw_line(pos + Vector2(1, 58) * s, pos + Vector2(1, 5) * s, Color(0.22, 0.4, 0.14, 0.2), 1.5 * s)
		# Leaves on stem (two pairs)
		var leaf_col := Color(0.28, 0.55, 0.18, 0.45)
		# Lower leaf pair
		_draw_leaf_shape(pos + Vector2(0, 40) * s, 12 * s, 6 * s, 0.3, leaf_col)
		_draw_leaf_shape(pos + Vector2(0, 40) * s, 12 * s, 6 * s, PI - 0.3, leaf_col)
		# Upper leaf pair
		_draw_leaf_shape(pos + Vector2(0, 22) * s, 10 * s, 5 * s, 0.5, leaf_col)
		_draw_leaf_shape(pos + Vector2(0, 22) * s, 10 * s, 5 * s, PI - 0.5, leaf_col)
		# Large petal ring
		var petal_col := Color(1.0, 0.85, 0.12, 0.55)
		var petal_light := Color(1.0, 0.9, 0.3, 0.5)
		for i in range(14):
			var angle: float = float(i) * TAU / 14.0
			var petal_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 14 * s
			draw_circle(petal_pos, 6 * s, petal_col)
			# Inner petal highlight
			var inner_p: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 10 * s
			draw_circle(inner_p, 3 * s, petal_light)
		# Brown center with seed pattern
		draw_circle(pos, 9 * s, Color(0.45, 0.3, 0.1, 0.6))
		draw_circle(pos, 7 * s, Color(0.55, 0.35, 0.12, 0.55))
		# Seed dots in center
		for i in range(6):
			var angle: float = float(i) * TAU / 6.0
			var dot_pos: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 4 * s
			draw_circle(dot_pos, 1.2 * s, Color(0.35, 0.22, 0.08, 0.4))

	func _draw_leaf_shape(pos: Vector2, length: float, width: float, angle: float, col: Color) -> void:
		var dir := Vector2(cos(angle), sin(angle))
		var perp := Vector2(-dir.y, dir.x)
		var tip: Vector2 = pos + dir * length
		var pts := PackedVector2Array([
			pos,
			pos + dir * length * 0.5 + perp * width,
			tip,
			pos + dir * length * 0.5 - perp * width,
		])
		draw_colored_polygon(pts, col)
		# Leaf vein
		draw_line(pos, tip, Color(col.r - 0.05, col.g - 0.05, col.b - 0.02, col.a * 0.5), 0.8)

	func _draw_garden_sign(pos: Vector2, _text: String) -> void:
		# Wooden post
		draw_rect(Rect2(pos.x - 4, pos.y, 8, 55), Color(0.5, 0.4, 0.28, 0.42))
		# Wood grain
		draw_line(Vector2(pos.x - 1, pos.y + 5), Vector2(pos.x - 1, pos.y + 50), Color(0.45, 0.35, 0.22, 0.15), 0.8)
		# Arrow-shaped sign board
		var sign_pts := PackedVector2Array([
			pos + Vector2(-28, -22),
			pos + Vector2(22, -22),
			pos + Vector2(32, -10),
			pos + Vector2(22, 2),
			pos + Vector2(-28, 2),
		])
		draw_colored_polygon(sign_pts, Color(0.62, 0.52, 0.34, 0.48))
		draw_colored_polygon(sign_pts, Color(0.48, 0.4, 0.28, 0.2))
		# Sign border
		for i in range(sign_pts.size()):
			var next_i: int = (i + 1) % sign_pts.size()
			draw_line(sign_pts[i], sign_pts[next_i], Color(0.42, 0.35, 0.22, 0.3), 1.5)
		# Text line decorations
		draw_rect(Rect2(pos.x - 18, pos.y - 15, 32, 3), Color(0.35, 0.3, 0.2, 0.3))
		draw_rect(Rect2(pos.x - 12, pos.y - 8, 22, 2), Color(0.35, 0.3, 0.2, 0.2))

	func _draw_watering_can(pos: Vector2) -> void:
		# Body (rounded rectangle approximation)
		draw_rect(Rect2(pos.x - 18, pos.y - 22, 36, 22), Color(0.45, 0.55, 0.48, 0.4))
		# Spout
		draw_line(pos + Vector2(18, -18), pos + Vector2(35, -30), Color(0.4, 0.5, 0.43, 0.4), 3.0)
		# Spout head (sprinkle)
		draw_circle(pos + Vector2(35, -30), 5, Color(0.42, 0.52, 0.45, 0.35))
		# Sprinkle holes
		for i in range(3):
			draw_circle(pos + Vector2(33 + float(i) * 2, -31), 0.8, Color(0.3, 0.4, 0.35, 0.25))
		# Handle
		draw_arc(pos + Vector2(0, -22), 14, PI * 0.15, PI * 0.85, 10, Color(0.4, 0.5, 0.43, 0.4), 2.5)
		# Highlight
		draw_rect(Rect2(pos.x - 14, pos.y - 20, 4, 14), Color(0.65, 0.72, 0.65, 0.15))
		# Water drops from spout
		draw_circle(pos + Vector2(36, -25), 1.5, Color(0.5, 0.7, 0.9, 0.25))
		draw_circle(pos + Vector2(34, -22), 1.2, Color(0.5, 0.7, 0.9, 0.2))

	# ---- KITCHEN MID ----
	func _draw_kitchen_mid() -> void:
		# Counter surface
		draw_rect(Rect2(-100, 480, 1800, 250), Color(0.6, 0.5, 0.4, 0.35))
		draw_rect(Rect2(-100, 475, 1800, 6), Color(0.65, 0.55, 0.42, 0.5))
		# Counter edge detail
		draw_rect(Rect2(-100, 481, 1800, 2), Color(0.5, 0.4, 0.32, 0.25))

		# === Cutting board with knife marks ===
		_draw_cutting_board(Vector2(100, 462))

		# === Detailed cooking pot with steam ===
		_draw_pot(Vector2(200, 460), 1.0)
		_draw_pot(Vector2(900, 465), 0.85)

		# === Frying pan ===
		_draw_pan(Vector2(500, 470), 1.0)
		_draw_pan(Vector2(1200, 465), 0.9)

		# === Hanging utensils: ladle, whisk, spatula, rolling pin ===
		_draw_hanging_ladle(Vector2(280, 300))
		_draw_hanging_whisk(Vector2(430, 310))
		_draw_hanging_spatula(Vector2(630, 295))
		_draw_hanging_rolling_pin(Vector2(780, 305))
		_draw_hanging_ladle(Vector2(1050, 300))
		_draw_hanging_whisk(Vector2(1250, 310))
		_draw_hanging_spatula(Vector2(1400, 295))

		# === Recipe book ===
		_draw_recipe_book(Vector2(650, 460))

		# === Salt & pepper shakers with S and P ===
		_draw_shaker(Vector2(370, 458), Color(0.9, 0.9, 0.88), true)
		_draw_shaker(Vector2(400, 460), Color(0.22, 0.22, 0.22), false)
		_draw_shaker(Vector2(1000, 460), Color(0.9, 0.9, 0.88), true)
		_draw_shaker(Vector2(1030, 462), Color(0.22, 0.22, 0.22), false)

		# === Microwave with window, buttons, display ===
		_draw_microwave(Vector2(1380, 400))

		# === Stacked plates ===
		_draw_plates(Vector2(180, 472))
		_draw_plates(Vector2(1100, 468))

		# === Oven mitt hanging ===
		_draw_oven_mitt(Vector2(340, 310))

	func _draw_cutting_board(pos: Vector2) -> void:
		# Board
		draw_rect(Rect2(pos.x - 30, pos.y - 5, 60, 18), Color(0.65, 0.52, 0.35, 0.45))
		# Wood grain
		draw_line(Vector2(pos.x - 25, pos.y + 2), Vector2(pos.x + 25, pos.y + 2), Color(0.58, 0.45, 0.28, 0.2), 1.0)
		draw_line(Vector2(pos.x - 25, pos.y + 7), Vector2(pos.x + 25, pos.y + 7), Color(0.58, 0.45, 0.28, 0.15), 1.0)
		# Knife marks (short diagonal scratches)
		for i in range(5):
			var x: float = pos.x - 18 + float(i) * 10
			draw_line(Vector2(x, pos.y - 2), Vector2(x + 3, pos.y + 4), Color(0.5, 0.4, 0.28, 0.15), 0.8)
		# Handle notch
		draw_rect(Rect2(pos.x + 25, pos.y - 2, 8, 12), Color(0.6, 0.48, 0.32, 0.4))
		draw_circle(Vector2(pos.x + 29, pos.y + 4), 2, Color(0.5, 0.4, 0.28, 0.3))

	func _draw_pot(pos: Vector2, s: float) -> void:
		# Body
		draw_rect(Rect2(pos.x - 22 * s, pos.y - 28 * s, 44 * s, 28 * s), Color(0.45, 0.45, 0.5, 0.48))
		# Body highlight
		draw_rect(Rect2(pos.x - 18 * s, pos.y - 26 * s, 6 * s, 22 * s), Color(0.55, 0.55, 0.6, 0.12))
		# Rim
		draw_rect(Rect2(pos.x - 24 * s, pos.y - 30 * s, 48 * s, 4 * s), Color(0.52, 0.52, 0.57, 0.5))
		# Handles
		draw_rect(Rect2(pos.x - 32 * s, pos.y - 22 * s, 10 * s, 6 * s), Color(0.4, 0.4, 0.45, 0.42))
		draw_rect(Rect2(pos.x + 22 * s, pos.y - 22 * s, 10 * s, 6 * s), Color(0.4, 0.4, 0.45, 0.42))
		# Lid (trapezoid)
		var lid_pts := PackedVector2Array([
			pos + Vector2(-24, -30) * s,
			pos + Vector2(24, -30) * s,
			pos + Vector2(17, -36) * s,
			pos + Vector2(-17, -36) * s,
		])
		draw_colored_polygon(lid_pts, Color(0.48, 0.48, 0.52, 0.42))
		# Lid knob
		draw_circle(pos + Vector2(0, -36) * s, 5 * s, Color(0.38, 0.38, 0.42, 0.48))
		draw_circle(pos + Vector2(0, -36) * s, 3 * s, Color(0.42, 0.42, 0.46, 0.45))
		# Steam wisps from pot
		for i in range(3):
			var sx: float = pos.x + (float(i) - 1.0) * 10.0 * s
			for j in range(4):
				var offset := Vector2(sin(float(j) * 1.2 + float(i)) * 8.0, float(j) * -12.0) * s
				draw_circle(Vector2(sx, pos.y - 40 * s) + offset, (5.0 - float(j) * 0.8) * s, Color(1, 1, 1, 0.04 - float(j) * 0.008))

	func _draw_pan(pos: Vector2, s: float) -> void:
		# Pan body circle
		var base_pts: PackedVector2Array = []
		for i in range(20):
			var angle: float = float(i) / 19.0 * TAU
			base_pts.append(pos + Vector2(cos(angle) * 22 * s, sin(angle) * 8 * s))
		if base_pts.size() >= 3:
			draw_colored_polygon(base_pts, Color(0.35, 0.35, 0.38, 0.45))
		# Pan rim
		draw_arc(pos, 22 * s, 0, TAU, 20, Color(0.4, 0.4, 0.43, 0.3), 1.5)
		# Inner surface highlight
		var inner_pts: PackedVector2Array = []
		for i in range(16):
			var angle: float = float(i) / 15.0 * TAU
			inner_pts.append(pos + Vector2(cos(angle) * 18 * s, sin(angle) * 6 * s - 1 * s))
		if inner_pts.size() >= 3:
			draw_colored_polygon(inner_pts, Color(0.32, 0.32, 0.35, 0.2))
		# Long handle
		draw_rect(Rect2(pos.x + 22 * s, pos.y - 4 * s, 35 * s, 6 * s), Color(0.3, 0.28, 0.25, 0.48))
		# Handle end
		draw_circle(pos + Vector2(58, -1) * s, 4 * s, Color(0.25, 0.22, 0.2, 0.42))
		# Handle rivet
		draw_circle(pos + Vector2(25, -1) * s, 2 * s, Color(0.45, 0.43, 0.4, 0.3))

	func _draw_hanging_ladle(pos: Vector2) -> void:
		var col := Color(0.52, 0.5, 0.47, 0.38)
		# Hook
		draw_arc(pos, 5, 0, PI, 8, col, 2.0)
		# Handle
		draw_line(pos + Vector2(0, 5), pos + Vector2(0, 55), col, 2.5)
		# Ladle bowl (cup shape)
		var bowl_pts: PackedVector2Array = []
		for i in range(14):
			var angle: float = float(i) / 13.0 * PI
			bowl_pts.append(pos + Vector2(cos(angle) * 12 + 0, sin(angle) * 10 + 60))
		if bowl_pts.size() >= 3:
			draw_colored_polygon(bowl_pts, Color(0.5, 0.48, 0.45, 0.42))
		# Bowl highlight
		draw_arc(pos + Vector2(0, 60), 10, PI * 0.1, PI * 0.6, 6, Color(0.6, 0.58, 0.55, 0.15), 1.0)

	func _draw_hanging_whisk(pos: Vector2) -> void:
		var col := Color(0.52, 0.5, 0.47, 0.38)
		draw_arc(pos, 5, 0, PI, 8, col, 2.0)
		# Handle
		draw_line(pos + Vector2(0, 5), pos + Vector2(0, 35), col, 3.0)
		# Whisk wire loops (5 wires)
		for i in range(5):
			var offset: float = float(i - 2) * 4.5
			var ctrl := Vector2(pos.x + offset * 2.2, pos.y + 52)
			draw_line(pos + Vector2(0, 35), ctrl, col, 1.5)
			draw_line(ctrl, pos + Vector2(0, 68), col, 1.5)
		# Bottom gathering point
		draw_circle(pos + Vector2(0, 68), 2, col)

	func _draw_hanging_spatula(pos: Vector2) -> void:
		var col := Color(0.52, 0.5, 0.47, 0.38)
		draw_arc(pos, 5, 0, PI, 8, col, 2.0)
		draw_line(pos + Vector2(0, 5), pos + Vector2(0, 40), col, 2.5)
		# Flat spatula head
		draw_rect(Rect2(pos.x - 9, pos.y + 40, 18, 28), Color(0.5, 0.48, 0.45, 0.42))
		# Slots in spatula
		draw_rect(Rect2(pos.x - 5, pos.y + 45, 10, 3), Color(0.58, 0.55, 0.5, 0.2))
		draw_rect(Rect2(pos.x - 5, pos.y + 52, 10, 3), Color(0.58, 0.55, 0.5, 0.2))
		draw_rect(Rect2(pos.x - 5, pos.y + 59, 10, 3), Color(0.58, 0.55, 0.5, 0.2))
		# Rounded bottom
		draw_circle(Vector2(pos.x, pos.y + 68), 9, Color(0.5, 0.48, 0.45, 0.15))

	func _draw_hanging_rolling_pin(pos: Vector2) -> void:
		var col := Color(0.6, 0.5, 0.38, 0.4)
		draw_arc(pos, 5, 0, PI, 8, Color(0.52, 0.5, 0.47, 0.38), 2.0)
		# String
		draw_line(pos + Vector2(0, 5), pos + Vector2(0, 25), Color(0.52, 0.5, 0.47, 0.35), 1.5)
		# Pin body (horizontal cylinder)
		draw_rect(Rect2(pos.x - 25, pos.y + 25, 50, 12), col)
		# Handles
		draw_rect(Rect2(pos.x - 32, pos.y + 27, 8, 8), Color(0.5, 0.42, 0.32, 0.4))
		draw_rect(Rect2(pos.x + 24, pos.y + 27, 8, 8), Color(0.5, 0.42, 0.32, 0.4))
		# Wood grain
		draw_line(Vector2(pos.x - 20, pos.y + 30), Vector2(pos.x + 20, pos.y + 30), Color(0.52, 0.42, 0.3, 0.15), 0.8)

	func _draw_recipe_book(pos: Vector2) -> void:
		# Open book shape (two pages)
		# Left page
		draw_rect(Rect2(pos.x - 22, pos.y - 28, 22, 28), Color(0.95, 0.92, 0.85, 0.38))
		# Right page
		draw_rect(Rect2(pos.x, pos.y - 28, 22, 28), Color(0.93, 0.9, 0.83, 0.35))
		# Spine
		draw_rect(Rect2(pos.x - 2, pos.y - 28, 4, 28), Color(0.65, 0.25, 0.2, 0.5))
		# Cover edges
		draw_rect(Rect2(pos.x - 24, pos.y - 30, 48, 2), Color(0.6, 0.22, 0.18, 0.45))
		draw_rect(Rect2(pos.x - 24, pos.y, 48, 2), Color(0.6, 0.22, 0.18, 0.45))
		# Page lines (left page)
		for i in range(4):
			var y: float = pos.y - 22.0 + float(i) * 6.0
			draw_line(Vector2(pos.x - 18, y), Vector2(pos.x - 4, y), Color(0.6, 0.55, 0.5, 0.18), 1.0)
		# Page lines (right page)
		for i in range(4):
			var y: float = pos.y - 22.0 + float(i) * 6.0
			draw_line(Vector2(pos.x + 4, y), Vector2(pos.x + 18, y), Color(0.6, 0.55, 0.5, 0.18), 1.0)
		# Page corner fold
		var fold := PackedVector2Array([
			pos + Vector2(22, -28), pos + Vector2(16, -28), pos + Vector2(22, -22),
		])
		draw_colored_polygon(fold, Color(0.88, 0.85, 0.78, 0.3))

	func _draw_shaker(pos: Vector2, col: Color, is_salt: bool) -> void:
		# Cylindrical body
		draw_rect(Rect2(pos.x - 7, pos.y - 24, 14, 24), Color(col.r, col.g, col.b, 0.48))
		# Body highlight
		draw_rect(Rect2(pos.x - 5, pos.y - 22, 3, 18), Color(col.r + 0.1, col.g + 0.1, col.b + 0.1, 0.15))
		# Cap (trapezoid)
		var cap_pts := PackedVector2Array([
			pos + Vector2(-7, -24),
			pos + Vector2(7, -24),
			pos + Vector2(5, -32),
			pos + Vector2(-5, -32),
		])
		draw_colored_polygon(cap_pts, Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, 0.5))
		# Holes on top
		if is_salt:
			draw_circle(pos + Vector2(-2, -30), 1, Color(0.3, 0.3, 0.3, 0.35))
			draw_circle(pos + Vector2(1, -29), 1, Color(0.3, 0.3, 0.3, 0.35))
			draw_circle(pos + Vector2(0, -31), 1, Color(0.3, 0.3, 0.3, 0.3))
			# S letter (two tiny lines)
			draw_line(pos + Vector2(-3, -16), pos + Vector2(3, -16), Color(0.3, 0.3, 0.3, 0.2), 1.0)
			draw_line(pos + Vector2(-3, -12), pos + Vector2(3, -12), Color(0.3, 0.3, 0.3, 0.2), 1.0)
			draw_line(pos + Vector2(-3, -16), pos + Vector2(-3, -14), Color(0.3, 0.3, 0.3, 0.2), 1.0)
			draw_line(pos + Vector2(3, -14), pos + Vector2(3, -12), Color(0.3, 0.3, 0.3, 0.2), 1.0)
		else:
			for i in range(4):
				draw_circle(pos + Vector2(float(i - 1) * 2.5 - 1, -30), 0.8, Color(0.8, 0.8, 0.8, 0.35))
			# P letter
			draw_line(pos + Vector2(-2, -18), pos + Vector2(-2, -10), Color(0.8, 0.8, 0.8, 0.2), 1.0)
			draw_line(pos + Vector2(-2, -18), pos + Vector2(2, -18), Color(0.8, 0.8, 0.8, 0.2), 1.0)
			draw_line(pos + Vector2(2, -18), pos + Vector2(2, -14), Color(0.8, 0.8, 0.8, 0.2), 1.0)
			draw_line(pos + Vector2(2, -14), pos + Vector2(-2, -14), Color(0.8, 0.8, 0.8, 0.2), 1.0)

	func _draw_microwave(pos: Vector2) -> void:
		# Body
		draw_rect(Rect2(pos.x - 50, pos.y - 38, 100, 76), Color(0.55, 0.55, 0.58, 0.42))
		# Body edge highlight
		draw_rect(Rect2(pos.x - 50, pos.y - 38, 100, 2), Color(0.65, 0.65, 0.68, 0.2))
		# Door window
		draw_rect(Rect2(pos.x - 42, pos.y - 30, 60, 56), Color(0.22, 0.25, 0.28, 0.32))
		draw_rect(Rect2(pos.x - 40, pos.y - 28, 56, 52), Color(0.15, 0.18, 0.2, 0.22))
		# Reflection on glass
		draw_line(Vector2(pos.x - 38, pos.y - 26), Vector2(pos.x - 28, pos.y + 18), Color(0.6, 0.62, 0.65, 0.08), 2.0)
		# Control panel
		draw_rect(Rect2(pos.x + 24, pos.y - 28, 22, 52), Color(0.5, 0.5, 0.52, 0.38))
		# Display
		draw_rect(Rect2(pos.x + 27, pos.y - 24, 16, 10), Color(0.2, 0.35, 0.2, 0.35))
		# Display digits (simple lines)
		draw_rect(Rect2(pos.x + 30, pos.y - 21, 4, 2), Color(0.3, 0.7, 0.3, 0.25))
		draw_rect(Rect2(pos.x + 36, pos.y - 21, 4, 2), Color(0.3, 0.7, 0.3, 0.25))
		# Buttons
		draw_circle(pos + Vector2(35, -5), 3.5, Color(0.4, 0.6, 0.4, 0.42))
		draw_circle(pos + Vector2(35, 5), 3.5, Color(0.6, 0.4, 0.4, 0.42))
		draw_rect(Rect2(pos.x + 28, pos.y + 12, 14, 7), Color(0.35, 0.55, 0.35, 0.32))
		# Handle
		draw_rect(Rect2(pos.x + 19, pos.y - 18, 3, 30), Color(0.48, 0.48, 0.52, 0.48))

	func _draw_plates(pos: Vector2) -> void:
		# Stack of 4 plates
		for i in range(4):
			var y: float = pos.y - float(i) * 4.5
			var alpha: float = 0.38 - float(i) * 0.03
			var col := Color(0.92, 0.9, 0.85, alpha)
			# Plate as oval polygon
			var pts: PackedVector2Array = []
			for j in range(24):
				var angle: float = float(j) / 23.0 * TAU
				pts.append(Vector2(pos.x + cos(angle) * 20, y + sin(angle) * 5.5))
			if pts.size() >= 3:
				draw_colored_polygon(pts, col)
			# Rim highlight
			draw_arc(Vector2(pos.x, y), 20, PI, TAU, 14, Color(0.82, 0.8, 0.74, 0.2), 1.0)
			# Inner ring
			draw_arc(Vector2(pos.x, y), 13, 0, TAU, 12, Color(0.85, 0.83, 0.78, 0.1), 0.8)

	func _draw_oven_mitt(pos: Vector2) -> void:
		# Hook
		draw_arc(pos, 4, 0, PI, 6, Color(0.5, 0.48, 0.45, 0.35), 1.5)
		# Mitt body
		draw_rect(Rect2(pos.x - 8, pos.y + 5, 16, 30), Color(0.8, 0.3, 0.25, 0.35))
		# Thumb
		draw_rect(Rect2(pos.x + 8, pos.y + 12, 8, 12), Color(0.78, 0.28, 0.22, 0.32))
		# Cuff
		draw_rect(Rect2(pos.x - 9, pos.y + 32, 18, 8), Color(0.75, 0.25, 0.2, 0.38))
		# Stripe pattern
		draw_line(Vector2(pos.x - 6, pos.y + 15), Vector2(pos.x + 6, pos.y + 15), Color(0.9, 0.5, 0.2, 0.2), 1.5)
		draw_line(Vector2(pos.x - 6, pos.y + 22), Vector2(pos.x + 6, pos.y + 22), Color(0.9, 0.5, 0.2, 0.2), 1.5)
		# Stitching
		draw_rect(Rect2(pos.x - 8, pos.y + 5, 16, 30), Color(0.7, 0.25, 0.2, 0.12), false, 1.0)

	# ---- FRIDGE MID ----
	func _draw_fridge_mid() -> void:
		# Fridge floor
		draw_rect(Rect2(-100, 500, 1800, 200), Color(0.72, 0.82, 0.92, 0.25))

		# === Frozen vegetables in ice blocks ===
		_draw_frozen_veggie(Vector2(80, 480), Color(0.3, 0.6, 0.2, 0.42), "round")
		_draw_frozen_veggie(Vector2(380, 485), Color(1.0, 0.5, 0.15, 0.42), "long")
		_draw_frozen_veggie(Vector2(720, 478), Color(0.8, 0.2, 0.15, 0.42), "round")
		_draw_frozen_veggie(Vector2(1080, 482), Color(0.3, 0.7, 0.3, 0.42), "long")
		_draw_frozen_veggie(Vector2(1420, 480), Color(0.9, 0.8, 0.2, 0.42), "round")

		# === Milk carton with brand label and frost ===
		_draw_milk_carton(Vector2(220, 468))
		_draw_milk_carton(Vector2(920, 472))

		# === Juice boxes with straws ===
		_draw_juice_box(Vector2(500, 475), Color(1.0, 0.6, 0.2, 0.42))
		_draw_juice_box(Vector2(1000, 478), Color(0.7, 0.2, 0.5, 0.42))
		_draw_juice_box(Vector2(1300, 472), Color(0.3, 0.6, 0.8, 0.42))

		# === Ice cream tubs with lid and brand ===
		_draw_ice_cream(Vector2(320, 465), Color(0.9, 0.7, 0.8, 0.42))
		_draw_ice_cream(Vector2(800, 470), Color(0.6, 0.4, 0.25, 0.42))
		_draw_ice_cream(Vector2(1200, 468), Color(0.95, 0.9, 0.7, 0.42))

		# === Frozen pizza box ===
		_draw_frozen_pizza(Vector2(600, 490))

		# === Yogurt cups with spoon ===
		_draw_yogurt_cup(Vector2(150, 492))
		_draw_yogurt_cup(Vector2(1100, 490))

		# === Penguin decoration ===
		_draw_penguin(Vector2(1480, 480))

		# === Frost patterns on edges (fractal-like branching) ===
		_draw_frost_pattern(Vector2(-30, 450), 1650)
		_draw_frost_pattern(Vector2(-30, 498), 1650)

		# === Water droplets with trail lines ===
		for i in range(28):
			var x: float = float(i) * 58.0 + 15.0
			var y: float = 435.0 + fmod(float(i) * 23.0, 65.0)
			_draw_water_drop(Vector2(x, y))

	func _draw_frozen_veggie(pos: Vector2, col: Color, shape: String) -> void:
		# Translucent blue ice block
		draw_rect(Rect2(pos.x - 20, pos.y - 32, 40, 32), Color(0.78, 0.88, 1.0, 0.18))
		draw_rect(Rect2(pos.x - 20, pos.y - 32, 40, 32), Color(0.68, 0.82, 0.95, 0.12), false, 1.5)
		# Ice block inner shine
		draw_rect(Rect2(pos.x - 17, pos.y - 30, 4, 24), Color(0.9, 0.95, 1.0, 0.08))
		# Veggie inside
		if shape == "round":
			# Green shapes inside (peas/broccoli)
			draw_circle(pos + Vector2(-5, -16), 8, col)
			draw_circle(pos + Vector2(6, -14), 7, Color(col.r + 0.05, col.g + 0.05, col.b + 0.05, col.a * 0.9))
			draw_circle(pos + Vector2(0, -20), 6, Color(col.r - 0.03, col.g + 0.08, col.b - 0.02, col.a * 0.85))
			# Highlights
			draw_circle(pos + Vector2(-6, -18), 2, Color(1, 1, 1, 0.12))
		else:
			# Carrot/bean shapes
			draw_rect(Rect2(pos.x - 5, pos.y - 28, 8, 22), col)
			draw_rect(Rect2(pos.x + 5, pos.y - 26, 6, 18), Color(col.r - 0.05, col.g + 0.05, col.b, col.a * 0.9))
			# Leaf top
			draw_circle(pos + Vector2(0, -28), 5, Color(0.2, 0.5, 0.15, 0.35))
		# Frost crystals on ice block
		draw_circle(pos + Vector2(-12, -26), 3.5, Color(1, 1, 1, 0.14))
		draw_circle(pos + Vector2(10, -8), 2.5, Color(1, 1, 1, 0.12))
		draw_circle(pos + Vector2(-8, -6), 2, Color(1, 1, 1, 0.1))

	func _draw_milk_carton(pos: Vector2) -> void:
		# Body
		draw_rect(Rect2(pos.x - 16, pos.y - 48, 32, 48), Color(0.95, 0.95, 0.98, 0.42))
		# Triangle top
		var top_pts := PackedVector2Array([
			pos + Vector2(-16, -48),
			pos + Vector2(16, -48),
			pos + Vector2(6, -60),
			pos + Vector2(-6, -60),
		])
		draw_colored_polygon(top_pts, Color(0.9, 0.9, 0.95, 0.42))
		# Top fold line
		draw_line(pos + Vector2(-6, -60), pos + Vector2(6, -60), Color(0.8, 0.82, 0.88, 0.3), 1.0)
		# Brand label area (blue rectangle)
		draw_rect(Rect2(pos.x - 12, pos.y - 38, 24, 22), Color(0.25, 0.45, 0.8, 0.32))
		# "MILK" text lines
		draw_rect(Rect2(pos.x - 8, pos.y - 34, 16, 3), Color(1, 1, 1, 0.32))
		draw_rect(Rect2(pos.x - 6, pos.y - 28, 12, 2), Color(1, 1, 1, 0.22))
		# Cow spot decoration (tiny dots)
		draw_circle(pos + Vector2(-4, -21), 2, Color(0.2, 0.2, 0.2, 0.12))
		draw_circle(pos + Vector2(5, -23), 1.5, Color(0.2, 0.2, 0.2, 0.1))
		# Frost patches
		draw_rect(Rect2(pos.x - 16, pos.y - 48, 32, 8), Color(0.85, 0.92, 1.0, 0.14))
		draw_circle(pos + Vector2(10, -10), 4, Color(0.88, 0.94, 1.0, 0.1))
		# Body edge highlight
		draw_rect(Rect2(pos.x - 14, pos.y - 46, 3, 40), Color(1, 1, 1, 0.06))

	func _draw_juice_box(pos: Vector2, col: Color) -> void:
		# Box body
		draw_rect(Rect2(pos.x - 12, pos.y - 32, 24, 32), col)
		# Lighter front face
		draw_rect(Rect2(pos.x - 10, pos.y - 30, 20, 28), Color(col.r + 0.1, col.g + 0.1, col.b + 0.1, col.a))
		# Top edge
		draw_rect(Rect2(pos.x - 12, pos.y - 32, 24, 3), Color(col.r - 0.1, col.g - 0.1, col.b - 0.1, col.a * 0.8))
		# Straw hole
		draw_circle(pos + Vector2(4, -32), 2, Color(0.2, 0.2, 0.2, 0.32))
		# Straw sticking out
		draw_line(pos + Vector2(4, -32), pos + Vector2(6, -48), Color(0.9, 0.9, 0.2, 0.42), 1.8)
		# Straw bend
		draw_line(pos + Vector2(6, -48), pos + Vector2(10, -50), Color(0.9, 0.9, 0.2, 0.42), 1.8)
		# Label lines
		draw_rect(Rect2(pos.x - 7, pos.y - 22, 14, 3), Color(1, 1, 1, 0.22))
		draw_rect(Rect2(pos.x - 5, pos.y - 16, 10, 2), Color(1, 1, 1, 0.15))
		# Fruit decoration circle
		draw_circle(pos + Vector2(0, -10), 4, Color(col.r + 0.15, col.g + 0.1, col.b, col.a * 0.6))
		# Frost on bottom
		draw_rect(Rect2(pos.x - 12, pos.y - 5, 24, 5), Color(0.85, 0.92, 1.0, 0.18))

	func _draw_ice_cream(pos: Vector2, col: Color) -> void:
		# Cylinder body
		draw_rect(Rect2(pos.x - 24, pos.y - 24, 48, 24), col)
		# Rounded top edge
		draw_arc(Vector2(pos.x, pos.y - 24), 24, PI, TAU, 12, Color(col.r, col.g, col.b, col.a * 0.3), 2.0)
		# Lid
		draw_rect(Rect2(pos.x - 26, pos.y - 28, 52, 5), Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, col.a))
		# Lid handle knob
		draw_rect(Rect2(pos.x - 6, pos.y - 32, 12, 5), Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a))
		# Brand label
		draw_rect(Rect2(pos.x - 18, pos.y - 20, 36, 14), Color(col.r + 0.1, col.g + 0.05, col.b + 0.05, col.a * 0.7))
		# Label text
		draw_rect(Rect2(pos.x - 12, pos.y - 17, 24, 3), Color(0.2, 0.15, 0.1, 0.2))
		draw_rect(Rect2(pos.x - 8, pos.y - 12, 16, 2), Color(0.2, 0.15, 0.1, 0.15))
		# Frost coating
		draw_circle(pos + Vector2(-18, -18), 5, Color(0.9, 0.95, 1.0, 0.15))
		draw_circle(pos + Vector2(14, -12), 4, Color(0.9, 0.95, 1.0, 0.12))
		draw_circle(pos + Vector2(-8, -6), 3, Color(0.92, 0.96, 1.0, 0.1))
		# Body highlight
		draw_rect(Rect2(pos.x - 21, pos.y - 22, 4, 18), Color(1, 1, 1, 0.06))

	func _draw_frozen_pizza(pos: Vector2) -> void:
		# Flat box
		draw_rect(Rect2(pos.x - 35, pos.y - 12, 70, 12), Color(0.7, 0.35, 0.2, 0.35))
		# Box top
		draw_rect(Rect2(pos.x - 35, pos.y - 14, 70, 3), Color(0.65, 0.3, 0.18, 0.38))
		# Label area
		draw_rect(Rect2(pos.x - 28, pos.y - 10, 56, 7), Color(0.8, 0.45, 0.25, 0.25))
		# Pizza circle decoration on label
		draw_circle(pos + Vector2(0, -7), 8, Color(0.9, 0.75, 0.4, 0.2))
		draw_circle(pos + Vector2(-3, -8), 2, Color(0.8, 0.2, 0.15, 0.15))
		draw_circle(pos + Vector2(4, -6), 1.5, Color(0.8, 0.2, 0.15, 0.12))
		# Frost on box
		draw_rect(Rect2(pos.x - 35, pos.y - 14, 70, 4), Color(0.88, 0.94, 1.0, 0.12))

	func _draw_yogurt_cup(pos: Vector2) -> void:
		# Cup body (slightly tapered)
		var cup := PackedVector2Array([
			pos + Vector2(-10, 0),
			pos + Vector2(10, 0),
			pos + Vector2(12, -20),
			pos + Vector2(-12, -20),
		])
		draw_colored_polygon(cup, Color(0.92, 0.9, 0.88, 0.38))
		# Lid
		draw_rect(Rect2(pos.x - 13, pos.y - 23, 26, 4), Color(0.85, 0.82, 0.8, 0.42))
		# Lid foil texture (shiny)
		draw_rect(Rect2(pos.x - 11, pos.y - 22, 22, 2), Color(0.95, 0.93, 0.9, 0.2))
		# Label stripe
		draw_rect(Rect2(pos.x - 9, pos.y - 14, 18, 6), Color(0.5, 0.3, 0.6, 0.25))
		# Spoon sticking out
		draw_line(pos + Vector2(5, -23), pos + Vector2(15, -35), Color(0.75, 0.73, 0.7, 0.35), 1.5)
		# Spoon head
		draw_circle(pos + Vector2(15, -35), 3, Color(0.75, 0.73, 0.7, 0.3))

	func _draw_penguin(pos: Vector2) -> void:
		# Body (black oval)
		var body_pts: PackedVector2Array = []
		for i in range(20):
			var angle: float = float(i) / 19.0 * TAU
			body_pts.append(pos + Vector2(cos(angle) * 10, sin(angle) * 14))
		if body_pts.size() >= 3:
			draw_colored_polygon(body_pts, Color(0.15, 0.15, 0.18, 0.4))
		# White belly
		var belly_pts: PackedVector2Array = []
		for i in range(16):
			var angle: float = float(i) / 15.0 * TAU
			belly_pts.append(pos + Vector2(cos(angle) * 6, sin(angle) * 10 + 2))
		if belly_pts.size() >= 3:
			draw_colored_polygon(belly_pts, Color(0.92, 0.92, 0.95, 0.35))
		# Head
		draw_circle(pos + Vector2(0, -16), 8, Color(0.15, 0.15, 0.18, 0.42))
		# Eyes
		draw_circle(pos + Vector2(-3, -18), 2, Color(1, 1, 1, 0.4))
		draw_circle(pos + Vector2(3, -18), 2, Color(1, 1, 1, 0.4))
		draw_circle(pos + Vector2(-3, -18), 1, Color(0.1, 0.1, 0.1, 0.5))
		draw_circle(pos + Vector2(3, -18), 1, Color(0.1, 0.1, 0.1, 0.5))
		# Beak
		var beak := PackedVector2Array([
			pos + Vector2(-2, -15), pos + Vector2(2, -15), pos + Vector2(0, -12),
		])
		draw_colored_polygon(beak, Color(0.9, 0.6, 0.15, 0.45))
		# Flippers
		draw_line(pos + Vector2(-10, -6), pos + Vector2(-14, 4), Color(0.15, 0.15, 0.18, 0.35), 3.0)
		draw_line(pos + Vector2(10, -6), pos + Vector2(14, 4), Color(0.15, 0.15, 0.18, 0.35), 3.0)
		# Feet
		draw_circle(pos + Vector2(-4, 14), 3, Color(0.9, 0.6, 0.15, 0.35))
		draw_circle(pos + Vector2(4, 14), 3, Color(0.9, 0.6, 0.15, 0.35))

	func _draw_frost_pattern(pos: Vector2, width: float) -> void:
		for i in range(int(width / 18)):
			var x: float = pos.x + float(i) * 18.0
			var size: float = 3.0 + fmod(float(i) * 7.0, 5.0)
			draw_circle(Vector2(x, pos.y), size, Color(0.9, 0.95, 1.0, 0.1))
			# Fractal-like branching lines
			if i % 2 == 0:
				var branch_h: float = size + 4.0
				draw_line(
					Vector2(x, pos.y - size),
					Vector2(x, pos.y - size - branch_h),
					Color(0.85, 0.92, 1.0, 0.07), 1.0
				)
				# Side branches
				draw_line(
					Vector2(x, pos.y - size - branch_h * 0.4),
					Vector2(x - 4, pos.y - size - branch_h * 0.7),
					Color(0.85, 0.92, 1.0, 0.05), 0.8
				)
				draw_line(
					Vector2(x, pos.y - size - branch_h * 0.4),
					Vector2(x + 4, pos.y - size - branch_h * 0.7),
					Color(0.85, 0.92, 1.0, 0.05), 0.8
				)

	func _draw_water_drop(pos: Vector2) -> void:
		# Teardrop shape
		draw_circle(pos, 2.8, Color(0.7, 0.82, 0.95, 0.2))
		# Highlight (top of drop)
		draw_circle(pos + Vector2(0, -1.2), 1.2, Color(0.88, 0.94, 1.0, 0.28))
		# Trail line below
		draw_line(pos + Vector2(0, 2.8), pos + Vector2(0, 8), Color(0.7, 0.82, 0.95, 0.07), 1.0)
		# Tiny trail dots
		draw_circle(pos + Vector2(0, 10), 0.8, Color(0.7, 0.82, 0.95, 0.05))
