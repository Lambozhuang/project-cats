extends RigidBody2D

var isCarried = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	freeze = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if isCarried == true:
		self.position = get_node("../Player/Marker2D").get_global_position()


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("carry"):
		print("carry the item")
		var bodies = $Area2D.get_overlapping_bodies()
		for body in bodies:
			if body.name == "Player" and get_node("../Player").canCarry == true:
				isCarried = true
				get_node("../Player").canCarry = false
				freeze = true
				
	elif Input.is_action_just_released("carry"):
		if isCarried:
			print("release the item")
			isCarried = false
			get_node("../Player").canCarry = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	print("touch item")
