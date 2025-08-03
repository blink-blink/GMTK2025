#@tool
class_name Organism extends Area2D

enum Types {Herbivore, Carnivore, Plant}
enum Actions {Reproduce, Eat, Move, Rest}
enum GroupSizes {Atomic, Small, Big, Large}

const HEATMAP_SIZE : int = 50

static var ancestor_map : Dictionary[Organism, Dictionary]
static var plant_heatmap : Array[int]
static var group_size_info : Dictionary[GroupSizes, Dictionary] = {
	GroupSizes.Atomic : {
		"size" : 1,
		"sprite_map" : {
			Types.Herbivore : [preload("res://bunny_head_test.tscn")],
			Types.Carnivore : [preload("res://bunny_head_test.tscn")],
			Types.Plant : [preload("res://sprites/sprite_atomic_plant.tscn")],
		}
	},
	GroupSizes.Small : {
		"size" : 5,
		"sprite_map" : {
			Types.Herbivore : [preload("res://bunny_head_test.tscn")],
			Types.Carnivore : [preload("res://bunny_head_test.tscn")],
			Types.Plant : [preload("res://sprites/srpite_small_plant.tscn")],
		}
	},
	GroupSizes.Big : {
		"size" : 10,
		"sprite_map" : {
			Types.Herbivore : [preload("res://bunny_head_test.tscn")],
			Types.Carnivore : [preload("res://bunny_head_test.tscn")],
			Types.Plant : [preload("res://sprites/sprite_big_plant.tscn"), preload("res://sprites/sprite_big_plant_2.tscn")],
		}
	},
	GroupSizes.Large : {
		"size" : 20,
		"sprite_map" : {
			Types.Herbivore : [preload("res://bunny_head_test.tscn")],
			Types.Carnivore : [preload("res://bunny_head_test.tscn")],
			Types.Plant : [preload("res://sprites/sprite_large_plant.tscn"), preload("res://sprites/sprite_large_plant_2.tscn")],
		}
	}
}

@onready var sprite: Node2D = $Sprite
#@onready var action_timer: Timer = $ActionTimer
@onready var interaction_area: Area2D = $InteractionArea
@onready var group_size_label: Label = $GroupSizeLabel
@onready var count_label: Label = $CountLabel
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

#sounds
@onready var eat_sfx: AudioStreamPlayer2D = %EatSFX
@onready var spawn_sfx: AudioStreamPlayer2D = %SpawnSFX
@onready var merge_sfx: AudioStreamPlayer2D = %MergeSFX

@export var type : Types :
	get:
		return type_value
	set(value):
		type_value = value
		update_color()

@export var size : float : 
	get:
		return size_value
	set(value):
		size_value = value
		
		if not is_instance_valid(sprite): return
		
		sprite.scale = Vector2.ONE * ((size_value - 1) * 0.05 + 0.125)

@export var planet_position : float :
	get:
		return planet_position_value
	set(value):
		planet_position_value = value
		if is_initial_position:
			original_placement = planet_position_value
			is_initial_position = false
		Main.instance.organism_position_updated.emit(self, planet_position_value)

var type_value : Types = Types.Herbivore
var size_value : float = 1
var planet_position_value : float = 0
var action_list : Array[Actions]
var action_weights : Array[float]
var action_time : float
var action_timer : float

var original_placement : float
var is_initial_position : bool = true

var reproduction_speed : int = 1
var reproduction_time : int = 10
var reproduction_timer : int = reproduction_time

var nourishment : int
var lifespan : int:
	get:
		return lifespan_value
	set(value):
		lifespan_value = value
		age_till_max_size = value/3
var lifespan_value : int
var age : int = 0
var age_till_max_size : int
var max_size : float
var min_size : float = 0.5

var count : int :
	get:
		return count_value
	set(value):
		count_value = value
		
		if is_instance_valid(count_label): count_label.text = str(count_value)
var count_value = 1

