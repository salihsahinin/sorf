extends Node3D
## Arka plan dünyası: İTÜ Ayazağa kampüsü, OpenStreetMap bina izleri (© OpenStreetMap katkıcıları, ODbL).
## veri/itu-binalar.json: her bina {h: yükseklik m, p: [[x, z], ...] metre, ad}. Çarpışma yok, yalnız görüntü.
## Parkur sonsuz alçaldığı için kampüs oyuncunun altında kalacak şekilde izler: yatayda uzaklaşınca
## yeniden ortalanır, düşeyde bulunulan bölümün DERIN metre altına yumuşakça iner.

const DERIN := 220.0

var hedef_y := 0.0
var dogus := Vector3.ZERO   # sokak modunda doğuş: merkeze en yakın yol noktası


func kur(sokak := false) -> void:
	var f := FileAccess.open("res://veri/itu-binalar.json", FileAccess.READ)
	var binalar: Array = JSON.parse_string(f.get_as_text())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in binalar:
		var h: float = b.h
		var poly := PackedVector2Array()
		for q in b.p:
			poly.append(Vector2(q[0], q[1]))
		if poly.size() < 3:
			continue
		# Saat yönü kontrolü: duvar normali dışa baksın.
		var alan := 0.0
		for i in poly.size():
			var a := poly[i]
			var c := poly[(i + 1) % poly.size()]
			alan += a.x * c.y - c.x * a.y
		if alan < 0.0:
			poly.reverse()
		var renk := Color(0.86, 0.82, 0.74) if b.ad == "" else Color(0.78, 0.84, 0.92)
		st.set_color(renk)
		for i in poly.size():
			var a := poly[i]
			var c := poly[(i + 1) % poly.size()]
			var a0 := Vector3(a.x, 0, a.y)
			var c0 := Vector3(c.x, 0, c.y)
			var a1 := a0 + Vector3(0, h, 0)
			var c1 := c0 + Vector3(0, h, 0)
			var n := (c0 - a0).cross(Vector3.UP).normalized()
			for v in [a0, a1, c0, c0, a1, c1]:
				st.set_normal(n)
				st.add_vertex(v)
		var ucgen := Geometry2D.triangulate_polygon(poly)
		for i in range(0, ucgen.size(), 3):
			for j in [0, 2, 1]:
				var q := poly[ucgen[i + j]]
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(q.x, h, q.y))
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	var ag := MeshInstance3D.new()
	ag.mesh = st.commit()
	ag.material_override = m
	add_child(ag)
	_yollar()
	if sokak:
		# Sokak modu: binalar ve zemin çarpışır, oyuncu yerde yürür.
		var govde := StaticBody3D.new()
		var sb := CollisionShape3D.new()
		sb.shape = ag.mesh.create_trimesh_shape()
		govde.add_child(sb)
		var sz := CollisionShape3D.new()
		sz.shape = WorldBoundaryShape3D.new()
		govde.add_child(sz)
		add_child(govde)
	var zemin := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	zemin.mesh = pm
	var zm := StandardMaterial3D.new()
	zm.albedo_color = Color(0.36, 0.46, 0.32)
	zemin.material_override = zm
	zemin.position.y = -0.2
	add_child(zemin)


func izle(oyuncu_konum: Vector3, bolum_y: float, dt: float) -> void:
	var yatay := Vector2(oyuncu_konum.x - position.x, oyuncu_konum.z - position.z)
	if yatay.length() > 1400.0:
		position.x = oyuncu_konum.x
		position.z = oyuncu_konum.z
	hedef_y = bolum_y - DERIN
	if position.y == 0.0:
		position.y = hedef_y
	position.y = lerpf(position.y, hedef_y, minf(1.0, dt * 0.5))


func _yollar() -> void:
	# veri/itu-yollar.json: her yol {g: genişlik m, t: OSM highway türü, p: [[x, z], ...]}. Düz şerit, çarpışmasız.
	var f := FileAccess.open("res://veri/itu-yollar.json", FileAccess.READ)
	var yollar: Array = JSON.parse_string(f.get_as_text())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var en_yakin := INF
	for y in yollar:
		var w: float = y.g * 0.5
		var yaya: bool = y.t in ["footway", "path", "pedestrian", "steps", "cycleway"]
		st.set_color(Color(0.62, 0.6, 0.56) if yaya else Color(0.2, 0.21, 0.23))
		var h := 0.04 if yaya else 0.03
		for i in range(y.p.size() - 1):
			var a := Vector3(y.p[i][0], h, y.p[i][1])
			var b := Vector3(y.p[i + 1][0], h, y.p[i + 1][1])
			if a.distance_to(b) < 0.01:
				continue
			var yan := (b - a).cross(Vector3.UP).normalized() * w
			for v in [a - yan, b - yan, a + yan, a + yan, b - yan, b + yan]:
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
			var d := Vector2(a.x, a.z).length()
			if yaya and d < en_yakin:
				en_yakin = d
				dogus = a
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	var ag := MeshInstance3D.new()
	ag.mesh = st.commit()
	ag.material_override = m
	add_child(ag)
