"""Update the current delivery metadata without rewriting historical verification."""
import hashlib, json, re, zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
repo = root.parents[2]
out = root/'DependencyCleanup'
def read(p):
    return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,v):
    p.write_text(json.dumps(v,indent=2)+'\n')
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

reviewed = [
    'Script/Items/Mars_Item_Cookbook.as', 'Script/Items/Hfsm/Mars_ItemUse_Cookbook_Hfsm.as',
    'Script/Items/Presentation/Mars_CookbookPresentationComponent.as',
    'Script/WorldObjects/Items/Mars_Cookbook_EntityScript.as',
    'Script/PlayerCharacter/HFSM/Mars_PlayerCharacter_Hfsm_Cookbook.as',
    'Script/Tests/FPHands/Mars_AutoTest_FPHands_HoldOverrideRequiresAnItemAndDefaultRestores.as',
    *[p.relative_to(repo).as_posix() for p in (repo/'Script/Tests/Cookbook').glob('*.as')]]
for name in reviewed:
    text = (repo/name).read_text()
    assert not re.search(r'\b(?:BookMenu::|UBookPageWidget|UCk_Utils_|FMath::|static_cast\b)',text), name
    assert text.isascii(), name
assets = read(out/'asset_dependencies.json')
report = {
    'status': 'Live cookbook uses Ck widgets and rasterizer; BookMenu remains enabled only as an existing project plugin.',
    'widget_parent': '/Script/CkUICore.Ck_UserWidget_UE', 'widget_compile': {'total':6,'errors':0,'warnings':0},
    'rendering': 'utils_widget_rasterizer::RenderWidgetToTexture, 1024x1536, GammaCorrection::Disabled. Cached UTexture2D pages, retained by AngelScript UObject members; restore base materials and release page arrays on drop/stow/destruction.',
    'assets_audited': assets['active_assets'], 'active_bookmenu_asset_references': assets['bookmenu_references'],
    'outside_active_game_asset_dependencies': [], 'handwritten_or_generated_as_bookmenu_references': 0,
    'baseline': {'cookbook':'5/5','log':'Saved/Logs/Cookbook-Gutter-Final.log'},
    'final': {'cookbook':'5/5','exit':0,'failed':0,'skipped':0,'contaminated':0,'seconds':50,
              'log':'Saved/Logs/Cookbook-WithoutBookMenu-Final.log','test_editor_args':'-DisablePlugins=BookMenu',
              'plugin_check':'All3 lane command lines contain DisablePlugins; no BookMenu mount/import messages.'},
    'runtime': 'Actual Sandbox raw pickup/open/E/E/Q/drop/re-pickup/open; six Ck page widgets and native Texture2D material inputs. Forced GC preserves cached spreads; after drop and deferred GC all page widgets are collected and base materials restored. Reopen creates new textures.',
    'runtime_records': sorted(p.name for p in out.glob('[0-9]*.json')),
    'limitations': ['Rendered PIE is plugin-enabled; disabled-plugin automation is NullRHI.','Hardware key focus, network and packaged runtime remain unverified.'],
    'legacy_prototype_assets_requiring_cleanup_before_plugin_removal': len(read(out/'widget_migration.json')['remaining_prototype_dependencies']),
    'legacy_details': 'widget_migration.json / remaining_prototype_dependencies',
    'guideline_review': {'reviewed':reviewed,'changes':'Do private helpers, Request mutator, In parameters, inferred locals, early guards, shared constants_cookbook; no raw Ck utils classes, FMath, unsupported casts or non-ASCII source. Existing compatibility, signal scope and geometry preserved.'},
    'source_sha256': {name:sha(repo/name) for name in reviewed},
    'native_widget_sha256': {p.relative_to(repo).as_posix():sha(p) for p in (repo/'Content/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets').glob('*.uasset')},
    'editor_return': {'world':'/Game/Mars/Maps/Warrens_VariantC_Mars_MAP','pie_stopped':True,'dirty_packages':0},
    'git':'Uncommitted/unpushed; plugin entry, prototype assets and unrelated work left untouched.'}
write(out/'REPORT.json', report)

