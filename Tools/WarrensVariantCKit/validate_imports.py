"""Read-only verification that every saved Unreal mesh matches its final export."""
import hashlib,json
from datetime import datetime,timezone
from pathlib import Path
import unreal as u

HERE=Path(__file__).resolve().parent

def main():
    subsystem=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);checked=[]
    for kit in ['ChainCrossingKit','PumpCisternKit','WarrensVariantCKit']:
        root=HERE.parent/kit/'Output'
        manifest=json.loads((root/'asset_manifest.json').read_text())
        report=json.loads((root/'Reports/unreal_import_all.json').read_text());assert report['status']=='passed'
        imported={r['id']:r for r in report['meshes']}
        for row in manifest['assets']:
            mesh=u.load_asset('/Game/Mars/Environment/'+kit+'/Meshes/'+row['name']);assert isinstance(mesh,u.StaticMesh)
            sha=hashlib.sha256((root/row['fbx']).read_bytes()).hexdigest()
            assert u.EditorAssetLibrary.get_metadata_tag(mesh,'SourceSHA256')==sha==imported[row['id']]['source_sha256'],row['id']
            assert u.EditorAssetLibrary.get_metadata_tag(mesh,'CatalogId')==row['id']
            assert subsystem.get_simple_collision_count(mesh)==subsystem.get_convex_collision_count(mesh)==0
            assert len(mesh.static_materials)==len(row['material_keys'])
            for slot,key in zip(mesh.static_materials,row['material_keys']):
                assert slot.material_interface.get_path_name().endswith('M_CCK_'+key+'.M_CCK_'+key),(row['id'],key)
            checked.append(dict(id=row['id'],path=mesh.get_path_name(),source_sha256=sha))
    assert len(checked)==len({r['id'] for r in checked})==196
    result=dict(status='passed',generated_utc=datetime.now(timezone.utc).isoformat(),meshes=checked,count=len(checked),scope='Saved asset/export hashes, material bindings and generated collision; no packaged claim')
    (HERE/'Output/Reports/unreal_final_import_validation.json').write_text(json.dumps(result,indent=2))
    print('VARIANT_C_FINAL_IMPORT_VALIDATION_PASSED',len(checked));return result

if __name__=='__main__':main()
