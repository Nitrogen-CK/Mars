//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

// Composed ON the dynamic body's entity, so a contact handler resolves it straight from the body. The caller adds the
// body first, with FCk_JoltBody_Spec.Set_PersistContacts(ECk_EnableDisable::Enable): without it a resting awake body
// reports no contact after the first step and goes Apart once GraceSeconds pass.
asset Mars_RestingHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Resting";
    RequiredFragments.Add(FMars_Feature_Resting);
    Description = "Whether this entity's dynamic body rests on any of its target bodies (and on which): a recent contact, or asleep while resting; apart/resting edges and landings";
}
struct FMars_Feature_Resting {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Resting_State
{
    Apart,
    Resting
}

struct FMars_Resting_Spec
{
    // The entities whose bodies count, each compared with the contact payload's other entity. Resting on any of them is
    // resting; Get_IsRestingOn tells them apart.
    UPROPERTY()
    TArray<FCk_Handle> Targets;

    // A contact this old still counts (contact events arrive from the previous physics step).
    UPROPERTY()
    float32 GraceSeconds = 0.1f;

    // A landing after at least this long apart is a hop.
    UPROPERTY()
    float32 HopMinSeconds = 0.12f;

    FMars_Resting_Spec() {}

    FMars_Resting_Spec(FCk_Handle InTarget)
    {
        Targets.Add(InTarget);
    }

    FMars_Resting_Spec(FCk_Handle InTarget, float32 InGraceSeconds, float32 InHopMinSeconds)
    {
        Targets.Add(InTarget);
        GraceSeconds = InGraceSeconds;
        HopMinSeconds = InHopMinSeconds;
    }

    FMars_Resting_Spec(const TArray<FCk_Handle>& InTargets, float32 InGraceSeconds, float32 InHopMinSeconds)
    {
        Targets = InTargets;
        GraceSeconds = InGraceSeconds;
        HopMinSeconds = InHopMinSeconds;
    }
}

// Without a target nothing can be rested on, and an invalid or repeated one cannot be told apart; a zero grace drops every
// contact at once; a negative hop time is meaningless.
mixin FMars_Validation Validate(const FMars_Resting_Spec& Self)
{
    if (Self.Targets.Num() == 0)
    { return FMars_Validation("Resting has no Targets"); }

    for (int32 Index = 0; Index < Self.Targets.Num(); ++Index)
    {
        if (ck::Is_NOT_Valid(Self.Targets[Index]))
        { return FMars_Validation(f"Resting has an invalid Targets[{Index}] [{Self.Targets[Index].ToString()}]"); }

        for (int32 Earlier = 0; Earlier < Index; ++Earlier)
        {
            if (Self.Targets[Earlier] == Self.Targets[Index])
            { return FMars_Validation(f"Resting has Targets[{Index}] [{Self.Targets[Index].ToString()}] repeating Targets[{Earlier}]"); }
        }
    }

    if (Self.GraceSeconds <= 0.0f)
    { return FMars_Validation(f"Resting has a non-positive GraceSeconds [{Self.GraceSeconds}]"); }

    if (Self.HopMinSeconds < 0.0f)
    { return FMars_Validation(f"Resting has a negative HopMinSeconds [{Self.HopMinSeconds}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Resting_Params
{
    UPROPERTY()
    FMars_Resting_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Written only by the Resting processors (and Add).
struct FMars_Fragment_Resting
{
    // Resting on any target.
    UPROPERTY()
    EMars_Resting_State State = EMars_Resting_State::Apart;

    // Parallel to the spec's Targets: seconds since the last contact with that target (0 on each Added / Persisted event;
    // k_NoContactAge before the first).
    UPROPERTY()
    TArray<float32> ContactAges;

    // Parallel to the spec's Targets: the last verdict for that target (a recent contact, or asleep while resting on it).
    UPROPERTY()
    TArray<bool> RestingOn;

    // Consecutive seconds Apart.
    UPROPERTY()
    float32 ApartSeconds = 0.0f;

    // Landings after at least HopMinSeconds apart.
    UPROPERTY()
    int32 Hops = 0;

    // This entity's body. Written only by Add.
    UPROPERTY()
    FCk_Handle_JoltBody Body;
}

// The Setup processor binds the body's contact signals once, then removes this tag.
struct FMars_Tag_Resting_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Apart <-> Resting edges.
delegate void FMars_Delegate_Resting_OnRestingChanged(FCk_Handle_Resting InResting, EMars_Resting_State InState);
event void FMars_Delegate_Resting_OnRestingChanged_MC(FCk_Handle_Resting InResting, EMars_Resting_State InState);

// A landing after at least HopMinSeconds apart (a hop); InApartSeconds is how long it was apart.
delegate void FMars_Delegate_Resting_OnLanded(FCk_Handle_Resting InResting, float32 InApartSeconds);
event void FMars_Delegate_Resting_OnLanded_MC(FCk_Handle_Resting InResting, float32 InApartSeconds);

struct FMars_Fragment_Resting_Signals
{
    FMars_Delegate_Resting_OnRestingChanged_MC OnRestingChanged;
    FMars_Delegate_Resting_OnLanded_MC OnLanded;
}
