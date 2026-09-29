// What an item looks like when it needs a physical representation - dropped in the world or held in the hand.
UCLASS()
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

    // World-mode pickup probe radius.
    UPROPERTY()
    float32 PickupProbeRadius = 40.0f;

    // Null = the base WorldItem entity script. Set it only for an item family that needs behaviour of its own.
    UPROPERTY()
    TSubclassOf<UMars_WorldItem_EntityScript> WorldItemScriptClass;
}

mixin bool Has_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Presentation);
}

mixin const UMars_ItemTrait_Presentation Get_Presentation(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Presentation);
}
