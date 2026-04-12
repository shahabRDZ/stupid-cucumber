extends Node

## Global game state manager (Autoload singleton)

signal score_changed(new_score: int)
signal salt_changed(new_salt: int)
signal chili_activated(duration: float)
signal chili_ended
signal player_died
signal combo_changed(combo: int)
signal shield_activated
signal shield_ended
signal oil_activated
signal oil_ended
signal biome_changed(biome: int)
signal achievement_unlocked(title: String, description: String)
signal enemy_killed(enemy_type: String)

# Score & collectibles
var score: int = 0
var salt_collected: int = 0
var total_salt: int = 0
var high_score: int = 0
var combo: int = 0
var combo_timer: float = 0.0
const COMBO_WINDOW: float = 1.5

# Chili state
var is_chili_active: bool = false
var chili_timer: float = 0.0
var chili_duration: float = 4.0
var chili_stacks: int = 0
const MAX_CHILI_STACKS: int = 3

# Shield state (yogurt)
var is_shield_active: bool = false
var shield_timer: float = 0.0
var shield_duration: float = 6.0
var shield_hits: int = 0

# Oil boost state
var is_oil_active: bool = false
var oil_timer: float = 0.0
var oil_duration: float = 5.0

# Game state
var is_game_over: bool = false
var distance_traveled: float = 0.0
var game_speed_multiplier: float = 1.0
var enemies_killed: int = 0
var obstacles_dodged: int = 0

# Biome system
enum Biome { GARDEN, KITCHEN, FRIDGE }
var current_biome: Biome = Biome.GARDEN
var biome_distance: float = 0.0
const BIOME_CHANGE_INTERVAL: float = 800.0

# Difficulty scaling
var difficulty: float = 1.0
const DIFFICULTY_RATE: float = 0.02

# Achievements
var achievements_unlocked: Array[String] = []
var achievement_defs: Array[Dictionary] = [
	{"id": "first_salt", "title": "Salty Start", "desc": "Collect your first salt!", "check": "salt_collected >= 1"},
	{"id": "salt_50", "title": "Salt Addict", "desc": "Collect 50 salt crystals", "check": "salt_collected >= 50"},
	{"id": "salt_200", "title": "Sodium Overload", "desc": "Collect 200 salt crystals", "check": "salt_collected >= 200"},
	{"id": "combo_5", "title": "Combo Starter", "desc": "Get a 5x combo!", "check": "combo >= 5"},
	{"id": "combo_15", "title": "Combo Master", "desc": "Get a 15x combo!", "check": "combo >= 15"},
	{"id": "distance_500", "title": "Marathon Cucumber", "desc": "Travel 500 meters", "check": "distance_traveled >= 500"},
	{"id": "distance_2000", "title": "Unstoppable Veggie", "desc": "Travel 2000 meters", "check": "distance_traveled >= 2000"},
	{"id": "chili_3", "title": "Fire Breather", "desc": "Stack 3 chilis at once!", "check": "chili_stacks >= 3"},
	{"id": "kill_5", "title": "Veggie Warrior", "desc": "Defeat 5 enemies", "check": "enemies_killed >= 5"},
	{"id": "kill_20", "title": "Kitchen Nightmare", "desc": "Defeat 20 enemies", "check": "enemies_killed >= 20"},
	{"id": "shield_use", "title": "Yogurt Shield", "desc": "Use a yogurt shield", "check": "shield_hits > 0"},
]

# Funny game over messages
var game_over_messages: Array[String] = [
	"Too much salt bro...",
	"You got PICKLED!",
	"Cucumber down! I repeat, cucumber DOWN!",
	"That was NOT a-peeling...",
	"You've been CHOPPED!",
	"Salad time... for YOU!",
	"The kitchen won this round.",
	"Rest in pickles.",
	"You got tossed... like a salad!",
	"Vitamin C ya later!",
	"Sliced and diced!",
	"The fridge claimed another victim...",
	"You got seasoned... permanently.",
	"Fork-ed up!",
	"That knife had your name on it.",
]

# Biome-specific colors
var biome_colors: Dictionary = {
	Biome.GARDEN: {"sky_top": Color(0.4, 0.7, 0.95), "sky_bottom": Color(0.85, 0.92, 0.98), "ground": Color(0.35, 0.6, 0.2)},
	Biome.KITCHEN: {"sky_top": Color(0.9, 0.85, 0.75), "sky_bottom": Color(0.95, 0.9, 0.85), "ground": Color(0.6, 0.5, 0.4)},
	Biome.FRIDGE: {"sky_top": Color(0.7, 0.85, 0.95), "sky_bottom": Color(0.85, 0.92, 0.98), "ground": Color(0.75, 0.82, 0.9)},
}


