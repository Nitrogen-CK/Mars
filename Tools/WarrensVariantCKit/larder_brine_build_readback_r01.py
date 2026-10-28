"""Read-only native material parity report; exports do not bind or save assets."""
import hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def run(candidate):
    import unreal as u
    spec=importlib.util.spec_from_file_location('_brine_property_reader',Path(__file__).with_name('catacomb_plane_normal_materials.py'))
    reader=importlib.util.module_from_spec(spec);spec.loader.exec_module(reader)
    spec=importlib.util.spec_from_file_location('_brine_source_guard',Path(__file__).with_name('larder_surface_pie_trial_r04.py'))
    guard=importlib.util.module_from_spec(spec);spec.loader.exec_module(guard);guard.guard();guard.clean()
    source=u.load_asset('/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_FX_Water')
    assert candidate.get_outer().get_path_name()=='/Engine/Transient'
    mel=u.MaterialEditingLibrary;rows={}
    for role,mat in [('source',source),('candidate',candidate)]:
        stats=mel.get_statistics(mat);assert stats.num_pixel_shader_instructions>0 and stats.num_vertex_shader_instructions>0
        path=RUN/('brine_'+role+'_build_r01.t3d')
        task=u.AssetExportTask()
        for key,value in dict(object=mat,exporter=u.ObjectExporterT3D(),filename=str(path),selected=False,replace_identical=False,prompt=False,automated=True,use_file_archive=False,write_empty_files=False).items():task.set_editor_property(key,value)
        if not path.exists():assert u.Exporter.run_asset_export_task(task) and not list(task.errors) and path.is_file()
        sample=mel.get_material_property_input_node(mat,u.MaterialProperty.MP_NORMAL)
        assert isinstance(sample,u.MaterialExpressionTextureSample) and sample.get_editor_property('const_coordinate')==0
        normal_sample=reader.properties(sample)
        for key in ['texture','sampler_type','sampler_source','mip_value_mode','automatic_view_mip_bias','const_coordinate']:normal_sample[key]=reader.serial(sample.get_editor_property(key))
        rows[role]=dict(path=mat.get_path_name(),statistics=stats.export_text(),normal_sample=normal_sample,snapshot=reader.snapshot(mat),export_file=path.relative_to(ROOT).as_posix(),export_sha256=sha(path))
    sample_fields=['texture','sampler_type','sampler_source','mip_value_mode','automatic_view_mip_bias','const_coordinate']
    for key in sample_fields:assert rows['source']['normal_sample'][key]==rows['candidate']['normal_sample'][key],key
    guard.guard();guard.clean()
    receipt=dict(status='TRANSIENT_BRINE_NATIVE_STATISTICS_AND_GRAPH_READBACK_NOT_BINDING_OR_PIXEL_PARITY_PROOF',tool_sha256=sha(__file__),normal_sample_equal_fields=sample_fields,rows=rows,boundary='Original and new four-node parameterized material exported and reflected read-only. Actual implicit UV0 verified. Terminal masks and material defaults require comparison of the complete exports before binding; no scene/material-instance/source save or tuning.')
    path=RUN/'brine_build_readback_r01.json';assert not path.exists();path.write_text(json.dumps(receipt,indent=2)+'\n');print('BRINE_BUILD_READBACK',sha(path))
    return receipt
