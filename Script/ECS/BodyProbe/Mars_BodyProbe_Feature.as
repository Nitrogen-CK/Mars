//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_BodyProbeHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_BodyProbe";
    RequiredFragments.Add(FMars_Feature_BodyProbe);
    Description = "A character's body probe: a capsule probe at the capsule centre that resizes with the character's capsule (crouch, uncrouch)";
}

struct FMars_Feature_BodyProbe {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_BodyProbe_Spec
{
    // The probe's shape comes from the character's capsule.
    UPROPERTY()
    FCk_Probe_Spec Probe;

    // Weak: the spec is retained in a fragment.
    UPROPERTY()
    TWeakObjectPtr<ACharacter> Character;

    FMars_BodyProbe_Spec() {}

    FMars_BodyProbe_Spec(FCk_Probe_Spec InProbe, ACharacter InCharacter)
    {
        Probe = InProbe;
        Character = InCharacter;
    }
}

mixin FMars_Validation Validate(const FMars_BodyProbe_Spec& Self)
{
    if (ck::Is_NOT_Valid(Self.Character.Get()))
    { return FMars_Validation("BodyProbe has no character to follow"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_BodyProbe_Params
{
    UPROPERTY()
    FMars_BodyProbe_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The capsule size the probe was last sized to.
struct FMars_Fragment_BodyProbe
{
    UPROPERTY()
    float32 HalfHeight = 0.0f;

    UPROPERTY()
    float32 Radius = 0.0f;
}
