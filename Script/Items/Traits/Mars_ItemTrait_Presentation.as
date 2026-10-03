// Whether one glove or both hold the item.
enum EMars_ItemPresentation_Handedness
{
    // Only the right glove grips it, at the Hand attach point.
    OneHanded,
    // Both gloves hold it by its sides; the hold centres on screen.
    TwoHanded
}

struct FMars_ItemPresentation_Visual
{
    // Null = the item renders nothing.
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    UPROPERTY()
    FVector MeshScale = FVector::OneVector;

    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> MaterialOverride;
}

// How the first-person gloves hold the item.
struct FMars_ItemPresentation_Grip
{
    // Finger pose the gloves use while holding this item.
    UPROPERTY()
    EMars_HandGripPose Pose = EMars_HandGripPose::Cradle;

    UPROPERTY()
    EMars_ItemPresentation_Handedness Handedness = EMars_ItemPresentation_Handedness::TwoHanded;

    // Two-handed: half the distance between the palms. Unset measures the Mesh bounds (x MeshScale, through
    // Mounting.HeldOffset).
    UPROPERTY()
    TOptional<float32> HalfWidth;

    // The primitive the gloves' fingers close on, fitted to the Mesh bounds (finger contact).
    UPROPERTY()
    EMars_FPHands_GripShape Shape = EMars_FPHands_GripShape::Auto;
}

// Where the item sits on whatever holds it, and how it gets there.
struct FMars_ItemPresentation_Mounting
{
    UPROPERTY()
    EMars_WorldItem_Persistence Persistence = EMars_WorldItem_Persistence::Transient;

    // Persistent only: the carrier's attach point the item mounts to while carried and not held (AttachPoint.Mars.Back).
    UPROPERTY()
    FGameplayTag CarryPoint;

    UPROPERTY()
    FTransform CarryOffset;

    // Relative to the player's Hand attach point.
    UPROPERTY()
    FTransform HeldOffset;

    // Relative to a cargo slot node while stowed in a backpack.
    UPROPERTY()
    FTransform CargoOffset;

    // Seconds a mount transition / stow / take lerps. 0 snaps.
    UPROPERTY()
    float32 ArriveSeconds = 0.25f;
}

// The item lying in the world (a World-mode world item).
struct FMars_ItemPresentation_WorldItem
{
    // Pickup probe radius for an item without a Mesh. An item with one is picked up (and a backpack weighs on plates)
    // through a box fitted to the Mesh bounds.
    UPROPERTY()
    float32 PickupProbeRadius = 40.0f;

    // Null = the base WorldItem entity script. Set it only for an item family that needs behaviour of its own.
    UPROPERTY()
    TSubclassOf<UMars_WorldItem_EntityScript> ScriptClass;
}

// What an item looks like when it needs a physical representation - dropped in the world or held in the hand.
UCLASS(Meta = (DisplayName = "🎭 Presentation"))
class UMars_ItemTrait_Presentation : UCk_ItemTrait
{
    UPROPERTY()
    FMars_ItemPresentation_Visual Visual;

    UPROPERTY()
    FMars_ItemPresentation_Grip Grip;

    UPROPERTY()
    FMars_ItemPresentation_Mounting Mounting;

    UPROPERTY()
    FMars_ItemPresentation_WorldItem WorldItem;
}

mixin bool Has_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Presentation);
}

mixin const UMars_ItemTrait_Presentation Get_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Presentation);
}
