extends Area2D
class_name FoodEntity

var food_color: Color = Color.GREEN
const FOOD_GROWTH_AREA: float = 75.0
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitoring = true 
	monitorable = true 
	food_color = Color(randf_range(0,0.2), randf_range(0.7,1.0), randf_range(0,0.2))
	queue_redraw() 

func _draw() -> void:
	if collision_shape and collision_shape.shape:
		draw_circle(Vector2.ZERO, collision_shape.shape.radius, food_color)
	else: 
		draw_circle(Vector2.ZERO, 5.0, food_color) 

func get_eaten() -> void:
	queue_free()
