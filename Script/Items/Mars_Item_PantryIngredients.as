// Pantry-rat ingredients. The Monk's Rind wedge is the lure that arms a grounded backpack's scent (PantryRaid): Transient,
// a blockout presentation on the rat candidate's cheese mesh (15 x 10 x 8 cm, pivot at its base centre) wearing its own
// Rind / Flesh materials (no ProtoGrid override), and no Food or cooking traits.

asset Mars_ItemDef_MonksRind of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Monk's Rind"));

    auto Blockout = FMars_ItemBlockout(TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(
        "/Game/ArtCandidates/PantryRat/R02/Props/PantryRat_R02_Cheese_Mars_SM.PantryRat_R02_Cheese_Mars_SM")),
        FVector::OneVector, EMars_ItemPresentation_Handedness::TwoHanded);
    auto Presentation = mars_items::Add_BlockoutTraits(this, Blockout);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>();

    _ItemTraits.Add(Cast<UMars_ItemTrait_StinkyCheese>(NewObject(this, UMars_ItemTrait_StinkyCheese)));
}

namespace mars_items
{
    UCk_InventoryItem_Definition MonksRind() { return Mars_ItemDef_MonksRind; }
}
