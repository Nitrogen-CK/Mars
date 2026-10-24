"""Explicit catalog-to-image coverage; reuse is never counted as a new model."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
props=json.loads((ROOT/'prop_catalog.json').read_text())
jobs=json.loads((ROOT/'image_jobs.json').read_text())
progress=json.loads((ROOT/'art_progress.json').read_text())['completed']
rows=[]
for p in props:
    sheets=[j for j in jobs if j['type']=='model-sheet' and p['id'] in j.get('catalog_ids',[])]
    reuse=p['status']=='reuse_existing'
    assert sheets or reuse,p['id']
    rows.append(dict(id=p['id'],name=p['name'],reuse_only=reuse,tiles=p['tiles'],
      sheets=[dict(id=j['id'],image=j['image'],review=progress.get(j['id'],{}).get('review','not_generated')) for j in sheets]))
report={'catalog_entries':len(props),'new_model_entries':sum(not r['reuse_only'] for r in rows),
 'reuse_only_entries':[r['id'] for r in rows if r['reuse_only']],
 'model_sheets':sum(j['type']=='model-sheet' for j in jobs),'district_sheets':sum(j['type']=='dressing-sheet' for j in jobs),
 'new_models_with_reviewed_reference':sum(not r['reuse_only'] and any(s['review']=='inspected' for s in r['sheets']) for r in rows),
 'uncovered_new_models':[r['id'] for r in rows if not r['reuse_only'] and not r['sheets']],
 'coverage_definition':'A linked group sheet contains the named asset form. It is a modeling reference, not a finished mesh or measured CAD drawing. Review status records actual image inspection.',
 'entries':rows}
(ROOT/'VISUAL_COVERAGE.json').write_text(json.dumps(report,indent=2)+'\n')
lines=['# Full-level visual coverage','',
 f"{len(props)} catalog entries: {report['new_model_entries']} new-model candidates and one existing Red key to reuse. {report['model_sheets']} modeling sheets plus {report['district_sheets']} local district-assembly studies.",'',
 'The original pass linked only 70 of 126 entries to a modeling sheet. This expansion adds the missing architecture, rocks, water, bell components, storage, signs, lights and small accents. Each new-model candidate below has an explicit reference. I14 deliberately uses the existing pickup.','',
 'Images supply shapes, separations and style. Exact dimensions, variants and gameplay constraints remain in the individual brief. A group sheet is not a promise that every proposed variant is a separate approved design. Water and atmosphere sheets distinguish carrier meshes from later shader/animation work.','',
 '## Whole-level dressing order','',
 '1. Fit wall, floor, ceiling, cliff and rock skins to retained greybox surfaces; protect ports and views.',
 '2. Assemble hoist, high bell, bridge, pump, mill and existing mechanism skins at source anchors.',
 '3. Fit deep-canal, shallow-ford, cistern and vat surface carriers to existing water bodies. Add sparse edge treatment.',
 '4. Add existing practical-light fixture skins; calibrate actual light only in the eventual Unreal camera pass.',
 '5. Dress closed-wall bays with storage, signs, service tools and district-specific props.',
 '6. Use rubble, repairs, roots and optional atmosphere sparingly; walk every route again.','',
 '## Catalog references','', '| ID | Asset | Modeling sheets |','|---|---|---|']
for row in rows:
    refs=' · '.join(f"[{s['id']}]({s['image']})" for s in row['sheets']) or 'Reuse existing Red key; no new mesh'
    lines.append(f"| {row['id']} | {row['name']} | {refs} |")
lines+=['','## District assembly references','',
 'These show local dressing hierarchy and a lantern-lit mood inset. They are illustrative assemblies, not surveyed screenshots or replacements for the source layout.','']
for j in jobs:
    if j['type']=='dressing-sheet':lines.append(f"- [{j['id']} / {', '.join(j['tiles'])}]({j['image']})")
(ROOT/'VISUAL_COVERAGE.md').write_text('\n'.join(lines)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='entries'}))
