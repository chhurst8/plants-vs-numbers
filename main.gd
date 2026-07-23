class_name Main
extends Node2D


const GRID_TILE_SIZE: int = 64
const GRID_PHYS_OFFSET: Vector2 = Vector2(232, 64)


@export var global_turn_timer: Timer

var points: int = 0
var current_wave: int = 0

enum TurnOwners {
	PLAYER, ENEMY
}
var turn_owner: TurnOwners


@export var plant_holder: Node2D
var plant_proto: PackedScene = preload("res://Plant.tscn")

@export var enemy_holder: Node2D
var enemy_proto: PackedScene = preload("res://Enemy.tscn")



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# testing
	spawn_enemy(4, Vector2i(0, -1))
	
	global_turn_timer.start()
	turn_owner = TurnOwners.PLAYER


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		print(phys_to_grid(get_global_mouse_position()))


func _on_global_turn_timer_timeout() -> void:
	if (turn_owner == TurnOwners.PLAYER):
		do_player_turn()
		turn_owner = TurnOwners.ENEMY
	else:
		do_enemy_turn()
		turn_owner = TurnOwners.PLAYER
	
	global_turn_timer.start()

func do_player_turn() -> void:
	for plant: Plant in plant_holder.get_children():
		plant.do_turn()

func do_enemy_turn() -> void:
	for enemy: Enemy in enemy_holder.get_children():
		enemy.do_turn()

func spawn_enemies() -> void:
	
	pass

func spawn_enemy(starting_number: int, grid_position: Vector2i) -> void:
	var enemy: Enemy = enemy_proto.instantiate()
	enemy.setup(starting_number, grid_position, self)
	enemy_holder.add_child(enemy)


func spawn_plant(starting_number: int, grid_position: Vector2i) -> void:
	var plant: Plant = plant_proto.instantiate()
	plant.setup(starting_number, grid_position, self)
	pass


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
