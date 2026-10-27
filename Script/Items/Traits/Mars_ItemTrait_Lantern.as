// Marks a lantern: it hangs by its bail, so a lantern hook accepts it (utils_lantern_hook::Get_IsLantern). Its flame is
// the item's UMars_ItemTrait_Flame.
UCLASS(Meta = (DisplayName = "🏮 Lantern"))
class UMars_ItemTrait_Lantern : UCk_ItemTrait
{
}

mixin bool Has_LanternTrait(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Lantern);
}
