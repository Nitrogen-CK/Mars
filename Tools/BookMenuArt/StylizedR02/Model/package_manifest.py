import ast,json,hashlib
from pathlib import Path
out=Path(__file__).resolve().parent
tree=ast.parse((out/'build_stylized.py').read_text())
colors=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='COLORS' for t in n.targets))
json.dump({'base_colors_linear_rgba':colors,'roughness_default':.78,'roughness_brass':.56,'page_texture_coordinate':0},open(out/'materials.json','w'),indent=2)
paths=[*out.glob('*.blend'),*out.glob('*.py'),*out.glob('*.json'),*out.glob('*.md'),*out.glob('FBX/*.fbx'),*out.glob('Renders/*')]
data={}
for p in sorted(paths):
 if p.name=='artifact_manifest.json': continue
 data[str(p.relative_to(out)).replace('\\','/')]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
json.dump(data,open(out/'artifact_manifest.json','w'),indent=2)
print('MANIFEST_COMPLETE files=%d'%len(data))
