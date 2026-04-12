extends CanvasLayer

## First-play tutorial overlay showing controls step by step

var current_step: int = 0
var step_timer: float = 0.0
var is_active: bool = false
var arrow_anim: float = 0.0
var step_display: TutorialDisplay


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS

	if GameManager.tutorial_completed:
		queue_free()
		return

	is_active = true

	# Semi-transparent overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.4)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.name = "Overlay"
	add_child(overlay)

	step_display = TutorialDisplay.new()
	step_display.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(step_display)

	_show_step(0)


func _show_step(step: int) -> void:
	current_step = step
	step_timer = 0.0
	step_display.step = step
	step_display.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_active:
		return

	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed:
			_advance()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed:
			_advance()


func _advance() -> void:
	current_step += 1
	GameManager.advance_tutorial()

	if current_step >= GameManager.TUTORIAL_STEPS:
		is_active = false
		# Fade out
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		_show_step(current_step)


func _process(delta: float) -> void:
	if not is_active:
		return
	step_timer += delta
	arrow_anim += delta
	step_display.arrow_anim = arrow_anim
	step_display.queue_redraw()


class TutorialDisplay extends Control:
	var step: int = 0
	var arrow_anim: float = 0.0

	var step_data: Array[Dictionary] = [
		{"title": "MOVE", "desc": "Use A/D or Arrow Keys\nto move left and right", "icon": "arrows"},
		{"title": "JUMP", "desc": "Press SPACE or UP\nto jump!", "icon": "jump"},
		{"title": "COLLECT", "desc": "Grab salt crystals for points!\nGet combos for bonus score", "icon": "salt"},
		{"title": "POWER-UPS", "desc": "Chili = Speed boost\nYogurt = Shield\nOlive Oil = Slide boost", "icon": "powerups"},
	]

	func _draw() -> void:
		if step >= step_data.size():
			return

		var data: Dictionary = step_data[step]
		var screen: Vector2 = get_viewport_rect().size
		var cx: float = screen.x / 2.0
		var cy: float = screen.y / 2.0

		# Panel background
		var panel_w: float = 400.0
		var panel_h: float = 220.0
		var panel_x: float = cx - panel_w / 2.0
		var panel_y: float = cy - panel_h / 2.0 - 30.0

		var panel_rect := Rect2(panel_x, panel_y, panel_w, panel_h)
		_draw_rounded_rect(panel_rect, Color(0.08, 0.1, 0.12, 0.92), 16)
		_draw_rounded_rect_border(panel_rect, Color(0.3, 0.8, 0.2, 0.8), 16, 2.0)

		# Step indicator dots
		for i in range(4):
			var dot_x: float = cx - 30 + i * 20
			var dot_y: float = panel_y + panel_h - 20
			var dot_color: Color = Color(0.3, 0.85, 0.2) if i == step else Color(0.4, 0.4, 0.4, 0.5)
			draw_circle(Vector2(dot_x, dot_y), 5 if i == step else 4, dot_color)

		# Icon area
		var icon_cx: float = cx
		var icon_cy: float = panel_y + 55
		_draw_icon(data["icon"], Vector2(icon_cx, icon_cy))

		# Title
		draw_string(ThemeDB.fallback_font, Vector2(cx - 80, panel_y + 105), data["title"], HORIZONTAL_ALIGNMENT_CENTER, 160, 28, Color(0.35, 0.9, 0.2))

		# Description
		var desc_lines: PackedStringArray = data["desc"].split("\n")
		for i in range(desc_lines.size()):
			draw_string(ThemeDB.fallback_font, Vector2(cx - 150, panel_y + 135 + i * 22), desc_lines[i], HORIZONTAL_ALIGNMENT_CENTER, 300, 16, Color(0.85, 0.88, 0.8, 0.9))

		# "Tap to continue"
		var tap_alpha: float = 0.4 + sin(arrow_anim * 3.0) * 0.3
		draw_string(ThemeDB.fallback_font, Vector2(cx - 80, panel_y + panel_h + 30), "Tap to continue", HORIZONTAL_ALIGNMENT_CENTER, 160, 14, Color(1, 1, 1, tap_alpha))


	func _draw_icon(icon_type: String, pos: Vector2) -> void:
		match icon_type:
			"arrows":
				# Left arrow
				var bounce: float = sin(arrow_anim * 3.0) * 5.0
				var left_points := PackedVector2Array([
					Vector2(pos.x - 30 - bounce, pos.y),
					Vector2(pos.x - 15, pos.y - 10),
					Vector2(pos.x - 15, pos.y + 10),
				])
				draw_colored_polygon(left_points, Color(0.3, 0.85, 0.2))
				# Right arrow
				var right_points := PackedVector2Array([
					Vector2(pos.x + 30 + bounce, pos.y),
					Vector2(pos.x + 15, pos.y - 10),
					Vector2(pos.x + 15, pos.y + 10),
				])
				draw_colored_polygon(right_points, Color(0.3, 0.85, 0.2))

			"jump":
				# Up arrow
				var bounce: float = abs(sin(arrow_anim * 3.0)) * 8.0
				var arrow_points := PackedVector2Array([
					Vector2(pos.x, pos.y - 20 - bounce),
					Vector2(pos.x - 15, pos.y - 5),
					Vector2(pos.x + 15, pos.y - 5),
				])
				draw_colored_polygon(arrow_points, Color(0.3, 0.85, 0.2))
				draw_rect(Rect2(pos.x - 5, pos.y - 5, 10, 18), Color(0.3, 0.85, 0.2))

			"salt":
				# Crystal
				var sparkle: float = sin(arrow_anim * 4.0) * 0.3 + 0.7
				var crystal_points := PackedVector2Array([
					Vector2(pos.x, pos.y - 18),
					Vector2(pos.x + 14, pos.y),
					Vector2(pos.x, pos.y + 18),
					Vector2(pos.x - 14, pos.y),
				])
				draw_colored_polygon(crystal_points, Color(0.85, 0.88, 0.95, sparkle))
				var inner_points := PackedVector2Array([
					Vector2(pos.x, pos.y - 9),
					Vector2(pos.x + 7, pos.y),
					Vector2(pos.x, pos.y + 9),
					Vector2(pos.x - 7, pos.y),
				])
				draw_colored_polygon(inner_points, Color(1.0, 1.0, 1.0, sparkle * 0.8))

			"powerups":
				# Chili
				draw_circle(Vector2(pos.x - 25, pos.y), 10, Color(0.85, 0.15, 0.1))
				draw_rect(Rect2(pos.x - 27, pos.y - 15, 4, 5), Color(0.2, 0.6, 0.15))
				# Yogurt
				var cup_points := PackedVector2Array([
					Vector2(pos.x - 8, pos.y - 10),
					Vector2(pos.x + 8, pos.y - 10),
					Vector2(pos.x + 6, pos.y + 10),
					Vector2(pos.x - 6, pos.y + 10),
				])
				draw_colored_polygon(cup_points, Color(0.9, 0.92, 0.95))
				draw_rect(Rect2(pos.x - 8, pos.y - 12, 16, 4), Color(0.6, 0.7, 0.85))
				# Oil bottle
				draw_rect(Rect2(pos.x + 18, pos.y - 10, 14, 20), Color(0.85, 0.65, 0.1))
				draw_rect(Rect2(pos.x + 22, pos.y - 15, 6, 6), Color(0.6, 0.45, 0.1))


	func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
		# Simple filled rounded rect approximation
		draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y), color)
		draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2), color)
		draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
		draw_circle(Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius), radius, color)
		draw_circle(Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius), radius, color)
		draw_circle(Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y - radius), radius, color)

	func _draw_rounded_rect_border(rect: Rect2, color: Color, radius: float, width: float) -> void:
		draw_line(Vector2(rect.position.x + radius, rect.position.y), Vector2(rect.position.x + rect.size.x - radius, rect.position.y), color, width)
		draw_line(Vector2(rect.position.x + radius, rect.position.y + rect.size.y), Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y), color, width)
		draw_line(Vector2(rect.position.x, rect.position.y + radius), Vector2(rect.position.x, rect.position.y + rect.size.y - radius), color, width)
		draw_line(Vector2(rect.position.x + rect.size.x, rect.position.y + radius), Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y - radius), color, width)
		draw_arc(Vector2(rect.position.x + radius, rect.position.y + radius), radius, PI, PI * 1.5, 8, color, width)
		draw_arc(Vector2(rect.position.x + rect.size.x - radius, rect.position.y + radius), radius, PI * 1.5, TAU, 8, color, width)
		draw_arc(Vector2(rect.position.x + radius, rect.position.y + rect.size.y - radius), radius, PI * 0.5, PI, 8, color, width)
		draw_arc(Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y - radius), radius, 0, PI * 0.5, 8, color, width)
