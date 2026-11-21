extends Node3D
## Sonsuz harita: oyuncu ilerledikçe önüne yeni bölüm üretilir, arkada kalan silinir.
## Imleç (konum + yön) yolun üzerinde ilerler; her bölüm türü imleci kendi kuralıyla taşır.
## Rampa = üçgen kesitli prizma; oyuncu rampanın yola bakan yüzünde kayar.
## Yeni bölüm türü eklemek: _bolum_ekle() içindeki eşleşmeye bir dal + TURLER listesine ad.

const IZGARA := preload("res://shaderlar/izgara.gdshader")
const G := 800.0 * 0.01905
const TURLER := ["duz", "zikzak", "viraj", "dusus", "dalga", "dar", "genis"]

var baslangic := Vector3(0, 62.0, 0)
var baslangic_yaw := 0.0
var rng := RandomNumberGenerator.new()
var bolumler: Array = []   # {dugum, bas, yaw, yuk, ad}
var imlec := Vector3(0, 54, -3)
var imlec_yaw := 0.0
var sayac := 0
var kampus := false          # sabit parkur: kampüsün batısından doğusuna, kendi kendine biter
var bitis_konum := Vector3.ZERO
# Kampüs rotası (veri/itu-binalar.json koordinatı, metre): Vadi Yurtları Yemekhanesi → Merkezi Derslik A (MED)
const VADI := Vector3(980, 0, -385)
const MED := Vector3(-54, 0, -56)
const MED_YUKSEKLIK := 20.0
const TEPE := 5.0   # kampüs rampalarının tepe yüksekliği (m): oyuncu zeminden 0-5 m arasında kayar
var rota := PackedVector3Array()


func kur(tohum: int = -1, kampus_modu := false) -> void:
	kampus = kampus_modu
	if tohum >= 0:
		rng.seed = tohum
	else:
		rng.randomize()
	_ortam()
	if not kampus:
		_kutu(self, Vector3(0, 60, 0), Vector3(12, 1, 12), Color(0.9, 0.9, 0.92))
		for i in 6:
			_bolum_ekle()
		return
	# Kampüs (alçak sörf): rampalar yol rotası boyunca, tepe yerden TEPE m. Rampa alçalmaz; hız hava ivmesiyle
	# (rampaya doğru tuş + fareyle aynı yöne dönüş) kazanılır. Rota köşeleri 25 m'den kısa parçalar birleşerek sadeleşir.
	var kose := PackedVector3Array([rota[0]])
	for i in range(1, rota.size()):
		if rota[i].distance_to(kose[kose.size() - 1]) >= 25.0 or i == rota.size() - 1:
			kose.append(rota[i])
	var renk_i := 0
	var s := 1
	for i in range(kose.size() - 1):
		var a := kose[i]
		var b := kose[i + 1]
		var yaw := atan2(-(b - a).x, -(b - a).z)
		# Virajda rampa dış tarafta dursun: dönüş yönünün tersi.
		if i + 2 < kose.size():
			var sonraki := atan2(-(kose[i + 2] - b).x, -(kose[i + 2] - b).z)
			s = -1 if wrapf(sonraki - yaw, -PI, PI) > 0.0 else 1
		var uz := a.distance_to(b) - 6.0
		if uz < 8.0:
			continue
		var kap := Node3D.new()
		add_child(kap)
		imlec = Vector3(a.x, TEPE, a.z) + ileri(yaw) * 3.0
		imlec_yaw = yaw
		bolumler.append({"dugum": kap, "bas": imlec, "yaw": yaw, "yuk": 5.0, "ad": "sokak", "uz": uz, "s": s})
		_parca(kap, s, uz, 4.5, TEPE, 0.0, Color.from_hsv(fmod(renk_i * 0.137, 1.0), 0.55, 0.92))
		renk_i += 1
	var ilk: Dictionary = bolumler[0]
	baslangic_yaw = ilk.yaw
	var p0: Vector3 = ilk.bas - ileri(ilk.yaw) * 10.0
	_kutu(self, Vector3(p0.x, TEPE + 1.5, p0.z), Vector3(8, 1, 8), Color(0.9, 0.9, 0.92))
	baslangic = Vector3(p0.x, TEPE + 3.5, p0.z)
	var son_n := kose[kose.size() - 1]
	bitis_konum = Vector3(son_n.x, 0.5, son_n.z)
	_kutu(self, bitis_konum, Vector3(20, 1, 20), Color(0.95, 0.85, 0.35))


