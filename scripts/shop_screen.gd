extends Control

## Skin Shop - Buy and equip cucumber skins with salt

var skin_cards: Array[SkinCard] = []
var wallet_label: Label
var preview: SkinPreview


func _ready() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.18, 0.06)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)

	# Title
	var title := Label.new()
	title.text = "SKIN SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.set_anchors_preset(PRESET_CENTER_TOP)
	title.position = Vector2(-150, 15)
	title.size = Vector2(300, 50)
	add_child(title)

	# Wallet display
	var wallet_panel := Panel.new()
	wallet_panel.position = Vector2(20, 15)
	wallet_panel.size = Vector2(200, 45)
	var wp_style := StyleBoxFlat.new()
	wp_style.bg_color = Color(0, 0, 0, 0.4)
	wp_style.corner_radius_top_left = 10
	wp_style.corner_radius_top_right = 10
	wp_style.corner_radius_bottom_left = 10
	wp_style.corner_radius_bottom_right = 10
	wallet_panel.add_theme_stylebox_override("panel", wp_style)
	add_child(wallet_panel)

	var salt_icon := ShopSaltIcon.new()
	salt_icon.custom_minimum_size = Vector2(30, 30)
	salt_icon.position = Vector2(30, 22)
	add_child(salt_icon)

	wallet_label = Label.new()
	wallet_label.text = "x %d" % GameManager.total_salt_wallet
	wallet_label.add_theme_font_size_override("font_size", 22)
	wallet_label.add_theme_color_override("font_color", Color(0.9, 0.92, 1.0))
	wallet_label.position = Vector2(65, 24)
	add_child(wallet_label)

	# Skin preview
	preview = SkinPreview.new()
	preview.position = Vector2(640, 500)
	add_child(preview)

	# Skin cards grid
	var grid := HBoxContainer.new()
	grid.set_anchors_preset(PRESET_CENTER)
	grid.position = Vector2(-420, -120)
	grid.custom_minimum_size = Vector2(840, 240)
	grid.add_theme_constant_override("separation", 14)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(grid)

	for skin_data in GameManager.skin_catalog:
		var card := SkinCard.new()
		card.skin_data = skin_data
		card.custom_minimum_size = Vector2(120, 220)
		card.update_state()
		card.pressed.connect(_on_skin_pressed.bind(skin_data))
		grid.add_child(card)
		skin_cards.append(card)

	# Back button
	var back_btn := Button.new()
	back_btn.text = "< BACK"
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.custom_minimum_size = Vector2(120, 42)
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.35, 0.35, 0.4)
	back_style.corner_radius_top_left = 10
	back_style.corner_radius_top_right = 10
	back_style.corner_radius_bottom_left = 10
	back_style.corner_radius_bottom_right = 10
	back_btn.add_theme_stylebox_override("normal", back_style)
	var back_hover: StyleBoxFlat = back_style.duplicate()
	back_hover.bg_color = Color(0.45, 0.45, 0.5)
	back_btn.add_theme_stylebox_override("hover", back_hover)
	back_btn.position = Vector2(20, 650)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)


func _on_skin_pressed(skin_data: Dictionary) -> void:
	var skin_id: String = skin_data["id"]
	if skin_id in GameManager.owned_skins:
		GameManager.equip_skin(skin_id)
	else:
		if GameManager.buy_skin(skin_id):
			wallet_label.text = "x %d" % GameManager.total_salt_wallet
	_refresh_cards()
	preview.queue_redraw()


func _refresh_cards() -> void:
	for card in skin_cards:
		card.update_state()
		card.queue_redraw()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ============================================================
# INNER CLASSES
# ============================================================

