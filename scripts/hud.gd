extends CanvasLayer

## In-game HUD for Stupid Cucumber
## Displays score, salt, power-up bars, combos, distance, achievements, and touch controls.

var player: CharacterBody2D = null

# UI references
var salt_count_label: Label
var score_label: Label
var combo_label: Label
var distance_label: Label

# Power-up bar instances
var chili_power_bar: PowerBar
var shield_power_bar: PowerBar
var oil_power_bar: PowerBar
var power_bar_container: VBoxContainer

# Achievement system
var achievement_popup: AchievementPopup

# Animation state
var combo_scale: float = 1.0
var combo_timer: float = 0.0
var salt_pop_scale: float = 1.0


func _ready() -> void:
	layer = 10

	_build_score_display()
	_build_salt_display()
	_build_power_bars()
	_build_combo_label()
	_build_distance_display()
	_build_achievement_popup()
	_build_touch_controls()
	_connect_signals()


func _process(delta: float) -> void:
	# --- Combo animation ---
	combo_scale = lerpf(combo_scale, 1.0, delta * 5.0)
	combo_label.scale = Vector2.ONE * combo_scale
	combo_label.pivot_offset = combo_label.size / 2.0

	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_label.modulate.a = 0.0

	if combo_label.modulate.a > 0.0 and combo_timer <= 0.0:
		combo_label.modulate.a = lerpf(combo_label.modulate.a, 0.0, delta * 3.0)
		if combo_label.modulate.a < 0.01:
			combo_label.modulate.a = 0.0

	# --- Salt pop animation ---
	salt_pop_scale = lerpf(salt_pop_scale, 1.0, delta * 8.0)
	salt_count_label.scale = Vector2.ONE * salt_pop_scale
	salt_count_label.pivot_offset = Vector2(0.0, salt_count_label.size.y / 2.0)

	# --- Power-up bars ---
	_update_power_bar(chili_power_bar, GameManager.is_chili_active, GameManager.chili_timer, GameManager.chili_duration)
	_update_power_bar(shield_power_bar, GameManager.is_shield_active, GameManager.shield_timer, GameManager.shield_duration)
	_update_power_bar(oil_power_bar, GameManager.is_oil_active, GameManager.oil_timer, GameManager.oil_duration)

	# --- Distance ---
	distance_label.text = "%dm" % int(GameManager.distance_traveled)


func _update_power_bar(bar: PowerBar, is_active: bool, timer: float, duration: float) -> void:
	if is_active and duration > 0.0:
		bar.fill = timer / duration
		bar.visible = true
	else:
		if bar.fill > 0.01:
			bar.fill = lerpf(bar.fill, 0.0, get_process_delta_time() * 4.0)
		else:
			bar.fill = 0.0
			bar.visible = false
	bar.queue_redraw()


# ==============================================================
# BUILD UI
# ==============================================================

func _build_score_display() -> void:
	# Background panel
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bg.position = Vector2(-210, 5)
	bg.size = Vector2(200, 55)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	# Score header
	var score_header := Label.new()
	score_header.text = "SCORE"
	score_header.add_theme_font_size_override("font_size", 12)
	score_header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 0.7))
	score_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_header.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_header.position = Vector2(-205, 8)
	score_header.size = Vector2(190, 18)
	add_child(score_header)

	# Score value
	score_label = Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 28)
	score_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	score_label.add_theme_constant_override("shadow_offset_x", 2)
	score_label.add_theme_constant_override("shadow_offset_y", 2)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.position = Vector2(-205, 22)
	score_label.size = Vector2(190, 35)
	add_child(score_label)