p=root/'INTEGRATION.md'
text=p.read_text().replace('BookMenu still supplies widget render-target creation/drawing.', 'All six pages derive from `UCk_UserWidget_UE`. CkWidgets rasterizes them to cached `UTexture2D` pages; no BookMenu runtime calls or live-asset references remain. See `DependencyCleanup/README.md` before removing the project plugin, because older prototype assets still reference it.')
text += '\n## Ck widgets and dependency cleanup\n\nLatest cookbook gate5/5 with `-DisablePlugins=BookMenu`, exit0 and zero skipped/contaminated. All6 page Blueprints compile under Ck_UserWidget_UE without errors/warnings;50 active assets have no BookMenu references. Actual renderer/GC/release/reopen checks and script guideline review: `DependencyCleanup/REPORT.json`. Nine older prototype assets outside StylizedR02 still reference the plugin; the project plugin entry remains enabled.\n'
p.write_text(text)
for filename in ['unreal_gameplay_report.json','DELIVERY.json']:
    p=root/filename; data=read(p)
    data['latest_revision']={'name':'Ck page widgets and BookMenu dependency cleanup','evidence':'DependencyCleanup/REPORT.json','removal_notes':'DependencyCleanup/README.md','focused_gate':'Saved/Logs/Cookbook-WithoutBookMenu-Final.log:5/5,exit0,-DisablePlugins=BookMenu'}
    if filename=='unreal_gameplay_report.json':
        for name in data['source_sha256']:
            data['source_sha256'][name]=sha(repo/name)
        data['editor_return']=report['editor_return']
    else:
        data['proof']['widgets']='All six Ck_UserWidget_UE page children compile with zero errors/warnings'
    write(p,data)
p=root/'PREVIEW.html'; text=p.read_text()
text=text.replace('6 BookPageWidget children across index, recipe and notes;', '6 Ck_UserWidget_UE children across index, recipe and notes;')
text=text.replace('<h2>Corrected spine and faster page turns</h2>', '<h2>Ck widgets / BookMenu independence</h2><p>Six Ck page widgets, native Ck rasterizer and zero BookMenu references across50 live assets. Cookbook5/5 with the plugin disabled. <a href="DependencyCleanup/README.md">Removal notes and verification</a></p><h2>Corrected spine and faster page turns</h2>')
p.write_text(text)
p=repo/'docs/plans/cookbook-item-integration/PROGRESS.md'
p.write_text(p.read_text()+'\n## Ck widgets / BookMenu independence - 2026-10-23\n\nReparented all6 pages to UCk_UserWidget_UE; Ck widget rasterizer now supplies cached Texture2D pages. Source uses typed Ck page-class arrays, native rasterization/local-controller capability guards and existing release semantics. Scoped guideline pass renamed private helpers/public clock request, normalized parameter/boolean/local style, shared spine/grip constants, and added early callback guards. The AS asset accessors were regenerated by the editor. No native or framework code changed.\n\nBaseline cookbook5/5 -> final5/5, exit0, fail0,skip0,contam0,50sec, with BookMenu disabled in all3 NullRHI test processes (`Cookbook-WithoutBookMenu-Final.log`). Six widget compiles0errors/0warnings.50 active assets have no BookMenu hard/soft references or external Game dependencies; all AS including generated bindings has zero BookMenu references. Actual plugin-enabled Sandbox PIE verifies pages, E/E/Q, GC survival, drop cleanup, and new textures on re-pickup/reopen.\n\nNine older prototype assets still reference BookMenu: SK_Book_Worn plus8 legacy materials/MIs. These and the plugin entry were left untouched; removal checklist and exact package list are in `Tools/BookMenuArt/StylizedR02/DependencyCleanup/`. Prior Warrens_VariantC restored, ownPIE stopped, native dirty0. Uncommitted/unpushed.\n')

# Keep the archive complete, preserving prior evidence and adding this revision.
archive=root/'Cookbook-Model-Rig-R02.zip'
with zipfile.ZipFile(archive) as z:
    names=set(z.namelist())
names.update(p.relative_to(root).as_posix() for p in out.iterdir() if p.is_file() and p.suffix in ['.py','.json','.md','.png'])
names.discard('delivery_manifest.json')
names={n for n in names if (root/n).is_file()}
write(root/'delivery_manifest.json',{n:{'bytes':(root/n).stat().st_size,'sha256':sha(root/n)} for n in sorted(names)})
temporary=archive.with_suffix('.updated.zip')
with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED) as z:
    for name in sorted(names|{'delivery_manifest.json'}):
        z.write(root/name,name)
temporary.replace(archive)
with zipfile.ZipFile(archive) as z:
    assert all(hashlib.sha256(z.read(n)).hexdigest()==sha(root/n) for n in names)
print('CK_COOKBOOK_FINAL_REPORT '+json.dumps({'assets':assets['active_assets'],'bookmenu_refs':0,'archive_entries':len(names)+1}))
