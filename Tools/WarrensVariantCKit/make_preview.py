#!/usr/bin/env python3
"""Build a local, data-derived review page for the full Warrens Variant C kit."""

from __future__ import annotations

import html
import json
import os
from pathlib import Path
from urllib.parse import quote


ROOT = Path(__file__).resolve().parents[2]
KIT = ROOT / "Tools" / "WarrensVariantCKit"
OUT = KIT / "Output"
TILE_ALIASES = {"Waterworks-W": "WaterworksW"}


def read_json(path: Path, required: bool = True):
    if not path.is_file():
        if required:
            raise FileNotFoundError(f"Required input is missing: {path}")
        return None
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def esc(value) -> str:
    return html.escape(str(value if value is not None else ""), quote=True)


def relative_link(path: Path) -> str:
    return quote(Path(os.path.relpath(path, OUT)).as_posix(), safe="/.:_-()")


def source_path_link(value: str) -> tuple[str, str] | None:
    path = ROOT / value
    if not path.is_file():
        return None
    return relative_link(path), Path(value).name


def canonical_tile(value: str) -> str:
    return TILE_ALIASES.get(value, value)


def format_dimensions(value) -> str:
    if isinstance(value, dict):
        vals = [value.get("width"), value.get("depth"), value.get("height")]
    else:
        vals = value if isinstance(value, list) else []
    if not vals or any(v is None for v in vals):
        return "dimensions unavailable"
    return " × ".join(f"{float(v):g}" for v in vals) + " cm"


def gather_source_links(row: dict, mapped: list[dict]) -> list[tuple[str, str]]:
    candidates: list[tuple[str, str]] = []
    for ref in row.get("reference_images", []):
        item = source_path_link(ref)
        if item:
            candidates.append(item)
    for mapping in mapped:
        for sheet in mapping.get("concept_sheets", []):
            path = sheet.get("path") or sheet.get("image")
            if path:
                item = source_path_link(path)
                if item:
                    candidates.append(item)
        for assembly in mapping.get("assembly_refs", []):
            for sheet in assembly.get("concept_sheets", []):
                path = sheet.get("path") or sheet.get("image")
                if path:
                    item = source_path_link(path)
                    if item:
                        candidates.append(item)
    deduped = []
    seen = set()
    for item in candidates:
        if item[0] not in seen:
            seen.add(item[0])
            deduped.append(item)
    return deduped


def preview_for(asset_id: str) -> Path | None:
    current=OUT / 'Previews' / f'{asset_id}.png'
    if current.is_file():return current
    if asset_id.startswith("WVC"):
        candidates = [OUT / "Previews" / f"{asset_id}.png"]
    elif asset_id.startswith("CCS"):
        candidates = [ROOT / "Tools" / "ChainCrossingKit" / "Output" / "Previews" / f"{asset_id}.png"]
    elif asset_id.startswith("PWC"):
        candidates = [ROOT / "Tools" / "PumpCisternKit" / "Output" / "Previews" / f"{asset_id}.png"]
    else:
        candidates = []
    return next((p for p in candidates if p.is_file()), None)


def mapping_index(mappings: list[dict]) -> dict[str, list[dict]]:
    result: dict[str, list[dict]] = {}
    for mapping in mappings:
        production_id = mapping.get("production_id") or mapping.get("reuse_asset")
        if production_id:
            result.setdefault(production_id, []).append(mapping)
    return result


