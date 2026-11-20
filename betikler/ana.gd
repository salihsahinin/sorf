extends Node3D
## Oyun döngüsü: seviye + oyuncu + gösterge; süre, düşünce yeniden başlatma, bitiş.
## Test: komut satırına "-- --test" eklenince bot rampada kayar, ölçüm yazar, kare kaydeder, çıkar.

const Oyuncu := preload("res://betikler/oyuncu.gd")
const Seviye := preload("res://betikler/seviye.gd")

var oyuncu: CharacterBody3D
var seviye: Node3D
var hiz_yazi: Label
var sure_yazi: Label
var bilgi_yazi: Label
var sure := 0.0
var kosuyor := false
var bitti := false
var en_iyi := -1.0
var en_yuksek := 0.0
var test := false
var test_t := 0.0
var test_sonraki := 0.0


func _ready() -> void:
	test = "--test" in OS.get_cmdline_user_args()
	_tuslar()
	seviye = Seviye.new()
	add_child(seviye)
	seviye.kur()
	oyuncu = Oyuncu.new()
	add_child(oyuncu)
	seviye.bitis.body_entered.connect(_bitise_girdi)
	_gosterge()
	_basla()
	if test:
		oyuncu.bot = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _tuslar() -> void:
	var harita := {
		"ileri": KEY_W, "geri": KEY_S, "sol": KEY_A, "sag": KEY_D,
		"zipla": KEY_SPACE, "yeniden": KEY_R,
	}
	for ad in harita:
		if not InputMap.has_action(ad):
			InputMap.add_action(ad)
		var olay := InputEventKey.new()
		olay.physical_keycode = harita[ad]
		InputMap.action_add_event(ad, olay)


func _gosterge() -> void:
	var katman := CanvasLayer.new()
	add_child(katman)
	hiz_yazi = _yazi(katman, 44)
	hiz_yazi.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hiz_yazi.position += Vector2(-200, -120)
	hiz_yazi.custom_minimum_size = Vector2(400, 0)
	hiz_yazi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sure_yazi = _yazi(katman, 30)
	sure_yazi.position = Vector2(24, 16)
	bilgi_yazi = _yazi(katman, 20)
	bilgi_yazi.position = Vector2(24, 64)
	bilgi_yazi.text = "W ile platformdan in · rampaya doğru A ya da D basılı tut · fareyle yön ver\nR yeniden başla · Esc fare"
	var nisan := ColorRect.new()
	nisan.color = Color(1, 1, 1, 0.8)
	nisan.size = Vector2(4, 4)
	nisan.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	katman.add_child(nisan)


func _yazi(ust: Node, boy: int) -> Label:
	var y := Label.new()
	y.add_theme_font_size_override("font_size", boy)
	y.add_theme_color_override("font_outline_color", Color.BLACK)
	y.add_theme_constant_override("outline_size", 6)
	ust.add_child(y)
	return y


func _basla() -> void:
	oyuncu.isinla(seviye.baslangic, seviye.baslangic_yaw)
	sure = 0.0
	kosuyor = false
	bitti = false
	en_yuksek = 0.0


func _bitise_girdi(govde: Node) -> void:
	if govde != oyuncu or bitti or not kosuyor:
		return
	bitti = true
	kosuyor = false
	if en_iyi < 0.0 or sure < en_iyi:
		en_iyi = sure


func _unhandled_input(olay: InputEvent) -> void:
	if test:
		return  # bot testinde gerçek klavye/fare girdisi sonucu bozmasın
	if olay.is_action_pressed("yeniden"):
		_basla()
	elif olay is InputEventKey and olay.pressed and olay.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif olay is InputEventMouseButton and olay.pressed and not test:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(dt: float) -> void:
	var p := oyuncu.global_position
	# Süre, oyuncu başlangıç platformunun ön kenarını geçince başlar.
	if not kosuyor and not bitti and p.z < seviye.baslangic.z - 6.0:
		kosuyor = true
	if kosuyor:
		sure += dt
	if p.y < seviye.olum_y:
		_basla()
	var h: float = oyuncu.yatay_hiz_birim()
	en_yuksek = maxf(en_yuksek, h)
	hiz_yazi.text = "%d" % int(h)
	var satir := "%.2f sn" % sure
	if bitti:
		satir += "  bitti"
	if en_iyi >= 0.0:
		satir += "   en iyi %.2f sn" % en_iyi
	sure_yazi.text = satir
	if test:
		_test_adimi(dt)


func _test_adimi(dt: float) -> void:
	test_t += dt
	# Bot: platformdan ileri yürüyüp düşer, rampa yüzüne yaklaşınca yalnız sağ tuşu (rampaya doğru) basılı tutar.
	var bp := oyuncu.global_position
	if bp.z > -7.5 and bp.y > 60.0:
		oyuncu.bot_girdi = Vector2(0, 1)
	elif bp.y < 48.0:
		oyuncu.bot_girdi = Vector2(1, 0)
	else:
		oyuncu.bot_girdi = Vector2.ZERO
	if test_t >= test_sonraki:
		test_sonraki += 0.5
		var p := oyuncu.global_position
		print("t=%.1f konum=(%.1f, %.1f, %.1f) yatay=%d birim/sn yerde=%s" % [test_t, p.x, p.y, p.z, int(oyuncu.yatay_hiz_birim()), oyuncu.yerde])
	if test_t >= 10.0:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_cikti"))
		get_viewport().get_texture().get_image().save_png("res://test_cikti/kare.png")
		var p := oyuncu.global_position
		var gecti: bool = p.y > seviye.olum_y + 5.0 and p.z < -30.0 and en_yuksek > 400.0
		print("TEST %s: en yüksek yatay hız %d birim/sn, son konum z=%.1f y=%.1f" % ["GECTI" if gecti else "KALDI", int(en_yuksek), p.z, p.y])
		get_tree().quit(0 if gecti else 1)
