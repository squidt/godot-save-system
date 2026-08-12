class_name SaveTransform3D extends SaveStep


func title() -> StringName:
	return &"xform"


func version() -> int:
	return 1


func is_owner() -> bool:
	return false


func is_enabled() -> bool:
	return false


func is_reinstantiated() -> bool:
	return false


func on_ready(node):
	pass


func to(node: Node) -> Variant:
	if node is not Node3D:
		return {}

	var xf: Transform3D = node.global_transform
	return "Origin%v, %s" % [xf.origin, var_to_str(xf.basis)]


func from(node: Node, data: Variant) -> void:
	if node is not Node3D:
		return

	var xf: Transform3D = node.global_transform
	var clean = data.replace("Origin(", "").replace("Basis(", "").replace(")", "")
	var args = clean.split_floats(",", false)

	# Invalid
	if args.size() != 12:
		return Transform3D.IDENTITY.translated(Vector3(0, 1, 0))

	# Otherwise
	return Transform3D(
		Basis(
			Vector3(args[3], args[6], args[9]),
			Vector3(args[4], args[7], args[10]),
			Vector3(args[5], args[8], args[11]),
		),
		Vector3(args[0], args[1], args[2])
	)
