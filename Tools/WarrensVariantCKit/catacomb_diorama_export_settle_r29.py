"""Record the single reproduced first-export-only UModel brush text difference."""
import copy
import re
def settle(lib):
    s=lib.STATE;assert s['stage']=='checkpointed';lib.guard();assert s['source'].dirty()==dict(maps=[],content=[])
    old=s['before'];new=lib.snapshot('settled_export_baseline_r29');assert old['hisms']==new['hisms'] and set(old['roster'])==set(new['roster']);pairs=[]
    for n,r in old['roster'].items():
        a=new['roster'][n];assert all(r[k]==a[k] for k in ('label','type','tags','pose','hidden','folder')) and set(r['components'])==set(a['components'])
        for cn,c in r['components'].items():assert c['raw']['sha256']==a['components'][cn]['raw']['sha256']
        if r['raw']['sha256']==a['raw']['sha256']:continue
        assert n=='PostProcessVolume_0' and r['type']=='/Script/Engine.PostProcessVolume'
        prior=(lib.ROOT/r['raw']['file']).read_text();current=(lib.ROOT/a['raw']['file']).read_text();pattern=r'^   Begin Brush Name=Model_1\n      Begin PolyList\n.*?^   End Brush\n';blocks=re.findall(pattern,prior,re.MULTILINE|re.DOTALL);assert len(blocks)==1 and prior.replace(blocks[0],'')==current
        pairs.append(dict(actor=n,before=r['raw'],after=a['raw'],omitted_block_sha256=lib.hashlib.sha256(blocks[0].encode()).hexdigest()))
    assert len(pairs)==1
    s['first_export_before']=copy.deepcopy(old);s['before']=new;s['export_settle']=lib.write('export_settle',dict(status='EXACT_SINGLE_FIRST_EXPORT_BRUSH_BLOCK_DIFFERENCE',pairs=pairs,snapshot=new,helper_sha256=lib.sha(__file__)));lib.guard();print('READ_ONLY_EXPORT_SETTLED',s['target'],len(pairs))
