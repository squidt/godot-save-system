@abstract
class_name SaveStep extends Resource

@abstract func title() -> StringName
@abstract func version() -> int
@abstract func is_owner() -> bool
@abstract func is_enabled() -> bool
@abstract func is_reinstantiated() -> bool

@abstract func on_ready(node)
@abstract func to(node: Node) -> Variant
@abstract func from(node: Node, data: Variant) -> void


func prefix() -> Array:
	return [title(), version()]