def build_entry_rows(catalog: dict, manifest: dict) -> list[dict]:
    by_id = {asset.get("id"): asset for asset in manifest.get("assets", [])}
    mapped_by_id = mapping_index(catalog.get("source_mappings", []))
    existing_by_id = {}
    for item in catalog.get("existing_assets", []):
        manifest_path = item.get("manifest")
        if not manifest_path:
            continue
        data = read_json(ROOT / manifest_path, required=False)
        if isinstance(data, dict):
            existing_by_id.update({a.get("id"): a for a in data.get("assets", [])})
    rows = []
    for model in catalog.get("models", []):
        asset_id = model.get("id", "")
        mappings = mapped_by_id.get(asset_id, [])
        tiles = sorted({canonical_tile(t) for m in mappings for t in m.get("tiles", [])})
        if not tiles:
            tiles = sorted({canonical_tile(r.get("tile")) for r in model.get("assembly_refs", []) if r.get("tile")})
        preview = preview_for(asset_id)
        mesh = by_id.get(asset_id, {})
        rows.append({
            "id": asset_id,
            "name": model.get("name", asset_id),
            "source": model.get("source_id", ""),
            "category": model.get("category", "Uncategorized"),
            "status": "generated",
            "dimensions": model.get("dimensions_cm"),
            "pivot": model.get("production_pivot") or model.get("pivot", "unspecified"),
            "materials": model.get("materials", []),
            "tiles": tiles,
            "notes": model.get("source_generation_brief") or model.get("blender_brief", ""),
            "links": gather_source_links(model, mappings),
            "preview": relative_link(preview) if preview else None,
            "manifest": mesh,
        })
    for asset in catalog.get("existing_assets", []):
        asset_id = asset.get("id", "")
        mappings = mapped_by_id.get(asset_id, [])
        tiles = sorted({canonical_tile(t) for m in mappings for t in m.get("tiles", [])})
        preview = preview_for(asset_id)
        manifest_path = asset.get("manifest")
        rows.append({
            "id": asset_id,
            "name": next((m.get("source_name") for m in mappings if m.get("source_name")), asset_id),
            "source": ", ".join(sorted({m.get("source_id", "") for m in mappings if m.get("source_id")})),
            "category": next((m.get("category") for m in mappings if m.get("category")), "Reusable asset"),
            "status": "reuse",
            "dimensions": asset.get("dimensions_cm"),
            "pivot": asset.get("pivot", "unspecified"),
            "materials": asset.get("material_keys", []),
            "tiles": tiles,
            "notes": "; ".join(m.get("reuse_basis", "") for m in mappings if m.get("reuse_basis")),
            "links": gather_source_links(asset, mappings),
            "preview": relative_link(preview) if preview else None,
            "manifest_path": manifest_path,
            "manifest": existing_by_id.get(asset_id, {}),
        })
    return rows


def report_summary(path: Path) -> str:
    if path.suffix.lower() != ".json":
        return "Report file available"
    try:
        obj = read_json(path, required=False)
    except (OSError, json.JSONDecodeError):
        return "Report could not be parsed"
    if not isinstance(obj, dict):
        return "Report file available"
    status = obj.get("status")
    if status:
        return f"Recorded status: {status}"
    return "Report available; no status field recorded"


def source_map_path(asset_name: str) -> str:
    return f"/Game/Mars/Maps/Variants/v8c/{asset_name}"


def card_html(row: dict) -> str:
    tiles = row["tiles"]
    search = " ".join([
        row["id"], row["name"], row["source"], row["category"],
        " ".join(tiles), " ".join(row["materials"]), row["notes"],
    ]).lower()
    if row["preview"]:
        image = f'<img loading="lazy" src="{esc(row["preview"])}" alt="{esc(row["name"])} preview" onerror="this.closest(\'.thumb\').classList.add(\'no-image\');this.remove()">'
    else:
        image = '<span class="no-art">No local preview</span>'
    links = " ".join(f'<a href="{esc(url)}">{esc(label)}</a>' for url, label in row["links"])
    tile_text = ", ".join(tiles) if tiles else "not tile-mapped"
    measured_dims = row.get("manifest", {}).get("actual_dimensions_cm")
    measured_text = f" · measured {format_dimensions(measured_dims)}" if measured_dims else ""
    geometry = row.get("manifest", {})
    geometry_text = ""
    if geometry.get("vertices") is not None and geometry.get("triangles") is not None:
        geometry_text = f'<p class="small">{int(geometry["vertices"]):,} vertices · {int(geometry["triangles"]):,} triangles</p>'
    return f'''<article class="asset-card" data-search="{esc(search)}" data-tiles="{esc("|".join(tiles))}" data-category="{esc(row["category"])}" data-status="{esc(row["status"])}">
      <div class="thumb">{image}<span class="status {esc(row["status"])}">{esc(row["status"])}</span></div>
      <div class="card-body"><div class="idline"><strong>{esc(row["id"])}</strong><span>{esc(row["category"])}</span></div>
      <h3>{esc(row["name"])}</h3><p class="dims">{esc(format_dimensions(row["dimensions"]))}{esc(measured_text)} · pivot: {esc(row["pivot"])}</p>{geometry_text}
      <p class="meta">Source: {esc(row["source"] or "not linked")}<br>Tiles: {esc(tile_text)}<br>Materials: {esc(", ".join(row["materials"]) or "not listed")}</p>
      {f'<p class="notes">{esc(row["notes"][:320])}</p>' if row["notes"] else ""}
      {f'<div class="links">{links}</div>' if links else ""}</div></article>'''


