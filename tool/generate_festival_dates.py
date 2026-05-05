#!/usr/bin/env python3
"""
Fill ``years`` on ethnic_festivals.json + religious_festivals.json for 2026–2035.

Only updates each festival's ``years`` object; all other JSON fields are preserved.

Dependencies: see tool/requirements-festival-dates.txt (use project .venv_dates).

Method notes (see script comments and REPORT printed by main()):
- Tibetan (Phugpa): caltib day_info; calendar_date M-D → Tibetan month + tithi day.
- Islamic: hijri_converter.Hijri → Gregorian (tabular/Umm al-Qura style in library).
- Lunar: zhdate with leap-month attempts.
- Dai 关门/开门: Thai Buddhist Lent proxies — Khao Phansa ≈ day after Asalha-region full moon
  (with known exceptions); Ok Phansa ≈ first October astronomical full moon (aligned to Thai civil practice).
- Yi New Year (yi_year_yi):凉山近年多在11月20日前后放假；缺少远期公文时用固定11-20占位（不确定性高于火把节）。
"""

from __future__ import annotations

import argparse
import json
import warnings
from datetime import date, timedelta
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple

warnings.filterwarnings("ignore", category=UserWarning, module="caltib")

ROOT = Path(__file__).resolve().parents[1]
ETHNIC_PATH = ROOT / "assets/data/ethnic_festivals.json"
RELIGIOUS_PATH = ROOT / "assets/data/religious_festivals.json"

YEARS = list(range(2026, 2036))


def _fmt(d: date) -> str:
    return d.isoformat()


def _split_md(s: str) -> Optional[Tuple[int, int]]:
    s = (s or "").strip()
    if not s or "-" not in s:
        return None
    try:
        a, b = s.split("-", 1)
        return int(a), int(b)
    except ValueError:
        return None


# --- Ephem full moons (local) ---
def _full_moons_gyear(g_year: int) -> List[date]:
    import ephem

    out: List[date] = []
    cur = ephem.Date(date(g_year, 1, 1))
    end = ephem.Date(date(g_year, 12, 31))
    while cur < end:
        n = ephem.next_full_moon(cur)
        d = ephem.localtime(n).date()
        if d.year == g_year:
            out.append(d)
        cur = n + 0.1
    return sorted(out)


def _khao_phansa(g_year: int) -> Optional[date]:
    """Thai Buddhist Lent start (proxy for 傣/德昂关门节)."""
    # Known civil-calendar outliers vs plain «July FM + 1»
    special = {
        2028: date(2028, 10, 3),
    }
    if g_year in special:
        return special[g_year]

    moons = _full_moons_gyear(g_year)
    # Asalha Buchā region: full moon in late Jun–Jul–early Aug
    window = [
        d
        for d in moons
        if (d.month == 6 and d.day >= 8)
        or d.month == 7
        or (d.month == 8 and d.day <= 15)
    ]
    if not window:
        # Rare layout: defer to late Sep/Oct per Thai lunar drift
        fall = [d for d in moons if d.month in (9, 10) and d.day >= 15]
        if fall:
            return fall[0] + timedelta(days=1)
        return None

    jfm = [d for d in window if d.month == 7]
    pick = jfm[0] if jfm else window[0]
    return pick + timedelta(days=1)


def _ok_phansa(g_year: int) -> Optional[date]:
    """End of Buddhist Lent (proxy for 开门节): first full moon in October (Thailand-style)."""
    moons = _full_moons_gyear(g_year)
    oct_m = [d for d in moons if d.month == 10]
    if oct_m:
        return oct_m[0]
    nov_m = [d for d in moons if d.month == 11]
    return nov_m[0] if nov_m else None


def _songkran_peak(g_year: int) -> date:
    """Representative splash / 傣历新年主活动日（中泰走廊近似）。"""
    # Yunnan 1388 傣历新年狂欢日常见报端为 4-15（2026）；其余年以泰国宋干首日 4-13 为主参照。
    if g_year == 2026:
        return date(2026, 4, 15)
    return date(g_year, 4, 13)


def _western_easter(g_year: int) -> date:
    """Anonymous Gregorian Easter (Western)."""
    a = g_year % 19
    b = g_year // 100
    c = g_year % 100
    d = b // 4
    e = b % 4
    f = (b + 8) // 25
    g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30
    i = c // 4
    k = c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    month = (h + l - 7 * m + 114) // 31
    day = ((h + l - 7 * m + 114) % 31) + 1
    return date(g_year, month, day)


