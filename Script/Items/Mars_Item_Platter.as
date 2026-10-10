// The prep tray as an item: PrepTray_Mars_SM (26 x 30 x 8 outer; pivot at the centre of its inner floor, which is 20.7 x 24.7:
// rope, posts and 1.6 cm planks take the rest), carried in both hands (HandsOnly: the overflow slot), Persistent so the pile
// on it rides the one entity between the hand, a dock and the floor. Pieces dropped on it settle between the kernel's
// invisible walls and freeze into a pile. The walls stand centred on Bounds' edges, 0.2 cm clear of the tray's own planks:
// Bounds.InnerHalfExtents = the inner floor's half x MeshScale - half a wall - 0.2.
asset Mars_ItemDef_Platter of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Platter"));

    _ItemTraits.Add(mars_items::Make_PlatterPresentation(this, FVector::OneVector, FVector(12.0, 0.0, -14.0)));
    _ItemTraits.Add(mars_items::Make_PlatterThrowable(this));
    _ItemTraits.Add(Cast<UMars_ItemTrait_HandsOnly>(NewObject(this, UMars_ItemTrait_HandsOnly)));

    auto Platter = Cast<UMars_ItemTrait_Platter>(NewObject(this, UMars_ItemTrait_Platter));
    Platter.Platter = FMars_Platter_Spec(4, FMars_Platter_Bounds(FVector2D(9.15, 11.15), 40.0f, 25.0f));
    _ItemTraits.Add(Platter);
}

// The same tray at 1.8 times its width and depth (the world item's body scales with it): inner floor 37.3 x 44.5, wide
// enough for the whole meat slab along its long side.
asset Mars_ItemDef_Platter_Large of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Large platter"));

    // Held further out and lower than the small tray, so its 54 cm width is not in the face.
    _ItemTraits.Add(mars_items::Make_PlatterPresentation(this, FVector(1.8, 1.8, 1.0), FVector(24.0, 0.0, -18.0)));
    _ItemTraits.Add(mars_items::Make_PlatterThrowable(this));
    _ItemTraits.Add(Cast<UMars_ItemTrait_HandsOnly>(NewObject(this, UMars_ItemTrait_HandsOnly)));

    auto Platter = Cast<UMars_ItemTrait_Platter>(NewObject(this, UMars_ItemTrait_Platter));
    Platter.Platter = FMars_Platter_Spec(12, FMars_Platter_Bounds(FVector2D(17.43, 21.03), 40.0f, 25.0f));
    _ItemTraits.Add(Platter);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Platter() { return Mars_ItemDef_Platter; }

    UCk_InventoryItem_Definition Platter_Large() { return Mars_ItemDef_Platter_Large; }

    // The tray held out in front at waist height (InHeldLocation under the hand node), level: its floor faces up and its long
    // side (Y) runs across the view. A HandsOnly item is never carried anywhere but the hands: its carry point IS the hand.
    UMars_ItemTrait_Presentation Make_PlatterPresentation(UObject InOuter, FVector InMeshScale, FVector InHeldLocation)
    {
        auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(InOuter, UMars_ItemTrait_Presentation));
        Presentation.Visual.Mesh = assets::PrepTray_Mars_SM();
        Presentation.Visual.MeshScale = InMeshScale;
        Presentation.Grip.Pose = EMars_HandGripPose::Cradle;
        Presentation.Grip.Layout = EMars_HandGripLayout::Cradle;
        Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
        Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator, InHeldLocation);
        Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
        Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Hand;
        Presentation.Mounting.CarryOffset = Presentation.Mounting.HeldOffset;
        Presentation.WorldItem.ScriptClass = UMars_Platter_EntityScript;
        return Presentation;
    }

    UMars_ItemTrait_Throwable Make_PlatterThrowable(UObject InOuter)
    {
        auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(InOuter, UMars_ItemTrait_Throwable));
        Throwable.ThrowSpeed = 500.0f;
        Throwable.DropSpeed = 100.0f;
        Throwable.AngularVelocityDeg = FVector::ZeroVector;
        return Throwable;
    }
}

namespace constants_platter
{
    // PrepTray_Mars_SM's pivot (the centre of its inner floor) sits this far above its underside: a station's dock lifts
    // the platter's root by it so the tray rests on the surface instead of sinking into it.
    const float64 k_FloorAboveBase = 1.5;
}
