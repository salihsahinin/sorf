"""Fotoğrafların sayısal özelliklerini niyet listesine göre kümeler; eğitim kümelerini çıkarır.

Girdi: <veri>/meta.jsonl + <veri>/resim/<id>.jpg (mapillary_indir.py çıktısı).
Fotoğraf başına özellikler:
  meta'dan  : x, z (metre) · pusula_sin, pusula_cos (bakış yönü) · saat_sin, saat_cos (çekim saati) · gun (çekim günü)
  pikselden : parlaklik (0-1 ortalama) · r, g, b (ortalama renk) · keskinlik (Laplace varyansı; düşük = bulanık; kümelemede log10)
Niyet listesi (egitim/gorsel_niyetler.json): her niyet bir özellik grubunu k-means ile kümeler.
Çıktı: <veri>/kumeler.csv (fotoğraf başına özellikler + niyet etiketleri + egitim_kumesi)
       <veri>/kumeler-ozet.json (niyet başına küme merkezleri ve sayılar; eğitim kümesi listesi)
Kullanım: C:/tools/sorf-venv/Scripts/python egitim/gorsel_kumele.py --veri C:/sistem/sorf-veri/mapillary
"""
import argparse
import datetime
import json
import math
import os

import numpy as np
import pandas as pd
from PIL import Image
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAT0, LON0, K = 41.105, 29.024, 111320.0


def piksel_ozellik(yol):
    """Küçültülmüş kareden parlaklık, ortalama renk ve keskinlik."""
    g = np.asarray(Image.open(yol).convert("RGB").resize((256, 192)), dtype=np.float32) / 255.0
    gri = g.mean(2)
    lap = gri[1:-1, 1:-1] * 4 - gri[:-2, 1:-1] - gri[2:, 1:-1] - gri[1:-1, :-2] - gri[1:-1, 2:]
    return float(gri.mean()), float(g[..., 0].mean()), float(g[..., 1].mean()), float(g[..., 2].mean()), float(lap.var())


def oku(veri):
    satirlar = []
    with open(os.path.join(veri, "meta.jsonl"), encoding="utf-8") as f:
        for s in f:
            m = json.loads(s)
            yol = os.path.join(veri, "resim", "%s.jpg" % m["id"])
            if not os.path.exists(yol) or not m.get("computed_geometry"):
                continue
            lon, lat = m["computed_geometry"]["coordinates"]
            t = datetime.datetime.fromtimestamp(m["captured_at"] / 1000.0)
            saat = (t.hour + t.minute / 60.0) / 24.0 * 2 * math.pi
            aci = math.radians(m.get("computed_compass_angle") or 0.0)
            p, r, g, b, k = piksel_ozellik(yol)
            satirlar.append({"id": m["id"], "x": (lon - LON0) * K * math.cos(math.radians(LAT0)), "z": -(lat - LAT0) * K,
                             "pusula_sin": math.sin(aci), "pusula_cos": math.cos(aci),
                             "saat_sin": math.sin(saat), "saat_cos": math.cos(saat), "gun": t.strftime("%Y-%m-%d"),
                             "kamera": m.get("camera_type", ""), "parlaklik": p, "r": r, "g": g, "b": b, "keskinlik": k})
    return pd.DataFrame(satirlar)


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--veri", default="C:/sistem/sorf-veri/mapillary")
    a.add_argument("--asgari", type=int, default=60, help="eğitim kümesi için en az fotoğraf")
    o = a.parse_args()
    df = oku(o.veri)
    df["keskinlik_log"] = np.log10(df["keskinlik"] + 1e-9)   # keskinlik çok geniş aralıkta; logaritmada kümelenir
    niyet = json.load(open(os.path.join(KOK, "egitim", "gorsel_niyetler.json"), encoding="utf-8"))
    ozet = {"fotograf": int(len(df)), "gun_sayisi": int(df["gun"].nunique()), "niyetler": {}}
    for n in niyet["niyetler"]:
        x = StandardScaler().fit_transform(df[n["ozellikler"]])
        k = n["k"]
        if k == "otomatik":   # blok: hiçbir küme "azami" fotoğrafı geçmeyene kadar k artar
            k = max(1, math.ceil(len(df) / n["azami"]))
            while np.bincount(KMeans(k, n_init=5, random_state=0).fit_predict(x)).max() > n["azami"]:
                k += 1
        k = min(k, len(df))
        km = KMeans(k, n_init=10, random_state=0).fit(x)
        df[n["ad"]] = km.labels_
        merkez = df.groupby(n["ad"])[n["ozellikler"]].mean().round(3)
        ozet["niyetler"][n["ad"]] = {"soz": n["soz"], "k": int(k), "sayi": np.bincount(km.labels_).tolist(),
                                     "merkez": merkez.to_dict("records")}
        if n.get("ele") == "en_dusuk_keskinlik":   # kalite: ortalama keskinliği en düşük küme eğitimden çıkar
            kotu = int(merkez["keskinlik_log"].idxmin())
            # Küme yalnız belirgin biçimde bulanıksa elenir: merkezler arası fark en az 0,5 (keskinlikte ~3 kat).
            belirgin = k > 1 and merkez["keskinlik_log"].max() - merkez["keskinlik_log"].min() >= 0.5
            df["egitime_girer"] = (df[n["ad"]] != kotu) | (not belirgin)
            ozet["niyetler"][n["ad"]]["elenen_kume"] = kotu
            ozet["niyetler"][n["ad"]]["elenen_fotograf"] = int((~df["egitime_girer"]).sum())
    # Eğitim kümesi = (blok, ışık) çifti; asgari fotoğraf sayısının altındakiler "yetersiz" işaretlenir.
    iyi = df[df["egitime_girer"]]
    sayim = iyi.groupby(["blok", "isik"]).size()
    df["egitim_kumesi"] = ["b%d-i%d" % (b, i) if e and sayim.get((b, i), 0) >= o.asgari else ""
                           for b, i, e in zip(df["blok"], df["isik"], df["egitime_girer"])]
    ozet["egitim_kumeleri"] = [{"ad": "b%d-i%d" % k, "fotograf": int(v), "egitilir": bool(v >= o.asgari)} for k, v in sayim.items()]
    ozet["egitilecek_kume"] = int(sum(c["egitilir"] for c in ozet["egitim_kumeleri"]))
    ozet["egitime_giren_fotograf"] = int((df["egitim_kumesi"] != "").sum())
    df.to_csv(os.path.join(o.veri, "kumeler.csv"), index=False)
    json.dump(ozet, open(os.path.join(o.veri, "kumeler-ozet.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("fotoğraf %d · gün %d" % (ozet["fotograf"], ozet["gun_sayisi"]))
    for ad, v in ozet["niyetler"].items():
        print("  %-7s k=%d sayılar %s%s" % (ad, v["k"], v["sayi"], " · elenen %d" % v["elenen_fotograf"] if "elenen_fotograf" in v else ""))
    print("eğitim kümesi: %d eğitilecek / %d toplam · eğitime giren fotoğraf %d" % (
        ozet["egitilecek_kume"], len(ozet["egitim_kumeleri"]), ozet["egitime_giren_fotograf"]))


if __name__ == "__main__":
    main()
