class_name Plant
extends Node2D

const FONT_SIZES = [36, 32, 26, 24, 20, 14]

var main: Main

var current_number: int

@export var number_display: Label


var grid_position: Vector2i = Vector2i.ZERO
var prev_grid_position: Vector2i = Vector2i(0, -1)

var phys_position_move_time: float = 0
var phys_position: Vector2
var prev_phys_position: Vector2


var projectile_proto: PackedScene = preload("res://Projectile.tscn")


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
	phys_position_move_time = 0
	position = phys_position
	
	main.spawn_notif(NotifText.NotifTypes.ADD, starting_number, 0.65, phys_position + Vector2(randf_range(-30, 30), randf_range(-20, -10)))
	visible = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	phys_position_move_time += delta
	if (phys_position_move_time >= 0.35):
		phys_position_move_time = 0.35
	
	#position = phys_position
	position = lerp(prev_phys_position, phys_position, Main.ease_out_quart(phys_position_move_time / 0.35))
	
	number_display.text = Main.format_big_number(current_number)
	number_display.add_theme_font_size_override("font_size", FONT_SIZES[clampi(len(number_display.text)-1, 0, 5)])

func do_turn() -> void:
	shoot()

func shoot():
	var projectile: Projectile = projectile_proto.instantiate()
	projectile.setup(current_number, grid_position, main)
	main.projectile_holder.add_child(projectile)


func change_position(new_pos: Vector2i):
	prev_grid_position = grid_position
	grid_position = new_pos
	
	phys_position = Main.grid_to_phys(grid_position)
	prev_phys_position = Main.grid_to_phys(prev_grid_position)
	
	phys_position_move_time = 0

func take_damage(damage_to_take: int) -> void:
	current_number -= damage_to_take
	
	main.spawn_notif(NotifText.NotifTypes.SUBTRACT, damage_to_take, 0.65, phys_position + Vector2(randf_range(-30, 30), randf_range(-20, -10)))
	
	number_display.text = Main.format_big_number(current_number)
	number_display.add_theme_font_size_override("font_size", FONT_SIZES[clampi(len(number_display.text)-1, 0, 5)])
	
	if (current_number <= 0):
		die()

func die() -> void:
	queue_free()

func increment(amount: int) -> void:
	current_number += amount
	main.spawn_notif(NotifText.NotifTypes.ADD, amount, 0.65, phys_position + Vector2(randf_range(-30, 30), randf_range(-20, -10)))

func decrement(amount: int) -> void:
	take_damage(amount)

func divide_to(amount: int) -> void:
	current_number = amount
	main.spawn_notif(NotifText.NotifTypes.DIVIDE, 2, 0.65, (position + phys_position) / 2.0)
