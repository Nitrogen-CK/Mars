struct FMars_CargoSlot_Mount
{
    // Unset: Offset is relative to the pack root. Set: Offset is applied on top of the socket's transform (socket location
    // scaled by Presentation.Visual.MeshScale, since the pack root is unit scale and the visual node carries the scale).
    UPROPERTY()
    TOptional<FName> Socket;

    UPROPERTY()
    FTransform Offset;

    UPROPERTY()
    float32 ProbeRadius = 12.0f;
}

// A wearable pack: fits only the hotbar's backpack slot, and carries one cargo slot per mount and optionally a lantern
// hook.
UCLASS(Meta = (DisplayName = "🎒 Backpack"))
class UMars_ItemTrait_Backpack : UCk_ItemTrait
{
    // 1..8 (Inventory.Mars.Cargo.0..7).
    UPROPERTY()
    TArray<FMars_CargoSlot_Mount> CargoSlots;

    // Where the pack's lantern hook sits, relative to the pack root (unit scale; the visual node carries the display
    // scale): a hung lantern's bail hangs here. Unset: the pack has no hook.
    UPROPERTY()
    TOptional<FTransform> LanternHookOffset;
}

mixin bool Has_Backpack(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Backpack);
}

mixin const UMars_ItemTrait_Backpack Get_Backpack(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Backpack);
}
