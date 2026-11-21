# Sörf

Counter-Strike sörf haritalarının hareket modelini Godot 4.7 ile yeniden kuran birinci şahıs oyun. Tüm geometri kodla üretilir; dış varlık dosyası yoktur.

## Çalıştırma

1. Godot 4.7.2 indir: https://github.com/godotengine/godot/releases/tag/4.7.2-stable (`Godot_v4.7.2-stable_win64.exe.zip`), `C:\tools\godot` içine aç.
2. `oyna.bat` çift tıkla. İlk açılışta önbellek üretilir (birkaç saniye).
3. Farklı yerdeyse: `Godot_v4.7.2-stable_win64.exe --path <bu klasör>`.

## Modlar

- **Sonsuz** (`oyna.bat`): harita ilerledikçe üretilir, bitmez.
- **Sokak** (`sokak.bat` ya da K ile): İTÜ Ayazağa zemin seviyesinde yürüme; binalar çarpışır, yollar ve yaya yolları OpenStreetMap verisinden (`veri/itu-yollar.json`, 1005 yol).
- **Kampüs** (`kampus.bat` ya da oyunda K): Vadi Yurtları üstünden Merkezi Derslik A (MED) çatısına sabit parkur, yaklaşık 1,1 km, 7 bölüm; bitiş platformunda süre ve en iyi süre.

## Nasıl sörf yapılır

| Tuş | İş |
|---|---|
| W | platformdan in |
| A / D | rampaya doğru olan tuşu basılı tut (sağdaki rampada D) |
| Fare | bakış yönü; hızlanmak için tuşla aynı yöne çevir |
| Boşluk | zıpla (yalnız düz yerde) |
| R | bölüm başına dön · K mod değiştir (sonsuz / kampüs) · F1/F2 yerçekimi · Esc fare |

Rampaya ilk temasta W'yi bırak. Yalnız yan tuşla kalırsan düşmezsin; fareyi aynı yöne yavaşça çevirince hız artar. Ekranın altındaki sayı yatay hızdır (Source birimi/sn).

## Mekanizma

`betikler/oyuncu.gd` Source motorunun `gamemovement.cpp` mantığını izler:

- **Yer mi hava mı:** yüzey normalinin düşey bileşeni 0,7'den küçükse yüzey yer sayılmaz. Sörf rampası diktir; oyuncu rampada havada kalır, sürtünme uygulanmaz.
- **Hava ivmesi (`AirAccelerate`):** istenen yöndeki hız bileşeni 30 birimin altındaysa hız eklenir. Hıza dik yönde basılan tuş bu sınıra hiç ulaşmaz; toplam hız her tikte büyür.
- **Hız kırpma (`ClipVelocity`):** rampaya çarpınca hızın yüzeye dik bileşeni silinir. Yerçekiminin rampa yönündeki payı ileri hıza dönüşür.
- Yerçekimi hızla logaritmik artar: g = 800 × (1 + 0,5 × ln(1 + v/1000)); 1000 birim/sn'de 1,35 kat, 3000'de 1,69 kat. F1/F2 tabanı %10 değiştirir.
- Sabitler: `sv_gravity` 800, `sv_airaccelerate` 150, `sv_accelerate` 5, `sv_friction` 4, `sv_maxvelocity` 3500. 1 Source birimi = 0,01905 m.

## Dosyalar

- `betikler/oyuncu.gd` hareket modeli.
- `betikler/seviye.gd` sonsuz harita üreticisi; bölüm türleri `TURLER` listesinde (duz, zikzak, viraj, dusus, dalga, dar, genis). Yeni tür = listeye ad + `_bolum_ekle()` içine dal. Rampa hiçbir eğimde yer sayılmaz (sörfte zıplama yok).
- `betikler/dunya.gd` arka plan: İTÜ Ayazağa binaları, `veri/itu-binalar.json`.
- `betikler/ana.gd` süre, en iyi süre, düşünce yeniden başlatma, bot testi.
- `shaderlar/izgara.gdshader` hız algısı için dünya uzayı ızgarası.

## Test

`test.bat` botu koşturur: bot platformdan iner, yalnız sağ tuşla rampada kayar. Geçme koşulu: düşmeden ilerlemek ve yatay hızın 400 birim/sn'yi geçmesi. Son kare `test_cikti/kare.png`. Çıkış kodu 0 = geçti.

## Birlikte geliştirme

- `main` dalına doğrudan yazılmaz; her iş kendi dalında, PR ile birleşir.
- PR açmadan önce `test.bat` geçmeli.
- Fikirler ve hatalar Issues'ta.

## Veri

Bina izleri ve yükseklikleri: © OpenStreetMap katkıcıları, ODbL (https://www.openstreetmap.org/copyright). Kutu: 41.098-41.114 K, 29.012-29.046 D; 1395 bina, 1390 yol, 2026-11-21 Overpass çekimi.

## Lisans

MIT, `LICENSE`.
