// A lantern: its world item composes the Lantern feature from Spec (UMars_Lantern_EntityScript), so the item must be
// Persistent - one body carries the flame from the floor to the hand to the belt.
UCLASS(Meta = (DisplayName = "🏮 Lantern"))
class UMars_ItemTrait_Lantern : UCk_ItemTrait
{
    UPROPERTY()
    FMars_Lantern_Spec Spec;
}

mixin bool Has_LanternTrait(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Lantern);
}
