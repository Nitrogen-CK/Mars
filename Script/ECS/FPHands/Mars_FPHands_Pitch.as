// How much of the view's pitch the gloves take. The hand chain hangs off the rendered view, which would fix the gloves on
// screen whatever the player looks at; a pitch node between the view and the hand chain turns the chain back, about the
// eye, by the part of the pitch the gloves do not follow. They keep the view's yaw, so they always face where the player
// turns, but stay nearer where the body would hold them: looking up, they sink toward the bottom of the screen.
struct FMars_FPHands_PitchSpec
{
    // The scene node between the view and the hand chain (Player.HandPitch). Invalid = the gloves take the whole pitch.
    UPROPERTY()
    FCk_Handle_SceneNode Node;

    // Fraction of an upward look the gloves follow, 0..1. 1 = fixed on screen; 0 = they stay level with the horizon.
    UPROPERTY()
    float32 FollowUp = 0.4f;

    // Fraction of a downward look the gloves follow, 0..1. Below 1 they rise toward the middle of the screen.
    UPROPERTY()
    float32 FollowDown = 1.0f;

    // How quickly the gloves take up a change of pitch (1/s); unset snaps. The view's pitch is read one frame behind the
    // render, so a snap shakes the gloves against the screen under a fast look; the ease hides that.
    UPROPERTY()
    TOptional<float32> InterpSpeed = TOptional<float32>(20.0f);

    // Where the gloves sink to while they are lowered (an armed throw, so the path and its landing are in view).
    UPROPERTY()
    FMars_FPHands_LowerSpec Lower;
}

// The lowered gloves, relative to where the pitch node would hold them: moved by Offset in the view's frame (X forward,
// Y right, Z up) and pitched by PitchDeg (down is negative), eased in and out at InterpSpeed (1/s).
struct FMars_FPHands_LowerSpec
{
    UPROPERTY()
    FVector Offset = FVector(0.0, 0.0, -14.0);

    UPROPERTY()
    float32 PitchDeg = -14.0f;

    UPROPERTY()
    float32 InterpSpeed = 10.0f;
}

// Both follow fractions within 0..1, InterpSpeed positive when set.
mixin FMars_Validation Validate(const FMars_FPHands_PitchSpec& Self)
{
    if (Self.FollowUp < 0.0f || Self.FollowUp > 1.0f)
    { return FMars_Validation(f"Pitch.FollowUp [{Self.FollowUp}] is outside [0, 1]"); }

    if (Self.FollowDown < 0.0f || Self.FollowDown > 1.0f)
    { return FMars_Validation(f"Pitch.FollowDown [{Self.FollowDown}] is outside [0, 1]"); }

    if (Self.InterpSpeed.IsSet() && (Self.InterpSpeed.GetValue() > 0.0f) == false)
    { return FMars_Validation(f"Pitch.InterpSpeed [{Self.InterpSpeed.GetValue()}] is not positive (unset snaps)"); }

    if ((Self.Lower.InterpSpeed > 0.0f) == false)
    { return FMars_Validation(f"Pitch.Lower.InterpSpeed [{Self.Lower.InterpSpeed}] is not positive"); }

    return FMars_Validation();
}

namespace utils_fphands
{
    // The pitch the gloves end up with for a view pitched InViewPitchDeg (up is positive).
    float32 Get_FollowedPitch(const FMars_FPHands_PitchSpec& InSpec, float32 InViewPitchDeg)
    {
        return InViewPitchDeg * (InViewPitchDeg >= 0.0f ? InSpec.FollowUp : InSpec.FollowDown);
    }

    // The pitch node's offset for that view: the rest of the pitch, turned back about the view's origin, then InLowerAlpha
    // (0..1) of the spec's Lower.
    FTransform Make_PitchOffset(const FMars_FPHands_PitchSpec& InSpec, float32 InViewPitchDeg, float32 InLowerAlpha)
    {
        const auto PitchDeg = Get_FollowedPitch(InSpec, InViewPitchDeg) - InViewPitchDeg + InSpec.Lower.PitchDeg * InLowerAlpha;
        return FTransform(FRotator(PitchDeg, 0.0, 0.0), InSpec.Lower.Offset * InLowerAlpha, FVector::OneVector);
    }
}

// The view pitch the pitch node was last set from (eased, degrees, up is positive); unset before the first tick with a
// pitch node.
mixin TOptional<float32> Get_ViewPitch(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).ViewPitchDeg;
}

// Whether the gloves are asked to be lowered (Request_SetLowered).
mixin bool Get_IsLowered(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).Lowered;
}

// How far the gloves have eased into their lowered pose, 0..1.
mixin float32 Get_LowerAlpha(const FCk_Handle_FPHands& Self)
{
    return Self.Get_Fragment(FMars_Fragment_FPHands).LowerAlpha;
}
