extends Control

## Main Menu - Phase 3 with animated background, detailed cucumber, and shop button

var title_bounce: float = 0.0
var floating_veggies: Array[Node2D] = []
var glow_timer: float = 0.0


func _ready() -> void:
	# Background - dark green gradient
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.22, 0.06)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	# Gradient overlay (lighter at bottom)
	var gradient_overlay := ColorRect.new()
	gradient_overlay.color = Color(0.12, 0.35, 0.1, 0.3)
	gradient_overlay.set_anchors_preset(PRESET_FULL_RECT)
	gradient_overlay.anchor_top = 0.5
	add_child(gradient_overlay)

	# Spawn floating veggies in background
	var viewport_size: Vector2 = get_viewport_rect().size
	for i in range(20):
		var veggie := FloatingVeggie.new()
		veggie.position = Vector2(randf() * viewport_size.x, randf() * viewport_size.y)
		add_child(veggie)
		floating_veggies.append(veggie)

	# Container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.position = Vector2(-160, -200)
	vbox.custom_minimum_size = Vector2(320, 400)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "STUPID\nCUCUMBER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 0.15))
	title.add_theme_color_override("font_shadow_color", Color(0.05, 0.15, 0.0, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.name = "Title"
	vbox.add_child(title)

	# Subtitle
	var subtitle := Label.new()
	subtitle.text = "A salty adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.85, 0.7, 0.7))
	vbox.add_child(subtitle)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(spacer)

	# Play button (orange styled)
	var play_btn := Button.new()
	play_btn.text = "  PLAY!  "
	play_btn.add_theme_font_size_override("font_size", 30)
	play_btn.add_theme_color_override("font_color", Color.WHITE)
	play_btn.custom_minimum_size = Vector2(220, 60)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.9, 0.3, 0.1)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.border_width_bottom = 5
	style.border_color = Color(0.65, 0.18, 0.04)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	play_btn.add_theme_stylebox_override("normal", style)

	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color(1.0, 0.4, 0.15)
	hover_style.border_color = Color(0.8, 0.25, 0.06)
	play_btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style: StyleBoxFlat = style.duplicate()
	pressed_style.bg_color = Color(0.7, 0.2, 0.05)
	pressed_style.border_width_bottom = 1
	play_btn.add_theme_stylebox_override("pressed", pressed_style)

	play_btn.pressed.connect(_on_play_pressed)
	vbox.add_child(play_btn)

	# Shop button (golden styled)
	var shop_btn := Button.new()
	shop_btn.text = "  SHOP  "
	shop_btn.add_theme_font_size_override("font_size", 24)
	shop_btn.add_theme_color_override("font_color", Color(0.15, 0.1, 0.0))
	shop_btn.custom_minimum_size = Vector2(220, 50)

	var shop_style := StyleBoxFlat.new()
	shop_style.bg_color = Color(0.95, 0.8, 0.2)
	shop_style.corner_radius_top_left = 12
	shop_style.corner_radius_top_right = 12
	shop_style.corner_radius_bottom_left = 12
	shop_style.corner_radius_bottom_right = 12
	shop_style.border_width_bottom = 4
	shop_style.border_color = Color(0.7, 0.55, 0.1)
	shop_style.content_margin_left = 10.0
	shop_style.content_margin_right = 10.0
	shop_btn.add_theme_stylebox_override("normal", shop_style)

	var shop_hover: StyleBoxFlat = shop_style.duplicate()
	shop_hover.bg_color = Color(1.0, 0.88, 0.3)
	shop_hover.border_color = Color(0.8, 0.65, 0.15)
	shop_btn.add_theme_stylebox_override("hover", shop_hover)

	var shop_pressed: StyleBoxFlat = shop_style.duplicate()
	shop_pressed.bg_color = Color(0.8, 0.65, 0.15)
	shop_pressed.border_width_bottom = 1
	shop_btn.add_theme_stylebox_override("pressed", shop_pressed)

	shop_btn.pressed.connect(_on_shop_pressed)
	vbox.add_child(shop_btn)

	# Stats display
	var stats_container := VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 4)
	stats_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stats_container)

	var hs_label := Label.new()
	hs_label.text = "High Score: %d" % GameManager.high_score
	hs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hs_label.add_theme_font_size_override("font_size", 16)
	hs_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 0.7))
	stats_container.add_child(hs_label)

	var ach_label := Label.new()
	var ach_count: int = GameManager.achievements_unlocked.size()
	ach_label.text = "Achievements: %d unlocked" % ach_count
	ach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ach_label.add_theme_font_size_override("font_size", 14)
	ach_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6, 0.6))
	stats_container.add_child(ach_label)

	var salt_label := Label.new()
	salt_label.text = "Total Salt: %d" % GameManager.total_salt_ever
	salt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	salt_label.add_theme_font_size_override("font_size", 14)
	salt_label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9, 0.6))
	stats_container.add_child(salt_label)

	# Cucumber character preview
	var cucumber_preview := CucumberPreview.new()
	cucumber_preview.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.8)
	add_child(cucumber_preview)

	# Creator credit bottom-left
	var credit := Label.new()
	credit.text = "Made by shahabrdz.dev"
	credit.add_theme_font_size_override("font_size", 13)
	credit.add_theme_color_override("font_color", Color(0.6, 0.85, 0.4, 0.6))
	credit.set_anchors_preset(PRESET_BOTTOM_LEFT)
	credit.position = Vector2(15, -25)
	add_child(credit)

	# Version label bottom-right
	var version := Label.new()
	version.text = "v0.3 - Phase 3"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	version.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	version.position = Vector2(-130, -25)
	add_child(version)


