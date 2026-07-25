class_name Main
extends Node2D


const GRID_TILE_SIZE: int = 64
const GRID_PHYS_OFFSET: Vector2 = Vector2(232, 64)

const COMBO_PURPLE: Color = Color("9700d8")
const COMBO_GREEN: Color = Color("35ff50")
const COMBO_RED: Color = Color("ff4b4b")
const COMBO_BLUE: Color = Color("3959ff")


@export var screen_transition: ScreenTransition

@export var global_turn_timer: Timer

@export var clock_thing: TextureProgressBar
@export var closest_enemy_indicator: Label
var closest_enemy_distance: int

@export var combo_letter: Label
@export var combo_bar: TextureProgressBar
var combo_amount: int = 0
var combo_anim_time: float = 0
var any_enemies_killed_this_turn: bool = false
var kill_drought: int = 0
var prev_combo_bar_value: float = 0

@export var hud_wave_indicator: Label
var hud_wave_anim_time: float = 0

@export var hud_score_display: Label
@export var factory_display: Label
@export var factory_rate_display: Label
@export var factory_price_display: Label
@export var increment_label: Label

@export var ghost_plant: Node2D
@export var ghost_plant_num: Label


@export var end_screen: EndScreen

var stat_enemies_killed: int
var stat_strongest_enemy_killed: int
var stat_explosions: int
var stat_best_combo: int = 0
var stat_current_good_combo: int = 0
var stat_biggest_plant: int = 0

var stat_total_score: int = 0
var score: int = 0

var produced_units: int = 0
var max_units: int = 7
var production_rate: int = 2
var factory_upgrade_price: int = 100

var current_wave: int = 0
var enemies_remaining_in_wave = {}
var current_turn: int = 0

enum TurnOwners {
	PLAYER, ENEMY
}
var turn_owner: TurnOwners
var rng = RandomNumberGenerator.new()


@export var plant_holder: Node2D
var plant_proto: PackedScene = preload("res://Plant.tscn")

@export var projectile_holder: Node2D
@export var explosion_holder: Node2D
var explosion_proto: PackedScene = preload("res://Explosion.tscn")

@export var notif_holder: Node2D
var notif_proto: PackedScene = preload("res://NotifText.tscn")

@export var enemy_holder: Node2D
var enemy_proto: PackedScene = preload("res://Enemy.tscn")


class Click:
	enum Buttons {LEFT, RIGHT}
	var button: Buttons
	
	var origin_phys: Vector2
	var origin_grid: Vector2i

	var release_phys: Vector2
	var release_grid: Vector2i
	
	var hold_time: float = 0
	
	func _init(_button: Buttons, _origin_phys: Vector2) -> void:
		button = _button
		origin_phys = _origin_phys
		origin_grid = Main.phys_to_grid(origin_phys)
		hold_time = 0
	
	func release(_release_phys: Vector2) -> void:
		release_phys = _release_phys
		release_grid = Main.phys_to_grid(release_phys)
	
	func _to_string() -> String:
		return Buttons.keys()[button] + " Click started at " + str(origin_grid) + ", held for " + str(hold_time)

var current_click: Click

var current_increment_amount: int
#var max_increment_amount: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = false
	
	global_turn_timer.start()
	turn_owner = TurnOwners.PLAYER
	
	current_click = null
	current_increment_amount = 1
	#max_increment_amount = 1
	
	score = 0
	stat_enemies_killed = 0
	stat_strongest_enemy_killed = 0
	stat_explosions = 0
	stat_best_combo = 0
	stat_current_good_combo = 0
	stat_biggest_plant = 0
	
	closest_enemy_distance = 10
	closest_enemy_indicator.text = str(closest_enemy_distance)
	
	combo_amount = 0
	any_enemies_killed_this_turn = false
	kill_drought = 0
	combo_anim_time = 1
	
	combo_letter.hide()
	combo_bar.hide()
	
	hud_wave_indicator.text = ""
	hud_wave_anim_time = 2
	
	factory_display.text = ""
	factory_rate_display.text = ""
	factory_price_display.text = "Price\n50"
	
	produced_units = 0
	production_rate = 2
	factory_upgrade_price = 100
	
	increment_label.text = "  0"
	ghost_plant.visible = false
	
	
	current_wave = 0
	
	init_wave()


