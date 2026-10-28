"""Derived Blender material-policy successor, matching native local plane normals."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def main():
    import bpy
    source=DOC/'pilot-preview-r03/CatacombPilot_R02.blend';out=DOC/'pilot-final-shading-r06'
    assert Path(bpy.data.filepath).resolve()==source.resolve() and sha(source)==read(DOC/'pilot-preview-r03/receipt.json')['derived_sha256']
    assert not out.exists();out.mkdir()
    spec=importlib.util.spec_from_file_location('_plane_shading_sync',HERE/'sync_art_libraries.py');sync=importlib.util.module_from_spec(spec);spec.loader.exec_module(sync)
    meshes={m.name:sync.mesh_hash(m) for m in bpy.data.meshes}
    graphs={m.name:sync.stable(sync.nodes(m.node_tree)) for m in bpy.data.materials if m.use_nodes}
    changes=[]
    for family,sign in [('floor',1),('ceiling',-1)]:
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+family];tree=mat.node_tree;bs=tree.nodes.get('Principled BSDF')
        assert not bs.inputs['Normal'].is_linked
        n=tree.nodes.new('ShaderNodeCombineXYZ');n.inputs['Z'].default_value=sign
        transform=tree.nodes.new('ShaderNodeVectorTransform');transform.vector_type='NORMAL';transform.convert_from='OBJECT';transform.convert_to='WORLD'
        normalize=tree.nodes.new('ShaderNodeVectorMath');normalize.operation='NORMALIZE'
        tree.links.new(n.outputs['Vector'],transform.inputs['Vector']);tree.links.new(transform.outputs['Vector'],normalize.inputs[0]);tree.links.new(normalize.outputs['Vector'],bs.inputs['Normal'])
        mat['normal_policy']='Intentional planar art shading for shallow veneer: normalized object-local '+str(sign)+'Z transformed to world'
        changes.append(dict(material=mat.name,local_normal=[0,0,sign],transform='NORMAL OBJECT TO WORLD',normal_input=normalize.name))
    assert all(sync.mesh_hash(bpy.data.meshes[k])==v for k,v in meshes.items())
    allowed={r['material'] for r in changes};assert all(sync.stable(sync.nodes(bpy.data.materials[k].node_tree))==v for k,v in graphs.items() if k not in allowed)
    derived=out/'CatacombPilot_R06.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True)
    guard=read(ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot/baseline_guard_r02.json');protected=guard['immutable_guards']|guard['collision_hashes'];assert all(sha(ROOT/k)==v for k,v in protected.items())
    report=dict(status='DERIVED_TWO_MATERIAL_LOCAL_PLANE_SHADING_SUCCESSOR',source_sha256=sha(source),derived_sha256=sha(derived),all_mesh_inventories_unchanged=len(meshes),unrelated_material_graphs_unchanged=len(graphs)-2,material_changes=changes,tool_sha256=sha(__file__),guard_count=len(protected),boundary='Only derived successor saved; original libraries/maps and all mesh positions/topology/UV/colors/normals unchanged. Native shading policy matched; lighting/extra rear practical library sync remains pending.')
    (out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('DERIVED_SHADING_POLICY_READY',sha(out/'receipt.json'),flush=True)
if __name__=='__main__':main()
