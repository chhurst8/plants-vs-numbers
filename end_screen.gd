class_name EndScreen
extends Node2D

var game_ended: bool = false

@export var background: Sprite2D
var anim_time: float = 0


@export var score_text: Label
@export var enemies_killed_text: Label
@export var explosions_text: Label
@export var strongest_enemy_killed_text: Label

var score_str: String
var enemies_killed_str: String
var explosions_str: String
var strongest_enemy_killed_str: String



@export var clock_thing: TextureProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_ended = false
	
	score_text.text = ""
	enemies_killed_text.text = ""
	explosions_text.text = ""
	strongest_enemy_killed_text.text = ""

func game_end(_score: int, _enemies_killed: int, _explosions: int, _strongest_enemy_killed: int) -> void:
	anim_time = 0
	game_ended = true
	
	score_str = "Total Score: " + str(_score)
	enemies_killed_str = "Enemies Killed: " + str(_enemies_killed)
	explosions_str = "Explosions: " + str(_explosions)
	strongest_enemy_killed_str = "Strongest Enemy Killed: " + str(_strongest_enemy_killed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (game_ended):
		anim_time += delta
		
		clock_thing.value = lerp(180, 360, clampf(anim_time, 0, 1))
		
		if (anim_time >= 0 and anim_time <= 1.6):
			background.position = Vector2(360, lerp(0, 720, Main.ease_out_bounce(anim_time / 1.6)))
			background.visible = true
		elif (anim_time < 0):
			background.position = Vector2(360, 0)
			background.visible = false
		else:
			background.position = Vector2(360, 720)
			background.visible = true
		
		# DISPLAY STATS
		if (anim_time > 2):
			var score_anim = lerp(0, len(score_str), Main.ease_out_cubic(clampf(anim_time - 2, 0, 1)))
			score_text.text = score_str.substr(0, score_anim)
			
			var enemies_killed_anim = lerp(0, len(enemies_killed_str), Main.ease_out_cubic(clampf(anim_time - 3, 0, 1)))
			enemies_killed_text.text = enemies_killed_str.substr(0, enemies_killed_anim)
			
			var explosions_anim = lerp(0, len(explosions_str), Main.ease_out_cubic(clampf(anim_time - 3.5, 0, 1)))
			explosions_text.text = explosions_str.substr(0, explosions_anim)
			
			var strongest_enemy_killed_anim = lerp(0, len(strongest_enemy_killed_str), Main.ease_out_cubic(clampf(anim_time - 4, 0, 1)))
			strongest_enemy_killed_text.text = strongest_enemy_killed_str.substr(0, strongest_enemy_killed_anim)
