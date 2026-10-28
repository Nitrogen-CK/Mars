"""Write-free authored startup-pickup preflight for Warrens v8c.

This checks source-plan geometry and metadata. It does not invoke Unreal or
claim that runtime spawn/readiness/pickup behavior works.
"""
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
PLAN = ROOT / 'Tools' / 'LevelDesign' / 'anchor_plans'
sys.path.insert(0, str(PLAN))
RUN = ROOT / 'Saved' / 'WarrensCGameplay-20261024'
MANIFEST_OUT = RUN / 'startup-manifest.json'
SUMMARY_JSON = RUN / 'startup-summary.json'
SUMMARY_MD = RUN / 'startup-summary.md'
REJECTED = RUN / 'startup-manifest.rejected-preflight.json'
REJECTED_MD = RUN / 'startup-summary.rejected-preflight.md'
CHECKPOINT = RUN / 'StartupCheckpoint'
TOL = 0.02


def load_module(name, builder, data):
    old = os.environ.get('WARRENS_DATA')
    os.environ['WARRENS_DATA'] = str(data)
    try:
        spec = importlib.util.spec_from_file_location(name, builder)
        module = importlib.util.module_from_spec(spec)
        sys.modules[name] = module
        spec.loader.exec_module(module)
        return module
    finally:
        if old is None:
            os.environ.pop('WARRENS_DATA', None)
        else:
            os.environ['WARRENS_DATA'] = old


def vadd(a, b): return [a[i] + b[i] for i in range(3)]
def vsub(a, b): return [a[i] - b[i] for i in range(3)]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))
def cross(a, b): return [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]]
def norm(a): return math.sqrt(dot(a, a))


def obb_axes(box):
    y, p = math.radians(box['yaw']), math.radians(box['pitch'])
    return [[math.cos(y)*math.cos(p), math.sin(y)*math.cos(p), math.sin(p)],
            [-math.sin(y), math.cos(y), 0.0],
            [-math.cos(y)*math.sin(p), -math.sin(y)*math.sin(p), math.cos(p)]]


def aabb_obb_overlap(center, half, box):
    """Full 15-axis SAT; touching is treated as non-overlap within 1 mm."""
    a_axes = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    b_axes = obb_axes(box)
    axes = a_axes + b_axes + [cross(a, b) for a in a_axes for b in b_axes]
    delta = vsub(box['centre'], center)
    b_half = [s / 2 for s in box['size']]
    for axis in axes:
        n = norm(axis)
        if n < 1e-9:
            continue
        axis = [x / n for x in axis]
        ra = sum(half[i] * abs(dot(axis, a_axes[i])) for i in range(3))
        rb = sum(b_half[i] * abs(dot(axis, b_axes[i])) for i in range(3))
        if abs(dot(delta, axis)) >= ra + rb - 0.001:
            return False
    return True


def mesh_aabb(row, bound):
    at, scale = row['at'], bound['scale']
    lo = [at[i] + bound['min'][i] * scale[i] / 100 for i in range(3)]
    hi = [at[i] + bound['max'][i] * scale[i] / 100 for i in range(3)]
    return [(lo[i] + hi[i]) / 2 for i in range(3)], [(hi[i] - lo[i]) / 2 for i in range(3)], lo, hi


def support_witnesses(solids, row):
    x, y = row['at'][:2]
    hx, hy = [v / 100 for v in row['footprint_half_cm']]
    points = [(x, y), (x-hx, y-hy), (x-hx, y+hy), (x+hx, y-hy), (x+hx, y+hy)]
    target = row['support_z']
    rows = []
    for px, py in points:
        # Matches runtime ProbeHalfRangeCm=5.0 in Mars_PlacedPickup_EntityScript.
        hit = solids.ray([px, py, target + 0.05], [px, py, target - 0.05])
        z = None if hit is None else hit[1][2]
        rows.append(dict(x=px, y=py, expected_z=target, hit_z=z,
                         source_box=None if hit is None else hit[2]['kind']))
    return rows


def manifest_for(module, data_path):
    data = json.loads(Path(data_path).read_text(encoding='utf-8'))
    return module.manifest(write=False, data=data)[0]