func _build_salt_display() -> void:
	# Background panel
	var bg := Panel.new()
	bg.position = Vector2(10, 5)
	bg.size = Vector2(140, 42)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	var container := HBoxContainer.new()
	container.position = Vector2(18, 10)
	container.add_theme_constant_override("separation", 6)
	add_child(container)

	# Salt crystal icon
	var salt_icon := SaltIcon.new()
	salt_icon.custom_minimum_size = Vector2(28, 28)
	container.add_child(salt_icon)

	# Salt count
	salt_count_label = Label.new()
	salt_count_label.text = "x 0"
	salt_count_label.add_theme_font_size_override("font_size", 22)
	salt_count_label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	salt_count_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	salt_count_label.add_theme_constant_override("shadow_offset_x", 2)
	salt_count_label.add_theme_constant_override("shadow_offset_y", 2)
	container.add_child(salt_count_label)


func _build_power_bars() -> void:
	power_bar_container = VBoxContainer.new()
	power_bar_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
	power_bar_container.position = Vector2(-110, 8)
	power_bar_container.size = Vector2(220, 90)
	power_bar_container.add_theme_constant_override("separation", 4)
	add_child(power_bar_container)

	# Chili bar: orange-red gradient
	chili_power_bar = PowerBar.new()
	chili_power_bar.bar_label = "CHILI"
	chili_power_bar.fill_color_start = Color(1.0, 0.3, 0.0)
	chili_power_bar.fill_color_end = Color(1.0, 0.75, 0.0)
	chili_power_bar.border_color = Color(0.85, 0.3, 0.1)
	chili_power_bar.icon_type = PowerBar.IconType.FLAME
	chili_power_bar.custom_minimum_size = Vector2(220, 22)
	chili_power_bar.visible = false
	power_bar_container.add_child(chili_power_bar)

	# Shield bar: blue
	shield_power_bar = PowerBar.new()
	shield_power_bar.bar_label = "SHIELD"
	shield_power_bar.fill_color_start = Color(0.2, 0.55, 0.95)
	shield_power_bar.fill_color_end = Color(0.5, 0.8, 1.0)
	shield_power_bar.border_color = Color(0.3, 0.5, 0.8)
	shield_power_bar.icon_type = PowerBar.IconType.BUBBLE
	shield_power_bar.custom_minimum_size = Vector2(220, 22)
	shield_power_bar.visible = false
	power_bar_container.add_child(shield_power_bar)

	# Oil bar: golden
	oil_power_bar = PowerBar.new()
	oil_power_bar.bar_label = "OIL"
	oil_power_bar.fill_color_start = Color(0.85, 0.65, 0.1)
	oil_power_bar.fill_color_end = Color(1.0, 0.88, 0.3)
	oil_power_bar.border_color = Color(0.7, 0.55, 0.15)
	oil_power_bar.icon_type = PowerBar.IconType.DROP
	oil_power_bar.custom_minimum_size = Vector2(220, 22)
	oil_power_bar.visible = false
	power_bar_container.add_child(oil_power_bar)


func _build_combo_label() -> void:
	combo_label = Label.new()
	combo_label.text = ""
	combo_label.add_theme_font_size_override("font_size", 38)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	combo_label.add_theme_constant_override("shadow_offset_x", 2)
	combo_label.add_theme_constant_override("shadow_offset_y", 2)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	combo_label.position = Vector2(-120, 70)
	combo_label.size = Vector2(240, 50)
	combo_label.modulate.a = 0.0
	add_child(combo_label)


func _build_distance_display() -> void:
	# Background
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bg.position = Vector2(-55, -45)
	bg.size = Vector2(110, 32)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.3)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	distance_label = Label.new()
	distance_label.text = "0m"
	distance_label.add_theme_font_size_override("font_size", 18)
	distance_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.9))
	distance_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	distance_label.add_theme_constant_override("shadow_offset_x", 1)
	distance_label.add_theme_constant_override("shadow_offset_y", 1)
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	distance_label.position = Vector2(-55, -44)
	distance_label.size = Vector2(110, 30)
	add_child(distance_label)


