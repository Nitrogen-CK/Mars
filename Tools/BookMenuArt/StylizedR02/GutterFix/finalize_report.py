"""Collect measured gutter evidence and refresh the local delivery package."""
import hashlib, json, math, runpy, zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent.parent
repo = root.parents[2]
out = root/'GutterFix'
def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))
def write(path, data):
    path.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

before = read(root/'Model/gutter_before.json')
after = read(root/'Model/gutter_validation.json')
traces = {}
for name in ['03-forward-recipe', '05-forward-notes', '07-reverse-recipe']:
    frames = read(out/(name+'.json'))
    end = next(i for i,f in enumerate(frames) if 'OPEN:' in f['state'])
    a, b = frames[end-1], frames[end]
    dot = min(1., abs(sum(x*y for x,y in zip(a['leaf_quaternion'], b['leaf_quaternion']))))
    traces[name] = {'samples': len(frames), 'first_open_seconds': b['time'],
        'section': b['section'], 'handoff_angle_degrees': math.degrees(2*math.acos(dot)),
        'handoff_translation_cm': math.dist(a['leaf_translation_cm'], b['leaf_translation_cm']),
        'terminal_translation_cm': frames[-1]['leaf_translation_cm']}

sheet = Image.new('RGB', (1000, 590), '#22271f')
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 21)
for i,(name,title) in enumerate([('04-after-forward-recipe','After E / sheet on left'),('08-after-reverse-recipe','After Q / sheet on right')]):
    image = Image.open(out/(name+'.png')).convert('RGB')
    # Native screenshot crops, no geometry or content retouching.
    crop = image.crop((530,155,750,610)).resize((253,523))
    sheet.paste(crop, (i*500+125,55))
    draw.text((i*500+80,15), title, fill='#f2e6c9', font=font)
sheet.save(out/'Middle-comparison.png')

report = {
    'cause': 'PageTurn_01 rest head is +0.476cm from the spine. Rotating the leaf 180 degrees around that fixed head offsets the left landing by +0.952cm (1.1424cm at runtime scale1.2).',
    'correction': 'Compensate the bend-chain root translation so its rotation is around spine X=0. Applied to both saved Blender sources, reproducible generator, centimetre FBX exporter, and both native turn clips. Fixed mesh and bind skeleton stay compatible.',
    'gutter_baseline': {'passed': 2, 'failed': 2, 'exit': 1, 'max_error_cm': max(e['xy_error_cm'] for e in before['endpoints'])},
    'gutter_final': {'passed': 4, 'failed': 0, 'exit': 0, 'max_error_cm': max(e['xy_error_cm'] for e in after['endpoints'])},
    'fbx_gate': {'passed': sum(read(root/'Model/roundtrip_validation.json')['checks'].values()), 'failed': 0, 'exit': 0, 'turn_frames_without_page_intersection': 216},
    'cookbook_gate': {'before': '5/5 in Cookbook-SpeedAndHandoff-Final.log', 'after': '5/5, exit0, failed0, skipped0, contaminated0, 1m18s', 'log': 'Saved/Logs/Cookbook-Gutter-Final.log'},
    'native_traces': traces, 'native_curves': 'Both native clips retain all four PageBend curves, each with108 keys. Root rotations differ only by float normalization (max quaternion component delta9.52e-7).',
    'speed': {'tuner': 'GlobalAnimRateScale', 'value': 1.5, 'file': 'Script/Items/Presentation/Mars_CookbookPresentationComponent.as:20', 'opening_seconds': (47/60)/1.5, 'turn_seconds': (107/60)/1.5},
    'prior_handoff_fix': 'Retain the terminal turn pose instead of resetting to idle: old forward handoff jumped179.993 degrees. This was separate from the offset hinge corrected here.',
    'images': ['04-after-forward-recipe.png','06-after-forward-notes.png','08-after-reverse-recipe.png','Middle-comparison.png'],
    'excluded_evidence': '09-reverse-index / 10-after-reverse-index include concurrent user camera/close input; not used as stable endpoint or matched-view proof.',
    'limits': ['Raw-event inbox injection does not prove physical keyboard/focus.', 'Remote multiplayer and packaged runtime remain unverified.'],
    'editor_return': {'pie_stopped': True, 'world': '/Game/Mars/Maps/Warrens_VariantC_Mars_MAP', 'dirty_packages': 0},
    'git': 'Uncommitted and unpushed; unrelated changes preserved.'}
