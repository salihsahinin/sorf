# sorf: insan ve ajan çalışma kuralları

Bu dosya depoda çalışan herkes (Salih, Yağız) ve onların yapay zekâ ajanları içindir.

## Akış
- `main` korumalı: doğrudan gönderim yok. Her iş kendi dalında, PR ile girer; PR'ı açan dışındaki kişi onaylar.
- PR açmadan önce `test.bat` geçer (çıkış kodu 0). Mod değiştiren iş `-- --test --kampus` ve `-- --test --sokak` testlerini de koşar.
- Commit mesajı İngilizce, kısa, etken. Kod tanımlayıcıları ve yorumlar Türkçe (mevcut dosyalardaki gibi).
- İş takibi Issues'ta; her PR ilgili issue'ya bağlanır (`#N`).

## Ajanın kendi karar verdiği işler
- Kendi dalında kod, test, belge değişikliği; parametre ayarı; hata düzeltmesi.
- Test geçmiyorsa PR açmaz; hatayı ve çıktıyı PR ya da issue'ya yazar.

## Ajanın sorduğu işler
- `main`'e birleştirme, dal silme, depo ayarı, davet, sürüm yayımlama.
- Yeni dış veri kaynağı ya da yeni bağımlılık.
- Oynanışı belirgin değiştiren karar (hareket sabitleri, mod ekleme/çıkarma).

## Veri ve lisans
- Google Earth / Google Maps görüntüsü indirilmez, modele girmez (Google koşulları).
- OpenStreetMap verisi `veri/` altında, atıf README'de (ODbL).
- Mapillary görüntüleri CC BY-SA 4.0; depoya resim konmaz, depo dışı klasörde durur.
- Anahtar ve token depoya, issue'ya, PR'a yazılmaz; ortam değişkeninde tutulur.

## Yapı
- `betikler/oyuncu.gd` hareket (Source modeli) · `seviye.gd` harita üretici · `dunya.gd` kampüs · `ana.gd` oyun döngüsü ve testler.
- `egitim/` model eğitimi için veri ve araçlar.
