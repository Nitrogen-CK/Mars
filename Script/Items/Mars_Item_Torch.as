// The torch: a bare pitch flame on a stick. Persistent (one body carries the flame between the floor, the hand and the
// belt), its world item UMars_Torch_EntityScript. It strikes itself alight, burns a few long measures and is then spent for
// good, and stowing it snuffs it.

namespace constants_torch_item
{
    // A 3 cm shaft, 55 cm long (the blockout stands in for a Torch_Mars_SM). The engine cylinder pivots at its centre, so
    // heights over the pivot run from -27.5 at the butt to 27.5 at the head.
    const FVector k_ShaftScale = FVector(0.03, 0.03, 0.55);
    // The flame node over the pivot: the shaft's top.
    const float64 k_HeadHeight = 27.5;
    // The hand closes on the shaft at the top of its lower third; holding it from the hand or the belt lifts it by this.
    const float64 k_GripHeight = -8.25;
}

asset Mars_ItemDef_Torch of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Torch"));

    auto Blockout = FMars_ItemBlockout(engine::Cylinder(), constants_torch_item::k_ShaftScale, EMars_ItemPresentation_Handedness::OneHanded);
    Blockout.Pose = TOptional<EMars_HandGripPose>(EMars_HandGripPose::Power);
    Blockout.Color = TOptional<FLinearColor>(FLinearColor(0.25f, 0.17f, 0.10f, 1.0f));
    auto Presentation = mars_items::Add_BlockoutTraits(this, Blockout);
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    // In the hand the shaft follows the fist (the grip frame's X), its grip point at the grip bone; on the belt it hangs
    // straight.
    Presentation.Mounting.HeldOffset = utils_fphands::Make_ShaftHeldOffset(constants_torch_item::k_GripHeight);
    Presentation.Mounting.CarryOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -constants_torch_item::k_GripHeight));
    Presentation.WorldItem.ScriptClass = UMars_Torch_EntityScript;

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_ToggleFlame;
    UseAction.HintText = FText::FromString("light");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;
    _ItemTraits.Add(UseAction);

    auto Fuel = FMars_Flame_Fuel();
    Fuel.Measures = 3;
    Fuel.SecondsPerMeasure = 90.0f;
    Fuel.GutterSeconds = 10.0f;
    Fuel.Refuel = EMars_Flame_Refuel::NotRefuelable;

    auto Flame = Cast<UMars_ItemTrait_Flame>(NewObject(this, UMars_ItemTrait_Flame));
    Flame.Spec.Fuel = TOptional<FMars_Flame_Fuel>(Fuel);
    Flame.Spec.StartIgnition = EMars_Flame_Ignition::Snuffed;
    Flame.Spec.Enclosure = EMars_Flame_Enclosure::Open;
    Flame.Spec.Lighting = EMars_Flame_Lighting::SelfLighting;
    Flame.Spec.OnStow = EMars_Flame_OnStow::Snuffs;
    // Every Mars flame lights the same 800 pool, wherever it is.
    Flame.Spec.Radius.Held = 800.0f;
    Flame.Spec.Radius.World = 800.0f;
    _ItemTraits.Add(Flame);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Torch() { return Mars_ItemDef_Torch; }
}
