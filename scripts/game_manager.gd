extends Node

## Global game state manager (Autoload singleton) - Phase 3

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
signal boss_spawned(biome: int)
signal boss_defeated(biome: int)
signal skin_changed(skin_id: String)
signal tutorial_step(step: int)
signal play_sound(sound_name: String)
signal pause_toggled(is_paused: bool)

# Score & collectibles
var score: int = 0
var salt_collected: int = 0
var total_salt_ever: int = 0
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
var is_paused: bool = false
var distance_traveled: float = 0.0
var game_speed_multiplier: float = 1.0
var enemies_killed: int = 0
var obstacles_dodged: int = 0
var bosses_defeated: int = 0

# Biome system
enum Biome { GARDEN, KITCHEN, FRIDGE }
var current_biome: Biome = Biome.GARDEN
var biome_distance: float = 0.0
const BIOME_CHANGE_INTERVAL: float = 800.0

# Boss system
var is_boss_active: bool = false
var boss_hp: int = 0
var boss_max_hp: int = 0
var chunks_since_biome_change: int = 0
const BOSS_SPAWN_CHUNKS: int = 8

# Difficulty scaling
var difficulty: float = 1.0
const DIFFICULTY_RATE: float = 0.02

# Shop / Skins
var total_salt_wallet: int = 0
var owned_skins: Array[String] = ["default"]
var equipped_skin: String = "default"

var skin_catalog: Array[Dictionary] = [
	{"id": "default", "name": "Classic Cucumber", "cost": 0, "body": Color(0.28, 0.72, 0.18), "highlight": Color(0.38, 0.82, 0.28)},
	{"id": "golden", "name": "Golden Gherkin", "cost": 100, "body": Color(0.85, 0.75, 0.2), "highlight": Color(0.95, 0.88, 0.4)},
	{"id": "ice", "name": "Frozen Pickle", "cost": 150, "body": Color(0.5, 0.75, 0.9), "highlight": Color(0.7, 0.88, 0.95)},
	{"id": "fire", "name": "Chili Cucumber", "cost": 200, "body": Color(0.85, 0.25, 0.15), "highlight": Color(0.95, 0.45, 0.25)},
	{"id": "galaxy", "name": "Space Pickle", "cost": 300, "body": Color(0.3, 0.15, 0.5), "highlight": Color(0.5, 0.3, 0.7)},
	{"id": "rainbow", "name": "Rainbow Cuke", "cost": 500, "body": Color(0.9, 0.4, 0.6), "highlight": Color(0.4, 0.8, 0.9)},
]

# Tutorial
var tutorial_completed: bool = false
var tutorial_step_index: int = 0
const TUTORIAL_STEPS: int = 4

# Achievements
var achievements_unlocked: Array[String] = []
var achievement_defs: Array[Dictionary] = [
	{"id": "first_salt", "title": "Salty Start", "desc": "Collect your first salt!", "check": "salt_collected >= 1"},
	{"id": "salt_50", "title": "Salt Addict", "desc": "Collect 50 salt crystals", "check": "salt_collected >= 50"},
	{"id": "salt_200", "title": "Sodium Overload", "desc": "Collect 200 salt crystals", "check": "salt_collected >= 200"},
	{"id": "salt_500", "title": "Dead Sea", "desc": "Collect 500 salt crystals", "check": "salt_collected >= 500"},
	{"id": "combo_5", "title": "Combo Starter", "desc": "Get a 5x combo!", "check": "combo >= 5"},
	{"id": "combo_15", "title": "Combo Master", "desc": "Get a 15x combo!", "check": "combo >= 15"},
	{"id": "combo_30", "title": "Combo Legend", "desc": "Get a 30x combo!", "check": "combo >= 30"},
	{"id": "distance_500", "title": "Marathon Cucumber", "desc": "Travel 500 meters", "check": "distance_traveled >= 500"},
	{"id": "distance_2000", "title": "Unstoppable Veggie", "desc": "Travel 2000 meters", "check": "distance_traveled >= 2000"},
	{"id": "distance_5000", "title": "World Runner", "desc": "Travel 5000 meters", "check": "distance_traveled >= 5000"},
	{"id": "chili_3", "title": "Fire Breather", "desc": "Stack 3 chilis at once!", "check": "chili_stacks >= 3"},
	{"id": "kill_5", "title": "Veggie Warrior", "desc": "Defeat 5 enemies", "check": "enemies_killed >= 5"},
	{"id": "kill_20", "title": "Kitchen Nightmare", "desc": "Defeat 20 enemies", "check": "enemies_killed >= 20"},
	{"id": "kill_50", "title": "Salad Slayer", "desc": "Defeat 50 enemies", "check": "enemies_killed >= 50"},
	{"id": "shield_use", "title": "Yogurt Shield", "desc": "Use a yogurt shield", "check": "shield_hits > 0"},
	{"id": "boss_1", "title": "Boss Basher", "desc": "Defeat your first boss", "check": "bosses_defeated >= 1"},
	{"id": "boss_3", "title": "Boss Destroyer", "desc": "Defeat 3 bosses", "check": "bosses_defeated >= 3"},
	{"id": "rich", "title": "Salt Millionaire", "desc": "Have 1000 salt in wallet", "check": "total_salt_wallet >= 1000"},
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
	"Blended into oblivion!",
	"The mixer wins... AGAIN.",
	"You've been julienned!",
]

