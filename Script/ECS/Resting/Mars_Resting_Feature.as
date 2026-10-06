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
    Description = "Whether this entity's dynamic body rests on one target body: a recent contact, or asleep while resting; apart/resting edges and landings";
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
    // The entity whose body counts (compared with the contact payload's other entity).
    UPROPERTY()
    FCk_Handle Target;

    // A contact this old still counts (contact events arrive from the previous physics step).
    UPROPERTY()
    float32 GraceSeconds = 0.1f;

    // A landing after at least this long apart is a hop.
    UPROPERTY()
    float32 HopMinSeconds = 0.12f;

    FMars_Resting_Spec() {}

    FMars_Resting_Spec(FCk_Handle InTarget)
    {
        Target = InTarget;
    }

    FMars_Resting_Spec(FCk_Handle InTarget, float32 InGraceSeconds, float32 InHopMinSeconds)
    {
        Target = InTarget;
        GraceSeconds = InGraceSeconds;
        HopMinSeconds = InHopMinSeconds;
    }
}

// Without a target nothing can be rested on; a zero grace drops every contact at once; a negative hop time is meaningless.
mixin FMars_Validation Validate(const FMars_Resting_Spec& Self)
{
    if (ck::Is_NOT_Valid(Self.Target))
    { return FMars_Validation(f"Resting has an invalid Target [{Self.Target.ToString()}]"); }

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
    UPROPERTY()
    EMars_Resting_State State = EMars_Resting_State::Apart;

    // Seconds since the last contact with the target; 0 on each Added / Persisted event.
    UPROPERTY()
    float32 ContactAge = 999.0f;

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
