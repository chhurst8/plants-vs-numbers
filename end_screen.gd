extends Node2D

var game_ended: bool = false

@export var background: Sprite2D
var anim_time: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	game_ended = false

func game_end() -> void:
	anim_time = 0
	game_ended = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (game_ended):
		anim_time += delta
		
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