class SkinCard extends Control:
	signal pressed
	var skin_data: Dictionary = {}
	var is_owned: bool = false
	var is_equipped: bool = false
	var hover: bool = false

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP

	func update_state() -> void:
		var skin_id: String = skin_data.get("id", "")
		is_owned = skin_id in GameManager.owned_skins
		is_equipped = GameManager.equipped_skin == skin_id

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				pressed.emit()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER:
			hover = true
			queue_redraw()
		elif what == NOTIFICATION_MOUSE_EXIT:
			hover = false
			queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y

		# Card background
		var bg_color := Color(0.15, 0.18, 0.12, 0.9)
		if is_equipped:
			bg_color = Color(0.12, 0.25, 0.1, 0.95)
		if hover:
			bg_color = bg_color.lightened(0.15)
		draw_rect(Rect2(0, 0, w, h), bg_color)

		# Border
		var border_color := Color(0.3, 0.3, 0.3)
		if is_equipped:
			border_color = Color(0.3, 0.85, 0.2)
		elif is_owned:
			border_color = Color(0.6, 0.7, 0.5)
		draw_rect(Rect2(0, 0, w, h), border_color, false, 2.0)

		# Equipped badge
		if is_equipped:
			draw_string(ThemeDB.fallback_font, Vector2(w / 2 - 28, 18), "EQUIPPED", HORIZONTAL_ALIGNMENT_CENTER, 56, 10, Color(0.3, 0.85, 0.2))

		# Cucumber preview with skin color
		var body_color: Color = skin_data.get("body", Color(0.28, 0.72, 0.18))
		var highlight_color: Color = skin_data.get("highlight", Color(0.38, 0.82, 0.28))
		var cx: float = w / 2.0
		var cy: float = 80.0
		_draw_filled_ellipse(Vector2(cx, cy), Vector2(18, 26), body_color)
		_draw_filled_ellipse(Vector2(cx - 4, cy - 2), Vector2(7, 18), highlight_color.lerp(body_color, 0.4))
		# Bumps
		draw_circle(Vector2(cx + 9, cy - 6), 2.5, body_color.darkened(0.15))
		draw_circle(Vector2(cx - 8, cy + 4), 2.0, body_color.darkened(0.15))
		# Stem
		draw_rect(Rect2(cx - 3, cy - 29, 6, 6), Color(0.2, 0.5, 0.1))
		# Eyes
		_draw_filled_ellipse(Vector2(cx - 6, cy - 4), Vector2(5, 6), Color.WHITE)
		_draw_filled_ellipse(Vector2(cx + 6, cy - 4), Vector2(4, 5), Color.WHITE)
		draw_circle(Vector2(cx - 5, cy - 4), 2.5, Color(0.1, 0.1, 0.1))
		draw_circle(Vector2(cx + 7, cy - 3), 2.0, Color(0.1, 0.1, 0.1))
		# Smile
		draw_arc(Vector2(cx, cy + 6), 4, 0.1, PI - 0.1, 8, Color(0.1, 0.1, 0.1), 1.5)

		# Name
		var name_text: String = skin_data.get("name", "Unknown")
		draw_string(ThemeDB.fallback_font, Vector2(5, 130), name_text, HORIZONTAL_ALIGNMENT_CENTER, w - 10, 12, Color(0.9, 0.9, 0.85))

		# Price / Status
		if is_owned:
			draw_string(ThemeDB.fallback_font, Vector2(5, 155), "OWNED", HORIZONTAL_ALIGNMENT_CENTER, w - 10, 14, Color(0.5, 0.8, 0.4))
		else:
			var cost: int = skin_data.get("cost", 0)
			var can_afford: bool = GameManager.total_salt_wallet >= cost
			var price_color := Color(0.9, 0.92, 1.0) if can_afford else Color(0.8, 0.3, 0.3)
			# Salt icon small
			draw_circle(Vector2(cx - 18, 150), 5, Color(0.85, 0.88, 0.95))
			draw_string(ThemeDB.fallback_font, Vector2(cx - 8, 155), str(cost), HORIZONTAL_ALIGNMENT_LEFT, 60, 14, price_color)

		# Buy/Equip hint at bottom
		if not is_owned:
			var can_afford: bool = GameManager.total_salt_wallet >= skin_data.get("cost", 0)
			if can_afford and hover:
				draw_string(ThemeDB.fallback_font, Vector2(5, h - 10), "Click to BUY", HORIZONTAL_ALIGNMENT_CENTER, w - 10, 11, Color(1.0, 0.85, 0.2))
		elif not is_equipped and hover:
			draw_string(ThemeDB.fallback_font, Vector2(5, h - 10), "Click to EQUIP", HORIZONTAL_ALIGNMENT_CENTER, w - 10, 11, Color(0.3, 0.85, 0.2))

	func _draw_filled_ellipse(center: Vector2, sz: Vector2, color: Color) -> void:
		var points: PackedVector2Array = []
		for i in range(25):
			var angle: float = float(i) / 24.0 * TAU
			points.append(center + Vector2(cos(angle) * sz.x, sin(angle) * sz.y))
		draw_colored_polygon(points, color)