def _lunar_md_in_gyear(g_year: int, lunar_month: int, lunar_day: int) -> Optional[date]:
    from zhdate import ZhDate

    for ly in range(g_year - 1, g_year + 2):
        for leap in (False, True):
            try:
                z = ZhDate(ly, lunar_month, lunar_day, leap_month=leap)
                dt = z.to_datetime()
                if dt.year == g_year:
                    return dt.date()
            except Exception:
                pass
    return None


def _hijri_md_in_gyear(g_year: int, h_month: int, h_day: int) -> Optional[date]:
    from hijri_converter import Hijri

    hy0 = int((g_year - 622) * 33 / 32)
    for hy in range(hy0 - 3, hy0 + 4):
        try:
            g = Hijri(hy, h_month, h_day).to_gregorian()
            dd = date(g.year, g.month, g.day)
            if dd.year == g_year:
                return dd
        except ValueError:
            continue
    return None


def _tibetan_md_in_gyear(g_year: int, t_month: int, t_tithi: int) -> Optional[date]:
    import caltib

    hits: List[Tuple[date, bool]] = []
    d = date(g_year, 1, 1)
    end = date(g_year, 12, 31)
    while d <= end:
        try:
            info = caltib.day_info(d, engine="phugpa")
            td = info.tibetan
            if td.month == t_month and td.tithi == t_tithi:
                hits.append((d, td.is_leap_month))
        except Exception:
            pass
        d += timedelta(days=1)
    if hits:
        hits.sort(key=lambda x: (x[1], x[0]))
        return hits[0][0]

    # Phugpa months sometimes omit a tithi: fall back to nearest tithi index in the same Tibetan month.
    near: List[Tuple[int, bool, date]] = []
    d = date(g_year, 1, 1)
    while d <= end:
        try:
            info = caltib.day_info(d, engine="phugpa")
            td = info.tibetan
            if td.month == t_month:
                near.append((abs(td.tithi - t_tithi), td.is_leap_month, d))
        except Exception:
            pass
        d += timedelta(days=1)
    if not near:
        return None
    near.sort(key=lambda x: (x[0], x[1], x[2]))
    return near[0][2]


def _fixed_md_in_gyear(g_year: int, month: int, day: int) -> date:
    return date(g_year, month, day)


def _effective_strategy_and_calendar(
    fest: Dict[str, Any],
) -> Tuple[str, str, str]:
    """Returns (strategy, calendar_type, calendar_date) after unknown downgrade."""
    strategy = str(fest.get("date_strategy") or "")
    ct = str(fest.get("calendar_type") or "")
    cd = str(fest.get("calendar_date") or "")
    fid = str(fest.get("id") or "")

    # ID overrides (do not change JSON metadata; only affect computation).
    if fid == "yi_tiger_leap":
        return "skip", "", ""
    if fid == "yi_huoba":
        return "lunar_convert", "lunar", "6-24"
    if fid == "yi_flower_day":
        return "lunar_convert", "lunar", "3-8"
    if fid == "yi_year_yi":
        return "yi_year_fixed", "yi", cd
    if fid in ("jingr_ha",):
        return "lunar_convert", "lunar", "8-10"
    if fid in ("jingr_changha",):
        return "lunar_convert", "lunar", "8-15"
    if fid == "tuzu_huaer":
        return "lunar_convert", "lunar", "6-6"

    if strategy == "unknown":
        if ct == "lunar" and cd:
            return "lunar_convert", ct, cd
        if ct == "gregorian" and cd:
            return "fixed", ct, cd
        if ct == "tibetan" and cd:
            return "algorithm", ct, cd
        if ct == "islamic" and cd:
            return "algorithm", ct, cd
        if ct == "dai":
            return "lookup", ct, cd
        if ct == "yi" and cd:
            return "yi_approx_lunar", "yi", cd

    return strategy, ct, cd


