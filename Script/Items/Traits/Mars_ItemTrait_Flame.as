// A flame item: its world item composes the Flame feature from Spec (UMars_FlameItem_EntityScript and its subclasses), so
// the item must be Persistent - one body carries the flame from the floor to the hand to the belt.
UCLASS(Meta = (DisplayName = "🔥 Flame"))
class UMars_ItemTrait_Flame : UCk_ItemTrait
{
    UPROPERTY()
    FMars_Flame_Spec Spec;
}

mixin bool Has_FlameTrait(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Flame);
}

mixin const UMars_ItemTrait_Flame Get_FlameTrait(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Flame);
}
