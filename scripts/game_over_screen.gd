extends CanvasLayer

## Game Over screen - Phase 2 with detailed stats and dead cucumber

var is_visible: bool = false
var anim_timer: float = 0.0

var panel: Panel
var dimmer: ColorRect
var message_label: Label
var score_value: Label
var best_value: Label
var salt_label: Label
var distance_label: Label
var enemies_label: Label
var retry_btn: Button
var menu_btn: Button
var stats_container: VBoxContainer


func _ready() -> void:
	layer = 20
	visible = false

	# Dimmer
	dimmer = ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.0)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.name = "Dimmer"
	add_child(dimmer)

	# Panel
	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-200, -250)
	panel.size = Vector2(400, 500)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.13, 0.96)
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.95, 0.45, 0.1)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Margin container inside panel
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Dead cucumber drawing
	var dead_cuc := DeadCucumber.new()
	dead_cuc.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(dead_cuc)

	# Game Over text
	var go_label := Label.new()
	go_label.text = "GAME OVER"
	go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_label.add_theme_font_size_override("font_size", 40)
	go_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.1))
	go_label.add_theme_color_override("font_shadow_color", Color(0.4, 0.1, 0.0, 0.5))
	go_label.add_theme_constant_override("shadow_offset_x", 2)
	go_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(go_label)

	# Funny message
	message_label = Label.new()
	message_label.text = ""
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 15)
	message_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 0.8))
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(message_label)

	# Score header
	var score_header := Label.new()
	score_header.text = "SCORE"
	score_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_header.add_theme_font_size_override("font_size", 13)
	score_header.add_theme_color_override("font_color", Color(0.65, 0.65, 0.55))
	vbox.add_child(score_header)

	# Score value (large golden number)
	score_value = Label.new()
	score_value.text = "0"
	score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_value.add_theme_font_size_override("font_size", 48)
	score_value.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
	score_value.add_theme_color_override("font_shadow_color", Color(0.5, 0.4, 0.0, 0.4))
	score_value.add_theme_constant_override("shadow_offset_x", 2)
	score_value.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(score_value)

	# Best value
	best_value = Label.new()
	best_value.text = "BEST: 0"
	best_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_value.add_theme_font_size_override("font_size", 16)
	best_value.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
	vbox.add_child(best_value)

	# Stats container (salt, distance, enemies) - delayed reveal
	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 4)
	stats_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_container.modulate.a = 0
	stats_container.name = "StatsContainer"
	vbox.add_child(stats_container)

	# Salt collected
	salt_label = Label.new()
	salt_label.text = ""
	salt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	salt_label.add_theme_font_size_override("font_size", 14)
	salt_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.92))
	stats_container.add_child(salt_label)

	# Distance traveled
	distance_label = Label.new()
	distance_label.text = ""
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.add_theme_font_size_override("font_size", 14)
	distance_label.add_theme_color_override("font_color", Color(0.75, 0.85, 0.75))
	stats_container.add_child(distance_label)

	# Enemies defeated
	enemies_label = Label.new()
	enemies_label.text = ""
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemies_label.add_theme_font_size_override("font_size", 14)
	enemies_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.7))
	stats_container.add_child(enemies_label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	# Retry button
	retry_btn = Button.new()
	retry_btn.text = "TRY AGAIN"
	retry_btn.add_theme_font_size_override("font_size", 22)
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	retry_btn.custom_minimum_size = Vector2(0, 50)

	var retry_style := StyleBoxFlat.new()
	retry_style.bg_color = Color(0.2, 0.7, 0.2)
	retry_style.corner_radius_top_left = 12
	retry_style.corner_radius_top_right = 12
	retry_style.corner_radius_bottom_left = 12
	retry_style.corner_radius_bottom_right = 12
	retry_style.border_width_bottom = 3
	retry_style.border_color = Color(0.12, 0.45, 0.12)
	retry_btn.add_theme_stylebox_override("normal", retry_style)

	var retry_hover: StyleBoxFlat = retry_style.duplicate()
	retry_hover.bg_color = Color(0.25, 0.8, 0.25)
	retry_btn.add_theme_stylebox_override("hover", retry_hover)

	var retry_pressed: StyleBoxFlat = retry_style.duplicate()
	retry_pressed.bg_color = Color(0.15, 0.55, 0.15)
	retry_pressed.border_width_bottom = 1
	retry_btn.add_theme_stylebox_override("pressed", retry_pressed)

	retry_btn.pressed.connect(_on_retry)
	vbox.add_child(retry_btn)

	# Menu button
	menu_btn = Button.new()
	menu_btn.text = "MENU"
	menu_btn.add_theme_font_size_override("font_size", 16)
	menu_btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	menu_btn.custom_minimum_size = Vector2(0, 40)

	var menu_style := StyleBoxFlat.new()
	menu_style.bg_color = Color(0.3, 0.3, 0.35)
	menu_style.corner_radius_top_left = 10
	menu_style.corner_radius_top_right = 10
	menu_style.corner_radius_bottom_left = 10
	menu_style.corner_radius_bottom_right = 10
	menu_style.border_width_bottom = 2
	menu_style.border_color = Color(0.2, 0.2, 0.25)
	menu_btn.add_theme_stylebox_override("normal", menu_style)

	var menu_hover: StyleBoxFlat = menu_style.duplicate()
	menu_hover.bg_color = Color(0.38, 0.38, 0.42)
	menu_btn.add_theme_stylebox_override("hover", menu_hover)

	menu_btn.pressed.connect(_on_menu)
	vbox.add_child(menu_btn)

	# Connect signal
	GameManager.player_died.connect(_on_player_died)


func show_game_over() -> void:
	visible = true
	is_visible = true
	anim_timer = 0.0

	# Populate data
	message_label.text = "\"%s\"" % GameManager.get_random_game_over_message()
	score_value.text = str(GameManager.score)

	# High score check
	var is_new_best: bool = GameManager.score >= GameManager.high_score and GameManager.score > 0
	if is_new_best:
		best_value.text = "NEW BEST!"
		best_value.add_theme_color_override("font_color", Color(1.0, 0.82, 0.0))
		best_value.add_theme_font_size_override("font_size", 20)
	else:
		best_value.text = "BEST: %d" % GameManager.high_score
		best_value.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
		best_value.add_theme_font_size_override("font_size", 16)

	# Stats
	salt_label.text = "Salt collected: %d" % GameManager.salt_collected
	distance_label.text = "Distance: %dm" % int(GameManager.distance_traveled)
	enemies_label.text = "Enemies defeated: %d" % GameManager.enemies_killed

	# Reset animation state
	panel.scale = Vector2(0.3, 0.3)
	panel.modulate.a = 0
	dimmer.color.a = 0
	stats_container.modulate.a = 0


func _process(delta: float) -> void:
	if not is_visible:
		return

	anim_timer += delta

	# Animate dimmer fade in
	dimmer.color.a = lerpf(dimmer.color.a, 0.65, delta * 4.0)

	# Animate panel slide/scale in
	panel.scale = panel.scale.lerp(Vector2.ONE, delta * 5.5)
	panel.modulate.a = lerpf(panel.modulate.a, 1.0, delta * 5.0)

	# Stats appear after a short delay
	if anim_timer > 0.6:
		stats_container.modulate.a = lerpf(stats_container.modulate.a, 1.0, delta * 4.0)

	# Pulse the score color for new best
	if GameManager.score >= GameManager.high_score and GameManager.score > 0:
		var pulse: float = (sin(anim_timer * 4.0) * 0.5 + 0.5)
		var gold := Color(1.0, 0.82, 0.0)
		var bright_gold := Color(1.0, 0.95, 0.5)
		best_value.add_theme_color_override("font_color", gold.lerp(bright_gold, pulse))


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	show_game_over()


func _on_retry() -> void:
	GameManager.restart_game()
	get_tree().reload_current_scene()


func _on_menu() -> void:
	GameManager.restart_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# --- Inner class: Dead Cucumber ---

class DeadCucumber extends Control:
	var timer: float = 0.0

	func _process(delta: float) -> void:
		timer += delta
		queue_redraw()

	func _draw() -> void:
		var center_x: float = size.x * 0.5
		var cy: float = size.y * 0.6

		# Body lying on its side (rotated ellipse)
		var body_color := Color(0.25, 0.6, 0.15)
		var body_dark := Color(0.18, 0.45, 0.1)

		# Main body - horizontal cucumber (lying down)
		var body_points: PackedVector2Array = PackedVector2Array()
		for i in range(28):
			var angle: float = float(i) / 27.0 * TAU
			body_points.append(Vector2(center_x + cos(angle) * 28, cy + sin(angle) * 12))
		draw_colored_polygon(body_points, body_color)

		# Light stripe
		var stripe_points: PackedVector2Array = PackedVector2Array()
		for i in range(28):
			var angle: float = float(i) / 27.0 * TAU
			stripe_points.append(Vector2(center_x + cos(angle) * 22, cy - 2 + sin(angle) * 7))
		draw_colored_polygon(stripe_points, body_color.lightened(0.15))

		# Bumps
		draw_circle(Vector2(center_x + 12, cy - 5), 2.5, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(center_x - 8, cy - 4), 2.0, body_dark.lerp(body_color, 0.5))
		draw_circle(Vector2(center_x + 18, cy + 2), 2.0, body_dark.lerp(body_color, 0.5))

		# Stem (on right side since lying down)
		draw_rect(Rect2(center_x + 26, cy - 3, 6, 5), Color(0.2, 0.45, 0.1))

		# X eyes
		var eye_y: float = cy - 3
		var left_eye_x: float = center_x - 8
		var right_eye_x: float = center_x + 4

		# Left X eye
		draw_line(Vector2(left_eye_x - 3, eye_y - 3), Vector2(left_eye_x + 3, eye_y + 3), Color(0.15, 0.15, 0.15), 2.0)
		draw_line(Vector2(left_eye_x + 3, eye_y - 3), Vector2(left_eye_x - 3, eye_y + 3), Color(0.15, 0.15, 0.15), 2.0)

		# Right X eye
		draw_line(Vector2(right_eye_x - 3, eye_y - 3), Vector2(right_eye_x + 3, eye_y + 3), Color(0.15, 0.15, 0.15), 2.0)
		draw_line(Vector2(right_eye_x + 3, eye_y - 3), Vector2(right_eye_x - 3, eye_y + 3), Color(0.15, 0.15, 0.15), 2.0)

		# Sad mouth
		draw_arc(Vector2(center_x - 2, cy + 5), 4.0, PI + 0.3, TAU - 0.3, 8, Color(0.12, 0.12, 0.12), 1.5)

		# Tongue sticking out
		draw_circle(Vector2(center_x + 2, cy + 7), 2.0, Color(0.8, 0.3, 0.3, 0.6))

		# Little stars/dizzy effect above head
		var star_alpha: float = (sin(timer * 3.0) * 0.4 + 0.6)
		_draw_star(Vector2(center_x - 12, cy - 16), 3.0, Color(1, 1, 0.5, star_alpha * 0.7))
		_draw_star(Vector2(center_x + 2, cy - 19), 2.5, Color(1, 1, 0.5, star_alpha * 0.5))
		_draw_star(Vector2(center_x + 14, cy - 15), 2.0, Color(1, 1, 0.5, star_alpha * 0.6))

	func _draw_star(pos: Vector2, sz: float, color: Color) -> void:
		# Simple 4-point star
		draw_line(pos + Vector2(-sz, 0), pos + Vector2(sz, 0), color, 1.5)
		draw_line(pos + Vector2(0, -sz), pos + Vector2(0, sz), color, 1.5)
		var d: float = sz * 0.6
		draw_line(pos + Vector2(-d, -d), pos + Vector2(d, d), color, 1.0)
		draw_line(pos + Vector2(d, -d), pos + Vector2(-d, d), color, 1.0)