func _build_achievement_popup() -> void:
	achievement_popup = AchievementPopup.new()
	achievement_popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	achievement_popup.position = Vector2(-160, -80)
	achievement_popup.size = Vector2(320, 70)
	add_child(achievement_popup)


func _build_touch_controls() -> void:
	var touch_ui := TouchControls.new()
	touch_ui.name = "TouchControls"
	add_child(touch_ui)


# ==============================================================
# SIGNAL CONNECTIONS
# ==============================================================

func _connect_signals() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.salt_changed.connect(_on_salt_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.chili_activated.connect(_on_chili_activated)
	GameManager.chili_ended.connect(_on_chili_ended)
	GameManager.shield_activated.connect(_on_shield_activated)
	GameManager.shield_ended.connect(_on_shield_ended)
	GameManager.oil_activated.connect(_on_oil_activated)
	GameManager.oil_ended.connect(_on_oil_ended)
	GameManager.achievement_unlocked.connect(_on_achievement_unlocked)


func _on_score_changed(new_score: int) -> void:
	score_label.text = str(new_score)


func _on_salt_changed(new_salt: int) -> void:
	salt_count_label.text = "x %d" % new_salt
	salt_pop_scale = 1.3


func _on_combo_changed(combo: int) -> void:
	if combo >= 3:
		combo_label.text = "%dx COMBO!" % combo
		combo_label.modulate.a = 1.0
		combo_scale = 1.5
		combo_timer = 2.0

		if combo >= 10:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.8))
		elif combo >= 7:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		else:
			combo_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))


func _on_chili_activated(_duration: float) -> void:
	chili_power_bar.visible = true


func _on_chili_ended() -> void:
	pass


func _on_shield_activated() -> void:
	shield_power_bar.visible = true


func _on_shield_ended() -> void:
	pass


func _on_oil_activated() -> void:
	oil_power_bar.visible = true


func _on_oil_ended() -> void:
	pass


func _on_achievement_unlocked(title: String, description: String) -> void:
	achievement_popup.queue_achievement(title, description)


# ==============================================================
# INPUT HANDLING FOR TOUCH CONTROLS
# ==============================================================

func _input(event: InputEvent) -> void:
	if not player:
		return

	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		var pos: Vector2 = touch.position
		if not touch.pressed:
			player.touch_left = false
			player.touch_right = false
			player.touch_jump = false
			return
		_handle_touch_position(pos)

	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		var pos: Vector2 = drag.position
		_handle_touch_position(pos)


func _handle_touch_position(pos: Vector2) -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size

	player.touch_left = false
	player.touch_right = false
	player.touch_jump = false

	if pos.y > screen_size.y * 0.5:
		if pos.x < screen_size.x * 0.3:
			player.touch_left = true
		elif pos.x < screen_size.x * 0.6:
			player.touch_right = true
		else:
			player.touch_jump = true


# ==============================================================
# INNER CLASSES
# ==============================================================

class SaltIcon extends Control:
	## Draws a sparkling salt crystal diamond shape.

	func _draw() -> void:
		var c: Vector2 = size / 2.0

		# Outer diamond
		var outer := PackedVector2Array([
			c + Vector2(0, -13),
			c + Vector2(9, 0),
			c + Vector2(0, 13),
			c + Vector2(-9, 0),
		])
		draw_colored_polygon(outer, Color(0.78, 0.82, 0.95))

		# Inner highlight
		var inner := PackedVector2Array([
			c + Vector2(0, -7),
			c + Vector2(5, 0),
			c + Vector2(0, 7),
			c + Vector2(-5, 0),
		])
		draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, 0.7))

		# Sparkle dots
		var sparkle_alpha: float = (sin(float(Engine.get_process_frames()) * 0.15) * 0.5 + 0.5) * 0.8
		draw_circle(c + Vector2(-4, -8), 1.5, Color(1, 1, 1, sparkle_alpha))
		draw_circle(c + Vector2(6, 3), 1.2, Color(1, 1, 1, sparkle_alpha * 0.7))
		draw_circle(c + Vector2(-2, 9), 1.0, Color(1, 1, 1, sparkle_alpha * 0.5))

	func _process(_delta: float) -> void:
		queue_redraw()


