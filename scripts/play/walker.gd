class_name Walker
extends Node
## Walks a Figure along a path: legs from the hip and knee, the free arm
## swinging against them, a small drop at each step, turning into the
## direction of travel. Stands and breathes when there's nowhere to go.

signal arrived()

const SPEED := 1.15  # m/s: late, tired, indoors
const STRIDE := 0.62

var fig: Node3D
var path := PackedVector3Array()
var face_to := Vector3.INF
var moving := false
var phase := 0.0
var amp := 0.0  # 0 standing .. 1 full stride
var _pelvis: Node3D
var _legs: Array = []
var _knees: Array = []
var _arms: Array = []
var _elbows: Array = []
var _rest: Dictionary = {}
var _hip_y := 0.0
var _breath := 0.0
var _pending_arrive := false
var free_arms := [true, true]  # arms held in a pose (a phone at the ear) don't swing
var hurry := false  # a double click: get there

func setup(f: Node3D) -> void:
	fig = f
	_pelvis = f.get_node_or_null("pelvis")
	if _pelvis == null:
		return
	_hip_y = _pelvis.position.y
	for side in ["leg_l", "leg_r"]:
		var leg := _pelvis.get_node_or_null(side)
		_legs.append(leg)
		_knees.append(leg.get_node_or_null("knee") if leg else null)
	for side in ["arm_l", "arm_r"]:
		var arm := _pelvis.get_node_or_null(side)
		_arms.append(arm)
		_elbows.append(arm.get_node_or_null("elbow") if arm else null)
	for n in _legs + _knees + _arms + _elbows:
		if n:
			_rest[n] = n.rotation
	# an arm already folded up (phone, bag) keeps its pose
	for i in 2:
		var arm: Node3D = _arms[i]
		if arm and absf(arm.rotation.x) > 0.5:
			free_arms[i] = false

func go(p: PackedVector3Array, face: Vector3 = Vector3.INF, fast: bool = false) -> void:
	hurry = fast
	path = p
	face_to = face
	if path.size() > 0 and fig and Vector2(path[0].x - fig.position.x, path[0].z - fig.position.z).length() < 0.05:
		path.remove_at(0)
	moving = path.size() > 0
	_pending_arrive = true
	if not moving and face_to == Vector3.INF:
		_arrive()

func stop() -> void:
	path = PackedVector3Array()
	moving = false
	_pending_arrive = false

func place(pos: Vector3, rot_y: float) -> void:
	stop()
	if fig:
		fig.position = pos
		fig.rotation.y = rot_y

func _arrive() -> void:
	if _pending_arrive:
		_pending_arrive = false
		arrived.emit()

func _process(d: float) -> void:
	if fig == null or not is_instance_valid(fig):
		return
	var turning := false
	if moving:
		var target := path[0]
		var to := Vector3(target.x - fig.position.x, 0, target.z - fig.position.z)
		var dist := to.length()
		var left := dist
		for k in range(1, path.size()):
			left += path[k].distance_to(path[k - 1])
		var pace := clampf(1.0 + (left - 3.0) * 0.12, 1.0, 2.1) * (2.0 if hurry else 1.0)
		var step := SPEED * pace * d * clampf(amp * 1.6, 0.35, 1.0)
		if dist <= step:
			fig.position = Vector3(target.x, fig.position.y, target.z)
			path.remove_at(0)
			if path.is_empty():
				moving = false
		else:
			fig.position += to / dist * step
		if dist > 0.001:
			turning = _turn_toward(atan2(to.x, to.z), d * 9.0)
		var before := int(floor(phase / PI))
		phase += step / (STRIDE * (1.25 if hurry else 1.0)) * PI
		if int(floor(phase / PI)) != before:
			_footstep()
		amp = move_toward(amp, 1.0, d * 4.0)
	else:
		amp = move_toward(amp, 0.0, d * 5.0)
		if face_to != Vector3.INF:
			var dir := face_to - fig.position
			turning = _turn_toward(atan2(dir.x, dir.z), d * 7.0)
		if not turning and _pending_arrive:
			_arrive()
	_pose(d)

var floor_sound := "tile"
var is_player := true

func _footstep() -> void:
	var v := -17.0 if is_player else -23.0
	Audio.sfx("step_%s_%d" % [floor_sound, randi() % 4 + 1], v, true)

func _turn_toward(want: float, rate: float) -> bool:
	var cur := fig.rotation.y
	var diff := wrapf(want - cur, -PI, PI)
	if absf(diff) < 0.03:
		fig.rotation.y = want
		return false
	fig.rotation.y = cur + clampf(diff, -rate, rate)
	return absf(diff) > 0.25

func _pose(d: float) -> void:
	if _pelvis == null:
		return
	_breath += d
	var s := sin(phase)
	var reduce := 0.6 if Settings.reduced_motion else 1.0
	var a := amp * reduce
	_pelvis.position.y = _hip_y - absf(cos(phase)) * 0.018 * a + sin(_breath * 1.7) * 0.002
	for i in 2:
		var sign := 1.0 if i == 0 else -1.0
		var leg: Node3D = _legs[i]
		var knee: Node3D = _knees[i]
		if leg:
			var r0: Vector3 = _rest[leg]
			leg.rotation = r0 + Vector3(-s * sign * 0.42 * a, 0, 0)
		if knee:
			var k0: Vector3 = _rest[knee]
			knee.rotation = k0 + Vector3(maxf(0.0, s * sign) * 0.55 * a + 0.05 * a, 0, 0)
		var arm: Node3D = _arms[i]
		var el: Node3D = _elbows[i]
		if arm and free_arms[i]:
			var q0: Vector3 = _rest[arm]
			arm.rotation = q0 + Vector3(s * sign * 0.3 * a, 0, 0)
			if el:
				var e0: Vector3 = _rest[el]
				el.rotation = e0 + Vector3(-0.2 * a - maxf(0.0, s * sign) * 0.15 * a, 0, 0)
