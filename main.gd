class_name Main
extends Node2D


const GRID_TILE_SIZE: int = 64
const GRID_PHYS_OFFSET: Vector2 = Vector2(232, 72)

const COMBO_PURPLE: Color = Color("9700d8")
const COMBO_GREEN: Color = Color("35ff50")
const COMBO_RED: Color = Color("ff4b4b")
const COMBO_BLUE: Color = Color("3959ff")


@export var screen_transition: ScreenTransition

@export var wave_generator: WaveGenerator

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
@export var increment_label: Label

@export var ghost_plant: Node2D
@export var ghost_plant_num: Label



@export var toggle_mute_sprite: Sprite2D
@export var pause_resume_sprite: Sprite2D
@export var pause_overlay: ColorRect


var game_over: bool = false
@export var end_screen: EndScreen

var stat_enemies_killed: int
var stat_strongest_enemy_killed: int
var stat_explosions: int
var stat_best_combo: int = 0
var stat_current_good_combo: int = 0
var stat_biggest_plant: int = 0

var stat_total_score: int = 0
var score: int = 0

var produced_units: float = 0
var max_units: float = 7
var production_rate: int = 2

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

# 0 = shoot, 1 = enemy_hit, 2 = explosion, 3 = plant_crush
# 4 = increment, 5 = decrement, 6 = combine, 7 = split
# 8 = plant_grow, 9 = move_around, 10 = wave_start
@export var sfx_players: Array[AudioStreamPlayer]

func play_sfx(sfx_id: int) -> void:
	if (len(sfx_players) >= sfx_id - 1):
		sfx_players[sfx_id].play()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	get_tree().paused = false
	pause_resume_sprite.texture = preload("res://Visuals/pause.svg")
	
	if (Global.muted):
		toggle_mute_sprite.texture = preload("res://Visuals/muted.svg")
	else:
		toggle_mute_sprite.texture = preload("res://Visuals/mute.svg")
	
	game_over = false
	
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
	
	produced_units = 4
	max_units = 4
	production_rate = 0
	
	increment_label.text = "  0"
	ghost_plant.visible = false
	
	
	current_wave = 0
	
	init_wave()


func _input(event: InputEvent) -> void:
	# We need this to handle the mouse scroll buttons because they get pressed and released instantenously
	# and the chance that it happens while the frame is happening is very low
	#if (event.is_action_pressed("ScrollUp")):
	#	current_increment_amount += 1
#		if (current_increment_amount >= produced_units):
#			current_increment_amount = produced_units
	#elif (event.is_action_pressed("ScrollDown")):
	#	current_increment_amount -= 1
	#	if (current_increment_amount <= 0):
	#		current_increment_amount = 0
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# PLAYER INPUT
	ghost_plant.visible = false
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
							# there is a plant to combine / move
							if (plant_at_tile_2 != null):
								# there is a plant to combine with
								plant_at_tile_1.change_position(action_tile_2)
								plant_at_tile_1.increment(plant_at_tile_2.current_number)
								plant_at_tile_2.die()
								if (plant_at_tile_1.current_number > stat_biggest_plant): stat_biggest_plant = plant_at_tile_1.current_number
								play_sfx(6)
							else:
								# there is no plant to combine with, so we just move
								plant_at_tile_1.change_position(action_tile_2)
								play_sfx(9)
					elif (current_click.button == Click.Buttons.RIGHT):
						if (plant_at_tile_1 != null):
							# there is a plant to swap / split
							if (plant_at_tile_2 != null):
								# there is a plant to swap with, so we do
								plant_at_tile_1.change_position(action_tile_2)
								plant_at_tile_2.change_position(action_tile_1)
								play_sfx(9)
							else:
								# there is no plant to swap with, so we try to split instead
								if (plant_at_tile_1.current_number > 1):
									# the plant is big enough to split, so do it
									var number_after_split = floori(plant_at_tile_1.current_number / 2.0)
									var other_number_after_split = ceili(plant_at_tile_1.current_number / 2.0)
									
									plant_at_tile_1.change_position(action_tile_2)
									plant_at_tile_1.divide_to(number_after_split)
									
									spawn_plant(other_number_after_split, action_tile_1)
									play_sfx(7)
								else:
									# the plant is not big enough to split, so we just move it
									plant_at_tile_1.change_position(action_tile_2)
									play_sfx(9)
				
				
			else:
				# not drag
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
							play_sfx(4)
						else:
							# spawn a new plant
							spawn_plant(current_increment_amount, action_tile)
							if (current_increment_amount > stat_biggest_plant): stat_biggest_plant = current_increment_amount
							play_sfx(8)
						produced_units -= current_increment_amount
					elif (current_click.button == Click.Buttons.RIGHT):
						if (plant_at_tile != null):
							# decrease the existing plant
							plant_at_tile.decrement(1)
							produced_units += 1
							if (produced_units > 0 and current_increment_amount == 0):
								current_increment_amount = 1
							play_sfx(5)
			
			
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
						ghost_plant_num.text = str(plant_at_tile_1.current_number)
						# get ghost plant offset
						var ghost_plant_offset = Vector2(0,0)
						var center_of_tile = grid_to_phys(current_click.origin_grid)
						ghost_plant_offset = current_click.origin_phys - center_of_tile
						#print(ghost_plant_offset)
						ghost_plant.position = get_global_mouse_position() - ghost_plant_offset
						ghost_plant.visible = true
				
	
	#UPDATE HUD
	hud_score_display.text = "Score\n" + str(score)

	#produced_units = ceili(produced_units)
	factory_display.text = format_big_number(floori(produced_units)) + "\n" + format_big_number(floori(max_units))
	factory_rate_display.text = "+" + format_big_number(production_rate)

	current_increment_amount = min(current_increment_amount, floori(produced_units))

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
		var tween_rot = closest_enemy_indicator.create_tween()
		tween_rot.tween_property(closest_enemy_indicator, "rotation_degrees", 360, 0.4).set_trans(Tween.TRANS_BACK)
		
		var tween_scale = closest_enemy_indicator.create_tween()
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

		var prev_produced: int = produced_units

		# produced_units += production_rate
		
		if (produced_units > 0 and prev_produced == 0 and current_increment_amount == 0):
			current_increment_amount = 1
		
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
		
		var spawned_all = false
		if (len(enemies_remaining_in_wave.keys()) < 2):
			spawned_all = true
		else:
			if (current_turn > enemies_remaining_in_wave.keys().max()):
				spawned_all = true
		
		if enemy_holder.get_child_count() == 0 && spawned_all && current_turn > 1:
			print_debug("next wave")
			current_turn = 0
			next_wave()
			#global_turn_timer.start()
			#return
		else:
			#print("spawning enemies")
			current_turn += 1
			if (enemies_remaining_in_wave.has(current_turn)):
				var wave = enemies_remaining_in_wave[current_turn]
				for enemy in wave:
					spawn_enemy(enemy["number"], Vector2i(enemy["position"], -2), enemy["difficulty"])
			do_enemy_turn()
		turn_owner = TurnOwners.PLAYER
	
	global_turn_timer.start()

