class_name Enemy
extends Node2D

var main: Main

var starting_number: int
var current_number: int

@export var number_display: Label


var grid_position: Vector2i = Vector2i.ZERO
var prev_grid_position: Vector2i = Vector2i(0, -1)

var phys_position: Vector2
var prev_phys_position: Vector2

enum EnemyAnimations {
	MOVE,
	ATTACK
}
var current_animation: EnemyAnimations
var anim_time: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func setup(_starting_number: int, starting_position: Vector2i, _main: Main) -> void:
	starting_number = _starting_number
	current_number = starting_number
	grid_position = starting_position
	prev_grid_position = grid_position
	main = _main
	
	number_display.text = str(current_number)
	
	phys_position = Main.grid_to_phys(grid_position)
	prev_phys_position = Main.grid_to_phys(prev_grid_position)
	anim_time = 0
	
	current_animation = EnemyAnimations.MOVE


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	anim_time += delta
	if (anim_time >= 1):
		anim_time = 1
	
	match current_animation:
		EnemyAnimations.MOVE:
			position = lerp(prev_phys_position, phys_position, Main.ease_in_out_quad(anim_time))
			
			if (grid_position.y >= 10):
				if (anim_time >= 1):
					print("zombie got to bottom. lose")
					main.lose_game()
		EnemyAnimations.ATTACK:
			if (anim_time <= 0.1):
				position = lerp(phys_position, phys_position + Vector2(0, Main.GRID_TILE_SIZE*0.45), Main.ease_in_back(anim_time / 0.1))
			else:
				position = lerp(phys_position + Vector2(0, Main.GRID_TILE_SIZE*0.45), phys_position, Main.ease_out_sine((anim_time - 0.1) / 0.9))
	
	

func do_turn() -> void:
	var plant_in_front: Plant = main.get_plant_at_tile(grid_position + Vector2i(0, 1))
	var plant_can_survive_attack: bool = false
	if (plant_in_front != null):
		if (plant_in_front.current_number > current_number):
			plant_can_survive_attack = true
		
		plant_in_front.take_damage(current_number)
	
	if (plant_can_survive_attack):
		prev_grid_position = grid_position
		phys_position = Main.grid_to_phys(grid_position)
		prev_phys_position = Main.grid_to_phys(prev_grid_position)
		anim_time = 0
		current_animation = EnemyAnimations.ATTACK
	else:
		prev_grid_position = grid_position
		grid_position = grid_position + Vector2i(0, 1)
		phys_position = Main.grid_to_phys(grid_position)
		prev_phys_position = Main.grid_to_phys(prev_grid_position)
		anim_time = 0
		current_animation = EnemyAnimations.MOVE
	


func take_damage(damage_to_take: int) -> void:
	current_number -= damage_to_take
	
	main.spawn_notif(NotifText.NotifTypes.SUBTRACT, damage_to_take, 0.65, phys_position + Vector2(randf_range(-30, 30), randf_range(-20, -10)))
	
	number_display.text = str(current_number)
	
	if (current_number == 0):
		explode()
	if (current_number < 0):
		die()

func explode() -> void:
	main.enemy_death(self)
	# TODO: queue free, give the player points, and spawn an explosion which damages other enemies in a 3x3 area
	queue_free()
	
	main.spawn_explosion(starting_number, grid_position, self)

func die() -> void:
	main.enemy_death(self)
	# TODO: queue free and also give the player points
	queue_free()
	pass
