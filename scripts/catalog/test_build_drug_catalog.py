"""build_drug_catalog için testler (standart kütüphane unittest).

Çalıştırma: python -I -m unittest discover -s scripts/catalog -p "test_*.py"
Sahte XLSX dosyaları test içinde üretilir; gerçek TİTCK dosyası gerekmez.
"""

import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

sys.path.insert(0, str(Path(__file__).parent))
import build_drug_catalog as b  # noqa: E402

BASLIK = ["SIRA NO", "BARKOD", "ÜRÜN ADI", "ETKİN MADDE", "ATC KODU", "RUHSAT SAHİBİ", "RUHSAT TARİHİ",
          "RUHSAT NUMARASI", "DEĞİŞİKLİK", "x", "DEĞİŞİKLİK TARİHİ", "ASKI", "ASKIYA ALINMA TARİHİ"]


def xlsx_yaz(yol, satirlar):
    """Satırlar: liste listesi (her hücre metin). Satır içi metin (inlineStr) kullanılır."""
    harf = "ABCDEFGHIJKLM"
    govde = []
    for i, s in enumerate(satirlar, 1):
        hucreler = "".join(
            f'<c r="{harf[j]}{i}" t="inlineStr"><is><t>{escape(v)}</t></is></c>' for j, v in enumerate(s)
        )
        govde.append(f'<row r="{i}">{hucreler}</row>')
    xml = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
        + "".join(govde)
        + "</sheetData></worksheet>"
    )
    with zipfile.ZipFile(yol, "w") as z:
        z.writestr("xl/worksheets/sheet1.xml", xml)


def satir(no, barkod, ad, etkin, atc, aski="0"):
    return [str(no), barkod, ad, etkin, atc, "FİRMA", "22190", "1/1", "", "", "", aski, ""]


class SunumAdiTesti(unittest.TestCase):
    def test_kutu_boyu_atilir(self):
        self.assertEqual(b.sunum_adi("ONADRON 0.75 MG TABLET, 100 TABLET"), "ONADRON 0.75 MG TABLET")

    def test_virgul_yoksa_tamami(self):
        self.assertEqual(b.sunum_adi("PAROL 500 MG TABLET"), "PAROL 500 MG TABLET")

    def test_fazla_bosluk_tek_olur(self):
        self.assertEqual(b.sunum_adi("  PAROL   500  MG TABLET,   20   TABLET "), "PAROL 500 MG TABLET")

    def test_ondalik_virgul_korunur(self):
        self.assertEqual(
            b.sunum_adi("% 0,4 LIDODEKS %5 DEKSTROZ İÇİNDE ÇÖZELTİ, 250 ML SETLİ"),
            "% 0,4 LIDODEKS %5 DEKSTROZ İÇİNDE ÇÖZELTİ",
        )
        self.assertEqual(b.sunum_adi("% 0,4 LIDOKAİN ENJEKSİYONLUK ÇÖZELTİ"), "% 0,4 LIDOKAİN ENJEKSİYONLUK ÇÖZELTİ")

    def test_rakamla_baslamayan_virgullu_parca_adin_parcasi_kalir(self):
        self.assertEqual(
            b.sunum_adi("%30 DEKSTROZ SUDAKİ ÇÖZELTİSİ, PVC 500 ML (SETLI)"),
            "%30 DEKSTROZ SUDAKİ ÇÖZELTİSİ, PVC 500 ML (SETLI)",
        )
        self.assertEqual(b.sunum_adi("BRUNAC % 5 GÖZ DAMLASI, ÇÖZELTİ"), "BRUNAC % 5 GÖZ DAMLASI, ÇÖZELTİ")

    def test_yalniz_son_kutu_parcasi_atilir(self):
        self.assertEqual(b.sunum_adi("X 5 MG, 10 MG TABLET, 20 TABLET"), "X 5 MG, 10 MG TABLET")

    def test_ayni_sunumun_set_ve_kutu_boylari_ayni_ada_iner(self):
        a = b.sunum_adi("SERUM ÇÖZELTİ, 250 ML SETLİ")
        c = b.sunum_adi("SERUM ÇÖZELTİ, 500 ML SETSİZ")
        self.assertEqual(a, c)


