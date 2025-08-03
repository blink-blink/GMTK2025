class_name Main extends Node2D

const ORGANISM_SCENE : PackedScene = preload("res://organism.tscn")
const INIT_ORGANISM_COUNT : int =  15
const INIT_ORGANISM_LIST_COUNT : int = 4
const MAX_PLANT_COUNT = 100

@onready var organism_list: VBoxContainer = %OrganismList
@onready var celestials: Sprite2D = $Celestials
@onready var organisms: Node2D = %Organisms
@onready var plants: Node2D = %Plants
@onready var days_label: Label = %DaysLabel
@onready var score_label: Label = $UserInterface/ScoreLabel
@onready var org_types_label: Label = %OrgTypesLabel
@onready var organism_spawner: Node2D = $OrganismSpawner
@onready var fatigue_timer: Timer = $FatigueTimer
@onready var fatigue_label: PanelContainer = %FatigueLabel

static var instance : Node2D

signal organism_position_updated(organism : Organism, planet_position : float)
signal organism_spawned(organism : Organism)
signal organism_reproduced(offspring : Organism)
signal organism_death(organism : Organism)
signal list_organism_spawned

@export var planet : Node2D
@export var planet_radius : float = 200
@export var seconds_per_day : float = 20

var organism_count : int = 0
var days : int = 0
var day_timer = seconds_per_day
var score : int = 0

var org_type_counter : Array[int]

func _ready() -> void:
	instance = self
	
	for i in INIT_ORGANISM_COUNT:
		
		var planet_circumference = TAU * planet_radius
		var target_position = planet_circumference * (i + randf_range(-0.5,0.5))/INIT_ORGANISM_COUNT
		Organism.spawn(target_position)
	
	for i in INIT_ORGANISM_LIST_COUNT:
		update_organism_list()
	
	update_score_label()
	
	fatigue_label.modulate = Color.TRANSPARENT

func _physics_process(delta: float) -> void:
	celestials.rotation += delta * TAU/seconds_per_day
	
	if day_timer > 0:
		day_timer -= delta
	else:
		days += 1
		day_timer = seconds_per_day
		days_label.text = "DAY %d" % days

func update_organism_list() -> void:
	#TODO PLACEHOLDER
	var o : Organism = ORGANISM_SCENE.instantiate()
	o.type = Organism.Types.values().pick_random()
	o.size = randi_range(1,3)
	o.max_size = o.size
	var o_button : OrganismButton = OrganismButton.create_button(o)
	organism_list.add_child(o_button)

func _on_organism_position_updated(o: Organism, planet_position: float) -> void:
	var planet_circumference = TAU * planet_radius
	var angle : float = planet_position/planet_circumference * TAU
	o.global_position = planet.global_position - Vector2(cos(angle), sin(angle)) * planet_radius
	o.rotation = -PI/2 + angle


func _on_organism_reproduced(offspring: Organism) -> void:
	#print("organism ", Organism.Types.keys()[organism.type], " : Size ", organism.size, " births ",Organism.Types.keys()[offspring.type], " : Size ", organism.size)
	score += 1
	update_score_label()

func update_score_label() -> void:
	score_label.text = "Score: %d" % score

func _on_organism_death(organism: Organism) -> void:
	update_org_type_label(organism, true)

func update_org_type_label(o : Organism, is_death : bool = false) -> void:
	if org_type_counter == []:
		for i in Organism.Types:
			org_type_counter.append(0)
	
	org_type_counter[o.type] += 1 if not is_death else -1
	var text : String = ""
	for i in Organism.Types.size():
		text += Organism.Types.keys()[i] + " : " + str(org_type_counter[i]) + "\n"
	org_types_label.text = text

func _on_organism_spawned(organism: Organism) -> void:
	update_org_type_label(organism)
	
	if organism.type == Organism.Types.Plant: 
		return plants.add_child(organism)
	organisms.add_child(organism)

func _on_list_organism_spawned() -> void:
	#print("list spawned")
	update_organism_list()

var fatigue_tween : Tween
func can_plants_spawn() -> bool:
	if not fatigue_timer.is_stopped(): return false
	
	if org_type_counter[Organism.Types.Plant] > MAX_PLANT_COUNT: 
		if fatigue_tween: fatigue_tween.kill()
		fatigue_tween = create_tween()
		fatigue_label.modulate = Color.TRANSPARENT
		fatigue_tween.tween_property(fatigue_label, "modulate:a", 1,0.3)
		
		fatigue_timer.start()
		return false
	
	if fatigue_tween: fatigue_tween.kill()
	fatigue_tween = create_tween()
	fatigue_tween.tween_property(fatigue_label, "modulate:a", 0,0.3)
	return true
