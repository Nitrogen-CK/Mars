"""Read-only verification for the approved Warrens C art revision receipts.

Run with the repository Python interpreter from any working directory. This
script reads map/package hashes and receipts, and runs the existing pure
manifest builder for the unchanged B/D comparison. It never imports Unreal,
opens the editor, or writes project files.
"""
from __future__ import annotations

import hashlib
import importlib
import ast
import json
import runpy
import sys
from types import SimpleNamespace
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
RUN = ROOT / "Saved/WarrensCGameplay-20261024"
REVIEW = ROOT / "docs/art/warrens-c-gameplay-review-20261024"
ART = RUN / "ArtCheckpoint"
P2 = RUN / "P2ReadabilityCheckpoint"
WHEEL = RUN / "WheelArtCheckpoint"
CANONICAL_PARITY = WHEEL / "CanonicalParity/P2_WHEEL_CANONICAL_PARITY.json"
CANONICAL_PARITY_BASELINE = WHEEL / "CanonicalParity/baseline_20261025T060119555621Z/baseline.json"
LIBRARY_SYNC = RUN / "ArtLibrarySyncCheckpoint/unreal-v2"
BLEND_PROMOTION = RUN / "ArtLibrarySyncCheckpoint/promoted-v3"
STAGE_TILES = ("Canal", "Brineworks", "WaterworksW")
LIBRARY_SYNC_SPEC_SHA256 = "0213afbcd88e10e84c4000736eaed5f4c95ab4f23a372ff887531cbed5e07f2e"
OMITTED_STATIC_KEYS = ("p2_fixture_wheel_cage", "p2_fixture_wheel_glass", "p2_fixture_wheel_flame")
EXPECTED_MATERIALS = {
    ("Mars_Bellkeeper_EntityScript", "BodyMaterialOverride"): "/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX10",
    ("Mars_Bellkeeper_EntityScript", "FaceMaterialOverride"): "/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor",
    ("Mars_Bellkeeper_EntityScript", "ControlMaterialOverride"): "/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX10",
    ("Mars_Bellkeeper_EntityScript", "GlyphMaterialOverride"): "/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor",
    ("Mars_Bellkeeper_EntityScript", "IndicatorMaterialOverride"): "/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor",
    ("Mars_BellkeeperClue_EntityScript", "BodyMaterialOverride"): "/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01",
    ("Mars_BellkeeperClue_EntityScript", "FaceMaterialOverride"): "/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor",
    ("Mars_BellkeeperClue_EntityScript", "GlyphMaterialOverride"): "/Game/Mars/Environment/WarrensVariantCKit/Materials/M_WVC_BellkeeperPrimaryColor",
}
ART_MAPS = {
    "Mill": "Content/Mars/Maps/Variants/v8c/LI_Warrens_Mill.umap",
    "Belfry": "Content/Mars/Maps/Variants/v8c/LI_Warrens_Belfry.umap",
    "Diorama": "Content/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_Diorama_Mars_MAP.umap",
    "KitLibrary": "Content/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_KitLibrary_Mars_MAP.umap",
}
BELFRY_RETENTION_SHA256 = "7ec77e1f6e686eaea0f7ecf480eb4121843a803248a763e5f962be60939a9492"
BELFRY_RETENTION_REVIEW_SHA256 = "b366a16dbffa8e357a7250b7d5b7b1f5f353dab19de055d7e2e74efcf51ae14c"
BELFRY_MAP_BEFORE = "0cf37a3328b85625962ea463c9866caedd17187d50e5ccc2d8bb52d6528bc909"
BELFRY_MAP_AFTER = "cbdcbc49774b21ff706b5883d39c9a8377ac2fc85c2ee7c9f49e65966fd32c21"
BELFRY_LIBRARY = RUN / "BelfryPaletteCheckpoint/blender-stone-v1"
BELFRY_DIORAMA = RUN / "BelfryDioramaPaletteCheckpoint/20261025_064517_485872_ea02622e"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def check(report: dict[str, Any], name: str, ok: bool, detail: Any) -> None:
    report["checks"].append({"name": name, "status": "PASS" if ok else "FAIL", "detail": detail})


def pending(report: dict[str, Any], name: str, detail: Any) -> None:
    report["checks"].append({"name": name, "status": "PENDING", "detail": detail})


def file_hash(path_text: str) -> tuple[str | None, str | None]:
    path = ROOT / path_text
    if not path.is_file():
        return None, f"missing file: {path_text}"
    return sha256(path), None


