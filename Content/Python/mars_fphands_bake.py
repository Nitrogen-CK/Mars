"""Bakes the first-person glove grip poses into Script/PlayerCharacter/FPHands/Mars_FPHands_PoseData.as.

The finger-contact solver (Mars_FPHands_Contact.as) replays each digit's curl from rest toward its grip pose, but
runtime script cannot sample animation assets, so the local rotations of the 24 digit bones are baked here.
Run in the editor after re-importing any A_FPHands_* pose:  py mars_fphands_bake.py   (or via Monolith run_python)
"""
import os
import unreal
ANIMS = "/Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/"
POSES = ["A_FPHands_Relaxed", "A_FPHands_Grip_Power", "A_FPHands_Grip_Pinch", "A_FPHands_Grip_Cradle",
         "A_FPHands_Grip_Hook", "A_FPHands_Fist", "A_FPHands_Open"]           # EMars_HandGripPose order
DIGITS = ["thumb", "index", "middle", "pinky"]
BONES = ["%s_%02d_%s" % (d, s, side) for side in ("l", "r") for d in DIGITS for s in (1, 2, 3)]
OUT = os.path.join(unreal.Paths.project_dir(), "Script/PlayerCharacter/FPHands/Mars_FPHands_PoseData.as")
rows = []
for pi, name in enumerate(POSES):
    anim = unreal.load_asset(ANIMS + name)
    for bi, bone in enumerate(BONES):
        t = unreal.AnimationLibrary.get_bone_pose_for_time(anim, bone, 0.0, False)
        q = t.rotation
        rows.append("            case %d: return FQuat(%.6f, %.6f, %.6f, %.6f); // %s %s" % (pi * len(BONES) + bi, q.x, q.y, q.z, q.w, name[10:], bone))
src = """// GENERATED - do not edit. Baked from /Game/Mars/Gameplay/PlayerCharacter/FPHands/Anims/A_FPHands_* by
// Content/Python/mars_fphands_bake.py. Re-bake after re-importing the grip poses.
// Local (parent-space) rotations of the 24 digit bones for each EMars_HandGripPose; runtime cannot sample anim poses.
namespace mars_fphands_posedata
{
    const int32 BoneCount = %d;

    // Bone order: per side (l, r): thumb, index, middle, pinky x segments 01..03.
    FName Get_BoneName(int32 InBone)
    {
        switch (InBone)
        {
%s
        }
        return NAME_None;
    }

    FQuat Get_Rotation(EMars_HandGripPose InPose, int32 InBone)
    {
        switch (int32(InPose) * BoneCount + InBone)
        {
%s
        }
        return FQuat::Identity;
    }
}
""" % (len(BONES), "\n".join('            case %d: return n"%s";' % (i, b) for i, b in enumerate(BONES)), "\n".join(rows))
open(OUT, "w", newline="\n").write(src)
print("baked", len(rows), "rotations ->", OUT)
