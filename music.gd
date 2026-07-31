extends AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if (Global.music_already_exists):
		queue_free()
	else:
		reparent(get_tree().root)
		start_menu_music()

func _on_timer_timeout() -> void:
	reparent(get_tree().root)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func start_game_music() -> void:
	$MenuMusic.volume_db = -80
	$MenuMusic.stop()
	
	volume_db = 0
	play()

func start_menu_music() -> void:
	$MenuMusic.volume_db = 0
	$MenuMusic.play()
	
	volume_db = -80
	stop()

func pause_music() -> void:
	stream_paused = true

func resume_music() -> void:
	stream_paused = false

func lose_game_get_quieter() -> void:
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "volume_db", -20, 2.0)

func is_main_music() -> void:
	pass
