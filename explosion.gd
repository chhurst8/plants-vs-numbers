class_name Explosion
extends Node2D

const FONT_SIZES = [100, 90, 70, 60, 50, 44]

var anim_time: float = 0
@export var number_display: Label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	anim_time = 0

func setup(damage_amount: int, pos: Vector2) -> void:
	number_display.text = Main.format_big_number(damage_amount)
	number_display.add_theme_font_size_override("font_size", FONT_SIZES[clampi(len(number_display.text)-1, 0, 5)])
	position = pos
	anim_time = 0
	scale = Vector2(0.85, 0.85)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	anim_time += delta
	
	if (anim_time >= 0.8):
		modulate = Color(1,1,1,0)
		queue_free()
	
	if (anim_time >= 0.4):
		var alpha: float = lerp(1, 0, Main.ease_in_quad((anim_time - 0.4) / 0.4))
		modulate = Color(1,1,1, alpha)
	else:
		modulate = Color(1,1,1,1)
	
	if (anim_time <= 0.4):
		var _exp_scale: float = lerp(0.85, 1.0, Main.ease_out_quart(anim_time / 0.4))
		scale = Vector2(_exp_scale, _exp_scale)
	elif (anim_time > 0.6):
		var _exp_scale: float = lerp(1.0, 0.85, Main.ease_in_quad((anim_time - 0.6) / 0.2))
		scale = Vector2(_exp_scale, _exp_scale)
