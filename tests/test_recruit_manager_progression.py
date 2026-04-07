#!/usr/bin/env python3
"""
Lightweight regression checks for RecruitManager progression graph generation.

This test intentionally avoids requiring a running Godot runtime so it can be
executed in basic CI environments as a static guard.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RECRUIT_MANAGER = ROOT / "systems/combat/recruit_manager.gd"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_human_chain_order_is_tiered() -> None:
    text = _read(RECRUIT_MANAGER)
    assert '"human_ashigaru": "human_cavalry"' in text
    assert '"human_cavalry": "human_samurai"' in text
    assert '"human_ashigaru": "human_samurai"' not in text


def test_deterministic_upgrade_graph_build_order() -> None:
    text = _read(RECRUIT_MANAGER)
    assert "legacy_from_ids.sort()" in text
    assert "troop_ids.sort()" in text


def test_game_data_not_ready_retry_guard_exists() -> None:
    text = _read(RECRUIT_MANAGER)
    assert "_upgrade_rebuild_retry_left" in text
    assert 'call_deferred("_rebuild_upgrade_rules_from_game_data")' in text


def test_no_external_upgrade_json_dependency() -> None:
    text = _read(RECRUIT_MANAGER)
    assert "troop_upgrade_rules.json" not in text
    assert "TROOP_UPGRADE_RULES_PATH" not in text
    assert "_load_troop_upgrade_rules" not in text


if __name__ == "__main__":
    # Minimal direct-run support (without pytest).
    funcs = [v for k, v in globals().items() if re.match(r"^test_", k) and callable(v)]
    for fn in funcs:
        fn()
    print(f"ok - {len(funcs)} recruit_manager progression checks passed")
