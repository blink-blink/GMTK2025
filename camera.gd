extends Camera2D

const MAX_ZOOM : float = 2.5
const MIN_ZOOM : float = 1.0
const ZOOM_SPEED : float = 0.1
const MAX_X_DISTANCE : float = 500
const MAX_Y_DISTANCE : float = 500

@export var camera_target : Node2D

var target_zoom : Vector2 = Vector2.ONE

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("zoom_in") and zoom <= Vector2.ONE * MAX_ZOOM:
		target_zoom += Vector2.ONE * ZOOM_SPEED
	if Input.is_action_just_pressed("zoom_out") and zoom >= Vector2.ONE * MIN_ZOOM:
		target_zoom -= Vector2.ONE * ZOOM_SPEED
	target_zoom = clamp(target_zoom, Vector2.ONE * MIN_ZOOM, Vector2.ONE * MAX_ZOOM)
		
	if event is InputEventMouseMotion and Input.is_action_pressed("drag"):
		position -= event.relative / zoom.x
		
		if abs(camera_target.global_position.x - position.x) > MAX_X_DISTANCE:
			position.x = camera_target.global_position.x - MAX_X_DISTANCE * sign(camera_target.global_position.x - position.x)
		if abs(camera_target.global_position.y - position.y) > MAX_Y_DISTANCE:
			position.y = camera_target.global_position.y - MAX_Y_DISTANCE * sign(camera_target.global_position.y - position.y)

func _process(delta: float) -> void:
	zoom = lerp(zoom, target_zoom, delta * 5.0)
