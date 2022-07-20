extends KinematicBody

onready var head = $Head
onready var lidar = $LIDARContainer
onready var lidar_ray = $Head/LidarRay
onready var camera = $Head/Camera

var move_speed = 7
var acceleration = 0
var gravity = 17.6
var jump_height = 6
var air_acceleration = 1
var floor_acceleration = 5

var mouse_sensitivity = 0.2
var joystick_sensitivity = 3
var stop_momentum = true
var max_slope_angle = 20
var ground_contact = false
var viewmodel_sway = 1
var in_air = false

var direction: Vector3
var velocity: Vector3
var gravity_vector: Vector3
var movement: Vector3

var fly = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	lidar.lidar_ray = lidar_ray
	lidar.camera = camera

func _process(delta):
	if Input.is_action_just_pressed("toggle_fly"):
		fly = !fly
	
	var h = Input.get_action_strength("look_r") - Input.get_action_strength("look_l")
	var v = Input.get_action_strength("look_up") - Input.get_action_strength("look_dw")
	rotate_camera(h * joystick_sensitivity, v * joystick_sensitivity)
	
	var angle_step = 2
	if Input.is_action_just_released("scan_size_up"):
		lidar.max_random_rotation -= angle_step
	elif Input.is_action_just_released("scan_size_down"):
		lidar.max_random_rotation += angle_step 
	
	clamp(lidar.max_random_rotation, 2, 90)
	
	if Input.is_action_just_pressed("restart"):
		lidar.remove_lidar_meshes()
	
	if Input.is_action_just_pressed("toggle_camera"):
		camera.cull_mask ^= 0xFFFFFFFF

func _physics_process(delta):
	direction = Vector3.ZERO
	in_air = !is_on_floor()
	
	if !fly:
		if in_air: acceleration = air_acceleration
		else: acceleration = floor_acceleration
		
		if Input.is_action_just_pressed("jump") and !in_air:
			jump()
	else:
		in_air = true
		acceleration = floor_acceleration
		gravity_vector = velocity
		
	var direction_not_rotated = Vector3(Input.get_action_strength("look_r") - Input.get_action_strength("look_l"), 0, Input.get_action_strength("move_fw") - Input.get_action_strength("move_bw"))
	
	var dir_node 
	if fly: dir_node = head
	else: dir_node = self
	
	direction -= Input.get_action_strength("move_fw") * dir_node.global_transform.basis.z;
	direction += Input.get_action_strength("move_bw") * dir_node.global_transform.basis.z;
	direction -= Input.get_action_strength("move_l") * dir_node.global_transform.basis.x;
	direction += Input.get_action_strength("move_r") * dir_node.global_transform.basis.x;
	
	if direction.length_squared() > 1:
		direction = direction.normalized()
	
	if stop_momentum:
		var v = velocity
		v.y = 0
		v = v.normalized()

		if direction.dot(v) <= -0.8:
			velocity = Vector3.ZERO;
	
	velocity = velocity.linear_interpolate(direction * move_speed, acceleration * delta)
	
	if (!in_air or is_on_ceiling()):
		gravity_vector = Vector3.ZERO
	else:
		gravity_vector.y -= gravity * delta
		
	movement = velocity + gravity_vector
	if in_air:
		movement = move_and_slide(movement, Vector3.UP, true)
	else:
		movement = move_and_slide_with_snap(movement, -get_floor_normal(), Vector3.UP, true)

func _input(event):
	if event is InputEventMouseMotion:
		rotate_camera(event.relative.x * mouse_sensitivity, event.relative.y * mouse_sensitivity)

func rotate_camera(h, v):
	rotate_y(deg2rad(-h))
	head.rotation = Vector3(clamp(head.rotation.x - deg2rad(v), deg2rad(-89), deg2rad(89)), head.rotation.y, head.rotation.z)

func jump():
	in_air = true
	gravity_vector = Vector3.UP * jump_height
	ground_contact = false
