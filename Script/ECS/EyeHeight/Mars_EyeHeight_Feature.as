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

    // The character whose capsule the eye follows; set at composition (a config asset leaves it empty).
    UPROPERTY()
    TWeakObjectPtr<ACharacter> Character;
}

mixin FMars_Validation Validate(const FMars_EyeHeight_Spec& Self)
{
    // A NaN passes every comparison below, so finiteness is checked first.
    if (Math::IsFinite(Self.Height) == false)
    { return FMars_Validation(f"Height [{Self.Height}] is not finite"); }

    if (Math::IsFinite(Self.BlendRate) == false)
    { return FMars_Validation(f"BlendRate [{Self.BlendRate}] is not finite"); }

    if (Self.BlendRate <= 0.0f)
    { return FMars_Validation(f"BlendRate [{Self.BlendRate}] must be > 0"); }

    if (ck::Is_NOT_Valid(Self.Character.Get()))
    { return FMars_Validation("Character is not set"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_EyeHeight_Params
{
    UPROPERTY()
    FMars_EyeHeight_Spec Spec;
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
