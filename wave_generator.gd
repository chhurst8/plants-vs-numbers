class_name WaveGenerator
extends Node2D


var solution = [] #(number of internal lists is shots)
var enemies = []
var place_enemy = []
var dead = []

var wave_low_end: int = 0
var wave_high_end: int = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	solution = []

func make_solution(level_num: int, maximum_point_capacity: int, _points_left_to_place: int, existing_board_state: Array[int]) -> Array:
	# Make the solution - 
	var max_lines_to_solve = 8 - min((3 - floor(level_num/3.0)), 0) # makes it 5,5,6,6,6,7,7,7,8,8,8,8,8,8,...
	var extra_rows = randi_range(3, 7)
	var shots = max_lines_to_solve + extra_rows

	var max_towers_to_solve = max(floor((level_num+12.0)/5.0), 5) # makes it 2, 2, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 5, ....

	var points_left_to_place = _points_left_to_place
	#first step of solution maker - 
	solution = [] #(number of internal lists is shots)
	for i in range(shots):
		solution.append([0, 0, 0, 0, 0])
	
	#print(solution)
	
	# build first line of solution
	print("points left to place: " + str(points_left_to_place))
	solution[0] = existing_board_state
	for i in range(max_towers_to_solve):
		var column = randi_range(0,4)
		var points = randi_range(0, points_left_to_place)
		solution[0][column] += points
		points_left_to_place -= points

	var swap_or_move_probability = clampi(roundi(level_num*10.6)+5, 0, 80)
	var combine_or_move_probability = clampi(roundi(level_num*10.8)+3, 0, 75)
	var split_or_split_merge_probability = clampi(roundi(level_num*0.8)-1, 0, 10)

	#building full solution - 
	for i in range(shots-1):
		solution[i+1] = solution[i].duplicate()
		
		var largest_tower: int = (solution[i+1]).max()
		
		#print("line " + str(i+1) + ": " + str(solution[i+1]))
		if randi_range(0, 100) < swap_or_move_probability: #this will do both swapping and moving, as a move is a swap with a 0 tower
			swap(solution[i+1].duplicate(), i+1, randi_range(0,4), randi_range(0,4), largest_tower) # for all of these theres a chance it picks the same row to "move" to, meaning nothing will happen, but honestly that seems fine with me as its all random chance anyway
		
		largest_tower = (solution[i+1]).max()
		if randi_range(0, 100) < combine_or_move_probability: #this will do both combining and moving, as a move is a combine with a 0 tower
			combine(solution[i+1].duplicate(), i+1, randi_range(0,4), randi_range(0,4), largest_tower)
		
		largest_tower = (solution[i+1]).max()
		if randi_range(0, 100) < split_or_split_merge_probability: #this will do both splitting and split and then merge
			split(solution[i+1].duplicate(), i+1, randi_range(0,4), randi_range(0,4), largest_tower)
		
		#print("line " + str(i+1) + ": " + str(solution[i+1]))
	
	print("solution: " + str(solution))
	
	var placed_literally_noone: bool = true
	enemies = []
	place_enemy = []
	dead = []
	for i in range(extra_rows+1):
		enemies.append([0,0,0,0,0])
		
		var row = []
		for j in range(0, 5):
			if (randi_range(0, 1) == 0):
				row.append(false)
			else:
				row.append(true)
				placed_literally_noone = false
		place_enemy.append(row)
		
		dead.append([false,false,false,false,false])
	if(placed_literally_noone):
		place_enemy[0][2] = true
	
	
	for shot_num in range(shots):
		for column in range(0,4):
			for onscreen_row in range(min(shot_num, extra_rows+1)):
				if ((place_enemy[onscreen_row][column]) and (not dead[onscreen_row][column])):
					enemies[onscreen_row][column] += solution[shot_num][column]
					var explode_chance = clamp((enemies[onscreen_row][column] * 2) + 9, 20, 80)
					if (randi_range(0, 100) < explode_chance * enemies[onscreen_row][column]):
						dead[onscreen_row][column] = true
						explode(onscreen_row, column, enemies[onscreen_row][column])
	
	print("enemies before: " + str(enemies))
	var valid: bool = false
	while (! valid): 
		if (len(enemies) <= 0):
			enemies = [[0, 0, 4, 0, 0], [0, 0, 4, 0, 0]]
			valid = true
		else:
			if (enemies[0] == [0, 0, 0, 0, 0]):
				enemies.pop_front()
			else:
				if (enemies[-1] == [0, 0, 0, 0, 0]):
					enemies.pop_back()
				else:
					valid = true
	
	wave_low_end = 0
	wave_high_end = 0
	for i in enemies:
		for j in i:
			var current_enemy = j
			if (current_enemy != 0):
				# we care
				if (current_enemy > wave_high_end): wave_high_end = current_enemy
				if (current_enemy < wave_low_end or wave_low_end == 0): wave_low_end = current_enemy
	
	print("enemies after: " + str(enemies))
	return (enemies)

