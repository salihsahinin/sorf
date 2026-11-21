"""Kapalı döngü: oynanış kaydı → CatBoost (rampada düşme olasılığı) → parkur ayarı.

Kalite ölçütü: parkuru hiç düşmeden bitirme olasılığı  P = Π (1 − p_i),  p_i = modelin i. rampa için düşme olasılığı.
Aday ayarlar: köşe yumuşatma tur sayısı (0-3) ve kesme oranı (0,15-0,40). Her aday için rampa özellikleri
(uzunluk, |dönüş|) veri/rota-kose.json köşelerinden oyunla aynı kuralla hesaplanır; giriş hızı kayıttaki medyandır.
Çıktı: veri/parkur-ayar.json (oyun açılışta okur) + egitim/model/parkur-rapor.json.
Kullanım: C:/tools/sorf-venv/Scripts/python egitim/parkur_ayarla.py
"""
import json
import math
import os

import numpy as np
import pandas as pd
from catboost import CatBoostClassifier
from sklearn.model_selection import StratifiedKFold, cross_val_score

KOK = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OZELLIK = ["uzunluk", "donus_mutlak", "giris_hiz"]
ASGARI = 40


def rampalar(kose, tur, oran):
    """Oyundaki (seviye.gd) kuralın aynısı: Chaikin + her kenar bir rampa (uzunluk − 1,5 m; 5 m altı atlanır)."""
    for _ in range(tur):
        y = [kose[0]]
        for a, b in zip(kose, kose[1:]):
            y += [a + (b - a) * oran, a + (b - a) * (1 - oran)]
        kose = y + [kose[-1]]
    yon = [math.atan2(-(b - a)[0], -(b - a)[1]) for a, b in zip(kose, kose[1:])]
    cikti = []
    for i, (a, b) in enumerate(zip(kose, kose[1:])):
        uz = float(np.linalg.norm(b - a)) - 1.5
        if uz < 5.0:
            continue
        d = 0.0 if i + 1 >= len(yon) else abs(math.degrees((yon[i + 1] - yon[i] + math.pi) % (2 * math.pi) - math.pi))
        cikti.append((uz, d))
    return cikti


def main():
    df = pd.read_json(os.path.join(KOK, "kayit", "oynanis.jsonl"), lines=True)
    df = df[(~df["bot"]) & (df["sure"] > 0.05)]          # bot satırları ve ışınlanma anı kayıtları dışarıda
    df["donus_mutlak"] = df["donus_derece"].abs()
    df["dustu"] = df["dustu"].astype(int)
    # Yeniden doğuş döngüsü ayıklanır: aynı rampada art arda düşme, oyuncu tuşa basmadan 2 sn içinde tekrarlandıysa
    # oyuncunun denemesi değildir (2026-11-21 kaydında 144 satırın çoğu böyleydi).
    dongu = (df["dustu"] == 1) & (df["sure"] < 2.0) & (df["bolum"] == df["bolum"].shift()) & (df["dustu"].shift() == 1)
    print("ayıklanan döngü satırı: %d" % int(dongu.sum()))
    df = df[~dongu]
    rapor = {"satir": int(len(df)), "dusme_orani": round(float(df["dustu"].mean()), 3)}
    print("satır %d · düşme oranı %.2f" % (len(df), df["dustu"].mean()))
    if len(df) < ASGARI or df["dustu"].nunique() < 2:
        raise SystemExit("model eğitilmedi: en az %d satır ve iki sınıf gerekir" % ASGARI)
    m = CatBoostClassifier(iterations=300, depth=3, learning_rate=0.05, verbose=0, random_seed=0,
                           monotone_constraints="(0,1,0)")   # dönüş arttıkça düşme azalmaz (az veride düzgünleştirme)
    kat = StratifiedKFold(5, shuffle=True, random_state=0)
    rapor["auc_5kat"] = round(float(cross_val_score(m, df[OZELLIK], df["dustu"], cv=kat, scoring="roc_auc").mean()), 3)
    m.fit(df[OZELLIK], df["dustu"])
    rapor["onem"] = dict(zip(OZELLIK, np.round(m.get_feature_importance(), 1).tolist()))
    os.makedirs(os.path.join(KOK, "egitim", "model"), exist_ok=True)
    m.save_model(os.path.join(KOK, "egitim", "model", "dusme.cbm"))
    kose = [np.array(k, dtype=float) for k in json.load(open(os.path.join(KOK, "veri", "rota-kose.json"), encoding="utf-8"))]
    hiz = float(df["giris_hiz"].median())
    adaylar = []
    for tur in range(0, 4):
        for oran in ([0.25] if tur == 0 else [0.15, 0.2, 0.25, 0.3, 0.35, 0.4]):
            r = rampalar(kose, tur, oran)
            x = pd.DataFrame({"uzunluk": [a for a, _ in r], "donus_mutlak": [b for _, b in r], "giris_hiz": hiz})
            p = m.predict_proba(x)[:, 1]
            adaylar.append({"tur": tur, "oran": oran, "rampa": len(r), "beklenen_dusme": round(float(p.sum()), 2),
                            "dusmeden_bitirme": round(float(np.prod(1 - p)), 5), "en_keskin_donus": round(max(b for _, b in r), 1)})
    adaylar.sort(key=lambda a: a["beklenen_dusme"])
    rapor["adaylar"] = adaylar
    rapor["secilen"] = adaylar[0]
    json.dump({"tur": adaylar[0]["tur"], "oran": adaylar[0]["oran"]}, open(os.path.join(KOK, "veri", "parkur-ayar.json"), "w"))
    json.dump(rapor, open(os.path.join(KOK, "egitim", "model", "parkur-rapor.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print("AUC (5 kat) %.3f · önem %s" % (rapor["auc_5kat"], rapor["onem"]))
    for a in adaylar[:3] + adaylar[-1:]:
        print(a)


if __name__ == "__main__":
    main()
