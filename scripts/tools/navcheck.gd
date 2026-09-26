extends Node
## Builds every walkable set and checks that each hotspot's stand point and
## each door can be reached from every other.
func _ready() -> void:
	var names := ["street", "lobby", "office", "building", "courtyard", "nell", "pool", "exchange", "receiving", "copyshop", "bakery"]
	var bad := 0
	for n in names:
		var st: SetBase = load("res://scripts/sets/set_%s.gd" % n).new()
		add_child(st)
		st.build("")
		if not st.can_walk():
			st.queue_free()
			continue
		var nav := Nav.new()
		nav.build(st)
		var points := {}
		for e in st.entries:
			points["door:" + e] = st.entries[e][0]
		for h in st.hotspots:
			points["spot:" + h] = st.hotspots[h]["stand"]
		var keys := points.keys()
		var start: Vector3 = points[keys[0]]
		for k in keys:
			var p := nav.path(start, points[k])
			if p.is_empty():
				print("UNREACHABLE %s %s from %s" % [n, k, keys[0]])
				bad += 1
		print("checked %s: %d points" % [n, keys.size()])
		st.queue_free()
	print("NAV CHECK DONE, unreachable: %d" % bad)
	get_tree().quit()
