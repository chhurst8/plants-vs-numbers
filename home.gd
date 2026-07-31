extends Node2D

@export var screen_transition: ScreenTransition

@export var music: Node


@export var toggle_mute_sprite: Sprite2D
@export var volume_slider: HSlider
@export var volume_slider_timer: Timer

var buffered_volume_change: float

@export var tutorial: Control
@export var tutorial_sprite: Sprite2D
var tutorial_progress: int = 0

@export var tutorial_slides: Array[Texture2D]

@export var records: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if (get_tree().paused):
		get_tree().paused = false
	if (Global.muted):
		toggle_mute_sprite.texture = preload("res://Visuals/muted.svg")
	else:
		toggle_mute_sprite.texture = preload("res://Visuals/mute.svg")
	
	buffered_volume_change = Global.unmuted_volume
	volume_slider.value = Global.unmuted_volume
	
	tutorial_progress = 0
	tutorial.hide()
	
	
	Global.load_scores()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	tutorial_progress = clamp(tutorial_progress, 0, 6)
	if (tutorial_progress == 0):
		tutorial.hide()
	else:
		tutorial.show()
		tutorial_sprite.texture = tutorial_slides[tutorial_progress - 1]
	
	records.text = "Highest Score: " + str(Global.highest_score) + "\nHighest Wave: " + str(Global.highest_wave)


func _on_play_button_pressed() -> void:
	if (!Global.music_already_exists):
		if (music.get_parent() == self):
			music.reparent(get_tree().root)
		Global.music_already_exists = true
	
	if (Global.need_tutorial):
		advance_tutorial()
	else:
		screen_transition.transition_to("main.tscn")

func advance_tutorial() -> void:
	tutorial.show()
	tutorial_progress += 1
	if (tutorial_progress == 6):
		Global.need_tutorial = false
		screen_transition.transition_to("main.tscn")

func regress_tutorial() -> void:
	tutorial_progress -= 1
	if (tutorial_progress == 0):
		tutorial.hide()

func _on_toggle_mute_pressed() -> void:
	Global.toggle_mute()
	if (Global.muted):
		toggle_mute_sprite.texture = preload("res://Visuals/muted.svg")
	else:
		toggle_mute_sprite.texture = preload("res://Visuals/mute.svg")


func _on_volume_slider_value_changed(value: float) -> void:
	if(volume_slider_timer.time_left <= 0):
		Global.set_master_volume(value)
	else:
		buffered_volume_change = value
		volume_slider_timer.start()

func _on_volume_slider_timer_timeout() -> void:
	Global.set_master_volume(buffered_volume_change)
