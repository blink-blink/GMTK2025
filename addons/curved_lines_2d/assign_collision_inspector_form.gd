@tool
extends Control

class_name AssignCollisionInspectorForm

var scalable_vector_shape_2d : ScalableVectorShape2D
var select_button : Button

func _enter_tree() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	select_button = find_child("GotoCollisionButton")
	if 'assigned_node_changed' in scalable_vector_shape_2d:
		scalable_vector_shape_2d.assigned_node_changed.connect(_on_svs_assignment_changed)
	_on_svs_assignment_changed()


func _on_svs_assignment_changed() -> void:
	if is_instance_valid(scalable_vector_shape_2d.collision_polygon):
		select_button.get_parent().show()
		select_button.disabled = false
	else:
		hide()


func _on_goto_collision_button_pressed() -> void:
	if not is_instance_valid(scalable_vector_shape_2d):
		return
	if not is_instance_valid(scalable_vector_shape_2d.collision_polygon):
		return
	EditorInterface.call_deferred('edit_node', scalable_vector_shape_2d.collision_polygon)

