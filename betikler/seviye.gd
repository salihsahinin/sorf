extends Node3D
## Parkur geometrisi kodla üretilir; dış varlık dosyası yoktur.
## Yön: ileri = -Z. Rampa = üçgen kesitli prizma (iki eğik yüz), tepe çizgisi ileri doğru alçalır.
## Yeni harita için kur() içindeki listeyi değiştirmek yeter.

const IZGARA := preload("res://shaderlar/izgara.gdshader")

var baslangic := Vector3(0, 62.0, 0)
var baslangic_yaw := 0.0
var olum_y := -60.0
var bitis: Area3D


func kur() -> void:
	_ortam()
	# Başlangıç platformu
	_kutu(Vector3(0, 60, 0), Vector3(12, 1, 12), Color(0.9, 0.9, 0.92))
	# Rampalar: tepe başlangıcı, uzunluk, yarı genişlik, yükseklik, tepe alçalması, renk
	_rampa(Vector3(5, 52, -3), 97.0, 6.0, 8.0, 8.0, Color(0.36, 0.62, 0.95))
	_rampa(Vector3(-4, 36, -125), 90.0, 6.0, 8.0, 8.0, Color(0.95, 0.6, 0.3))
	_rampa(Vector3(5, 20, -240), 100.0, 6.0, 8.0, 10.0, Color(0.4, 0.85, 0.6))
	_rampa(Vector3(-4, 2, -365), 100.0, 6.0, 8.0, 10.0, Color(0.85, 0.45, 0.8))
	# Bitiş platformu
	var b_konum := Vector3(0, -26, -520)
	_kutu(b_konum, Vector3(40, 1, 40), Color(0.95, 0.85, 0.35))
	bitis = Area3D.new()
	var s := CollisionShape3D.new()
	var k := BoxShape3D.new()
	k.size = Vector3(40, 6, 40)
	s.shape = k
	bitis.add_child(s)
	bitis.position = b_konum + Vector3(0, 3.5, 0)
	add_child(bitis)


func _malzeme(renk: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = IZGARA
	m.set_shader_parameter("renk", renk)
	m.set_shader_parameter("cizgi", renk.darkened(0.55))
	return m


func _kutu(konum: Vector3, boyut: Vector3, renk: Color) -> void:
	var govde := StaticBody3D.new()
	govde.position = konum
	var ag := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = boyut
	ag.mesh = bm
	ag.material_override = _malzeme(renk)
	govde.add_child(ag)
	var s := CollisionShape3D.new()
	var k := BoxShape3D.new()
	k.size = boyut
	s.shape = k
	govde.add_child(s)
	add_child(govde)


func _rampa(tepe: Vector3, uzunluk: float, yari: float, yukseklik: float, alcalma: float, renk: Color) -> void:
	# Yerel köşeler: 0-1 tepe çizgisi, 2-3 sol taban, 4-5 sağ taban (ön, arka).
	var p := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, -alcalma, -uzunluk),
		Vector3(-yari, -yukseklik, 0), Vector3(-yari, -yukseklik - alcalma, -uzunluk),
		Vector3(yari, -yukseklik, 0), Vector3(yari, -yukseklik - alcalma, -uzunluk),
	])
	var ucgenler := [
		[0, 2, 3], [0, 3, 1],   # sol yüz
		[0, 1, 5], [0, 5, 4],   # sağ yüz
		[0, 4, 2],              # ön kapak
		[1, 3, 5],              # arka kapak
		[2, 4, 5], [2, 5, 3],   # taban
	]
	var merkez := Vector3.ZERO
	for v in p:
		merkez += v
	merkez /= p.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for u in ucgenler:
		var a: Vector3 = p[u[0]]
		var b: Vector3 = p[u[1]]
		var c: Vector3 = p[u[2]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot(a - merkez) < 0.0:
			var gecici := b
			b = c
			c = gecici
			n = -n
		# Godot ön yüzü saat yönünde sarar: dışa bakan normal için köşe sırası a, c, b.
		for v in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	var govde := StaticBody3D.new()
	govde.position = tepe
	var ag := MeshInstance3D.new()
	ag.mesh = st.commit()
	ag.material_override = _malzeme(renk)
	govde.add_child(ag)
	var s := CollisionShape3D.new()
	var k := ConvexPolygonShape3D.new()
	k.points = p
	s.shape = k
	govde.add_child(s)
	add_child(govde)


func _ortam() -> void:
	var cevre := WorldEnvironment.new()
	var e := Environment.new()
	var gok := Sky.new()
	var gm := ProceduralSkyMaterial.new()
	gm.sky_top_color = Color(0.18, 0.32, 0.6)
	gm.sky_horizon_color = Color(0.7, 0.8, 0.92)
	gm.ground_bottom_color = Color(0.1, 0.12, 0.18)
	gm.ground_horizon_color = Color(0.7, 0.8, 0.92)
	gok.sky_material = gm
	e.background_mode = Environment.BG_SKY
	e.sky = gok
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cevre.environment = e
	add_child(cevre)
	var gunes := DirectionalLight3D.new()
	gunes.rotation_degrees = Vector3(-50, 35, 0)
	gunes.shadow_enabled = true
	gunes.directional_shadow_max_distance = 250.0
	add_child(gunes)