func explode(row, column, value):
	var explode_chance = value * 2
	var overkill_chance = value * 2
	if ((randi_range(0, 100) < explode_chance) and column > 0):
		if (place_enemy[row][column-1] and (not dead[row][column-1])):
			var chain_react: bool = randi_range(0, 100) < overkill_chance
			if (chain_react):
				enemies[row][column-1] += randi_range(0, value-1)
				dead[row][column-1] = true
			else:
				enemies[row][column-1] += randi_range(0, value-1)
	
	if ((randi_range(0, 100) < explode_chance) and column < 4):
		if (place_enemy[row][column+1] and (not dead[row][column+1])):
			var chain_react: bool = randi_range(0, 100) < overkill_chance
			if (chain_react):
				enemies[row][column+1] += randi_range(0, value-1)
				dead[row][column+1] = true
			else:
				enemies[row][column+1] += randi_range(0, value-1)
	
	if ((randi_range(0, 100) < explode_chance) and column > 0 and row<len(enemies)-1):
		if (place_enemy[row+1][column-1] and (not dead[row+1][column-1])):
			var chain_react: bool = randi_range(0, 100) < overkill_chance
			if (chain_react):
				enemies[row+1][column-1] += randi_range(0, value-1)
				dead[row][column-1] = true
			else:
				enemies[row+1][column-1] += randi_range(0, value-1)
	
	if ((randi_range(0, 100) < explode_chance) and column < 4 and row<len(enemies)-1):
		if (place_enemy[row+1][column+1] and (not dead[row+1][column+1])):
			var chain_react: bool = randi_range(0, 100) < overkill_chance
			if (chain_react):
				enemies[row+1][column+1] += randi_range(0, value-1)
				dead[row][column+1] = true
			else:
				enemies[row+1][column+1] += randi_range(0, value-1)
	
	if ((randi_range(0, 100) < explode_chance) and row<len(enemies)-1):
		if (place_enemy[row+1][column] and (not dead[row+1][column])):
			var chain_react: bool = randi_range(0, 100) < overkill_chance
			if (chain_react):
				enemies[row+1][column] += randi_range(0, value-1)
				dead[row][column] = true
			else:
				enemies[row+1][column] += randi_range(0, value-1)

func swap(reference, target, from, to, largest_tower: int):
	if (largest_tower == reference[from] or largest_tower == reference[to]):
		# if either are the largest tower, make it less likely
		if (randi_range(0, 2) != 0):
			solution[target][to] = reference[from]
			solution[target][from] = reference[to]
	else:
		solution[target][to] = reference[from]
		solution[target][from] = reference[to]

func combine(reference, target, from, to, largest_tower: int):
	if (largest_tower == reference[from] or largest_tower == reference[to]):
		# if either are the largest tower, make it less likely
		if (randi_range(0, 2) != 0):
			solution[target][to] = reference[from] + reference[to]
			solution[target][from] = 0
	else:
		solution[target][to] = reference[from] + reference[to]
		solution[target][from] = 0

func split(reference, target, from, to, largest_tower: int):
	if (reference[from] == 1 and reference[to] == 0):
		solution[target][to] = reference[from]
		solution[target][from] = reference[to]
	else:
		solution[target][to] += floori(reference[from]/2.0)
		solution[target][from] = ceili(reference[from]/2.0) #should do the same rounding as the actual game here
