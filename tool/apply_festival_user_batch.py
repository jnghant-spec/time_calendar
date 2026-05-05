#!/usr/bin/env python3
"""Apply user-confirmed festival categories (metadata only); then run generate_festival_dates.py."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# F 类：完全不改动（不增删字段）
F_IDS = frozenset(
    {
        "hani_zhalet",
        "jingp_munao",
        "taoism_sanqing",
        "christianity_epiphany",
    }
)

# A：农历 + lunar_convert，calendar_date 为用户指定
A_CALENDAR = {
    "gela_chixin": "7-1",
    "gela_mountgod": "3-1",
    "wa_new_rice_wa": "8-1",
    "lisu_hot_spring": "1-3",
    "lisu_knife_ladder": "2-8",
    "hani_angmatu": "1-1",
    "hani_kuzazha": "6-24",
    "tuzu_leitai": "2-2",
    "jino_new_rice_jino": "9-1",
    "blang_hounan": "3-1",
    "blang_shankang": "6-1",
    "dea_flower_water": "3-1",
    "nu_fairy": "3-15",
    "nu_forest": "3-1",
    "lahu_hulu": "10-15",
    "lahu_kuota": "1-1",
    "pumi_wuxi": "1-1",
    "pumi_zhuanshan": "7-15",
    "qiang_mount": "3-1",
    "qiang_rmai": "10-1",
    "yug_fire_offer": "1-1",
    "yug_horse_mane": "4-1",
    "yug_ovoo": "6-1",
    "hez_river_lamp": "7-15",
    "hez_wurig": "5-15",
    "daw_kumle": "5-1",
    "elc_bonfire": "6-18",
    "ewk_mikulu": "5-1",
    "ewk_sebin": "6-18",
    "ach_aluwo": "3-20",
    "ach_huijie": "9-15",
    "li_shanlan": "3-1",
    "jingp_newrice": "8-1",
    "menggu_mare_milk": "8-1",
}

B_CALENDAR = {
    "wa_monihei": "5-1",
    "wa_wood_drum": "4-1",
    "lisu_kuoshi": "12-20",
    "jino_techmark": "2-6",
}

C_IDS = frozenset({"mul_yifan", "tuzu_nadun", "shui_duan", "shui_mao"})
C_NOTE_FRAG = "2029-2035 年为近似推算（农历对照占位）；具体日以地方历书或政府公告为准。"

D_ETHNIC = frozenset(
    {
        "yi_tiger_leap",
        "chaoxian_huijia",
        "gaoshan_harvest",
        "gaoshan_sowing",
        "dulo_kachewa",
        "dulo_sky_offer",
        "luob_dongen",
        "luob_xudulong",
        "tata_saban",
    }
)
D_RELIGIOUS = frozenset({"hinduism_diwali", "hinduism_holi"})

E_IDS = frozenset({"christianity_thanksgiving_x"})


def _merge_note(existing: str, fragment: str) -> str:
    t = (existing or "").strip()
    if fragment in t:
        return t
    if not t:
        return fragment
    return t + " " + fragment


def _apply_defaults(f: dict) -> None:
    fid = f.get("id")
    if fid in F_IDS:
        return
    f.setdefault("available", True)
    f.setdefault("display_mode", "calendar")
    f.setdefault("source_references", [])


def patch_festival(f: dict) -> None:
    fid = f.get("id")
    if not fid or fid in F_IDS:
        return

    if fid in A_CALENDAR:
        f["calendar_type"] = "lunar"
        f["date_strategy"] = "lunar_convert"
        f["calendar_date"] = A_CALENDAR[fid]
        f["available"] = True
        f["display_mode"] = "calendar"
        f.setdefault("source_references", [])
        return

    if fid in B_CALENDAR:
        f["calendar_type"] = "gregorian"
        f["date_strategy"] = "fixed"
        f["calendar_date"] = B_CALENDAR[fid]
        f["available"] = True
        f["display_mode"] = "calendar"
        f.setdefault("source_references", [])
        return

    if fid in C_IDS:
        f["date_strategy"] = "lookup"
        # calendar_date 保持 JSON 原有水历/土族占位数字，由生成脚本按农历补足十年
        f["available"] = True
        f["display_mode"] = "calendar"
        f.setdefault("source_references", [])
        f["note"] = _merge_note(str(f.get("note") or ""), C_NOTE_FRAG)
        return

    if fid in D_ETHNIC or fid in D_RELIGIOUS:
        f["available"] = False
        f["display_mode"] = "culture_only"
        f["years"] = {}
        f["confidence"] = "low"
        f.setdefault("source_references", [])
        return

    if fid in E_IDS:
        f["available"] = False
        f["display_mode"] = "hidden"
        f["years"] = {}
        f.setdefault("source_references", [])
        return

    if fid == "menb_new_year":
        f["calendar_type"] = "tibetan"
        f["date_strategy"] = "algorithm"
        f["calendar_date"] = "1-1"
        f["available"] = True
        f["display_mode"] = "calendar"
        f.setdefault("source_references", [])
        return


def main() -> None:
    eth_path = ROOT / "assets/data/ethnic_festivals.json"
    rel_path = ROOT / "assets/data/religious_festivals.json"

    eth_doc = json.loads(eth_path.read_text(encoding="utf-8"))
    rel_doc = json.loads(rel_path.read_text(encoding="utf-8"))

    for f in eth_doc.get("festivals", []):
        patch_festival(f)
    for f in rel_doc.get("festivals", []):
        patch_festival(f)

    for doc in (eth_doc, rel_doc):
        for f in doc.get("festivals", []):
            _apply_defaults(f)

    eth_path.write_text(json.dumps(eth_doc, ensure_ascii=False, indent=2), encoding="utf-8")
    rel_path.write_text(json.dumps(rel_doc, ensure_ascii=False, indent=2), encoding="utf-8")

    rc = subprocess.call([sys.executable, str(ROOT / "tool/generate_festival_dates.py")])
    raise SystemExit(rc)


if __name__ == "__main__":
    main()