func ileri(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func sag(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


## Oyuncunun bulunduğu bölümün sırası; çağıran ana.gd, önünde 6 bölüm kalacak şekilde üretimi sürdürür.
func guncelle(p: Vector3, simdiki: int) -> int:
	var yeni := simdiki
	for i in range(simdiki + 1, mini(simdiki + 4, bolumler.size())):
		var b: Dictionary = bolumler[i]
		if (p - b.bas).dot(ileri(b.yaw)) > 0.0 and p.distance_to(b.bas) < 300.0:
			yeni = i
	if kampus:
		return yeni
	while bolumler.size() - yeni < 6:
		_bolum_ekle()
	# Geride kalan bölümleri sil (dizideki yeri korunur, düğüm serbest bırakılır).
	for i in range(0, yeni - 3):
		var b: Dictionary = bolumler[i]
		if b.dugum != null:
			b.dugum.queue_free()
			b.dugum = null
	return yeni


func _gap(uzunluk: float) -> void:
	# Boşluk + düşüş: oyuncu ~18 m/s ile uçarken düşeceği kadar alçalt.
	imlec += ileri(imlec_yaw) * uzunluk
	imlec.y -= 3.0 + 0.5 * G * pow(uzunluk / 18.0, 2)


func _parca(kap: Node3D, s: int, uz: float, yari: float, yuk: float, alc: float, renk: Color, ilerle := true) -> void:
	var tepe := imlec + sag(imlec_yaw) * s * yari * 0.5
	_rampa(kap, tepe, imlec_yaw, uz, yari, yuk, alc, renk)
	if ilerle:
		imlec += ileri(imlec_yaw) * uz
		imlec.y -= alc


func _bolum_ekle() -> void:
	var ad: String = "duz" if sayac == 0 else TURLER[rng.randi() % TURLER.size()]
	var kap := Node3D.new()
	add_child(kap)
	var renk := Color.from_hsv(fmod(sayac * 0.137, 1.0), 0.55, 0.92)
	var s := 1 if (sayac == 0 or rng.randf() < 0.5) else -1
	var kayit := {"dugum": kap, "bas": imlec, "yaw": imlec_yaw, "yuk": 12.0, "ad": ad}
	match ad:
		"duz":
			var uz := 150.0 if sayac == 0 else rng.randf_range(90, 150)
			_parca(kap, s, uz, 10, 12, uz * rng.randf_range(0.08, 0.13), renk)
			_gap(rng.randf_range(10, 18))
		"zikzak":
			for i in rng.randi_range(3, 5):
				_parca(kap, s, rng.randf_range(40, 60), 10, 12, 5.0, renk)
				s = -s
				_gap(rng.randf_range(6, 10))
		"viraj":
			if kampus:
				# Virajlar parkuru doğu yönüne geri çevirir; kampüsün dışına taşmasın.
				var fark := wrapf(_hedef_yaw(imlec) - imlec_yaw, -PI, PI)
				if absf(fark) > 0.05:
					s = -1 if fark > 0.0 else 1
			var adim := -s * deg_to_rad(rng.randf_range(9, 14))
			for i in rng.randi_range(7, 11):
				_parca(kap, s, 22, 10, 12, 2.5, renk)
				imlec -= ileri(imlec_yaw) * 1.5   # parçalar üst üste binsin, ek yeri olmasın
				imlec_yaw += adim
			_gap(10)
		"dusus":
			_gap(rng.randf_range(22, 32))
			kayit.bas = imlec
			kayit.yuk = 16.0
			_parca(kap, s, 130, 14, 16, 14, renk)
			_gap(12)
		"dalga":
			for i in 4:
				_parca(kap, s, 50, 10, 12, 1.0 if i % 2 == 0 else 9.0, renk)
				imlec -= ileri(imlec_yaw) * 1.0
			_gap(12)
		"dar":
			kayit.yuk = 12.0
			_parca(kap, s, 80, 5, 12, 9, renk)
			_gap(12)
		"genis":
			kayit.yuk = 18.0
			_parca(kap, s, 170, 18, 18, 22, renk)
			_gap(16)
	bolumler.append(kayit)
	sayac += 1


func _malzeme(renk: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = IZGARA
	m.set_shader_parameter("renk", renk)
	m.set_shader_parameter("cizgi", renk.darkened(0.55))
	return m


func _kutu(kap: Node, konum: Vector3, boyut: Vector3, renk: Color) -> void:
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
	kap.add_child(govde)


func _rampa(kap: Node, tepe: Vector3, yaw: float, uzunluk: float, yari: float, yukseklik: float, alcalma: float, renk: Color) -> void:
	# Yerel köşeler: 0-1 tepe çizgisi, 2-3 sol taban, 4-5 sağ taban (ön, arka). Yerel ileri = -Z.
	var p := PackedVector3Array([
		Vector3(0, 0, 0), Vector3(0, -alcalma, -uzunluk),
		Vector3(-yari, -yukseklik, 0), Vector3(-yari, -yukseklik - alcalma, -uzunluk),
		Vector3(yari, -yukseklik, 0), Vector3(yari, -yukseklik - alcalma, -uzunluk),
	])
	var ucgenler := [[0, 2, 3], [0, 3, 1], [0, 1, 5], [0, 5, 4], [0, 4, 2], [1, 3, 5], [2, 4, 5], [2, 5, 3]]
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
		for v in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	var govde := StaticBody3D.new()
	govde.position = tepe
	govde.rotation.y = yaw
	govde.add_to_group("rampa")
	var ag := MeshInstance3D.new()
	ag.mesh = st.commit()
	ag.material_override = _malzeme(renk)
	govde.add_child(ag)
	var s := CollisionShape3D.new()
	var k := ConvexPolygonShape3D.new()
	k.points = p
	s.shape = k
	govde.add_child(s)
	kap.add_child(govde)


func _ortam() -> void:
	var cevre := WorldEnvironment.new()
	var e := Environment.new()
	var gok := Sky.new()
	var gm := PhysicalSkyMaterial.new()   # Rayleigh/Mie saçılımı: güneşe göre değişen gerçek gök rengi
	gm.turbidity = 6.0
	gm.ground_color = Color(0.3, 0.32, 0.3)
	gok.sky_material = gm
	e.background_mode = Environment.BG_SKY
	e.sky = gok
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.95
	e.ssao_enabled = true            # köşe ve bina diplerinde ortam gölgesi
	e.ssao_radius = 2.0
	e.ssao_intensity = 2.5
	e.glow_enabled = true
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.1
	e.fog_enabled = true
	e.fog_density = 0.00015 if kampus else 0.0008  # kampüste uzak binalar görünsün
	cevre.environment = e
	add_child(cevre)
	var gunes := DirectionalLight3D.new()
	gunes.rotation_degrees = Vector3(-38, 35, 0)
	gunes.light_energy = 1.4
	gunes.shadow_enabled = true
	gunes.directional_shadow_max_distance = 400.0
	add_child(gunes)


func _hedef_yaw(nereden: Vector3) -> float:
	# ileri(yaw) = (-sin yaw, 0, -cos yaw) olduğundan MED yönünü veren yaw.
	var d := MED - nereden
	return atan2(-d.x, -d.z)
