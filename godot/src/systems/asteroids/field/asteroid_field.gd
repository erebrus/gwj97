class_name AsteroidField
extends Node2D

## Deterministic, streamable asteroid placement.
##
## The map is a pure function of (world_seed, cell coordinates). Nothing is
## stored, so a cell regenerates identically every time the ship returns to it
## and an infinite world costs no memory. The only persistent state is the set
## of asteroids the player has already mined out.

@export var cell_size := 1500            ## world units per grid cell
@export var  max_per_cell := 4       ## upper bound on asteroids in one cell
@export var  min_dist := 450.0        ## minimum spacing. MUST be <= CELL (3x3 check)
@export var  base_density := .8     ## expected count in the emptiest regions
@export var  clumpiness := 3.0       ## gamma on the density field; higher = rarer, tighter fields
@export var  mineral_count := 3
@export var  mineral_weights :Array[float]= [0.6,.35,.15]
@export var seed_value := 1337 
var world_seed: int = 0
@export var station:Station
@export var clear_radius := 800

var _density := FastNoiseLite.new()
var _ore := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()

var _clear_zones: Array[Vector3] = []   ## x,y = centre, z = radius
var _cand_cache: Dictionary = {}        ## Vector2i -> Array[Dictionary]
var _mined: Dictionary = {}             ## Vector3i -> true

func _ready():
	assert(min_dist <= cell_size, "min_dist must be <= CELL or the 3x3 spacing check misses neighbours")
	world_seed = seed_value

	# Large-scale density field. Low frequency = big asteroid fields.
	_density.seed = seed_value
	_density.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_density.frequency = 0.0012
	_density.fractal_type = FastNoiseLite.FRACTAL_FBM
	_density.fractal_octaves = 3

	# Ore field, deliberately uncorrelated with density: the richest rocks
	# should not always sit in the safest, densest clusters.
	_ore.seed = seed_value + 7919
	_ore.noise_type = FastNoiseLite.TYPE_CELLULAR
	_ore.frequency = 0.0025
	_ore.fractal_type = FastNoiseLite.FRACTAL_NONE
	_ore.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_ore.cellular_jitter = 1.0
	
	add_clear_zone(station.global_position, clear_radius)   # keep the home station clear


#region Public API

## Keeps spawn and station approaches free of rock.
func add_clear_zone(centre: Vector2, radius: float) -> void:
	_clear_zones.append(Vector3(centre.x, centre.y, radius))
	_cand_cache.clear()


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / cell_size), floori(world_pos.y / cell_size))


## Every asteroid in one grid cell, spacing already resolved.
func get_cell_asteroids(cell: Vector2i) -> Array[AsteroidData]:
	var result: Array[AsteroidData] = []

	var mine: Array = _candidates(cell)
	if mine.is_empty():
		return result

	var neighbours: Array = []
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			neighbours.append_array(_candidates(cell + Vector2i(ox, oy)))

	for c in mine:
		if _mined.has(_candidate_id(c)):
			continue
		if _blocked(c, mine) or _blocked(c, neighbours):
			continue
		result.append(_build(c))

	return result


## Every asteroid overlapping a world-space rectangle.
func query_rect(rect: Rect2) -> Array[AsteroidData]:
	var result: Array[AsteroidData] = []
	var from := world_to_cell(rect.position)
	var to := world_to_cell(rect.end)
	for cy in range(from.y, to.y + 1):
		for cx in range(from.x, to.x + 1):
			result.append_array(get_cell_asteroids(Vector2i(cx, cy)))
	return result


## 0..1 expected local density. Useful for radar overlays and spawn logic.
func density_at(world_pos: Vector2) -> float:
	var n := _density.get_noise_2dv(world_pos) * 0.5 + 0.5   # -1..1 -> 0..1
	n = clampf((n - 0.35) / 0.45, 0.0, 1.0)                  # stretch, then saturate
	n = pow(n, clumpiness)
	return n * _clearance(world_pos)


func mark_mined(asteroid: AsteroidData) -> void:
	_mined[asteroid.id()] = true


func is_mined(asteroid: AsteroidData) -> bool:
	return _mined.has(asteroid.id())


func save_state() -> Dictionary:
	return {"seed": world_seed, "mined": _mined.keys()}


func load_state(data: Dictionary) -> void:
	world_seed = data.get("seed", world_seed)
	_mined.clear()
	for k in data.get("mined", []):
		_mined[k] = true

#endregion


#region Generation

