extends Spatial

export var lidar_mesh_scene: PackedScene

const lidar_size = 10000
const max_points = lidar_size * 100

var lidar_ray: Spatial
var camera: Camera

var current_point = 0
var max_random_rotation = 10
var point_per_second = 250

var full_scan_size = 75
var scanning = false

var full_scan_progress = 0

func _physics_process(delta):
	if !scanning:
		if Input.is_action_pressed("attack1"):
			circle_scan(delta)
		elif Input.is_action_pressed("attack2"):
			full_scan()
	else:
		var point_count = ceil(point_per_second * delta)
		point_count *= 15;
		
		for i in range(0, point_count):
			var y = (full_scan_progress + i) / full_scan_size
			var x = ((full_scan_progress + i) as int) % (full_scan_size as int)
			
			var screen_pos = Vector2(x / full_scan_size as float, y / full_scan_size as float)
			screen_pos *= get_tree().root.size
			
			var start = camera.project_ray_origin(screen_pos);
			var end = start + (camera.project_ray_normal(screen_pos) * 2000)
			
			put_point(start, end)
		
		full_scan_progress += point_count;
		if full_scan_progress >= full_scan_size * full_scan_size:
			full_scan_progress = 0;
			scanning = false;

func create_lidar_mesh() -> MultiMeshInstance:
	var mesh = lidar_mesh_scene.instance() as MultiMeshInstance
	mesh.multimesh = mesh.multimesh.duplicate() as MultiMesh
	mesh.multimesh.instance_count = lidar_size
	mesh.multimesh.visible_instance_count = 0
	
	add_child(mesh)
	mesh.set_as_toplevel(true)
	mesh.global_transform = Transform.IDENTITY
	
	return mesh

func remove_lidar_meshes():
	current_point = 0
	for m in get_children():
		m.queue_free()

func set_point(idx, trans, color):
	var mesh_id = idx / lidar_size
	var child_count = get_child_count()
	
	if mesh_id >= child_count:
		create_lidar_mesh()
	
	var mesh = (get_child(mesh_id) as MultiMeshInstance).multimesh
	
	var point_id = idx % lidar_size
	mesh.visible_instance_count = max(mesh.visible_instance_count, point_id + 1)
	mesh.set_instance_transform(point_id, trans)
	mesh.set_instance_color(point_id, color)

func put_point(start, end):
	var space_state = get_world().direct_space_state

	var col = space_state.intersect_ray(start, end, [], 1, true, false);

	if (col != null && col.size() > 0):
		var hit: Vector3 = col["position"]
		var body: Spatial = col["collider"]

		var trans = Transform(Basis.IDENTITY, hit)

		var is_enemy = body.is_in_group("Enemy")

		var color
		if is_enemy: color = Color(1, 0, 0) 
		else: color = Color(0.2, 0.2, 0.2)

		var max_offset = 0.025
		color += Color(
			range_lerp(randf(), 0, 1, -max_offset, max_offset),
			range_lerp(randf(), 0, 1, -max_offset, max_offset),
			range_lerp(randf(), 0, 1, -max_offset, max_offset)
		)

		set_point(current_point, trans, color)

		current_point += 1
		if current_point == max_points:
			 current_point = 0;

func circle_scan(delta):
	if scanning: return
	
	var ps = point_per_second * delta
	
	for i in range(0, ps):
		var vector = Vector2(randf(), randf()).normalized() * randf() * max_random_rotation
		lidar_ray.rotation_degrees = Vector3(vector.x, vector.y, 0)
		
		var start = lidar_ray.global_transform.origin
		var end = start + (-lidar_ray.global_transform.basis.z * 200)
		
		put_point(start, end)

func full_scan():
	if scanning: return
	scanning = true