class PowerBar extends Control:
	## A generic horizontal power-up bar with animated fill, colored gradient, and icon.

	enum IconType { FLAME, BUBBLE, DROP }

	var fill: float = 0.0
	var bar_label: String = ""
	var fill_color_start: Color = Color.WHITE
	var fill_color_end: Color = Color.WHITE
	var border_color: Color = Color.WHITE
	var icon_type: IconType = IconType.FLAME

	func _draw() -> void:
		var bar_rect := Rect2(Vector2(24, 0), Vector2(size.x - 24, size.y))

		# Background
		draw_rect(bar_rect, Color(0.1, 0.1, 0.1, 0.5))

		# Animated fill
		var fill_width: float = bar_rect.size.x * fill
		if fill_width > 0.5:
			# Gradient shimmer
			var shimmer: float = sin(float(Engine.get_process_frames()) * 0.2) * 0.5 + 0.5
			var col: Color = fill_color_start.lerp(fill_color_end, shimmer)
			draw_rect(Rect2(bar_rect.position, Vector2(fill_width, bar_rect.size.y)), col)

			# Bright edge highlight
			var highlight_x: float = bar_rect.position.x + fill_width - 2.0
			draw_rect(Rect2(Vector2(highlight_x, bar_rect.position.y), Vector2(2, bar_rect.size.y)), Color(1, 1, 1, 0.3))

		# Border
		draw_rect(bar_rect, border_color.lerped(Color.WHITE, 0.2), false, 1.5)

		# Icon on the left side
		var icon_center := Vector2(12, size.y / 2.0)
		match icon_type:
			IconType.FLAME:
				_draw_flame_icon(icon_center)
			IconType.BUBBLE:
				_draw_bubble_icon(icon_center)
			IconType.DROP:
				_draw_drop_icon(icon_center)

		# Label text
		draw_string(
			ThemeDB.fallback_font,
			Vector2(bar_rect.position.x + 4, size.y - 5),
			bar_label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11,
			Color(1, 1, 1, 0.65)
		)

	func _draw_flame_icon(center: Vector2) -> void:
		var pts := PackedVector2Array([
			center + Vector2(0, -8),
			center + Vector2(5, 2),
			center + Vector2(3, 7),
			center + Vector2(0, 5),
			center + Vector2(-3, 7),
			center + Vector2(-5, 2),
		])
		draw_colored_polygon(pts, Color(1.0, 0.45, 0.1, 0.9))
		var inner_pts := PackedVector2Array([
			center + Vector2(0, -4),
			center + Vector2(3, 2),
			center + Vector2(0, 5),
			center + Vector2(-3, 2),
		])
		draw_colored_polygon(inner_pts, Color(1.0, 0.85, 0.2, 0.8))

	func _draw_bubble_icon(center: Vector2) -> void:
		draw_circle(center, 7, Color(0.3, 0.6, 1.0, 0.5))
		draw_arc(center, 7, 0.0, TAU, 24, Color(0.5, 0.75, 1.0, 0.8), 1.5)
		# Highlight
		draw_circle(center + Vector2(-2, -3), 2, Color(1, 1, 1, 0.5))

	func _draw_drop_icon(center: Vector2) -> void:
		var pts := PackedVector2Array([
			center + Vector2(0, -8),
			center + Vector2(5, 2),
			center + Vector2(4, 5),
			center + Vector2(0, 8),
			center + Vector2(-4, 5),
			center + Vector2(-5, 2),
		])
		draw_colored_polygon(pts, Color(0.9, 0.75, 0.15, 0.85))
		draw_circle(center + Vector2(-1, -1), 2, Color(1, 1, 1, 0.4))


