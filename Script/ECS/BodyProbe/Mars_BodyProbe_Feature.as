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
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_BodyProbe_Params
{
    UPROPERTY()
    TWeakObjectPtr<ACharacter> Character;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_BodyProbe
{
    // The capsule half-height the probe was last sized to.
    UPROPERTY()
    float32 HalfHeight = 0.0f;
}