func do_player_turn() -> void:
	if (plant_holder.get_child_count() > 0):
		play_sfx(0)
		for plant: Plant in plant_holder.get_children():
			plant.do_turn()

func do_enemy_turn() -> void:
	for enemy: Enemy in enemy_holder.get_children():
		enemy.do_turn()

func init_wave() -> void:
	#rng.seed = current_wave
	rng.randomize()
	
	if(current_wave == 0):
		enemies_remaining_in_wave = {}
		return
	
	var existing_board_state: Array[int] = get_existing_board_state()
	print("existing board state: " + str(existing_board_state))
	var enemies_from_generator = wave_generator.make_solution(current_wave, max_units, produced_units, existing_board_state)
	
	current_turn = 0
	
	var line = 0
	for enemy_line in enemies_from_generator:
		line += 1
		enemies_remaining_in_wave[line] = []
		var spot = 0
		for number in enemy_line:
			spot += 1
			if (number == 0):
				continue
			var difficulty_index
			if (wave_generator.wave_high_end == wave_generator.wave_low_end):
				difficulty_index = 1
			else:
				difficulty_index = roundi((number - wave_generator.wave_low_end) / (wave_generator.wave_high_end - wave_generator.wave_low_end)) * 2
			enemies_remaining_in_wave[line].append({ "difficulty": difficulty_index, "position": spot-1, "number": number })
	
	#var boss = round(0.333333 * pow(current_wave, 2) + 3 * (current_wave) + 0.666667) #round((3.68354 + 1.74921 * log(current_wave)) * rng.randf_range(0.9, 1.1)) # round((2 * pow(1.5, 2)) * rng.randf_range(0.9, 1.1));
	#var boss_factors = factors(boss)
	#while len(boss_factors) < 4:
		#boss += 1
		#boss_factors = factors(boss)
#
	#print("boss of wave %s: %s" % [str(current_wave), str(boss)] )
	#var num_enemies = round((1.68354 + 1.74921 * log(current_wave)) * rng.randf_range(0.8, 1.2)) # round(3 * (2) * rng.randf_range(0.6, 1.4))
	#print("#enemies of wave %s: %s" % [str(current_wave), str(num_enemies)] )
	#var boss_placed = false
	#enemies_remaining_in_wave = {}
	#var line = 0
	#while num_enemies > 0:
		#line += 1
		#var enemies_in_line = min(round(min(pow(rng.randf(), 3), 1) * num_enemies), 5)
		##if line == 1:
		#enemies_in_line = max(1, enemies_in_line)
		#enemies_remaining_in_wave[line] = []
		#num_enemies -= enemies_in_line
		#var occupied_spots = []
		#for i in enemies_in_line:
