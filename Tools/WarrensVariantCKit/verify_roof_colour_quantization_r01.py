"""Calibrate raw FBX RGB -> UE render bytes against unchanged accepted ceiling."""
import hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def raw(path):
    from io_scene_fbx import parse_fbx
    tree,_=parse_fbx.parse(str(path));objects,=[v for v in tree.elems if v.id==b'Objects'];geom,=[v for v in objects.elems if v.id==b'Geometry'];layer,=[v for v in geom.elems if v.id==b'LayerElementColor'];c,=[v for v in layer.elems if v.id==b'Colors'];v=list(c.props[0]);return [v[i:i+4] for i in range(0,len(v),4)]
def main():
    baseline=DOC/'native-corrections-r10/accepted_ceiling_native_colour_baseline_r01.json';b=json.loads(baseline.read_text());source=Path(b['source_file'][0]);assert source.is_file();values=raw(source);expected={tuple(int(255*max(0,min(1,c[k]))) for k in range(3)) for c in values};actual={tuple(v) for v in b['RGB_bytes']};assert expected==actual,(len(expected),len(actual),expected-actual,actual-expected)
    newp=DOC/'roof-completion-export-r01/raw_fbx_linear_colours.json';n=json.loads(newp.read_text());new_expected=sorted({tuple(int(255*c[k]) for k in range(3)) for c in n['RGBA_values']});out=newp.parent/'colour_quantization_proof.json';assert not out.exists()
    r=dict(status='RAW_LINEAR_FBX_RGB_TO_UINT8_RENDER_CONTRACT_CALIBRATED_ON_ACCEPTED_CEILING',baseline_sha256=sha(baseline),accepted_source_fbx_sha256=sha(source),accepted_unique_RGB_bytes=len(actual),accepted_exact_set_equality=True,new_raw_payload_sha256=sha(newp),new_expected_RGB_bytes=new_expected,new_expected_RGB_max=[max(v[k] for v in new_expected)/255 for k in range(3)],tool_sha256=sha(__file__),boundary='UE FbxStaticMeshImport.cpp943-952 truncates255*clampedrawFBXcolour then storesFLinearColor(FColor); acceptednativeRenderData reproducesexactrawbyteRGBset. NewnativeRenderData must match this measuredcontract. BlenderdefaultsRGBreimportdisplayvaluesareseparate. No colours/materials/textures/gamma changed.')
    out.write_text(json.dumps(r,indent=2)+'\n');print('COLOUR_CONTRACT_CALIBRATED',len(actual),'old colours;',len(new_expected),'new expected colours',sha(out),flush=True)
if __name__=='__main__':main()
