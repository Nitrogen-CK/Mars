from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
jobs=json.loads((ROOT/'image_jobs.json').read_text())
specs={
 'MODEL13':'Correct only the catalog ID labels in this existing masonry sheet. The left filler wall is A03. BOTH the left and right arch-half views belong to A07, so change the right arch-half ID from A09 to A07. The loose keystone at upper right is A09, so change its ID from A23 to A09. The thin seam-cover strip at lower right remains A23. Preserve every object shape, material, position, neutral background and all other text. This is a text correction only.',
 'MODEL26':'Correct only TWO swapped catalog labels in this existing sheet. The low stone/timber CAMP PACK PLINTH at bottom left/center is I20, not P13. The small closed RELIQUARY STORAGE BOX at bottom right is P13, not I20. Change those IDs accordingly. The top vault door remains I19. Preserve all object shapes, positions, lighting, material, view labels and other text. This is a label correction only.',
 'MODEL37':'Correct only the catalog labels in this existing sheet. H11 Millstone Drum stays unchanged. The top-right wooden axle is a COMPONENT OF H11, so label it "H11 / axle component", not H12. The bottom-left SALT CHUTE is H12, not I12. The open CURING VAT body at middle-right is I12, not I13. The separate lid is I13 and its label stays unchanged. Preserve every object shape, material, background, layout, view caption and assembly. Text correction only.'}
for ident,prompt in specs.items():
    j=next(j for j in jobs if j['id']==ident)
    if 'revision_reference' not in j:j['revision_reference']=j['image']
    j['image']=j['revision_reference'].replace('.png','-r02.png')
    j['edit_prompt']=f'prompts/{ident}_r02-edit.txt'
    (ROOT/j['edit_prompt']).write_text('Use case: text-localization. '+prompt+'\n')
(ROOT/'image_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
print(json.dumps([dict(id=j['id'],prompt=(ROOT/j['edit_prompt']).read_text(),reference=str(ROOT/j['revision_reference'])) for j in jobs if j['id'] in specs]))
