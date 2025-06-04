extends Node2D

const DSU_Class = preload("res://scripts/DSU.gd")
const SlimeScene = preload("res://scenes/Slime.tscn")
const FoodScene = preload("res://scenes/Food.tscn")

var dsu_instance: DSU
var slimes_map: Dictionary = {}
var slime_id_counter: int = 0
var player_slime_node_id: int = -1

const MAX_FOOD_ON_SCREEN: int = 15
const MIN_FOOD_SPAWN_INTERVAL: float = 1.0
const MAX_FOOD_SPAWN_INTERVAL: float = 3.0
var current_food_count: int = 0

const MAX_ENEMIES_ON_SCREEN: int = 5
const MIN_ENEMY_SPAWN_INTERVAL: float = 3.0
const MAX_ENEMY_SPAWN_INTERVAL: float = 7.0
var current_enemy_count: int = 0
var enemy_spawn_timer: Timer

const PLAYER_INITIAL_RADIUS: float = 15.0
const PLAYER_INITIAL_COLOR: Color = Color.GOLD

const ENEMY_INITIAL_RADIUS_MIN: float = 8.0
const ENEMY_INITIAL_RADIUS_MAX: float = 12.0
const ENEMY_RADIUS_FACTOR_MIN_OF_PLAYER: float = 0.6  
const ENEMY_RADIUS_FACTOR_MAX_OF_PLAYER: float = 1.2 
const ENEMY_ABSOLUTE_MIN_RADIUS: float = 5.0         

var screen_size: Vector2
var game_is_over: bool = false
@onready var game_over_label: Label = $GameOver
@onready var food_spawn_timer: Timer = $FoodSpawnTimer


func _ready() -> void:
	dsu_instance = DSU_Class.new()
	screen_size = get_viewport_rect().size
	
	if not is_instance_valid(game_over_label): 
		setup_game_over_ui()
	else:
		game_over_label.visible = false 

	print("Slime DSU Game Started. Use WASD to move. R to Restart.")
	
	spawn_player_slime_entity()
	
	var initial_food_to_spawn = min(MAX_FOOD_ON_SCREEN / 2, 7)
	for i in range(initial_food_to_spawn):
		if current_food_count < MAX_FOOD_ON_SCREEN: spawn_random_food()
		else: break
	
	if not is_instance_valid(food_spawn_timer):
		food_spawn_timer = Timer.new()
		food_spawn_timer.name = "FoodSpawnTimer" 
		add_child(food_spawn_timer)
	if not food_spawn_timer.is_connected("timeout", Callable(self, "_on_food_spawn_timer_timeout")):
		food_spawn_timer.timeout.connect(Callable(self, "_on_food_spawn_timer_timeout"))
	randomize_and_start_food_timer()

	enemy_spawn_timer = Timer.new()
	enemy_spawn_timer.name = "EnemySpawnTimer"
	add_child(enemy_spawn_timer)
	enemy_spawn_timer.timeout.connect(Callable(self, "_on_enemy_spawn_timer_timeout"))
	randomize_and_start_enemy_timer()

func setup_game_over_ui():
	game_over_label.visible = true

func _process(_delta: float):
	if Input.is_action_just_pressed("restart_game"):
		restart_game()
	
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

func restart_game():
	get_tree().reload_current_scene()

func spawn_slime(p_pos: Vector2, p_radius: float, p_color: Color, p_base_type: SlimeEntity.SlimeType, p_is_player: bool) -> SlimeEntity:
	slime_id_counter += 1
	var new_slime_id = slime_id_counter
	
	var slime_instance: SlimeEntity = SlimeScene.instantiate() as SlimeEntity
	slime_instance.initialize(new_slime_id, p_pos, p_radius, p_color, p_base_type, p_is_player)
	
	dsu_instance.make_set(new_slime_id, p_radius, p_color, p_is_player)
	
	var dsu_data = dsu_instance.get_set_data(new_slime_id)
	if dsu_data and not dsu_data.is_empty():
		slime_instance.update_properties_from_dsu_set(dsu_data)
	else:
		printerr("Failed to get DSU data for new slime: ", new_slime_id)

	add_child(slime_instance)
	slimes_map[new_slime_id] = slime_instance
	slime_instance.absorbed_into_another.connect(_on_slime_absorbed_into_another)

	if p_is_player:
		player_slime_node_id = new_slime_id
		slime_instance.game_over.connect(Callable(self, "handle_game_over_event"))

	return slime_instance

func spawn_player_slime_entity() -> void:
	var initial_pos = screen_size / 2
	spawn_slime(initial_pos, PLAYER_INITIAL_RADIUS, PLAYER_INITIAL_COLOR, SlimeEntity.SlimeType.PLAYER, true)

