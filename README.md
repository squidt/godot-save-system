!!! This README and project is still in the drafting phase !!!

# Purpose

- Allow flexible map-based saving a la STALKER and semi-open-world games with distinct maps/ areas that are revisitable. Let Godot's built in scene-instantiation do most of the heavy lifting and only serialize important parts that changed since instantiation such as position, velocity, and other steps.
- Modular `SaveSteps` that only save particular aspects of the object, allowing for custom written behavior during serialization/ deserialization. Need to call functions, establish relationships, navigate state machines after deserializing? No problem! Maybe!
- Ownership model that allows for use in a 'staging' system where maps are added and removed.
- Ownership model that allows 'picked up' items to disable their saving and allow another node to perform their serialization instead. This prevents duplicated objects between level transitions and saving/ loading events.

# Install

Copy the folder "squid-save" from "addons/squid-save" into your Godot's "addons/" folder and enable the plugin in settings.

# Design

Relies entirely on Godot's uid and scene system to recreate saved nodes from save files and deserialize them.

## Ownership model

- None: Nodes that opt-out of ownership will not serialize descendant nodes, instead relying on a valid "Save Owner" ancestor
- Auto: Nodes that are valid scenes and can be instantiated through the UID system are by default owners of nodes under them and will be responsible for serializing them. Ownership of child/ grandchildren nodes stops where another valid "Save Owner" begins.
- Manual: Useful for custom serialization/ deserialization of descendants. Ancestor Save Owners will not try to save descendants of this node, but it is now responsible for serializing them through either ensuring a `SaveStep` exists that performs that task (recommended) or inheriting and extending `Saveable::serialize/deserialize`

## Recreation model

- None: This node will NOT be freed and reinstantiated, instead relying on whichever owner exists above it and Godot's scene structure to reinstantiate it. If it has any saved data it will be set via its `NodePath` at the time of saving. If the `NodePath` changes between serializations this behavior will not deserialize. This is useful for objects that exist in a scene which may be 'recreatable' such as a scene of an Area3D with specific properties set, but doesn't need to change or save these properties in the save file. This is used when it is preferred to not reinstantiate and lose those scene-set-properties.
- Auto: Nodes that can be reinstantiated will be, then deserialized. Otherwise, the behavior is the same as `None`

# How to

- Add `Saveable` to scene root
- Add `SaveSteps` the easiest of which is `SaveProperties` which saves and loads properties using JSON.from_native and JSON.to_native. It can take any non-full-object variant. (No resources for security concerns).

# Flaws

- Ownership model and tree structure performs a lot of the heavy lifting of relationships, setup may be unintuitive
  - additionally, if there is a 'MyObject -> (owns) -> OtherObject link, the recommended procedure is that 'OtherObject' disable its save and 'MyObject' de/serializes 'OtherObject' through a custom SaveStep, spawns it in the world, and re-establishes the link. "Spawns it in the world" may mean a 'staging system' that keeps track of the current map.

- Probably doesn't work in release due to uid's not being exported. This is solvable but not implemented yet.
- Doesn't support Editable Children where `Saveable.behavior.steps` is changed. The system relies on loading a .tscn from its uid in the save file, which will contain the scenes current save behavior
- Not yet supporting save version conversions
- Changes to save behaviors where `SaveStep`s are added or removed to `Saveable.behavior` will cause loading a save from disk to only serialize/ deserialize what that scene's `Saveable.behavior` currently is.
- AKA there is no versioning of save steps, and no "figuring out" which `SaveStep` resources are saved in the file itself. Only the instantiated scene's save behavior matters.

# TODO

- uh
- encryption
- testing in my own games for flaws/ rewrites
- optionally saving to binary or json instead of only json. json conversion is called in `SaveManager` (core/manager.gd) so if you do need this just change it there.
