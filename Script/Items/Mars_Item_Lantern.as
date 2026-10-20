// The lantern and its fuel. The lantern is Persistent (its one body carries the flame between the floor, the hand and the
// belt) and its world item is UMars_Lantern_EntityScript, which composes the Lantern kernel and draws the light. Tallow
// is a plain one-handed consumable: using it refuels a carried lantern.

namespace constants_lantern_item
{
    // CampLantern_Mars_SM is 26 x 26 x 58.3 cm with its pivot at its base; at this scale 14.3 x 14.3 x 32 cm.
    const float64 k_MeshScale = 0.55;
    // The bail's top over the pivot at k_MeshScale: hanging the lantern from a hand or a belt drops it by this much.
    const float64 k_BailHeight = 32.0;
}

asset Mars_ItemDef_Lantern of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Lantern"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::CampLantern_Mars_SM();
    Presentation.Visual.MeshScale = FVector(constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale);
    Presentation.Grip.Pose = EMars_HandGripPose::Power;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    // Hung by its bail from the hand and from the belt.
    Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
    Presentation.Mounting.CarryOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_lantern_item::k_BailHeight));
    Presentation.WorldItem.ScriptClass = UMars_Lantern_EntityScript;
    _ItemTraits.Add(Presentation);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_ToggleShutter;
    UseAction.HintText = FText::FromString("shutter");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;
    _ItemTraits.Add(UseAction);

    auto Lantern = Cast<UMars_ItemTrait_Lantern>(NewObject(this, UMars_ItemTrait_Lantern));
    _ItemTraits.Add(Lantern);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

// A cake of rendered tallow (a cream proxy cylinder).
asset Mars_ItemDef_Tallow of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Tallow"));

    auto Blockout = FMars_ItemBlockout(engine::Cylinder(), FVector(0.09, 0.09, 0.07), EMars_ItemPresentation_Handedness::OneHanded);
    Blockout.Pose = TOptional<EMars_HandGripPose>(EMars_HandGripPose::Power);
    Blockout.Color = TOptional<FLinearColor>(FLinearColor(0.93f, 0.86f, 0.66f, 1.0f));
    mars_items::Add_BlockoutTraits(this, Blockout);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_Refuel;
    UseAction.HintText = FText::FromString("refuel lantern");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Timed;
    UseAction.HoldSeconds = 0.6f;
    _ItemTraits.Add(UseAction);

    auto Tallow = Cast<UMars_ItemTrait_Tallow>(NewObject(this, UMars_ItemTrait_Tallow));
    _ItemTraits.Add(Tallow);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Lantern() { return Mars_ItemDef_Lantern; }
    UCk_InventoryItem_Definition Tallow()  { return Mars_ItemDef_Tallow;  }
}
