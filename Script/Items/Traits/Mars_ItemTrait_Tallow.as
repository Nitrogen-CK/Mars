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

mixin const UMars_ItemTrait_Tallow Get_Tallow(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Tallow);
}
