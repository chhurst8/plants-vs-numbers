class_name NotifText
extends Node2D

@export var number_display: Label

enum NotifTypes {
	ADD,
	SUBTRACT,
	DIVIDE
}
var notif_type: NotifTypes

var notif_number: int

var notif_lifespan: float


var lifetime: float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func setup(_notif_type: NotifTypes, _notif_number: int, _notif_lifespan: float, _phys_position: Vector2) -> void:
	notif_type = _notif_type
	notif_number = _notif_number
	notif_lifespan = _notif_lifespan
	
	match notif_type:
		NotifTypes.ADD:
			number_display.text = "+"
		NotifTypes.SUBTRACT:
			number_display.text = "-"
		NotifTypes.DIVIDE:
			number_display.text = "/"
	number_display.text += str(notif_number)
	
	position = _phys_position
	visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += Vector2(0, -40 * delta)
	
	lifetime += delta
	if (lifetime >= notif_lifespan):
		queue_free()
	else:
		number_display.self_modulate = Color(1, 1, 1, lerp(1, 0, lifetime / notif_lifespan))