def _build_years_for_festival(fest: Dict[str, Any]) -> Dict[str, str]:
    strategy, ct, cd = _effective_strategy_and_calendar(fest)
    fid = str(fest.get("id") or "")
    out: Dict[str, str] = {}

    if strategy == "skip":
        return {}

    md = _split_md(cd)

    gen: Optional[Callable[[int], Optional[date]]] = None

    if strategy == "fixed":
        if fid == "christianity_easter":
            gen = _western_easter
        elif fid == "christianity_good_friday":
            gen = lambda y: _western_easter(y) - timedelta(days=2)
        elif md:
            mm, dd = md
            gen = lambda y, mm=mm, dd=dd: _fixed_md_in_gyear(y, mm, dd)
        else:
            gen = None

    elif strategy == "lunar_convert":
        if md:

            def _lc(y: int, lm: int = md[0], ld: int = md[1]) -> Optional[date]:
                return _lunar_md_in_gyear(y, lm, ld)

            gen = _lc

    elif strategy == "algorithm":
        if ct == "islamic" and md:

            def _hi(y: int, hm: int = md[0], hd: int = md[1]) -> Optional[date]:
                return _hijri_md_in_gyear(y, hm, hd)

            gen = _hi
        elif ct == "tibetan" and md:

            def _tb(y: int, tm: int = md[0], tt: int = md[1]) -> Optional[date]:
                return _tibetan_md_in_gyear(y, tm, tt)

            gen = _tb

    elif strategy == "lookup":
        if fid in ("dai_water_splashing", "dea_water"):
            gen = _songkran_peak
        elif fid == "dai_closing_door":
            gen = _khao_phansa
        elif fid in ("dai_opening_door", "dea_open_gate"):
            gen = _ok_phansa
        else:
            gen = None

    elif strategy == "yi_year_fixed":
        # Administrative proxy — far years lack published Liangshan notices.
        gen = lambda y: date(y, 11, 20)

    elif strategy == "yi_approx_lunar":
        # e.g. yi tiger leap calendar yi 2-8 → try lunar 2-8 as ethnographic fallback
        if md:

            def _ya(y: int, lm: int = md[0], ld: int = md[1]) -> Optional[date]:
                return _lunar_md_in_gyear(y, lm, ld)

            gen = _ya

    if gen is not None:
        for y in YEARS:
            try:
                d = gen(y)
            except Exception:
                d = None
            if d is not None:
                out[str(y)] = _fmt(d)

    # Lunar placeholders for lookup festivals without published calendars (2026–2028 only).
    lookup_lunar_extra = {
        "mul_yifan": (11, 1),
        "shui_duan": (9, 1),
        "shui_mao": (6, 1),
        "tuzu_nadun": (7, 1),
    }
    if fid in lookup_lunar_extra:
        lm, ld = lookup_lunar_extra[fid]
        for y in (2026, 2027, 2028):
            if str(y) not in out:
                d = _lunar_md_in_gyear(y, lm, ld)
                if d is not None:
                    out[str(y)] = _fmt(d)

    return out


def _patch_doc(path: Path) -> Tuple[int, int, int]:
    """Returns (full_count, partial_count, empty_count)."""
    text = path.read_text(encoding="utf-8")
    doc = json.loads(text)
    fests = doc.get("festivals")
    if not isinstance(fests, list):
        return (0, 0, 0)

    full = partial = empty = 0
    for fest in fests:
        if not isinstance(fest, dict):
            continue
        new_years = _build_years_for_festival(fest)
        fest["years"] = new_years
        n = len(new_years)
        if n == 0:
            empty += 1
        elif n == len(YEARS):
            full += 1
        else:
            partial += 1

    path.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")
    return full, partial, empty


def main() -> None:
    ap = argparse.ArgumentParser(description="Fill festival years 2026–2035.")
    ap.add_argument("--dry-run", action="store_true", help="Statistics only; no file writes.")
    args = ap.parse_args()

    if args.dry_run:
        eth = json.loads(ETHNIC_PATH.read_text(encoding="utf-8"))
        rel = json.loads(RELIGIOUS_PATH.read_text(encoding="utf-8"))
        full = partial = empty = 0
        for fest in eth.get("festivals", []) + rel.get("festivals", []):
            if not isinstance(fest, dict):
                continue
            n = len(_build_years_for_festival(fest))
            if n == 0:
                empty += 1
            elif n == len(YEARS):
                full += 1
            else:
                partial += 1
        print("DRY RUN ethnic+religious:", "full", full, "partial", partial, "empty", empty)
        return

    ef, ep, ee = _patch_doc(ETHNIC_PATH)
    rf, rp, re_ = _patch_doc(RELIGIOUS_PATH)
    total_full = ef + rf
    total_partial = ep + rp
    total_empty = ee + re_
    print("Ethnic:", ETHNIC_PATH, "full", ef, "partial", ep, "empty", ee)
    print("Religious:", RELIGIOUS_PATH, "full", rf, "partial", rp, "empty", re_)
    print("TOTAL full", total_full, "partial", total_partial, "empty", total_empty)


if __name__ == "__main__":
    main()
