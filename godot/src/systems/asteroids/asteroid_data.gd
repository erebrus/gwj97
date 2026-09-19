class_name AsteroidData
extends RefCounted

## One generated asteroid. Pure data - no scene, no node.
## (cell, index) is a stable identity: it survives unload/reload and can be
## written to a save file to remember which rocks have been mined out.

var position: Vector2
var scene: int
var richness: float      ## 0..1 local density, drives size and yield
var mineral: Types.Resources        
var cell: Vector2i
var index: int


func id() -> Vector3i:
	return Vector3i(cell.x, cell.y, index)
