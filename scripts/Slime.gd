extends CharacterBody2D
class_name SlimeEntity

enum SlimeType { PLAYER, ENEMY }

@onready var animated_sprite: AnimatedSprite2D = $Node2D/AnimatedSprite2D
@onready var physics_collision_shape_node: CollisionShape2D = $PhysicsCollisionShape
@onready var detection_area: Area2D = $DetectionArea

var id_num: int = 0
var base_sprite_radius: float = 7.0
var radius: float = 7.0:
	set(value):
		radius = value
		if is_inside_tree(): 
			update_all_shapes_and_visuals()
var alive: bool = true

const CAPSULE_HEIGHT_TO_RADIUS_RATIO: float = 3

var slime_type: SlimeType = SlimeType.ENEMY
var is_player_controlled: bool = false
var visual_color: Color = Color.WHITE : 
	set(value):
		visual_color = value
		if animated_sprite:
			animated_sprite.modulate = visual_color

var original_radius: float 
var original_color: Color 

var move_speed: float = 150.0
var enemy_move_speed: float = 70.0

var move_direction: Vector2 = Vector2.ZERO 
var current_animation: String = "idle"
var change_dir_timer: float = 0.0 
const MIN_DIR_CHANGE_TIME: float = 1.0
const MAX_DIR_CHANGE_TIME: float = 3.0

signal game_over
signal absorbed_into_another(absorbee_node: SlimeEntity, absorber_id_num: int)

func _ready() -> void:
	if detection_area and not detection_area.is_connected("area_entered", Callable(self, "_on_DetectionArea_area_entered")):
		detection_area.connect("area_entered", Callable(self, "_on_DetectionArea_area_entered"))
	elif not detection_area:
		printerr("Slime ID ", id_num, ": DetectionArea node not found in _ready!")

	if physics_collision_shape_node:
		if physics_collision_shape_node.shape:
			physics_collision_shape_node.shape = physics_collision_shape_node.shape.duplicate()
		else:
			printerr("Slime ID ", id_num, ": PhysicsCollisionShape has no shape. Creating Capsule.")
			physics_collision_shape_node.shape = CapsuleShape2D.new()
		physics_collision_shape_node.rotation_degrees = 90
	else:
		printerr("Slime ID ", id_num, ": CRITICAL - PhysicsCollisionShape node not found.")

	var detection_shape_child_node = detection_area.get_node_or_null("CollisionShape2D")
	if detection_shape_child_node:
		if detection_shape_child_node.shape:
			detection_shape_child_node.shape = detection_shape_child_node.shape.duplicate()
		else:
			printerr("Slime ID ", id_num, ": DetectionArea's CollisionShape has no shape. Creating Capsule.")
			detection_shape_child_node.shape = CapsuleShape2D.new()
		detection_shape_child_node.rotation_degrees = 90
	else:
		printerr("Slime ID ", id_num, ": DetectionArea has no child CollisionShape2D.")

	if animated_sprite and animated_sprite.modulate != visual_color:
		animated_sprite.modulate = visual_color

	update_all_shapes_and_visuals() 
	
	if slime_type == SlimeType.ENEMY and move_direction == Vector2.ZERO and not is_player_controlled:
		randomize_enemy_direction()
	
	play_animation("idle")


func update_all_shapes_and_visuals():
	update_specific_collision_shape(physics_collision_shape_node)
	if detection_area:
		var detection_shape_child = detection_area.get_node_or_null("CollisionShape2D")
		if detection_shape_child:
			update_specific_collision_shape(detection_shape_child)
	update_visual_scale()

func update_specific_collision_shape(shape_owner_node: CollisionShape2D):
	if shape_owner_node and shape_owner_node.shape:
		if shape_owner_node.shape is CapsuleShape2D:
			var capsule: CapsuleShape2D = shape_owner_node.shape
			capsule.radius = self.radius
			capsule.height = self.radius * CAPSULE_HEIGHT_TO_RADIUS_RATIO

func _physics_process(delta: float) -> void:
	if not alive:
		play_animation("null")
		velocity = Vector2.ZERO 
		move_and_slide()
		return

	var input_direction = Vector2.ZERO 
	var new_animation = current_animation 
	var is_moving = false

	if self.is_player_controlled: 
		if Input.is_action_pressed("move_right"): input_direction.x += 1; is_moving = true
		if Input.is_action_pressed("move_left"):  input_direction.x -= 1; is_moving = true
		if Input.is_action_pressed("move_down"):  input_direction.y += 1; is_moving = true
		if Input.is_action_pressed("move_up"):    input_direction.y -= 1; is_moving = true

		if is_moving:
			if abs(input_direction.x) > abs(input_direction.y):
				if input_direction.x > 0: new_animation = "right";
				else: new_animation = "left";
			elif abs(input_direction.y) > 0:
				new_animation = "down" if input_direction.y > 0 else "up"
		else:
			new_animation = "idle"
		play_animation(new_animation)

		if input_direction.length_squared() > 0:
			velocity = input_direction.normalized() * move_speed 
		else:
			velocity = Vector2.ZERO

	elif self.slime_type == SlimeType.ENEMY: 
		if abs(move_direction.x) > abs(move_direction.y):
			if move_direction.x > 0: play_animation("right");
			elif move_direction.x < 0: play_animation("left");
		elif abs(move_direction.y) > 0:
			if move_direction.y > 0: play_animation("down")
			elif move_direction.y < 0: play_animation("up")
		else:
			play_animation("idle")

		velocity = move_direction * enemy_move_speed
		
		change_dir_timer -= delta
		if change_dir_timer <= 0:
			randomize_enemy_direction()
	
	move_and_slide()

	if self.slime_type == SlimeType.ENEMY and get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision: KinematicCollision2D = get_slide_collision(i)
			if collision and collision.get_collider() is StaticBody2D: 
				move_direction = move_direction.bounce(collision.get_normal())
				global_position += collision.get_normal() * 0.5 
				break 


