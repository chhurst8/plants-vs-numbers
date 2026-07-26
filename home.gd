extends Node2D

@export var screen_transition: ScreenTransition

@export var music: Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_play_button_pressed() -> void:
	if (music.get_parent() == self):
		music.reparent(get_tree().root)
	
	screen_transition.transition_to("main.tscn")
