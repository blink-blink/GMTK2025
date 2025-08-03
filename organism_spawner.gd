extends Node2D

@onready var sprite_preview: Node2D = $SpritePreview
@onready var phantom: Sprite2D = $Phantom

var planet_spawn_position : float
var organism_to_spawn : Organism

func _input(event: InputEvent) -> void:
	if event is InputEventMouse and visible:
		get_viewport().set_input_as_handled()
	else:
		return
	
	#if Input.is_action_just_pressed("drag"): show()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.is_pressed(): 
			if is_instance_valid(organism_to_spawn): 
				organism_to_spawn.get_parent().remove_child(organism_to_spawn)
				organism_to_spawn.show()
				organism_to_spawn.spawn_to_planet(planet_spawn_position)
				organism_to_spawn = null
			hide()

func _ready() -> void:
	hide()

func _process(delta: float) -> void:
	sprite_preview.global_position = get_viewport().get_camera_2d().get_global_mouse_position()
	
	var planet : Node2D = Main.instance.planet
	var planet_to_preview : Vector2 = planet.global_position - sprite_preview.global_position
	var angle = fmod((atan2(planet_to_preview.y, planet_to_preview.x) + TAU), TAU) 
	
	phantom.rotation = angle - PI/2
	phantom.global_position = planet.global_position - Vector2(cos(angle), sin(angle)) * Main.instance.planet_radius
	
	var planet_circumference = TAU * Main.instance.planet_radius
	planet_spawn_position = angle/TAU * planet_circumference

func spawn(organism : Organism) -> void:
	organism_to_spawn = organism
	for c : Node2D in sprite_preview.get_children(): c.queue_free()
	
	var o_preview : Node2D = organism_to_spawn.duplicate()
	o_preview.position = Vector2.ZERO
	o_preview.rotation = 0
	sprite_preview.add_child(o_preview)
	show()