def runtime_gallery_html(views: list[dict] | None) -> str:
    runtime_dir = OUT / "Runtime"
    if views is None:
        return '<p class="missing">review_views.json is unavailable; no runtime review targets can be listed.</p>'
    sections = []
    for view in views:
        view_id = str(view.get("id", ""))
        image_path = runtime_dir / f"{view_id}.png"
        if view_id and image_path.is_file():
            body = f'<a class="runtime-shot" href="{esc(relative_link(image_path))}"><img loading="lazy" src="{esc(relative_link(image_path))}" alt="{esc(view.get("label", view_id))} runtime view"><span>{esc(image_path.name)}</span></a>'
        else:
            body = f'<p class="missing">No capture for this authored view yet; expected <code>{esc(view_id)}.png</code>.</p>'
        eye = view.get("plan_eye", [])
        target = view.get("target", [])
        sections.append(f'''<article class="view-card" data-kind="{esc(view.get("kind", "unknown"))}"><div class="idline"><strong>{esc(view.get("kind", "unknown"))}</strong><span>{esc(view_id)}</span></div><h3>{esc(view.get("label", view_id))}</h3><p class="small">Plan eye: {esc(eye)} · target: {esc(target)}<br>Source floor: {esc(view.get("source_floor", "not recorded"))}</p>{body}</article>''')
    return "".join(sections)