# Biome-specific colors
var biome_colors: Dictionary = {
	Biome.GARDEN: {"sky_top": Color(0.4, 0.7, 0.95), "sky_bottom": Color(0.85, 0.92, 0.98), "ground": Color(0.35, 0.6, 0.2)},
	Biome.KITCHEN: {"sky_top": Color(0.9, 0.85, 0.75), "sky_bottom": Color(0.95, 0.9, 0.85), "ground": Color(0.6, 0.5, 0.4)},
	Biome.FRIDGE: {"sky_top": Color(0.7, 0.85, 0.95), "sky_bottom": Color(0.85, 0.92, 0.98), "ground": Color(0.75, 0.82, 0.9)},
}


func _ready() -> void:
	load_save_data()


func _process(delta: float) -> void:
	if is_paused or is_game_over:
		return

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
	if biome_distance >= BIOME_CHANGE_INTERVAL and not is_boss_active:
		biome_distance = 0.0
		chunks_since_biome_change = 0
		var next_biome: int = (current_biome + 1) % 3
		current_biome = next_biome as Biome
		biome_changed.emit(current_biome)

	# Difficulty scaling
	difficulty = 1.0 + (distance_traveled / 100.0) * DIFFICULTY_RATE


func toggle_pause() -> void:
	is_paused = not is_paused
	get_tree().paused = is_paused
	pause_toggled.emit(is_paused)


func add_salt(amount: int = 1) -> void:
	combo += 1
	combo_timer = COMBO_WINDOW
	combo_changed.emit(combo)

	var combo_multiplier: int = mini(combo, 10)
	var points: int = amount * 10 * combo_multiplier

	salt_collected += amount
	total_salt_ever += amount
	total_salt_wallet += amount
	score += points

	score_changed.emit(score)
	salt_changed.emit(salt_collected)
	play_sound.emit("collect_salt")
	_check_achievements()


func activate_chili() -> void:
	chili_stacks = mini(chili_stacks + 1, MAX_CHILI_STACKS)
	chili_timer = chili_duration
	is_chili_active = true
	chili_activated.emit(chili_duration)
	play_sound.emit("chili")
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
	play_sound.emit("shield")
	_check_achievements()


func end_shield() -> void:
	is_shield_active = false
	shield_timer = 0.0
	shield_ended.emit()


func use_shield_hit() -> bool:
	if is_shield_active:
		shield_hits += 1
		play_sound.emit("shield_hit")
		if shield_hits >= 3:
			end_shield()
		_check_achievements()
		return true
	return false


func activate_oil() -> void:
	is_oil_active = true
	oil_timer = oil_duration
	oil_activated.emit()
	play_sound.emit("oil")


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
	play_sound.emit("enemy_kill")
	_check_achievements()


