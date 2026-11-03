"""Yeni kurallarla beklenen analitik çıktısı (Sprint 2 düzeltmeleri).

`generate_golden.py` eski Django kodunu çalıştırır ve eski davranışı kaydeder
(`expected_analytics.json`; dokunulmaz). Bu betik aynı örnek veriyi
(`dataset.json`) okur ve DÜZELTİLMİŞ kuralları Django'dan bağımsız, sıfırdan
uygular. Dart servisi bu çıktıyla karşılaştırılır; iki ayrı dilde yazılmış iki
ayrı hesap aynı sonucu veriyorsa Dart'a güvenilir.

Yeni kurallar (bkz. mobile/test/golden/FARKLAR.md):
  T1  Günler kaydın kendi UTC farkıyla yerel güne göre gruplanır.
  T2  0 geçerli bir değerdir; boş yalnız hiç kayıt yoksa.
  T3  Geçersiz gün adı yeni kayıtta olamaz; veride bulunursa yok sayılır, kalan
      boşsa ilaç her gün beklenir.
  T4  Uyum yalnız programlı günler üzerinden; programdışı günler "extra_days".
  T5  Pencere = bugün dahil son N yerel gün (gün başından).
  T6  Rahatlama = dozdan sonraki 2 saatte şiddetin, dozdan önceki ortalamanın
      altına ilk indiği kayıt.

Çalıştırma (depo kökünden):
    python -I scripts/golden/generate_golden_v2.py
"""

import json
import math
from datetime import datetime, timedelta
from pathlib import Path

GOLDEN = Path(__file__).resolve().parents[2] / "mobile" / "test" / "golden"
OFFSET = timedelta(hours=3)  # Europe/Istanbul, yıl boyu UTC+3
WINDOW = timedelta(hours=2)
WEEKDAYS = {
    "monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3,
    "friday": 4, "saturday": 5, "sunday": 6,
}


class AmbiguousRounding(Exception):
    """Yarıma çok yakın ama tam yarım olmayan değer: kayan nokta farkı
    dillere göre farklı yuvarlayabilir; veriyi değiştir."""


