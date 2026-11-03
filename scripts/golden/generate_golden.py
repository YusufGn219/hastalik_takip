"""Altin veri (golden data) uretici - vitapuls Sprint 0.

Eski Python analitigini sabit bir ornek veri setiyle, SABITLENMIS bir "simdi" ile
calistirir ve hem girdiyi hem cikti JSON'larini mobile/test/golden/ altina yazar.
Dart'a tasinan analitik bu dosyalarla birebir karsilastirilacak (Sprint 2).

Calistirma (depo kokunden):
    ./venv/Scripts/python.exe scripts/golden/generate_golden.py

Proje ayarlarina ve PostgreSQL'e dokunmaz: gecici, bellek ici SQLite kullanir.
"""
import json
import math
import sys
from datetime import date, datetime, timedelta, timezone as dt_tz
from decimal import Decimal
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
OUT_DIR = ROOT / "mobile" / "test" / "golden"

import django  # noqa: E402
from django.conf import settings  # noqa: E402

settings.configure(
    DEBUG=False,
    SECRET_KEY="golden-only",
    INSTALLED_APPS=[
        "django.contrib.contenttypes",
        "django.contrib.auth",
        "apps.users",
        "apps.health",
    ],
    DATABASES={"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}},
    AUTH_USER_MODEL="users.User",
    USE_TZ=True,
    TIME_ZONE="Europe/Istanbul",
    DEFAULT_AUTO_FIELD="django.db.models.BigAutoField",
)
django.setup()

from django.core.management import call_command  # noqa: E402

call_command("migrate", verbosity=0, interactive=False)

from apps.health.models import (  # noqa: E402
    ChronicCondition, DailyLog, Episode, Medication, MedicationLog, Symptom,
    SymptomEntry,
)
from apps.users.models import User  # noqa: E402
from services.health import analytics  # noqa: E402

# "Simdi" sabit: 2026-11-01 10:00 UTC (= 13:00 Istanbul; UTC ve yerel tarih ayni).
FROZEN_NOW = datetime(2026, 11, 1, 10, 0, 0, tzinfo=dt_tz.utc)
PERIODS = [7, 30, 90]


def t(s):
    """'2026-10-25T10:00' -> UTC aware datetime."""
    return datetime.fromisoformat(s).replace(tzinfo=dt_tz.utc)


def iso(dt):
    return None if dt is None else dt.astimezone(dt_tz.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --------------------------------------------------------------- veri seti
user = User.objects.create_user(
    email="golden@example.com", password="x", first_name="Altin", last_name="Veri"
)
sym = {s.name: s for s in Symptom.objects.all()}
med = {m.name: m for m in Medication.objects.filter(is_global=True)}
S_HEAD, S_FEVER, S_COUGH, S_TIRED = (
    sym["Baş ağrısı"], sym["Ateş"], sym["Öksürük"], sym["Yorgunluk"],
)
M_PAROL, M_ASPIRIN = med["Parol"], med["Aspirin"]

# Kullaniciya ait tekrarlayan ilaclar (adlar ASCII: SQLite/PG siralamasi ayni kalsin).
M_DAILY = Medication.objects.create(
    user=user, name="Gunluk vitamin", type="chronic", is_recurring=True,
    recurring_time="09:00", recurring_days=None)
M_WEEK = Medication.objects.create(
    user=user, name="Hafta ici ilac", type="chronic", is_recurring=True,
    recurring_time="08:00", recurring_days=["monday", "wednesday", "friday"])
M_BAD = Medication.objects.create(
    user=user, name="Hatali gun adi", type="chronic", is_recurring=True,
    recurring_time="21:00", recurring_days=["funday"])  # gecersiz ad -> her gun beklenir

cond = ChronicCondition.objects.create(user=user, name="Migren")
cond.medications.set([M_DAILY, M_WEEK])

# Gunluk kayitlar: 2026-10-01 .. 2026-11-01, bazi gunler eksik, bir gun su = 0.0.
GAP_DAYS = {5, 6, 17, 29}
for i in range(32):
    if i in GAP_DAYS:
        continue
    DailyLog.objects.create(
        user=user,
        date=date(2026, 10, 1) + timedelta(days=i),
        sleep_hours=5.0 + ((i * 7) % 10) / 2,
        water_intake=0.0 if i == 12 else 1.0 + ((i * 3) % 8) / 2,
        mood=1 + (i * 3) % 5,
        energy_level=1 + (i * 2) % 5,
    )


def episode(symptom, start, end=None, notes=""):
    return Episode.objects.create(
        user=user, symptom=symptom, start_time=t(start),
        ended_at=t(end) if end else None,
        status="resolved" if end else "ongoing", resolution_notes=notes)


def entry(symptom, ts, severity, ep=None, location=""):
    return SymptomEntry.objects.create(
        user=user, symptom=symptom, episode=ep, severity=severity,
        timestamp=t(ts), location=location)


def medlog(m, ts, ep=None, cond_=None, dose=None):
    return MedicationLog.objects.create(
        user=user, medication=m, taken_at=t(ts), dose_amount=dose,
        dose_unit="tablet", episode=ep, condition=cond_)


# --- Atak A: bas agrisi, 90 gunluk pencerede (30 gunde degil: 2026-10-03)
epA = episode(S_HEAD, "2026-10-03T06:00", "2026-10-03T14:00")
entry(S_HEAD, "2026-10-03T06:00", 7, epA, "alin")
entry(S_HEAD, "2026-10-03T07:30", 8, epA)
medlog(M_PAROL, "2026-10-03T08:00", epA, dose=500)
entry(S_HEAD, "2026-10-03T09:00", 5, epA)
entry(S_HEAD, "2026-10-03T11:00", 4, epA)

# --- Atak B: bas agrisi, 30 gunluk pencerede (2026-10-20)
epB = episode(S_HEAD, "2026-10-20T15:00", "2026-10-21T01:00")
entry(S_HEAD, "2026-10-20T15:00", 6, epB, "sag sakak")
entry(S_HEAD, "2026-10-20T16:00", 7, epB)
medlog(M_PAROL, "2026-10-20T16:30", epB, dose=500)
entry(S_HEAD, "2026-10-20T17:30", 4, epB)   # sonraki 2 saatte
entry(S_HEAD, "2026-10-20T18:30", 2, epB)
medlog(M_ASPIRIN, "2026-10-20T20:00", epB, dose=100)  # oncesi var, sonrasi yok -> atlanir
entry(S_HEAD, "2026-10-20T19:00", 3, epB)
# Sinir durumlari: oncesi tam taken_at'ta dahil, sonrasi tam taken_at+2s'de dahil
medlog(M_PAROL, "2026-10-20T22:00", epB, dose=500)
entry(S_HEAD, "2026-10-20T22:00", 5, epB)            # tam taken_at (once, dahil)
entry(S_HEAD, "2026-10-21T00:00", 1, epB)            # tam taken_at+2s (sonra, dahil)

# --- Atak C: atesli, 7 gunluk pencerenin icinde ve devam ediyor
epC = episode(S_FEVER, "2026-10-28T08:00")
entry(S_FEVER, "2026-10-28T08:00", 6, epC)
entry(S_FEVER, "2026-10-28T09:30", 7, epC)
medlog(M_ASPIRIN, "2026-10-28T10:00", epC, dose=100)
entry(S_FEVER, "2026-10-28T11:00", 4, epC)
entry(S_FEVER, "2026-10-28T11:45", 3, epC)
medlog(M_ASPIRIN, "2026-10-29T08:00", epC, dose=100)
entry(S_FEVER, "2026-10-29T07:00", 5, epC)
entry(S_FEVER, "2026-10-29T07:30", 6, epC)
entry(S_FEVER, "2026-10-29T09:00", 4, epC)
entry(S_FEVER, "2026-10-29T09:30", 3, epC)
entry(S_FEVER, "2026-10-29T10:15", 6, epC)
# Oncesi hic yok -> bu ilac kaydi atlanir
medlog(M_PAROL, "2026-10-30T12:00", epC, dose=500)
entry(S_FEVER, "2026-10-30T13:00", 3, epC)
# Atagi olmayan ilac kaydi: etki hesabina girmez
medlog(M_PAROL, "2026-10-31T09:00", None, dose=500)

# --- Atagi olmayan tekil kayitlar (sinir ve saat-dilimi durumlari)
entry(S_COUGH, "2026-10-09T10:00", 3)
entry(S_COUGH, "2026-10-12T21:30", 4)
entry(S_COUGH, "2026-10-15T12:00", 5)
entry(S_COUGH, "2026-10-26T21:30", 2)   # yerel 27 Ekim 00:30; analitik UTC gunu kullanir (26)
entry(S_COUGH, "2026-10-27T21:30", 3)   # yerel 28 Ekim 00:30; UTC gunu 27
entry(S_COUGH, "2026-10-29T14:00", 3)
entry(S_TIRED, "2026-10-22T10:00", 4)   # count esitligini onlemek icin
entry(S_TIRED, "2026-10-25T10:00", 4)   # 7 gunluk pencerenin TAM siniri (dahil)
entry(S_TIRED, "2026-10-25T09:59", 9)   # siniri 1 dk gecmis (7 gunde dislanir)
entry(S_TIRED, "2026-10-02T10:00", 3)   # 30 gunluk pencerenin TAM siniri (dahil)
entry(S_TIRED, "2026-10-02T09:59", 8)   # 1 dk gecmis (30 gunde dislanir)
entry(S_TIRED, "2026-10-30T09:00", 3)
entry(S_TIRED, "2026-10-31T09:00", 5)
entry(S_TIRED, "2026-10-31T15:00", 4)

# --- Tekrarlayan ilac kayitlari (uyum)
medlog(M_DAILY, "2026-10-02T06:00", cond_=cond)
for d in range(3, 32):                       # 3 Ekim .. 31 Ekim; her 5. gun atlanir
    if d % 5 == 0:
        continue
    medlog(M_DAILY, f"2026-10-{d:02d}T06:00", cond_=cond)
medlog(M_DAILY, "2026-10-04T18:00", cond_=cond)   # ayni gunde 2. kayit: tek gun sayilir
medlog(M_DAILY, "2026-11-01T06:00", cond_=cond)
# Hafta ici ilac: Pzt/Car/Cum + izinli olmayan bir gunde alim (Sal 13 Ekim)
for d in ("2026-10-05", "2026-10-07", "2026-10-09", "2026-10-12", "2026-10-14",
          "2026-10-16", "2026-10-21", "2026-10-23", "2026-10-26", "2026-10-30"):
    medlog(M_WEEK, f"{d}T05:30", cond_=cond)
medlog(M_WEEK, "2026-10-13T05:30", cond_=cond)    # Sali: izinli degil ama sayilir
# Gece yarisi sinirinda alim: 22:30 UTC = yerel ertesi gun 01:30 (taken_at__date yerel)
medlog(M_BAD, "2026-10-26T22:30", cond_=cond)     # yerel 27 Ekim
medlog(M_BAD, "2026-10-29T12:00", cond_=cond)
medlog(M_BAD, "2026-10-31T12:00", cond_=cond)


# ------------------------------------------------- belirsizlik korumasi
AMBIGUOUS = []


def checked_round(x, ndigits=None):
    """Yarim-yarim (tie) durumlari reddeder: SQLite/PG ve Dart arasinda
    yuvarlama farki dogurabilecek veri setini baştan eleriz."""
    scale = 10 ** (ndigits or 0)
    scaled = float(x) * scale
    if abs((scaled - math.floor(scaled)) - 0.5) < 1e-6:
        loc = sys._getframe(1).f_locals
        where = loc.get("day") or loc.get("med_name") or loc.get("item")
        AMBIGUOUS.append(f"{x!r} (ndigits={ndigits}) @ {where}")
    return round(x, ndigits) if ndigits is not None else round(x)


analytics.round = checked_round  # modul-yerel 'round' yerlesik olani golgeler


def assert_no_count_ties(result):
    """symptom_frequency '-count' ile siralanir; esitlikte sira tanimsiz."""
    counts = [row["count"] for row in result["symptom_frequency"]]
    if len(counts) != len(set(counts)):
        named = [(r["symptom_name"], r["count"]) for r in result["symptom_frequency"]]
        AMBIGUOUS.append(f"count esitligi (sira belirsiz): {named}")


# ---------------------------------------------------------------- cikti
expected = {}
with mock.patch("django.utils.timezone.now", return_value=FROZEN_NOW):
    for days in PERIODS:
        sa = analytics.get_symptom_analytics(user, days)
        assert_no_count_ties(sa)
        expected[str(days)] = {
            "symptom_analytics": sa,
            "daily_trends": analytics.get_daily_trends(user, days),
            "medication_effect": analytics.get_medication_effect(user, days),
            "medication_adherence": analytics.get_medication_adherence(user, days),
        }

if AMBIGUOUS:
    raise SystemExit("Yarim kalan yuvarlama degerleri (veri setini degistir):\n  "
                     + "\n  ".join(sorted(set(AMBIGUOUS))))

dataset = {
    "meta": {
        "frozen_now": iso(FROZEN_NOW),
        "timezone": "Europe/Istanbul",
        "periods": PERIODS,
        "note": "Tum zamanlar UTC (Z). Kimlikler Python tarafindaki tam sayi kimlikleridir.",
    },
    "symptoms": [{"id": s.id, "name": s.name} for s in Symptom.objects.order_by("id")],
    "medications": [
        {"id": m.id, "name": m.name, "type": m.type, "is_global": m.is_global,
         "is_recurring": m.is_recurring,
         "recurring_time": m.recurring_time if isinstance(m.recurring_time, str)
         else (m.recurring_time.strftime("%H:%M") if m.recurring_time else None),
         "recurring_days": m.recurring_days}
        for m in Medication.objects.order_by("id")
        if m.is_global is False or m.id in {M_PAROL.id, M_ASPIRIN.id}
    ],
    "chronic_conditions": [
        {"id": c.id, "name": c.name,
         "medication_ids": sorted(c.medications.values_list("id", flat=True))}
        for c in ChronicCondition.objects.order_by("id")
    ],
    "episodes": [
        {"id": e.id, "symptom_id": e.symptom_id, "start_time": iso(e.start_time),
         "ended_at": iso(e.ended_at), "status": e.status}
        for e in Episode.objects.order_by("id")
    ],
    "symptom_entries": [
        {"id": s.id, "symptom_id": s.symptom_id, "episode_id": s.episode_id,
         "severity": s.severity, "timestamp": iso(s.timestamp), "location": s.location}
        for s in SymptomEntry.objects.order_by("id")
    ],
    "daily_logs": [
        {"id": d.id, "date": d.date.isoformat(), "sleep_hours": float(d.sleep_hours),
         "water_intake": float(d.water_intake), "mood": d.mood,
         "energy_level": d.energy_level}
        for d in DailyLog.objects.order_by("date")
    ],
    "medication_logs": [
        {"id": m.id, "medication_id": m.medication_id, "taken_at": iso(m.taken_at),
         "dose_amount": float(m.dose_amount) if m.dose_amount is not None else None,
         "dose_unit": m.dose_unit, "episode_id": m.episode_id,
         "condition_id": m.condition_id}
        for m in MedicationLog.objects.order_by("id")
    ],
}

OUT_DIR.mkdir(parents=True, exist_ok=True)


def dump(name, obj):
    path = OUT_DIR / name
    text = json.dumps(obj, ensure_ascii=False, indent=2,
                      default=lambda o: float(o) if isinstance(o, Decimal) else str(o))
    path.write_text(text + "\n", encoding="utf-8")
    print("yazildi:", path.relative_to(ROOT))


dump("dataset.json", dataset)
dump("expected_analytics.json", expected)
