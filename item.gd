extends Node2D

var isCarried = false

func _physics_process(delta: float) -> void:
	if isCarried == true:
		var attach_point = get_node("../../Player/Marker2D").get_global_position()
		var offset = Vector2(0, -20)  # Adjust the x value as desired
		self.position = attach_point + offset


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("carry"):
		print("carry the item")
		var bodies = $Area2D.get_overlapping_bodies()
		for body in bodies:
			if body.name == "Player" and get_node("../../Player").canCarry == true:
				isCarried = true
				get_node("../../Player").canCarry = false
				
	elif Input.is_action_just_released("carry"):
		if isCarried:
			print("release the item")
			isCarried = false
			self.position = self.position - Vector2(0, -40)
			get_node("../../Player").canCarry = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	print("touch item")
