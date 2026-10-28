"""Ownership checked Spire Connector imports. Does not save unrelated packages."""
import json,hashlib,math,gc
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output';DEST='/Game/Mars/Environment/SpireConnectorKit';OWNER='Mars.SpireConnectorKit.v1';TAG='SpireConnectorOwner'
EAL=u.EditorAssetLibrary;TOOLS=u.AssetToolsHelpers.get_asset_tools()

def own(asset):EAL.set_metadata_tag(asset,TAG,OWNER)
def save(asset):
    own(asset);assert EAL.save_loaded_asset(asset,False),asset.get_path_name()
def require_owned(path,cls):
    if not EAL.does_asset_exist(path):return None
    a=u.load_asset(path)
    assert isinstance(a,cls) and EAL.get_metadata_tag(a,TAG)==OWNER,'Foreign asset: '+path
    return a

def import_one(row):
    source=OUT/row['fbx'];path=DEST+'/Meshes/'+row['name'];existing=require_owned(path,u.StaticMesh)
    if existing:
        previous=Path(existing.get_editor_property('asset_import_data').get_first_filename()).resolve()
        assert str(previous).casefold()==str(source.resolve()).casefold(),'Source mismatch '+path
        if EAL.get_metadata_tag(existing,'SpireSourceSHA256')==hashlib.sha256(source.read_bytes()).hexdigest():return existing
    task=u.AssetImportTask();task.filename=str(source);task.destination_path=DEST+'/Meshes';task.destination_name=row['name'];task.automated=True;task.replace_existing=existing is not None;task.replace_existing_settings=existing is not None;task.save=False;task.async_=False;task.factory=u.FbxFactory()
    opts=u.FbxImportUI();opts.automated_import_should_detect_type=False;opts.import_as_skeletal=False;opts.import_mesh=True;opts.import_animations=False;opts.import_materials=False;opts.import_textures=False;opts.mesh_type_to_import=u.FBXImportType.FBXIT_STATIC_MESH
    for k,v in dict(combine_meshes=True,auto_generate_collision=False,generate_lightmap_u_vs=False,build_nanite=False,transform_vertex_to_absolute=True,reorder_material_to_fbx_order=True,import_uniform_scale=1.0,normal_import_method=u.FBXNormalImportMethod.FBXNIM_IMPORT_NORMALS,vertex_color_import_option=u.VertexColorImportOption.REPLACE).items():opts.static_mesh_import_data.set_editor_property(k,v)
    task.options=opts;world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world();flag=u.SystemLibrary.get_console_variable_bool_value('Interchange.FeatureFlags.Import.FBX')
    try:u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX 0');TOOLS.import_asset_tasks([task])
    finally:u.SystemLibrary.execute_console_command(world,'Interchange.FeatureFlags.Import.FBX '+('1' if flag else '0'))
    a=u.load_asset(path);assert isinstance(a,u.StaticMesh),path
    assert any(str(p).split('.')[0]==path for p in task.imported_object_paths),str(task.imported_object_paths)
    own(a);EAL.set_metadata_tag(a,'SpireSourceSHA256',hashlib.sha256(source.read_bytes()).hexdigest())
    save(a);return a

def manifest():return json.loads((OUT/'asset_manifest.json').read_text())