CANONICAL_WHEEL_FILES = (
    "Tools/LevelDesign/anchor_plans/design_warrens_v8c.py",
    "Tools/LevelDesign/anchor_plans/data/warrens_v8c.json",
    "Saved/AnchorPlans/v8c-manifest.json",
)
CANONICAL_WHEEL_FIELDS = {
    "WheelMeshOverride": {"asset": "/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS21_HandwheelBody_Mars_SM"},
    "WheelMeshLocalTransform": {"transform": {"location": [2.5, 0, 0], "rotation": [0, 90, 0]}},
    "WheelMaterialOverride": {"asset": "/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09"},
}
CANONICAL_WHEEL_PROPS = frozenset(CANONICAL_WHEEL_FIELDS)
CANONICAL_WHEEL_TARGET = {"cls": "Mars_SlidingBridge_EntityScript", "at": [79, 20, -2.2], "tile": "Canal"}
CANONICAL_WHEEL_MESH_SOURCE_HUNK_OLD = (
    b"                    MaterialOverride=dict(asset='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09')))),\r\n"
)
CANONICAL_WHEEL_MESH_SOURCE_HUNK_NEW = (
    b"                    MaterialOverride=dict(asset='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09'),\r\n"
    b"                    WheelMeshOverride=dict(asset='/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS21_HandwheelBody_Mars_SM'),\r\n"
    b"                    WheelMeshLocalTransform=dict(transform=dict(location=[2.5, 0, 0], rotation=[0, 90, 0])),\r\n"
    b"                    WheelMaterialOverride=dict(asset='/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX09')))),\r\n"
)
HISTORICAL_SECTION_AST_SHA256 = "db202505cfea04611e53448b13fefdba49cabdee0de6e8c1de0958f74a9212da"


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def canonical_sha(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def _section_overrides_ast_sha(source: str) -> str | None:
    try:
        tree = ast.parse(source)
        node = next(n for n in tree.body if isinstance(n, ast.Assign)
                    and any(isinstance(target, ast.Name) and target.id == "SECTION_OVERRIDES" for target in n.targets))
    except (SyntaxError, StopIteration):
        return None
    return hashlib.sha256(ast.dump(node.value, include_attributes=False).encode("utf-8")).hexdigest()


def _canonical_target_props(doc: dict[str, Any], kind: str) -> list[dict[str, Any]]:
    if kind == "data":
        rows = [row.get("entity", {}) for row in doc.get("sectionOverrides", [])
                if row.get("puzzleId") == "P2"]
    else:
        rows = [row for row in doc.get("entities", [])
                if row.get("cls") == CANONICAL_WHEEL_TARGET["cls"]
                and row.get("tile") == CANONICAL_WHEEL_TARGET["tile"]
                and row.get("at") == CANONICAL_WHEEL_TARGET["at"]]
    return rows


def _drop_canonical_wheel_props(doc: dict[str, Any], kind: str) -> tuple[dict[str, Any], int, bool]:
    projected = json.loads(json.dumps(doc))
    rows = _canonical_target_props(projected, kind)
    if len(rows) != 1:
        return projected, len(rows), False
    row = rows[0]
    if kind == "data":
        if row.get("cls") != CANONICAL_WHEEL_TARGET["cls"] or row.get("tile") != CANONICAL_WHEEL_TARGET["tile"] or row.get("at") != CANONICAL_WHEEL_TARGET["at"]:
            return projected, len(rows), False
        props = row.get("props", {})
    else:
        props = row.get("props", {})
    if not CANONICAL_WHEEL_PROPS.issubset(props):
        return projected, len(rows), False
    for key in CANONICAL_WHEEL_PROPS:
        props.pop(key, None)
    return projected, len(rows), True


def verify_p2_wheel_canonical_parity(report: dict[str, Any]) -> bool:
    """Check the wheel presentation delta from its exact pre-change backups."""
    if not CANONICAL_PARITY.is_file():
        pending(report, "P2 wheel canonical C plan parity receipt", {
            "expected_receipt": str(CANONICAL_PARITY.relative_to(ROOT)),
            "required_files": list(CANONICAL_WHEEL_FILES),
        })
        return False
    receipt = read_json(CANONICAL_PARITY)
    if not CANONICAL_PARITY_BASELINE.is_file():
        check(report, "P2 wheel canonical C plan parity receipt", False,
              {"error": f"missing immutable preflight: {CANONICAL_PARITY_BASELINE.relative_to(ROOT)}"})
        return False
    baseline = read_json(CANONICAL_PARITY_BASELINE)
    files = receipt.get("files", {})
    file_rows = {}
    for rel in CANONICAL_WHEEL_FILES:
        entry = files.get(rel, {})
        checkpoint_rel = entry.get("checkpoint", "").replace("\\", "/")
        checkpoint_path = ROOT / checkpoint_rel
        before = sha256(checkpoint_path) if checkpoint_path.is_file() else None
        actual, error = file_hash(rel)
        file_rows[rel] = {
            "checkpoint": checkpoint_rel,
            "before_receipt": entry.get("before_sha256"), "before_actual": before,
            "after_receipt": entry.get("after_sha256"), "after_actual": actual,
            "checkpoint_matches": before == entry.get("before_sha256"),
            "current_matches": actual == entry.get("after_sha256"), "error": error,
        }
    expected_checkpoint_map = {
        "Tools/LevelDesign/anchor_plans/design_warrens_v8c.py": "design_warrens_v8c.py",
        "Tools/LevelDesign/anchor_plans/data/warrens_v8c.json": "warrens_v8c.json",
        "Saved/AnchorPlans/v8c-manifest.json": "v8c-manifest.json",
    }
    snapshot_rows = {row["path"]: row for row in baseline.get("files", [])}
    source_history = read_json(RUN / "ArtPlan/SourceCheckpoint/SOURCE_HASHES.json")
    source_expected = {row["path"].replace("\\", "/"): row for row in source_history.get("files", [])}
    p4_update = read_json(RUN / "ArtPlan/CANONICAL_ART_UPDATE.json")
    p4_expected = {row["path"].replace("\\", "/"): row for row in p4_update.get("files", [])}
    baseline_chain_ok = True
    for rel, checkpoint_name in expected_checkpoint_map.items():
        entry = files.get(rel, {})
        snapshot = snapshot_rows.get(rel, {})
        receipt_checkpoint_name = Path(entry.get("checkpoint", "")).name
        baseline_chain_ok = baseline_chain_ok and receipt_checkpoint_name == checkpoint_name
        baseline_chain_ok = baseline_chain_ok and entry.get("checkpoint") == snapshot.get("checkpoint")
        baseline_chain_ok = baseline_chain_ok and entry.get("before_sha256") == snapshot.get("sha256") == snapshot.get("checkpoint_sha256")
        baseline_chain_ok = baseline_chain_ok and entry.get("before_mtime_utc") == snapshot.get("mtime_utc")
        if rel == CANONICAL_WHEEL_FILES[0]:
            baseline_chain_ok = baseline_chain_ok and entry.get("before_sha256") == source_expected.get(rel, {}).get("current_sha256")
        else:
            baseline_chain_ok = baseline_chain_ok and entry.get("before_sha256") == p4_expected.get(rel, {}).get("after_sha256")

    pre_source = (ROOT / files.get(CANONICAL_WHEEL_FILES[0], {}).get("checkpoint", "")).read_text(encoding="utf-8")
    current_source = (ROOT / CANONICAL_WHEEL_FILES[0]).read_text(encoding="utf-8")
    source_before_ast = _section_overrides_ast_sha(pre_source)
    source_after_ast = _section_overrides_ast_sha(current_source)
    old_source_bytes = (ROOT / files.get(CANONICAL_WHEEL_FILES[0], {}).get("checkpoint", "")).read_bytes()
    current_source_bytes = (ROOT / CANONICAL_WHEEL_FILES[0]).read_bytes()
    exact_hunk_count = old_source_bytes.count(CANONICAL_WHEEL_MESH_SOURCE_HUNK_OLD)
    exact_source_hunk = (exact_hunk_count == 1 and current_source_bytes == old_source_bytes.replace(
        CANONICAL_WHEEL_MESH_SOURCE_HUNK_OLD, CANONICAL_WHEEL_MESH_SOURCE_HUNK_NEW, 1))
    hunk = receipt.get("source_hunk", {})
    hunk_ok = (hunk.get("old_line_count") == 1 and hunk.get("added_lines") == [
        line.decode("utf-8").rstrip("\r\n") for line in CANONICAL_WHEEL_MESH_SOURCE_HUNK_NEW.splitlines(keepends=True)[1:]
    ] and hunk.get("sha256") == hashlib.sha256(CANONICAL_WHEEL_MESH_SOURCE_HUNK_NEW).hexdigest())
    section_ast_ok = (source_before_ast == HISTORICAL_SECTION_AST_SHA256
                      and source_before_ast == receipt.get("section_ast_before_sha256")
                      and source_after_ast == receipt.get("section_ast_after_sha256"))
    review_rel = "docs/art/warrens-c-gameplay-review-20261024/P2_WHEEL_STAGED_BINDING_REVIEW.md"
    review_sha, _ = file_hash(review_rel)
    review_text = (ROOT / review_rel).read_text(encoding="utf-8-sig")
    approval = receipt.get("approval", {})
    approval_ok = (approval.get("status") == "APPROVED"
                   and approval.get("review_source") == review_rel
                   and approval.get("review_source_sha256") == review_sha
                   and "Canonical C presentation-field parity and the narrowly scoped receipt-chain verifier update are approved." in review_text)

    old_data = read_json(ROOT / files.get(CANONICAL_WHEEL_FILES[1], {}).get("checkpoint", ""))
    new_data = read_json(ROOT / CANONICAL_WHEEL_FILES[1])
    old_manifest = read_json(ROOT / files.get(CANONICAL_WHEEL_FILES[2], {}).get("checkpoint", ""))
    new_manifest = read_json(ROOT / CANONICAL_WHEEL_FILES[2])
    data_projection, data_target_count, data_projection_valid = _drop_canonical_wheel_props(new_data, "data")
    manifest_projection, manifest_target_count, manifest_projection_valid = _drop_canonical_wheel_props(new_manifest, "manifest")
    data_delta_ok = data_projection_valid and data_projection == old_data
    manifest_delta_ok = manifest_projection_valid and manifest_projection == old_manifest
    data_targets = _canonical_target_props(new_data, "data")
    manifest_targets = _canonical_target_props(new_manifest, "manifest")
    data_props = data_targets[0].get("props", {}) if len(data_targets) == 1 else {}
    manifest_props = manifest_targets[0].get("props", {}) if len(manifest_targets) == 1 else {}
    props_ok = (all(data_props.get(k) == value for k, value in CANONICAL_WHEEL_FIELDS.items())
                and all(manifest_props.get(k) == value for k, value in CANONICAL_WHEEL_FIELDS.items()))
    target_receipt = receipt.get("target", {})
    target_ok = (target_receipt.get("cls") == CANONICAL_WHEEL_TARGET["cls"]
                 and target_receipt.get("at") == CANONICAL_WHEEL_TARGET["at"]
                 and target_receipt.get("tile") == CANONICAL_WHEEL_TARGET["tile"]
                 and target_receipt.get("props") == CANONICAL_WHEEL_FIELDS)
    manifest_delta_receipt = receipt.get("manifest_semantic_delta", {})
    manifest_delta_ok = (manifest_delta_receipt.get("old_box_count") == len(old_manifest.get("boxes", []))
                         and manifest_delta_receipt.get("new_box_count") == len(new_manifest.get("boxes", []))
                         and manifest_delta_receipt.get("old_entity_count") == len(old_manifest.get("entities", []))
                         and manifest_delta_receipt.get("new_entity_count") == len(new_manifest.get("entities", []))
                         and manifest_delta_receipt.get("changed_entity_count") == 1
                         and manifest_delta_receipt.get("changed_existing_props") == sorted(CANONICAL_WHEEL_PROPS))

    # Recompute pre-change C output from the frozen Python/JSON inputs and
    # current C/B/D outputs without writing manifests.
    anchor_dir = ROOT / "Tools/LevelDesign/anchor_plans"
    sys.path.insert(0, str(anchor_dir))
    try:
        builder = importlib.import_module("build_warrens")
        common = importlib.import_module("design_warrens_v8_common")
        old_map, old_data_path = builder.MAP, builder.DATA
        old_module = runpy.run_path(str(ROOT / files[CANONICAL_WHEEL_FILES[0]]["checkpoint"]), run_name="pre_wheel_c_design")
        old_variant = SimpleNamespace(**old_module)
        old_variant_data = common.build(old_variant)
        builder.MAP = "/Game/Mars/Maps/Warrens_VariantC_Mars_MAP"
        builder.DATA = anchor_dir / "data/warrens_v8c.json"
        old_generated, _ = builder.manifest(write=False, data=old_variant_data)
        current_variant = importlib.import_module("design_warrens_v8c")
        current_variant_data = common.build(current_variant)
        current_generated, _ = builder.manifest(write=False, data=current_variant_data)
        c_saved_preflight = read_json(ROOT / files[CANONICAL_WHEEL_FILES[2]]["checkpoint"])
        c_pre_ok = (canonical_sha(old_variant_data) == canonical_sha(old_data)
                    and canonical_sha(old_generated) == canonical_sha(c_saved_preflight)
                    and canonical_sha(old_generated) == baseline["pure_manifest_preflight"]["C"]["generated_sha256"])
        c_current_ok = (canonical_sha(current_variant_data) == canonical_sha(new_data)
                        and canonical_sha(current_generated) == canonical_sha(new_manifest))
        bd_rows = {}
        for suffix, map_path in (("b", "/Game/Mars/Maps/Warrens_VariantB_Mars_MAP"),
                                 ("d", "/Game/Mars/Maps/Warrens_VariantD_Mars_MAP")):
            variant = importlib.import_module(f"design_warrens_v8{suffix}")
            variant_path = anchor_dir / f"design_warrens_v8{suffix}.py"
            builder.MAP = map_path
            generated, _ = builder.manifest(write=False, data=common.build(variant))
            saved_path = ROOT / f"Saved/AnchorPlans/v8{suffix}-manifest.json"
            saved = read_json(saved_path)
            before = baseline["pure_manifest_preflight"][suffix.upper()]
            bd_rows[suffix.upper()] = {
                "matches_saved": canonical_sha(generated) == canonical_sha(saved),
                "matches_preflight_hash": canonical_sha(generated) == before.get("generated_sha256"),
                "source_unchanged": sha256(variant_path) == before.get("source_module_sha256"),
                "saved_manifest_unchanged": sha256(saved_path) == before.get("saved_raw_sha256"),
                "generated_sha256": canonical_sha(generated),
            }
    except Exception as exc:
        c_pre_ok = c_current_ok = False
        bd_rows = {"error": f"{type(exc).__name__}: {exc}"}
    finally:
        if "builder" in locals() and "old_map" in locals() and "old_data_path" in locals():
            builder.MAP, builder.DATA = old_map, old_data_path

    pre_manifest_ok = receipt.get("preflight") == {
        key: {name: baseline["pure_manifest_preflight"][key][name]
              for name in ("map", "generated_sha256", "source_module_sha256", "saved_raw_sha256", "generated_matches_saved")}
        for key in ("C", "B", "D")
    }
    bd_ok = all(row.get("matches_saved") and row.get("matches_preflight_hash")
                and row.get("source_unchanged") and row.get("saved_manifest_unchanged")
                for row in bd_rows.values()) if bd_rows and "error" not in bd_rows else False

    # The mechanism source and saved Canal map are independent runtime evidence;
    # canonical parity changes only the authored C plan and emitted manifest.
    wheel_review = read_json(REVIEW / "P2_WHEEL_RETENTION.json")
    material_receipt_rel = wheel_review.get("stage_receipt", "")
    material_receipt_path = ROOT / material_receipt_rel
    material_receipt_sha = sha256(material_receipt_path) if material_receipt_path.is_file() else None
    material_stage = read_json(material_receipt_path) if material_receipt_path.is_file() else {}
    wheel_build = read_json(REVIEW / "P2_WHEEL_BUILD_TEST.json")
    as_source_sha, _ = file_hash("Script/WorldObjects/Mechanisms/Mars_SlidingBridge_EntityScript.as")
    canal_map_sha, _ = file_hash("Content/Mars/Maps/Variants/v8c/LI_Warrens_Canal.umap")
    runtime_guards = receipt.get("runtime_guards", {})
    map_and_as_ok = (wheel_review.get("stage_receipt_sha256") == material_receipt_sha
                     and material_receipt_sha == runtime_guards.get("wheel_material_receipt_sha256")
                     and as_source_sha == wheel_build.get("final", {}).get("source_sha256")
                     and as_source_sha == runtime_guards.get("as_source_sha256")
                     and canal_map_sha == material_stage.get("after_sha256")
                     and canal_map_sha == runtime_guards.get("canal_map_sha256")
                     and runtime_guards.get("as_source_path") == "Script/WorldObjects/Mechanisms/Mars_SlidingBridge_EntityScript.as"
                     and runtime_guards.get("canal_map_path") == "Content/Mars/Maps/Variants/v8c/LI_Warrens_Canal.umap"
                     and runtime_guards.get("wheel_material_receipt") == material_receipt_rel
                     and runtime_guards.get("wheel_material_receipt_after_sha256") == material_stage.get("after_sha256"))

    before_after_chain_ok = (receipt.get("status") == "APPLIED_CANONICAL_THREE_FIELD_PARITY"
                             and receipt.get("baseline_manifest") == str(CANONICAL_PARITY_BASELINE.relative_to(ROOT)).replace("\\", "/")
                             and set(files) == set(CANONICAL_WHEEL_FILES)
                             and all(row["checkpoint_matches"] and row["current_matches"] for row in file_rows.values())
                             and baseline_chain_ok)
    valid = bool(before_after_chain_ok and exact_source_hunk and hunk_ok and section_ast_ok
                 and data_delta_ok and manifest_delta_ok and props_ok and target_ok
                 and c_pre_ok and c_current_ok and pre_manifest_ok and bd_ok and map_and_as_ok and approval_ok)
    check(report, "P2 wheel canonical C plan three-field parity chain", valid, {
        "receipt_sha256": sha256(CANONICAL_PARITY), "status": receipt.get("status"),
        "baseline_manifest": receipt.get("baseline_manifest"), "files": file_rows,
        "baseline_links_match_P4_receipts": baseline_chain_ok,
        "section_ast": {"before": source_before_ast, "after": source_after_ast,
                         "historical_guard_matches": source_before_ast == HISTORICAL_SECTION_AST_SHA256,
                         "receipt_matches": section_ast_ok},
        "source_hunk_exact": exact_source_hunk, "source_hunk_receipt_matches": hunk_ok,
        "review_approval_matches_current_source": approval_ok, "review_source_sha256": review_sha,
        "data_delta_only_three_props": data_delta_ok, "manifest_delta_only_three_props": manifest_delta_ok,
        "target_counts": {"data": data_target_count, "manifest": manifest_target_count},
        "expected_props_match_data_and_manifest": props_ok, "receipt_target_matches": target_ok,
        "receipt_manifest_delta_matches": manifest_delta_ok,
        "pure_pre_change_C_generation_matches_checkpoint": c_pre_ok,
        "pure_current_C_generation_matches_saved_data_manifest": c_current_ok,
        "preflight_hashes_recorded": pre_manifest_ok, "B_D_generation_unchanged": bd_rows,
        "wheel_runtime_map_and_AS_unchanged": map_and_as_ok,
        "source_hash_sha256": as_source_sha, "canal_map_sha256": canal_map_sha,
        "claim_boundary": "offline source/data/manifest and saved receipt-chain verification; no editor or runtime action",
    })
    return valid


def _matches_exact_successor(path: str, before: str, actual: str | None, successors: dict[str, tuple[str, str]]) -> bool:
    return actual == before or successors.get(path.replace("\\", "/")) == (before, actual)


def verify_belfry_library_retention(report: dict[str, Any]) -> dict[str, tuple[str, str]]:
    """Admit exactly two promoted Blends and one saved review map, after proof."""
    successors: dict[str, tuple[str, str]] = {
        "Tools/WarrensVariantCKit/Output/WarrensVariantC_KitLibrary.blend": (
            "50a54a4d7efbff84314cc6dfb303a2308fc801474ae8292d7cb050bfcfc388cf", "28ae1af77e09a3dbb5377462861f171c56472f239b00eb4a2a913951fa038fa7"),
        "Tools/WarrensVariantCKit/Output/WarrensVariantC_Diorama.blend": (
            "ac79fa7e3636891688f95939815188e4cf92f67f607e139af28aeb6436500d5f", "2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc"),
        ART_MAPS["Diorama"]: (
            "54893400ca58615414ac54e7a518aa889b8322b4a83f502d25cfdfb6a32f5ea3", "1d6db2767b1922dbe27b335b8acdf596ff17c8c599effdc49016496ef3bd4293"),
    }
    evidence: dict[str, str] = {}

    def load(path: Path, expected: str | None = None) -> Any:
        actual = sha256(path)
        assert expected is None or actual == expected, str(path)
        evidence[str(path.relative_to(ROOT)).replace("\\", "/")] = actual
        return read_json(path)

    def strip_session(value: Any) -> None:
        if isinstance(value, dict):
            value.pop("session_uid", None)
            for item in value.values():
                strip_session(item)
        elif isinstance(value, list):
            for item in value:
                strip_session(item)

    try:
        assert sha256(REVIEW / "BELFRY_PALETTE_RETENTION.json") == BELFRY_RETENTION_SHA256
        assert sha256(REVIEW / "BELFRY_PALETTE_RETENTION.md") == BELFRY_RETENTION_REVIEW_SHA256
        assert sha256(REVIEW / "BELFRY_LIBRARY_SYNC.md") == "0ab8cec4be1b2d04b949d5ccfd2d4f5f7b52e95c6b2d7441c21e9a4460fa5b73"
        helper = runpy.run_path(str(ROOT / "Tools/WarrensVariantCKit/belfry_palette_persistent.py"))
        delta = helper["contract"]()
        bindings = {r["source_key"]: r for r in delta["bindings"]}
        promotion = load(BELFRY_LIBRARY / "promotion.json", "51ebbcc8294a684f97d3229749eff05b6397d17b8c0025109a91341b742ce00f")
        baseline = load(BELFRY_LIBRARY / "baseline.json", "80e5b804540f5433b5f75edef924e3120bba18fbd2e3b084de582f98b36c7261")
        assert promotion["status"] == "PROMOTED_STONE_ONLY" and promotion["other_immutable_unchanged"] == 462
        assert set(promotion["targets"]) == set(promotion["originals"]) == {"KitLibrary", "Diorama"}
        assert promotion["originals"] == baseline["original"] and len(baseline["immutable"]) == 464
        assert file_hash(baseline["approval"]["path"])[0] == baseline["approval"]["sha256"]
        assert file_hash(baseline["approved_preflight"])[0] == baseline["approved_preflight_sha256"]
        palette = runpy.run_path(str(ROOT / "Tools/WarrensVariantCKit/build_belfry_palette.py"))
        stage_hashes = {
            "KitLibrary": ("da939fdaf1f559d3e5754dbe0aa80ab5dec54fec9bb90fa8360d866fd0525fca", "91a4bfd90eb090326e02057ce9ff7efa1185b43041decfb333010264f90ea044", "6d0b8871342466d05413cf2ab27b3bdf87d92e1e77d8beba46ed4098456e3052", "530f4822f5ae25a711a3193eeb73d335a1304bb129fcd355441e9fa1c824900e"),
            "Diorama": ("389fab233534a146274cf0b3e785b53a5001af19234fa102feb287aebfa3de73", "be31bdbccb660bcd56401dab4f208b4bdbb377b83f5b09c5f59be5404d0f9183", "e12ccd787ff3c19fd713ccca67162bb6049ae4397b0dd50a0d590a3d45ec9800", "a59eb8678e17b6197c6da00abe1c89dac6c5efcdc59b86c0859291d64263ab2d"),
        }
        for name, hashes in stage_hashes.items():
            target = promotion["targets"][name]
            before_hash, after_hash = successors[target["path"]]
            assert target["before_sha256"] == before_hash == sha256(ROOT / target["checkpoint"])
            assert target["after_sha256"] == after_hash == sha256(ROOT / target["path"])
            stage_dir = BELFRY_LIBRARY / ("r02_" + name)
            stage = load(stage_dir / "receipt.json", hashes[0])
            staged_reopen = load(stage_dir / "reopen.json", hashes[1])
            reopened = load(BELFRY_LIBRARY / "promoted_reopened" / (name + ".json"), hashes[2])
            assert sha256(stage_dir / (name + ".stone.blend")) == staged_reopen["stage_sha256"] == after_hash
            assert stage["status"] == "STAGED_NOT_PROMOTED" and staged_reopen["status"] == "REOPENED_STONE_ONLY_VERIFIED"
            assert reopened["status"] == "PROMOTED_ORIGINAL_REOPENED_VERIFIED" and reopened["source"] == target
            assert reopened["source_sha256"] == after_hash and reopened["read_only"] is True
            assert reopened["existing_materials_and_meshes_preserved"] is True
            assert reopened["selected_instances"] == stage["selected_instances"] == staged_reopen["selected_instances"] == 2144
            assert reopened["material_families"] == stage["material_families"] == ["TX01", "TX02"]
            assert len(stage["wrappers"]) == staged_reopen["wrappers"] == 7
            assert len(stage["material_deltas"]) == stage["copied_materials"] == staged_reopen["copied_materials"] == 4
            assert {r["source_key"]: r["source_row"] for r in stage["bindings"]} == {k: r["source_row"] for k, r in bindings.items()}
            assert len(stage["bindings"]) == 2144 and stage["selector"] == reopened["selector"]
            assert stage["selector"]["sha256"] == helper["DELTA_SHA"] and stage["selector"]["selection_sha256"] == delta["selection_sha256"]
            assert stage["geometry"] == staged_reopen["geometry"] == reopened["geometry"]
            assert stage["geometry"]["count"] == 32646
            original = load(stage_dir / "before.json", hashes[3])
            observed = load(ROOT / reopened["observed_inventory"]["file"], reopened["observed_inventory"]["sha256"])
            assert "Render Result" not in original["images"] and "Render Result" not in observed["images"]
            strip_session(original)
            strip_session(observed)
            assert palette["digest"](observed) == stage["inventory_sha256"] == staged_reopen["inventory_sha256"] == reopened["inventory_sha256"]
            assert len(observed["scenes"]) == reopened["scenes"] == 15 and len(observed["objects"]) == reopened["objects"] == 65753
            assert len(observed["images"]) == reopened["images"] == 145
            assert set(observed["objects"]) - set(original["objects"]) == {p["candidate"] for w in stage["wrappers"] for p in w["parts"]}
            assert set(observed["collections"]) - set(original["collections"]) == {w["candidate"] for w in stage["wrappers"]}
            assert set(observed["materials"]) - set(original["materials"]) == {r["candidate"] for r in stage["material_deltas"]}
            for binding in stage["bindings"]:
                obj = observed["objects"][binding["instance"]]
                assert obj["instance"] == binding["candidate_collection"]
                obj["instance"] = binding["source_collection"]
            for group in ("objects", "collections", "materials"):
                for key in set(observed[group]) - set(original[group]):
                    if group == "materials":
                        change = next(r for r in stage["material_deltas"] if r["candidate"] == key)
                        palette["check_color_delta"](original[group][change["source"]]["nodes"], observed[group][key]["nodes"], change)
                    del observed[group][key]
            for group, field in (("materials", "values"), ("images", "properties")):
                for key, item in original[group].items():
                    if "users" in item[field]:
                        observed[group][key][field]["users"] = item[field]["users"]
            assert observed == original, "Promoted original inventory changed beyond enumerated bindings/copies"
            del observed, original
        assert all(_matches_exact_successor(p, h, file_hash(p)[0], successors) for p, h in baseline["immutable"].items())

        preflight = load(BELFRY_DIORAMA / "preflight.json", "e274d2816d36b906c8b3bb75f9e2ec2689e1315ae535247f77975b9259b73bcc")
        applied = load(BELFRY_DIORAMA / "applied.json", "5392a6a48e90bf92410d707a06818dfc04f92eec69e04a89fa28d915e9cfeb56")
        unloaded = load(BELFRY_DIORAMA / "unloaded.json", "71c6962362002574cb985dd2903f3ba993fdad9c7adf038fcd8c4bb19dd359c7")
        audit = load(BELFRY_DIORAMA / "audit.json", "72a13b5f629212822b0d045832a7b455a8d1b995a941944f552920aedf4ba0a7")
        assert preflight["status"] == "DIORAMA_PREFLIGHT_REVIEW_REQUIRED" and applied["status"] == "DIORAMA_APPLIED_RELOAD_AUDIT_REQUIRED"
        assert audit["status"] == "DIORAMA_RELOAD_AUDITED" and unloaded["status"] == "DIORAMA_UNLOADED_OBSERVED"
        assert sha256(ROOT / applied["preflight_file"]) == applied["preflight_sha256"] == evidence[str((BELFRY_DIORAMA / "preflight.json").relative_to(ROOT)).replace("\\", "/")]
        assert sha256(ROOT / audit["applied_file"]) == audit["applied_sha256"] == unloaded["applied_sha256"]
        before_hash, after_hash = successors[ART_MAPS["Diorama"]]
        assert preflight["map_sha256"] == applied["map_before"] == applied["checkpoint_sha256"] == sha256(ROOT / applied["checkpoint_file"]) == before_hash
        assert read_json(LIBRARY_SYNC / "Diorama.json")["after_sha256"] == before_hash
        assert file_hash(ART_MAPS["Diorama"])[0] == applied["map_after"] == unloaded["map_after_sha256"] == audit["map_sha256"] == after_hash
        assert unloaded["other_world_open"] is True and unloaded["target_find_object_result"] is None and audit["unload_reload_identity_changed"] is True
        assert applied["only_diorama_map_saved"] is True and applied["cook_setting_restored"] is True and applied["collision_guard_count"] == 54
        assert preflight["guards"] == applied["guards"] == unloaded["guards"] == audit["guards"] and len(applied["guards"]) == 561
        assert all(_matches_exact_successor(p, h, file_hash(p)[0], successors) for p, h in applied["guards"].items())
        assert preflight["delta_sha256"] == helper["DELTA_SHA"] and preflight["selection_sha256"] == delta["selection_sha256"]
        diorama = runpy.run_path(str(ROOT / "Tools/WarrensVariantCKit/belfry_palette_diorama.py"))
        selection = preflight["selection"]
        assert len(selection["records"]) == 2144 and {r["source_key"] for r in selection["records"]} == set(bindings)
        before = preflight["actors_and_components"]
        for row in selection["records"]:
            binding = bindings[row["source_key"]]
            assert row["target"] == binding["slots"][0]["target_material_path"] and row["row_sha256"] == binding["source_row_sha256"]
            actor, = [r for r in before.values() if r["label"] == row["label"]]
            component, = [c for c in actor["components"].values() if "instances" in c]
            # Native HISM indices are recorded separately; the complete roster
            # sorts serialized poses, so membership must use the exact pose.
            assert 0 <= row["index"] < len(component["instances"])
            assert component["instances"].count(row["world_pose"]) == 1
        for label, indices in selection["by_label"].items():
            actual_indices = [r["index"] for r in selection["records"] if r["label"] == label]
            assert sorted(actual_indices) == indices and len(set(indices)) == len(indices)
        expected = diorama["_expected_after"](None, before, selection)
        after = applied["expected_after_roster"]
        assert after == applied["observed_after_roster"] == audit["actor_component_roster"]
        assert set(expected).issubset(after) and all(after[k] == v for k, v in expected.items())
        additions = [after[k] for k in set(after) - set(expected)]
        assert len(additions) == 5 and {r["label"] for r in additions} == set(diorama["PARTITION_LABELS"].values())
        for source_label, new_label in diorama["PARTITION_LABELS"].items():
            source, = [r for r in before.values() if r["label"] == source_label]
            new, = [r for r in additions if r["label"] == new_label]
            assert new["type"] == "/Script/Engine.Actor" and new["tags"] == [diorama["OWNER"]] and new["hidden"] is False
            assert len(source["components"]) == len(new["components"]) == 1
            original_component, = source["components"].values()
            new_component, = new["components"].values()
            for field in ("mesh", "collision", "overlap", "shadow", "visible", "pose"):
                assert new_component[field] == original_component[field]
            poses = [r["world_pose"] for r in selection["records"] if r["label"] == source_label]
            assert sorted(new_component["instances"], key=canonical_sha) == sorted(poses, key=canonical_sha)
            slots = list(original_component["materials"])
            slots[0] = delta["materials"][selection["targets"][source_label]]["target_asset"]
            assert new_component["materials"] == slots
        assert diorama["_total_instances"](after) == applied["total_instances_after"] == audit["total_instances"] == 32646
        assert set(applied["rebind_groups"]) == diorama["WHOLE_GROUPS"] and len(applied["component_contracts_after"]) == 12
    except (AssertionError, KeyError, OSError, ValueError, TypeError) as exc:
        check(report, "Belfry palette exact three-artifact library supersession and reopen", False, {"error": f"{type(exc).__name__}: {exc}"})
        return {}
    check(report, "Belfry palette exact three-artifact library supersession and reopen", True, {
        "supersessions": {p: {"before": h[0], "after": h[1]} for p, h in successors.items()}, "evidence": evidence,
        "Blender": {"targets": 2, "selected_each": 2144, "wrappers_each": 7, "copied_materials_each": 4, "geometry_each": 32646,
                    "scenes_each": 15, "objects_each": 65753, "packed_images_each": 145, "inventory_normalization": "session_uid only; original material/image user counts account for copies"},
        "Unreal_Diorama": {"selected": 2144, "partial_groups": 5, "whole_groups": 2, "instances": 32646, "protected_files": 561},
        "boundary": "Exact saved/reopened library artifacts, not gameplay input, pacing or new art acceptance. Unreal KitLibrary stays unchanged.",
    })
    return successors


def verify_belfry_palette_retention(report: dict[str, Any], library_successors: dict[str, tuple[str, str]] | None = None) -> bool:
    """One exact saved appearance epoch; historical receipts remain immutable."""
    receipt_path = REVIEW / "BELFRY_PALETTE_RETENTION.json"
    if not receipt_path.is_file():
        pending(report, "Belfry palette saved source and runtime receipt chain", {"missing": str(receipt_path.relative_to(ROOT))})
        return False
    evidence: dict[str, str] = {}

    def linked(row: dict[str, str]) -> Any:
        path = (ROOT / row["file"]).resolve()
        assert path.is_relative_to(ROOT) and path.is_file() and sha256(path) == row["sha256"], row["file"]
        evidence[str(path.relative_to(ROOT)).replace("\\", "/")] = row["sha256"]
        return read_json(path) if path.suffix == ".json" else path

    try:
        assert sha256(receipt_path) == BELFRY_RETENTION_SHA256
        retained = read_json(receipt_path)
        assert retained["status"] == "SAVED_RELOADED_RUNTIME_OBSERVED_ASTRA_RETENTION_PENDING"
        applied = linked(retained["applied"])
        reload_audit = linked(retained["reload_audit"])
        identity = linked(retained["reviewed_reload_identity"])
        runtime = linked(retained["runtime_all_poses"])
        helper = runpy.run_path(str(ROOT / "Tools/WarrensVariantCKit/belfry_palette_persistent.py"))
        delta = helper["contract"]()  # Pins all 2144 selectors to the immutable fitted source ledger.
        base = helper["_base"]()
        checkpoint_path = ROOT / applied["checkpoint"]
        checkpoint = read_json(checkpoint_path)
        original = linked({"file": checkpoint["preflight_file"], "sha256": checkpoint["preflight_sha256"]})
        recovery = helper["_recovery"](applied["recovery"]["file"], applied["recovery"]["sha256"])
        assert checkpoint["recovery"] == original["recovery"] == applied["recovery"]
        assert sha256(ROOT / checkpoint["backup"]) == checkpoint["map_before"] == original["map_sha256"] == applied["map_before"] == BELFRY_MAP_BEFORE
        assert applied["map_after"] == retained["source_map_sha256"] == sha256(ROOT / ART_MAPS["Belfry"]) == BELFRY_MAP_AFTER
        assert read_json(ART / "P4_Belfry.json")["after_sha256"] == BELFRY_MAP_BEFORE
        assert original["inventory"] == recovery["inventory"] and original["matched_rows"] == recovery["matched_rows"]
        helper["_exact_roster"](recovery["roster"], original["roster"])
        assert applied["status"] == "SAVED_RELOAD_AND_PIE_PENDING"
        assert applied["delta_sha256"] == original["delta_sha256"] == helper["DELTA_SHA"]
        assert applied["guards"] == original["guards"] == checkpoint["guards"] == recovery["guards"]
        assert len(applied["guards"]) == 646
        assert all(_matches_exact_successor(path, expected, file_hash(path)[0], library_successors or {}) for path, expected in applied["guards"].items())
        assert retained["original_shared_materials_and_collision_unchanged"] is True and retained["other_guarded_files_unchanged"] == 646
        assert retained["editor_after"] == {"dirty_packages": [], "pie": False}

        # Reconstruct the exact 590/112 split and six pure-group slot changes.
        bindings = {r["source_key"]: r for r in delta["bindings"]}
        matches = original["matched_rows"]
        assert len(matches) == 2984 and sum(r["selected"] for r in matches) == len(bindings) == 2144
        by_actor: dict[str, list[dict[str, Any]]] = {}
        for row in matches:
            assert row["selected"] == (row["source_key"] in bindings)
            by_actor.setdefault(row["actor"], []).append(row)
        for label, source in original["inventory"].items():
            expected = json.loads(json.dumps(source))
            rows = by_actor.get(label, [])
            if label == "WVC_BACKING_TX01":
                protected = sorted(r["index"] for r in rows if not r["selected"])
                candidates = sorted(r["index"] for r in rows if r["selected"])
                assert len(rows) == 702 and len(protected) == 112 and len(candidates) == 590
                expected["instances"] = [source["instances"][i] for i in protected]
                new_group = json.loads(json.dumps(source))
                new_group.update(path=applied["expected_new"]["path"], actor=helper["NEW_ACTOR"], actor_tags=[helper["OWNER"]],
                                 instances=[source["instances"][i] for i in candidates], materials=[delta["materials"]["TX01"]["target_asset"]])
                assert new_group == applied["expected_new"]
            elif any(r["selected"] for r in rows):
                assert all(r["selected"] for r in rows)
                paths = {bindings[r["source_key"]]["slots"][0]["target_material_path"] for r in rows}
                assert len(paths) == 1
                expected["materials"][0] = paths.pop()
            assert expected == applied["expected_inventory"][label], label
        assert set(applied["expected_inventory"]) == set(original["inventory"]) and len(original["inventory"]) == 32
        records = list(applied["expected_inventory"].values()) + [applied["expected_new"]]
        aliases = {s["target_asset"]: s["source_asset"] for s in delta["materials"].values()}
        assert len(records) == 33 and sum(len(r["instances"]) for r in records) == 3537
        assert base["_visible_instances"](records, aliases) == original["visible_multiset"] == applied["visible_multiset"] == reload_audit["visible_multiset"]
        assert applied["visible_multiset"]["count"] == 3525

        for key, spec in delta["materials"].items():
            material = applied["created_materials"][key]
            assert material == {"asset": spec["target_asset"], "sha256": recovery["materials"][key]["sha256"]}
            assert file_hash("Content/" + spec["target_asset"].removeprefix("/Game/") + ".uasset")[0] == material["sha256"]
            graph = reload_audit["graphs"][key]
            linked(graph)
            assert graph["all_nine_nodes_and_masks_verified"] is True and graph["sha256"] == recovery["materials"][key]["graph"]["sha256"]
            expected, _ = base["_canonical_material"](base["_text_blocks"](ROOT / spec["source_graph_file"]), "M_CCK_" + key, spec["source_asset"] + ".M_CCK_" + key)
            name = spec["target_asset"].rsplit("/", 1)[1]
            observed, _ = base["_canonical_material"](base["_text_blocks"](ROOT / graph["file"]), name, spec["target_asset"] + "." + name)
            expected["@M@/MaterialExpressionConstant3Vector_0"]["Constant"] = "(R=%.6f,G=%.6f,B=%.6f,A=1.000000)" % tuple(spec["lerp_a_linear_rgba"][:3])
            assert observed == expected, key
        assert sorted(applied["reused_material_paths"]) == sorted(s["target_asset"] for s in delta["materials"].values())

        # Validate the reviewed five-export identity exception against the actual
        # reopened exports; all other raw comparisons still use the strict audit.
        after = json.loads(json.dumps(original["roster"]))
        roster_folder = (ROOT / retained["reload_audit"]["file"]).parent / "roster"
        for actor_name, actor in after.items():
            actor["raw"] = {"file": str((roster_folder / (actor_name + ".t3d")).relative_to(ROOT)), "sha256": sha256(roster_folder / (actor_name + ".t3d"))}
            for name, component in actor["components"].items():
                path = roster_folder / (actor_name + "__" + name + ".t3d")
                component["raw"] = {"file": str(path.relative_to(ROOT)), "sha256": sha256(path)}
        identity_row = retained["reviewed_reload_identity"]
        assert identity["applied_sha256"] == retained["applied"]["sha256"] and reload_audit["reviewed_identity"]["sha256"] == identity_row["sha256"]
        reviewed = helper["_reviewed_reload_roster"](original["roster"], after, identity_row["file"], identity_row["sha256"],
            identity["applied_file"], retained["applied"]["sha256"], checkpoint["preflight_file"], checkpoint["preflight_sha256"])
        after[applied["new_actor"]] = {}  # The strict helper checks original actors; the owned group is checked above.
        helper["_verify_roster"](reviewed, after, {k: set(v) for k, v in applied["changed_components"].items()}, applied["new_actor"])
        assert reload_audit["status"] == "SAVED_REOPEN_AUDITED_PIE_PENDING"
        for row in (retained, reload_audit):
            assert row["selected"] == 2144 and row["hisms"] == 33 and row["instances"] == 3537 and row["protected_original"] == 112
        assert runtime["status"] == "PIE_SUBSETS_OBSERVED_HELD_VIEWS_PENDING"
        assert runtime["selected"] == 2144 and runtime["source_art_rows_pose_matched"] == 2984 and runtime["hisms"] == 33
        assert runtime["all_instance_poses_matched"] == runtime["total_instances"] == 3537 and runtime["visible_instances"] == retained["visible_instances"] == 3525
        assert runtime["protected_original"] == 112 and runtime["new_owned"] == retained["new_owned"] == 590
        assert runtime["pose_tolerances"] == {"translation_cm": .1, "scale": .001, "rotation_radians": .001}
        assert runtime["materials"] == {k: s["target_asset"] for k, s in delta["materials"].items()}
        for label, capture in retained["captures"].items():
            metadata = linked(capture["record"])
            linked(capture["image"])
            assert metadata["image_sha256"] == capture["image"]["sha256"] and metadata["world"] == runtime["world"]
            assert "pack=true" in metadata["inventory"] and "Mars_ItemDef_Lantern" in metadata["inventory"] and "held=" in metadata["inventory"]
            assert metadata["actual_held_light"]["intensity"] == capture["actual_held_intensity"] > 0 and metadata["fov"] == 90
        assert set(retained["captures"]) == {"panel", "landing"} and retained["root_pixels_viewed"] is True
    except (AssertionError, KeyError, OSError, ValueError, TypeError) as exc:
        check(report, "Belfry palette saved source and runtime receipt chain", False, {"error": f"{type(exc).__name__}: {exc}"})
        return False
    check(report, "Belfry palette saved source and runtime receipt chain", True, {
        "retention_sha256": BELFRY_RETENTION_SHA256, "map_before": BELFRY_MAP_BEFORE, "map_after": BELFRY_MAP_AFTER,
        "selected": 2144, "protected_original": 112, "new_owned": 590, "hisms": 33, "instances": 3537, "visible": 3525,
        "all_pose_runtime_receipt": retained["runtime_all_poses"], "linked_evidence": evidence,
        "boundary": retained["boundary"], "original_Blender_and_Unreal_Diorama_palette_parity": "not admitted by this source-map chain",
    })
    approval_path = REVIEW / "BELFRY_PALETTE_RETENTION.md"
    if not approval_path.is_file():
        pending(report, "Belfry palette explicit retention approval", {"expected": str(approval_path.relative_to(ROOT))})
        return False
    approval = approval_path.read_text(encoding="utf-8-sig")
    approved = (sha256(approval_path) == BELFRY_RETENTION_REVIEW_SHA256
                and "**APPROVED for bounded retention and exact presentation parity.**" in approval
                and BELFRY_RETENTION_SHA256 in approval)
    check(report, "Belfry palette explicit retention approval", approved, {"path": str(approval_path.relative_to(ROOT)), "sha256": sha256(approval_path), "exact_retention_receipt": BELFRY_RETENTION_SHA256})
    return approved


def verify_art_receipts(report: dict[str, Any], canonical_parity_ok: bool = False, belfry_palette_ok: bool = False,
                        library_successors: dict[str, tuple[str, str]] | None = None) -> None:
    checkpoint = read_json(ART / "manifest.json")
    receipt_paths = {
        "Mill": ART / "applied_Mill.json",
        "Belfry": ART / "P4_Belfry.json",
        "Diorama": ART / "applied_Diorama.json",
        "KitLibrary": ART / "applied_KitLibrary.json",
    }
    receipts = {}
    for name, path in receipt_paths.items():
        if path.is_file():
            receipts[name] = read_json(path)
        else:
            receipts[name] = None
            pending(report, f"current art receipt {name}", {"expected_receipt": str(path.relative_to(ROOT))})
    backup_rows = {}
    for source, entry in checkpoint.items():
        backup_path = ROOT / entry["backup"]
        actual = sha256(backup_path) if backup_path.is_file() else None
        backup_rows[source] = {"expected": entry["sha256"], "actual": actual, "matches": actual == entry["sha256"]}
    check(report, "historical art checkpoint integrity", bool(backup_rows) and all(x["matches"] for x in backup_rows.values()), backup_rows)

    sync_receipts = {}
    for name in ("Diorama", "KitLibrary"):
        path = LIBRARY_SYNC / f"{name}.json"
        sync_receipts[name] = read_json(path) if path.is_file() else None

    current_rows = {}
    for name, rel in ART_MAPS.items():
        receipt = receipts[name]
        actual, error = file_hash(rel)
        latest = sync_receipts.get(name) if name in sync_receipts else None
        expected = latest.get("after_sha256") if latest else (receipt.get("after_sha256") if receipt else None)
        chain_before = latest.get("before_sha256") if latest else None
        legacy_after = receipt.get("after_sha256") if receipt else None
        palette_supersedes = name == "Belfry" and belfry_palette_ok and expected == BELFRY_MAP_BEFORE and actual == BELFRY_MAP_AFTER
        # For an art map later revised by an approved P2 stage, the latest
        # P2 receipt is authoritative. This branch is currently only relevant
        # to the three crossing tiles, not Mill/Belfry.
        current_rows[name] = {"path": rel, "receipt_after": expected, "current": actual,
                              "matches_receipt": _matches_exact_successor(rel, expected, actual, library_successors or {}) or palette_supersedes, "error": error,
                              "superseded_by_exact_library_chain": (library_successors or {}).get(rel) == (expected, actual),
                              "superseded_by_exact_Belfry_palette_chain": palette_supersedes,
                              "collision_count_attested": (latest or receipt).get("collision_files_preserved") if (latest or receipt) else None,
                              "latest_receipt": f"ArtLibrarySyncCheckpoint/unreal-v2/{name}.json" if latest else "ArtCheckpoint",
                              "legacy_receipt_after": legacy_after,
                              "latest_before_matches_legacy_after": chain_before == legacy_after if latest else None}
    if any(receipt is None for receipt in receipts.values()):
        pending(report, "current Mill, Belfry, diorama and library map hashes", current_rows)
    else:
        check(report, "current Mill, Belfry, diorama and library map hashes",
              all(row["matches_receipt"] and row.get("latest_before_matches_legacy_after") is not False for row in current_rows.values()), current_rows)

    # The canonical art update also records the source-generated material fields.
    canonical = read_json(RUN / "ArtPlan/CANONICAL_ART_UPDATE.json")
    bindings = {(row[0], row[1]): row[2] for row in canonical.get("bindings", [])}
    fields_ok = bindings == {
        ("panel", "BodyMaterialOverride"): EXPECTED_MATERIALS[("Mars_Bellkeeper_EntityScript", "BodyMaterialOverride")],
        ("panel", "FaceMaterialOverride"): EXPECTED_MATERIALS[("Mars_Bellkeeper_EntityScript", "FaceMaterialOverride")],
        ("panel", "ControlMaterialOverride"): EXPECTED_MATERIALS[("Mars_Bellkeeper_EntityScript", "ControlMaterialOverride")],
        ("panel", "GlyphMaterialOverride"): EXPECTED_MATERIALS[("Mars_Bellkeeper_EntityScript", "GlyphMaterialOverride")],
        ("panel", "IndicatorMaterialOverride"): EXPECTED_MATERIALS[("Mars_Bellkeeper_EntityScript", "IndicatorMaterialOverride")],
        ("clue", "BodyMaterialOverride"): EXPECTED_MATERIALS[("Mars_BellkeeperClue_EntityScript", "BodyMaterialOverride")],
        ("clue", "FaceMaterialOverride"): EXPECTED_MATERIALS[("Mars_BellkeeperClue_EntityScript", "FaceMaterialOverride")],
        ("clue", "GlyphMaterialOverride"): EXPECTED_MATERIALS[("Mars_BellkeeperClue_EntityScript", "GlyphMaterialOverride")],
    }
    check(report, "canonical P4 eight-field binding receipt", fields_ok, {
        "status": canonical.get("status"), "fields": len(bindings), "bindings_match": fields_ok,
        "gameplay_topology_equal": canonical.get("c_gameplay_topology_equal"),
    })

    # Parse the current C source output and ensure only the approved values are
    # wired to the expected panel/clue entity props; retain runtime phrase data.
    generated = read_json(ROOT / "Saved/AnchorPlans/v8c-manifest.json")
    observed: dict[tuple[str, str], str] = {}
    for row in generated.get("entities", []):
        cls = row.get("cls")
        if cls not in {"Mars_Bellkeeper_EntityScript", "Mars_BellkeeperClue_EntityScript"}:
            continue
        for key, value in row.get("props", {}).items():
            if key in {k[1] for k in EXPECTED_MATERIALS}:
                asset = value.get("asset") if isinstance(value, dict) else None
                observed[(cls, key)] = asset
    check(report, "current emitted P4 material fields", observed == EXPECTED_MATERIALS, {
        "expected": {f"{c}.{p}": v for (c, p), v in EXPECTED_MATERIALS.items()},
        "observed": {f"{c}.{p}": v for (c, p), v in observed.items()},
    })

    # Verify current C source/manifest files against the canonical update's
    # recorded hashes when that receipt contains them; properties above remain
    # authoritative if later non-art plan metadata is regenerated.
    input_hashes = {}
    for rel in ("Tools/LevelDesign/anchor_plans/data/warrens_v8c.json", "Saved/AnchorPlans/v8c-manifest.json"):
        actual, error = file_hash(rel)
        input_hashes[rel] = {"current": actual, "error": error}
    check(report, "canonical receipt provenance", canonical.get("status") == "UPDATED_EIGHT_P4_ART_PROPERTIES_ONLY"
          and canonical.get("other_variant_manifests_equal") == {"b": True, "d": True}, {
              "receipt_status": canonical.get("status"), "other_variant_manifests_equal": canonical.get("other_variant_manifests_equal"),
              "current_inputs": input_hashes,
          })
    parity_receipt = read_json(CANONICAL_PARITY) if CANONICAL_PARITY.is_file() else {}
    parity_files = parity_receipt.get("files", {}) if canonical_parity_ok else {}
    receipt_files = {}
    for entry in canonical.get("files", []):
        rel = entry["path"].replace("\\", "/")
        actual, error = file_hash(rel)
        parity = parity_files.get(rel)
        if parity:
            matches = (entry.get("after_sha256") == parity.get("before_sha256")
                       and actual == parity.get("after_sha256"))
        else:
            matches = actual == entry.get("after_sha256")
        receipt_files[rel] = {"historical_after": entry.get("after_sha256"), "actual": actual,
                              "canonical_parity_before": parity.get("before_sha256") if parity else None,
                              "canonical_parity_after": parity.get("after_sha256") if parity else None,
                              "matches": matches, "parity_chain_valid": canonical_parity_ok if parity else None,
                              "error": error}
    check(report, "canonical C data and emitted manifest hashes", bool(receipt_files) and all(x["matches"] for x in receipt_files.values()), receipt_files)

    source_hash_manifest = read_json(RUN / "ArtPlan/SourceCheckpoint/SOURCE_HASHES.json")
    source_hash_rows = {}
    for entry in source_hash_manifest.get("files", []):
        rel = entry["path"].replace("\\", "/")
        actual, error = file_hash(rel)
        parity = parity_files.get(rel)
        if parity:
            matches = (entry.get("current_sha256") == parity.get("before_sha256")
                       and actual == parity.get("after_sha256"))
        else:
            matches = actual == entry.get("current_sha256")
        source_hash_rows[rel] = {"historical_current": entry.get("current_sha256"), "actual": actual,
                                 "canonical_parity_before": parity.get("before_sha256") if parity else None,
                                 "canonical_parity_after": parity.get("after_sha256") if parity else None,
                                 "matches": matches, "parity_chain_valid": canonical_parity_ok if parity else None,
                                 "error": error}
    check(report, "P4 source edit hashes against byte-preserving pre-art checkpoint", bool(source_hash_rows) and all(x["matches"] for x in source_hash_rows.values()), source_hash_rows)


def verify_collision_roster(report: dict[str, Any]) -> None:
    roster_path = RUN / "StartupCheckpoint/collision_hashes.json"
    roster = read_json(roster_path)
    actual = {}
    for rel, expected in roster.items():
        value, error = file_hash(rel)
        actual[rel] = {"expected": expected, "actual": value, "matches": value == expected, "error": error}
    check(report, "54-file derived collision hash roster", len(roster) == 54 and all(r["matches"] for r in actual.values()), {
        "expected_count": 54, "roster_count": len(roster), "matched_count": sum(r["matches"] for r in actual.values()),
        "mismatches": [p for p, r in actual.items() if not r["matches"]],
    })


def verify_library_sync(report: dict[str, Any], library_successors: dict[str, tuple[str, str]] | None = None) -> None:
    """Verify the applied Unreal review-map sync against the staged static projection."""
    audit_path = REVIEW / "library-sync/STAGED_AUDIT.json"
    audit = read_json(audit_path)
    expected_policy = {
        "version": 3,
        "context": "Static Blender cutaways and Unreal Diorama only; live LI source rows unchanged",
        "omitted_semantic_keys": list(OMITTED_STATIC_KEYS),
        "reason": "The actual windlass fixed mount is runtime-owned and absent from the static cutaway. Do not display unsupported lantern geometry or invent a stand/control.",
        "runtime_reference": "docs/art/warrens-c-gameplay-review-20261024/ART_held_sluice.png",
        "runtime_reference_sha256": "b2f4354066e80543d57747e91f6695aab3a41df3536ee3893bbba7dc8a53b09c",
    }
    try:
        sync_dir = ROOT / "Tools/WarrensVariantCKit"
        sys.path.insert(0, str(sync_dir))
        projection_module = importlib.import_module("sync_art_libraries")
        projection = projection_module.projection()
        projected_omissions = projection.get("omitted", [])
        source_rows = len(read_json(sync_dir / "P2SlidingSpan/readability_delta.json").get("placements", []))
        projection_source_sha = sha256(sync_dir / "sync_art_libraries.py")
        projection_ok = projection.get("spec_sha256") == LIBRARY_SYNC_SPEC_SHA256
        projection_ok = bool(projection_ok and projection.get("presentation_policy") == expected_policy
                             and audit.get("spec_sha256") == LIBRARY_SYNC_SPEC_SHA256
                             and audit.get("tool_sha256") == projection_source_sha
                             and audit.get("source_live_fixture_rows") == 11
                             and audit.get("static_fixture_rows") == 8
                             and len(projection.get("effective", [])) == 32646
                             and len(projection.get("additions", [])) == 517
                             and len(projection.get("removals", [])) == 214
                             and len(projection.get("lights", [])) == 4
                             and len(projection.get("base", {}).get("placements", [])) == 37511
                             and len(projection.get("old", [])) == 32343
                             and source_rows == 11
                             and len(projected_omissions) == 3
                             and {row.get("semantic_key") for row in projected_omissions} == set(OMITTED_STATIC_KEYS))
    except Exception as exc:
        check(report, "V3 static library projection policy", False, {"error": f"{type(exc).__name__}: {exc}"})
        return
    check(report, "V3 static library projection policy", projection_ok, {
        "spec_sha256": projection.get("spec_sha256"), "expected_spec_sha256": LIBRARY_SYNC_SPEC_SHA256,
        "staged_audit_spec_sha256": audit.get("spec_sha256"), "projection_source_sha256": projection_source_sha,
        "staged_audit_tool_hash_matches": audit.get("tool_sha256") == projection_source_sha,
        "effective_rows": len(projection.get("effective", [])), "additions": len(projection.get("additions", [])),
        "removals": len(projection.get("removals", [])), "live_fixture_source_rows": source_rows,
        "omitted_keys": sorted(row.get("semantic_key") for row in projected_omissions),
        "policy_matches": projection.get("presentation_policy") == expected_policy,
        "static_counts": projection.get("zones", {}),
        "boundary": "Pure projection/source-input validation; no live Level Instance state read.",
    })

    receipts = {}
    rows = {}
    for name, path in (("Diorama", ART_MAPS["Diorama"]), ("KitLibrary", ART_MAPS["KitLibrary"])):
        receipt_path = LIBRARY_SYNC / f"{name}.json"
        if not receipt_path.is_file():
            pending(report, f"Unreal v3 art-library sync {name}", {"missing_receipt": str(receipt_path.relative_to(ROOT))})
            continue
        rec = read_json(receipt_path)
        receipts[name] = rec
        legacy = read_json(ART / f"applied_{name}.json")
        actual, error = file_hash(path)
        backup = ROOT / rec.get("backup", "")
        backup_hash = sha256(backup) if backup.is_file() else None
        omissions = rec.get("context_dependent_omissions", [])
        omission_rows_ok = len(omissions) == 3 and {row.get("semantic_key") for row in omissions} == set(OMITTED_STATIC_KEYS)
        omission_meshes = {row.get("semantic_key"): row.get("source_row", {}).get("mesh_id") for row in omissions}
        expected_meshes = {"p2_fixture_wheel_cage": "CCS60", "p2_fixture_wheel_glass": "CCS61", "p2_fixture_wheel_flame": "CCS64"}
        omission_rows_ok = bool(omission_rows_ok and omission_meshes == expected_meshes
                                and all(row.get("source_row", {}).get("tile") == "Brineworks" for row in omissions))
        policy_ok = rec.get("presentation_policy") == expected_policy and omission_rows_ok
        chain_ok = rec.get("status") == "APPLIED" and rec.get("before_sha256") == legacy.get("after_sha256")
        chain_ok = bool(chain_ok and rec.get("source_spec") == LIBRARY_SYNC_SPEC_SHA256
                        and rec.get("spec_sha256") == LIBRARY_SYNC_SPEC_SHA256
                        and _matches_exact_successor(path, rec.get("after_sha256"), actual, library_successors or {}) and backup_hash == rec.get("before_sha256")
                        and rec.get("collision_files_preserved") == 54 and rec.get("original_catalog_instances") == 196
                        and rec.get("unchanged_roster") and rec.get("sync_roster") and policy_ok)
        if name == "Diorama":
            chain_ok = bool(chain_ok and rec.get("removed") == 214 and rec.get("added") == 516 and rec.get("added_instances") == 516)
        else:
            chain_ok = bool(chain_ok and rec.get("removed") == 0 and rec.get("added") == 3 and rec.get("added_instances") == 3)
        rows[name] = {"path": path, "status": rec.get("status"), "current_sha256": actual,
                      "receipt_after_sha256": rec.get("after_sha256"), "legacy_after_sha256": legacy.get("after_sha256"),
                      "before_chains_to_legacy": rec.get("before_sha256") == legacy.get("after_sha256"),
                      "backup_matches_before": backup_hash == rec.get("before_sha256"), "error": error,
                      "operations": {"removed": rec.get("removed"), "added": rec.get("added")},
                      "catalog_entries": rec.get("original_catalog_instances"), "collision_files_preserved": rec.get("collision_files_preserved"),
                      "omissions": omission_meshes, "policy_matches": policy_ok,
                      "unchanged_roster_entries": len(rec.get("unchanged_roster", {})),
                      "sync_roster_entries": len(rec.get("sync_roster", {})), "chain_valid": chain_ok}
    if len(rows) == 2:
        check(report, "Unreal review-map v3 receipt and hash chains", all(row["chain_valid"] for row in rows.values()), rows)


def verify_p2_worn_pack_walk(report: dict[str, Any]) -> None:
    operation_path = REVIEW / "P2_ART_OPERATION.json"
    movement_path = RUN / "P2_ART_stage2_worn_pack_walk_forward.json"
    if not operation_path.is_file() or not movement_path.is_file():
        pending(report, "P2 stage-2 raw-input crossing observation", {
            "operation": str(operation_path.relative_to(ROOT)), "movement": str(movement_path.relative_to(ROOT))})
        return
    operation = read_json(operation_path)
    movement = read_json(movement_path)
    events = {row.get("label"): row for row in operation.get("events", [])}
    partial = events.get("partial_after_release", {})
    seated = events.get("seated_after_release", {})
    part_xyz = lambda event, part: [row.get("at") for row in event.get("parts", []) if row.get("part", "").endswith(part)]
    guards_partial, cage_partial, deck_partial = (part_xyz(partial, "SlidingBridge_Guard"),
                                                   part_xyz(partial, "SlidingBridge_Cage"),
                                                   part_xyz(partial, "SlidingBridge_Deck"))
    guards_seated, cage_seated, deck_seated = (part_xyz(seated, "SlidingBridge_Guard"),
                                                part_xyz(seated, "SlidingBridge_Cage"),
                                                part_xyz(seated, "SlidingBridge_Deck"))
    operation_ok = len(events) == 4 and len(guards_partial) == 2 and len(cage_partial) == len(deck_partial) == 1
    operation_ok = bool(operation_ok and len(guards_seated) == 2 and len(cage_seated) == len(deck_seated) == 1
                        and abs(cage_partial[0][0] - 1579.3615) < 0.1 and abs(deck_partial[0][0] - cage_partial[0][0]) < 0.01
                        and abs(cage_seated[0][0] - 900.0) < 0.01 and abs(deck_seated[0][0] - cage_seated[0][0]) < 0.01
                        and all(abs(p[2] + 250.0) < 0.1 for p in guards_partial)
                        and all(abs(p[2] + 30.0) < 0.1 for p in guards_seated)
                        and "No puzzle/source/guard/deck assignments" in operation.get("boundary", ""))

    samples = movement.get("samples", [])
    gap_samples = [row for row in samples if abs(row.get("at", [0, 0, 0])[2] + 142.8537) < 0.01]
    movement_ok = movement.get("action") == "/Script/AngelscriptAssets.Mars_IA_Move"
    movement_ok = bool(movement_ok and movement.get("axis") == [1, 0, 0] and movement.get("seconds") == 12
                        and movement.get("boundary", "").startswith("Real Move action injected through Enhanced Input")
                        and len(samples) == 79 and len(gap_samples) == 17
                        and all(row["t"] < 12 for row in gap_samples)
                        and gap_samples[0]["at"][0] > 879 and gap_samples[-1]["at"][0] < -128
                        and all(abs(row["at"][1] + 3500.0) < 0.01 for row in gap_samples)
                        and movement.get("initial", [0])[0] > 879 and movement.get("final", [0])[0] < -128)
    check(report, "P2 stage-2 raw mechanism and movement observation receipts", operation_ok and movement_ok, {
        "operation_sha256": sha256(operation_path), "movement_sha256": sha256(movement_path),
        "observed_event_labels": sorted(events), "partial_cage_xyz": cage_partial, "seated_cage_xyz": cage_seated,
        "partial_guard_z": [row[2] for row in guards_partial], "seated_guard_z": [row[2] for row in guards_seated],
        "movement_axis": movement.get("axis"), "movement_seconds": movement.get("seconds"),
        "movement_initial_xyz": movement.get("initial"), "movement_final_xyz": movement.get("final"),
        "samples": len(samples), "gap_height_samples": len(gap_samples),
        "gap_sample_t_first_last": [gap_samples[0]["t"], gap_samples[-1]["t"]] if gap_samples else None,
        "gap_sample_x_first_last": [gap_samples[0]["at"][0], gap_samples[-1]["at"][0]] if gap_samples else None,
        "cargo_state": "Not present in the movement receipt; no loaded/worn-pack cargo claim is verified by this check.",
        "boundary": "Saved raw-input/runtime observations only; not physical keyboard evidence, full bypass acceptance or comprehensive traversal testing.",
    })


def verify_blender_promotion(report: dict[str, Any], library_successors: dict[str, tuple[str, str]] | None = None) -> None:
    promotion_path = BLEND_PROMOTION / "promotion.json"
    if not promotion_path.is_file():
        pending(report, "Promoted original Blender library sources", {"missing_receipt": str(promotion_path.relative_to(ROOT))})
        return
    promotion = read_json(promotion_path)
    specs = read_json(REVIEW / "library-sync/STAGED_AUDIT.json")
    source_paths = {
        "Diorama": "Tools/WarrensVariantCKit/Output/WarrensVariantC_Diorama.blend",
        "KitLibrary": "Tools/WarrensVariantCKit/Output/WarrensVariantC_KitLibrary.blend",
    }
    targets = promotion.get("targets", {})
    rows = {}
    changed_originals = set(source_paths.values())
    for name, source in source_paths.items():
        rec = targets.get(name, {})
        stage_record = read_json(ROOT / rec["stage_receipt"]) if rec.get("stage_receipt") and (ROOT / rec["stage_receipt"]).is_file() else {}
        current, error = file_hash(source)
        staged_path = rec.get("staged")
        staged_hash = sha256(ROOT / staged_path) if staged_path and (ROOT / staged_path).is_file() else None
        backup_path = ROOT / rec.get("backup", "")
        backup_hash = sha256(backup_path) if backup_path.is_file() else None
        expected_staged = specs.get("targets", {}).get(name, {}).get("staged_sha256")
        target_ok = bool(rec and rec.get("source") == source
                         and _matches_exact_successor(source, rec.get("after_sha256"), current, library_successors or {})
                         and rec.get("after_sha256") == expected_staged and staged_hash == rec.get("after_sha256")
                         and backup_hash == rec.get("before_sha256")
                         and stage_record.get("status") == "STAGED"
                         and stage_record.get("stage_sha256") == rec.get("after_sha256")
                         and stage_record.get("source_sha256") == rec.get("before_sha256"))
        rows[name] = {"source": source, "current_sha256": current, "promoted_sha256": rec.get("after_sha256"),
                      "stage_matches_promoted": staged_hash == rec.get("after_sha256"),
                      "original_backup_matches_before": backup_hash == rec.get("before_sha256"),
                      "stage_receipt_valid": stage_record.get("status") == "STAGED" and stage_record.get("stage_sha256") == rec.get("after_sha256"),
                      "error": error, "valid": target_ok}

    protected = promotion.get("protected_before", {})
    protected_rows = {}
    for rel, expected in protected.items():
        norm = rel.replace("\\", "/")
        if norm in changed_originals:
            continue
        actual, error = file_hash(norm)
        protected_rows[norm] = {"expected": expected, "actual": actual,
                                "matches": _matches_exact_successor(norm, expected, actual, library_successors or {}), "error": error}
    protected_ok = len(protected) == 464 and len(protected_rows) == len(protected) - len(changed_originals) \
        and all(row["matches"] for row in protected_rows.values())
    promo_ok = (promotion.get("status") == "PROMOTED" and promotion.get("spec_sha256") == LIBRARY_SYNC_SPEC_SHA256
                and promotion.get("static_count") == 32646 and promotion.get("catalog_count") == 196
                and set(targets) == set(source_paths) and all(row["valid"] for row in rows.values()) and protected_ok)
    check(report, "v3 original Blender promotion and protected-file hashes", promo_ok, {
        "receipt_sha256": sha256(promotion_path), "spec_sha256": promotion.get("spec_sha256"),
        "static_count": promotion.get("static_count"), "catalog_count": promotion.get("catalog_count"),
        "targets": rows, "protected_before_count": len(protected),
        "protected_current_count": len(protected_rows),
        "protected_mismatches": [path for path, row in protected_rows.items() if not row["matches"]],
        "collision_files_preserved": sum("CkJoltData" in path for path in protected_rows),
        "claim_boundary": "Saved source and protected-file hashes; not a complete Blender reopen-content audit.",
    })

    reopen_rows = {}
    missing = []
    for name, source in source_paths.items():
        path = BLEND_PROMOTION / f"{name}_reopened.json"
        if not path.is_file():
            missing.append(str(path.relative_to(ROOT)))
            continue
        record = read_json(path)
        reopened_sha = record.get("source_sha256", record.get("package_sha256", record.get("after_sha256")))
        # Reopen reports may record either the opened filepath's current hash or
        # the promoted source hash. Capture schema and reported counts without
        # treating an unknown schema as passing.
        audit = record.get("audit", record.get("verification", {}))
        expected_audit = specs.get("targets", {}).get(name, {}).get("audit", {})
        audit_ok = (audit.get("catalog_entries") == 196 and audit.get("unchanged_objects") == 64701
                    and audit.get("original_meshes") == 205 and audit.get("original_materials") == 70
                    and audit.get("original_packed_images") == 139 and audit.get("original_lights") == 28
                    and audit.get("original_cameras") == 14 and audit.get("new_light_datablocks") == 0
                    and audit.get("source_metadata_only") is True
                    and audit.get("counts") == expected_audit.get("counts"))
        valid = bool(record.get("status") == "REOPENED_ORIGINAL_VERIFIED"
                     and reopened_sha == targets.get(name, {}).get("after_sha256") and audit_ok)
        reopen_rows[name] = {"status": record.get("status"), "source_sha256": reopened_sha,
                             "matches_promoted": reopened_sha == targets.get(name, {}).get("after_sha256"),
                             "audit_keys": sorted(audit) if isinstance(audit, dict) else None,
                             "audit_core_counts_match": audit_ok,
                             "valid": valid, "record_sha256": sha256(path)}
    if missing:
        pending(report, "Fresh original Blender reopen audit", {"missing_receipts": missing, "available": reopen_rows})
    else:
        check(report, "Fresh original Blender reopen audit", all(row["valid"] for row in reopen_rows.values()), reopen_rows)


def is_dark(color: list[float]) -> bool:
    return len(color) >= 3 and all(channel < 0.1 for channel in color[:3])


def is_orange(color: list[float]) -> bool:
    return len(color) >= 3 and color[0] > 0.9 and color[1] > 0.5 and 0.05 < color[2] < 0.3


def verify_p4_saved_feedback(report: dict[str, Any]) -> None:
    base = REVIEW
    wrong_path = base / "P4_ART_SAVED_WRONG_RESET.json"
    flash_path = base / "P4_ART_SAVED_FLASH.json"
    solve_path = base / "P4_ART_SAVED_SOLVE.json"
    acceptance_path = base / "P4_ART_RUNTIME_ACCEPTANCE.md"
    wrong = read_json(wrong_path)
    flash = read_json(flash_path)
    solve = read_json(solve_path)
    acceptance = acceptance_path.read_text(encoding="utf-8-sig")

    wrong_rows = wrong.get("rows", [])
    wrong_lamps = [r for r in wrong_rows if r.get("part", "").endswith("Bellkeeper_Lamp")]
    wrong_candles = [r for r in wrong_rows if r.get("part", "").endswith("Bellkeeper_Candle")]
    wrong_ok = len(wrong_lamps) == 1 and len(wrong_candles) == 3 and is_dark(wrong_lamps[0]["color"]) \
        and sum(is_orange(r["color"]) for r in wrong_candles) == 2 \
        and "actual raw aim/grip/look/pull" in wrong.get("boundary", "")
    check(report, "P4 first wrong commit retains two reward candles", wrong_ok, {
        "capture_sha256": sha256(wrong_path), "lamp_dark": len(wrong_lamps) == 1 and is_dark(wrong_lamps[0]["color"]),
        "lit_reward_candles": sum(is_orange(r["color"]) for r in wrong_candles),
        "required_lit_candles": 2, "actual_input_boundary": wrong.get("boundary"),
    })

    changes = flash.get("changes", [])
    red_index = next((i for i, item in enumerate(changes)
                      if is_red(item.get("state", {}).get("lamp", []))), None)
    pair = None
    if red_index is not None:
        red_event = changes[red_index]
        reset = next((item for item in changes[red_index + 1:]
                      if is_dark(item.get("state", {}).get("lamp", []))), None)
        if reset:
            pair = (red_event, reset)
    observer_read_only = "read-only per-frame" in flash.get("boundary", "").casefold()
    flash_ok = bool(pair and flash.get("saw_red") and flash.get("reset_observed") and observer_read_only)
    if pair:
        red, reset = pair
        flash_ok = flash_ok and 0 < reset["t"] - red["t"] <= 1.1 \
            and sum(is_orange(c) for c in red["state"].get("candles", [])) == 1 \
            and sum(is_orange(c) for c in reset["state"].get("candles", [])) == 1
    check(report, "P4 second wrong flash returns dark and retains last candle", bool(flash_ok), {
        "capture_sha256": sha256(flash_path),
        "red_time": pair[0]["t"] if pair else None,
        "reset_time": pair[1]["t"] if pair else None,
        "flash_duration_seconds": pair[1]["t"] - pair[0]["t"] if pair else None,
        "lit_candles_at_red": sum(is_orange(c) for c in pair[0]["state"].get("candles", [])) if pair else None,
        "lit_candles_after_reset": sum(is_orange(c) for c in pair[1]["state"].get("candles", [])) if pair else None,
        "read_only_observer": observer_read_only,
    })

    events = {event.get("label"): event for event in solve.get("events", [])}
    initial_parts = events.get("initial", {}).get("parts", [])
    solved_parts = events.get("after_solve_attempt", {}).get("parts", [])
    initial_lamp = next((r for r in initial_parts if r.get("part", "").endswith("Bellkeeper_Lamp")), None)
    solved_lamp = next((r for r in solved_parts if r.get("part", "").endswith("Bellkeeper_Lamp")), None)
    initial_pointers = [r for r in initial_parts if r.get("part", "").endswith("Bellkeeper_Pointer")]
    solved_pointers = [r for r in solved_parts if r.get("part", "").endswith("Bellkeeper_Pointer")]
    steps = solve.get("steps", [])
    required_steps = ("aim dial 0", "grip dial 0", "turn dial 0", "release dial 0", "aim dial 1",
                      "grip dial 1", "turn dial 1", "release dial 1", "aim dial 2", "grip dial 2",
                      "turn dial 2", "release dial 2", "aim correct commit", "grip correct commit",
                      "pull correct commit", "release correct commit", "solved sample")
    correction = "all three dials actually began at Square, the first input was90 degrees, and no diagnostic lantern-light relocation was active"
    solve_ok = bool(solve.get("error") is None and initial_lamp and solved_lamp
                    and is_dark(initial_lamp.get("color", []))
                    and len(initial_pointers) == 3 and len(solved_pointers) == 3
                    and all(any(abs(a - b) > 1.0 for a, b in zip(old.get("rotation", []), new.get("rotation", [])))
                            for old, new in zip(initial_pointers, solved_pointers))
                    and solved_lamp.get("color", [])[0] > 0.08
                    and solved_lamp.get("color", [])[1] > 0.8
                    and solved_lamp.get("color", [])[2] > 0.15
                    and all(step in steps for step in required_steps)
                    and correction in acceptance)
    check(report, "P4 saved raw-input solve and authoritative boundary correction", solve_ok, {
        "capture_sha256": sha256(solve_path),
        "acceptance_note_sha256": sha256(acceptance_path),
        "error": solve.get("error"),
        "initial_lamp_dark": bool(initial_lamp and is_dark(initial_lamp.get("color", []))),
        "solved_lamp_color": solved_lamp.get("color") if solved_lamp else None,
        "pointer_count_initial_and_solved": [len(initial_pointers), len(solved_pointers)],
        "raw_grip_turn_release_commit_steps_present": all(step in steps for step in required_steps),
        "authoritative_initial_detent_and_lighting_correction_present": correction in acceptance,
        "inherited_json_boundary_ignored": True,
        "json_boundary_text": solve.get("boundary"),
        "claim_boundary": "saved opted-in PIE interaction/feedback; no held-lantern, novice, co-op, or packaged acceptance",
    })


def _wheel_roster_projection(record: dict[str, Any]) -> dict[str, Any]:
    """Drop only the target actor's separately recorded wheel presentation fields."""
    roster = record.get("source_world_roster_before", {})
    actors = roster.get("actors", [])
    projected = []
    target_count = 0
    for actor in actors:
        row = json.loads(json.dumps(actor))
        if row.get("label") == "WVC_P2_SlidingSpan":
            target_count += 1
            row.pop("wheel_art", None)
        projected.append(row)
    return {
        "source_world": roster.get("source_world"),
        "actor_count": roster.get("actor_count"),
        "actors": projected,
        "target_count": target_count,
    }


def _wheel_fields_from_roster(record: dict[str, Any], which: str) -> dict[str, Any] | None:
    roster = record.get(which, {})
    matches = [actor.get("wheel_art") for actor in roster.get("actors", [])
               if actor.get("label") == "WVC_P2_SlidingSpan"]
    return matches[0] if len(matches) == 1 else None


def _normalize_wheel_asset_ref(value: Any) -> Any:
    if not isinstance(value, str):
        return value
    package, dot, object_name = value.rpartition(".")
    if dot and package.rsplit("/", 1)[-1] == object_name:
        return package
    return value


def verify_p2_wheel_retention(report: dict[str, Any], canonical_parity_ok: bool = False, belfry_palette_ok: bool = False,
                              library_successors: dict[str, tuple[str, str]] | None = None) -> bool:
    """Verify the exact immutable stage chain and separately supplied approval evidence."""
    names = {
        "mesh": "p2_wheel_staged_20261025T052524814606Z.json",
        "offset": "p2_wheel_offset_staged_20261025T054034254658Z.json",
        "offset_postverify": "p2_wheel_offset_staged_20261025T054034254658Z_postverify.json",
        "material": "p2_wheel_material_staged_20261025T054830046172Z.json",
    }
    paths = {key: WHEEL / value for key, value in names.items()}
    missing = [str(path.relative_to(ROOT)) for path in paths.values() if not path.is_file()]
    if missing:
        pending(report, "P2 wheel staged retention chain", {"missing_receipts": missing})
        return False
    records = {key: read_json(path) for key, path in paths.items()}
    mesh, offset, post, material = (records[key] for key in ("mesh", "offset", "offset_postverify", "material"))
    hashes = {key: sha256(path) for key, path in paths.items()}
    map_rel = "Content/Mars/Maps/Variants/v8c/LI_Warrens_Canal.umap"
    map_path = ROOT / map_rel
    current_map_hash = sha256(map_path) if map_path.is_file() else None
    original_hash = "001f554db780f507a568ee7c71ba106d904c3069e916915c852ef68f09fec5d8"
    mesh_hash = "56e6c02ea2d835a08497910a0690e3885dfcc8c85301887532527020a7bb1b50"
    offset_hash = "62613e784da33bf1db8afb6e44d1a9071c82b1df5632d1dd7cc8fa8cf8d217c9"
    tile_package = "/Game/Mars/Maps/Variants/v8c/LI_Warrens_Canal"

    checkpoints = {}
    for key, record, expected in (("mesh", mesh, original_hash), ("offset", offset, mesh_hash),
                                  ("material", material, offset_hash)):
        checkpoint = ROOT / record.get("checkpoint", "")
        actual = sha256(checkpoint) if checkpoint.is_file() else None
        checkpoints[key] = {"path": record.get("checkpoint"), "expected": expected,
                            "receipt": record.get("checkpoint_sha256"), "actual": actual,
                            "matches": record.get("checkpoint_sha256") == expected == actual}

    chain_status = (
        mesh.get("status") == "STAGED_CANAL_SAVED"
        and mesh.get("target_package") == tile_package
        and mesh.get("before_sha256") == original_hash
        and mesh.get("after_sha256") == mesh_hash
        and offset.get("status") == "POST_SAVE_CHECKS_PENDING"
        and offset.get("target_package") == tile_package
        and offset.get("previous_receipt") == str(paths["mesh"].relative_to(ROOT)).replace("\\", "/")
        and offset.get("previous_receipt_sha256") == hashes["mesh"]
        and offset.get("before_sha256") == mesh_hash
        and offset.get("after_sha256") == offset_hash
        and post.get("status") == "STAGED_OFFSET_POST_SAVE_VERIFIED"
        and post.get("stage_receipt_sha256") == hashes["offset"]
        and post.get("after_sha256") == offset_hash
        and post.get("only_delta") == "WheelMeshLocalTransform.translation [0,0,0] to [2.5,0,0]"
        and material.get("status") == "STAGED_CANAL_MATERIAL_SAVED"
        and material.get("target_package") == tile_package
        and material.get("before_sha256") == offset_hash
        and material.get("after_sha256") == current_map_hash
        and material.get("offset_receipt") == str(paths["offset"].relative_to(ROOT)).replace("\\", "/")
        and material.get("offset_receipt_sha256") == hashes["offset"]
        and material.get("offset_postverify_receipt") == str(paths["offset_postverify"].relative_to(ROOT)).replace("\\", "/")
        and material.get("offset_postverify_receipt_sha256") == hashes["offset_postverify"]
    )
    identity_transform = {"location": [0.0, 0.0, 0.0],
                          "rotation_xyzw": [0.0, -0.0, 0.7071067690849304, 0.7071067690849304],
                          "scale": [1.0, 1.0, 1.0]}
    offset_transform = {"location": [2.5, 0.0, 0.0],
                        "rotation_xyzw": [0.0, -0.0, 0.7071067690849304, 0.7071067690849304],
                        "scale": [1.0, 1.0, 1.0]}
    mesh_asset = "/Game/Mars/Environment/ChainCrossingKit/Meshes/WarrensC_CCS21_HandwheelBody_Mars_SM"
    fields_ok = (
        mesh.get("before_art_fields", {}).get("WheelMeshOverride") is None
        and mesh.get("before_art_fields", {}).get("WheelMeshLocalTransform") == {"location": [0.0, 0.0, 0.0], "rotation_xyzw": [0.0, -0.0, 0.0, 1.0], "scale": [1.0, 1.0, 1.0]}
        and mesh.get("candidate_art_fields", {}).get("WheelMeshOverride") == mesh_asset
        and mesh.get("candidate_art_fields", {}).get("WheelMeshLocalTransform") == identity_transform
        and mesh.get("candidate_art_fields", {}).get("WheelMaterialOverride") is None
        and offset.get("before_art_fields", {}).get("WheelMeshOverride", "").endswith("/WarrensC_CCS21_HandwheelBody_Mars_SM.WarrensC_CCS21_HandwheelBody_Mars_SM")
        and offset.get("before_art_fields", {}).get("WheelMeshLocalTransform") == identity_transform
        and offset.get("before_art_fields", {}).get("WheelMaterialOverride") is None
        and offset.get("candidate_art_fields", {}).get("WheelMeshOverride") == mesh_asset
        and offset.get("candidate_art_fields", {}).get("WheelMeshLocalTransform") == offset_transform
        and offset.get("candidate_art_fields", {}).get("WheelMaterialOverride") is None
        and material.get("before_art_fields", {}).get("WheelMeshOverride", "").endswith("/WarrensC_CCS21_HandwheelBody_Mars_SM.WarrensC_CCS21_HandwheelBody_Mars_SM")
        and material.get("before_art_fields", {}).get("WheelMeshLocalTransform") == offset_transform
        and material.get("candidate_art_fields", {}).get("WheelMeshOverride") == mesh_asset
        and material.get("candidate_art_fields", {}).get("WheelMeshLocalTransform") == offset_transform
        and material.get("candidate_art_fields", {}).get("WheelMaterialOverride", "").endswith("/M_CCK_TX09.M_CCK_TX09")
        and material.get("before_art_fields", {}).get("WheelMaterialOverride") is None
    )
    for record in (mesh, offset, material):
        before_fields = _wheel_fields_from_roster(record, "source_world_roster_before")
        after_fields = _wheel_fields_from_roster(record, "source_world_roster_after")
        expected_before = record.get("before_art_fields", {})
        expected_after = record.get("candidate_art_fields", {})
        if before_fields is None or after_fields is None:
            fields_ok = False
            continue
        fields_ok = fields_ok and {
            name: _normalize_wheel_asset_ref(value) for name, value in before_fields.items()
        } == {
            name: _normalize_wheel_asset_ref(value) for name, value in expected_before.items()
        } and {
            name: _normalize_wheel_asset_ref(value) for name, value in after_fields.items()
        } == {
            name: _normalize_wheel_asset_ref(value) for name, value in expected_after.items()
        }

    roster_rows = {}
    projections = []
    for key, record in (("mesh", mesh), ("offset", offset), ("material", material)):
        before_projection = _wheel_roster_projection(record)
        after_record = dict(record)
        after_record["source_world_roster_before"] = record.get("source_world_roster_after", {})
        after_projection = _wheel_roster_projection(after_record)
        roster_rows[key] = {
            "before_count": before_projection.get("actor_count"),
            "after_count": after_projection.get("actor_count"),
            "target_count_before_after": [before_projection.get("target_count"), after_projection.get("target_count")],
            "non_wheel_projection_equal": before_projection == after_projection,
        }
        projections.append(after_projection)
    roster_ok = all(row["before_count"] == row["after_count"] == 50
                    and row["target_count_before_after"] == [1, 1]
                    and row["non_wheel_projection_equal"] for row in roster_rows.values())
    roster_ok = roster_ok and projections[0] == projections[1] == projections[2]

    collision_rows = {}
    baseline_collisions = read_json(RUN / "StartupCheckpoint/collision_hashes.json")
    for key, record in (("mesh", mesh), ("offset", offset), ("material", material)):
        before = record.get("collision_before", {}).get("files", {})
        after = record.get("collision_after", {}).get("files", {})
        collision_rows[key] = {
            "before_count": record.get("collision_before", {}).get("count"),
            "after_count": record.get("collision_after", {}).get("count"),
            "before_after_equal": before == after,
            "matches_54_baseline": before == baseline_collisions,
        }
    collision_ok = all(row["before_count"] == row["after_count"] == 54
                       and row["before_after_equal"] and row["matches_54_baseline"]
                       for row in collision_rows.values())

    canonical_parity = read_json(CANONICAL_PARITY) if CANONICAL_PARITY.is_file() else {}
    canonical_files = canonical_parity.get("files", {}) if canonical_parity_ok else {}
    canonical_relatives = set(CANONICAL_WHEEL_FILES[:2])
    protected_rows = {}
    for key, record in (("mesh", mesh), ("offset", offset), ("material", material)):
        before = record.get("protected_files_before", {})
        after = record.get("protected_files_after", {})
        unchanged = {rel: digest for rel, digest in after.items() if rel != map_rel}
        current = {}
        parity_current = {}
        for rel, digest in unchanged.items():
            value, error = file_hash(rel)
            parity = canonical_files.get(rel) if rel in canonical_relatives else None
            if parity:
                matches = (before.get(rel) == digest == parity.get("before_sha256")
                           and value == parity.get("after_sha256"))
                parity_current[rel] = {"receipt_before": parity.get("before_sha256"),
                                       "receipt_after": parity.get("after_sha256"),
                                       "stage_baseline": digest, "actual": value,
                                       "matches": matches, "error": error}
            else:
                palette_supersedes = (belfry_palette_ok and rel == ART_MAPS["Belfry"]
                                      and digest == BELFRY_MAP_BEFORE and value == BELFRY_MAP_AFTER)
                current[rel] = {"expected": digest, "actual": value,
                                "matches": _matches_exact_successor(rel, digest, value, library_successors or {}) or palette_supersedes,
                                "superseded_by_exact_Belfry_palette_chain": palette_supersedes, "error": error}
        protected_rows[key] = {
            "before_count": len(before), "after_count": len(after), "other_count": len(unchanged),
            "other_before_after_equal": {r: before.get(r) == after.get(r) for r in unchanged},
            "stable_file_count": len(current),
            "stable_current_match_count": sum(item["matches"] for item in current.values()),
            "other_current_mismatches": [r for r, item in current.items() if not item["matches"]],
            "approved_canonical_files": parity_current,
            "protected_changes": record.get("protected_changes"),
        }
    protected_ok = all(row["before_count"] == row["after_count"] == 20 and row["other_count"] == 19
                       and all(row["other_before_after_equal"].values())
                       and row["stable_file_count"] == 17
                       and row["stable_current_match_count"] == 17
                       and not row["other_current_mismatches"]
                       and set(row["approved_canonical_files"]) == canonical_relatives
                       and all(item["matches"] for item in row["approved_canonical_files"].values())
                       and row["protected_changes"] == {}
                       for row in protected_rows.values())
    lifecycle_ok = all(record.get("saved") is True and record.get("auto_cook_setting_restored") is True
                       and record.get("dirty_packages_after") == {"maps": [], "content": []}
                       for record in (mesh, offset, material))
    chain_ok = bool(chain_status and fields_ok and all(row["matches"] for row in checkpoints.values())
                    and current_map_hash == material.get("after_sha256") and roster_ok and collision_ok
                    and protected_ok and lifecycle_ok)
    check(report, "P2 exact staged wheel map and protected-roster chain", chain_ok, {
        "receipts": {key: {"path": str(paths[key].relative_to(ROOT)), "sha256": hashes[key], "status": records[key].get("status")}
                     for key in names if key != "offset_postverify"},
        "offset_postverify": {"path": str(paths["offset_postverify"].relative_to(ROOT)), "sha256": hashes["offset_postverify"], "status": post.get("status")},
        "chain_fields_match": chain_status, "permitted_visual_fields_match": fields_ok,
        "checkpoints": checkpoints, "current_canal_sha256": current_map_hash,
        "source_world_rosters": roster_rows, "roster_consistent_across_stages": projections[0] == projections[1] == projections[2],
        "collision_rosters": collision_rows, "protected_file_rosters": protected_rows,
        "saved_cook_restored_and_clean": lifecycle_ok,
        "historical_offset_receipt_status_preserved": offset.get("status"),
    })

    # The final approval receipt is written by the owner after reviewing exact
    # runtime evidence. Absence remains pending; this verifier never creates it.
    approval_path = REVIEW / "P2_WHEEL_RETENTION.json"
    if not approval_path.is_file():
        pending(report, "P2 wheel final retention approval receipt", {
            "expected_receipt": str(approval_path.relative_to(ROOT)),
            "write_schema": {
                "status": "APPROVED",
                "review_source": "docs/art/warrens-c-gameplay-review-20261024/P2_WHEEL_STAGED_BINDING_REVIEW.md",
                "review_source_sha256": "<sha256 of current review source>",
                "stage_receipt": "Saved/WarrensCGameplay-20261024/WheelArtCheckpoint/p2_wheel_material_staged_20261025T054830046172Z.json",
                "stage_receipt_sha256": hashes["material"],
                "evidence": {
                    "identity": {"path": "docs/art/warrens-c-gameplay-review-20261024/P2_WHEEL_FINAL_IDENTITY.json", "sha256": "<current file sha256>"},
                    "front": {"path": "docs/art/warrens-c-gameplay-review-20261024/ART_held_wheel_final_front.json", "sha256": "<metadata sha256>", "image_sha256": "<png sha256>"},
                    "oblique": {"path": "docs/art/warrens-c-gameplay-review-20261024/ART_held_wheel_final_oblique.json", "sha256": "<metadata sha256>", "image_sha256": "<png sha256>"},
                    "source": {"path": "Script/WorldObjects/Mechanisms/Mars_SlidingBridge_EntityScript.as", "sha256": "<current source sha256>"},
                    "build_test": {"path": "docs/art/warrens-c-gameplay-review-20261024/P2_WHEEL_BUILD_TEST.json", "sha256": "<metadata sha256>"},
                    "offset_postverify": {"path": str(paths["offset_postverify"].relative_to(ROOT)).replace("\\", "/"), "sha256": hashes["offset_postverify"]},
                },
            },
        })
        return chain_ok

    approval = read_json(approval_path)
    review_rel = "docs/art/warrens-c-gameplay-review-20261024/P2_WHEEL_STAGED_BINDING_REVIEW.md"
    review_sha, review_error = file_hash(review_rel)
    review_text = (ROOT / review_rel).read_text(encoding="utf-8-sig")
    identity_rel = "docs/art/warrens-c-gameplay-review-20261024/P2_WHEEL_FINAL_IDENTITY.json"
    front_rel = "docs/art/warrens-c-gameplay-review-20261024/ART_held_wheel_final_front.json"
    oblique_rel = "docs/art/warrens-c-gameplay-review-20261024/ART_held_wheel_final_oblique.json"
    source_rel = "Script/WorldObjects/Mechanisms/Mars_SlidingBridge_EntityScript.as"
    build_rel = "docs/art/warrens-c-gameplay-review-20261024/P2_WHEEL_BUILD_TEST.json"
    evidence_specs = {
        "identity": (identity_rel, None),
        "front": (front_rel, "docs/art/warrens-c-gameplay-review-20261024/ART_held_wheel_final_front.png"),
        "oblique": (oblique_rel, "docs/art/warrens-c-gameplay-review-20261024/ART_held_wheel_final_oblique.png"),
        "source": (source_rel, None),
        "build_test": (build_rel, None),
        "offset_postverify": (str(paths["offset_postverify"].relative_to(ROOT)).replace("\\", "/"), None),
    }
    evidence_rows = {}
    for key, (expected_path, image_path) in evidence_specs.items():
        row = approval.get("evidence", {}).get(key, {})
        actual, error = file_hash(expected_path)
        expected_row_path = row.get("path", "").replace("\\", "/")
        row_ok = expected_row_path == expected_path and row.get("sha256") == actual
        image_actual = None
        if image_path:
            image_actual, image_error = file_hash(image_path)
            row_ok = row_ok and row.get("image_sha256") == image_actual
            error = error or image_error
        evidence_rows[key] = {"path": expected_path, "receipt_path": expected_row_path,
                              "expected_sha256": row.get("sha256"), "actual_sha256": actual,
                              "image_sha256": image_actual, "receipt_image_sha256": row.get("image_sha256"),
                              "matches": row_ok, "error": error}
    identity = read_json(ROOT / identity_rel)
    front_meta = read_json(ROOT / front_rel)
    oblique_meta = read_json(ROOT / oblique_rel)
    build = read_json(ROOT / build_rel)
    source_sha, source_error = file_hash(source_rel)
    build_log_sha, build_log_error = file_hash(build.get("final", {}).get("log", "").replace("\\", "/"))
    image_identity_ok = (
        identity.get("stage_receipt") == str(paths["material"].relative_to(ROOT)).replace("\\", "/")
        and identity.get("source_sha") == source_sha == build.get("final", {}).get("source_sha256")
        and identity.get("mesh", "").endswith("/WarrensC_CCS21_HandwheelBody_Mars_SM")
        and identity.get("material", "").endswith("/M_CCK_TX09")
        and identity.get("collision") == "<CollisionEnabled.NO_COLLISION: 0>"
        and identity.get("pose", {}).get("scale") == [1.0, 1.0, 1.0]
        and "pack=true" in identity.get("held_inventory", "")
        and "Mars_ItemDef_Lantern" in identity.get("held_inventory", "")
        and "pack=true" in front_meta.get("inventory", "") and "pack=true" in oblique_meta.get("inventory", "")
        and front_meta.get("image_sha256") == evidence_rows["front"].get("image_sha256")
        and oblique_meta.get("image_sha256") == evidence_rows["oblique"].get("image_sha256")
        and build.get("status") == "FOCUSED_BUILD_TEST_PASS" and build.get("process_exit_code") == 0
        and build.get("final", {}).get("counts") == {"total": 3, "passed": 3, "failed": 0, "skipped": 0, "contaminated": 0}
        and build_log_sha == build.get("final", {}).get("log_sha256")
    )
    review_ok = "## Final bounded retention — APPROVED" in review_text and "Retain the final CCS21 / +2.5 cm axial adapter / TX09 wheel binding." in review_text
    approval_ok = (
        approval.get("status") == "APPROVED"
        and approval.get("review_source") == review_rel
        and approval.get("review_source_sha256") == review_sha
        and approval.get("stage_receipt") == str(paths["material"].relative_to(ROOT)).replace("\\", "/")
        and approval.get("stage_receipt_sha256") == hashes["material"]
        and all(row["matches"] for row in evidence_rows.values())
        and image_identity_ok and review_ok
    )
    check(report, "P2 wheel final runtime evidence and approval receipt", approval_ok, {
        "approval_receipt_sha256": sha256(approval_path), "review_source_sha256": review_sha,
        "review_source_error": review_error, "review_has_exact_retention_approval": review_ok,
        "approval_stage_receipt_sha256_matches": approval.get("stage_receipt_sha256") == hashes["material"],
        "evidence": evidence_rows, "identity_and_runtime_binding_match": image_identity_ok,
        "current_source_sha256": source_sha, "source_error": source_error,
        "focused_build_log_sha256": build_log_sha, "build_log_error": build_log_error,
    })
    return chain_ok


def is_red(color: list[float]) -> bool:
    return len(color) >= 3 and color[0] > 0.8 and color[1] < 0.15 and color[2] < 0.15


def verify_p2_readability(report: dict[str, Any], wheel_chain_ok: bool = False) -> None:
    # Stage 1 is historical evidence; stage 2, when present, supersedes its
    # current-map hash. Missing stage 2 is explicitly pending, never green.
    stage1 = {}
    stage2 = {}
    for tile in STAGE_TILES:
        path = P2 / f"stage1_{tile}.json"
        if not path.is_file():
            pending(report, f"P2 readability stage 1 {tile}", {"missing": str(path.relative_to(ROOT))})
            continue
        rec = read_json(path)
        backup = ROOT / rec.get("backup", "")
        backup_hash = sha256(backup) if backup.is_file() else None
        ok = rec.get("status") == "APPLIED" and rec.get("stage") == 1 and rec.get("after_sha256") and rec.get("collision_files_preserved") == 54
        ok = bool(ok and backup_hash == rec.get("before_sha256") and rec.get("added_lights") == 0 and rec.get("modified_lights") == 0)
        stage1[tile] = rec
        check(report, f"P2 readability stage 1 {tile} historical receipt", ok, {
            "status": rec.get("status"), "stage": rec.get("stage"), "before_matches_checkpoint": backup_hash == rec.get("before_sha256"),
            "after_sha256": rec.get("after_sha256"), "collision_files_preserved": rec.get("collision_files_preserved"),
            "fixture_rows": rec.get("fixture_rows"), "lights_added_or_changed": [rec.get("added_lights"), rec.get("modified_lights")],
        })

        stage2_path = P2 / f"stage2_{tile}.json"
        if not stage2_path.is_file():
            pending(report, f"P2 readability stage 2 {tile}", {"expected_receipt": str(stage2_path.relative_to(ROOT)),
                      "current_stage1_hash": file_hash(ART_MAPS.get(tile, f"Content/Mars/Maps/Variants/v8c/LI_Warrens_{tile}.umap"))[0]})
            continue
        rec2 = read_json(stage2_path)
        stage2[tile] = rec2
        rel = ART_MAPS.get(tile, f"Content/Mars/Maps/Variants/v8c/LI_Warrens_{tile}.umap")
        current, _ = file_hash(rel)
        chain_ok = rec2.get("status") == "APPLIED" and rec2.get("stage") == 2
        historical_hash_ok = current == rec2.get("after_sha256")
        superseded_by_wheel = tile == "Canal" and wheel_chain_ok
        chain_ok = bool(chain_ok and rec2.get("before_sha256") == rec.get("after_sha256")
                        and rec2.get("collision_files_preserved") == 54
                        and (historical_hash_ok or superseded_by_wheel))
        mech1 = rec.get("mechanism", {}).get("snapshot", {}).get("bridge")
        mech2 = rec2.get("mechanism", {}).get("snapshot", {}).get("bridge")
        chain_ok = bool(chain_ok and mech1 and mech2 == mech1)
        check(report, f"P2 readability stage 2 {tile} current receipt", chain_ok, {
            "status": rec2.get("status"), "stage": rec2.get("stage"), "before_matches_stage1_after": rec2.get("before_sha256") == rec.get("after_sha256"),
            "current_matches_stage2_after": historical_hash_ok,
            "current_stage2_hash_superseded_by_verified_wheel_chain": superseded_by_wheel,
            "collision_files_preserved": rec2.get("collision_files_preserved"),
            "same_single_bridge_mechanism_snapshot": bool(mech1 and mech2 == mech1),
        })

    # P2's authored mechanism/readability contract and source ledger must still
    # match the reviewed topology inputs. This is static receipt evidence, not
    # a player comprehension or runtime traversal claim.
    delta = read_json(ROOT / "Tools/WarrensVariantCKit/P2SlidingSpan/readability_delta.json")
    guard_names = (
        "Tools/WarrensVariantCKit/Output/fitted_instances.json",
        "Tools/WarrensVariantCKit/P2SlidingSpan/Output/art_delta.json",
        "Tools/LevelDesign/anchor_plans/data/warrens_v8c_p2_section.json",
    )
    guards = {}
    for rel in guard_names:
        got, error = file_hash(rel)
        expected = delta.get("source_guards", {}).get(rel)
        guards[rel] = {"expected": expected, "actual": got, "matches": got == expected, "error": error}
    contract = delta.get("required_mechanism", {})
    contract_ok = contract.get("class") == "Mars_SlidingBridge_EntityScript" and contract.get("root_plan_m") == [79, 20, -2.2]
    contract_ok = bool(contract_ok and contract.get("actual_wheel_center_plan_m") == [122, 11.5, -1.5]
                       and contract.get("policy") == "No wheel/drive/guard/deck/cage transform, component, mesh, material or interaction changes.")
    topology_ok = all(r["matches"] for r in guards.values()) and contract_ok
    check(report, "P2 source ledger and topology constraints", topology_ok, {
        "guarded_source_hashes": guards, "required_mechanism": contract,
        "claim_boundary": "static source/receipt constraints only; no gameplay readability acceptance",
    })


def verify_bd_generation(report: dict[str, Any]) -> None:
    anchor_dir = ROOT / "Tools/LevelDesign/anchor_plans"
    sys.path.insert(0, str(anchor_dir))
    try:
        builder = importlib.import_module("build_warrens")
        common = importlib.import_module("design_warrens_v8_common")
        rows = []
        for suffix, map_path in (("b", "/Game/Mars/Maps/Warrens_VariantB_Mars_MAP"),
                                 ("d", "/Game/Mars/Maps/Warrens_VariantD_Mars_MAP")):
            variant = importlib.import_module(f"design_warrens_v8{suffix}")
            builder.MAP = map_path
            data = common.build(variant)
            generated, _summary = builder.manifest(write=False, data=data)
            expected = read_json(RUN.parent / f"AnchorPlans/v8{suffix}-manifest.json")
            # JSON round-trip normalizes the builder's tuple/list representation.
            same = json.loads(json.dumps(generated, sort_keys=True)) == json.loads(json.dumps(expected, sort_keys=True))
            rows.append({"variant": suffix.upper(), "map": map_path, "matches_saved_manifest": same,
                         "current_boxes": len(generated.get("boxes", [])), "saved_boxes": len(expected.get("boxes", []))})
    except Exception as exc:  # report inability; do not substitute receipt claims
        check(report, "B/D current generation equality", False, {"error": f"{type(exc).__name__}: {exc}"})
        return
    check(report, "B/D current generation equality", all(row["matches_saved_manifest"] for row in rows), rows)


def main() -> int:
    report: dict[str, Any] = {
        "schema": 1,
        "scope": "read-only current art revision verification",
        "historical_and_current_evidence_are_separate": True,
        "checks": [],
    }
    canonical_parity_ok = verify_p2_wheel_canonical_parity(report)
    library_successors = verify_belfry_library_retention(report)
    belfry_palette_ok = verify_belfry_palette_retention(report, library_successors)
    verify_art_receipts(report, canonical_parity_ok=canonical_parity_ok, belfry_palette_ok=belfry_palette_ok, library_successors=library_successors)
    verify_collision_roster(report)
    verify_library_sync(report, library_successors)
    verify_blender_promotion(report, library_successors)
    verify_p4_saved_feedback(report)
    wheel_chain_ok = verify_p2_wheel_retention(report, canonical_parity_ok=canonical_parity_ok,
                                             belfry_palette_ok=belfry_palette_ok, library_successors=library_successors)
    verify_p2_readability(report, wheel_chain_ok=wheel_chain_ok)
    verify_p2_worn_pack_walk(report)
    verify_bd_generation(report)
    statuses = [row["status"] for row in report["checks"]]
    report["counts"] = {name.lower(): statuses.count(name) for name in ("PASS", "FAIL", "PENDING")}
    report["status"] = "FAIL" if "FAIL" in statuses else ("PENDING" if "PENDING" in statuses else "PASS")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 1 if report["status"] == "FAIL" else (2 if report["status"] == "PENDING" else 0)


if __name__ == "__main__":
    raise SystemExit(main())