var group_size : GroupSizes :
	get:
		return group_size_value
	set(value):
		group_size_value = value
		if is_instance_valid(group_size_label): group_size_label.text = GroupSizes.keys()[group_size_value]
var group_size_value : GroupSizes = GroupSizes.Atomic 

var root_ancestor : int = get_instance_id()

var is_despawning : bool = false
var tween : Tween

const ORGANISM_SCENE : PackedScene = preload("res://organism.tscn")

static func spawn(planet_position: float, type: Types = Types.values().pick_random(), size : int = randi_range(1,3)) -> Organism:
	var o : Organism = ORGANISM_SCENE.instantiate()
	
	o.type = type
	o.planet_position = planet_position
	o.size = size
	o.max_size = size
	
	o.on_spawned()
	return o

func _ready() -> void:
	load_sprite()
	
	size = size
	count = count
	group_size = group_size
	action_timer = randf_range(1.5, 2.0)
	collision_shape_2d.shape.radius = 10
	interaction_area.get_child(0).shape.radius = 22
	
	match type:
		Types.Carnivore:
			for action in Actions.values():
				action_list.append(action)
				match action:
					Actions.Eat: action_weights.append(0.05)
					Actions.Reproduce: action_weights.append(0.15)
					_: action_weights.append(0.40)
			lifespan = 60
		Types.Herbivore:
			for action in Actions.values():
				action_list.append(action)
				match action:
					Actions.Eat: action_weights.append(0.12)
					Actions.Reproduce: action_weights.append(0.28)
					_: action_weights.append(0.3)
			lifespan = 60
		Types.Plant:
			action_list = [Actions.Reproduce, Actions.Rest]
			action_weights = [0.6, 0.4]
			lifespan = 100
	
	$AncestorLabel.text = str(root_ancestor)
	$NourishmentLabel.text = str(nourishment)
	
	set_process(false)

func _process(delta: float) -> void:
	action_timer -= delta
	if action_timer <= 0:
		action_timer = randf_range(1.5, 2.0)
		_on_action_timer_timeout()

func _on_action_timer_timeout() -> void:
	if try_group(): return # order is necessary
	
	reproduction_timer = 0 if reproduction_timer < 0 else reproduction_timer - 1
	match weighted_pick(action_list, action_weights):
		Actions.Move:
			if tween: tween.kill()
			tween = create_tween()
			tween.tween_property(self, "planet_position", planet_position + randf_range(-10,10),0.25)
		Actions.Reproduce:
			if reproduction_timer <= 0 and (nourishment >= count or type == Types.Plant):
				reproduction_timer = reproduction_time
				for i in count: 
					if type == Types.Plant and not Main.instance.can_plants_spawn(): break
					reproduce()
				nourishment -= count
		Actions.Eat:
			var prey : Array[Organism] = []
			for o : Organism in interaction_area.get_overlapping_areas():
				if prey.size() >= count: break
				if o == self: continue
				if type == Types.Carnivore and o.type == Types.Plant: continue
				if type == Types.Herbivore and o.type != Types.Plant: continue
				if o.root_ancestor != root_ancestor:
					prey.append(o)
			
			# eat prey
			var eat_count : int = count
			var eat_successful : bool = false
			for i in range(prey.size() - 1, -1, -1):
				if eat_count <= 0:
					break

				var p: Organism = prey[i]
				if is_instance_valid(p) and not p.is_despawning:
					p.death()
					nourishment += 1
					eat_count -= 1
					eat_successful = true
				else:
					prey.remove_at(i)
			
			if eat_successful: eat_sfx.play()
	
	age += 1
	if age < age_till_max_size and size < max_size:  size += 1.0/age_till_max_size*(max_size - min_size)
	$NourishmentLabel.text = str(nourishment)
	#print(Types.keys()[type], ": ",nourishment)
	if age > lifespan:
		death()

