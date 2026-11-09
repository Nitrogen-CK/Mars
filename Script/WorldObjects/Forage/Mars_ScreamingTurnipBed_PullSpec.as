// The Screaming Turnip bed's pull tuner (UMars_ScreamingTurnipBed_EntityScript.Pull, ExposeOnSpawn): how far and how
// high the stalks stretch, the spring the stretch follows the walk with, and the pull's timings. Assembly data: the
// Control kernel gets WalkCm and its spring from it, the presentation the stretch. The spawn-params generator emits a
// non-default value as the positional constructor calls, nested.

// How far the crown is drawn toward the puller at alpha 1: TravelCm along the planted mesh's -X (the Use side) and LiftCm
// up, in the mesh's own space. The bed's Control reads TravelCm of ground walked as alpha 1 (WalkCm), so the stalks keep
// pace with the player; the HarvestGrip sockets swing about 2 cm past the crown at full pitch (authored), so the gloves
// travel TravelCm + ~2 and the arms give the difference. TravelCm must stay inside the mesh's safe range
// (constants_screaming_turnip_assets::k_StretchTravelSafeMinCm .. MaxCm). The defaults are the manifest's
// (gameplay_numbers.k_StretchTravelCm_default / k_StretchLiftCm_default): the 4x stretch, and the lift that with the
// clips' own 2 cm crown rise reproduces Phase J's full-strain height.
struct FMars_ScreamingTurnipBed_StretchSpec
{
    UPROPERTY()
    float32 TravelCm = 146.2f;

    UPROPERTY()
    float32 LiftCm = 18.0f;

    FMars_ScreamingTurnipBed_StretchSpec() {}

    FMars_ScreamingTurnipBed_StretchSpec(float32 InTravelCm, float32 InLiftCm)
    {
        TravelCm = InTravelCm;
        LiftCm = InLiftCm;
    }
}

// The Control's spring and threshold: Alpha'' = Stiffness (Pull - Alpha) - Damping Alpha'; the root pops at EngageAlpha.
// 400 / 40 is critically damped (time constant ~50 ms): about 20 cm of lag at a full backward walk, a visible load read
// that does not trail the walk by half the stretch (the lever's 60 / 12 did, PIE run-08).
struct FMars_ScreamingTurnipBed_SpringSpec
{
    UPROPERTY()
    float32 Stiffness = 400.0f;

    UPROPERTY()
    float32 Damping = 40.0f;

    UPROPERTY()
    float32 EngageAlpha = 0.97f;

    FMars_ScreamingTurnipBed_SpringSpec() {}

    FMars_ScreamingTurnipBed_SpringSpec(float32 InStiffness, float32 InDamping, float32 InEngageAlpha)
    {
        Stiffness = InStiffness;
        Damping = InDamping;
        EngageAlpha = InEngageAlpha;
    }
}

// GripSeconds: SRC_Grip's span from the press (twice its authored 0.2 s, the maintainer's 2026-11-06 ruling).
// CancelSecondsFromFullStrain: SRC_Cancel's span for the whole clip, one play rate from any strain (0.23 s authored / 0.7,
// about 0.33, keeps the socket motion under 1.5 cm per 60 Hz sample; Phase J Part 1). TurnDegreesPerSecond: how fast the
// planted root turns its Use side toward the puller, through the Grip clip rather than a snap.
struct FMars_ScreamingTurnipBed_TimingSpec
{
    UPROPERTY()
    float32 GripSeconds = 0.4f;

    UPROPERTY()
    float32 CancelSecondsFromFullStrain = 0.7f;

    UPROPERTY()
    float32 TurnDegreesPerSecond = 540.0f;

    FMars_ScreamingTurnipBed_TimingSpec() {}

    FMars_ScreamingTurnipBed_TimingSpec(float32 InGripSeconds, float32 InCancelSecondsFromFullStrain, float32 InTurnDegreesPerSecond)
    {
        GripSeconds = InGripSeconds;
        CancelSecondsFromFullStrain = InCancelSecondsFromFullStrain;
        TurnDegreesPerSecond = InTurnDegreesPerSecond;
    }
}

struct FMars_ScreamingTurnipBed_PullSpec
{
    UPROPERTY()
    FMars_ScreamingTurnipBed_StretchSpec Stretch;

    UPROPERTY()
    FMars_ScreamingTurnipBed_SpringSpec Spring;

    UPROPERTY()
    FMars_ScreamingTurnipBed_TimingSpec Timing;

    FMars_ScreamingTurnipBed_PullSpec() {}

    FMars_ScreamingTurnipBed_PullSpec(FMars_ScreamingTurnipBed_StretchSpec InStretch, FMars_ScreamingTurnipBed_SpringSpec InSpring,
                                      FMars_ScreamingTurnipBed_TimingSpec InTiming)
    {
        Stretch = InStretch;
        Spring = InSpring;
        Timing = InTiming;
    }
}

// A travel that walks somewhere, is finite and stays inside the mesh's safe range, a finite lift, a spring that moves and never feeds energy in, a threshold
// inside (0, 1], positive spans and a turn that turns. The bed ensures on it and destroys itself.
mixin FMars_Validation Validate(const FMars_ScreamingTurnipBed_PullSpec& Self)
{
    const auto& Stretch = Self.Stretch;
    if (Math::IsFinite(Stretch.TravelCm) == false || Stretch.TravelCm <= 0.0f)
    { return FMars_Validation(f"Pull.Stretch.TravelCm [{Stretch.TravelCm}] is not a positive finite distance"); }

    const auto SafeMin = constants_screaming_turnip_assets::k_StretchTravelSafeMinCm;
    const auto SafeMax = constants_screaming_turnip_assets::k_StretchTravelSafeMaxCm;
    if (Stretch.TravelCm < SafeMin || Stretch.TravelCm > SafeMax)
    { return FMars_Validation(f"Pull.Stretch.TravelCm [{Stretch.TravelCm}] is outside the mesh's safe range [{SafeMin}, {SafeMax}] cm"); }

    if (Math::IsFinite(Stretch.LiftCm) == false)
    { return FMars_Validation(f"Pull.Stretch.LiftCm [{Stretch.LiftCm}] is not finite"); }

    const auto& Spring = Self.Spring;
    if (Spring.Stiffness <= 0.0f)
    { return FMars_Validation(f"Pull.Spring.Stiffness [{Spring.Stiffness}] is not positive"); }

    if (Spring.Damping < 0.0f)
    { return FMars_Validation(f"Pull.Spring.Damping [{Spring.Damping}] is negative"); }

    if (Spring.EngageAlpha <= 0.0f || Spring.EngageAlpha > 1.0f)
    { return FMars_Validation(f"Pull.Spring.EngageAlpha [{Spring.EngageAlpha}] is outside (0, 1]"); }

    const auto& Timing = Self.Timing;
    if (Timing.GripSeconds <= 0.0f)
    { return FMars_Validation(f"Pull.Timing.GripSeconds [{Timing.GripSeconds}] is not positive"); }

    if (Timing.CancelSecondsFromFullStrain <= 0.0f)
    { return FMars_Validation(f"Pull.Timing.CancelSecondsFromFullStrain [{Timing.CancelSecondsFromFullStrain}] is not positive"); }

    if (Timing.TurnDegreesPerSecond <= 0.0f)
    { return FMars_Validation(f"Pull.Timing.TurnDegreesPerSecond [{Timing.TurnDegreesPerSecond}] is not positive"); }

    return FMars_Validation();
}
