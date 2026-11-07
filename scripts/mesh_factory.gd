extends RefCounted

## Helpers for building the low-poly 3D world entirely from primitives.


static func make_material(
	color: Color,
	metallic: float = 0.05,
	roughness: float = 0.75,
	emission: Color = Color(0.0, 0.0, 0.0),
	energy: float = 0.0,
	unshaded: bool = false,
	transparent: bool = false,
	billboard: bool = false,
	vertex_color: bool = false,
	no_depth: bool = false
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission != Color(0.0, 0.0, 0.0):
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = maxf(energy, 0.001)
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if billboard:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.billboard_keep_scale = true
	if vertex_color:
		material.vertex_color_use_as_albedo = true
	if no_depth:
		material.no_depth_test = true
	return material


static func add_mesh(
	parent: Node,
	mesh: Mesh,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var material: Material
	if opts.has("material"):
		material = opts["material"]
	else:
		material = make_material(
			color,
			float(opts.get("metallic", 0.05)),
			float(opts.get("roughness", 0.75)),
			opts.get("emission", Color(0.0, 0.0, 0.0)),
			float(opts.get("energy", 0.0)),
			bool(opts.get("unshaded", false)),
			bool(opts.get("transparent", false)),
			bool(opts.get("billboard", false)),
			bool(opts.get("vertex_color", false)),
			bool(opts.get("no_depth", false))
		)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = opts.get("rotation", Vector3.ZERO)
	instance.scale = opts.get("scale", Vector3.ONE)
	instance.cast_shadow = int(opts.get("cast_shadow", GeometryInstance3D.SHADOW_CASTING_SETTING_ON))
	if opts.has("name"):
		instance.name = str(opts["name"])
	parent.add_child(instance)
	return instance


static func add_box(
	parent: Node,
	size: Vector3,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return add_mesh(parent, mesh, position, color, opts)


static func add_sphere(
	parent: Node,
	radius: float,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = int(opts.get("segments", 20))
	mesh.rings = int(opts.get("rings", 10))
	return add_mesh(parent, mesh, position, color, opts)


static func add_cylinder(
	parent: Node,
	radius: float,
	height: float,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = int(opts.get("segments", 16))
	return add_mesh(parent, mesh, position, color, opts)


static func add_cone(
	parent: Node,
	radius: float,
	height: float,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = int(opts.get("segments", 14))
	return add_mesh(parent, mesh, position, color, opts)


static func add_capsule(
	parent: Node,
	radius: float,
	height: float,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = int(opts.get("segments", 16))
	mesh.rings = int(opts.get("rings", 8))
	return add_mesh(parent, mesh, position, color, opts)


static func add_torus(
	parent: Node,
	inner_radius: float,
	outer_radius: float,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = int(opts.get("rings", 32))
	mesh.ring_segments = int(opts.get("ring_segments", 8))
	return add_mesh(parent, mesh, position, color, opts)


static func add_quad(
	parent: Node,
	size: Vector2,
	position: Vector3,
	color: Color,
	opts: Dictionary = {}
) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	return add_mesh(parent, mesh, position, color, opts)