class SkinPreview extends Node2D:
	var timer: float = 0.0

	func _process(delta: float) -> void:
		timer += delta
		queue_redraw()

	func _draw() -> void:
		var colors: Dictionary = GameManager.get_equipped_colors()
		var body_color: Color = colors["body"]
		var highlight: Color = colors["highlight"]
		var wobble: float = sin(timer * 1.8) * 0.05
		var bounce: float = abs(sin(timer * 1.3)) * 6.0

		draw_set_transform(Vector2(0, -bounce), wobble, Vector2(3.0, 3.0))

		# Body
		_draw_filled_ellipse(Vector2(0, 0), Vector2(18, 28), body_color)
		_draw_filled_ellipse(Vector2(-5, 0), Vector2(7, 22), highlight.lerp(body_color, 0.4))
		_draw_filled_ellipse(Vector2(4, -2), Vector2(5, 18), highlight.lerp(body_color, 0.5))

		# Bumps
		for i in range(6):
			var bx: float = sin(float(i) * 1.8) * 10.0
			var by: float = cos(float(i) * 1.3) * 14.0
			draw_circle(Vector2(bx, by), 2.5, body_color.darkened(0.15))

		# Stem
		draw_rect(Rect2(-4, -31, 8, 7), Color(0.2, 0.5, 0.1))
		var leaf_sway: float = sin(timer * 2.5) * 0.2
		var leaf_pts := PackedVector2Array([
			Vector2(4, -30),
			Vector2(12 + sin(timer * 2.0) * 2, -36),
			Vector2(14, -30),
			Vector2(8, -28),
		])
		draw_colored_polygon(leaf_pts, Color(0.25, 0.6, 0.15))

		# Eyes
		_draw_filled_ellipse(Vector2(-7, -5), Vector2(6, 7), Color.WHITE)
		_draw_filled_ellipse(Vector2(7, -5), Vector2(5, 6), Color.WHITE)
		# Irises
		var look: float = sin(timer * 0.8) * 2.0
		draw_circle(Vector2(-6 + look, -5), 3.0, Color(0.2, 0.6, 0.15))
		draw_circle(Vector2(8 + look, -4), 2.5, Color(0.2, 0.6, 0.15))
		# Pupils
		draw_circle(Vector2(-6 + look, -5), 1.8, Color(0.1, 0.1, 0.1))
		draw_circle(Vector2(8 + look, -4), 1.5, Color(0.1, 0.1, 0.1))
		# Shine
		draw_circle(Vector2(-8 + look, -7), 1.0, Color.WHITE)
		draw_circle(Vector2(6 + look, -6), 0.8, Color.WHITE)

		# Smile
		draw_arc(Vector2(0, 5), 5, 0.1, PI - 0.1, 10, Color(0.1, 0.1, 0.1), 1.5)
		# Blush
		draw_circle(Vector2(-12, 2), 3, Color(0.9, 0.5, 0.5, 0.3))
		draw_circle(Vector2(12, 2), 3, Color(0.9, 0.5, 0.5, 0.3))

		# Legs
		var leg_anim: float = sin(timer * 2.0)
		draw_line(Vector2(-6, 22), Vector2(-8 + leg_anim * 3, 34), body_color.darkened(0.2), 3.0)
		draw_line(Vector2(6, 22), Vector2(8 - leg_anim * 3, 34), body_color.darkened(0.2), 3.0)
		draw_circle(Vector2(-8 + leg_anim * 3, 35), 3, body_color.darkened(0.3))
		draw_circle(Vector2(8 - leg_anim * 3, 35), 3, body_color.darkened(0.3))

		# Arms
		var arm_anim: float = cos(timer * 2.0) * 3.0
		draw_line(Vector2(-15, -2), Vector2(-22, 6 + arm_anim), body_color.darkened(0.15), 2.5)
		draw_line(Vector2(15, -2), Vector2(22, 6 - arm_anim), body_color.darkened(0.15), 2.5)

		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

		# "Currently Equipped" text
		draw_string(ThemeDB.fallback_font, Vector2(-60, 60), GameManager.get_skin_data(GameManager.equipped_skin)["name"], HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(0.8, 0.85, 0.7))

	func _draw_filled_ellipse(center: Vector2, sz: Vector2, color: Color) -> void:
		var points: PackedVector2Array = []
		for i in range(25):
			var angle: float = float(i) / 24.0 * TAU
			points.append(center + Vector2(cos(angle) * sz.x, sin(angle) * sz.y))
		draw_colored_polygon(points, color)


class ShopSaltIcon extends Control:
	func _draw() -> void:
		var cx: float = size.x / 2.0
		var cy: float = size.y / 2.0
		var pts := PackedVector2Array([
			Vector2(cx, cy - 10),
			Vector2(cx + 8, cy),
			Vector2(cx, cy + 10),
			Vector2(cx - 8, cy),
		])
		draw_colored_polygon(pts, Color(0.85, 0.88, 0.95))
		var inner := PackedVector2Array([
			Vector2(cx, cy - 5),
			Vector2(cx + 4, cy),
			Vector2(cx, cy + 5),
			Vector2(cx - 4, cy),
		])
		draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, 0.8))
