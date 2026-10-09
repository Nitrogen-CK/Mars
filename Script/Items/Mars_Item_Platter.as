// The prep tray as an item: PrepTray_Mars_SM (26 x 30 x 8, pivot at the centre of its inner floor), carried in both hands
// (HandsOnly: the overflow slot), Persistent so the pieces on it ride the one entity between the hand, a dock and the
// floor. Eight slots in a 2 x 4 grid on the floor; pieces have no bodies on a platter and may overlap.
asset Mars_ItemDef_Platter of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Platter"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::PrepTray_Mars_SM();
    Presentation.Grip.Pose = EMars_HandGripPose::Cradle;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
    // Held out in front at waist height, level: the tray's floor faces up and its long side (Y) runs across the view.
    Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator, FVector(12.0, 0.0, -14.0));
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    // A HandsOnly item is never carried anywhere but the hands: its carry point IS the hand.
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Hand;
    Presentation.Mounting.CarryOffset = Presentation.Mounting.HeldOffset;
    Presentation.WorldItem.ScriptClass = UMars_Platter_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    Throwable.ThrowSpeed = 300.0f;
    Throwable.DropSpeed = 80.0f;
    Throwable.AngularVelocityDeg = FVector::ZeroVector;
    _ItemTraits.Add(Throwable);

    _ItemTraits.Add(Cast<UMars_ItemTrait_HandsOnly>(NewObject(this, UMars_ItemTrait_HandsOnly)));

    auto Platter = Cast<UMars_ItemTrait_Platter>(NewObject(this, UMars_ItemTrait_Platter));
    for (int32 Row = 0; Row < 2; ++Row)
    {
        for (int32 Column = 0; Column < 4; ++Column)
        {
            Platter.Platter.SlotsLocal.Add(FTransform(FRotator::ZeroRotator,
                FVector(-5.5 + 11.0 * float64(Row), -9.75 + 6.5 * float64(Column), 0.0)));
        }
    }

    _ItemTraits.Add(Platter);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Platter() { return Mars_ItemDef_Platter; }
}

namespace constants_platter
{
    // PrepTray_Mars_SM's pivot (the centre of its inner floor) sits this far above its underside: a station's dock lifts
    // the platter's root by it so the tray rests on the surface instead of sinking into it.
    const float64 k_FloorAboveBase = 1.5;
}