def parse(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def local_day(dt):
    return (dt + OFFSET).date()


# Yuvarlama kuralı (Dart ile aynı): yarım değer YUKARI yuvarlanır. Eski Python
# çift sayıya yuvarlıyordu; yeni kural iki tarafta da açıkça bu.
def _half_up(y):
    frac = y - math.floor(y)
    if 0 < abs(frac - 0.5) < 1e-9:
        raise AmbiguousRounding(f"{y}")
    return math.floor(y + 0.5)


def round1(x):
    return _half_up(x * 10) / 10


def round_int(x):
    return _half_up(x)


def mean(values):
    return sum(values) / len(values)


def symptom_analytics(d, days, start):
    names = {s["id"]: s["name"] for s in d["symptoms"]}
    entries = [e for e in d["symptom_entries"] if local_day(parse(e["timestamp"])) >= start]

    by_symptom = {}
    for e in entries:
        by_symptom.setdefault(names[e["symptom_id"]], []).append(e["severity"])
    frequency = sorted(
        (
            {"symptom_name": n, "count": len(v), "avg_severity": round1(mean(v))}
            for n, v in by_symptom.items()
        ),
        key=lambda x: (-x["count"], x["symptom_name"]),
    )

    by_day = {}
    for e in entries:
        by_day.setdefault(local_day(parse(e["timestamp"])).isoformat(), []).append(e["severity"])
    trend = [{"date": k, "avg_severity": round1(mean(v))} for k, v in sorted(by_day.items())]

    return {"period_days": days, "symptom_frequency": frequency, "severity_trend": trend}


def daily_trends(d, days, start):
    logs = sorted(
        (l for l in d["daily_logs"] if l["date"] >= start.isoformat()),
        key=lambda l: l["date"],
    )
    trends = [
        {
            "date": l["date"],
            "sleep_hours": float(l["sleep_hours"]),
            "water_intake": float(l["water_intake"]),
            "mood": l["mood"],
            "energy_level": l["energy_level"],
        }
        for l in logs
    ]

    def avg(key):
        return round1(mean([float(l[key]) for l in logs])) if logs else None

    return {
        "period_days": days,
        "trends": trends,
        "averages": {
            "sleep_hours": avg("sleep_hours"),
            "water_intake": avg("water_intake"),
            "mood": avg("mood"),
            "energy_level": avg("energy_level"),
        },
    }


def medication_effect(d, days, start):
    med_names = {m["id"]: m["name"] for m in d["medications"]}
    logs = [
        l for l in d["medication_logs"]
        if l["episode_id"] is not None and local_day(parse(l["taken_at"])) >= start
    ]
    logs.sort(key=lambda l: parse(l["taken_at"]), reverse=True)

    acc = {}
    for l in logs:
        taken = parse(l["taken_at"])
        in_ep = [e for e in d["symptom_entries"] if e["episode_id"] == l["episode_id"]]
        before = [e for e in in_ep if taken - WINDOW <= parse(e["timestamp"]) <= taken]
        after = sorted(
            (e for e in in_ep if taken < parse(e["timestamp"]) <= taken + WINDOW),
            key=lambda e: parse(e["timestamp"]),
        )
        if not before or not after:
            continue

        before_avg = mean([e["severity"] for e in before])
        after_avg = mean([e["severity"] for e in after])
        relief = None
        for e in after:
            if e["severity"] < before_avg:
                relief = int((parse(e["timestamp"]) - taken).total_seconds() / 60)
                break

        a = acc.setdefault(
            med_names[l["medication_id"]],
            {"usage": 0, "before": [], "after": [], "relief": []},
        )
        a["usage"] += 1
        a["before"].append(before_avg)
        a["after"].append(after_avg)
        if relief is not None:
            a["relief"].append(relief)

    effects = [
        {
            "medication_name": name,
            "usage_count": a["usage"],
            "avg_severity_before": round1(mean(a["before"])),
            "avg_severity_after": round1(mean(a["after"])),
            "avg_relief_minutes": round_int(mean(a["relief"])) if a["relief"] else None,
        }
        for name, a in acc.items()
    ]
    return {"period_days": days, "effects": effects}


def medication_adherence(d, days, start, today):
    recurring = sorted((m for m in d["medications"] if m["is_recurring"]), key=lambda m: m["name"])

    all_days = []
    cur = start
    while cur <= today:
        all_days.append(cur)
        cur += timedelta(days=1)

    result = []
    for m in recurring:
        allowed = {WEEKDAYS[x] for x in (m["recurring_days"] or []) if x in WEEKDAYS}

        def scheduled(day, allowed=allowed):
            return not allowed or day.weekday() in allowed

        expected = sum(1 for day in all_days if scheduled(day))
        if expected == 0:
            continue

        taken_days = {
            local_day(parse(l["taken_at"]))
            for l in d["medication_logs"]
            if l["medication_id"] == m["id"] and start <= local_day(parse(l["taken_at"])) <= today
        }
        on_schedule = sum(1 for day in taken_days if scheduled(day))
        result.append({
            "medication_name": m["name"],
            "expected_days": expected,
            "taken_days": on_schedule,
            "extra_days": len(taken_days) - on_schedule,
            "missed_days": expected - on_schedule,
            "adherence_rate": round1(on_schedule / expected * 100),
        })
    return {"period_days": days, "adherence": result}


def main():
    d = json.loads((GOLDEN / "dataset.json").read_text(encoding="utf-8"))
    today = local_day(parse(d["meta"]["frozen_now"]))

    out = {}
    for days in d["meta"]["periods"]:
        start = today - timedelta(days=days - 1)
        out[str(days)] = {
            "symptom_analytics": symptom_analytics(d, days, start),
            "daily_trends": daily_trends(d, days, start),
            "medication_effect": medication_effect(d, days, start),
            "medication_adherence": medication_adherence(d, days, start, today),
        }

    path = GOLDEN / "expected_analytics_v2.json"
    path.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"yazıldı: {path}")


if __name__ == "__main__":
    main()
