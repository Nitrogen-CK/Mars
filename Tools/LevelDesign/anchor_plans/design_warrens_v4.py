"""Warrens v4 proposal: v3's plan graph, fleshed out (run: python design_warrens_v4.py -> data/warrens_v4.json; NOT live).

Same nodes, links, closure group, anchor tags, crawls, shortcuts, Rafters and ladders as v3, so the emitted plan, the
solver tests and the registered tags stay valid. What changes is everything the plan graph does not see:
- rooms stop being flat rectangles: the Charnel Court is a sunken arena with a rim, the Lamp Chapel an octagon with a
  station apron, the Root Shaft a railed trench that opens down into the Undercroft (the one place all three levels
  are seen at once), the Ossuary an aisle maze of bone stacks;
- a pocket layer: dead-end burial niches off every room and ring tunnel, each a socket for a flavour anchor family
  (F forage, C cache, O omen, T threat, X trap, N lantern rest, P pack plinth). v3 has none: its only dead ends are the
  five foyers;
- water: a wade basin in the Cistern and a gutter in the Sluice and Undercroft, so three rooms sound different;
- landmark props: the mourner statue, bone stacks, roots in the shaft, the chimes, candle clusters (tallow forage).
Builder work needed to build this (viewer.js lists the schema): polygon rooms, per-cell floor height / extraRamps,
niches as walkable rects, water as sunken floor, props as placed meshes. Metres; +X east, +Y north; z = floor height.
"""
import json
from pathlib import Path

import design_warrens_v3 as v3

OUT = Path(__file__).resolve().parent / 'data' / 'warrens_v4.json'

ROOMS = [
    # The Lamp Chapel: an octagon round the hearth, 9 m tall, the station apron along its north wall.
    dict(id='chapel', label='Lamp Chapel', poly=[(43, 32), (53, 32), (57, 36), (57, 44), (53, 48), (43, 48), (39, 44), (39, 36)], z=0, light='hearth'),
    # The Charnel Court: a sunken arena (-1.5) ringed by a 3 m rim at 0; the rim is where the pack waits and the retreat runs.
    dict(id='court', label='Charnel Court', poly=[(6, 28), (10, 24), (24, 24), (28, 30), (28, 50), (20, 52), (6, 50)], z=0, light='cold'),
    dict(id='court-pit', label='', rect=(9, 28, 25, 46), z=-1.5),
    dict(id='ossuary', label='Ossuary', rect=(30, 56, 44, 68), z=0, light=None),
    dict(id='reliquary', label='Reliquary', rect=(50, 56, 62, 68), z=0, light='dim'),
    # The Root Shaft: the court floor keeps 22 x 18 m clear; its east side is a railed trench down to the Undercroft.
    dict(id='shaft', label='Root Shaft', rect=(68, 40, 90, 62), z=0, light='shaft'),
    dict(id='chimes', label='Chime Room', poly=[(72, 22), (84, 22), (84, 32), (78, 34), (72, 32)], z=0, light=None),
    dict(id='cistern', label='Cistern', rect=(14, 6, 28, 18), z=0, light=None),
    dict(id='pump', label='Pump Room', rect=(34, 8, 46, 20), z=0, light='dim'),
    dict(id='sluice', label='Sluice', rect=(54, 10, 68, 22), z=0, light=None),
    dict(id='undercroft', label='Undercroft', rect=(44, 28, 68, 52), z=-5, light='cold'),
    # The shaft's foot: the Undercroft reaches east under the trench; the vault hangs off it to the south.
    dict(id='shaftfoot', label='Shaft Foot', rect=(80, 42, 92, 60), z=-5, light=None),
    dict(id='vault', label='Vault', rect=(84, 32, 92, 38), z=-5, light=None),
]
DEEP = (8, 18, 94, 62)
FOOTPRINT = (0, 0, 96, 80)

# Steps between heights (treads in the viewer; a ramp or stair for the builder).
EXTRA_RAMPS = [
    dict(id='court-steps-e', a=(27, 37, 0.0), b=(23, 37, -1.5), width=4.0, note='the Nave door down into the arena'),
    dict(id='court-steps-n', a=(14, 48, 0.0), b=(14, 44, -1.5), width=4.0, note='from the S1 side'),
    dict(id='court-steps-s', a=(18, 26, 0.0), b=(18, 30, -1.5), width=3.0, note='from the stair-head side'),
]

