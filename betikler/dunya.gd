extends Node3D
## Arka plan dünyası: İTÜ Ayazağa kampüsü, OpenStreetMap bina izleri (© OpenStreetMap katkıcıları, ODbL).
## veri/itu-binalar.json: her bina {h: yükseklik m, p: [[x, z], ...] metre, ad}. Çarpışma yok, yalnız görüntü.
## Parkur sonsuz alçaldığı için kampüs oyuncunun altında kalacak şekilde izler: yatayda uzaklaşınca
## yeniden ortalanır, düşeyde bulunulan bölümün DERIN metre altına yumuşakça iner.

const DERIN := 220.0

var hedef_y := 0.0
var dogus := Vector3.ZERO
var bina_kutulari := {}   # 20 m hücre → bina AABB listesi (ağaç yerleşimi için)
var yol_parcalari: Array = []   # [a, b, yarı genişlik, yaya]
var galeri: Array = []   # sabit kamera noktaları [konum, yaw]   # sokak modunda doğuş: merkeze en yakın yol noktası


func kur(sokak := false) -> void:
	var f := FileAccess.open("res://veri/itu-binalar.json", FileAccess.READ)
	var binalar: Array = JSON.parse_string(f.get_as_text())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in binalar:
		_kutu_kaydet(b.p)
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
		var palet := [Color(0.82, 0.78, 0.70), Color(0.74, 0.72, 0.68), Color(0.70, 0.52, 0.42), Color(0.88, 0.86, 0.80), Color(0.62, 0.64, 0.66)]
		var renk: Color = palet[absi(hash(str(b.p[0]))) % palet.size()]
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
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaderlar/bina.gdshader")
	var ag := MeshInstance3D.new()
	ag.mesh = st.commit()
	ag.material_override = m
	add_child(ag)
	_yollar()
	_agaclar()
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
	var zm := ShaderMaterial.new()
	zm.shader = preload("res://shaderlar/zemin.gdshader")
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
		st.set_color(Color(0.40, 0.39, 0.37) if yaya else Color(0.16, 0.17, 0.18))
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
			yol_parcalari.append([a, b, w, yaya])
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


func _kutu_kaydet(p: Array) -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q in p:
		mn = mn.min(Vector2(q[0], q[1]))
		mx = mx.max(Vector2(q[0], q[1]))
	var kutu := Rect2(mn, mx - mn).grow(2.0)
	for gx in range(int(floor(kutu.position.x / 20.0)), int(floor(kutu.end.x / 20.0)) + 1):
		for gz in range(int(floor(kutu.position.y / 20.0)), int(floor(kutu.end.y / 20.0)) + 1):
			var k := Vector2i(gx, gz)
			if not bina_kutulari.has(k):
				bina_kutulari[k] = []
			bina_kutulari[k].append(kutu)


func _bina_icinde(x: float, z: float) -> bool:
	var k := Vector2i(int(floor(x / 20.0)), int(floor(z / 20.0)))
	for kutu in bina_kutulari.get(k, []):
		if kutu.has_point(Vector2(x, z)):
			return true
	return false


func _agaclar() -> void:
	# Sokak ağaçları ve lambalar: araç yollarının iki yanına aralıklı dizilir; bina kutusuna düşen atlanır.
	# Tek çizim çağrısı için MultiMesh. Konum deterministik (tohum sabit) olsun ki galeri kareleri karşılaştırılabilsin.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var agac: Array = []
	var lamba: Array = []
	for y in yol_parcalari:
		var a: Vector3 = y[0]
		var b: Vector3 = y[1]
		var w: float = y[2]
		var uz := a.distance_to(b)
		var yon := (b - a) / uz
		var yan := yon.cross(Vector3.UP)
		var t := rng.randf_range(0.0, 8.0)
		while t < uz:
			for taraf in [-1.0, 1.0]:
				var q: Vector3 = a + yon * t + yan * float(taraf) * (w + 2.2)
				if not _bina_icinde(q.x, q.z) and Vector2(q.x - dogus.x, q.z - dogus.z).length() > 6.0:
					if y[3]:
						if rng.randf() < 0.15:
							agac.append(q)
					else:
						agac.append(q)
			if not y[3] and int(t / 14.0) % 2 == 0:
				var l := a + yon * t + yan * (w + 0.8)
				if not _bina_icinde(l.x, l.z):
					lamba.append([l, yon])
			t += rng.randf_range(12.0, 20.0)
		if galeri.size() < 4 and not y[3] and uz > 30.0 and absf(a.x) < 600.0 and absf(a.z) < 500.0 and galeri.size() * 37 < yol_parcalari.find(y) % 160:
			galeri.append([a + Vector3(0, 1.6, 0), atan2(-yon.x, -yon.z)])
	_coklu(agac, _agac_govde(), Color(0.36, 0.27, 0.2), rng, true)
	_coklu(agac, _agac_tac(), Color(0.22, 0.36, 0.17), rng, false)
	var lm: Array = []
	for l in lamba:
		lm.append(l[0])
	_coklu(lm, _lamba(), Color(0.25, 0.26, 0.28), rng, true)


func _agac_govde() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.12
	m.bottom_radius = 0.18
	m.height = 3.0
	m.radial_segments = 6
	return m


func _agac_tac() -> Mesh:
	var m := SphereMesh.new()
	m.radius = 2.2
	m.height = 3.6
	m.radial_segments = 8
	m.rings = 5
	return m


func _lamba() -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.06
	m.bottom_radius = 0.09
	m.height = 6.0
	m.radial_segments = 6
	return m


func _coklu(noktalar: Array, mesh: Mesh, renk: Color, rng: RandomNumberGenerator, govde: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = noktalar.size()
	var yerel := RandomNumberGenerator.new()
	yerel.seed = 7
	for i in noktalar.size():
		var q: Vector3 = noktalar[i]
		var olcek := yerel.randf_range(0.75, 1.3)
		var bz := Basis(Vector3.UP, yerel.randf() * TAU).scaled(Vector3(olcek, olcek, olcek))
		var h: float = mesh.height if mesh is CylinderMesh else 0.0
		var oy := h * 0.5 * olcek if govde else (2.6 + 1.6) * olcek
		mm.set_instance_transform(i, Transform3D(bz, q + Vector3(0, oy, 0)))
		mm.set_instance_color(i, renk.lightened(yerel.randf_range(-0.15, 0.15)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mi.material_override = mat
	add_child(mi)
	print("dunya: %d örnek (%s)" % [noktalar.size(), mesh.get_class()])
