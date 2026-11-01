// The pickle mimic's feet and gait. It has no legs (Stephen 2026-10-31: "it just needs to be the foot that can be
// magically floating and moving up and down as the character moves"): the walker plants and lifts four feet and the
// entity script draws a floating block foot at each, so the legs carry no rig chains. A leg's "hip" is only the point
// over its rest foot that the gait measures reach from, and its chain geometry only the reach the gait plans with (how
// far a foot may trail or lead), not anything drawn.
//
// The gait is a trot: the diagonal pairs swing together (front-right with back-left, then front-left with back-right),
// half a cycle apart.
//
// Every number here is measured in the walker body's frame (cm: +X the face's direction, +Y right, +Z up; the origin is
// the jar's base centre, Clearance over the ground standing) and matches the art contract of
// Tools/Blender/mars_monsters/build_pickle_mimic_pieces.py: the rest foot on the ground on the diagonal just outside the
// jar's base (far enough out that the feet clear the glass when it sits down). Change the art and these together.
namespace utils_pickle_mimic
{
    // The jar's base over the ground standing (SurfaceMotion clearance); the rest feet stand on that ground.
    const float32 Clearance = 30.0f;

    // Disguised, the walker body sinks this far below the root (the base 11 over the ground, sat between its feet).
    const float32 TuckDrop = 19.0f;

    const FVector FrontRightHip = FVector(28.28, 28.28, 0.0);
    const FVector FrontRightRestFoot = FVector(28.28, 28.28, -30.0);
    const FVector FrontRightPole = FVector(60.0, 60.0, 30.0);

    // The reach the gait plans with: twice this, from the hip.
    const float32 ReachSegment = 26.0f;

    int32 Get_LegCount()
    {
        return 4;
    }

    // Front-right, front-left, back-right, back-left.
    FName Get_LegId(int32 InLegIndex)
    {
        if (InLegIndex == 0)
        { return n"LegFR"; }

        if (InLegIndex == 1)
        { return n"LegFL"; }

        if (InLegIndex == 2)
        { return n"LegBR"; }

        return n"LegBL";
    }

    // The leg's mirror of the front-right numbers: X flips for the back legs, Y for the left ones.
    FVector Get_LegMirror(int32 InLegIndex)
    {
        const auto Front = InLegIndex < 2 ? 1.0 : -1.0;
        const auto Right = (InLegIndex % 2) == 0 ? 1.0 : -1.0;
        return FVector(Front, Right, 1.0);
    }

    FVector Get_HipLocal(int32 InLegIndex)
    {
        return FrontRightHip * Get_LegMirror(InLegIndex);
    }

    FVector Get_RestFootLocal(int32 InLegIndex)
    {
        return FrontRightRestFoot * Get_LegMirror(InLegIndex);
    }

    // The trot: front-right and back-left lift at 0, front-left and back-right half a cycle later.
    float32 Get_TrotPhase(int32 InLegIndex)
    {
        return (InLegIndex == 0 || InLegIndex == 3) ? 0.0f : 0.5f;
    }

    TArray<FCk_ProceduralLeg_Spec> Make_Legs()
    {
        auto Lengths = TArray<float32>();
        Lengths.Add(ReachSegment);
        Lengths.Add(ReachSegment);

        auto Legs = TArray<FCk_ProceduralLeg_Spec>();
        for (int32 Index = 0; Index < Get_LegCount(); ++Index)
        {
            auto Placement = FCk_ProceduralLeg_Placement(Get_HipLocal(Index), Get_RestFootLocal(Index));
            Placement.Set_PhaseOffset(Get_TrotPhase(Index));

            auto Chain = FCk_ProceduralLeg_ChainGeometry();
            Chain.Set_SegmentLengths(Lengths);
            Chain.Set_PoleLocal(FrontRightPole * Get_LegMirror(Index));

            Legs.Add(FCk_ProceduralLeg_Spec(Get_LegId(Index), Placement, Chain));
        }

        return Legs;
    }
}

// The data assets bind CK_PROPERTY setters, so the blocks fill their fields through field method calls; inside the
// feature's namespace because a global asset literal is not referenceable from other files.
namespace utils_pickle_mimic
{
    asset Mars_PickleMimicRig of UCk_ProceduralRig_Data
    {
        _Legs.Append(utils_pickle_mimic::Make_Legs());
    }

    // A quick, stompy trot: a 0.5 s cycle whose swings last 0.22 s (each diagonal pair in the air a little under half the
    // time), the feet lifted 12 cm (they read as hopping up and down), short strides kept round the rest feet. The
    // cadence reference is a slow walk; the hunt runs the cycle faster.
    asset Mars_PickleMimicGait of UCk_ProceduralGait_Data
    {
        _Timing.Set_CycleDuration(FCk_Time(0.5));
        _Timing.Set_StepDuration(FCk_Time(0.22));
        _Timing.Set_CadenceSpeedRef(110.0f);
        _Timing.Set_MaxCadenceScale(2.4f);
        _Step.Set_Height(12.0f);
        _Step.Set_Threshold(14.0f);
        _Step.Set_MaxVelocityLead(22.0f);
    }
}
