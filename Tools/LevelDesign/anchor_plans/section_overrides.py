"""Apply reviewed local sections by exact source geometry, never array index.

This runs after tile assignment so fragments retain their original ownership.
Unrecognized or changed source pieces fail before the manifest is emitted.
"""
import copy
import json
from pathlib import Path

FIELDS = ('kind', 'centre', 'size', 'yaw', 'pitch', 'tile')


def same_box(a, b):
    for key in FIELDS:
        av, bv = a.get(key), b.get(key)
        if isinstance(av, (list, tuple)):
            if not isinstance(bv, (list, tuple)) or len(av) != len(bv):
                return False
            if any(abs(x-y) > 1e-6 for x, y in zip(av, bv)):
                return False
        elif isinstance(av, (float, int)) and isinstance(bv, (float, int)):
            if abs(av-bv) > 1e-6:
                return False
        elif av != bv:
            return False
    return True


def load(relative):
    path = Path(__file__).resolve().parent / relative
    assert path.parent == Path(__file__).resolve().parent / 'data'
    return json.loads(path.read_text(encoding='utf-8'))


def apply(manifest, sections):
    reports = []
    for entry in sections:
        section = load(entry['file'])
        edits = [(row['source'], row['replacements']) for row in section['splits']]
        edits += [(row, []) for row in section['removed_boxes']]
        replacements = {}
        # Resolve the entire contract before changing this manifest.
        for source, fragments in edits:
            matches = [i for i, row in enumerate(manifest['boxes']) if same_box(source, row)]
            assert len(matches) == 1, ('Section source mismatch', section['id'], source, matches)
            index = matches[0]
            assert index not in replacements, ('Overlapping section edits', index)
            replacements[index] = []
            for fragment in fragments:
                row = copy.deepcopy(manifest['boxes'][index])
                row.update({key: copy.deepcopy(fragment[key]) for key in FIELDS})
                row['sourceId'] = section['id'] + ':split:' + str(source['index'])
                replacements[index].append(row)
        old = section['remove_entity']
        entities = [row for row in manifest['entities']
                    if row['cls'] == old['cls'] and row['at'] == old['at']]
        assert len(entities) == 1, ('Section entity mismatch', old, entities)
        manifest['boxes'][:] = [piece for i, row in enumerate(manifest['boxes'])
                               for piece in replacements.get(i, [row])]
        for added in section['added_boxes']:
            row = {key: copy.deepcopy(added[key]) for key in FIELDS if key in added}
            row['tile'] = 'Waterworks-W' if row['centre'][0] < 70 else 'Canal'
            row['sourceId'] = section['id'] + ':' + added['name']
            manifest['boxes'].append(row)
        manifest['entities'].remove(entities[0])
        manifest['entities'].append(copy.deepcopy(entry['entity']))
        reports.append(dict(id=section['id'], removed_sources=len(edits),
                            replacement_fragments=sum(len(rows) for rows in replacements.values()),
                            added_static_solids=len(section['added_boxes']),
                            moving_support='Runtime owner; absent from static floor acceptance',
                            boundary=section['proof_boundary']))
    manifest['sectionOverrides'] = reports
    return reports
