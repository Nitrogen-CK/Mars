"""Append current evidence and correct the superseded palette export contract."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024'
state = DOC/'lookdev/catacomb-shape-pbr-r03/STATE_CURRENT.md'
text = '''

CURRENT R52 - R51 PALETTE-BAKED NATIVE CLAIM SUPERSEDED. All r06 *-palette-export-r01 exports are QUARANTINED for native import. Actual raw-FBX audit reproduced vertex UNorm clipping: Hall walls5412/124722 corners, Ossuary walls12012/125490, Cellar floor36/14880; Sluice kept on the same original pipeline. four_room_vertex_range_contract_r01.json confirms all12 ORIGINAL export-r05 family FBXs have zero out-of-range RGB. Use hall-export-r02, ossuary-export-r01, cellar-export-r01, sluice-export-r01 with range-safe original StoneTint, accepted native gain and RoomTint material parameter. Do not silently clip or normalize palette-baked data. The prior floating FBX corner audit was not native UNorm acceptance.

R52 Larder downward raw-shell colour axis ACCEPTED by Astra dc461bbd (native-ceiling-colour-r14/ASTRA_CEILING_COLOUR_RESULT_R14.md): measured ceiling family successor, independent normal/roughness outputs unchanged. Roof strip BaseColor80/66/49 vs adjacent82/68/51; all3 A/C PNG-byte exact. Normal cleanup finish_room_trial_r10/restored.json proved8 actors absent and original383HISMs/45452instances/five source lights exact. Complete Larder/source/library remains HELD for remaining fitted/bay context. Freeze accepted window/light/props/brine/highroof/raw-shell axes.

R52 reusable RoomTint white-copy native parity ACCEPTED by Astra0fffb67e (remaining-room-rollout-r01/native-room-tint-parity-r15/ASTRA_ROOM_TINT_WHITE_RESULT_R15.md). Walls/floor Lit+BaseColor A/B/C all RGB pixels identical; local ceiling Lit A/B exact, BaseColor A/B12pixels max3 and unchanged A/C10pixels max2 in same context patch. Do not claim perfect whole-frame ceiling parity or known cause. Normal cleanup finish_room_trial_r11/restored.json:4 owned actors absent, original383HISMs/45452instances/five lights exact. Three copied family graphs remain transient/unbound, RoomTint white, original independent R03 normal/roughness textures retained. Concrete three-absent-private-master helper/gate now prepared for Astra; no saved masters/MI/mesh/native four-room rollout yet.

R52 fitted-context family transient built/compiled ONLY: fitted-context-family-r01/transient_build_readback_r01.json. Measured native family palettes at64 area quantiles; independent existing N/R; no second drawn course grid.372pixel/151vertex instructions,12pixeltexture samples,6samplers; no FPS claim. Native source RGB is in range; Walls alpha1.0000001192 caused earlier strict RGBA assertion, NOT RGB clipping. This is separate from real four-room palette-baked RGB clipping. Five decorative NoCollision static HISM targets2788 instances, actual preserved nonzero seeds10459/9541/13470/14535/29462. Proposed finite material-only trial finish_room_trial_r12/native-fitted-stone-r16 pending Astra gate; no binding yet. Hard abs(N.z)=.99 family transition and statistical instance-area distribution need native bevel/context review.

R52 CURRENT EDITOR verified Main/noPIE/no dirty packages; all canonical+9 private Larder asset guards exact. All former PIE controller/capture STATEs None, no retained world/pawn/helper references. Ninth saved private HighRoof remains2292a9a6; never rerun its Factory importer. Continue independent private four-room assets/native diagnostics while finishing Larder; then source/native+Blender library adoption and ALL remaining rooms/entrances/connectors. Mill source-floor derivation remains blocked pending actual ramp/non-Cube attribution; no fabricated nominal-z floor. Sluice native-library obligation remains open. No C++/AngelScript edits/build-test claim, stage/commit/push.
'''
existing = state.read_bytes()
assert b'CURRENT R52 -' not in existing
with state.open('ab') as file:
    file.write(text.encode('utf-8'))
progress = DOC/'PROGRESS.md'
rows = progress.read_bytes().splitlines(keepends=True)
line, = [i for i, value in enumerate(rows) if value.startswith(b'**Current - ')]
ending = b'\r\n' if rows[line].endswith(b'\r\n') else b'\n'
rows[line] = b'**Current - R52:** Larder R14 downward colour and R15 neutral RoomTint copies accepted by Astra. Remaining fitted-context trial and three private material masters prepared; no bindings/saves released yet. Four-room palette-baked exports quarantined for measured UNorm clipping; use original in-range FBXs + RoomTint. Main/noPIE/0dirty/canonical+9 exact. Continue all remaining rooms and native/Blender library sync; complete Larder/source adoption still held. See STATE_CURRENT.md R52.'+ending
progress.write_bytes(b''.join(rows))
print('CURRENT_STATE_R52_APPENDED_AND_PROGRESS_LINE_UPDATED')
