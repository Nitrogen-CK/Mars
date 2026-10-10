// Whole foods as items: the world item is the food's own joint (UMars_FoodItem_EntityScript, the Food trait), so there is no
// Presentation mesh: the joint wears its own display. Stowed like any item (a bag slot, a backpack's cargo slot) and held
// in both hands when its slot is selected, Persistent so the one joint moves between the floor, the hands, the back, a
// pack and a platter, and thrown like a platter.
asset Mars_ItemDef_Food_MeatSlab of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Meat slab"));

    // The slab's long axis (its mesh +X) across the view, held level a little below and in front of the hands.
    _ItemTraits.Add(mars_items::Make_FoodPresentation(this, FTransform(FRotator(0.0, 90.0, 0.0), FVector(14.0, 0.0, -12.0)), 18.0f));
    _ItemTraits.Add(mars_items::Make_PlatterThrowable(this));

    auto Food = Cast<UMars_ItemTrait_Food>(NewObject(this, UMars_ItemTrait_Food));
    Food.Food = mars::Food_MeatSlab_Mars;
    _ItemTraits.Add(Food);
}

asset Mars_ItemDef_Food_MushroomSlice of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Mushroom slice"));

    // The slice's long axis (its mesh +Y) already runs across the view.
    _ItemTraits.Add(mars_items::Make_FoodPresentation(this, FTransform(FRotator::ZeroRotator, FVector(14.0, 0.0, -12.0)), 6.0f));
    _ItemTraits.Add(mars_items::Make_PlatterThrowable(this));

    auto Food = Cast<UMars_ItemTrait_Food>(NewObject(this, UMars_ItemTrait_Food));
    Food.Food = mars::Food_MushroomSlice_Mars;
    _ItemTraits.Add(Food);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Food_MeatSlab() { return Mars_ItemDef_Food_MeatSlab; }

    UCk_InventoryItem_Definition Food_MushroomSlice() { return Mars_ItemDef_Food_MushroomSlice; }

    // A meshless, two-handed cradle at InHeldOffset whose palms sit InHalfWidth either side of the hold (no mesh to measure).
    // Stowed and not selected, the food rides the carrier's back, behind and below the Back point so it clears a worn pack;
    // in a pack it sits on the cargo slot's node.
    UMars_ItemTrait_Presentation Make_FoodPresentation(UObject InOuter, FTransform InHeldOffset, float32 InHalfWidth)
    {
        auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(InOuter, UMars_ItemTrait_Presentation));
        Presentation.Grip.Pose = EMars_HandGripPose::Cradle;
        Presentation.Grip.Layout = EMars_HandGripLayout::Cradle;
        Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
        Presentation.Grip.HalfWidth = TOptional<float32>(InHalfWidth);
        Presentation.Mounting.HeldOffset = InHeldOffset;
        Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
        Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
        Presentation.Mounting.CarryOffset = FTransform(FRotator::ZeroRotator, FVector(-35.0, 0.0, -25.0));
        Presentation.Mounting.CargoOffset = FTransform::Identity;
        Presentation.WorldItem.ScriptClass = UMars_FoodItem_EntityScript;
        return Presentation;
    }
}
