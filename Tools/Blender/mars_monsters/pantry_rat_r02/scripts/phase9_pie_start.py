"""Phase 9 PIE probe (run as a capture_pie_movement_clip probe script, inside PIE): the theft story with rat-relative framing -
side views (rat's right) through Emerge, BoundApproach and FleeWithLoot, a top view through Inspect / ClaimTell - and per-phase
slow motion so a 0.4 s capture interval samples the 0.4 s bound every 0.05 s of game time (slomo 0.125) and the creep every
0.1 s (slomo 0.25)."""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else \
    "D:/Repositories/CkRepos/Orion/Tools/Blender/mars_monsters/pantry_rat_r02/scripts"
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import pantry_rat_court_ue as m  # noqa: E402

importlib.reload(m)
SIDE = (0.0, 170.0, 16.0, 8.0, 0.0)      # (fwd, side, up, look_up, look_fwd), cm in the rat's frame; side + = its right
TOP = (-60.0, 0.0, 330.0, 0.0, 30.0)
m.story_start("theft")
m.frame_start([(("Emerge", "BoundApproach", "FleeWithLoot", "FleePause"), SIDE), (("Inspect", "ClaimTell", "ClaimTransfer"), TOP)],
              default=(110.0, 70.0, 25.0, 15.0, 10.0), rate=8.0,
              slomo_phases={"Emerge": 0.25, "BoundApproach": 0.125, "FleeWithLoot": 0.125, "Inspect": 0.25})
