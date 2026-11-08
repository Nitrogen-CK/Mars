// The pantry rats' lure: a grounded backpack holding an item with this trait draws rats from their dens (PantryRaid). The
// cheese is itself an ingredient a rat may steal.
UCLASS(Meta = (DisplayName = "🧀 Stinky cheese"))
class UMars_ItemTrait_StinkyCheese : UCk_ItemTrait
{
}

mixin bool Has_StinkyCheese(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_StinkyCheese);
}
