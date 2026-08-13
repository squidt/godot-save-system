@tool
class_name SaveTransform3D extends SaveStep


func title() -> StringName:
	return &"xform"


func version() -> int:
	return 0


func on_ready(node):
	pass


func to(node: Node) -> Variant:
	if node is not Node3D:
		return "invalid"

	return _xf_to_str(node.global_transform)


func from(node: Node, data: Variant) -> void:
	node = node as Node3D
	data = data as String
	if !node or !data:
		return

	node.global_transform = _str_to_xf(data)


func _xf_to_str(xf: Transform3D) -> String:
	return (
		"%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s"
		% [
			xf.basis.x.x,
			xf.basis.x.y,
			xf.basis.x.z,
			xf.basis.y.x,
			xf.basis.y.y,
			xf.basis.y.z,
			xf.basis.z.x,
			xf.basis.z.y,
			xf.basis.z.z,
			xf.origin.x,
			xf.origin.y,
			xf.origin.z,
		]
	)


func _str_to_xf(string: String) -> Transform3D:
	var args = string.split_floats(",")
	if args.size() != 12:
		return Transform3D.IDENTITY
	return Transform3D(
		Basis(
			Vector3(args[0], args[1], args[2]),
			Vector3(args[3], args[4], args[5]),
			Vector3(args[6], args[7], args[8])
		),
		Vector3(args[9], args[10], args[11])
	)
