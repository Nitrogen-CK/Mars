// What an item looks like when it needs a physical representation - dropped in the world or held in the hand.
UCLASS(Meta = (DisplayName = "🎭 Presentation"))
class UMars_ItemTrait_Presentation : UCk_ItemTrait
{
    // Null = the item renders nothing.
    UPROPERTY()
    TSoftObjectPtr<UStaticMesh> Mesh;

    UPROPERTY()
    FVector MeshScale = FVector::OneVector;

    UPROPERTY()
    TSoftObjectPtr<UMaterialInterface> MaterialOverride;

    // Relative to the player's Hand attach point.
    UPROPERTY()
    FTransform HeldOffset;

    // Finger pose the first-person gloves use while holding this item.
    UPROPERTY()
    EMars_HandGripPose GripPose = EMars_HandGripPose::Cradle;

    // Both gloves hold the item by its sides (the hold centres on screen); otherwise only the right glove grips it,
    // at the Hand attach point.
    UPROPERTY()
    bool IsTwoHanded = true;

    // Two-handed: half the distance between the palms. <= 0 measures the Mesh bounds (x MeshScale, through HeldOffset).
    UPROPERTY()
    float32 GripHalfWidth = 0.0f;

    // The primitive the gloves' fingers close on, fitted to the Mesh bounds (finger contact).
    UPROPERTY()
    EMars_FPHands_GripShape GripShape = EMars_FPHands_GripShape::Auto;

    // World-mode pickup probe radius for an item without a Mesh. An item with one is picked up (and a backpack weighs on
    // plates) through a box fitted to the Mesh bounds.
    UPROPERTY()
    float32 PickupProbeRadius = 40.0f;

    // Null = the base WorldItem entity script. Set it only for an item family that needs behaviour of its own.
    UPROPERTY()
    TSubclassOf<UMars_WorldItem_EntityScript> WorldItemScriptClass;

    UPROPERTY()
    EMars_WorldItem_Persistence Persistence = EMars_WorldItem_Persistence::Transient;

    // Persistent only: the carrier's attach point the item mounts to while carried and not held (AttachPoint.Mars.Back).
    UPROPERTY()
    FGameplayTag CarryPoint;

    UPROPERTY()
    FTransform CarryOffset;

    // Relative to a cargo slot node while stowed in a backpack.
    UPROPERTY()
    FTransform CargoOffset;

    // Seconds a mount transition / stow / take lerps. 0 = snap.
    UPROPERTY()
    float32 ArriveSeconds = 0.25f;
}

mixin bool Has_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Presentation);
}

mixin const UMars_ItemTrait_Presentation Get_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Presentation);
}