func spawn_random_enemy() -> void:
	var target_min_radius: float
	var target_max_radius: float

	var player_ref = get_player_slime_node()
	if player_ref and player_ref.alive:
		var player_current_radius = player_ref.radius
		
		target_min_radius = player_current_radius * ENEMY_RADIUS_FACTOR_MIN_OF_PLAYER
		target_max_radius = player_current_radius * ENEMY_RADIUS_FACTOR_MAX_OF_PLAYER
		target_min_radius = max(target_min_radius, ENEMY_ABSOLUTE_MIN_RADIUS)
		target_max_radius = max(target_max_radius, ENEMY_ABSOLUTE_MIN_RADIUS + 1.0) 
		target_max_radius = max(target_max_radius, target_min_radius + 1.0) 

	else:
		target_min_radius = ENEMY_INITIAL_RADIUS_MIN
		target_max_radius = ENEMY_INITIAL_RADIUS_MAX

	var enemy_radius = randf_range(target_min_radius, target_max_radius)
	
	var spawn_pos = Vector2(randf_range(enemy_radius, screen_size.x - enemy_radius), randf_range(enemy_radius, screen_size.y - enemy_radius))
	
	if player_ref and player_ref.alive: 
		var min_dist_from_player = player_ref.radius + enemy_radius + 50.0 
		var attempts = 0
		while spawn_pos.distance_to(player_ref.global_position) < min_dist_from_player and attempts < 10:
			spawn_pos = Vector2(randf_range(enemy_radius, screen_size.x - enemy_radius), randf_range(enemy_radius, screen_size.y - enemy_radius))
			attempts += 1
			
	var random_hue: float = randf()
	var random_saturation: float = randf_range(0.7, 1.0)
	var random_value: float = randf_range(0.6, 1.0)
	var enemy_color: Color = Color.from_hsv(random_hue, random_saturation, random_value, 1.0)

	spawn_slime(spawn_pos, enemy_radius, enemy_color, SlimeEntity.SlimeType.ENEMY, false)
	current_enemy_count += 1

func get_player_slime_node() -> SlimeEntity:
	if player_slime_node_id != -1 and slimes_map.has(player_slime_node_id):
		var player_node = slimes_map[player_slime_node_id]
		if is_instance_valid(player_node) and player_node.alive: 
			return player_node
	return null

func handle_player_vs_enemy(player_s: SlimeEntity, enemy_s: SlimeEntity):
	if game_is_over or not is_instance_valid(player_s) or not player_s.alive or not is_instance_valid(enemy_s) or not enemy_s.alive:
		return

	var player_dsu_data = dsu_instance.get_set_data(player_s.id_num)
	var enemy_dsu_data = dsu_instance.get_set_data(enemy_s.id_num)

	if player_dsu_data.is_empty() or enemy_dsu_data.is_empty():
		printerr("DSU data missing for player (",player_s.id_num,") vs enemy (",enemy_s.id_num,") interaction.")
		return
	if player_dsu_data.root_id == enemy_dsu_data.root_id: return

	if player_dsu_data.total_area > enemy_dsu_data.total_area: 
		var new_root_id = dsu_instance.union_sets(player_s.id_num, enemy_s.id_num)
		if new_root_id != null:
			var new_player_set_data = dsu_instance.get_set_data(new_root_id)
			player_s.update_properties_from_dsu_set(new_player_set_data)
			enemy_s.get_absorbed(player_s.id_num) 
	else: 
		handle_game_over_event() 
		if is_instance_valid(player_s): 
			player_s.get_absorbed(enemy_s.id_num)


func handle_enemy_vs_enemy_merge(slime1: SlimeEntity, slime2: SlimeEntity):
	if game_is_over or not is_instance_valid(slime1) or not slime1.alive or \
	   not is_instance_valid(slime2) or not slime2.alive:
		return
	if slime1 == slime2 : return

	var s1_dsu_data = dsu_instance.get_set_data(slime1.id_num)
	var s2_dsu_data = dsu_instance.get_set_data(slime2.id_num)

	if s1_dsu_data.is_empty() or s2_dsu_data.is_empty():
		printerr("DSU data missing for enemy(",slime1.id_num,") vs enemy (",slime2.id_num,") merge.")
		return
	if s1_dsu_data.root_id == s2_dsu_data.root_id: return

	var absorber: SlimeEntity = slime1
	var absorbee: SlimeEntity = slime2
	if s1_dsu_data.total_area < s2_dsu_data.total_area:
		absorber = slime2
		absorbee = slime1

	var new_root_id = dsu_instance.union_sets(absorber.id_num, absorbee.id_num)
	if new_root_id != null:
		var new_dsu_set_data = dsu_instance.get_set_data(new_root_id)
		absorber.update_properties_from_dsu_set(new_dsu_set_data)
		absorbee.get_absorbed(absorber.id_num)


