"""Add explicitly separate source-required parts without duplicating source entries."""
import copy,json
from pathlib import Path
HERE=Path(__file__).resolve().parent
def main():
    path=HERE/'model_catalog.json';data=json.loads(path.read_text())
    models=data['models'];by_source={r['source_id']:r for r in models}
    for source,ident,suffix,name,dim,pivot in [
        ('H15','WVC081','Lid','SarcophagusLid',(300,150,20),'bottom center'),
        ('P11','WVC082','Single','SingleChimeBone',(80,12,12),'center')]:
        if any(r['id']==ident for r in models):continue
        row=copy.deepcopy(by_source[source]);row.update(id=ident,source_id=source+'_'+suffix,name=name,
            dimensions_cm=dict(zip(('width','depth','height'),dim)),pivot=pivot,production_pivot=pivot,variants=1,
            source_pivot_contract='Separate component, explicit '+pivot+' pivot; assembly derives contact from measured exported bounds.')
        row['blender_brief']=f"Separate source-required {name}, parent catalog {source}. Dimensions {dim} cm, {pivot}. Keep real opening/part separation. Hollow tomb body never includes this lid. Single chime bone is a blunt graphic bone along X, without baked chain or rail. No collision, lights, gameplay or glyphs."
        row['source_generation_brief']=row['blender_brief'];models.append(row)
    if not any(r['id']=='WVC083' for r in models):
        row=copy.deepcopy(by_source['D12']);row.update(id='WVC083',source_id='GraphicCarrier',name='EmblemSurfaceCarrier',dimensions_cm=dict(width=60,depth=1,height=80),materials=['ART01'],pivot='bottom center',production_pivot='bottom center',variants=1,model_sheets=['ART01','ART02','ART03','ART04','ART05','ART06'],reference_images=[])
        row['blender_brief']='Reusable flat front-facing masked emblem/mural plane, 60x80cm, bottom-contact pivot. Full0..1 UVs. Place just above opaque cloth/plaque/wall; use authored ART01..06, never an invented control glyph.'
        row['source_generation_brief']=row['blender_brief'];models.append(row)
    liquid=next(r for r in models if r['source_id']=='W11');liquid.update(materials=['FX_ShallowWater'],pivot='center',production_pivot='center')
    data['separate_component_count']=3
    data['builder_compatibility']['models']='models[] has WVC + integer IDs, supported pivots and shared categories. Source mappings remain150 entries; separate lid/bone and shared emblem carrier add three production meshes.'
    path.write_text(json.dumps(data,indent=2)+'\n');print('VARIANT_C_NEW_MODELS',len(models))
if __name__=='__main__':main()
