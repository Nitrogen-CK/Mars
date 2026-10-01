//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_EyeHeightHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_EyeHeight";
    RequiredFragments.Add(FMars_Feature_EyeHeight);
    Description = "A character's eye node: rides at a fixed height above the capsule centre and eases across capsule resizes (crouch, uncrouch) instead of snapping";
}

struct FMars_Feature_EyeHeight {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_EyeHeight_Spec
{
    // Above the capsule centre.
    UPROPERTY()
    float32 Height = 64.0f;

    // Exponential rate (1/s) at which the eye eases back to Height after the capsule resizes. 12 settles ~95% in 0.25 s.
    UPROPERTY()
    float32 BlendRate = 12.0f;
}

mixin FMars_Validation Validate(const FMars_EyeHeight_Spec& Self)
{
    if (Self.BlendRate <= 0.0f)
    { return FMars_Validation(f"non-positive BlendRate [{Self.BlendRate}]"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_EyeHeight_Params
{
    UPROPERTY()
    float32 Height = 64.0f;

    UPROPERTY()
    float32 BlendRate = 12.0f;

    UPROPERTY()
    TWeakObjectPtr<ACharacter> Character;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_EyeHeight
{
    // The capsule half-height seen last frame; a change is a crouch or uncrouch.
    UPROPERTY()
    float32 LastHalfHeight = 0.0f;

    // Cm the eye still sits above (or below) Height, so a resize that moves the capsule centre does not move the view.
    UPROPERTY()
    float32 Offset = 0.0f;
}