def make_materials():
    spec=json.loads((HERE.parents[1]/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'))
    result={};lib=u.MaterialEditingLibrary
    for row in spec['materials']+[dict(id='M09_Emissive',palette='#ffb654',roughness=.4),dict(id='M00',palette='#181d20',roughness=.9)]:
        key=row['id'];name='M_Spire_'+key;path=DEST+'/Materials/'+name;m=require_owned(path,u.Material)
        recipe=hashlib.sha256(json.dumps({'recipe':1,'material':row},sort_keys=True).encode()).hexdigest()
        if not m or EAL.get_metadata_tag(m,'SpireMaterialRecipeSHA256')!=recipe:
            if not m:m=TOOLS.create_asset(name,DEST+'/Materials',u.Material,u.MaterialFactoryNew())
            assert m;own(m);lib.delete_all_material_expressions(m);m.set_editor_property('used_with_instanced_static_meshes',True)
            raw=[int(row['palette'].lstrip('#')[i:i+2],16)/255 for i in (0,2,4)];col=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in raw]
            c=lib.create_material_expression(m,u.MaterialExpressionConstant3Vector,-600,0);c.set_editor_property('constant',u.LinearColor(*col,1))
            v=lib.create_material_expression(m,u.MaterialExpressionVertexColor,-600,180);mult=lib.create_material_expression(m,u.MaterialExpressionMultiply,-300,0)
            assert lib.connect_material_expressions(c,'',mult,'A');assert lib.connect_material_expressions(v,'',mult,'B');assert lib.connect_material_property(mult,'',u.MaterialProperty.MP_BASE_COLOR)
            for value,prop,y in [(row['roughness'],u.MaterialProperty.MP_ROUGHNESS,300),(.45 if key in ['M05','M06'] else 0,u.MaterialProperty.MP_METALLIC,420)]:
                n=lib.create_material_expression(m,u.MaterialExpressionConstant,-300,y);n.set_editor_property('r',value);assert lib.connect_material_property(n,'',prop)
            if key=='M09_Emissive':
                em=lib.create_material_expression(m,u.MaterialExpressionMultiply,-300,-180);em.set_editor_property('const_b',2.0);assert lib.connect_material_expressions(c,'',em,'A');assert lib.connect_material_property(em,'',u.MaterialProperty.MP_EMISSIVE_COLOR)
            lib.recompile_material(m);EAL.set_metadata_tag(m,'SpireMaterialReady','1');EAL.set_metadata_tag(m,'SpireMaterialRecipeSHA256',recipe);save(m)
        result[key]=m
    print('SPIRE_MATERIALS',len(result));return result

def import_batch(start=0,count=15):
    data=manifest();mats=make_materials();sm=u.get_editor_subsystem(u.StaticMeshEditorSubsystem);reports=[]
    for row in data['assets'][start:start+count]:
        a=import_one(row)
        keys=[]
        for i,slot in enumerate(a.get_editor_property('static_materials')):
            name=str(slot.get_editor_property('imported_material_slot_name'));key=name.removeprefix('SP_');assert key in mats,(row['id'],name);a.set_material(i,mats[key]);keys.append(key)
        assert set(keys)==set(row['material_keys']),(row['id'],keys,row['material_keys'])
        hulls=sm.get_convex_collision_count(a)
        if row['category']=='Collision':
            assert hulls==row['collision_hulls'] and hulls>0,(row['id'],hulls,row['collision_hulls'])
            a.get_editor_property('body_setup').set_editor_property('collision_trace_flag',u.CollisionTraceFlag.CTF_USE_SIMPLE_AS_COMPLEX)
        b=a.get_bounds();lo=[b.origin.x-b.box_extent.x,b.origin.y-b.box_extent.y,b.origin.z-b.box_extent.z];hi=[b.origin.x+b.box_extent.x,b.origin.y+b.box_extent.y,b.origin.z+b.box_extent.z]
        assert all(abs(lo[k]-row['bounds_min_cm'][k])<.2 and abs(hi[k]-row['bounds_max_cm'][k])<.2 for k in range(3)),(row['id'],lo,hi)
        save(a);reports.append(dict(id=row['id'],asset=a.get_path_name(),hulls=hulls,bounds_min_cm=lo,bounds_max_cm=hi,materials=keys))
    (OUT/'Reports'/f'unreal_import_{start:03}.json').write_text(json.dumps(reports,indent=2));print('SPIRE_IMPORT_BATCH_PASSED',start,len(reports));return reports

def axis_gate():
    row=json.loads((OUT/'axis_fixture.json').read_text());a=import_one(row);bounds=a.get_bounds();lo=[bounds.origin.x-bounds.box_extent.x,bounds.origin.y-bounds.box_extent.y,bounds.origin.z-bounds.box_extent.z];hi=[bounds.origin.x+bounds.box_extent.x,bounds.origin.y+bounds.box_extent.y,bounds.origin.z+bounds.box_extent.z]
    assert all(abs(lo[k]-row['bounds_min_cm'][k])<.15 and abs(hi[k]-row['bounds_max_cm'][k])<.15 for k in range(3)),(lo,hi,row)
    result={'status':'passed','asset':a.get_path_name(),'bounds_min_cm':lo,'bounds_max_cm':hi,'identity_import_scale':True};(OUT/'Reports/axis_unreal.json').write_text(json.dumps(result,indent=2));print('SPIRE_AXIS_UNREAL_PASSED',json.dumps(result));return result
