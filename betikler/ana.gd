extends Node3D
## Oyun döngüsü: sonsuz seviye + oyuncu + gösterge; düşünce bulunulan bölümün başına dönüş.
## Test: komut satırına "-- --test" eklenince bot ilk rampada kayar, ölçüm yazar, kare kaydeder, çıkar.

const Oyuncu := preload("res://betikler/oyuncu.gd")
const Seviye := preload("res://betikler/seviye.gd")
const Dunya := preload("res://betikler/dunya.gd")

var dunya: Node3D
static var kampus_modu := false   # K tuşuyla değişir, sahne yeniden yüklenince korunur
static var sokak_modu := false    # kampüste zemin seviyesinde yürüme
var bitti := false
# Oynanış kaydı (kampüs modu): rampa başına bir satır → kayit/oynanis.jsonl; CatBoost eğitim verisi.
var kayit_t0 := 0.0
var kayit_giris := 0.0
var kayit_tepe := 0.0
var en_iyi := -1.0

var oyuncu: CharacterBody3D
var seviye: Node3D
var hiz_yazi: Label
var sure_yazi: Label
var bilgi_yazi: Label
var sure := 0.0
var bolum := 0
var en_ileri := 0
var dusme := 0
var en_yuksek := 0.0
var test := false
var test_t := 0.0
var test_sonraki := 0.0


func _ready() -> void:
	test = "--test" in OS.get_cmdline_user_args()
	if "--kampus" in OS.get_cmdline_user_args():
		kampus_modu = true
	if "--sokak" in OS.get_cmdline_user_args():
		sokak_modu = true
		kampus_modu = false
	_tuslar()
	# Dünya önce kurulur: kampüs parkuru yol ağından rota çıkarır.
	dunya = Dunya.new()
	add_child(dunya)
	dunya.kur(sokak_modu or kampus_modu)
	seviye = Seviye.new()
	add_child(seviye)
	if sokak_modu:
		seviye._ortam()
	else:
		if kampus_modu:
			seviye.rota = dunya.rota(Seviye.VADI, Seviye.MED)
		seviye.kur(2026 if kampus_modu else (7 if test else -1), kampus_modu)
		if kampus_modu:
			var pr: Array = []
			for bb in seviye.bolumler:
				pr.append([bb.bas, bb.bas + seviye.ileri(bb.yaw) * bb.get("uz", 0.0)])
			print("rampa şeridinden elenen ağaç/lamba: %d" % dunya.rampadan_ele(pr))
	oyuncu = Oyuncu.new()
	add_child(oyuncu)
	_gosterge()
	if sokak_modu:
		seviye.baslangic = dunya.dogus + Vector3(0, 1.2, 0)
	oyuncu.isinla(seviye.baslangic, seviye.baslangic_yaw)
	if test:
		oyuncu.bot = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _tuslar() -> void:
	var harita := {"ileri": KEY_W, "geri": KEY_S, "sol": KEY_A, "sag": KEY_D, "zipla": KEY_SPACE, "yeniden": KEY_R}
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
	sure_yazi = _yazi(katman, 26)
	sure_yazi.position = Vector2(24, 16)
	bilgi_yazi = _yazi(katman, 18)
	bilgi_yazi.position = Vector2(24, 96)
	bilgi_yazi.text = "W ile in · rampaya doğru A/D basılı tut · fareyle aynı yöne dön\nR bölüm başı · F1/F2 yerçekimi · K mod (sonsuz/kampüs/sokak) · Esc fare"
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


func _bolum_basina() -> void:
	var b: Dictionary = seviye.bolumler[bolum]
	if bolum == 0:
		oyuncu.isinla(seviye.baslangic, seviye.baslangic_yaw)
		return
	# Yolun üstünde, rampa yüzünün ortasına yakın; ileri doğru hızla başlat.
	oyuncu.isinla(b.bas + Vector3(0, -b.yuk * 0.5 + 1.5, 0), b.yaw)
	oyuncu.bekle = not test
	oyuncu.bekle_hiz = seviye.ileri(b.yaw) * 12.0
	if test:
		oyuncu.hiz = oyuncu.bekle_hiz