# Boss system
func spawn_boss() -> void:
	if is_boss_active:
		return
	is_boss_active = true
	match current_biome:
		Biome.GARDEN:
			boss_max_hp = 5
		Biome.KITCHEN:
			boss_max_hp = 7
		Biome.FRIDGE:
			boss_max_hp = 10
	boss_hp = boss_max_hp
	boss_spawned.emit(current_biome)
	play_sound.emit("boss_appear")


func damage_boss(amount: int = 1) -> void:
	if not is_boss_active:
		return
	boss_hp -= amount
	play_sound.emit("boss_hit")
	if boss_hp <= 0:
		defeat_boss()


func defeat_boss() -> void:
	is_boss_active = false
	bosses_defeated += 1
	score += 500
	score_changed.emit(score)
	boss_defeated.emit(current_biome)
	play_sound.emit("boss_defeat")
	_check_achievements()


func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	play_sound.emit("die")

	if score > high_score:
		high_score = score
		save_save_data()

	player_died.emit()


func get_random_game_over_message() -> String:
	return game_over_messages[randi() % game_over_messages.size()]


# Shop
func buy_skin(skin_id: String) -> bool:
	for skin in skin_catalog:
		if skin["id"] == skin_id:
			var cost: int = skin["cost"]
			if total_salt_wallet >= cost and skin_id not in owned_skins:
				total_salt_wallet -= cost
				owned_skins.append(skin_id)
				save_save_data()
				play_sound.emit("purchase")
				return true
	return false


func equip_skin(skin_id: String) -> void:
	if skin_id in owned_skins:
		equipped_skin = skin_id
		skin_changed.emit(skin_id)
		save_save_data()


func get_skin_data(skin_id: String) -> Dictionary:
	for skin in skin_catalog:
		if skin["id"] == skin_id:
			return skin
	return skin_catalog[0]


func get_equipped_colors() -> Dictionary:
	var data: Dictionary = get_skin_data(equipped_skin)
	return {"body": data["body"], "highlight": data["highlight"]}


# Tutorial
func advance_tutorial() -> void:
	tutorial_step_index += 1
	tutorial_step.emit(tutorial_step_index)
	if tutorial_step_index >= TUTORIAL_STEPS:
		tutorial_completed = true
		save_save_data()


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
	is_paused = false
	is_boss_active = false
	boss_hp = 0
	distance_traveled = 0.0
	difficulty = 1.0
	game_speed_multiplier = 1.0
	enemies_killed = 0
	obstacles_dodged = 0
	current_biome = Biome.GARDEN
	biome_distance = 0.0
	chunks_since_biome_change = 0
	get_tree().paused = false


func _check_achievements() -> void:
	for achievement in achievement_defs:
		if achievement["id"] in achievements_unlocked:
			continue
		var expr := Expression.new()
		var err := expr.parse(achievement["check"], ["salt_collected", "combo", "distance_traveled", "chili_stacks", "enemies_killed", "shield_hits", "bosses_defeated", "total_salt_wallet"])
		if err == OK:
			var result = expr.execute([salt_collected, combo, distance_traveled, chili_stacks, enemies_killed, shield_hits, bosses_defeated, total_salt_wallet])
			if result == true:
				achievements_unlocked.append(achievement["id"])
				achievement_unlocked.emit(achievement["title"], achievement["desc"])
				play_sound.emit("achievement")


func save_save_data() -> void:
	var file := FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_var(high_score)
		file.store_var(total_salt_wallet)
		file.store_var(total_salt_ever)
		file.store_var(owned_skins)
		file.store_var(equipped_skin)
		file.store_var(achievements_unlocked)
		file.store_var(tutorial_completed)


func load_save_data() -> void:
	if FileAccess.file_exists("user://save.dat"):
		var file := FileAccess.open("user://save.dat", FileAccess.READ)
		if file:
			high_score = file.get_var()
			total_salt_wallet = file.get_var()
			total_salt_ever = file.get_var()
			owned_skins = file.get_var()
			equipped_skin = file.get_var()
			achievements_unlocked = file.get_var()
			tutorial_completed = file.get_var()