## Raw jittered-grid candidates for one cell, before spacing rejection.
## Deterministic: depends only on world_seed and the cell coordinates.
func _candidates(cell: Vector2i) -> Array:
	if _cand_cache.has(cell):
		return _cand_cache[cell]

	_rng.seed = _cell_seed(cell)

	var origin := Vector2(cell) * cell_size
	var d := density_at(origin + Vector2(cell_size, cell_size) * 0.5)
	var expected := lerpf(base_density, float(max_per_cell), d)

	# Integer part, plus the fractional part rolled probabilistically. This is
	# what lets a field average e.g. 1.7 asteroids per cell.
	var count := int(expected)
	if _rng.randf() < expected - float(count):
		count += 1

	var out: Array = []
	for i in count:
		out.append({
			"pos": origin + Vector2(_rng.randf(), _rng.randf()) * cell_size,
			"cell": cell,
			"index": i,
			"density": d,
		})

	if _cand_cache.size() > 4096:
		_cand_cache.clear()
	_cand_cache[cell] = out
	return out


## A candidate dies if it lands too close to any GLOBALLY EARLIER candidate.
## Ordering by (cell.y, cell.x, index) is what makes this order-independent:
## the result does not depend on which chunk the player streamed in first, so
## there are no seams at chunk borders.
func _blocked(c: Dictionary, others: Array) -> bool:
	var limit := min_dist * min_dist
	var pos: Vector2 = c["pos"]
	for o in others:
		if not _is_earlier(o, c):
			continue
		if pos.distance_squared_to(o["pos"]) < limit:
			return true
	return false


func _is_earlier(a: Dictionary, b: Dictionary) -> bool:
	var ca: Vector2i = a["cell"]
	var cb: Vector2i = b["cell"]
	if ca.y != cb.y:
		return ca.y < cb.y
	if ca.x != cb.x:
		return ca.x < cb.x
	return int(a["index"]) < int(b["index"])


func _build(c: Dictionary) -> AsteroidData:
	var a := AsteroidData.new()
	a.position = c["pos"]
	a.cell = c["cell"]
	a.index = int(c["index"])

	# Per-asteroid randomness from a hash, NOT from the RNG stream, so cells
	# can be built in any order without shifting results.
	var h := _mix(_cell_seed(a.cell) ^ _mix(a.index * 0x9E3779B1 + 1))
	var t := float(h & 0xFFFF) / 65535.0
	print("t:%3f" % t)
	a.richness = t

	#a.radius = lerpf(6.0, 22.0, t * t)            # small rocks common, big ones rare
	#a.radius *= lerpf(0.8, 1.35, a.richness)      # denser fields run bigger
	a.scene = t * 65535
	a.mineral = _mineral_at(a.position, t)
	#print ("mineral: ", a.mineral)
	return a


	
func _mineral_at(p: Vector2, t: float) -> int:
	var v := _ore.get_noise_2dv(p) * 0.5 + 0.5
	if t > 0.85:
		v = fposmod(v + 0.37, 1.0)
	var acc := 0.0
	for i in mineral_weights.size():
		acc += mineral_weights[i]
		if v < acc:
			return i
	return mineral_weights.size() -1
	
	#var band := int(v * mineral_count)
	#if t > 0.85:                                   # a little variety inside a band
		#band += 1
	#return clampi(band % mineral_count, 0, mineral_count - 1)


func _clearance(p: Vector2) -> float:
	var f := 1.0
	for z in _clear_zones:
		var dist := p.distance_to(Vector2(z.x, z.y))
		f = minf(f, smoothstep(z.z * 0.5, z.z, dist))
	return f

#endregion


#region Hashing

## Neighbouring cells must get thoroughly unrelated seeds. Feeding a PRNG
## nearby seeds (seed + cx * 1000 + cy) produces correlated first outputs,
## which shows up as diagonal streaks across the asteroid field.
func _cell_seed(cell: Vector2i) -> int:
	return _mix(world_seed ^ _mix(cell.x) ^ _mix(cell.y * 0x9E3779B1))


static func _candidate_id(c:Dictionary) -> Vector3:
	var cell := Vector2i (c["cell"])
	return Vector3i(cell.x,cell.y, int(c["index"]))

static func _mix(v: int) -> int:
	var a := v & 0xFFFFFFFF
	a = ((a ^ (a >> 16)) * 0x7FEB352D) & 0xFFFFFFFF
	a = ((a ^ (a >> 15)) * 0x846CA68B) & 0xFFFFFFFF
	return (a ^ (a >> 16)) & 0xFFFFFFFF

#endregion
