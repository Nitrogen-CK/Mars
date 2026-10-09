// A tray that carries food pieces: the Platter kernel's spec the item's entity script composes.
UCLASS(Meta = (DisplayName = "🍽️ Platter"))
class UMars_ItemTrait_Platter : UCk_ItemTrait
{
    UPROPERTY()
    FMars_Platter_Spec Platter;
}

mixin bool Has_Platter(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Platter);
}

mixin const UMars_ItemTrait_Platter Get_Platter(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Platter);
}
