extends SetBase
## Shown when a set script is missing, so a typo never produces a black hole.

func build(_variant: String) -> void:
	make_env(Color("101014"), Color("8a8a96"), 0.6)
	var m := SetKit.mat(Color("5d5a63"))
	SetKit.room(self, 5, 5, 3, SetKit.mat(Color("3a3840")), m, m, ["s", "e"])
	SetKit.omni(self, Vector3(0, 2.5, 0), Color("ffe9c2"), 1.2, 8)
	add_cam("main", Vector3(4.5, 3.5, 5.5), Vector3(0, 1, 0), 50)
