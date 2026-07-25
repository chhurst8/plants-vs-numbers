class_name EndScreen
extends Node2D

var game_ended: bool = false

@export var background: Sprite2D
var anim_time: float = 0


@export var score_text: Label
@export var enemies_killed_text: Label
@export var explosions_text: Label
@export var strongest_enemy_killed_text: Label
@export var wave_reached_text: Label

var score_str: String
var enemies_killed_str: String
var explosions_str: String
var strongest_enemy_killed_str: String
var wave_reached_str: String



@export var clock_thing: TextureProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_ended = false
	
	score_text.text = ""
	enemies_killed_text.text = ""
	explosions_text.text = ""
	strongest_enemy_killed_text.text = ""
	wave_reached_text.text = ""

func game_end(_score: int, _enemies_killed: int, _explosions: int, _strongest_enemy_killed: int, _wave_reached: int) -> void:
	anim_time = 0
	game_ended = true
	
	score_str = "Total Score: " + str(_score)
	enemies_killed_str = "Enemies Killed: " + str(_enemies_killed)
	explosions_str = "Explosions: " + str(_explosions)
	strongest_enemy_killed_str = "Strongest Enemy Killed: " + str(_strongest_enemy_killed)
	wave_reached_str = "Wave Reached: " + str(_wave_reached)

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
			display_stat(score_text, score_str, 2)
			
			display_stat(wave_reached_text, wave_reached_str, 3)
			
			display_stat(enemies_killed_text, enemies_killed_str, 3.5)
			
			display_stat(explosions_text, explosions_str, 4)
			
			display_stat(strongest_enemy_killed_text, strongest_enemy_killed_str, 4.5)

func display_stat(text_obj: Label, stat_string: String, writing_start_time: float) -> void:
	var stat_anim = lerp(0, len(stat_string), Main.ease_out_cubic(clampf(anim_time - writing_start_time, 0, 1)))
	text_obj.text = stat_string.substr(0, stat_anim)
