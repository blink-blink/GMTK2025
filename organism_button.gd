class_name OrganismButton extends TextureButton

const placeholder_texture = preload("uid://bhlywlfnvw7jf")
const ORGANISM_BUTTON_SCENE = preload("res://organism_button.tscn")

@onready var preview_holder: Node2D = $PreviewHolder

var organism : Organism

static func create_button(organism : Organism) -> OrganismButton:
	var b : OrganismButton = ORGANISM_BUTTON_SCENE.instantiate()
	b.organism = organism
	return b

func _ready() -> void:
	Main.instance.organism_spawned.connect(on_organism_spawned)
	preview_holder.add_child(organism)
	#organism.hide()
	#modulate = organism.sprite.modulate
	

func on_organism_spawned(organism : Organism) -> void:
	if self.organism == organism:
		Main.instance.list_organism_spawned.emit()
		queue_free()

func _on_pressed() -> void:
	#print("pressed")
	Main.instance.organism_spawner.spawn(organism)
