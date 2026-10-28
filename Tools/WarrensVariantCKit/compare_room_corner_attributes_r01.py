"""Associate actual corner RGB and normal vectors through the full geometry proof."""
import hashlib
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def main():
    rooms=json.loads((DOC/'four_room_exports_r01.json').read_text())['rooms'];reports=[]
    zero_path=DOC/'zero_corner_normal_diagnostic_r01.json'
    zero_diagnostic=json.loads(zero_path.read_text())
    exceptions={(r['room'],r['family'],v['native_triangle'],v['corner']):v for r in zero_diagnostic for v in r['zero_samples']}
    for room in rooms:
        for family in ('walls','floor','ceiling'):
            expected=DOC/room['folder']/('actual_fbx_'+family+'_corner_attributes_r01.json')
            native=DOC/('native_corner_attributes_'+room['room']+'_'+family+'_r01.json')
            proof=DOC/('native_correspondence_'+room['room']+'_'+family+'_r02.json')
            e=json.loads(expected.read_text());n=json.loads(native.read_text());p=json.loads(proof.read_text())
            assert len(e['triangles'])==p['FBX_triangles'] and len(n['triangles'])==p['native_triangles']
            count=0;maximum=0.;minimum_dot=1.;mismatches=[];invalid_source=[]
            for row in p['matches']:
                actual=n['triangles'][row['native_triangle']];source=e['triangles'][row['fbx_triangle']]
                for corner,index in enumerate(row['cyclic_corner_order']):
                    count+=1
                    if actual['RGB_bytes'][corner]!=source['RGB_bytes'][index]:mismatches.append([row['native_triangle'],corner])
                    a=actual['normals'][corner];b=source['normals'][index]
                    assert all(math.isfinite(v) for v in a+b)
                    if sum(v*v for v in b)==0:
                        exception=exceptions[(room['room'],family,row['native_triangle'],corner)]
                        assert room['room']=='ossuary' and family=='walls' and a==[0.,0.,1.]
                        assert exception['fbx_triangle']==row['fbx_triangle'] and exception['fbx_normal']==b and exception['native_normal']==a
                        invalid_source.append(exception)
                        continue
                    maximum=max(maximum,max(abs(x-y) for x,y in zip(a,b)))
                    dot=sum(x*y for x,y in zip(a,b))/(math.sqrt(sum(v*v for v in a))*math.sqrt(sum(v*v for v in b)))
                    minimum_dot=min(minimum_dot,dot)
            assert count==p['native_triangles']*3 and not mismatches
            # Raw standard packed normals retain small component quantization errors.
            # Record measured errors; this check rejects flipped or damaged fields.
            assert maximum<.01 and minimum_dot>.9998
            reports.append(dict(room=room['room'],family=family,corners=count,RGB_byte_mismatches=0,maximum_normal_component_error_valid_source=maximum,minimum_normalized_normal_dot_valid_source=minimum_dot,maximum_normal_angle_degrees_valid_source=math.degrees(math.acos(max(-1,min(1,minimum_dot)))),source_zero_normal_exceptions=invalid_source,expected_attributes_sha256=sha(expected),native_attributes_sha256=sha(native),geometry_correspondence_sha256=sha(proof),actual_saved_slots=n['actual_saved_slots']))
    assert sum(len(r['source_zero_normal_exceptions']) for r in reports)==348
    result=dict(status='TWELVE_PRIVATE_NATIVE_CORNER_RGB_EXACT_VALID_NORMAL_FIELD_MEASURED_WITH_EXPLICIT_SOURCE_ZERO_EXCEPTION',tool_sha256=sha(__file__),zero_source_diagnostic_sha256=sha(zero_path),meshes=reports,total_corners=sum(r['corners'] for r in reports),boundary='Every native triangle corner follows the full cyclic geometry/UV/material mapping. RGB byte associations exactly match the range-safe original FBX, including multiplicity. Valid imported corner normal directions retain measured packed-vector errors, not bit equality. Ossuary348 corners on116 thin source faces have source zero normals and native +Z; explicitly listed, excluded only from undefined angular comparison. Their geometry and RGB still match. No normal-field parity claim for these invalid source normals; native art review required. Gameplay and source/library persistence remain separate checks.')
    output=DOC/'four_room_native_corner_attributes_r01.json';assert not output.exists();output.write_text(json.dumps(result,indent=2)+'\n')
    print('ALL12_CORNER_ASSOCIATIONS_RGB_EXACT',result['total_corners'],'MAX_VALID_NORMAL_ERROR',max(r['maximum_normal_component_error_valid_source'] for r in reports),'MAX_VALID_NORMAL_ANGLE',max(r['maximum_normal_angle_degrees_valid_source'] for r in reports),'SOURCE_ZERO_NORMAL_CORNERS',348)


if __name__=='__main__':main()
