extends Node


var current_scene = null

var muted: bool = false

var unmuted_volume: float = 0


var need_tutorial: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var root = get_tree().root
	# Using a negative index counts from the end, so this gets the last child node of `root`.
	current_scene = get_tree().current_scene
	
	muted = false
	
	unmuted_volume = 0
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), unmuted_volume)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func set_master_volume(new_volume: float) -> void:
	unmuted_volume = new_volume
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), unmuted_volume)

func toggle_mute():
	muted = !muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

func set_music(menu: bool) -> void:
	var children: Array[Node] = get_tree().root.get_children()
	for child in children:
		if(child.has_method("is_main_music")):
			if (menu):
				child.start_menu_music()
			else:
				child.start_game_music()


func goto_scene(path):
	# This function will usually be called from a signal callback,
	# or some other function in the current scene.
	# Deleting the current scene at this point is
	# a bad idea, because it may still be executing code.
	# This will result in a crash or unexpected behavior.

	# The solution is to defer the load to a later time, when
	# we can be sure that no code from the current scene is running:
	
	_deferred_goto_scene.call_deferred(path)


func _deferred_goto_scene(path):
	# It is now safe to remove the current scene.
	current_scene.free()

	# Load the new scene.
	var s = ResourceLoader.load(path)

	# Instance the new scene.
	current_scene = s.instantiate()

	# Add it to the active scene, as child of root.
	get_tree().root.add_child(current_scene)

	# Optionally, to make it compatible with the SceneTree.change_scene_to_file() API.
	get_tree().current_scene = current_scene
