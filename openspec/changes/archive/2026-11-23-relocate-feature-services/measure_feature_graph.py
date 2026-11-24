#!/usr/bin/env python3
"""Measure direct and hidden feature-module reachability for Q-8.

Direct edges match scripts/quality_gates.sh feature_edges (package imports only).
Hidden paths treat hand-written files under lib/src/{ui,services,utils}/ as
intermediate nodes (package + relative imports).

Usage (repo root):
  python3 openspec/changes/relocate-feature-services/measure_feature_graph.py
"""

from __future__ import annotations

import collections
import re
import sys
from pathlib import Path

PKG_FEAT = re.compile(r"package:kafkalyzer/src/features/([A-Za-z0-9_]+)/")
IMPORT_LINE = re.compile(r"""^(?:import|export)\s+['"]([^'"]+)['"]""", re.M)
SHARED_PREFIXES = ("lib/src/ui/", "lib/src/services/", "lib/src/utils/")


def is_generated(path: str) -> bool:
    name = Path(path).name
    return (
        name.endswith((".g.dart", ".freezed.dart", ".mocks.dart"))
        or path == "lib/src/flex_theme_bridge.dart"
    )


def list_dart(root: str) -> list[str]:
    base = Path(root)
    if not base.exists():
        return []
    return [
        str(p)
        for p in sorted(base.rglob("*.dart"))
        if not is_generated(str(p))
    ]


def resolve_target(src: str, target: str) -> str | None:
    if target.startswith("package:kafkalyzer/src/"):
        return "lib/src/" + target[len("package:kafkalyzer/src/") :]
    if target.startswith("package:") or target.startswith("dart:"):
        return None
    try:
        return str(
            (Path(src).parent / target)
            .resolve()
            .relative_to(Path(".").resolve())
        )
    except Exception:
        return None


def is_feature(path: str) -> bool:
    return path.startswith("lib/src/features/")


def is_shared(path: str) -> bool:
    return any(path.startswith(p) for p in SHARED_PREFIXES)


def feat_name(path: str) -> str:
    return path.split("/")[3]


def warshall(edge_list: list[tuple[str, str]]) -> list[tuple[str, str]]:
    mods = sorted({a for a, b in edge_list} | {b for a, b in edge_list})
    e = set(edge_list)
    r = {(a, b): (a == b or (a, b) in e) for a in mods for b in mods}
    for k in mods:
        for i in mods:
            for j in mods:
                if r[(i, k)] and r[(k, j)]:
                    r[(i, j)] = True
    return sorted(
        (a, b)
        for a in mods
        for b in mods
        if a < b and r[(a, b)] and r[(b, a)]
    )


def build_edges() -> tuple[list[tuple[str, str, str]], list[tuple[str, str]]]:
    """Return (direct_rows as from,to,file), (all_graph_edges as node,node)."""
    feat_files = list_dart("lib/src/features")
    shared_files = (
        list_dart("lib/src/ui")
        + list_dart("lib/src/services")
        + list_dart("lib/src/utils")
    )

    direct_rows: list[tuple[str, str, str]] = []
    graph: list[tuple[str, str]] = []

    for f in feat_files:
        frm = feat_name(f)
        text = Path(f).read_text(encoding="utf-8")
        for m in PKG_FEAT.finditer(text):
            to = m.group(1)
            if to != frm:
                direct_rows.append((frm, to, f))
                graph.append((f"F:{frm}", f"F:{to}"))
        for m in IMPORT_LINE.finditer(text):
            target = resolve_target(f, m.group(1))
            if target and is_shared(target):
                graph.append((f"F:{frm}", f"S:{target}"))

    for f in shared_files:
        text = Path(f).read_text(encoding="utf-8")
        for m in IMPORT_LINE.finditer(text):
            target = resolve_target(f, m.group(1))
            if not target:
                continue
            if is_feature(target):
                graph.append((f"S:{f}", f"F:{feat_name(target)}"))
            elif is_shared(target):
                graph.append((f"S:{f}", f"S:{target}"))

    return direct_rows, graph


def shared_to_feature() -> dict[str, set[str]]:
    out: dict[str, set[str]] = {}
    for f in (
        list_dart("lib/src/ui")
        + list_dart("lib/src/services")
        + list_dart("lib/src/utils")
    ):
        feats: set[str] = set()
        text = Path(f).read_text(encoding="utf-8")
        for m in IMPORT_LINE.finditer(text):
            target = resolve_target(f, m.group(1))
            if target and is_feature(target):
                feats.add(feat_name(target))
        if feats:
            out[f] = feats
    return out


def main() -> int:
    direct_rows, graph = build_edges()
    pair_counts = collections.Counter((a, b) for a, b, _ in direct_rows)
    print("=== DIRECT (package only) ===")
    for (a, b), c in sorted(pair_counts.items()):
        print(f"{a} → {b} {c}")
    print(f"TOTAL EDGE ROWS: {len(direct_rows)}")
    print(f"ONE-DIRECTIONAL PAIRS: {len(pair_counts)}")
    direct_mutual = warshall([(a, b) for a, b, _ in direct_rows])
    print(f"DIRECT MUTUAL PAIRS: {direct_mutual or 'none'}")

    print("\n=== SHARED → FEATURE ===")
    s2f = shared_to_feature()
    for path, feats in sorted(s2f.items()):
        print(f"{path}: {sorted(feats)}")
    print(f"count: {len(s2f)}")

    # Full-graph feature mutual pairs
    mods = sorted({a for a, b in graph} | {b for a, b in graph})
    e = set(graph)
    r = {(a, b): (a == b or (a, b) in e) for a in mods for b in mods}
    for k in mods:
        for i in mods:
            for j in mods:
                if r[(i, k)] and r[(k, j)]:
                    r[(i, j)] = True
    feats = sorted({m[2:] for m in mods if m.startswith("F:")})
    full_mutual = [
        (a, b)
        for a in feats
        for b in feats
        if a < b
        and r.get((f"F:{a}", f"F:{b}"))
        and r.get((f"F:{b}", f"F:{a}"))
    ]
    print("\n=== FULL GRAPH MUTUAL FEATURE PAIRS ===")
    for a, b in full_mutual:
        print(f"{a} ↔ {b}")
    print(f"count: {len(full_mutual)}")

    # New one-hop hidden
    adj: dict[str, set[str]] = collections.defaultdict(set)
    for a, b in graph:
        adj[a].add(b)
    direct_set = {(a, b) for a, b, _ in direct_rows}
    print("\n=== NEW ONE-HOP HIDDEN (F→S→F, not already direct) ===")
    hidden = []
    for a in feats:
        for s in adj[f"F:{a}"]:
            if not s.startswith("S:"):
                continue
            for t in adj[s]:
                if t.startswith("F:") and t[2:] != a:
                    if (a, t[2:]) not in direct_set:
                        hidden.append((a, t[2:], s[2:]))
    for a, b, via in sorted(set(hidden)):
        print(f"{a} → {b} via {via}")
    print(f"count: {len(set(hidden))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
