"""Mapillary'den İTÜ Ayazağa kampüsü fotoğraflarını indirir (Gaussian Splatting eğitim verisi).

Kullanım:
  set MAPILLARY_TOKEN=MLY|...   (https://www.mapillary.com/dashboard/developers adresinden, kendi hesabınla)
  python egitim/mapillary_indir.py --sayim            # yalnız say, indirme yok
  python egitim/mapillary_indir.py --cikti C:/sistem/sorf-veri/mapillary

Çıktı: <cikti>/resim/<id>.jpg + <cikti>/meta.jsonl (konum, yön, çekim zamanı, dizi, kamera tipi).
Kaldığı yerden sürer: inmiş dosyayı yeniden indirmez.
Lisans: Mapillary görüntüleri CC BY-SA 4.0. Resimler depoya konmaz (boyut); yalnız bu betik ve sonuç modeli.
"""
import argparse
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

# Kampüs kutusu (veri/itu-binalar.json ile aynı): güney, batı, kuzey, doğu
KUTU = (41.098, 29.012, 41.112, 29.036)
HUCRE = 0.003  # Graph API büyük kutuda sonuç keser; kutu hücrelere bölünür
ALANLAR = "id,thumb_2048_url,computed_geometry,computed_compass_angle,captured_at,sequence,camera_type"


def istek(url: str) -> dict:
    for deneme in range(5):
        try:
            with urllib.request.urlopen(url, timeout=60) as y:
                return json.load(y)
        except Exception as h:  # ağ hatası ya da hız sınırı: bekle, yeniden dene
            time.sleep(2 ** deneme)
            son = h
    raise son


def hucreler():
    g, b, k, d = KUTU
    y = g
    while y < k:
        x = b
        while x < d:
            yield (x, y, min(x + HUCRE, d), min(y + HUCRE, k))
            x += HUCRE
        y += HUCRE


def listele(token: str) -> list:
    goruldu, sonuc = set(), []
    for h in hucreler():
        url = "https://graph.mapillary.com/images?" + urllib.parse.urlencode({
            "access_token": token, "bbox": ",".join("%.6f" % v for v in h),
            "fields": ALANLAR, "limit": 2000})
        while url:
            veri = istek(url)
            for r in veri.get("data", []):
                if r["id"] not in goruldu and r.get("thumb_2048_url"):
                    goruldu.add(r["id"])
                    sonuc.append(r)
            url = veri.get("paging", {}).get("next")
        print("hücre %s: toplam %d" % (h, len(sonuc)), file=sys.stderr)
    return sonuc


def indir(r: dict, klasor: str) -> bool:
    yol = os.path.join(klasor, "%s.jpg" % r["id"])
    if os.path.exists(yol):
        return False
    for deneme in range(4):
        try:
            urllib.request.urlretrieve(r["thumb_2048_url"], yol + ".tmp")
            os.replace(yol + ".tmp", yol)
            return True
        except Exception:
            time.sleep(2 ** deneme)
    return False


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--cikti", default="C:/sistem/sorf-veri/mapillary")
    a.add_argument("--sayim", action="store_true")
    a.add_argument("--is-parcacigi", type=int, default=8)
    o = a.parse_args()
    token = os.environ.get("MAPILLARY_TOKEN")
    if not token:
        sys.exit("MAPILLARY_TOKEN ortam değişkeni yok (betiğin başındaki kullanıma bak).")
    liste = listele(token)
    diziler = {r.get("sequence") for r in liste}
    print("kampüste %d fotoğraf, %d dizi" % (len(liste), len(diziler)))
    if o.sayim:
        return
    klasor = os.path.join(o.cikti, "resim")
    os.makedirs(klasor, exist_ok=True)
    with open(os.path.join(o.cikti, "meta.jsonl"), "w", encoding="utf-8") as f:
        for r in liste:
            f.write(json.dumps({k: v for k, v in r.items() if k != "thumb_2048_url"}, ensure_ascii=False) + "\n")
    with ThreadPoolExecutor(o.is_parcacigi) as h:
        yeni = sum(h.map(lambda r: indir(r, klasor), liste))
    print("indirilen %d, toplam klasörde %d" % (yeni, len(os.listdir(klasor))))


if __name__ == "__main__":
    main()
