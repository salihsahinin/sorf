"""Rota koridorunu k-means ile eğitim bloklarına böler (her blok ayrı sahne modeli olarak eğitilir).

Girdi (öncelik sırasıyla):
  --meta <meta.jsonl>   Mapillary fotoğraf konumları (mapillary_indir.py çıktısı)
  yoksa                 veri/itu-yollar.json içinde koridora düşen yol noktaları (fotoğraf gelene kadar vekil)
Çıktı:
  egitim/bloklar.json   blok merkezi (metre), yarıçap, nokta sayısı, komşu bloklar
  egitim/bloklar.svg    harita: noktalar blok rengine boyalı

Neden k-means: bloklar yaklaşık eşit çaplı ve kompakt olmalı; her bloğun fotoğrafları tek ekran kartı belleğine
(6 GB) sığmalı. k, "blok başına en çok N nokta" koşulu sağlanana kadar artırılır. Komşu bloklar %20 bindirilir
ki birleşim yerinde boşluk kalmasın (VastGaussian / CityGaussian'daki bölme fikri).
Kullanım: python egitim/blok_kumele.py [--meta yol] [--azami 400] [--tohum 0]
"""
import argparse
import json
import math
import os

import numpy as np

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAT0, LON0, K = 41.105, 29.024, 111320.0
# mapillary_indir.py ile aynı koridor: güney, batı, kuzey, doğu
KUTU = (41.1042, 29.0216, 41.1099, 29.0390)


def metre(lat, lon):
    return ((lon - LON0) * K * math.cos(math.radians(LAT0)), -(lat - LAT0) * K)


def noktalar(meta, yollar):
    if meta:
        p = []
        with open(meta, encoding="utf-8") as f:
            for satir in f:
                g = json.loads(satir).get("computed_geometry")
                if g:
                    p.append(metre(g["coordinates"][1], g["coordinates"][0]))
        return np.array(p), "mapillary"
    (x0, z1), (x1, z0) = metre(KUTU[0], KUTU[1]), metre(KUTU[2], KUTU[3])
    p = []
    for y in json.load(open(yollar, encoding="utf-8")):
        for a, b in zip(y["p"], y["p"][1:]):
            n = max(1, int(math.dist(a, b) // 5))  # yol boyunca 5 m'de bir örnek
            for i in range(n):
                q = (a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n)
                if x0 <= q[0] <= x1 and z0 <= q[1] <= z1:
                    p.append(q)
    return np.array(p), "yol-vekil"


def kmeans(p, k, rng, tur=50):
    """Lloyd algoritması, k-means++ başlangıcı. Dönen: merkezler, etiketler."""
    m = [p[rng.integers(len(p))]]
    for _ in range(k - 1):
        d = np.min(((p[:, None] - np.array(m)[None]) ** 2).sum(-1), axis=1)
        m.append(p[rng.choice(len(p), p=d / d.sum())])
    m = np.array(m)
    for _ in range(tur):
        e = ((p[:, None] - m[None]) ** 2).sum(-1).argmin(1)
        yeni = np.array([p[e == j].mean(0) if (e == j).any() else m[j] for j in range(k)])
        if np.allclose(yeni, m, atol=0.01):
            break
        m = yeni
    return m, ((p[:, None] - m[None]) ** 2).sum(-1).argmin(1)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--meta")
    a.add_argument("--yollar", default=os.path.join(KOK, "veri", "itu-yollar.json"), help="fotoğraf yokken vekil: OSM yol dosyası (kampus-modu dalında)")
    a.add_argument("--azami", type=int, default=400)
    a.add_argument("--tohum", type=int, default=0)
    o = a.parse_args()
    p, kaynak = noktalar(o.meta, o.yollar)
    rng = np.random.default_rng(o.tohum)
    k = max(1, math.ceil(len(p) / o.azami))
    while True:
        m, e = kmeans(p, k, rng)
        if np.bincount(e, minlength=k).max() <= o.azami:
            break
        k += 1
    bloklar = []
    for j in range(k):
        q = p[e == j]
        r = float(np.sqrt(((q - m[j]) ** 2).sum(-1)).max())
        bloklar.append({"no": j, "merkez": [round(float(m[j][0]), 1), round(float(m[j][1]), 1)],
                        "yaricap": round(r, 1), "bindirmeli_yaricap": round(r * 1.2, 1), "nokta": int(len(q))})
    for b in bloklar:
        b["komsu"] = [c["no"] for c in bloklar if c is not b and
                      math.dist(b["merkez"], c["merkez"]) < b["bindirmeli_yaricap"] + c["bindirmeli_yaricap"]]
    json.dump({"kaynak": kaynak, "nokta": int(len(p)), "azami": o.azami, "tohum": o.tohum, "bloklar": bloklar},
              open(os.path.join(KOK, "egitim", "bloklar.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    mn, mx = p.min(0) - 40, p.max(0) + 40
    olcek = 1400 / (mx[0] - mn[0])
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="%d" style="background:#0b1016">' % ((mx[1] - mn[1]) * olcek)]
    for q, j in zip(p, e):
        svg.append('<circle cx="%.1f" cy="%.1f" r="2" fill="hsl(%d,70%%,62%%)"/>' % ((q[0] - mn[0]) * olcek, (q[1] - mn[1]) * olcek, j * 360 // k))
    for b in bloklar:
        cx, cy = (b["merkez"][0] - mn[0]) * olcek, (b["merkez"][1] - mn[1]) * olcek
        svg.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="hsl(%d,70%%,62%%)" stroke-dasharray="6 4"/>' % (cx, cy, b["bindirmeli_yaricap"] * olcek, b["no"] * 360 // k))
        svg.append('<text x="%.1f" y="%.1f" fill="#fff" font-family="Consolas" font-size="20" text-anchor="middle">%d (%d)</text>' % (cx, cy + 6, b["no"], b["nokta"]))
    open(os.path.join(KOK, "egitim", "bloklar.svg"), "w", encoding="utf-8").write("\n".join(svg) + "\n</svg>\n")
    print("kaynak %s · %d nokta · k = %d · blok başına en çok %d · yarıçap %.0f-%.0f m" % (
        kaynak, len(p), k, max(b["nokta"] for b in bloklar), min(b["yaricap"] for b in bloklar), max(b["yaricap"] for b in bloklar)))


if __name__ == "__main__":
    main()
