extends Node2D

## Main game scene orchestrator
## Wires up player, camera, level generator, HUD, and game over screen

var player: CharacterBody2D
var camera: Camera2D
var level_gen: Node2D
var hud: CanvasLayer
var game_over: CanvasLayer
var parallax_bg: ParallaxBackground


func _ready() -> void:
	# -- PARALLAX BACKGROUND --
	parallax_bg = load("res://scripts/parallax_bg.gd").new()
	add_child(parallax_bg)

	# -- PLAYER --
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(200, 400)
	player.collision_layer = 1
	player.collision_mask = 2  # collide with platforms

	# Player collision shape
	var player_shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14.0
	capsule.height = 48.0
	player_shape.shape = capsule
	player.add_child(player_shape)

	# Attach player script
	var player_script = load("res://scripts/player.gd")
	player.set_script(player_script)
	player.add_to_group("player")

	add_child(player)

	# -- CAMERA --
	camera = Camera2D.new()
	camera.name = "GameCamera"
	var camera_script = load("res://scripts/camera_controller.gd")
	camera.set_script(camera_script)
	camera.target = player
	camera.position = player.position
	add_child(camera)
	camera.make_current()

	# Link parallax to camera
	parallax_bg.camera = camera

	# -- LEVEL GENERATOR --
	level_gen = Node2D.new()
	level_gen.name = "LevelGenerator"
	var level_script = load("res://scripts/level_generator.gd")
	level_gen.set_script(level_script)
	level_gen.player = player
	add_child(level_gen)

	# -- HUD --
	var hud_script = load("res://scripts/hud.gd")
	hud = CanvasLayer.new()
	hud.set_script(hud_script)
	hud.player = player
	add_child(hud)

	# -- GAME OVER SCREEN --
	var go_script = load("res://scripts/game_over_screen.gd")
	game_over = CanvasLayer.new()
	game_over.set_script(go_script)
	add_child(game_over)

	# -- PAUSE SCREEN --
	var pause_script = load("res://scripts/pause_screen.gd")
	var pause_screen := CanvasLayer.new()
	pause_screen.set_script(pause_script)
	add_child(pause_screen)

	# -- TUTORIAL (first play only) --
	if not GameManager.tutorial_completed:
		var tut_script = load("res://scripts/tutorial_overlay.gd")
		var tutorial := CanvasLayer.new()
		tutorial.set_script(tut_script)
		add_child(tutorial)

	# -- WORLD BOUNDARY (kill zone below) --
	var kill_zone := Area2D.new()
	kill_zone.position = Vector2(0, 1000)
	kill_zone.collision_layer = 4
	kill_zone.collision_mask = 1
	var kz_shape := CollisionShape2D.new()
	var kz_rect := RectangleShape2D.new()
	kz_rect.size = Vector2(100000, 20)
	kz_shape.shape = kz_rect
	kill_zone.add_child(kz_shape)
	kill_zone.body_entered.connect(_on_kill_zone_entered)
	add_child(kill_zone)


func _on_kill_zone_entered(body: Node2D) -> void:
	if body == player and player.has_method("die"):
		player.die()