func _unhandled_input(olay: InputEvent) -> void:
	if test:
		return  # bot testinde gerçek klavye/fare girdisi sonucu bozmasın
	if olay.is_action_pressed("yeniden"):
		_bolum_basina()
	elif olay is InputEventKey and olay.pressed and olay.physical_keycode == KEY_K:
		# Sıra: sonsuz → kampüs → sokak → sonsuz
		if sokak_modu:
			sokak_modu = false
		elif kampus_modu:
			kampus_modu = false
			sokak_modu = true
		else:
			kampus_modu = true
		get_tree().reload_current_scene()
	elif olay is InputEventKey and olay.pressed and olay.physical_keycode == KEY_F1:
		oyuncu.yercekimi *= 0.9
	elif olay is InputEventKey and olay.pressed and olay.physical_keycode == KEY_F2:
		oyuncu.yercekimi *= 1.1
	elif olay is InputEventKey and olay.pressed and olay.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif olay is InputEventMouseButton and olay.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(dt: float) -> void:
	var p := oyuncu.global_position
	if sokak_modu:
		if p.y < -20.0:
			oyuncu.isinla(seviye.baslangic, oyuncu.yaw)
		hiz_yazi.text = "%d" % int(oyuncu.yatay_hiz_birim())
		sure_yazi.text = "sokak · İTÜ Ayazağa · konum (%d, %d) m" % [int(p.x), int(p.z)]
		if test:
			test_t += dt
			oyuncu.bot_girdi = Vector2(0, 1)
			if "--galeri" in OS.get_cmdline_user_args():
				# Sabit noktalardan kare: önce/sonra karşılaştırması için. Her nokta 1,5 sn.
				var noktalar: Array = [[seviye.baslangic + Vector3(0, 0.4, 0), 0.0]] + dunya.galeri
				var i := int(test_t / 1.5)
				oyuncu.bot_girdi = Vector2.ZERO
				if i >= noktalar.size():
					get_tree().quit(0)
					return
				oyuncu.isinla(noktalar[i][0], noktalar[i][1])
				if fmod(test_t, 1.5) + dt >= 1.5:
					DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_cikti"))
					get_viewport().get_texture().get_image().save_png("res://test_cikti/galeri-%d.png" % i)
				return
			if test_t >= 3.0:
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_cikti"))
				get_viewport().get_texture().get_image().save_png("res://test_cikti/sokak.png")
				var gecti: bool = absf(p.y - seviye.baslangic.y) < 1.5 and oyuncu.yerde
				print("SOKAK %s: doğuş %s, şimdi y=%.2f, yerde=%s, yürüdü %.1f m" % ["GECTI" if gecti else "KALDI", seviye.baslangic, p.y, oyuncu.yerde, Vector2(p.x - seviye.baslangic.x, p.z - seviye.baslangic.z).length()])
				get_tree().quit(0 if gecti else 1)
		return
	var onceki := bolum
	bolum = seviye.guncelle(p, bolum)
	kayit_tepe = maxf(kayit_tepe, oyuncu.yatay_hiz_birim())
	if kampus_modu and bolum != onceki:
		_kayit(onceki, false)
	en_ileri = maxi(en_ileri, bolum)
	if not bitti and (bolum > 0 or p.distance_to(seviye.baslangic) > 7.0):
		sure += dt
	var b: Dictionary = seviye.bolumler[bolum]
	if not kampus_modu:
		dunya.izle(p, b.bas.y, dt)
	elif not bitti and p.distance_to(seviye.bitis_konum) < 40.0:
		bitti = true
		if en_iyi < 0.0 or sure < en_iyi:
			en_iyi = sure
	if p.y < b.bas.y - 70.0 or (kampus_modu and not bitti and p.y < 1.2 and oyuncu.yerde and bolum > 0):
		dusme += 1
		if kampus_modu:
			_kayit(bolum, true)
		_bolum_basina()
	var h: float = oyuncu.yatay_hiz_birim()
	en_yuksek = maxf(en_yuksek, h)
	hiz_yazi.text = "%d" % int(h)
	var mod := "kampüs %d/%d" % [bolum + 1, seviye.bolumler.size()] if kampus_modu else "sonsuz, bölüm %d" % (bolum + 1)
	var ek := ""
	if bitti:
		ek = "   bitti"
	if en_iyi >= 0.0:
		ek += "   en iyi %d:%05.2f" % [int(en_iyi) / 60, fmod(en_iyi, 60.0)]
	sure_yazi.text = "%d:%05.2f   %s (%s)   düşme %d%s\nyerçekimi %d" % [
		int(sure) / 60, fmod(sure, 60.0), mod, b.ad, dusme, ek, int(round(oyuncu.etkin_yercekimi() / 0.01905))]
	if test:
		_test_adimi(dt)


