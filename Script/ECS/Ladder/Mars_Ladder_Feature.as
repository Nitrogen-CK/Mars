//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_LadderHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Ladder";
    RequiredFragments.Add(FMars_Feature_Ladder);
    Description = "A climbable ladder: its climb line and the two trigger zones that offer it to climbers";
}
struct FMars_Feature_Ladder {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Ladder frame: the origin is the foot on the floor; local +X points OUT of the ladder toward the climber; the rungs span
// local Y; the climb line is (Standoff, 0, z) for z in [0, Height]. Field order is the positional constructor's order (the
// spawn-params generator emits it when a subclass changes a default).
struct FMars_Ladder_Spec
{
    // Foot (origin) to the top rung / the surface of the platform the ladder serves.
    UPROPERTY()
    float32 Height = 300.0f;

    // Rung span (local Y).
    UPROPERTY()
    float32 Width = 60.0f;

    // Capsule centre distance in front of the plane (local +X).
    UPROPERTY()
    float32 Standoff = 45.0f;

    // FrontZone depth in front of the plane.
    UPROPERTY()
    float32 MountDepth = 90.0f;

    // Top exit distance BEHIND the plane (onto the platform).
    UPROPERTY()
    float32 TopExitDepth = 70.0f;

    // Both zones extend this far above their edge (a capsule's worth).
    UPROPERTY()
    float32 ZoneHeightPadding = 100.0f;

    FMars_Ladder_Spec() {}

    FMars_Ladder_Spec(
        float32 InHeight,
        float32 InWidth,
        float32 InStandoff,
        float32 InMountDepth,
        float32 InTopExitDepth,
        float32 InZoneHeightPadding)
    {
        Height = InHeight;
        Width = InWidth;
        Standoff = InStandoff;
        MountDepth = InMountDepth;
        TopExitDepth = InTopExitDepth;
        ZoneHeightPadding = InZoneHeightPadding;
    }
}

// Every length must be positive: a zero height has no line to climb, a zero standoff puts the capsule in the rungs, and
// zero-depth zones or exit detect nothing / drop the climber on the edge. The climb speed is the climber's (FMars_Climber_Spec).
mixin FMars_Validation Validate(const FMars_Ladder_Spec& Self)
{
    if (Self.Height <= 0.0f)
    { return FMars_Validation(f"Ladder has a non-positive Height [{Self.Height}]"); }

    if (Self.Width <= 0.0f)
    { return FMars_Validation(f"Ladder has a non-positive Width [{Self.Width}]"); }

    if (Self.Standoff <= 0.0f)
    { return FMars_Validation(f"Ladder has a non-positive Standoff [{Self.Standoff}]"); }

    if (Self.MountDepth <= 0.0f)
    { return FMars_Validation(f"Ladder has a non-positive MountDepth [{Self.MountDepth}]"); }

    if (Self.TopExitDepth <= 0.0f)
    { return FMars_Validation(f"Ladder has a non-positive TopExitDepth [{Self.TopExitDepth}]"); }

    return FMars_Validation();
}

// Front: in front of the plane over the whole height (mounts at the foot or mid-height). Top: behind the plane at the top,
// on the platform the ladder serves (mounts at the top).
enum EMars_Ladder_Zone
{
    Front,
    Top
}

struct FMars_Tag_Ladder_NeedsSetup {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Ladder_Params
{
    UPROPERTY()
    float32 Height = 300.0f;

    UPROPERTY()
    float32 Width = 60.0f;

    UPROPERTY()
    float32 Standoff = 45.0f;

    UPROPERTY()
    float32 MountDepth = 90.0f;

    UPROPERTY()
    float32 TopExitDepth = 70.0f;

    UPROPERTY()
    float32 ZoneHeightPadding = 100.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Ladder
{
    UPROPERTY()
    FCk_Handle_Trigger FrontZone;

    UPROPERTY()
    FCk_Handle_Trigger TopZone;
}

// Lives on each zone's trigger entity: trigger signals carry only the trigger, so this is how they find their ladder.
struct FMars_Fragment_Ladder_TriggerLink
{
    UPROPERTY()
    FCk_Handle_Ladder Ladder;

    UPROPERTY()
    EMars_Ladder_Zone Zone = EMars_Ladder_Zone::Front;
}