func _process(delta: float) -> void:
	title_bounce += delta
	glow_timer += delta
	var title_node: Label = find_child("Title", true, false)
	if title_node:
		var bounce_offset: float = sin(title_bounce * 2.0) * 4.0
		title_node.position.y = bounce_offset
		# Glow effect on title color
		var glow: float = sin(glow_timer * 1.5) * 0.15 + 0.85
		var base_col := Color(0.35, 0.9, 0.15)
		var bright_col := Color(0.55, 1.0, 0.35)
		title_node.add_theme_color_override("font_color", base_col.lerp(bright_col, (glow - 0.7) / 0.3))


func _on_play_pressed() -> void:
	GameManager.restart_game()
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")


# --- Inner class: Ultra Detailed Cucumber Preview ---

class CucumberPreview extends Node2D:
	var timer: float = 0.0
	var blink_timer: float = 0.0
	var blink_duration: float = 0.15
	var is_blinking: bool = false
	var next_blink: float = 3.0
	var wave_timer: float = 0.0
	var is_waving: bool = false
	var next_wave: float = 6.0
	var look_target: Vector2 = Vector2.ZERO
	var look_timer: float = 0.0
	var next_look: float = 2.0
	var expression_state: int = 0  # 0=normal, 1=happy, 2=surprised
	var expression_timer: float = 0.0
	var next_expression: float = 4.0

	func _process(delta: float) -> void:
		timer += delta

		# Blinking logic
		blink_timer += delta
		if not is_blinking and blink_timer >= next_blink:
			is_blinking = true
			blink_timer = 0.0
		if is_blinking and blink_timer >= blink_duration:
			is_blinking = false
			blink_timer = 0.0
			next_blink = randf_range(2.0, 5.0)

		# Waving logic
		wave_timer += delta
		if not is_waving and wave_timer >= next_wave:
			is_waving = true
			wave_timer = 0.0
		if is_waving and wave_timer >= 1.5:
			is_waving = false
			wave_timer = 0.0
			next_wave = randf_range(5.0, 10.0)

		# Looking around logic
		look_timer += delta
		if look_timer >= next_look:
			look_target = Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
			look_timer = 0.0
			next_look = randf_range(1.5, 4.0)

		# Expression changes
		expression_timer += delta
		if expression_timer >= next_expression:
			expression_state = randi() % 3
			expression_timer = 0.0
			next_expression = randf_range(3.0, 7.0)

		queue_redraw()

	func _draw() -> void:
		var wobble: float = sin(timer * 1.8) * 0.06
		var bounce: float = abs(sin(timer * 1.2)) * 8.0
		var scale_val := Vector2(2.5, 2.5)

		draw_set_transform(Vector2(0, -bounce), wobble, scale_val)

		# --- Shadow under cucumber ---
		var shadow_scale: float = 1.0 - bounce / 40.0
		_draw_filled_ellipse(Vector2(0, 38), Vector2(20.0 * shadow_scale, 4.0), Color(0, 0, 0, 0.2))

		# --- Body ---
		var body_color := Color(0.28, 0.72, 0.18)
		var body_light := Color(0.38, 0.82, 0.28)
		var body_dark := Color(0.2, 0.55, 0.12)

		# Main body ellipse
		_draw_filled_ellipse(Vector2(0, 0), Vector2(18, 28), body_color)
		# Light stripe left
		_draw_filled_ellipse(Vector2(-5, 0), Vector2(7, 22), body_light.lerp(body_color, 0.4))
		# Light stripe right
		_draw_filled_ellipse(Vector2(4, -2), Vector2(5, 18), body_light.lerp(body_color, 0.5))
		# Dark edge right
		_draw_filled_ellipse(Vector2(12, 0), Vector2(5, 20), body_dark.lerp(body_color, 0.6))

		# Bumps on body (textured cucumber skin)
		draw_circle(Vector2(10, -10), 3.5, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(12, 4), 3.0, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(-11, 2), 2.8, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(8, 14), 2.5, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(-9, -12), 2.5, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(-7, 15), 2.2, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(-12, -5), 2.0, body_dark.lerp(body_color, 0.45))
		draw_circle(Vector2(6, -18), 2.0, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(-4, 20), 1.8, body_dark.lerp(body_color, 0.5))
		# Bump highlights
		draw_circle(Vector2(9.5, -10.5), 1.5, body_light.lerp(body_color, 0.5))
		draw_circle(Vector2(11.5, 3.5), 1.2, body_light.lerp(body_color, 0.5))

		# --- Stem ---
		var stem_color := Color(0.2, 0.5, 0.1)
		var stem_dark := Color(0.15, 0.38, 0.07)
		draw_rect(Rect2(-4, -31, 8, 7), stem_color)
		draw_rect(Rect2(-3, -34, 6, 4), stem_dark)
		# Leaves on stem
		var leaf_points: PackedVector2Array = PackedVector2Array([
			Vector2(4, -30),
			Vector2(12, -36),
			Vector2(14, -30),
			Vector2(8, -28),
		])
		draw_colored_polygon(leaf_points, Color(0.25, 0.6, 0.15))
		# Second leaf (other side)
		var leaf2_points: PackedVector2Array = PackedVector2Array([
			Vector2(-4, -32),
			Vector2(-11, -38),
			Vector2(-13, -32),
			Vector2(-7, -30),
		])
		draw_colored_polygon(leaf2_points, Color(0.22, 0.55, 0.12))
		# Leaf vein lines
		draw_line(Vector2(8, -33), Vector2(11, -31), Color(0.18, 0.45, 0.1), 0.8)
		draw_line(Vector2(-7, -35), Vector2(-10, -33), Color(0.18, 0.45, 0.1), 0.8)

		# --- Face ---
		var look_x: float = lerpf(0.0, look_target.x, 0.5 + sin(timer * 0.7) * 0.5)
		var look_y: float = lerpf(0.0, look_target.y, 0.5 + cos(timer * 0.5) * 0.5)
		var look := Vector2(look_x, look_y)

		# Eye whites
		if is_blinking:
			# Closed eyes - horizontal lines
			draw_line(Vector2(-10, -6), Vector2(-4, -6), Color(0.15, 0.15, 0.15), 2.0)
			draw_line(Vector2(4, -6), Vector2(10, -6), Color(0.15, 0.15, 0.15), 2.0)
		else:
			# Left eye
			_draw_filled_ellipse(Vector2(-7, -5), Vector2(6.5, 8.0), Color.WHITE)
			# Right eye
			_draw_filled_ellipse(Vector2(7, -5), Vector2(6.0, 7.5), Color.WHITE)

			# Pupils
			var pupil_size_l: float = 3.5
			var pupil_size_r: float = 3.0
			if expression_state == 2:  # surprised - bigger pupils
				pupil_size_l = 4.5
				pupil_size_r = 4.0
			draw_circle(Vector2(-7, -5) + look, pupil_size_l, Color(0.08, 0.08, 0.08))
			draw_circle(Vector2(7, -5) + look, pupil_size_r, Color(0.08, 0.08, 0.08))

			# Eye shine
			draw_circle(Vector2(-8.5, -7) + look * 0.3, 1.5, Color(1, 1, 1, 0.8))
			draw_circle(Vector2(5.5, -7) + look * 0.3, 1.2, Color(1, 1, 1, 0.8))

		# Eyebrows - change with expression
		if expression_state == 2:  # surprised - raised eyebrows
			draw_line(Vector2(-11, -15), Vector2(-3, -16), Color(0.15, 0.4, 0.08), 1.5)
			draw_line(Vector2(3, -16), Vector2(11, -15), Color(0.15, 0.4, 0.08), 1.5)
		elif expression_state == 1:  # happy - angled down
			draw_line(Vector2(-11, -14), Vector2(-3, -12), Color(0.15, 0.4, 0.08), 1.5)
			draw_line(Vector2(3, -12), Vector2(11, -14), Color(0.15, 0.4, 0.08), 1.5)
		else:  # normal
			draw_line(Vector2(-11, -13), Vector2(-3, -14), Color(0.15, 0.4, 0.08), 1.5)
			draw_line(Vector2(3, -14), Vector2(11, -13), Color(0.15, 0.4, 0.08), 1.5)

		# Mouth - changes with expression
		if expression_state == 1:  # happy - big smile
			draw_arc(Vector2(0, 6), 6.0, 0.2, PI - 0.2, 12, Color(0.12, 0.12, 0.12), 2.0)
			# Teeth showing
			draw_rect(Rect2(-3, 6, 6, 3), Color(0.95, 0.95, 0.92))
		elif expression_state == 2:  # surprised - O mouth
			_draw_filled_ellipse(Vector2(0, 8), Vector2(4, 5), Color(0.12, 0.12, 0.12))
			_draw_filled_ellipse(Vector2(0, 8), Vector2(2.5, 3), Color(0.25, 0.1, 0.1))
		else:  # normal - derpy smile
			var mouth_open: float = sin(timer * 1.0) * 0.3 + 0.3
			draw_arc(Vector2(0, 7), 5.0, 0.1 + mouth_open * 0.2, PI - 0.1 - mouth_open * 0.2, 10, Color(0.12, 0.12, 0.12), 2.0)
			# Tongue peek
			if mouth_open > 0.4:
				_draw_filled_ellipse(Vector2(2, 10), Vector2(3, 2), Color(0.85, 0.35, 0.35))

		# Cheek blush
		_draw_filled_ellipse(Vector2(-12, 2), Vector2(4, 2.5), Color(0.9, 0.4, 0.4, 0.25))
		_draw_filled_ellipse(Vector2(12, 2), Vector2(4, 2.5), Color(0.9, 0.4, 0.4, 0.25))

		# --- Arms ---
		var arm_color := body_color.darkened(0.15)

		if is_waving:
			# Waving right arm
			var wave_end := Vector2(22 + sin(wave_timer * 8.0) * 6, -18 + cos(wave_timer * 8.0) * 4)
			draw_line(Vector2(14, -2), wave_end, arm_color, 3.5)
			# Hand with fingers
			draw_circle(wave_end, 3.5, arm_color.lightened(0.1))
			draw_line(wave_end, wave_end + Vector2(2, -3), arm_color.lightened(0.1), 1.5)
			draw_line(wave_end, wave_end + Vector2(4, -1), arm_color.lightened(0.1), 1.5)
			draw_line(wave_end, wave_end + Vector2(3, 2), arm_color.lightened(0.1), 1.5)
			# Left arm normal
			draw_line(Vector2(-14, -2), Vector2(-20, 10), arm_color, 3.5)
			draw_circle(Vector2(-20, 10), 3.0, arm_color.lightened(0.1))
		else:
			# Normal arms
			var arm_swing: float = sin(timer * 1.5) * 3.0
			draw_line(Vector2(-14, -2), Vector2(-20, 10 + arm_swing), arm_color, 3.5)
			draw_circle(Vector2(-20, 10 + arm_swing), 3.0, arm_color.lightened(0.1))
			draw_line(Vector2(14, -2), Vector2(20, 10 - arm_swing), arm_color, 3.5)
			draw_circle(Vector2(20, 10 - arm_swing), 3.0, arm_color.lightened(0.1))

		# --- Legs ---
		var leg_anim: float = sin(timer * 2.5) * 2.0
		draw_line(Vector2(-7, 24), Vector2(-10 + leg_anim, 36), body_dark, 3.5)
		draw_line(Vector2(7, 24), Vector2(10 - leg_anim, 36), body_dark, 3.5)
		# Feet
		_draw_filled_ellipse(Vector2(-10 + leg_anim, 37), Vector2(5, 2.5), body_dark.darkened(0.1))
		_draw_filled_ellipse(Vector2(10 - leg_anim, 37), Vector2(5, 2.5), body_dark.darkened(0.1))

		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func _draw_filled_ellipse(center: Vector2, sz: Vector2, color: Color) -> void:
		var points: PackedVector2Array = PackedVector2Array()
		for i in range(28):
			var angle: float = float(i) / 27.0 * TAU
			points.append(center + Vector2(cos(angle) * sz.x, sin(angle) * sz.y))
		draw_colored_polygon(points, color)


