extends CanvasLayer

## Pause screen with resume, menu, and settings

var is_visible: bool = false
var panel: Panel
var anim_timer: float = 0.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Dimmer
	var dimmer := ColorRect.new()
	dimmer.color = Color(0, 0, 0, 0.5)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dimmer)

	# Panel
	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-160, -180)
	panel.size = Vector2(320, 360)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.12, 0.15, 0.95)
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.border_width_top = 3
	panel_style.border_width_bottom = 3
	panel_style.border_width_left = 3
	panel_style.border_width_right = 3
	panel_style.border_color = Color(0.3, 0.75, 0.2)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Pause icon (drawn)
	var pause_icon := PauseIcon.new()
	pause_icon.custom_minimum_size = Vector2(60, 60)
	vbox.add_child(pause_icon)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	# Cucumber face
	var face := PauseCucumber.new()
	face.custom_minimum_size = Vector2(80, 80)
	vbox.add_child(face)

	# Resume button
	var resume_btn := _create_button("RESUME", Color(0.2, 0.7, 0.2), Color(0.25, 0.8, 0.25))
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	# Menu button
	var menu_btn := _create_button("MAIN MENU", Color(0.35, 0.35, 0.4), Color(0.45, 0.45, 0.5))
	menu_btn.pressed.connect(_on_menu)
	vbox.add_child(menu_btn)

	GameManager.pause_toggled.connect(_on_pause_toggled)


func _create_button(text: String, color: Color, hover_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.custom_minimum_size = Vector2(0, 48)

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_bottom = 3
	style.border_color = color.darkened(0.3)
	btn.add_theme_stylebox_override("normal", style)

	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = hover_color
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = color.darkened(0.2)
	pressed.border_width_bottom = 1
	btn.add_theme_stylebox_override("pressed", pressed)

	return btn


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			GameManager.toggle_pause()


func _on_pause_toggled(paused: bool) -> void:
	visible = paused
	is_visible = paused
	if paused:
		panel.scale = Vector2(0.7, 0.7)
		panel.modulate.a = 0.0
		anim_timer = 0.0


func _process(delta: float) -> void:
	if not is_visible:
		return
	anim_timer += delta
	panel.scale = panel.scale.lerp(Vector2.ONE, delta * 8.0)
	panel.modulate.a = lerpf(panel.modulate.a, 1.0, delta * 6.0)


func _on_resume() -> void:
	GameManager.toggle_pause()


func _on_menu() -> void:
	GameManager.toggle_pause()
	GameManager.restart_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


class PauseIcon extends Control:
	func _draw() -> void:
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		# Circle background
		draw_circle(Vector2(cx, cy), 25, Color(0.3, 0.75, 0.2, 0.3))
		# Two pause bars
		draw_rect(Rect2(cx - 10, cy - 12, 7, 24), Color(0.3, 0.85, 0.2))
		draw_rect(Rect2(cx + 3, cy - 12, 7, 24), Color(0.3, 0.85, 0.2))


class PauseCucumber extends Control:
	var timer: float = 0.0

	func _process(delta: float) -> void:
		timer += delta
		queue_redraw()

	func _draw() -> void:
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0

		# Sleeping cucumber face
		var body := Color(0.28, 0.72, 0.18)
		_draw_ellipse(Vector2(cx, cy), Vector2(22, 28), body)
		_draw_ellipse(Vector2(cx - 4, cy), Vector2(10, 20), body.lightened(0.15))

		# Closed eyes (sleeping)
		var ey: float = cy - 5
		draw_line(Vector2(cx - 10, ey), Vector2(cx - 4, ey - 2), Color(0.1, 0.1, 0.1), 2.0)
		draw_line(Vector2(cx + 4, ey), Vector2(cx + 10, ey - 2), Color(0.1, 0.1, 0.1), 2.0)

		# Zzz
		var zx: float = cx + 18
		var zy: float = cy - 15
		var z_offset: float = sin(timer * 2.0) * 3.0
		draw_string(ThemeDB.fallback_font, Vector2(zx, zy + z_offset), "Z", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.85, 1.0, 0.7))
		draw_string(ThemeDB.fallback_font, Vector2(zx + 8, zy - 10 + z_offset * 0.7), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.8, 0.85, 1.0, 0.5))
		draw_string(ThemeDB.fallback_font, Vector2(zx + 14, zy - 18 + z_offset * 0.4), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.8, 0.85, 1.0, 0.3))

		# Peaceful smile
		draw_arc(Vector2(cx, cy + 8), 5, 0.1, PI - 0.1, 8, Color(0.1, 0.1, 0.1), 1.5)

	func _draw_ellipse(center: Vector2, sz: Vector2, color: Color) -> void:
		var points: PackedVector2Array = []
		for i in range(25):
			var angle: float = float(i) / 24.0 * TAU
			points.append(center + Vector2(cos(angle) * sz.x, sin(angle) * sz.y))
		draw_colored_polygon(points, color)
