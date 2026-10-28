"""Select the serialized spawner property, excluding editor preview script copies."""
from pathlib import Path

tools=Path(__file__).parent;old=tools/'larder_source_preflight_r01.py';new=tools/'larder_source_preflight_r02.py'
s=old.read_text().replace('source-retention-preflight-r01','source-retention-preflight-r02')
begin=s.index("        kind=u.load_class(None,'/Script/Angelscript.Mars_Anchor_Spawn_EntityScript')")
end=s.index('        assert len(scripts)==1',begin)
s=s[:begin]+'''        for actor in u.GameplayStatics.get_all_actors_of_class(world,u.Actor):
            if 'Spawner' not in actor.get_class().get_name():continue
            obj=actor.get_editor_property('_EntityScript')
            if obj and obj.get_class().get_name()=='Mars_Anchor_Spawn_EntityScript' and 'Anchor.Mars.Warrens.S3' in obj.get_editor_property('AnchorId').export_text():
                assert obj.get_outer()==actor
                script=exporter._export(u,obj,folder/'S3_script.t3d')
                scripts.append(dict(path=obj.get_path_name(),actor=actor.get_path_name(),actor_guid=actor.get_editor_property('actor_guid').export_text(),type=obj.get_class().get_name(),AnchorId=obj.get_editor_property('AnchorId').export_text(),GateMaterialOverride=obj.get_editor_property('GateMaterialOverride').get_path_name(),LeverSide=str(obj.get_editor_property('LeverSide')),HasCrawl=obj.get_editor_property('HasCrawl'),raw=script))
'''+s[end:]
assert not new.exists();new.write_text(s);print('SERIALIZED_SOURCE_SELECTION_PREFLIGHT_READY')
