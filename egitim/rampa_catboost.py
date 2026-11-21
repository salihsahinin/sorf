"""Oynanış kaydından rampa zorluğu modeli: k-means ile rampa türleri, tür başına CatBoost.

Girdi: kayit/oynanis.jsonl (oyun kampüs modunda rampa başına bir satır yazar).
Adımlar:
  1. Rampa özellikleri (uzunluk, |dönüş|, taraf, giriş hızı) standartlaştırılır, k-means ile K türe ayrılır.
  2. Her tür için CatBoostClassifier "dustu" hedefini öğrenir (tür içinde iki sınıf da varsa ve satır >= ASGARI ise).
  3. Çıktı: egitim/model/tur_<k>.cbm + egitim/model/ozet.json (tür merkezleri, satır sayısı, düşme oranı, AUC).
Kullanım: C:/tools/sorf-venv/Scripts/python egitim/rampa_catboost.py [--k 3]
Veri azsa model eğitilmez; betik hangi türde kaç satır eksik olduğunu yazar.
"""
import argparse
import json
import os

import numpy as np
import pandas as pd
from catboost import CatBoostClassifier
from sklearn.cluster import KMeans
from sklearn.model_selection import cross_val_score
from sklearn.preprocessing import StandardScaler

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OZELLIK = ["uzunluk", "donus_mutlak", "taraf", "giris_hiz"]
ASGARI = 30


def main():
    a = argparse.ArgumentParser()
    a.add_argument("--kayit", default=os.path.join(KOK, "kayit", "oynanis.jsonl"))
    a.add_argument("--k", type=int, default=3)
    o = a.parse_args()
    if not os.path.exists(o.kayit):
        raise SystemExit("kayıt yok: %s (kampüs modunda oyna, dosya kendiliğinden oluşur)" % o.kayit)
    df = pd.read_json(o.kayit, lines=True)
    df = df[~df["bot"]]
    df["donus_mutlak"] = df["donus_derece"].abs()
    df["dustu"] = df["dustu"].astype(int)
    print("satır %d · düşme oranı %.2f" % (len(df), df["dustu"].mean() if len(df) else float("nan")))
    if len(df) < o.k:
        raise SystemExit("kümeleme için en az %d satır gerekir" % o.k)
    olcek = StandardScaler().fit(df[OZELLIK])
    km = KMeans(n_clusters=o.k, n_init=10, random_state=0).fit(olcek.transform(df[OZELLIK]))
    df["tur"] = km.labels_
    cikti = os.path.join(KOK, "egitim", "model")
    os.makedirs(cikti, exist_ok=True)
    ozet = {"satir": int(len(df)), "k": o.k, "turler": []}
    for t in range(o.k):
        alt = df[df["tur"] == t]
        kayit = {"tur": t, "satir": int(len(alt)), "dusme_orani": round(float(alt["dustu"].mean()), 3),
                 "merkez": dict(zip(OZELLIK, np.round(olcek.inverse_transform(km.cluster_centers_[t:t + 1])[0], 2).tolist()))}
        if len(alt) < ASGARI or alt["dustu"].nunique() < 2:
            kayit["model"] = "eğitilmedi: satır %d/%d, sınıf sayısı %d" % (len(alt), ASGARI, alt["dustu"].nunique())
        else:
            m = CatBoostClassifier(iterations=300, depth=4, learning_rate=0.05, verbose=0, random_seed=0)
            kayit["auc_5kat"] = round(float(cross_val_score(m, alt[OZELLIK], alt["dustu"], cv=5, scoring="roc_auc").mean()), 3)
            m.fit(alt[OZELLIK], alt["dustu"])
            m.save_model(os.path.join(cikti, "tur_%d.cbm" % t))
            kayit["model"] = "tur_%d.cbm" % t
            kayit["onem"] = dict(zip(OZELLIK, np.round(m.get_feature_importance(), 1).tolist()))
        ozet["turler"].append(kayit)
        print(kayit)
    json.dump(ozet, open(os.path.join(cikti, "ozet.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)


if __name__ == "__main__":
    main()
