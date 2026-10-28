"""Prepend current evidence while retaining legacy PROGRESS bytes exactly."""
from pathlib import Path
P=Path(__file__).resolve().parents[2]/'docs/art/warrens-c-gameplay-review-20261024/PROGRESS.md'
MARK=b'**Current, R09 native stone/static props accepted; complete room held for forage art.**'
paragraph=MARK+b' R02 angular albedo plus new geometry-baked NormalDX and independent roughness maps are connected in four compiled owned native materials and captured in packed-pawn/real-lantern PIE. Astra accepted the stone envelope, tomb/lid and ivory props in [the R09 review](lookdev/catacomb-shape-pbr-r03/NATIVE_R09_ENVELOPE_AND_FORAGE_REVIEW.md). Sparse R08 spots were rejected. [Current preview](lookdev/catacomb-shape-pbr-r03/PREVIEW.html). In-room Husk forage still needs art; preserve all seeded alternatives and gameplay. Focused prechange Toolbox Forage baseline:9/9,0failed,0contaminated,exit0. Final trial restoration:383HISMs/45440originalinstances and651protectedfiles including54collisionfiles exact; PIE stopped, zero dirty packages. No Catacomb source-level or original-library save yet. [Current state](lookdev/catacomb-shape-pbr-r03/STATE_CURRENT.md).'
raw=P.read_bytes();assert MARK not in raw
head,sep,tail=raw.partition(b'\n');assert b'Current texture rollout state' in head
P.write_bytes(head+sep+b'\r\n'+paragraph+b'\r\n'+tail)