class TouchControls extends Control:
	## Draws semi-transparent touch buttons for mobile input.

	func _ready() -> void:
		set_anchors_preset(PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var screen: Vector2 = get_viewport_rect().size
		var alpha: float = 0.15
		var icon_alpha: float = 0.45

		# --- Left arrow (bottom-left) ---
		var left_center := Vector2(75, screen.y - 85)
		draw_circle(left_center, 38, Color(1, 1, 1, alpha))
		draw_arc(left_center, 38, 0, TAU, 32, Color(1, 1, 1, alpha * 2.0), 2.0)
		# Arrow shape pointing left
		var left_arrow := PackedVector2Array([
			left_center + Vector2(-12, 0),
			left_center + Vector2(4, -10),
			left_center + Vector2(4, 10),
		])
		draw_colored_polygon(left_arrow, Color(1, 1, 1, icon_alpha))

		# --- Right arrow ---
		var right_center := Vector2(185, screen.y - 85)
		draw_circle(right_center, 38, Color(1, 1, 1, alpha))
		draw_arc(right_center, 38, 0, TAU, 32, Color(1, 1, 1, alpha * 2.0), 2.0)
		# Arrow shape pointing right
		var right_arrow := PackedVector2Array([
			right_center + Vector2(12, 0),
			right_center + Vector2(-4, -10),
			right_center + Vector2(-4, 10),
		])
		draw_colored_polygon(right_arrow, Color(1, 1, 1, icon_alpha))

		# --- Jump button (bottom-right) ---
		var jump_center := Vector2(screen.x - 90, screen.y - 85)
		draw_circle(jump_center, 46, Color(0.3, 0.85, 0.35, alpha))
		draw_arc(jump_center, 46, 0, TAU, 32, Color(0.3, 0.85, 0.35, alpha * 2.5), 2.0)
		# Up arrow for jump
		var jump_arrow := PackedVector2Array([
			jump_center + Vector2(0, -14),
			jump_center + Vector2(12, 4),
			jump_center + Vector2(4, 4),
			jump_center + Vector2(4, 14),
			jump_center + Vector2(-4, 14),
			jump_center + Vector2(-4, 4),
			jump_center + Vector2(-12, 4),
		])
		draw_colored_polygon(jump_arrow, Color(1, 1, 1, icon_alpha))


class AchievementPopup extends Control:
	## Animated achievement notification that slides in from the top.
	## Supports queuing multiple achievements.

	var queue: Array[Dictionary] = []
	var current_title: String = ""
	var current_description: String = ""
	var state: int = 0  # 0=hidden, 1=sliding_in, 2=showing, 3=sliding_out
	var anim_progress: float = 0.0
	var show_timer: float = 0.0

	const SLIDE_SPEED: float = 4.0
	const SHOW_DURATION: float = 3.0

	func _process(delta: float) -> void:
		match state:
			0:  # Hidden - check queue
				if queue.size() > 0:
					var entry: Dictionary = queue.pop_front()
					current_title = entry.get("title", "")
					current_description = entry.get("desc", "")
					state = 1
					anim_progress = 0.0
			1:  # Sliding in
				anim_progress = minf(anim_progress + delta * SLIDE_SPEED, 1.0)
				if anim_progress >= 1.0:
					state = 2
					show_timer = SHOW_DURATION
			2:  # Showing
				show_timer -= delta
				if show_timer <= 0.0:
					state = 3
					anim_progress = 1.0
			3:  # Sliding out
				anim_progress = maxf(anim_progress - delta * SLIDE_SPEED, 0.0)
				if anim_progress <= 0.0:
					state = 0
		queue_redraw()

	func queue_achievement(title: String, description: String) -> void:
		queue.append({"title": title, "desc": description})

	func _draw() -> void:
		if state == 0:
			return

		# Ease function for smooth slide
		var t: float = _ease_out_back(anim_progress)
		var offset_y: float = lerpf(-size.y - 10.0, 0.0, t)

		# Panel background
		var panel_rect := Rect2(Vector2(0, offset_y), size)
		var bg_color := Color(0.12, 0.1, 0.18, 0.88)
		_draw_rounded_rect(panel_rect, bg_color, 10.0)

		# Gold border
		var border_color := Color(0.95, 0.8, 0.2, 0.7)
		_draw_rounded_rect_outline(panel_rect, border_color, 10.0, 2.0)

		# Trophy icon (simple drawn trophy)
		var trophy_x: float = 28.0
		var trophy_y: float = offset_y + size.y / 2.0
		_draw_trophy(Vector2(trophy_x, trophy_y))

		# Title in gold
		draw_string(
			ThemeDB.fallback_font,
			Vector2(55, offset_y + 26),
			current_title,
			HORIZONTAL_ALIGNMENT_LEFT,
			int(size.x) - 65, 18,
			Color(1.0, 0.88, 0.25)
		)

		# Description
		draw_string(
			ThemeDB.fallback_font,
			Vector2(55, offset_y + 48),
			current_description,
			HORIZONTAL_ALIGNMENT_LEFT,
			int(size.x) - 65, 13,
			Color(0.82, 0.82, 0.85, 0.85)
		)

	func _draw_trophy(center: Vector2) -> void:
		# Cup body
		var cup := PackedVector2Array([
			center + Vector2(-8, -10),
			center + Vector2(8, -10),
			center + Vector2(6, 2),
			center + Vector2(-6, 2),
		])
		draw_colored_polygon(cup, Color(1.0, 0.82, 0.15))

		# Stem
		draw_rect(Rect2(center + Vector2(-2, 2), Vector2(4, 6)), Color(0.9, 0.72, 0.1))

		# Base
		draw_rect(Rect2(center + Vector2(-6, 8), Vector2(12, 3)), Color(1.0, 0.82, 0.15))

		# Handles
		draw_arc(center + Vector2(-9, -4), 5, -PI * 0.5, PI * 0.5, 8, Color(1.0, 0.82, 0.15), 2.0)
		draw_arc(center + Vector2(9, -4), 5, PI * 0.5, PI * 1.5, 8, Color(1.0, 0.82, 0.15), 2.0)

		# Star on cup
		draw_circle(center + Vector2(0, -4), 2.5, Color(1.0, 1.0, 0.6, 0.7))

	func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
		# Simplified rounded rect using polygon approximation
		var pts := PackedVector2Array()
		var corners: Array[Vector2] = [
			rect.position + Vector2(radius, 0),
			rect.position + Vector2(rect.size.x - radius, 0),
			rect.position + Vector2(rect.size.x, radius),
			rect.position + Vector2(rect.size.x, rect.size.y - radius),
			rect.position + Vector2(rect.size.x - radius, rect.size.y),
			rect.position + Vector2(radius, rect.size.y),
			rect.position + Vector2(0, rect.size.y - radius),
			rect.position + Vector2(0, radius),
		]
		for p in corners:
			pts.append(p)
		draw_colored_polygon(pts, color)

	func _draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float) -> void:
		var pts := PackedVector2Array()
		var corners: Array[Vector2] = [
			rect.position + Vector2(radius, 0),
			rect.position + Vector2(rect.size.x - radius, 0),
			rect.position + Vector2(rect.size.x, radius),
			rect.position + Vector2(rect.size.x, rect.size.y - radius),
			rect.position + Vector2(rect.size.x - radius, rect.size.y),
			rect.position + Vector2(radius, rect.size.y),
			rect.position + Vector2(0, rect.size.y - radius),
			rect.position + Vector2(0, radius),
		]
		for p in corners:
			pts.append(p)
		pts.append(corners[0])
		draw_polyline(pts, color, width)

	func _ease_out_back(t: float) -> float:
		var c1: float = 1.70158
		var c3: float = c1 + 1.0
		return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)