func _on_slime_absorbed_into_another(absorbee_node: SlimeEntity, _absorber_id_num: int): 
	if not is_instance_valid(absorbee_node): return 
	
	var absorbee_id = absorbee_node.id_num
	if slimes_map.has(absorbee_id):
		slimes_map.erase(absorbee_id) 
		
		if not absorbee_node.is_player_controlled:
			current_enemy_count = max(0, current_enemy_count - 1)
		
		if absorbee_id == player_slime_node_id:
			player_slime_node_id = -1 
			if not game_is_over:
				printerr("CRITICAL: Player node (ID: ", absorbee_id, ") absorbed but game not over!")
				handle_game_over_event() 

		absorbee_node.queue_free()


func handle_slime_eat_food(slime_eater: SlimeEntity, food_item: FoodEntity):
	if not is_instance_valid(slime_eater) or not slime_eater.alive or not is_instance_valid(food_item): return

	var eater_dsu_id = slime_eater.id_num
	var root_id = dsu_instance.find_set(eater_dsu_id)
	if root_id == null: 
		printerr("Slime ", eater_dsu_id, " trying to eat food but not in DSU.")
		return

	dsu_instance.set_total_area[root_id] += FoodEntity.FOOD_GROWTH_AREA
	
	var new_dsu_set_data = dsu_instance.get_set_data(eater_dsu_id)
	if new_dsu_set_data and not new_dsu_set_data.is_empty():
		slime_eater.update_properties_from_dsu_set(new_dsu_set_data)
	
	food_item.get_eaten()


func randomize_and_start_food_timer():
	if not is_instance_valid(food_spawn_timer): return
	var next_interval = randf_range(MIN_FOOD_SPAWN_INTERVAL, MAX_FOOD_SPAWN_INTERVAL)
	food_spawn_timer.wait_time = next_interval
	food_spawn_timer.start()

func _on_food_spawn_timer_timeout():
	if not game_is_over and current_food_count < MAX_FOOD_ON_SCREEN:
		spawn_random_food()
	randomize_and_start_food_timer() 

func spawn_food_at(pos: Vector2):
	var food_instance: FoodEntity = FoodScene.instantiate() as FoodEntity
	food_instance.position = pos
	add_child(food_instance)
	current_food_count += 1
	food_instance.tree_exited.connect(Callable(self, "_on_food_item_removed").bind(food_instance))

func spawn_random_food():
	var margin = 20 
	var random_x = randf_range(margin, screen_size.x - margin)
	var random_y = randf_range(margin, screen_size.y - margin)
	spawn_food_at(Vector2(random_x, random_y))

func _on_food_item_removed(_food_node: Node): 
	if current_food_count > 0:
		current_food_count -= 1


func randomize_and_start_enemy_timer():
	if not is_instance_valid(enemy_spawn_timer): return
	var next_interval = randf_range(MIN_ENEMY_SPAWN_INTERVAL, MAX_ENEMY_SPAWN_INTERVAL)
	enemy_spawn_timer.wait_time = next_interval
	enemy_spawn_timer.start()

func _on_enemy_spawn_timer_timeout():
	var player_node = get_player_slime_node() 
	if not game_is_over and current_enemy_count < MAX_ENEMIES_ON_SCREEN and is_instance_valid(player_node) and player_node.alive:
		spawn_random_enemy()
	randomize_and_start_enemy_timer()


func handle_game_over_event():
	if game_is_over: return
	game_is_over = true
	
	if is_instance_valid(game_over_label): game_over_label.visible = true
	
	if is_instance_valid(food_spawn_timer) and not food_spawn_timer.is_stopped(): food_spawn_timer.stop()
	if is_instance_valid(enemy_spawn_timer) and not enemy_spawn_timer.is_stopped(): enemy_spawn_timer.stop()
	
	var player_node = get_player_slime_node() 
	if is_instance_valid(player_node):
		player_node.is_player_controlled = false
		player_node.play_animation("null") 
	
	for slime_id in slimes_map:
		var s = slimes_map.get(slime_id)
		if s is SlimeEntity and is_instance_valid(s) and s.alive:
			if s.id_num == player_slime_node_id : continue 

			s.enemy_move_speed = 0 
			s.velocity = Vector2.ZERO 
			s.play_animation("idle")