# Dead-end pockets: the sockets for the flavour anchors (none in the plan graph; a run rolls them after the solve).
NICHES = [
    # Charnel Court
    dict(id='court-pack', rect=(12, 52, 16, 56), z=0, family='P', note='pack plinth at the S1 mouth, 4 m from the rim'),
    dict(id='court-forage', rect=(2, 34, 6, 38), z=0, family='F', note='mushrooms in the west burial niche'),
    dict(id='court-omen', rect=(28, 44, 30, 46), z=0, family='O', note='eyes in the east wall niche'),
    dict(id='court-threat', rect=(16, 20, 20, 24), z=0, family='T', note='sentry alcove south of the arena'),
    # Ossuary and Reliquary
    dict(id='mourner', rect=(22, 58, 30, 66), z=0, family='C', note="Mourner's Table: the 8 x 8 cache alcove"),
    dict(id='ossuary-husk', rect=(34, 68, 38, 71), z=0, family='F', note='husk spill in the north niche'),
    dict(id='reliquary-omen', rect=(62, 60, 64, 64), z=0, family='O', note='lamp bank that gutters out'),
    dict(id='reliquary-rest', rect=(58, 68, 62, 71), z=0, family='N', note='lantern rest by the S2 mouth'),
    # Root Shaft
    dict(id='shaft-pack', rect=(64, 52, 68, 56), z=0, family='P', note='pack plinth outside the court, by the R4 tunnel'),
    dict(id='shaft-trap', rect=(68, 36, 72, 40), z=0, family='X', note='spike strip on the Chime side approach'),
    dict(id='rafters-vine', rect=(68, 62, 72, 66), z=5, family='F', note='vine fruit on the Rafters, under the shaft light'),
    # Chime Room, Sluice, Pump, Cistern
    dict(id='bellkeeper', rect=(74, 14, 82, 22), z=0, family='C', note="Bellkeeper's Confession, south of the chimes"),
    dict(id='chime-threat', rect=(84, 30, 88, 34), z=0, family='T', note='sentry niche beside the S3 corridor'),
    dict(id='porter', rect=(68, 8, 76, 14), z=0, family='C', note="Porter's Wager: the dead-end freight niche"),
    dict(id='sluice-rest', rect=(54, 22, 58, 25), z=0, family='N', note='lantern rest at the Sluice north wall'),
    dict(id='pump-threat', rect=(46, 8, 49, 11), z=0, family='T', note='omen-or-sentry niche behind the pump'),
    dict(id='pump-omen', rect=(30, 14, 34, 17), z=0, family='O', note='swaying chains in the west niche'),
    dict(id='cistern-forage', rect=(10, 14, 14, 18), z=0, family='F', note='mushroom bed across the basin, wet and dark'),
    dict(id='cistern-trap', rect=(28, 6, 32, 9), z=0, family='X', note='steam vent pair on the Pump side'),
    # Undercroft and Shaft Foot
    dict(id='under-rest', rect=(44, 52, 48, 56), z=-5, family='N', note='lantern rest at the lair rim'),
    dict(id='under-forage', rect=(68, 30, 72, 34), z=-5, family='F', note='deep mushrooms'),
    dict(id='under-omen', rect=(60, 52, 62, 54), z=-5, family='O', note='the inner wall niche'),
    dict(id='foot-threat', rect=(92, 50, 95, 54), z=-5, family='T', note='wall-lurker socket at the shaft foot'),
]

WATER = [
    dict(id='cistern-basin', rect=(16, 8, 24, 15), z=0, depth=0.5, note='the Cistern pool'),
    dict(id='sluice-gutter', rect=(56, 12, 66, 13.5), z=0, depth=0.4, note='the Sluice channel'),
    dict(id='under-channel', rect=(46, 30, 66, 32), z=-5, depth=0.4, note='drainage along the lair'),
]

