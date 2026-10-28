// Deterministically holds the real definition-selected spawn path in Continue, before any WorldItem/body/item exists.
// This tests cancellation of an owned pending child without relying on a lucky one-frame observation window.
class UMars_Test_PlacedPickupPending_EntityScript : UMars_WorldItem_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        utils_entity_tag::Add(InHandle, n"TAG_MarsPlacedPickupPendingFixture");
        return ECk_EntityScript_ConstructionFlow::Continue;
    }
}

asset Mars_TestItemDef_PlacedPickupPending of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("PlacedPickup pending lifecycle fixture"));
    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.WorldItem.ScriptClass = UMars_Test_PlacedPickupPending_EntityScript;
    _ItemTraits.Add(Presentation);
}

namespace utils_placed_pickup_test
{
    UCk_InventoryItem_Definition Get_PendingDefinition()
    { return Mars_TestItemDef_PlacedPickupPending; }
}
