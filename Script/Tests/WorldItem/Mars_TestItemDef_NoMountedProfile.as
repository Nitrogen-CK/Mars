// Immutable test input: body-bearing World items cannot consume an empty mounted profile.
asset Mars_TestItemDef_NoMountedProfile of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Missing mounted profile fixture"));
    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.MountedBodyProfile = NAME_None;
    _ItemTraits.Add(Presentation);
}

namespace mars_test_world_item
{
    UCk_InventoryItem_Definition NoMountedProfile() { return Mars_TestItemDef_NoMountedProfile; }
}
