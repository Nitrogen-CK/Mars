// Lantern fuel: using it refuels the emptiest lantern its user carries by Measures (UMars_SmState_ItemUse_Refuel).
UCLASS(Meta = (DisplayName = "🕯️ Tallow"))
class UMars_ItemTrait_Tallow : UCk_ItemTrait
{
    UPROPERTY()
    int32 Measures = 2;
}

mixin bool Has_Tallow(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Tallow);
}

// 0 for an item that is no tallow.
mixin int32 Get_TallowMeasures(const FCk_Handle_Item& Self)
{
    if (Self.Has_Tallow() == false)
    { return 0; }

    const UMars_ItemTrait_Tallow Tallow = Self.Get_ItemTrait(UMars_ItemTrait_Tallow);
    return Tallow.Measures;
}