#func can_plant_reproduce() -> bool:
	#for o : Organism in interaction_area.get_overlapping_areas():
		#if o == self: continue
		#if o.type == Types.Plant:
			#return false
	#return true

func load_sprite() -> void:
	update_color()
	
	for s : Node2D in sprite.get_children(): s.queue_free()
	sprite.add_child(group_size_info[group_size]["sprite_map"][type].pick_random().instantiate())

func update_color() -> void:
	if not is_instance_valid(sprite): return
	match type_value:
		Types.Herbivore:
			sprite.modulate = Color.GREEN
		Types.Carnivore:
			sprite.modulate = Color.RED
		Types.Plant:
			sprite.modulate = Color.WHITE

func spawn_to_planet(planet_position : float = 0) -> void:
	self.planet_position = planet_position
	on_spawned()

func death() -> void:
	try_unregister_plant()
	
	Main.instance.organism_death.emit(self)
	
	if count <= 1: 
		queue_free()
		return
	count -= 1

func on_spawned() -> void:
	if type == Organism.Types.Plant: register_plant_spawn()
	
	Main.instance.organism_spawned.emit(self)
	set_process(true)
	spawn_sfx.play()

func reproduce() -> void:
	var offspring : Organism = self.duplicate()
	offspring.root_ancestor = self.root_ancestor
	offspring.nourishment = 1 if self.nourishment > 1 else 0
	offspring.size = offspring.min_size
	offspring.max_size = self.max_size
	
	if type == Organism.Types.Plant: offspring.planet_position = pick_plant_offspring_position()
	else: offspring.planet_position = planet_position + randf_range(-20,20) * (group_size + 1)
	
	offspring.on_spawned()
	#print("offspring: ", Types.keys()[offspring.type], " spawned")
	Main.instance.organism_reproduced.emit(offspring)

func pick_plant_offspring_position() -> float:
	var planet_circumference : float = TAU * Main.instance.planet_radius
	var heatmap_index : int = int(floor(fmod(planet_position,planet_circumference)/planet_circumference*HEATMAP_SIZE))%HEATMAP_SIZE
	var minima_index : float = find_least_dense_direction(heatmap_index)
	
	var target_position : float =  ((minima_index+randf_range(0.01,0.99))/HEATMAP_SIZE) * planet_circumference
	return target_position

func find_least_dense_direction(start_index: int, max_steps : int = 10) -> int:
	var current : int = start_index
	for step in max_steps:
		var left : int = (current - 1 + HEATMAP_SIZE) % HEATMAP_SIZE
		var right : int = (current + 1) % HEATMAP_SIZE

		var current_density : int = plant_heatmap[current]
		var left_density : int = plant_heatmap[left]
		var right_density : int = plant_heatmap[right]

		if left_density < current_density and left_density <= right_density:
			current = left
		elif right_density < current_density and right_density < left_density:
			current = right
		else:
			break # Local minimum or plateau

	return current

func try_unregister_plant(use_count : bool = false) -> void:
	if type != Types.Plant: return
	
	var planet_circumference : float = TAU * Main.instance.planet_radius
	var heatmap_index : int = int(floor(fmod(planet_position,planet_circumference)/planet_circumference*HEATMAP_SIZE))%HEATMAP_SIZE
	plant_heatmap[heatmap_index] -= count if use_count else 1
	
	#print(str(plant_heatmap) + " grouping..." if use_count else "")

func register_plant_spawn(spawn_position : float = planet_position) -> void:
	if plant_heatmap == []:
		for i in HEATMAP_SIZE: plant_heatmap.append(0)
	
	var planet_circumference : float = TAU * Main.instance.planet_radius
	var heatmap_index : int = int(floor(fmod(spawn_position,planet_circumference)/planet_circumference*HEATMAP_SIZE))%HEATMAP_SIZE
	plant_heatmap[heatmap_index] += count
	
	#print(plant_heatmap, " spawning...")

