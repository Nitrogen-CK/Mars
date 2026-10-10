// A whole food as an item: its world item is the food's own FoodPiece (UMars_FoodItem_EntityScript composes Food's joint on
// the world item's entity), so the item carries the joint itself between the floor, the hands and a platter.
UCLASS(Meta = (DisplayName = "🥩 Food"))
class UMars_ItemTrait_Food : UCk_ItemTrait
{
    UPROPERTY()
    UMars_Food_Def Food;
}

mixin bool Has_Food(const FCk_Handle_Item& Self)
{
    return Self.Has_ItemTrait(UMars_ItemTrait_Food);
}

mixin const UMars_ItemTrait_Food Get_Food(const FCk_Handle_Item& Self)
{
    return Self.Get_ItemTrait(UMars_ItemTrait_Food);
}

// The food item in the hands: the selected slot's item when it carries the Food trait and is a Persistent world item's.
// Invalid otherwise. Read from the hotbar, not HeldItem: HeldItem follows the selection a drain later.
mixin FCk_Handle_Item TryGet_SelectedFood(const FCk_Handle_Hotbar& Self)
{
    const auto Item = Self.Get_SelectedItem();
    if (ck::Is_NOT_Valid(Item) || Item.Has_Food() == false || Item.Has_PersistentWorldItem() == false)
    { return FCk_Handle_Item(); }

    return Item;
}