func play_animation(anim_name: String):
	if not animated_sprite or not animated_sprite.sprite_frames: return
	if anim_name == "null":
		if animated_sprite.is_playing(): animated_sprite.stop()
		current_animation = "null"
		return
	if animated_sprite.sprite_frames.has_animation(anim_name):
		if current_animation != anim_name or not animated_sprite.is_playing():
			animated_sprite.play(anim_name)
			current_animation = anim_name

func update_visual_scale():
	if animated_sprite:
		var scale_factor = self.radius / base_sprite_radius
		animated_sprite.scale = Vector2(scale_factor, scale_factor)

func randomize_enemy_direction():
	move_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	if move_direction == Vector2.ZERO:
		move_direction = Vector2.RIGHT.rotated(randf_range(0, TAU))
	change_dir_timer = randf_range(MIN_DIR_CHANGE_TIME, MAX_DIR_CHANGE_TIME)

func initialize(p_id: int, p_pos: Vector2, p_init_radius: float, p_init_color: Color, p_base_type: SlimeType, p_is_initially_player: bool = false) -> void:
	self.id_num = p_id
	self.global_position = p_pos
	
	self.original_radius = p_init_radius
	self.original_color = p_init_color
	
	self.slime_type = p_base_type
	self.is_player_controlled = p_is_initially_player
	self.visual_color = p_init_color 

	self.radius = p_init_radius 
	
	if self.slime_type == SlimeType.ENEMY and not self.is_player_controlled:
		randomize_enemy_direction()

func get_absorbed(absorber_node_id: int) -> void:
	if alive:
		alive = false
		set_physics_process(false)

		if physics_collision_shape_node:
			physics_collision_shape_node.set_deferred("disabled", true)
		if detection_area:
			var det_shape = detection_area.get_node_or_null("CollisionShape2D")
			if det_shape : det_shape.set_deferred("disabled", true)
			detection_area.set_deferred("monitoring", false)
			detection_area.set_deferred("monitorable", false)

		play_animation("null") 
		if animated_sprite: animated_sprite.set_deferred("visible", false)
		
		emit_signal("absorbed_into_another", self, absorber_node_id)

func update_properties_from_dsu_set(dsu_set_data: Dictionary) -> void:
	if not dsu_set_data or not dsu_set_data.has("total_area"):
		printerr("Slime ", id_num, ": Invalid DSU data received for update. Data: ", str(dsu_set_data))
		self.radius = self.original_radius if self.original_radius > 0 else 1.0
		self.visual_color = self.original_color if self.original_color else Color.MAGENTA
		self.is_player_controlled = (self.slime_type == SlimeType.PLAYER) 
		return

	var total_area = dsu_set_data.get("total_area", PI * pow(self.original_radius if self.original_radius > 0 else 1.0, 2))
	var color_sum: Color = dsu_set_data.get("color_sum", self.original_color if self.original_color else Color.BLACK)
	var num_elements = dsu_set_data.get("size", 1)
	
	if total_area > 0.001:
		self.radius = sqrt(total_area / PI)
	else:
		self.radius = 1.0

	if num_elements > 0:
		self.visual_color = Color(
			color_sum.r / float(num_elements),
			color_sum.g / float(num_elements),
			color_sum.b / float(num_elements),
			color_sum.a / float(num_elements) 
		)
	else:
		self.visual_color = self.original_color if self.original_color else Color.MAGENTA 

	self.is_player_controlled = dsu_set_data.get("is_player", false)
	
	if self.is_player_controlled:
		self.slime_type = SlimeType.PLAYER 
		

func _on_DetectionArea_area_entered(area_that_entered_detection_zone: Area2D) -> void:
	if not alive or area_that_entered_detection_zone == detection_area : return

	var main_node = get_tree().get_root().get_node_or_null("main")
	if not main_node: 
		printerr("Main node not found in Slime ID ", id_num, " for detection!")
		return

	if area_that_entered_detection_zone is FoodEntity:
		var food_item: FoodEntity = area_that_entered_detection_zone as FoodEntity
		if food_item.is_inside_tree() and food_item.has_method("get_eaten"):
			if main_node.has_method("handle_slime_eat_food"):
				main_node.handle_slime_eat_food(self, food_item)
	
	elif area_that_entered_detection_zone.get_parent() is SlimeEntity:
		var other_slime_entity: SlimeEntity = area_that_entered_detection_zone.get_parent() as SlimeEntity
		if not other_slime_entity.alive or other_slime_entity == self : return

		var self_is_eff_player = self.is_player_controlled
		var other_is_eff_player = other_slime_entity.is_player_controlled

		if self_is_eff_player and not other_is_eff_player:
			if main_node.has_method("handle_player_vs_enemy"):
				main_node.handle_player_vs_enemy(self, other_slime_entity)
		elif not self_is_eff_player and other_is_eff_player: 
			if main_node.has_method("handle_player_vs_enemy"):
				main_node.handle_player_vs_enemy(other_slime_entity, self) 
		elif not self_is_eff_player and not other_is_eff_player: 
			if main_node.has_method("handle_enemy_vs_enemy_merge"):
				main_node.handle_enemy_vs_enemy_merge(self, other_slime_entity)
