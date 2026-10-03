struct FMars_CargoSlot_Mount
{
    // NAME_None = Offset is relative to the pack root. Otherwise Offset is applied on top of the socket's transform
    // (socket location scaled by Presentation.MeshScale, since the pack root is unit scale and the visual node carries the scale).
    UPROPERTY()
    FName Socket;

    UPROPERTY()
    FTransform Offset;

    UPROPERTY()
    float32 ProbeRadius = 12.0f;
}

// A wearable pack: fits only the hotbar's backpack slot, and carries one cargo slot per mount.
UCLASS(Meta = (DisplayName = "🎒 Backpack"))
class UMars_ItemTrait_Backpack : UCk_ItemTrait
{
    // 1..8 (Inventory.Mars.Cargo.0..7).
    UPROPERTY()
    TArray<FMars_CargoSlot_Mount> CargoSlots;
}

mixin bool Has_Backpack(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Backpack);
}

mixin const UMars_ItemTrait_Backpack Get_Backpack(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Backpack);
}