func _test_adimi(dt: float) -> void:
	test_t += dt
	if kampus_modu and "--galeri" in OS.get_cmdline_user_args():
		# Rota üzerinde 6 noktadan kare (her bölümün başında, rampa yüzünde göz hizası).
		var n: int = seviye.bolumler.size()
		var i := int(test_t / 1.2)
		if i >= 6:
			get_tree().quit(0)
			return
		var bb: Dictionary = seviye.bolumler[mini(i * (n - 1) / 5, n - 1)]
		oyuncu.isinla(bb.bas + Vector3(0, -1.5, 0), bb.yaw)
		oyuncu.bot_girdi = Vector2.ZERO
		if fmod(test_t, 1.2) + dt >= 1.2:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_cikti"))
			get_viewport().get_texture().get_image().save_png("res://test_cikti/rota-%d.png" % i)
		return
	if kampus_modu:
		if test_t >= 2.0:
			var kk: Array = []
			for v in seviye.ham_kose:
				kk.append([snappedf(v.x, 0.1), snappedf(v.z, 0.1)])
			var kf := FileAccess.open("res://veri/rota-kose.json", FileAccess.WRITE)
			kf.store_string(JSON.stringify(kk))
			kf.close()
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_cikti"))
			get_viewport().get_texture().get_image().save_png("res://test_cikti/kampus.png")
			var son: Vector3 = seviye.bitis_konum
			var gecti: bool = seviye.bolumler.size() >= 10 and Vector2(son.x - seviye.MED.x, son.z - seviye.MED.z).length() < 80.0 and seviye.baslangic.y < 10.0
			print("KAMPUS %s: %d bölüm, başlangıç y=%.0f, bitiş (%.0f, %.0f, %.0f)" % ["GECTI" if gecti else "KALDI", seviye.bolumler.size(), seviye.baslangic.y, son.x, son.y, son.z])
			get_tree().quit(0 if gecti else 1)
		return
	var bp := oyuncu.global_position
	if bp.z > -7.5 and bp.y > 59.0:
		oyuncu.bot_girdi = Vector2(0, 1)
	elif bp.y < 50.0:
		oyuncu.bot_girdi = Vector2(1, 0)
	else:
		oyuncu.bot_girdi = Vector2.ZERO
	if test_t >= test_sonraki:
		test_sonraki += 1.0
		print("t=%.1f konum=(%.1f, %.1f, %.1f) yatay=%d bölüm=%d" % [test_t, bp.x, bp.y, bp.z, int(oyuncu.yatay_hiz_birim()), bolum])
	if test_t >= 10.0:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://test_cikti"))
		get_viewport().get_texture().get_image().save_png("res://test_cikti/kare.png")
		# Üretici: 40 bölüm üret, her türün çıktığını say.
		while seviye.bolumler.size() < 40:
			seviye._bolum_ekle()
		var turler := {}
		for k in seviye.bolumler:
			turler[k.ad] = true
		var gecti: bool = dusme == 0 and bp.z < -30.0 and en_yuksek > 400.0 and turler.size() == seviye.TURLER.size()
		print("TEST %s: en yüksek %d birim/sn, düşme %d, z=%.1f, 40 bölümde tür %d/%d" % [
			"GECTI" if gecti else "KALDI", int(en_yuksek), dusme, bp.z, turler.size(), seviye.TURLER.size()])
		get_tree().quit(0 if gecti else 1)


func _kayit(i: int, dustu: bool) -> void:
	# Satır: rampanın özellikleri (uzunluk, taraf, sonraki rampaya dönüş açısı) + oyuncunun o rampadaki sonucu.
	var b: Dictionary = seviye.bolumler[i]
	var donus := 0.0
	if i + 1 < seviye.bolumler.size():
		donus = rad_to_deg(wrapf(seviye.bolumler[i + 1].yaw - b.yaw, -PI, PI))
	var satir := {
		"zaman": Time.get_datetime_string_from_system(), "bot": test, "bolum": i,
		"uzunluk": b.get("uz", 0.0), "taraf": b.get("s", 0), "donus_derece": snappedf(donus, 0.1),
		"giris_hiz": int(kayit_giris), "tepe_hiz": int(kayit_tepe), "cikis_hiz": int(oyuncu.yatay_hiz_birim()),
		"sure": snappedf(sure - kayit_t0, 0.01), "dustu": dustu,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://kayit"))
	var yol := "res://kayit/oynanis.jsonl"
	var f := FileAccess.open(yol, FileAccess.READ_WRITE) if FileAccess.file_exists(yol) else FileAccess.open(yol, FileAccess.WRITE)
	f.seek_end()
	f.store_line(JSON.stringify(satir))
	f.close()
	kayit_t0 = sure
	kayit_giris = oyuncu.yatay_hiz_birim()
	kayit_tepe = kayit_giris