func _input(event: InputEvent) -> void:
	# We need this to handle the mouse scroll buttons because they get pressed and released instantenously
	# and the chance that it happens while the frame is happening is very low
	if (event.is_action_pressed("ScrollUp")):
		current_increment_amount += 1
		if (current_increment_amount >= produced_units):
			current_increment_amount = produced_units
	elif (event.is_action_pressed("ScrollDown")):
		current_increment_amount -= 1
		if (current_increment_amount <= 0):
			current_increment_amount = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# PLAYER INPUT
	if (current_click == null):
		if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			current_click = Click.new(Click.Buttons.LEFT, get_global_mouse_position())
		elif (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
			current_click = Click.new(Click.Buttons.RIGHT, get_global_mouse_position())
	else:
		var released: bool = false
		
		#print(current_click)
		current_click.hold_time += delta
		if (current_click.button == Click.Buttons.LEFT):
			if (! Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
				current_click.release(get_global_mouse_position())
				released = true
		elif (current_click.button == Click.Buttons.RIGHT):
			if (! Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
				current_click.release(get_global_mouse_position())
				released = true
		
		if (released):
			var drag: bool = false
			if (current_click.origin_grid != current_click.release_grid):
				# We probably dragged
				if (current_click.hold_time <= 0.1):
					# But if it was only for a tiny amount of time then it was probably meant to be a click then move the mouse elsewhere
					drag = false
				else: drag = true
			
			
			if (drag):
				ghost_plant.visible = false
				
				var should_do_action: bool = true
				var action_tile_1: Vector2i
				var action_tile_2: Vector2i
				if (are_we_even_close_to_a_valid_tile(current_click.origin_grid)):
					action_tile_1 = get_closest_valid_tile(current_click.origin_grid)
					action_tile_2 = get_closest_valid_tile(current_click.release_grid)
				else:
					# we were probably trying to click on some other UI button far away or whatever
					should_do_action = false
				
				if (should_do_action):
					# We are going to do a click action right now, let's check the context to see if there are already plants there
					var plant_at_tile_1: Plant = get_plant_at_tile(action_tile_1)
					var plant_at_tile_2: Plant = get_plant_at_tile(action_tile_2)
					if (current_click.button == Click.Buttons.LEFT):
						if (plant_at_tile_1 != null):
							# there is a plant to move
							if (plant_at_tile_2 != null):
								# there is a plant to swap with
								plant_at_tile_1.change_position(action_tile_2)
								plant_at_tile_2.change_position(action_tile_1)
							else:
								# there is no plant to swap with
								plant_at_tile_1.change_position(action_tile_2)
					elif (current_click.button == Click.Buttons.RIGHT):
						if (plant_at_tile_1 != null):
							# there is a plant to combine / split
							if (plant_at_tile_2 != null):
								# there is a plant to combine with
								plant_at_tile_1.change_position(action_tile_2)
								plant_at_tile_1.increment(plant_at_tile_2.current_number)
								plant_at_tile_2.die()
								if (plant_at_tile_1.current_number > stat_biggest_plant): stat_biggest_plant = plant_at_tile_1.current_number
							else:
								# there is no plant to combine with, so we try to split instead
								if (plant_at_tile_1.current_number > 1):
									# the plant is big enough to split, so do it
									var number_after_split = floori(plant_at_tile_1.current_number / 2.0)
									var other_number_after_split = ceili(plant_at_tile_1.current_number / 2.0)
									
									plant_at_tile_1.change_position(action_tile_2)
									plant_at_tile_1.divide_to(number_after_split)
									
									spawn_plant(other_number_after_split, action_tile_1)
								else:
									# the plant is not big enough to split, so we just move it
									plant_at_tile_1.change_position(action_tile_2)
			else:
				ghost_plant.visible = false
				
				var should_do_action: bool = true
				var action_tile: Vector2i
				if (get_closest_valid_tile(current_click.origin_grid) == current_click.origin_grid):
					action_tile = get_closest_valid_tile(current_click.origin_grid)
				else:
					# we were probably trying to click on some other UI button far away or whatever
					should_do_action = false
				
				if (should_do_action):
					# We are going to do a click action right now, let's check the context to see if there is already a plant there
					var plant_at_tile: Plant = get_plant_at_tile(action_tile)
					if (current_click.button == Click.Buttons.LEFT && current_increment_amount != 0):
						if (plant_at_tile != null):
							# increase the existing plant
							plant_at_tile.increment(current_increment_amount)
							if (plant_at_tile.current_number > stat_biggest_plant): stat_biggest_plant = plant_at_tile.current_number
						else:
							# spawn a new plant
							spawn_plant(current_increment_amount, action_tile)
							if (current_increment_amount > stat_biggest_plant): stat_biggest_plant = current_increment_amount
						produced_units -= current_increment_amount
					elif (current_click.button == Click.Buttons.RIGHT):
						if (plant_at_tile != null):
							# decrease the existing plant
							plant_at_tile.decrement(1)
			
			
			current_click = null
		else:
			# still dragging possibly
			ghost_plant.visible = false
			
			var drag: bool = false
			if (current_click.origin_grid != phys_to_grid(get_global_mouse_position())):
				# We probably dragged
				if (current_click.hold_time <= 0.1):
					# But if it was only for a tiny amount of time then it was probably meant to be a click then move the mouse elsewhere
					drag = false
				else: drag = true
			
			if (drag):
				# check if we are dragging a plant
				var action_tile_1: Vector2i
				if (are_we_even_close_to_a_valid_tile(current_click.origin_grid)):
					action_tile_1 = get_closest_valid_tile(current_click.origin_grid)
					# We are going to do a click action right now, let's check the context to see if there are already plants there
					var plant_at_tile_1: Plant = get_plant_at_tile(action_tile_1)
					
					if (plant_at_tile_1 != null):
						
						ghost_plant.visible = true
						ghost_plant_num.text = str(plant_at_tile_1.current_number)
						# get ghost plant offset
						var ghost_plant_offset = Vector2(0,0)
						var center_of_tile = grid_to_phys(current_click.origin_grid)
						ghost_plant_offset = current_click.origin_phys - center_of_tile
						#print(ghost_plant_offset)
						ghost_plant.position = get_global_mouse_position() - ghost_plant_offset
				
	
	#UPDATE HUD
	hud_score_display.text = "Score\n" + str(score)

	factory_display.text = str(produced_units) + "/" + str(max_units)
	factory_rate_display.text = "+" + str(production_rate)
	factory_price_display.text = "Price\n" + str(factory_upgrade_price)

	current_increment_amount = min(current_increment_amount, produced_units)

	increment_label.text = "  " + str(current_increment_amount)
	
	if (turn_owner == TurnOwners.PLAYER):
		clock_thing.value = lerp(0, 180, clampf(1 - global_turn_timer.time_left, 0, 1))
	else:
		clock_thing.value = lerp(180, 360, clampf(1 - global_turn_timer.time_left, 0, 1))

	
	var furthest_along_dist: int = -3
	if (enemy_holder.get_child_count() > 0):
		for enemy: Enemy in enemy_holder.get_children():
			if (enemy.grid_position.y > furthest_along_dist): furthest_along_dist = enemy.grid_position.y
	var prev_closest_enemy_distance = closest_enemy_distance
	closest_enemy_distance = clampi(10 - furthest_along_dist, 0, 10)
	if (closest_enemy_distance != prev_closest_enemy_distance):
		# the closest enemy distance has changed
		closest_enemy_indicator.text = str(closest_enemy_distance)
		closest_enemy_indicator.rotation_degrees = 0
		var tween_rot = get_tree().create_tween()
		tween_rot.tween_property(closest_enemy_indicator, "rotation_degrees", 360, 0.4).set_trans(Tween.TRANS_BACK)
		
		var tween_scale = get_tree().create_tween()
		tween_scale.tween_property(closest_enemy_indicator, "scale", Vector2(1.2, 1.2), 0.2)
		tween_scale.tween_property(closest_enemy_indicator, "scale", Vector2(1.0, 1.0), 0.2)
	
	if(combo_anim_time < 1):
		combo_anim_time += delta
		if (combo_anim_time <= 0.1):
			var _letter_scale = lerpf(1.0, 1.1, combo_anim_time / 0.1)
			combo_letter.scale = Vector2(_letter_scale, _letter_scale)
		elif (combo_anim_time <= 0.2):
			var _letter_scale = lerpf(1.1, 1.0, ease_out_cubic((combo_anim_time - 0.1) / 0.1))
			combo_letter.scale = Vector2(_letter_scale, _letter_scale)
		if (combo_anim_time <= 0.4):
			var new_combo_bar_value: float = 0.0
			if (combo_amount <= 3):
				new_combo_bar_value = (combo_amount) * (100.0 / 3.0)
			elif (combo_amount <= 6):
				new_combo_bar_value = (combo_amount - 3) * (100.0 / 3.0)
			elif (combo_amount <= 8):
				new_combo_bar_value = (combo_amount - 6) * (100.0 / 2.0)
			elif (combo_amount <= 10):
				new_combo_bar_value = (combo_amount - 8) * (100.0 / 2.0)
			
			combo_bar.value = lerpf(prev_combo_bar_value, new_combo_bar_value, ease_out_quart(combo_anim_time / 0.4))
	
	
	hud_wave_indicator.text = "Wave " + str(current_wave)
	if(hud_wave_anim_time < 2.5):
		hud_wave_anim_time += delta
		if (hud_wave_anim_time <= 0.8):
			var _indicator_scale = lerpf(1.0, 1.25, ease_out_cubic(hud_wave_anim_time / 0.8))
			hud_wave_indicator.scale = Vector2(_indicator_scale, _indicator_scale)
		elif(hud_wave_anim_time >= 1.2 and hud_wave_anim_time <= 2.2):
			var _indicator_scale = lerpf(1.25, 1.0, ease_in_quad((hud_wave_anim_time - 1.2) / 1.0))
			hud_wave_indicator.scale = Vector2(_indicator_scale, _indicator_scale)
		
		if (hud_wave_anim_time >= 0.4 and hud_wave_anim_time <= 1.9):
			hud_wave_indicator.rotation_degrees = sin(((hud_wave_anim_time-0.4)/1.5)*8*PI)*lerpf(7, 2, (hud_wave_anim_time-0.4)/1.5)
		else:
			hud_wave_indicator.rotation_degrees = 0


func _on_global_turn_timer_timeout() -> void:
	if (turn_owner == TurnOwners.PLAYER):
		do_player_turn()

		produced_units += production_rate
		produced_units = min(produced_units, max_units)

		turn_owner = TurnOwners.ENEMY
	else:
		# it is the enemy turn
		# BUT first handle the combo thing
		if (any_enemies_killed_this_turn):
			kill_drought = 0
		else:
			kill_drought += 1
			
			var new_combo_amount: int = 0
			if (kill_drought <= 2):
				new_combo_amount = combo_amount - 1
			elif (kill_drought <= 4):
				new_combo_amount = combo_amount - 2
			else:
				new_combo_amount = combo_amount - 3
			
			update_combo_hud(new_combo_amount)
		any_enemies_killed_this_turn = false
		
		if (combo_amount <= 3):
			prev_combo_bar_value = (combo_amount) * (100.0 / 3.0)
		elif (combo_amount <= 6):
			prev_combo_bar_value = (combo_amount - 3) * (100.0 / 3.0)
		elif (combo_amount <= 8):
			prev_combo_bar_value = (combo_amount - 6) * (100.0 / 2.0)
		elif (combo_amount <= 10):
			prev_combo_bar_value = (combo_amount - 8) * (100.0 / 2.0)
		#prev_combo_bar_value = combo_bar.value
		
		if enemy_holder.get_child_count() == 0 && current_turn > 1:
			print_debug("next wave")
			current_turn = 0
			next_wave()
			#global_turn_timer.start()
			#return
		else:
			current_turn += 1
			if (enemies_remaining_in_wave.has(current_turn)):
				var wave = enemies_remaining_in_wave[current_turn]
				for enemy in wave:
					spawn_enemy(enemy["number"], Vector2i(enemy["position"], -2), enemy["difficulty"])
			do_enemy_turn()
		turn_owner = TurnOwners.PLAYER
	
	global_turn_timer.start()

func do_player_turn() -> void:
	for plant: Plant in plant_holder.get_children():
		plant.do_turn()

func do_enemy_turn() -> void:
	for enemy: Enemy in enemy_holder.get_children():
		enemy.do_turn()

func init_wave() -> void:
	print("hi")
	rng.seed = current_wave
	current_turn = 0
	var boss = round((2 * pow(1.5, current_wave + 1)) * rng.randf_range(0.9, 1.1));
	var num_enemies = round(3 * (current_wave + 1) * rng.randf_range(0.6, 1.4))
	print_debug(num_enemies)
	var boss_placed = false
	enemies_remaining_in_wave = {}
	var line = 0
	print_debug("about to spawn enemies")
	while num_enemies > 0:
		print_debug(num_enemies)
		line += 1
		var enemies_in_line = min(round(min(pow(rng.randf(), 3), 1) * num_enemies), 4)
		enemies_remaining_in_wave[line] = []
		num_enemies -= enemies_in_line
		var occupied_spots = []
		print_debug(enemies_in_line)
		for i in enemies_in_line:
			var is_boss = !boss_placed && (rng.randf() > 0.5 || num_enemies == 0)
			var difficulty = rng.randf_range(0.2, 0.6)
			var number = boss if is_boss else round(difficulty * boss)
			if is_boss:
				boss_placed = true
			var spot = rng.randi_range(0, 5 - 1)
			while occupied_spots.has(spot):
				spot = rng.randi_range(0, 5 - 1)
			occupied_spots.append(spot)
			var difficulty_index = 2 if is_boss else 1 if difficulty > 0.5 else 0 
			enemies_remaining_in_wave[line].append({"difficulty": difficulty_index, "position": spot, "number": number})
	print_debug(enemies_remaining_in_wave)


func spawn_enemy(starting_number: int, grid_position: Vector2i, difficulty: int) -> void:
	var enemy: Enemy = enemy_proto.instantiate()
	enemy.setup(starting_number, grid_position, self)
	if difficulty == 1:
		enemy.get_node("NumberDisplay").add_theme_color_override("font_color", Color.YELLOW)
	elif difficulty == 2:
		enemy.get_node("NumberDisplay").add_theme_color_override("font_color", Color.RED)

	enemy_holder.add_child(enemy)



func spawn_plant(starting_number: int, grid_position: Vector2i) -> void:
	var plant: Plant = plant_proto.instantiate()
	plant.setup(starting_number, grid_position, self)
	plant_holder.add_child(plant)


func spawn_notif(notif_type: NotifText.NotifTypes, notif_number: int, notif_lifespan: float, _pos: Vector2) -> void:
	var notif: NotifText = notif_proto.instantiate()
	notif.setup(notif_type, notif_number, notif_lifespan, _pos)
	notif_holder.add_child(notif)

func spawn_explosion(explosion_damage: int, explosion_position: Vector2i, exploding_enemy: Enemy) -> void:
	for enemy: Enemy in enemy_holder.get_children():
		if (enemy != exploding_enemy):
			if (enemy.grid_position.x >= explosion_position.x - 1 and enemy.grid_position.x <= explosion_position.x + 1
			and enemy.grid_position.y >= explosion_position.y - 1 and enemy.grid_position.y <= explosion_position.y + 1):
				enemy.take_damage(explosion_damage)
				print("explosion at " + str(explosion_position) + " damaged enemy at " + str(enemy.grid_position))
	
	stat_explosions += 1
	
	
	# create the visual explosion
	var explosion: Explosion = explosion_proto.instantiate()
	explosion.setup(explosion_damage, grid_to_phys(explosion_position))
	explosion_holder.add_child(explosion)

func get_enemies() -> Array[Node]:
	return enemy_holder.get_children()

func get_plant_at_tile(grid_point: Vector2i) -> Plant:
	for plant: Plant in plant_holder.get_children():
		if (plant.grid_position == grid_point):
			return plant
	return null

func enemy_death(dead_enemy: Enemy, is_exploding: bool = false) -> void:
	var enemy_number = dead_enemy.starting_number
	if (enemy_number > stat_strongest_enemy_killed): stat_strongest_enemy_killed = enemy_number
	stat_enemies_killed += 1
	
	
	# gain score
	var score_gained: int = roundi(enemy_number * get_combo_multiplier())
	if (is_exploding): score_gained = score_gained * 2
	print("score gained: " + str(score_gained))
	score += score_gained
	stat_total_score += score_gained
	spawn_notif(NotifText.NotifTypes.ADD, score_gained, 0.35, hud_score_display.position + (hud_score_display.size/2) + Vector2(randf_range(-20, 20), randf_range(-10, 10)))
	
	# update the combo counter
	any_enemies_killed_this_turn = true
	if (is_exploding):
		increase_combo(2)
	else:
		increase_combo(1)

func increase_combo(amount: int) -> void:
	var new_combo_amount = combo_amount + amount
	update_combo_hud(new_combo_amount)

func update_combo_hud(new_combo_amount: int) -> void:
	#var old_combo_amount: int = combo_amount
	combo_amount = new_combo_amount
	if (combo_amount > 10): combo_amount = 10
	if (combo_amount < 0): combo_amount = 0
	
	combo_anim_time = 0
	
	if (combo_amount == 0):
		combo_letter.hide()
		combo_bar.hide()
		
		stat_current_good_combo = 0
	else:
		combo_letter.show()
		combo_bar.show()
		
		if (combo_amount <= 3):
			combo_letter.text = "C"
			combo_letter.add_theme_color_override("font_color", COMBO_BLUE)
			combo_bar.tint_progress = COMBO_BLUE
			
			stat_current_good_combo = 0
		elif (combo_amount <= 6):
			combo_letter.text = "B"
			combo_letter.add_theme_color_override("font_color", COMBO_RED)
			combo_bar.tint_progress = COMBO_RED
			
			stat_current_good_combo = 0
		elif (combo_amount <= 8):
			combo_letter.text = "A"
			combo_letter.add_theme_color_override("font_color", COMBO_GREEN)
			combo_bar.tint_progress = COMBO_GREEN
			
			stat_current_good_combo += 1
			if (stat_current_good_combo > stat_best_combo): stat_best_combo = stat_current_good_combo
		elif (combo_amount <= 10):
			combo_letter.text = "S"
			combo_letter.add_theme_color_override("font_color", COMBO_PURPLE)
			combo_bar.tint_progress = COMBO_PURPLE
			
			stat_current_good_combo += 1
			if (stat_current_good_combo > stat_best_combo): stat_best_combo = stat_current_good_combo

func get_combo_multiplier() -> float:
	if (combo_amount > 0):
		if (combo_amount <= 3):
			# C = 1.5x
			return (1.5)
		elif (combo_amount <= 6):
			# B = 2.0x
			return (2.0)
		elif (combo_amount <= 8):
			# A = 3.0x
			return (3.0)
		elif (combo_amount <= 10):
			# S = 5.0x
			return (5.0)
		else:
			return (1.0)
	else:
		# No combo
		return (1.0)



func _on_upgrade_factory_button_pressed() -> void:
	print("upgrade factory")
	if (score >= factory_upgrade_price):
		score -= factory_upgrade_price
		# increase production rate
		production_rate = ceili(production_rate * 1.25)
		
		# increase factory upgrade price
		factory_upgrade_price = ceili(factory_upgrade_price * 1.25)
		max_units = ceili(max_units * 1.25)





func next_wave():
	current_wave += 1
	hud_wave_anim_time = 0
	print("next wave")
	init_wave()


func lose_game() -> void:
	increment_label.hide()
	ghost_plant.hide()
	
	end_screen.game_end(stat_total_score, current_wave, stat_best_combo, stat_enemies_killed, stat_explosions, stat_strongest_enemy_killed, stat_biggest_plant)
	get_tree().paused = true


func _on_retry_button_pressed() -> void:
	if (end_screen.anim_time > 1.4):
		screen_transition.transition_to("main.tscn")

func _on_home_menu_button_pressed() -> void:
	if (end_screen.anim_time > 1.4):
		screen_transition.transition_to("home.tscn")


static func are_we_even_close_to_a_valid_tile(grid_point: Vector2i) -> bool:
	var closest_valid: Vector2i = get_closest_valid_tile(grid_point)
	return (closest_valid.distance_to(grid_point) <= 2)

static func get_closest_valid_tile(grid_point: Vector2i) -> Vector2i:
	var new_point: Vector2i = grid_point
	if (! grid_point.x >= 0): new_point.x = 0
	if (! grid_point.x <= 4): new_point.x = 4
	if (! grid_point.y >= 0): new_point.y = 0
	if (! grid_point.y <= 9): new_point.y = 9
	
	return (new_point)

static func grid_to_phys(_grid_pos: Vector2i) -> Vector2:
	var _pos: Vector2 = Vector2.ZERO
	
	_pos.x = (_grid_pos.x * GRID_TILE_SIZE) + GRID_PHYS_OFFSET.x
	_pos.y = (_grid_pos.y * GRID_TILE_SIZE) + GRID_PHYS_OFFSET.y
	
	return _pos

static func phys_to_grid(_pos: Vector2) -> Vector2i:
	var _grid_pos: Vector2 = Vector2.ZERO
	
	_grid_pos.x = roundi((_pos.x - GRID_PHYS_OFFSET.x) / GRID_TILE_SIZE)
	_grid_pos.y = roundi((_pos.y - GRID_PHYS_OFFSET.y) / GRID_TILE_SIZE)
	
	return _grid_pos

static func ease_in_out_quad(t: float) -> float:
	return ((t*t)/((t*t) + ((1-t)*(1-t))))

static func ease_out_quart(t: float) -> float:
	return (1 - pow(1-t, 4))

static func ease_out_sine(t: float) -> float:
	return sin(PI*t / 2)

static func ease_out_cubic(t: float) -> float:
	return (1 - (pow(1-t, 3)))

static func ease_in_cubic(t: float) -> float:
	return (t*t*t)

static func ease_in_quad(t: float) -> float:
	return(t*t)

static func ease_in_back(t: float) -> float:
	var _c1 = 1.70158
	var _c3 = _c1 + 1
	return ((_c3*t*t*t) - (_c1*t*t))

static func ease_out_bounce(t: float) -> float:
	var _n1 = 7.5625
	var _d1 = 2.75
	
	if (t < 1 / _d1):
		return (_n1 * t * t)
	elif (t < 2 / _d1):
		var _x2 = t - (1.5 / _d1)
		return (_n1 * _x2 * _x2 + 0.75)
	elif (t < 2.5 / _d1):
		var _x2 = t - (2.25 / _d1)
		return (_n1 * _x2 * _x2 + 0.9375)
	else:
		var _x2 = t - (2.625 / _d1)
		return (_n1 * _x2 * _x2 + 0.984375)
