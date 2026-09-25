extends SetBase
## Not a location: everybody in a row, for checking the figures.

func build(_v: String) -> void:
	title = "LINE-UP"
	make_env(Color("202428"), Color("8a8c90"), 0.9)
	var K := SetKit
	K.box(self, Vector3(14, 0.1, 6), Vector3(0, -0.05, 0), K.mat(Color("6a6a64")))
	K.box(self, Vector3(14, 4, 0.1), Vector3(0, 2, -2), K.mat("paint_cream", 1.0))
	var ids := ["jad", "inez", "dima", "sal", "teodor", "kaye", "nell", "june", "adeyemi"]
	var poses := ["down", "clasp", "forward", "phone", "down", "card", "phone_low", "down", "down"]
	for i in ids.size():
		var look := Figure.cast(ids[i], {"arms": poses[i]})
		if poses[i] == "card":
			look["card"] = "7"
		K.person(self, Vector3(-4.0 + i * 1.0, 0, 0), 0.0, look)
	K.person(self, Vector3(5.5, 0, 0.3), -0.4, {"coat": Color("e8e4d8"), "skin": Color("c8a080"), "hair": Color("3a2a1a"), "robe": true, "shape": "f", "arms": "card", "card": "12", "hair_style": "long"}, "sit_low")
	K.person(self, Vector3(6.4, 0, 0), 0.0, {"coat": Color("1e2430"), "trousers": Color("1e2430"), "skin": Color("d0b098"), "hair": Color("2a2420"), "hair_style": "cap", "cap_tilt": 0.12, "arms": "clasp"})
	K.omni(self, Vector3(0, 3.2, 2.5), Color("fff4e0"), 1.6, 14.0)
	K.omni(self, Vector3(-4, 2.0, 3.0), Color("c0d0ff"), 0.6, 10.0)
	add_cam("main", Vector3(1.0, 1.3, 7.5), Vector3(1.0, 0.95, 0), 48)
	add_cam("heads", Vector3(-3.0, 1.62, 1.6), Vector3(-3.0, 1.6, 0), 34)
	add_cam("heads2", Vector3(0.5, 1.6, 1.7), Vector3(0.5, 1.55, 0), 38)
	add_cam("side", Vector3(6.0, 1.3, 3.2), Vector3(5.8, 0.9, 0), 40)
	add_cam("poses", Vector3(0.0, 1.35, 3.6), Vector3(0.0, 1.15, 0), 40)
	add_cam("sal", Vector3(-0.6, 1.5, 1.4), Vector3(-1.0, 1.35, 0), 50)
