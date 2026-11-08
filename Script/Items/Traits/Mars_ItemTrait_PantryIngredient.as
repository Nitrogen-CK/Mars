// An ordinary forage ingredient that is not a Food: a pantry rat may steal it out of a grounded backpack, as it steals any
// Food (utils_pantry_raid::Get_IsStealable).
UCLASS(Meta = (DisplayName = "🌰 Pantry ingredient"))
class UMars_ItemTrait_PantryIngredient : UCk_ItemTrait
{
}

mixin bool Has_PantryIngredient(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_PantryIngredient);
}

namespace mars_items
{
    // Marks InDefinition as an ingredient a pantry rat may steal.
    void Add_PantryIngredientTrait(UCk_InventoryItem_Definition InDefinition)
    {
        InDefinition._ItemTraits.Add(Cast<UMars_ItemTrait_PantryIngredient>(NewObject(InDefinition, UMars_ItemTrait_PantryIngredient)));
    }
}
