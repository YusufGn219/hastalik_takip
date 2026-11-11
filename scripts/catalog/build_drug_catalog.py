"""TİTCK "Ruhsatlı Beşeri Tıbbi Ürünler Listesi" XLSX dosyasından ilaç kataloğu üretir.

Yalnız Python standart kütüphanesi kullanır (paket kurulumu yok); çalıştırma:

    python -I scripts/catalog/build_drug_catalog.py <liste.xlsx> --tarih 2026-11-06 \
        [--cikti scripts/catalog/out/drugs.json]

Kurallar (kullanıcı kararı, 2026-11-11):
  * Düzey "sunum": ürün adından sondaki kutu boyu parçası (", 100 TABLET") atılır;
    ad + doz + form kalır. Ondalık virgül ("0,4") ve rakamla başlamayan
    parçalar adın parçasıdır. Aynı (sunum, etkin madde, ATC) üçlüsü tek satır olur.
  * Ruhsatı askıda olan ürünler (askı durumu 0 dışında) kataloğa girmez.
  * Barkod katalogda tutulmaz.
  * Metinler olduğu gibi (büyük harf, kaynak yazımı) saklanır; arama için
    normalleştirme uygulamada yapılır (foldTr).

Çıktı JSON: {"meta": {...}, "items": [[ad, etkin_madde, atc], ...]}, ada göre sıralı,
aynı girdiyle aynı çıktı (deterministik).

UYARI: Üretilen dosya git'e GİRMEZ (.gitignore). TİTCK verisinin uygulamayla
dağıtımı için izin teyidi (Sprint 10 hukuk teyidi) alınana kadar yayımlanmaz.
"""

import argparse
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
_T = "{%s}t" % NS["m"]
_ROW = "{%s}row" % NS["m"]

# Beklenen başlıklar (ikinci satır); sıra ve ad doğrulanır, kayarsa betik durur.
BEKLENEN_BASLIKLAR = {
    "A": "SIRA NO",
    "B": "BARKOD",
    "C": "ÜRÜN ADI",
    "D": "ETKİN MADDE",
    "E": "ATC KODU",
}
ASKI_SUTUNU = "L"  # "RUHSATI ASKIDA OLMAYAN ÜRÜN: 0 ..." sütunu


class KatalogHatasi(Exception):
    pass


def _sutun(ref):
    return re.match(r"[A-Z]+", ref).group(0)


def _paylasilan_metinler(z):
    if "xl/sharedStrings.xml" not in z.namelist():
        return []
    kok = ET.fromstring(z.read("xl/sharedStrings.xml"))
    return ["".join(t.text or "" for t in si.iter(_T)) for si in kok.findall("m:si", NS)]


def satirlari_oku(yol):
    """Birinci sayfanın satırlarını {sütun_harfi: metin} sözlüğü olarak üretir."""
    with zipfile.ZipFile(yol) as z:
        metinler = _paylasilan_metinler(z)
        sayfa = "xl/worksheets/sheet1.xml"
        if sayfa not in z.namelist():
            raise KatalogHatasi("Birinci sayfa bulunamadı: " + sayfa)
        # Akış açıkça kapatılır: Windows'ta açık kalan tutamaç dosyayı kilitler.
        with z.open(sayfa) as akis:
            for _, el in ET.iterparse(akis, events=("end",)):
                if el.tag != _ROW:
                    continue
                satir = {}
                for c in el.findall("m:c", NS):
                    v = c.find("m:v", NS)
                    if v is not None:
                        satir[_sutun(c.get("r"))] = metinler[int(v.text)] if c.get("t") == "s" else v.text
                        continue
                    satir_ici = c.find("m:is", NS)
                    if satir_ici is not None:
                        satir[_sutun(c.get("r"))] = "".join(t.text or "" for t in satir_ici.iter(_T))
                yield satir
                el.clear()


# Kutu boyu eki: SON "virgül + boşluk" parçası rakamla başlıyorsa ("..., 100 TABLET",
# "..., 250 ML SETLİ"). Virgül + boşluk şartı ondalık virgülü ("0,4") korur; rakamla
# başlamayan parçalar ("..., ÇÖZELTİ", "..., PVC 500 ML") adın parçasıdır, kalır.
_KUTU_EKI = re.compile(r",\s+\d[^,]*$")


def sunum_adi(urun_adi):
    """'ONADRON 0.75 MG TABLET, 100 TABLET' -> 'ONADRON 0.75 MG TABLET'.

    Yalnız sondaki tek kutu boyu parçası atılır; ondalık virgül ve rakamla
    başlamayan virgüllü parçalar korunur.
    """
    ad = re.sub(r"\s+", " ", urun_adi).strip()
    return _KUTU_EKI.sub("", ad).strip()


def katalog_uret(satirlar):
    """Satırlardan (ad, etkin, atc) listesi üretir; (liste, istatistik) döner."""
    baslik_goruldu = False
    ham = askida = eksik_ad = 0
    gorulen = set()
    for satir in satirlar:
        if not baslik_goruldu:
            if all(satir.get(k, "").strip() == v for k, v in BEKLENEN_BASLIKLAR.items()):
                baslik_goruldu = True
            continue
        if not satir.get("A", "").strip().isdigit():
            continue  # alt bilgi vb.
        ham += 1
        if satir.get(ASKI_SUTUNU, "0").strip() not in ("0", ""):
            askida += 1
            continue
        ad = sunum_adi(satir.get("C", ""))
        if not ad:
            eksik_ad += 1
            continue
        etkin = re.sub(r"\s+", " ", satir.get("D", "")).strip().lower()
        atc = satir.get("E", "").strip().upper()
        gorulen.add((ad, etkin, atc))
    if not baslik_goruldu:
        raise KatalogHatasi(
            "Başlık satırı beklenen biçimde değil (SIRA NO, BARKOD, ÜRÜN ADI, ETKİN MADDE, ATC KODU); "
            "dosya biçimi değişmiş olabilir."
        )
    items = sorted(gorulen)
    istatistik = {
        "kaynak_satir": ham,
        "askida_atlanan": askida,
        "adsiz_atlanan": eksik_ad,
        "katalog_satiri": len(items),
        "atc_bos": sum(1 for _, _, a in items if not a),
    }
    return items, istatistik


def yaz(items, istatistik, tarih, cikti):
    cikti = Path(cikti)
    cikti.parent.mkdir(parents=True, exist_ok=True)
    veri = {
        "meta": {
            "kaynak": "TİTCK Ruhsatlı Beşeri Tıbbi Ürünler Listesi",
            "liste_tarihi": tarih,
            "duzey": "sunum (ad + doz + form; kutu boyu yok)",
            "askidakiler": "dışarıda",
            **istatistik,
        },
        "items": [list(x) for x in items],
    }
    cikti.write_text(json.dumps(veri, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return cikti


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("xlsx")
    p.add_argument("--tarih", required=True, help="listenin tarihi, YYYY-MM-DD")
    p.add_argument("--cikti", default="scripts/catalog/out/drugs.json")
    a = p.parse_args(argv)
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", a.tarih):
        p.error("--tarih YYYY-MM-DD olmalı")
    items, ist = katalog_uret(satirlari_oku(a.xlsx))
    yol = yaz(items, ist, a.tarih, a.cikti)
    print(json.dumps(ist, ensure_ascii=False))
    print("yazıldı:", yol, f"({yol.stat().st_size / 1e6:.2f} MB)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KatalogHatasi as e:
        print("HATA:", e, file=sys.stderr)
        sys.exit(2)
