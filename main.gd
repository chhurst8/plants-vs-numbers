class_name Main
extends Node2D


const GRID_TILE_SIZE: int = 64
const GRID_PHYS_OFFSET: Vector2 = Vector2(232, 64)


@export var global_turn_timer: Timer

var points: int = 0
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
var max_increment_amount: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	init_wave()
	
	global_turn_timer.start()
	turn_owner = TurnOwners.PLAYER
	
	current_click = null
	current_increment_amount = 1
	max_increment_amount = 1


func _input(event: InputEvent) -> void:
	# We need this to handle the mouse scroll buttons because they get pressed and released instantenously
	# and the chance that it happens while the frame is happening is very low
	if (event.is_action_pressed("ScrollUp")):
		current_increment_amount += 1
		if (current_increment_amount >= max_increment_amount):
			current_increment_amount = max_increment_amount
	elif (event.is_action_pressed("ScrollDown")):
		current_increment_amount -= 1
		if (current_increment_amount <= 1):
			current_increment_amount = 1

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
		
		print(current_click)
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
							else:
								# there is no plant to combine with, so we split instead
								var number_after_split = floori(plant_at_tile_1.current_number / 2.0)
								var other_number_after_split = ceili(plant_at_tile_1.current_number / 2.0)
								
								plant_at_tile_1.change_position(action_tile_2)
								plant_at_tile_1.divide_to(number_after_split)
								spawn_plant(other_number_after_split, action_tile_1)
			else:
				var should_do_action: bool = true
				var action_tile: Vector2i
				if (are_we_even_close_to_a_valid_tile(current_click.origin_grid)):
					action_tile = get_closest_valid_tile(current_click.origin_grid)
				else:
					# we were probably trying to click on some other UI button far away or whatever
					should_do_action = false
				
				if (should_do_action):
					# We are going to do a click action right now, let's check the context to see if there is already a plant there
					var plant_at_tile: Plant = get_plant_at_tile(action_tile)
					if (current_click.button == Click.Buttons.LEFT):
						if (plant_at_tile != null):
							# increase the existing plant
							plant_at_tile.increment(current_increment_amount)
						else:
							# spawn a new plant
							spawn_plant(current_increment_amount, action_tile)
					elif (current_click.button == Click.Buttons.RIGHT):
						if (plant_at_tile != null):
							# decrease the existing plant
							plant_at_tile.decrement(current_increment_amount)
			
			
			current_click = null
	
	


func _on_global_turn_timer_timeout() -> void:
	if (turn_owner == TurnOwners.PLAYER):
		do_player_turn()
		turn_owner = TurnOwners.ENEMY
	else:
		current_turn += 1
		if (enemies_remaining_in_wave.has(current_turn)):
			var wave = enemies_remaining_in_wave[current_turn]
			for enemy in wave:
				spawn_enemy(enemy["number"], Vector2i(enemy["position"], -2))
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
	rng.seed = current_wave
	var boss = roundf((2 * pow(2, current_wave)) * rng.randf_range(0.9, 1.1));
	var num_enemies = roundf(3 * (current_wave + 1) * rng.randf_range(0.6, 1.4))
	print_debug(num_enemies)
	var boss_placed = false
	enemies_remaining_in_wave = {}
	var line = 0
	while num_enemies > 0:
		line += 1
		var enemies_in_line = roundf(min(1 / rng.randf(), 1) * num_enemies)
		enemies_remaining_in_wave[line] = []
		num_enemies -= enemies_in_line
		var occupied_spots = []
		for i in enemies_in_line:
			var is_boss = !boss_placed && (rng.randf() > 0.5 || num_enemies == 0)
			if is_boss:
				boss_placed = true
			var spot = rng.randi_range(0, 4 - 1)
			while occupied_spots.has(spot):
				spot = rng.randi_range(0, 4 - 1)
			occupied_spots.append(spot)
			enemies_remaining_in_wave[line].append({"position": spot, "number": boss})
	print_debug(enemies_remaining_in_wave)

func spawn_enemies() -> void:
	
	pass

func spawn_enemy(starting_number: int, grid_position: Vector2i) -> void:
	var enemy: Enemy = enemy_proto.instantiate()
	enemy.setup(starting_number, grid_position, self)
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
	
	#TODO: create the visual explosion

func get_enemies() -> Array[Node]:
	return enemy_holder.get_children()

func get_plant_at_tile(grid_point: Vector2i) -> Plant:
	for plant: Plant in plant_holder.get_children():
		if (plant.grid_position == grid_point):
			return plant
	return null

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