def equivalent_non_c_outputs():
    out = []
    for variant in ('b', 'd'):
        current_data = PLAN / 'data' / f'warrens_v8{variant}.json'
        current_builder = PLAN / 'build_warrens.py'
        backup_builder = CHECKPOINT / 'Tools' / 'LevelDesign' / 'anchor_plans' / 'build_warrens.py'
        if not backup_builder.exists():
            out.append(dict(variant=variant, equal=None, reason='checkpoint lacks baseline builder'))
            continue
        live_mod = load_module(f'preflight_live_{variant}', current_builder, current_data)
        # Apply the checkpoint builder to the same current variant data: the
        # checkpoint contains C-only authored inputs, so it has no B/D data copy.
        base_mod = load_module(f'preflight_base_{variant}', backup_builder, current_data)
        live = manifest_for(live_mod, current_data)
        base = manifest_for(base_mod, current_data)
        has_proxy = any(e.get('cls') == 'Mars_PlacedPickup_EntityScript' for e in live['entities'])
        out.append(dict(variant=variant, equal=live == base,
                        current_sha256=hashlib.sha256(json.dumps(live, sort_keys=True).encode()).hexdigest(),
                        checkpoint_sha256=hashlib.sha256(json.dumps(base, sort_keys=True).encode()).hexdigest(),
                        placed_pickup_proxy_present=has_proxy))
    return out