# --- Inner class: Floating Veggie ---

class FloatingVeggie extends Node2D:
	var velocity: Vector2 = Vector2.ZERO
	var rotation_speed: float = 0.0
	var veggie_type: int = 0
	var veggie_scale: float = 1.0
	var alpha: float = 0.0
	var screen_size: Vector2 = Vector2(1280, 720)
	var timer: float = 0.0

	func _ready() -> void:
		veggie_type = randi() % 7  # 0=tomato, 1=carrot, 2=chili, 3=salt, 4=onion, 5=broccoli, 6=mushroom
		veggie_scale = randf_range(0.8, 1.6)
		rotation_speed = randf_range(-0.5, 0.5)
		alpha = randf_range(0.15, 0.35)

		var speed: float = randf_range(10.0, 30.0)
		var angle: float = randf() * TAU
		velocity = Vector2(cos(angle), sin(angle)) * speed

		var vp: Viewport = get_viewport()
		if vp:
			screen_size = vp.get_visible_rect().size

	func _process(delta: float) -> void:
		timer += delta
		position += velocity * delta
		rotation += rotation_speed * delta

		# Wrap around screen
		if position.x < -40:
			position.x = screen_size.x + 40
		elif position.x > screen_size.x + 40:
			position.x = -40
		if position.y < -40:
			position.y = screen_size.y + 40
		elif position.y > screen_size.y + 40:
			position.y = -40

		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(veggie_scale, veggie_scale))

		match veggie_type:
			0:
				_draw_tomato()
			1:
				_draw_carrot()
			2:
				_draw_chili()
			3:
				_draw_salt_crystal()
			4:
				_draw_onion()
			5:
				_draw_broccoli()
			6:
				_draw_mushroom()

		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func _draw_tomato() -> void:
		var col := Color(0.85, 0.15, 0.1, alpha)
		draw_circle(Vector2.ZERO, 10, col)
		draw_circle(Vector2(-2, -2), 8, Color(0.95, 0.25, 0.15, alpha))
		# Stem
		draw_rect(Rect2(-1.5, -13, 3, 4), Color(0.2, 0.5, 0.1, alpha))
		# Leaf
		draw_line(Vector2(0, -12), Vector2(6, -14), Color(0.25, 0.6, 0.15, alpha), 2.0)
		draw_line(Vector2(0, -12), Vector2(-5, -15), Color(0.25, 0.6, 0.15, alpha), 2.0)

	func _draw_carrot() -> void:
		var col := Color(0.95, 0.55, 0.1, alpha)
		var points: PackedVector2Array = PackedVector2Array([
			Vector2(-6, -8),
			Vector2(6, -8),
			Vector2(1, 14),
		])
		draw_colored_polygon(points, col)
		# Stripes
		draw_line(Vector2(-3, -4), Vector2(0, 10), Color(0.85, 0.45, 0.05, alpha * 0.5), 1.0)
		# Leaves
		draw_line(Vector2(0, -8), Vector2(-4, -16), Color(0.2, 0.6, 0.15, alpha), 2.0)
		draw_line(Vector2(0, -8), Vector2(3, -17), Color(0.2, 0.6, 0.15, alpha), 2.0)
		draw_line(Vector2(0, -8), Vector2(0, -18), Color(0.25, 0.65, 0.18, alpha), 2.0)

	func _draw_chili() -> void:
		var col := Color(0.9, 0.1, 0.05, alpha)
		# Curved chili body using small circles
		for i in range(8):
			var t: float = float(i) / 7.0
			var x: float = sin(t * 1.5) * 5.0
			var y: float = t * 18.0 - 9.0
			var r: float = 4.0 - t * 2.5
			draw_circle(Vector2(x, y), r, col)
		# Stem
		draw_rect(Rect2(-2, -12, 4, 4), Color(0.2, 0.5, 0.1, alpha))

	func _draw_salt_crystal() -> void:
		var col := Color(0.9, 0.9, 0.95, alpha)
		draw_rect(Rect2(-5, -6, 10, 12), col)
		draw_rect(Rect2(-3, -4, 6, 8), Color(0.95, 0.95, 1.0, alpha))
		# Sparkle
		var sparkle_alpha: float = (sin(timer * 3.0) * 0.5 + 0.5) * alpha
		draw_circle(Vector2(3, -3), 1.5, Color(1, 1, 1, sparkle_alpha))

	func _draw_onion() -> void:
		var col := Color(0.85, 0.75, 0.5, alpha)
		draw_circle(Vector2(0, 2), 9, col)
		draw_circle(Vector2(0, 0), 7, Color(0.9, 0.8, 0.55, alpha))
		# Top sprout
		draw_line(Vector2(0, -8), Vector2(-2, -15), Color(0.3, 0.6, 0.2, alpha), 1.5)
		draw_line(Vector2(0, -8), Vector2(2, -14), Color(0.3, 0.6, 0.2, alpha), 1.5)
		# Root lines
		draw_line(Vector2(0, 11), Vector2(-1, 14), Color(0.7, 0.6, 0.4, alpha * 0.6), 1.0)
		draw_line(Vector2(0, 11), Vector2(1, 15), Color(0.7, 0.6, 0.4, alpha * 0.6), 1.0)

	func _draw_broccoli() -> void:
		# Stem
		draw_rect(Rect2(-2, 2, 4, 10), Color(0.3, 0.55, 0.2, alpha))
		# Florets
		var green := Color(0.2, 0.6, 0.15, alpha)
		var light_green := Color(0.3, 0.7, 0.2, alpha)
		draw_circle(Vector2(0, -2), 6, green)
		draw_circle(Vector2(-5, 0), 5, green)
		draw_circle(Vector2(5, 0), 5, green)
		draw_circle(Vector2(-3, -5), 4, light_green)
		draw_circle(Vector2(3, -5), 4, light_green)
		draw_circle(Vector2(0, -6), 3.5, light_green)

	func _draw_mushroom() -> void:
		# Stem
		draw_rect(Rect2(-3, 0, 6, 10), Color(0.9, 0.88, 0.82, alpha))
		# Cap
		var cap_pts := PackedVector2Array([
			Vector2(-10, 2),
			Vector2(-8, -4),
			Vector2(-4, -8),
			Vector2(0, -10),
			Vector2(4, -8),
			Vector2(8, -4),
			Vector2(10, 2),
		])
		draw_colored_polygon(cap_pts, Color(0.75, 0.35, 0.2, alpha))
		# Cap spots
		draw_circle(Vector2(-4, -5), 2, Color(0.9, 0.85, 0.75, alpha * 0.6))
		draw_circle(Vector2(3, -3), 1.5, Color(0.9, 0.85, 0.75, alpha * 0.6))
