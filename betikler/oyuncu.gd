extends CharacterBody3D
## Source motoru hareket modeli (yer ivmesi, sürtünme, hava ivmesi, yüzeyde hız kırpma).
## Sörf bu modelin yan ürünüdür: dik rampa "yer" sayılmaz, oyuncu havada kalır,
## hızı rampa düzlemine kırpılır ve rampaya doğru yan tuş basılı tutulunca düşmeden kayar.
## Uzunluklar metre; sabitler Source biriminden çevrilir (1 birim = 0,01905 m).

const B := 0.01905

@export var yercekimi := 800.0 * B        # sv_gravity 800
@export var yer_hizi := 250.0 * B         # yerde istenen azami hız
@export var yer_ivme := 5.0               # sv_accelerate
@export var hava_ivme := 150.0            # sv_airaccelerate (sörf sunucusu değeri)
@export var hava_tavan := 30.0 * B        # havada tek tikte istenen hız tavanı
@export var surtunme := 4.0               # sv_friction
@export var dur_hizi := 100.0 * B         # sv_stopspeed
@export var ziplama := 268.33 * B         # 45 birim yükseklik veren ilk hız
@export var azami_hiz := 3500.0 * B       # sv_maxvelocity
@export var yer_egimi := 0.7              # normal.y bu değerin altındaysa yüzey yer değildir
@export var fare := 0.0022

var hiz := Vector3.ZERO
var yerde := false
var yaw := 0.0
var pitch := 0.0
var bot := false
var bot_girdi := Vector2.ZERO  # x: sağ(+)/sol(-), y: ileri(+)/geri(-)
var kamera: Camera3D


func _ready() -> void:
	var sekil := CollisionShape3D.new()
	var kutu := BoxShape3D.new()
	kutu.size = Vector3(0.61, 1.37, 0.61)  # Source oyuncu kutusu 32 x 72 birim
	sekil.shape = kutu
	add_child(sekil)
	kamera = Camera3D.new()
	kamera.top_level = true
	kamera.fov = 74.0
	kamera.far = 3000.0
	add_child(kamera)
	kamera.current = true


func _unhandled_input(olay: InputEvent) -> void:
	if olay is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= olay.relative.x * fare
		pitch = clampf(pitch - olay.relative.y * fare, -1.55, 1.55)


func _process(_dt: float) -> void:
	kamera.global_position = get_global_transform_interpolated().origin + Vector3(0, 0.53, 0)
	kamera.rotation = Vector3(pitch, yaw, 0)


func isinla(konum: Vector3, yeni_yaw: float) -> void:
	global_position = konum
	hiz = Vector3.ZERO
	yaw = yeni_yaw
	pitch = 0.0
	yerde = false
	reset_physics_interpolation()


func yatay_hiz_birim() -> float:
	return Vector2(hiz.x, hiz.z).length() / B


func _girdi() -> Vector2:
	if bot:
		return bot_girdi
	return Vector2(
		Input.get_axis("sol", "sag"),
		Input.get_axis("geri", "ileri"))


func _physics_process(dt: float) -> void:
	var g := _girdi()
	var taban := Basis(Vector3.UP, yaw)
	var istek := (taban * Vector3(g.x, 0, -g.y))
	istek.y = 0
	if istek.length() > 1.0:
		istek = istek.normalized()
	var istek_hiz := istek.length() * yer_hizi
	var yon := istek.normalized() if istek_hiz > 0.0 else Vector3.ZERO

	_yer_kontrol()
	var zipla := Input.is_action_pressed("zipla") and not bot
	if yerde and zipla:
		hiz.y = ziplama
		yerde = false

	if yerde:
		_surtun(dt)
		_ivmelen(yon, istek_hiz, yer_ivme, istek_hiz, dt)
	else:
		_ivmelen(yon, istek_hiz, hava_ivme, minf(istek_hiz, hava_tavan), dt)
		hiz.y -= yercekimi * dt

	if hiz.length() > azami_hiz:
		hiz = hiz.normalized() * azami_hiz
	_tasi(dt)


func _yer_kontrol() -> void:
	# Yukarı doğru hızlı giderken yere yapışma yok (Source: 140 birim/sn eşiği).
	if hiz.y > 140.0 * B:
		yerde = false
		return
	var c := move_and_collide(Vector3(0, -0.04, 0), true)
	if c != null and c.get_normal().y >= yer_egimi:
		if not yerde:
			hiz.y = 0.0
		yerde = true
		hiz = hiz.slide(c.get_normal())
	else:
		yerde = false


func _surtun(dt: float) -> void:
	var s := hiz.length()
	if s < 0.001:
		return
	var kontrol := maxf(s, dur_hizi)
	var yeni := maxf(s - kontrol * surtunme * dt, 0.0)
	hiz *= yeni / s


func _ivmelen(yon: Vector3, istek_hiz: float, ivme: float, tavan: float, dt: float) -> void:
	# Source Accelerate / AirAccelerate: hız yalnız istenen yöndeki bileşen tavanın altındaysa eklenir.
	# Havada tavan küçüktür (30 birim); bu yüzden hıza dik yönde basılan tuş toplam hızı artırır.
	if istek_hiz <= 0.0:
		return
	var mevcut := hiz.dot(yon)
	var ek := tavan - mevcut
	if ek <= 0.0:
		return
	var adim := minf(ivme * istek_hiz * dt, ek)
	hiz += yon * adim


func _tasi(dt: float) -> void:
	# Source TryPlayerMove: çarpınca hız yüzey düzlemine kırpılır, kalan yol aynı tikte sürer.
	var kalan := hiz * dt
	for i in 4:
		var c := move_and_collide(kalan)
		if c == null:
			break
		var n := c.get_normal()
		hiz = hiz.slide(n)
		kalan = c.get_remainder().slide(n)
		if kalan.length() < 0.0001:
			break
