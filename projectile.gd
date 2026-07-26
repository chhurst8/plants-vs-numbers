class_name Projectile
extends Node2D

const TILES_PER_SEC: float = 12
const FONT_SIZES = [28, 24, 20, 18, 16, 12]

var main: Main

var current_number: int

@export var number_display: Label


var grid_position: Vector2i = Vector2i.ZERO
var prev_grid_position: Vector2i = Vector2i(0, -1)

var position_move_time: float = 0
var phys_position: Vector2
var prev_phys_position: Vector2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func setup(starting_number: int, starting_position: Vector2i, _main: Main) -> void:
	current_number = starting_number
	grid_position = starting_position
	prev_grid_position = grid_position
	main = _main
	
	number_display.text = Main.format_big_number(current_number)
	number_display.add_theme_font_size_override("font_size", FONT_SIZES[clampi(len(number_display.text)-1, 0, 5)])
	
	phys_position = Main.grid_to_phys(grid_position)
	prev_phys_position = Main.grid_to_phys(prev_grid_position)
	position_move_time = 0


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	number_display.text = Main.format_big_number(current_number)
	number_display.add_theme_font_size_override("font_size", FONT_SIZES[clampi(len(number_display.text)-1, 0, 5)])
	
	position_move_time += delta
	if (position_move_time >= 1 / TILES_PER_SEC):
		position_move_time -= 1 / TILES_PER_SEC
		
		prev_grid_position = grid_position
		grid_position += Vector2i(0, -1)
		
		prev_phys_position = Main.grid_to_phys(prev_grid_position)
		phys_position = Main.grid_to_phys(grid_position)
	
	check_for_hit()
	
	position = lerp(prev_phys_position, phys_position, position_move_time*TILES_PER_SEC)
	
	if (grid_position.y <= -1 and position_move_time >= (0.8 / TILES_PER_SEC)):
		queue_free()

func check_for_hit() -> void:
	for enemy: Enemy in main.get_enemies():
		if (enemy.grid_position == grid_position):
			# We are in the same place
			enemy.take_damage(current_number)
			queue_free()
			return