write(out/'REPORT.json', report)
write(root/'SandboxPlacement/REPORT.json', {
    'map': '/Game/Mars/Maps/Sandbox_Mars_MAP', 'actor': 'Item_Cookbook', 'authored_location_cm': [-450,0,50],
    'actors_before': len(read(root/'SandboxPlacement/before-actors.json')['actors']),
    'actors_after': len(read(root/'SandboxPlacement/after-actors.json')['actors']),
    'verification': 'Exactly one cookbook added; existing actor records unchanged. Saved map survives reload and fresh editor restart; automatic WorldItem spawn falls onto floor and raw LMB picks it up.',
    'placement': 'Script/Editor/Mars_SandboxMapBuilder.as:459; Mars.Sandbox.PlaceCookbook refuses duplicate label.',
    'deleted_maps': 'Removed only the three orphaned service definitions/catalog entries from Script/Camp/Mars_ServiceDefinition.as. Remaining Sandbox/BrokenCistern destinations exist. User map deletions preserved.',
    'camp_gate': 'Saved/Logs/Cookbook-DeletedMaps-CampSession.log: 4/4, exit0, failed0, skipped0, contaminated0.',
    'animation_revision': '../GutterFix/REPORT.json'})

integration = root/'INTEGRATION.md'
text = integration.read_text()
text = text.replace('Run `Mars_SpawnCookbook` in the gameplay PIE console. Look at the loose book and click LMB to pick it up.', 'Open Sandbox and find `Item_Cookbook` at (-450, 0, 50), between the rock and ration. Look at the book and click LMB to pick it up. `Mars_SpawnCookbook` remains an optional debug spawn.')
text = text.replace('No cookbook has been added to gameplay maps or the initial loadout.', 'The Sandbox map contains one persistent cookbook; the map builder also includes it in future rebuilds. The initial loadout is unchanged.')
text = text.replace('PIE is stopped and the previous CrawlerDoorway map restored.', 'Latest PIE is stopped; the Warrens_VariantC map that was open before the final check is restored.')
text += '\n## Sandbox, speed and gutter correction\n\nThe three deleted-map services were removed from the catalog; CampSession passed4/4. `GlobalAnimRateScale` is1.5 (opening~0.522s, turning~1.189s). Forward/reverse completion retains the actual final pose. The moving leaf now rotates about the spine centre, correcting the1.1424cm runtime gutter error. Four evaluated endpoint alignment checks and12 FBX checks pass; final Cookbook5/5, exit0. See `GutterFix/REPORT.json` and `GutterFix/COMPARE.html`. Native animation assets, both Blender files, FBXs and motion preview are current.\n'
integration.write_text(text)

progress = repo/'docs/plans/cookbook-item-integration/PROGRESS.md'
text = progress.read_text().replace('no map placement was authored.', 'one persistent cookbook is now saved in Sandbox (later revision below).').replace('No gameplay map was changed to place the item.', 'Sandbox now contains Item_Cookbook; see the later placement revision.')
text += '\n## Sandbox and animation corrections - 2026-10-23\n\nSaved Item_Cookbook at(-450,0,50) using the existing entity-spawner factory; actor baseline347->348, no prior actor record changes. Map reload and fresh editor restart retained it; automatic physical spawn/pickup observed. Removed orphaned PilgrimsHollow/SevereredAqueduct/SunkenKitchens service definitions after user deleted those maps; retained Sandbox/BrokenCistern. CampSession4/4, exit0.\n\nNative animation tuner GlobalAnimRateScale1.5 advances the explicit clock exactly once. Baseline endpoint test0/1 exposed the forward180degree idle reset; retaining terminal pose passed5/5. User then identified an independent gutter offset: root rest X+.476cm rotated around itself, placing the left leaf+.952cm off target. Source baseline2/4 endpoint alignments failed. Corrected root translation around spine X0 in both turn clips/source blends/generator/FBXs. Final4/4 aligned,12/12 round-trip checks,216 page-turn frames without page-surface intersections. Native raw-input E,E,Q traces and matched recipe captures verify the actual gutter. Both clips retain four108-key morph curves. Final Cookbook5/5 exit0, skipped0, contaminated0,1m18s (`Saved/Logs/Cookbook-Gutter-Final.log`). No native code changes since the successful integration build.\n\nCurrent evidence: `Tools/BookMenuArt/StylizedR02/GutterFix/REPORT.json`, `COMPARE.html`, and `SandboxPlacement/REPORT.json`. Both source blends,7FBXs, motionGIF and deliveryZIP refreshed. Final ownPIE stopped, prior Warrens_VariantC restored, dirty native packages0. User open Blender untouched. Uncommitted/unpushed. Hardware focus, network and packaged runtime remain unverified.\n'
progress.write_text(text)