func _ready() -> void:
	load_high_score()


func _process(delta: float) -> void:
	# Combo timer
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo = 0
			combo_changed.emit(combo)

	# Chili timer
	if is_chili_active:
		chili_timer -= delta
		if chili_timer <= 0:
			end_chili()

	# Shield timer
	if is_shield_active:
		shield_timer -= delta
		if shield_timer <= 0:
			end_shield()

	# Oil timer
	if is_oil_active:
		oil_timer -= delta
		if oil_timer <= 0:
			end_oil()

	# Biome cycling
	biome_distance += delta * game_speed_multiplier * 10.0
	if biome_distance >= BIOME_CHANGE_INTERVAL:
		biome_distance = 0.0
		var next_biome: int = (current_biome + 1) % 3
		current_biome = next_biome as Biome
		biome_changed.emit(current_biome)

	# Difficulty scaling
	difficulty = 1.0 + (distance_traveled / 100.0) * DIFFICULTY_RATE


func add_salt(amount: int = 1) -> void:
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)

	var combo_multiplier: int = mini(combo, 10)
	var points: int = amount * 10 * combo_multiplier

	salt_collected += amount
	total_salt += amount
	score += points

	score_changed.emit(score)
	salt_changed.emit(salt_collected)
	_check_achievements()


func activate_chili() -> void:
	chili_stacks = mini(chili_stacks + 1, MAX_CHILI_STACKS)
	chili_timer = chili_duration
	is_chili_active = true
	chili_activated.emit(chili_duration)
	_check_achievements()


func end_chili() -> void:
	is_chili_active = false
	chili_stacks = 0
	chili_timer = 0.0
	chili_ended.emit()


func activate_shield() -> void:
	is_shield_active = true
	shield_timer = shield_duration
	shield_hits = 0
	shield_activated.emit()
	_check_achievements()


func end_shield() -> void:
	is_shield_active = false
	shield_timer = 0.0
	shield_ended.emit()


func use_shield_hit() -> bool:
	if is_shield_active:
		shield_hits += 1
		if shield_hits >= 3:
			end_shield()
		_check_achievements()
		return true
	return false


func activate_oil() -> void:
	is_oil_active = true
	oil_timer = oil_duration
	oil_activated.emit()


func end_oil() -> void:
	is_oil_active = false
	oil_timer = 0.0
	oil_ended.emit()


func add_distance(dist: float) -> void:
	distance_traveled += dist
	score += int(dist * 0.1)
	score_changed.emit(score)
	_check_achievements()


func on_enemy_killed(enemy_type: String) -> void:
	enemies_killed += 1
	score += 50
	score_changed.emit(score)
	enemy_killed.emit(enemy_type)
	_check_achievements()


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true

	if score > high_score:
		high_score = score
		save_high_score()

	player_died.emit()


func get_random_game_over_message() -> String:
	return game_over_messages[randi() % game_over_messages.size()]


func restart_game() -> void:
	score = 0
	salt_collected = 0
	combo = 0
	combo_timer = 0.0
	is_chili_active = false
	chili_timer = 0.0
	chili_stacks = 0
	is_shield_active = false
	shield_timer = 0.0
	shield_hits = 0
	is_oil_active = false
	oil_timer = 0.0
	is_game_over = false
	distance_traveled = 0.0
	difficulty = 1.0
	game_speed_multiplier = 1.0
	enemies_killed = 0
	obstacles_dodged = 0
	current_biome = Biome.GARDEN
	biome_distance = 0.0


func _check_achievements() -> void:
	for achievement in achievement_defs:
		if achievement["id"] in achievements_unlocked:
			continue
		var expr := Expression.new()
		var err := expr.parse(achievement["check"], ["salt_collected", "combo", "distance_traveled", "chili_stacks", "enemies_killed", "shield_hits"])
		if err == OK:
			var result = expr.execute([salt_collected, combo, distance_traveled, chili_stacks, enemies_killed, shield_hits])
			if result == true:
				achievements_unlocked.append(achievement["id"])
				achievement_unlocked.emit(achievement["title"], achievement["desc"])


func save_high_score() -> void:
	var file := FileAccess.open("user://highscore.save", FileAccess.WRITE)
	if file:
		file.store_var(high_score)


func load_high_score() -> void:
	if FileAccess.file_exists("user://highscore.save"):
		var file := FileAccess.open("user://highscore.save", FileAccess.READ)
		if file:
			high_score = file.get_var()
