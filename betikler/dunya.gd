extends Node3D
## Arka plan dünyası: İTÜ Ayazağa kampüsü, OpenStreetMap bina izleri (© OpenStreetMap katkıcıları, ODbL).
## veri/itu-binalar.json: her bina {h: yükseklik m, p: [[x, z], ...] metre, ad}. Çarpışma yok, yalnız görüntü.
## Parkur sonsuz alçaldığı için kampüs oyuncunun altında kalacak şekilde izler: yatayda uzaklaşınca
## yeniden ortalanır, düşeyde bulunulan bölümün DERIN metre altına yumuşakça iner.

const DERIN := 220.0

var hedef_y := 0.0


func kur() -> void:
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