def main():
    if SUMMARY_JSON.exists() and MANIFEST_OUT.exists():
        previous = json.loads(SUMMARY_JSON.read_text(encoding='utf-8'))
        previous_hash = hashlib.sha256(MANIFEST_OUT.read_bytes()).hexdigest()
        if previous.get('generated_manifest_sha256') == previous_hash:
            suffix = 1
            while (RUN / f'startup-manifest.previous-{suffix}.json').exists():
                suffix += 1
            MANIFEST_OUT.replace(RUN / f'startup-manifest.previous-{suffix}.json')
    if MANIFEST_OUT.exists() and not REJECTED.exists():
        # Preserve the earlier report-only artifact before replacing it with
        # the real full manifest; once rejected exists, MANIFEST_OUT is canonical.
        MANIFEST_OUT.replace(REJECTED)
    if SUMMARY_MD.exists():
        if not REJECTED_MD.exists():
            SUMMARY_MD.replace(REJECTED_MD)
        else:
            suffix = 1
            while (RUN / f'startup-summary.previous-{suffix}.md').exists():
                suffix += 1
            SUMMARY_MD.replace(RUN / f'startup-summary.previous-{suffix}.md')
    if SUMMARY_JSON.exists():
        suffix = 1
        while (RUN / f'startup-summary.previous-{suffix}.json').exists():
            suffix += 1
        SUMMARY_JSON.replace(RUN / f'startup-summary.previous-{suffix}.json')
    builder = PLAN / 'build_warrens.py'
    data_path = PLAN / 'data' / 'warrens_v8c.json'
    module = load_module('preflight_v8c', builder, data_path)
    module.MAP = '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP'
    source_data = json.loads(data_path.read_text(encoding='utf-8'))
    man, source_summary = module.manifest(write=False, data=source_data)
    fixtures = man.get('placedPickupStartup', {}).get('fixtures', [])
    bounds_path = PLAN / source_data['placedPickupStartup']['boundsFile']
    bounds = json.loads(bounds_path.read_text(encoding='utf-8'))
    solids = module.Solids(man['boxes'])
    errors, checks = [], []
    source_items = {e['note'].replace(' ', '_').replace(':', '_'): e for e in man['entities']
                    if e.get('placedPickupOriginal')}
    if len(fixtures) != 34:
        errors.append(f'fixture_count expected 34 got {len(fixtures)}')
    if set(source_items) != {f['id'] for f in fixtures}:
        errors.append('fixture identity set differs between proxies and emitted manifest')
    for row in fixtures:
        entity = source_items.get(row['id'])
        if entity is None:
            errors.append(f"{row['id']}: no matching emitted entity")
            continue
        original = entity['placedPickupOriginal']
        kind = row['kind']
        bound = bounds[kind]
        if original.get('props'):
            errors.append(f"{row['id']}: source entity has custom properties")
        if original.get('yaw', 0) != 0 or original.get('pitch', 0) != 0:
            errors.append(f"{row['id']}: source transform rotation is nonzero")
        if entity['cls'] != 'Mars_PlacedPickup_EntityScript' or entity.get('tile') is not None:
            errors.append(f"{row['id']}: proxy class/tile mismatch")
        expected_existing_at = source_data['placedPickupStartup'].get('existingAtById', {}).get(row['id'], original['at'])
        if entity.get('placedPickupExistingAt') != expected_existing_at:
            errors.append(f"{row['id']}: saved-position metadata mismatch")
        center, half, lo, hi = mesh_aabb(original, bound)
        support = row['support_z']
        feet = support_witnesses(solids, row)
        bad_feet = [f for f in feet if f['hit_z'] is None or abs(f['hit_z'] - support) > TOL]
        if bad_feet:
            errors.append(f"{row['id']}: support witness failure {bad_feet}")
        overlaps = []
        for box in man['boxes']:
            if box.get('collision', module.COLLISION.get(box['kind'], 'BlockAll')) == 'NoCollision':
                continue
            if aabb_obb_overlap(center, half, box):
                overlaps.append(dict(kind=box['kind'], centre=box['centre'], size=box['size'], yaw=box['yaw'], pitch=box['pitch']))
        if overlaps:
            errors.append(f"{row['id']}: conservative full-mesh AABB overlaps source solids {overlaps[:4]}")
        if lo[2] < support - TOL:
            errors.append(f"{row['id']}: mesh envelope penetrates support by {support-lo[2]:.4f} m")
        checks.append(dict(id=row['id'], kind=kind, class_name=entity['cls'], tile=entity.get('tile'),
                           original_class=original['cls'], original_transform=original['at'],
                           existing_saved_transform=entity.get('placedPickupExistingAt'),
                           original_props=original.get('props', {}), rotation=dict(yaw=original.get('yaw', 0), pitch=original.get('pitch', 0)),
                           mesh=bound['mesh'], definition=bound['definition'], scale=bound['scale'],
                           mesh_aabb_m=dict(min=lo, max=hi), support_z_m=support,
                           support_witnesses=feet, overlap_count=len(overlaps), overlaps=overlaps))
    outputs = equivalent_non_c_outputs()
    for row in outputs:
        if row['equal'] is False:
            errors.append(f"v8{row['variant']} latest manifest differs from StartupCheckpoint")
    # Enforce the builder's own reported geometry gates in addition to this preflight.
    source_gates = {k: v for k, v in source_summary.items()
                    if k.endswith(('Errors', 'Leaks', 'Bypasses', 'Breaks'))}
    baseline_summary_path = RUN / 'p2-summary.json'
    baseline_summary = json.loads(baseline_summary_path.read_text(encoding='utf-8'))
    inherited_crawl = set(baseline_summary.get('crawlBypasses', []))
    inherited_floor_warnings = set(baseline_summary.get('ladderErrors', []))
    current_crawl = set(source_summary.get('crawlBypasses', []))
    current_floor_warnings = set(source_summary.get('ladderErrors', []))
    vault_exception = 'vault: the key is not on a floor'
    if current_crawl != inherited_crawl:
        errors.append(f'crawlBypasses changed vs pre-startup summary: {sorted(current_crawl ^ inherited_crawl)}')
    if current_floor_warnings - inherited_floor_warnings != {vault_exception}:
        errors.append('ladderErrors delta vs pre-startup summary is not exactly the reviewed vault-plinth exception')
    if inherited_floor_warnings - current_floor_warnings:
        errors.append(f'pre-existing ladderErrors unexpectedly disappeared: {sorted(inherited_floor_warnings-current_floor_warnings)}')
    required_zero = ('gateLeaks', 'walkBreaks', 'dropErrors', 'blockedViews', 'propErrors')
    for name in required_zero:
        value = source_summary.get(name, [])
        if value:
            errors.append(f'source builder gate {name}={value}')
    key_check = next((c for c in checks if c['id'] == 'vault_key'), None)
    vault_reviewed = bool(key_check and abs(key_check['support_z_m'] - 2.8) < 1e-6
                          and key_check['mesh_aabb_m']['min'][2] > 2.8
                          and len(key_check['support_witnesses']) == 5
                          and all(w['hit_z'] is not None and abs(w['hit_z']-2.8) <= TOL
                                  for w in key_check['support_witnesses']))
    if vault_exception in current_floor_warnings and not vault_reviewed:
        errors.append('vault plinth placement exception lacks five floor witnesses or positive mesh clearance')
    inputs = [builder, PLAN / 'design_warrens_v8c.py', PLAN / 'design_warrens_v8_common.py',
              data_path, PLAN / 'placed_pickups.py', bounds_path, baseline_summary_path]
    input_hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
    RUN.mkdir(parents=True, exist_ok=True)
    MANIFEST_OUT.write_text(json.dumps(man, indent=2) + '\n', encoding='utf-8')
    manifest_sha = hashlib.sha256(MANIFEST_OUT.read_bytes()).hexdigest()
    report = dict(preflight='offline authored geometry only', inputs_sha256=input_hashes,
                  generated_manifest_sha256=manifest_sha, source_builder_summary=source_summary,
                  source_builder_gates=source_gates,
                  inherited_source_diagnostics=dict(crawlBypasses=sorted(inherited_crawl),
                      ladderErrors=sorted(inherited_floor_warnings)),
                  reviewed_plinth_placement_exception=dict(id='vault_key',source_summary_warning=vault_exception,
                      expected_plinth_top_m=2.8,mesh_bottom_m=None if key_check is None else key_check['mesh_aabb_m']['min'][2],
                      all_five_support_witnesses_pass=vault_reviewed),
                  source_gate_comparison=dict(baseline=str(baseline_summary_path.relative_to(ROOT)),
                      crawlBypasses_delta=sorted(current_crawl-inherited_crawl),
                      ladderErrors_delta=sorted(current_floor_warnings-inherited_floor_warnings),
                      removed_inherited_ladderErrors=sorted(inherited_floor_warnings-current_floor_warnings)),
                  fixture_count=len(fixtures),
                  tolerances=dict(support_m=TOL, support_ray_half_range_m=0.05,
                                  touch_separation_m=0.001), non_c_output_comparison=outputs,
                  checks=checks, errors=errors,
                  limitations=['Mesh AABBs are conservative visual envelopes, not runtime collision shapes.',
                               'No Unreal load, Jolt body readiness, spawn completion, retention, pickup, or gameplay behavior was exercised.'])
    lines = ['# Warrens v8c startup pickup offline preflight', '',
             f"Fixtures: {len(fixtures)}; errors: {len(errors)}.",
             'This is source geometry only; mesh envelopes are conservative and do not prove runtime collision or Jolt readiness.', '',
             '| Fixture | Type | Support z | Five source floor witnesses | Conservative overlap |',
             '|---|---|---:|---|---:|']
    for row in checks:
        witness = 'pass' if all(f['hit_z'] is not None and abs(f['hit_z']-row['support_z_m']) <= TOL for f in row['support_witnesses']) else 'FAIL'
        lines.append(f"| {row['id']} | {row['kind']} | {row['support_z_m']:.2f} m | {witness} | {row['overlap_count']} |")
    lines.extend(['', 'Non-C current-vs-checkpoint outputs: ' + ', '.join(f"v8{x['variant']}={x['equal']}" for x in outputs), '',
                  'Errors:'] + ([f'- {e}' for e in errors] if errors else ['- None.']))
    SUMMARY_JSON.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    SUMMARY_MD.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(dict(fixtures=len(fixtures), errors=len(errors), manifest=str(MANIFEST_OUT),
                          summary_json=str(SUMMARY_JSON), summary_md=str(SUMMARY_MD),
                          manifest_sha256=manifest_sha, source_gates=source_gates, non_c=outputs), indent=2))
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())