PROPS = [
    dict(kind='statue', at=(17, 50, 0), size=(2.0, 1.2, 4.5), yaw=-90, note='split mourner: the court landmark, seen from the Nave door'),
    dict(kind='bench', at=(44, 46, 0), size=(2.0, 0.8, 0.9), note='cutting bench'),
    dict(kind='station', at=(49, 46.5, 0), size=(1.6, 1.0, 1.0), note='searing station'),
    dict(kind='station', at=(53, 46, 0), size=(1.4, 0.8, 0.9), note='platter rack'),
    dict(kind='plinth', at=(41, 38, 0), size=(1.2, 1.2, 0.3), note='pack plinth by the Nave door'),
    dict(kind='stack', at=(35, 59, 0), size=(6.0, 1.0, 2.6), note='bone stacks: the aisle maze'),
    dict(kind='stack', at=(39, 62, 0), size=(6.0, 1.0, 2.6)),
    dict(kind='stack', at=(35, 65, 0), size=(6.0, 1.0, 2.6)),
    dict(kind='sarcophagus', at=(56, 62, 0), size=(3.0, 1.5, 1.2), note='the reliquary tomb'),
    dict(kind='root', at=(87, 46, -5), size=(1.4, 1.4, 14.0), note='roots down the shaft'),
    dict(kind='root', at=(88, 51, -5), size=(1.0, 1.0, 14.0)),
    dict(kind='root', at=(87, 56, -5), size=(1.2, 1.2, 14.0)),
    dict(kind='chimes', at=(78, 27, 0), size=(6.0, 0.2, 3.5), yaw=0, note='bone chimes across the room: the native trap'),
    dict(kind='pillar', at=(43, 12, 0), size=(2.0, 2.0, 3.2), note='the pump: the audio landmark of the south'),
    dict(kind='candles', at=(46, 34, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(32, 67, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(26, 16, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(74, 30, 0), size=(0.9, 0.9, 0.5), note='tallow'),
    dict(kind='candles', at=(46, 50, -5), size=(0.9, 0.9, 0.5), note='tallow'),
]

HOLES = v3.HOLES + [
    dict(id='shaft-trench', level='main', rect=(86, 44, 90, 58), kind='open', note='the railed trench: the court looks 5 m down to the shaft foot, 5 m up to the key ledge'),
]
EXTRA_WALKS = [w for w in v3.EXTRA_WALKS if w['id'] != 'vault-passage'] + [
    dict(id='foot-passage', level='deep', pts=[(67, 48), (74, 48), (80, 50)], width=2.5, note='Undercroft to the shaft foot'),
    dict(id='vault-passage', level='deep', pts=[(88, 42), (88, 39)], width=2.5, note='shaft foot to the vault door'),
]
LOCKS = [
    dict(id='vault', door=dict(at=(88, 40.5), yaw=-90.0, spanCm=250.0, level='deep'), lock=dict(at=(86.4, 41.5), yaw=0.0, level='deep'),
         key='Red', keyAt=(88, 50, 5.0), channel='Mechanism.Channel.Keys.Red',
         note='the key lies on the ledge 10 m above the shaft foot; seen from below, fetched over the Rafters'),
]
PILLARS = [p for p in v3.PILLARS if not (p['level'] == 'main' and p['rect'][0] >= 80)] + [
    dict(level='main', rect=(80, 43, 83, 46)),  # Root Shaft cover, moved off the trench
    dict(level='deep', rect=(84, 48, 86, 50)),
]
LIGHTS = v3.LIGHTS + [dict(at=(86, 50, -2.0), kind='cold'), dict(at=(20, 12, 2.0), kind='dim')]


def build():
    data = v3.build()
    data.update(
        revision='v4',
        source='Tools/LevelDesign/anchor_plans/design_warrens_v4.py (Warrens v4 proposal, 2026-10-19: v3 graph, fleshed out)',
        footprint=list(FOOTPRINT), deep=list(DEEP),
        rooms=[dict(r, rect=list(r['rect'])) if 'rect' in r else dict(r, poly=[list(p) for p in r['poly']]) for r in ROOMS],
        holes=HOLES, extraWalks=EXTRA_WALKS, locks=LOCKS,
        pillars=[dict(p, rect=list(p['rect'])) for p in PILLARS],
        lights=[dict(l, at=list(l['at'])) for l in LIGHTS],
        extraRamps=[dict(r, a=list(r['a']), b=list(r['b'])) for r in EXTRA_RAMPS],
        niches=[dict(n, rect=list(n['rect'])) for n in NICHES],
        water=[dict(w, rect=list(w['rect'])) for w in WATER],
        props=[dict(p, at=list(p['at']), size=list(p['size'])) for p in PROPS],
    )
    return data


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, indent=1), encoding='utf-8')
    print(f'wrote {OUT.name}: {len(data["nodes"])} nodes, {len(data["links"])} links, {len(data["rooms"])} rooms, '
          f'{len(data["niches"])} pockets, {len(data["props"])} props, {len(data["water"])} water')