class KatalogUretTesti(unittest.TestCase):
    def uret(self, *veri_satirlari, ust=None):
        satirlar = [["RUHSATLI ÜRÜNLER LİSTESİ"] if ust is None else ust, BASLIK, *veri_satirlari]
        with tempfile.TemporaryDirectory() as d:
            yol = Path(d) / "t.xlsx"
            xlsx_yaz(yol, satirlar)
            return b.katalog_uret(b.satirlari_oku(yol))

    def test_ayni_sunumun_kutu_boylari_tek_satir_olur(self):
        items, ist = self.uret(
            satir(1, "111", "ONADRON 0.75 MG TABLET, 100 TABLET", "Dekzametazon", "H02AB02"),
            satir(2, "112", "ONADRON 0.75 MG TABLET, 20 TABLET", "dekzametazon", "H02AB02"),
        )
        self.assertEqual(items, [("ONADRON 0.75 MG TABLET", "dekzametazon", "H02AB02")])
        self.assertEqual(ist["kaynak_satir"], 2)
        self.assertEqual(ist["katalog_satiri"], 1)

    def test_askidaki_urunler_girmez(self):
        items, ist = self.uret(
            satir(1, "1", "A 10 MG TABLET, 10 TABLET", "x", "N01", aski="0"),
            satir(2, "2", "B 10 MG TABLET, 10 TABLET", "y", "N02", aski="1"),
            satir(3, "3", "C 10 MG TABLET, 10 TABLET", "z", "N03", aski="2"),
            satir(4, "4", "D 10 MG TABLET, 10 TABLET", "w", "N04", aski="3"),
        )
        self.assertEqual([i[0] for i in items], ["A 10 MG TABLET"])
        self.assertEqual(ist["askida_atlanan"], 3)

    def test_farkli_doz_ve_farkli_atc_ayri_satir(self):
        items, _ = self.uret(
            satir(1, "1", "PAROL 500 MG TABLET, 20 TABLET", "parasetamol", "N02BE01"),
            satir(2, "2", "PAROL 650 MG TABLET, 20 TABLET", "parasetamol", "N02BE01"),
            satir(3, "3", "PAROL 500 MG TABLET, 20 TABLET", "parasetamol", "N02BE51"),
        )
        self.assertEqual(len(items), 3)

    def test_atc_bos_kalir_ve_sayilir(self):
        items, ist = self.uret(satir(1, "1", "X 5 MG TABLET, 10 TABLET", "m", ""))
        self.assertEqual(items[0][2], "")
        self.assertEqual(ist["atc_bos"], 1)

    def test_alt_bilgi_ve_sayisal_olmayan_satirlar_atlanir(self):
        items, ist = self.uret(
            satir(1, "1", "A 1 MG TABLET, 10 TABLET", "m", "N01"),
            ["Toplam", "", "", "", ""],
        )
        self.assertEqual(len(items), 1)
        self.assertEqual(ist["kaynak_satir"], 1)

    def test_adsiz_satir_atlanir_ve_sayilir(self):
        items, ist = self.uret(satir(1, "1", "  ", "m", "N01"), satir(2, "2", ", 10 TABLET", "m", "N01"))
        self.assertEqual(items, [])
        self.assertEqual(ist["adsiz_atlanan"], 2)

    def test_cikti_ada_gore_sirali_ve_deterministik(self):
        veri = [
            satir(1, "1", "ZETA 1 MG TABLET, 10 TABLET", "m", "N01"),
            satir(2, "2", "ALFA 1 MG TABLET, 10 TABLET", "m", "N01"),
        ]
        a, _ = self.uret(*veri)
        c, _ = self.uret(*reversed(veri))
        self.assertEqual(a, c)
        self.assertEqual([i[0] for i in a], ["ALFA 1 MG TABLET", "ZETA 1 MG TABLET"])

    def test_cok_satirda_cikti_siralidir(self):
        # Az öğede küme sırası tesadüfen sıralı çıkabilir; 40 öğede çıkmaz.
        veri = [satir(i, str(i), f"ILAC{(i * 7) % 40:02d} 5 MG TABLET, 10 TABLET", "m", "N01") for i in range(1, 41)]
        items, _ = self.uret(*veri)
        self.assertEqual(len(items), 40)
        self.assertEqual(items, sorted(items))

    def test_baslik_degismisse_durur(self):
        bozuk = list(BASLIK)
        bozuk[4] = "ATC"
        with tempfile.TemporaryDirectory() as d:
            yol = Path(d) / "t.xlsx"
            xlsx_yaz(yol, [["üst"], bozuk, satir(1, "1", "A 1 MG, 1", "m", "N01")])
            with self.assertRaises(b.KatalogHatasi):
                b.katalog_uret(b.satirlari_oku(yol))

    def test_birinci_sayfa_yoksa_hata(self):
        with tempfile.TemporaryDirectory() as d:
            yol = Path(d) / "t.xlsx"
            with zipfile.ZipFile(yol, "w") as z:
                z.writestr("xl/worksheets/sheet9.xml", "<x/>")
            with self.assertRaises(b.KatalogHatasi):
                list(b.satirlari_oku(yol))


class YazTesti(unittest.TestCase):
    def test_json_yapisi_ve_turkce_karakter(self):
        items = [("ÇAYKUR 1 MG TABLET", "şeker", "A01")]
        with tempfile.TemporaryDirectory() as d:
            yol = b.yaz(items, {"katalog_satiri": 1}, "2026-11-06", Path(d) / "alt" / "drugs.json")
            veri = json.loads(yol.read_text(encoding="utf-8"))
        self.assertEqual(veri["items"], [["ÇAYKUR 1 MG TABLET", "şeker", "A01"]])
        self.assertEqual(veri["meta"]["liste_tarihi"], "2026-11-06")
        self.assertEqual(veri["meta"]["askidakiler"], "dışarıda")

    def test_ayni_girdi_ayni_dosya(self):
        items = [("A 1 MG", "m", "N01"), ("B 1 MG", "m", "N01")]
        with tempfile.TemporaryDirectory() as d:
            a = b.yaz(items, {}, "2026-11-06", Path(d) / "a.json").read_bytes()
            c = b.yaz(items, {}, "2026-11-06", Path(d) / "c.json").read_bytes()
        self.assertEqual(a, c)


if __name__ == "__main__":
    unittest.main()
