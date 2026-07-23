class_name Enemy
extends Node2D

var main: Main

var starting_number: int
var current_number: int

@export var number_display: Label


var grid_position: Vector2i = Vector2i.ZERO
var prev_grid_position: Vector2i = Vector2i(0, -1)

var phys_position_move_time: float = 0
var phys_position: Vector2
var prev_phys_position: Vector2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func setup(_starting_number: int, starting_position: Vector2i, _main: Main) -> void:
	starting_number = _starting_number
	grid_position = starting_position
	prev_grid_position = grid_position
	main = _main
	
	number_display.text = str(current_number)
	
	phys_position = Main.grid_to_phys(grid_position)
	prev_phys_position = Main.grid_to_phys(prev_grid_position)
	phys_position_move_time = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	phys_position_move_time += delta
	if (phys_position_move_time >= 1):
		phys_position_move_time = 1
	
	
	position = lerp(prev_phys_position, phys_position, ease_in_out_quad(phys_position_move_time))

func do_turn() -> void:
	prev_grid_position = grid_position
	grid_position = grid_position + Vector2i(0, 1)
	phys_position = Main.grid_to_phys(grid_position)
	prev_phys_position = Main.grid_to_phys(prev_grid_position)
	phys_position_move_time = 0

func ease_in_out_quad(t: float) -> float:
	return ((t*t)/((t*t) + ((1-t)*(1-t))))


func take_damage(damage_to_take: int) -> void:
	current_number -= damage_to_take
	
	number_display.text = str(current_number)
	
	if (current_number == 0):
		explode()
	if (current_number < 0):
		die()

func explode() -> void:
	pass

func die() -> void:
	pass
