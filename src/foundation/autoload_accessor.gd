# AutoloadAccessor - Helper for accessing autoloads safely in Godot 4.x
# In Godot 4.x, cross-autoload calls require explicit node access

class_name AutoloadAccessor

## Get an autoload singleton by registered name
static func get_singleton(name: String) -> Node:
	var path: String = "/root/" + name
	if not GodotSingletons.has_singleton(name):
		return null
	return GodotSingletons.get_singleton(name)