game = read(root/'unreal_gameplay_report.json')
game['limitations'] = [v for v in game['limitations'] if not v.startswith('No cookbook placement')]
game['editor_return'] = report['editor_return']
game['latest_revision'] = {'name': 'Sandbox placement, 1.5x speed, terminal-pose continuity and spine-centred leaf', 'evidence': 'GutterFix/REPORT.json', 'comparison': 'GutterFix/COMPARE.html', 'focused_gate': report['cookbook_gate']}
for path in list(game['source_sha256'])+['Script/Camp/Mars_ServiceDefinition.as','Script/Editor/Mars_SandboxMapBuilder.as']:
    game['source_sha256'][path] = sha(repo/path)
write(root/'unreal_gameplay_report.json', game)
delivery = read(root/'DELIVERY.json')
delivery['git'] = report['git']
delivery['latest_revision'] = game['latest_revision']
write(root/'DELIVERY.json', delivery)

preview = root/'PREVIEW.html'
text = preview.read_text().replace('In gameplay PIE, run <code>Mars_SpawnCookbook</code>, look at the loose book and click LMB to pick it up.', 'In Sandbox, find <code>Item_Cookbook</code> between the rock and ration at (-450, 0, 50). Look at it and click LMB to pick it up.')
text = text.replace('<h2>20% larger / raised reading pose</h2>', '<h2>Corrected spine and faster page turns</h2><p>1.5x animation speed. The leaf now lands on the same gutter in both directions. <a href="GutterFix/COMPARE.html">Actual Unreal binding close-ups and final checks</a></p><h2>20% larger / raised reading pose</h2>')
preview.write_text(text)
notes = root/'Model/README.md'
notes.write_text(notes.read_text()+'\n## Spine-centred turn correction\n\n`PageTurn_01` retains its offset rest head for mesh compatibility. `set_pose` compensates its translation around spine X0; both turn actions key that location. `export_centimetres.py` scales animated location keys/handles with rest geometry, then verifies restoration. Run `check_gutter.py` alongside the round-trip validator: the moving/fixed page rectangles must agree in XY at all four endpoints. Baseline2/4 -> final4/4. See `../GutterFix/REPORT.json` for actual native endpoint traces and screenshots.\n')

runpy.run_path(str(root/'Model/package_manifest.py'))
archive = root/'Cookbook-Model-Rig-R02.zip'
with zipfile.ZipFile(archive) as old:
    names = set(old.namelist())
names.update(['INTEGRATION.md','Model/check_gutter.py','Model/fix_gutter_actions.py','Model/gutter_before.json','Model/gutter_validation.json','GutterFix/REPORT.json','GutterFix/COMPARE.html','GutterFix/Middle-comparison.png','SandboxPlacement/REPORT.json'])
names.update('GutterFix/'+n for n in ['04-after-forward-recipe.png','04-after-forward-recipe.json','06-after-forward-notes.png','06-after-forward-notes.json','08-after-reverse-recipe.png','08-after-reverse-recipe.json','03-forward-recipe.json','05-forward-notes.json','07-reverse-recipe.json','native-root-forward.json','native-root-reverse.json'])
files = sorted(n for n in names if (root/n).is_file() and n != 'delivery_manifest.json')
write(root/'delivery_manifest.json', {n:{'bytes':(root/n).stat().st_size,'sha256':sha(root/n)} for n in files})
temp = archive.with_suffix('.updated.zip')
with zipfile.ZipFile(temp, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in files+['delivery_manifest.json']:
        z.write(root/name, name)
temp.replace(archive)
print('GUTTER_DELIVERY_COMPLETE '+json.dumps({'traces': traces,'zip_files':len(files)+1,'report':str(out/'REPORT.json')}))