#
			#var is_boss = !boss_placed && (rng.randf() > 0.2 || num_enemies == 0)
			#var difficulty = rng.randf_range(0.2, 0.6)
			#var number = 0
			#var meta_inf = {}
			#if is_boss:
				#number = boss
			#elif difficulty > 0.5:
				#number = ceili(difficulty * boss)
			#else:
				#var factor = boss_factors[rng.randi_range(0, len(boss_factors) - 2)]
				#var boss_multiple = boss / factor
				#meta_inf["boss_multiple"] = boss_multiple
				#meta_inf["difficulty"] = difficulty
				#meta_inf["factor"] = factor
				#number = ceili(boss_multiple * difficulty) * factor
			## var number = boss if is_boss else round(difficulty * boss)
			#if is_boss:
				#boss_placed = true
			#var spot = rng.randi_range(0, 5 - 1)
			#while occupied_spots.has(spot):
				#spot = rng.randi_range(0, 5 - 1)
			#occupied_spots.append(spot)
			#var difficulty_index = 2 if is_boss else 1 if difficulty > 0.5 else 0 
			#enemies_remaining_in_wave[line].append({"difficulty": difficulty_index, "position": spot, "number": number, "meta": meta_inf})
	print("enemies of wave %s: %s" % [str(current_wave), str(enemies_remaining_in_wave)] )

func factors(number: int) -> Array[int]:
	var factors: Array[int] = []
	for i in number:
		if number % (i+1) == 0:
			factors.append(i + 1)
	return factors



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
				#print("explosion at " + str(explosion_position) + " damaged enemy at " + str(enemy.grid_position))
	
	stat_explosions += 1
	
	
	# create the visual explosion
	var explosion: Explosion = explosion_proto.instantiate()
	explosion.setup(explosion_damage, grid_to_phys(explosion_position))
	explosion_holder.add_child(explosion)
	
	play_sfx(2)

func get_enemies() -> Array[Node]:
	return enemy_holder.get_children()

func get_plant_at_tile(grid_point: Vector2i) -> Plant:
	for plant: Plant in plant_holder.get_children():
		if (plant.grid_position == grid_point):
			return plant
	return null

func get_existing_board_state() -> Array[int]:
	var result: Array[int] = [0, 0, 0, 0, 0]
	for plant: Plant in plant_holder.get_children():
		result[plant.grid_position.x] += plant.current_number
	return result

func enemy_death(dead_enemy: Enemy, is_exploding: bool = false) -> void:
	var enemy_number = dead_enemy.starting_number
	if (enemy_number > stat_strongest_enemy_killed): stat_strongest_enemy_killed = enemy_number
	stat_enemies_killed += 1
	
	
	# gain score
	var score_gained: int = roundi(enemy_number * get_combo_multiplier())
	if (is_exploding): score_gained = score_gained * 2
	#print("score gained: " + str(score_gained))
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



func _on_recall_button_pressed() -> void:
	print("recall")
	
	var units_to_recall: int = 0
	# kill all plants
	for plant: Plant in plant_holder.get_children():
		units_to_recall += plant.current_number
		plant.die()
	
	# give back the units
	produced_units += units_to_recall
	if (produced_units >= 1 and current_increment_amount == 0):
		current_increment_amount = 1



func next_wave():
	current_wave += 1
	hud_wave_anim_time = 0
	produced_units += 0.5
	max_units += 0.5
	if (produced_units >= 1 and current_increment_amount == 0):
		current_increment_amount = 1
	play_sfx(10)
	#print("next wave")
	init_wave()


func lose_game() -> void:
	increment_label.hide()
	ghost_plant.hide()
	
	play_sfx(11)
	game_over = true
	end_screen.game_end(stat_total_score, current_wave, stat_best_combo, stat_enemies_killed, stat_explosions, stat_strongest_enemy_killed, stat_biggest_plant)
	get_tree().paused = true


func _on_retry_button_pressed() -> void:
	if (end_screen.anim_time > 1.4):
		screen_transition.transition_to("main.tscn")

func _on_home_menu_button_pressed() -> void:
	if (end_screen.anim_time > 1.4):
		screen_transition.transition_to("home.tscn")


func _on_pause_resume_pressed() -> void:
	var _paused = get_tree().paused
	
	if (!game_over):
		if (_paused):
			pause_overlay.visible = false
			pause_resume_sprite.texture = preload("res://Visuals/pause.svg")
			Global.resume_music()
		else:
			pause_overlay.visible = true
			pause_resume_sprite.texture = preload("res://Visuals/resume.svg")
			Global.pause_music()
	
		get_tree().paused = !_paused


func _on_toggle_mute_pressed() -> void:
	Global.toggle_mute()
	if (Global.muted):
		toggle_mute_sprite.texture = preload("res://Visuals/muted.svg")
	else:
		toggle_mute_sprite.texture = preload("res://Visuals/mute.svg")


static func format_big_number(current_number: int) -> String:
	if current_number < 1000:
		return str(current_number)
	else:
		var magnitude = magnitude(current_number)
		var mantissa = current_number / (pow(10,magnitude))
		if (magnitude >= 10):
			return str("%.1f" % mantissa) + "e" + str(magnitude)
		else:
			return str("%.2f" % mantissa) + "e" + str(magnitude)

static func magnitude(number: int) -> int:
	return max(floor((log(number))/(log(10))),0)


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