func try_group() -> bool:
	if group_size == GroupSizes.Large: return false
	
	var member_candidates : Array[Organism]= []
	var org_count : int = count
	var max_pos : float = planet_position
	var min_pos : float = max_pos
	var min_age : int = age
	var max_age : int = age
	var total_lifespan : int = lifespan
	var total_nourishment : int = nourishment
	var old_group_size : GroupSizes = group_size
	var largest_size : float = size
	var largest_max_size : float = max_size
	
	for o : Organism in interaction_area.get_overlapping_areas():
		if o == self: continue
		if o.is_queued_for_deletion(): continue
		if o.is_despawning: continue
		if (o.root_ancestor ==  root_ancestor or type == Types.Plant or type == Types.Herbivore) and o.type == type and group_size == o.group_size:
			member_candidates.append(o)
			org_count += o.count
			total_nourishment += o.nourishment
			total_lifespan += o.lifespan
			if o.planet_position < min_pos: min_pos = o.planet_position
			if o.planet_position > max_pos: max_pos = o.planet_position
			if o.age > min_age: min_age = o.age
			if o.age < max_age: max_age = o.age
			if o.size > largest_size: largest_size = o.size
			if o.max_size > largest_max_size: largest_max_size = o.max_size
	
	if member_candidates.is_empty(): return false
	
	for i in GroupSizes.values():
		if org_count < group_size_info[i]["size"]:
			group_size = i-1
			break
		if i == GroupSizes.values().size()-1 and org_count >= group_size_info[i]["size"]:
			group_size = i
	
	if group_size == GroupSizes.Atomic: return false
	
	var circumference : float = TAU * Main.instance.planet_radius
	var merged_position : float = fmod(min_pos + fmod((max_pos - min_pos + circumference), circumference) / 2.0, circumference)
	var angle : float = merged_position/circumference * TAU
	var actual_merged_position = Main.instance.planet.global_position - Vector2(cos(angle), sin(angle)) * Main.instance.planet_radius
	
	try_unregister_plant(true)
	for o : Organism in member_candidates: 
		o.try_unregister_plant(true)
		o.set_process(false)
		o.is_despawning = true
		#o.queue_free()
		
		if o.tween: o.tween.kill()
		o.tween = create_tween()
		o.tween.tween_property(o, "global_position", actual_merged_position, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		o.tween.tween_callback(o.queue_free)
	
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(self, "global_position", actual_merged_position, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	planet_position = merged_position
	count = org_count
	nourishment = total_nourishment
	lifespan += (max_age - min_age)
	age = max_age
	
	var new_shape : CircleShape2D = CircleShape2D.new()
	new_shape.radius = 22 * (group_size + 1) # 22 is default radius for interaction area
	interaction_area.get_child(0).shape = new_shape
	
	new_shape = CircleShape2D.new()
	new_shape.radius = 10 * (group_size + 1) # 10 is default radius
	collision_shape_2d.shape = new_shape
	
	if group_size > old_group_size:
		#TODO replace with sprite
		if type == Types.Plant:
			max_size = largest_max_size
			var old_size : float = size
			tween.tween_property(self, "size", largest_max_size * (1 + 0.25 * (group_size + 1)), 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tween.tween_callback(load_sprite)
			tween.tween_property(self, "size", old_size, 0.1).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
		else:
			load_sprite()
			tween.tween_property(self, "size", largest_max_size * (group_size + 1), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		#size = largest_max_size * (group_size + 1)
	
	register_plant_spawn(planet_position)
	
	merge_sfx.play()
	
	#print(Types.keys()[type], " grouped with size ", group_size,": ", count)
	
	return true

func split() -> void:
	pass

func weighted_pick(items: Array[Actions], weights: Array[float]):
	var total = 0
	for i in weights: total += i
	var r = randf() * total
	var acc = 0.0
	for i in items.size():
		acc += weights[i]
		if r < acc:
			return items[i]
	return null  # fallback
