class_name ScreenTransition
extends Sprite2D

var anim_time: float = 0

var moving_up: bool = true

var next_scene: String

var going: bool = false
var went: bool = false


@export var bounce_sfx: AudioStreamPlayer
@export var woosh_sfx: AudioStreamPlayer
@export var delayer_bounce: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	moving_up = true
	anim_time = 0
	
	position = Vector2(360, 720)
	
	next_scene = ""
	going = false
	went = false
	
	woosh_sfx.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if (moving_up):
		if (anim_time <= 1.0):
			anim_time += delta
			
			position = Vector2(360, lerp(720, 0, Main.ease_in_cubic(anim_time / 1.0)))
			visible = true
		else:
			position = Vector2(0, 0)
			visible = false
	else:
		if (anim_time <= 1.6):
			anim_time += delta
			
			position = Vector2(360, lerp(0, 720, Main.ease_out_bounce(anim_time / 1.6)))
			visible = true
		else:
			if (anim_time <= 2.0):
				anim_time += delta
				position = Vector2(360, 720)
				visible = true
			else:
				if (!went):
					if (next_scene == "main.tscn"): Global.set_music(false)
					else: Global.set_music(true)
					Global.goto_scene(next_scene)
					went = true

func transition_to(path: String) -> void:
	if (!going):
		next_scene = path
		move_down()
		going = true

func move_down() -> void:
	moving_up = false
	anim_time = 0
	delayer_bounce.start()


func _on_delayer_b_timeout() -> void:
	bounce_sfx.play()