def make_html(catalog: dict, manifest: dict, zones: list[dict], fitted: dict, views: list[dict] | None) -> str:
    rows = build_entry_rows(catalog, manifest)
    runtime_html = runtime_gallery_html(views)
    cards = "\n".join(card_html(row) for row in rows)
    categories = sorted({row["category"] for row in rows})
    category_options = "".join(f'<option value="{esc(c)}">{esc(c)}</option>' for c in categories)
    tile_options = "".join(f'<option value="{esc(z["id"])}">{esc(z["id"])}</option>' for z in zones)
    view_kinds = sorted({str(view.get("kind", "unknown")) for view in (views or [])})
    runtime_kind_options = "".join(f'<option value="{esc(kind)}">{esc(kind.title())}</option>' for kind in view_kinds)
    zone_cards = []
    for zone in zones:
        concepts = []
        for path in zone.get("concept_links", []):
            link = source_path_link(path)
            if link:
                concepts.append(f'<a href="{esc(link[0])}">{esc(link[1])}</a>')
        concepts_html = " · ".join(concepts) if concepts else "No linked concept image found."
        zone_cards.append(f'''<article class="zone-card"><h3>{esc(zone["id"])}</h3><p>{esc(zone.get("label", ""))}</p><code>{esc(zone["map_path"])}</code><p class="links">{concepts_html}</p></article>''')
    main_report = read_json(OUT / "Reports" / "dressed_Main.json", required=False)
    main_instances = main_report.get("instances") if isinstance(main_report, dict) else None
    main_asset = main_report.get("asset") if isinstance(main_report, dict) else None
    if isinstance(main_report, dict) and main_report.get("tile") == "Main":
        main_path = main_asset or "Main map asset not recorded"
        zone_cards.append(f'''<article class="zone-card"><h3>Main surround</h3><p>Surrounding map dressing record · {esc(main_instances if main_instances is not None else "instance count not recorded")} instances</p><code>{esc(main_path)}</code><p class="small">Source report: <a href="{esc(relative_link(OUT / "Reports" / "dressed_Main.json"))}">dressed_Main.json</a></p></article>''')
    report_files = []
    reports_dir = OUT / "Reports"
    if reports_dir.is_dir():
        report_files = sorted(p for p in reports_dir.iterdir() if p.is_file() and p.suffix.lower() in {".json", ".md", ".png"})
    report_rows = "".join(f'<li><a href="{esc(relative_link(path))}">{esc(path.name)}</a><span>{esc(report_summary(path))}</span></li>' for path in report_files)
    blend_files = [p for p in (OUT / "WarrensVariantC_Diorama.blend", OUT / "WarrensVariantC_KitLibrary.blend") if p.is_file()]
    blend_links = " · ".join(f'<a href="{esc(relative_link(path))}">{esc(path.name)}</a>' for path in blend_files) or "No Blender project file found."
    blender_report = read_json(OUT / "Reports" / "blender_validation.json", required=False)
    unreal_report = read_json(OUT / "Reports" / "unreal_import_all.json", required=False)
    checks_report = read_json(OUT / "Reports" / "placement_checks.json", required=False)
    level_report = read_json(OUT / "Reports" / "unreal_level_validation.json", required=False)
    pie_report = read_json(OUT / "Reports" / "pie_final_rooms_r05.json", required=False)
    new_count = len(catalog.get("models", []))
    reuse_count = len(catalog.get("existing_assets", []))
    library_count = new_count + reuse_count
    map_count = len(zones)
    main_count = 1 if isinstance(main_report, dict) and main_report.get("tile") == "Main" else 0
    source_mapping_count = len(catalog.get("source_mappings", []))
    coverage = fitted.get("coverage", {})
    coverage_tiles = coverage.get("tiles", {}) if isinstance(coverage, dict) else {}
    coverage_summary = {
        "tiles": len(coverage_tiles),
        "selected_boxes": sum(int(v.get("selected_floor_boxes", 0)) for v in coverage_tiles.values()),
        "exposed_samples": sum(int(v.get("exposed_floor_samples", 0)) for v in coverage_tiles.values()),
        "missing_samples": sum(int(v.get("missing_floor_samples", 0)) for v in coverage_tiles.values()),
    }
    fit_counts = {
        "placements": len(fitted.get("placements", [])),
        "source_instances": fitted.get("source_instance_count"),
        "checked_placements": checks_report.get("instances") if isinstance(checks_report, dict) else None,
        "coverage": coverage_summary,
    }
    kind_counts = {}
    for view in views or []:
        kind = str(view.get("kind", "unknown"))
        kind_counts[kind] = kind_counts.get(kind, 0) + 1
    view_mix = " · ".join(f"{count} {kind}{'' if count == 1 else 's'}" for kind, count in sorted(kind_counts.items())) or "No authored view targets"
    named_reports = [
        ('FINAL_AUDIT.md', 'Final audit and known limitations'),
        ('toolbox_verification.json', 'Focused automation verdicts'),
        ('runtime_visual_review_west_r05.md', 'Final west-room pixel review'),
        ('runtime_visual_review_east_r05.md', 'Final east-room pixel review'),
        ('boundary_visual_review_r05.md', 'Final boundary pixel review'),
        ("boundary_visual_review.md", "Boundary visual review"),
        ("gate_art_binding.md", "Gate art binding review"),
        ("placement_adversarial_review.md", "Placement adversarial review"),
        ("unreal_level_validation.json", "Unreal level validation"),
        ('pie_final_rooms_r05.json', 'Final PIE room record'),
        ('pie_final_boundaries_r05.json', 'Final PIE boundary record'),
    ]
    named_report_links = []
    for filename, label in named_reports:
        path = reports_dir / filename
        if path.is_file():
            named_report_links.append(f'<a href="{esc(relative_link(path))}">{esc(label)}</a>')
    named_report_html = " · ".join(named_report_links) or "No named review reports found."
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Warrens Variant C — Full Kit Review</title>
<style>
:root{{--bg:#171815;--panel:#24251f;--panel2:#2d2e27;--ink:#eee9db;--muted:#b5b09f;--accent:#bd9a5e;--line:#48483e;--green:#7abf8b;--blue:#8db6ce}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--ink);font:15px/1.5 system-ui,Segoe UI,sans-serif}}a{{color:#d6bd8a}}a:hover{{color:#fff}}header.hero{{padding:36px clamp(18px,4vw,64px);background:linear-gradient(120deg,#252820,#121411);border-bottom:1px solid var(--line)}}.eyebrow{{text-transform:uppercase;letter-spacing:.14em;color:var(--accent);font-size:.78rem}}h1{{font-size:clamp(2rem,4vw,3.5rem);line-height:1.05;margin:.35rem 0 1rem}}.lede{{max-width:900px;color:#d3cfbf}}main{{max-width:1600px;margin:auto;padding:24px clamp(14px,3vw,42px) 64px}}section{{margin:32px 0}}h2{{font-size:1.55rem;margin:0 0 12px}}h3{{margin:0 0 6px}}.stat-grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px}}.stat,.zone-card,.runtime-tile,.report-box{{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px}}.stat b{{font-size:1.8rem;display:block;color:var(--accent)}}.stat span,.muted{{color:var(--muted)}}.filters{{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0}}input,select{{background:var(--panel2);color:var(--ink);border:1px solid var(--line);border-radius:6px;padding:10px;min-width:160px}}input[type=search]{{flex:1;min-width:240px}}.gallery{{display:grid;grid-template-columns:repeat(auto-fill,minmax(255px,1fr));gap:12px}}.asset-card{{background:var(--panel);border:1px solid var(--line);border-radius:10px;overflow:hidden;display:flex;flex-direction:column}}.thumb{{height:190px;background:radial-gradient(ellipse,#393b33,#1a1b18);position:relative;display:grid;place-items:center}}.thumb img{{max-width:100%;max-height:100%;object-fit:contain}}.thumb.no-image:after{{content:'Preview unavailable';color:var(--muted)}}.no-art{{color:var(--muted)}}.status{{position:absolute;top:9px;right:9px;padding:3px 8px;border-radius:20px;background:#385443;color:#d9f1df;font-size:.75rem}}.status.reuse{{background:#394a58;color:#d9eaf3}}.card-body{{padding:12px}}.idline{{display:flex;justify-content:space-between;gap:8px;color:var(--muted);font-size:.8rem}}.idline strong{{color:var(--accent)}}.card-body h3{{margin-top:5px;font-size:1.05rem}}.dims{{color:#ded5bf;font-size:.86rem;margin:.4rem 0}}.meta,.notes{{color:var(--muted);font-size:.82rem;overflow-wrap:anywhere}}.notes{{border-top:1px solid var(--line);padding-top:8px}}.links{{font-size:.8rem;display:flex;flex-wrap:wrap;gap:8px}}.zone-grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px}}code{{display:block;color:#c5c1b2;font-size:.78rem;overflow-wrap:anywhere;margin:8px 0}}.runtime-grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:10px}}.runtime-tile header{{margin-bottom:10px}}.runtime-shots{{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:8px}}.runtime-shot{{display:block;background:#10110f;border:1px solid var(--line);border-radius:6px;padding:4px}}.runtime-shot img{{width:100%;height:180px;object-fit:contain;background:#10110f}}.runtime-shot span{{display:block;font-size:.8rem;padding:4px}}.missing{{color:var(--muted);font-style:italic}}.report-list{{list-style:none;padding:0;margin:0;display:grid;gap:6px}}.report-list li{{display:flex;flex-wrap:wrap;gap:8px;justify-content:space-between;padding:8px;border-bottom:1px solid var(--line)}}.report-list span{{color:var(--muted);font-size:.85rem}}.warning{{border-left:4px solid var(--accent);padding:10px 14px;background:#29271f;color:#e1d6be}}.small{{font-size:.82rem;color:var(--muted)}}.empty{{color:var(--muted);grid-column:1/-1}}
</style></head><body>
<header class="hero"><div class="eyebrow">Local evidence page · full-level Variant C</div><h1>Warrens dressing kit</h1><p class="lede">The full Variant C model library and current placement evidence, linked to its source concepts, local previews, generated meshes, Blender projects, and Unreal asset paths. This page reads the repository files at generation time; missing evidence remains visibly missing.</p></header>
<main>
<section><div class="stat-grid"><div class="stat"><b>{library_count}</b><span>library entries ({new_count} generated + {reuse_count} reusable)</span></div><div class="stat"><b>{map_count} + {main_count}</b><span>district tiles + Main surround record</span></div><div class="stat"><b>{source_mapping_count}</b><span>source catalog mappings</span></div><div class="stat"><b>{fit_counts['placements']}</b><span>fitted placement rows</span></div><div class="stat"><b>{fit_counts['checked_placements'] if fit_counts['checked_placements'] is not None else '—'}</b><span>placement-check report rows</span></div><div class="stat"><b>{fit_counts['source_instances'] if fit_counts['source_instances'] is not None else '—'}</b><span>source instances in fitter manifest</span></div></div></section>
<section><h2>Library gallery</h2><p class="small">Search model names, source IDs, categories, material keys, and tile coverage. Reused CCS/PWC meshes use their kit preview when present.</p><div class="filters"><input id="search" type="search" placeholder="Search models, IDs, materials…"><select id="tileFilter"><option value="">All tiles</option>{tile_options}</select><select id="categoryFilter"><option value="">All categories</option>{category_options}</select><select id="statusFilter"><option value="">Generated and reused</option><option value="generated">Generated</option><option value="reuse">Reuse</option></select></div><p id="resultCount" class="small"></p><div id="gallery" class="gallery">{cards}</div></section>
<section><h2>Tile and Unreal asset paths</h2><div class="zone-grid">{"".join(zone_cards)}</div></section>
<section><h2>Runtime review views</h2><p class="small">{len(views or [])} authored targets from Output/review_views.json ({esc(view_mix)}). Each card expects the exact file Output/Runtime/&lt;id&gt;.png; cards describe capture availability only.</p><p class="warning">A screenshot proves only the captured view. Physical input, network/co-op behavior, and packaged collision are not proven by these images or by this page.</p><div class="filters"><select id="runtimeKind"><option value="">All view kinds</option>{runtime_kind_options}</select></div><div id="runtimeGallery" class="runtime-grid">{runtime_html}</div></section>
<section><h2>Recorded validation state</h2><div class="report-box"><p>Blender report status: <strong>{esc(blender_report.get("status", "No status recorded") if isinstance(blender_report, dict) else "Report absent")}</strong> · Unreal import report status: <strong>{esc(unreal_report.get("status", "No status recorded") if isinstance(unreal_report, dict) else "Report absent")}</strong> · Unreal level validation: <strong>{esc(level_report.get("status", "No status recorded") if isinstance(level_report, dict) else "Report absent")}</strong> · final PIE room record: <strong>{esc(pie_report.get("status", "No status recorded") if isinstance(pie_report, dict) else "Report absent")}</strong>.</p><p>These are statuses recorded in the linked reports, not an overall completion claim. Blender projects: {blend_links}</p><p>Unreal destination recorded in import report: <code>{esc(unreal_report.get("destination", "No destination field/report present") if isinstance(unreal_report, dict) else "No Unreal import report present")}</code></p><p class="small">Fitted manifest: {fit_counts['placements']} rows. Placement checks: {fit_counts['checked_placements'] if fit_counts['checked_placements'] is not None else 'no row count recorded'} rows; source-instance baseline recorded by fitter: {fit_counts['source_instances'] if fit_counts['source_instances'] is not None else 'not recorded'}. Surface coverage: {fit_counts['coverage']['tiles']} tiles, {fit_counts['coverage']['selected_boxes']} selected floor boxes, {fit_counts['coverage']['exposed_samples']} exposed samples, {fit_counts['coverage']['missing_samples']} recorded missing samples.</p><p class="links">{named_report_html}</p></div></section>
<section><h2>Verification reports</h2><ul class="report-list">{report_rows or '<li>No report files found.</li>'}</ul></section>
<section><h2>Source baseline notes and evidence limits</h2><p class="warning">The source P4 baseline lacks its dial and clue actors, and defines no Bellkeeper encounter. Existing prototype controls are retained; the kit does not fabricate fixed-answer leaf actors. The source documents keep the six glyphs individually swappable and the phrase gameplay-authored. See <a href="{esc(relative_link(ROOT / 'docs' / 'art' / 'warrens-c-dressing-r01' / 'SOURCE.json'))}">SOURCE.json</a> and <a href="{esc(relative_link(ROOT / 'docs' / 'art' / 'warrens-c-dressing-r01' / 'ASSEMBLY_RECIPES.md'))}">ASSEMBLY_RECIPES.md</a>.</p><p class="warning">This local dossier does not claim physical-input verification, multiplayer/network verification, packaged-build collision, or full regression coverage. Only evidence present in the linked files is reported. The fitted-instance manifest is dressing data, not proof that an editor map applied it correctly.</p><p class="small">Source plan: <a href="{esc(relative_link(KIT / 'zone_plan.json'))}">zone_plan.json</a> · Catalog: <a href="{esc(relative_link(KIT / 'model_catalog.json'))}">model_catalog.json</a> · Fitted data: <a href="{esc(relative_link(OUT / 'fitted_instances.json'))}">fitted_instances.json</a> · Manifest: <a href="{esc(relative_link(OUT / 'asset_manifest.json'))}">asset_manifest.json</a> · <a href="{esc(relative_link(KIT / 'prop_assemblies.json'))}">prop_assemblies.json</a> · <a href="{esc(relative_link(KIT / 'prop_render_review.md'))}">prop_render_review.md</a></p></section>
</main><script>
const cards=[...document.querySelectorAll('.asset-card')], search=document.querySelector('#search'), tile=document.querySelector('#tileFilter'), category=document.querySelector('#categoryFilter'), status=document.querySelector('#statusFilter'), count=document.querySelector('#resultCount');
function filter(){{const q=search.value.toLowerCase().trim(),t=tile.value,c=category.value,s=status.value;let n=0;for(const el of cards){{const ok=(!q||el.dataset.search.includes(q))&&(!t||el.dataset.tiles.split('|').includes(t))&&(!c||el.dataset.category===c)&&(!s||el.dataset.status===s);el.hidden=!ok;if(ok)n++}}count.textContent=`Showing ${{n}} of ${{cards.length}} library entries.`}}
[search,tile,category,status].forEach(el=>el.addEventListener('input',filter));filter();
const runtimeKind=document.querySelector('#runtimeKind'),viewCards=[...document.querySelectorAll('.view-card')];runtimeKind?.addEventListener('input',()=>{{for(const el of viewCards)el.hidden=!!runtimeKind.value&&el.dataset.kind!==runtimeKind.value}});
</script></body></html>'''


def main() -> None:
    catalog = read_json(KIT / "model_catalog.json")
    manifest = read_json(OUT / "asset_manifest.json")
    fitted = read_json(OUT / "fitted_instances.json")
    zone_plan = read_json(KIT / "zone_plan.json")
    zones = []
    for row in zone_plan.get("zones", []):
        source = row.get("source_tile", {})
        zone = row.get("zone_art", {})
        asset = source.get("asset") or source.get("id")
        zones.append({
            "id": source.get("id", "Unknown"),
            "label": source.get("label", ""),
            "map_path": source_map_path(asset),
            "concept_links": zone.get("concept_links", []),
        })
    if not zones:
        raise ValueError("zone_plan.json contains no zones[].source_tile records")
    review_views = read_json(OUT / "review_views.json", required=False)
    if review_views is not None and not isinstance(review_views, list):
        raise ValueError("Output/review_views.json must contain a list of authored views")
    page = make_html(catalog, manifest, zones, fitted, review_views)
    output = OUT / "PREVIEW.html"
    output.write_text(page, encoding="utf-8")
    print(f"Wrote {output} ({len(catalog.get('models', []))} generated + {len(catalog.get('existing_assets', []))} reusable entries; {len(zones)} tiles).")


if __name__ == "__main__":
    main()
