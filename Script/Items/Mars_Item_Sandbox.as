// Sandbox items: enough variety to fill the bag, the overflow slot, and exercise use/drop/throw.

asset Mars_ItemDef_Rock of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Rock"));

    mars_items::Add_BlockoutTraits(this, mars_items::Make_BallBlockout(FVector(0.3, 0.3, 0.3)));
}

asset Mars_ItemDef_Ration of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Ration"));

    mars_items::Add_BlockoutTraits(this,
        FMars_ItemBlockout(engine::Cube(), FVector(0.3, 0.3, 0.3), EMars_ItemPresentation_Handedness::TwoHanded));

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_Consume;
    UseAction.HintText = FText::FromString("eat");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Timed;
    UseAction.HoldSeconds = 1.0f;
    UseAction.ConsumeOnSuccess = true;
    _ItemTraits.Add(UseAction);
}

asset Mars_ItemDef_Cog of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Cog"));

    mars_items::Add_BlockoutTraits(this,
        FMars_ItemBlockout(engine::Cylinder(), FVector(0.3, 0.3, 0.3), EMars_ItemPresentation_Handedness::TwoHanded));
}

// One cargo mount per pocket socket on the mesh (Pocket1..3); stowed items sit on the socket itself.
asset Mars_ItemDef_Backpack of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Backpack"));
    _CoreInfo.Set_Icon(assets::Backpack_T());

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::SM_PlayerBackpack();
    // A quarter over the mesh's size (69 x 93 x 97 cm, pivot at its base): 86 x 116 x 121 cm, as tall as the chef's body.
    Presentation.Visual.MeshScale = FVector(1.25, 1.25, 1.25);
    Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -10.0));
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
    // The worn pack's front face on the Back attach point: the face is 35.7 cm ahead of the pivot, times MeshScale.
    Presentation.Mounting.CarryOffset = FTransform(FRotator::ZeroRotator, FVector(-44.6, 0.0, 0.0));
    Presentation.WorldItem.ScriptClass = UMars_Backpack_EntityScript;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
    _ItemTraits.Add(Presentation);

    _ItemTraits.Add(mars_items::Make_PlatterThrowable(this));

    auto Backpack = Cast<UMars_ItemTrait_Backpack>(NewObject(this, UMars_ItemTrait_Backpack));
    auto Mount = FMars_CargoSlot_Mount();
    Mount.ProbeRadius = 10.0f;
    Mount.Socket = TOptional<FName>(n"Pocket1");
    Backpack.CargoSlots.Add(Mount);
    Mount.Socket = TOptional<FName>(n"Pocket2");
    Backpack.CargoSlots.Add(Mount);
    Mount.Socket = TOptional<FName>(n"Pocket3");
    Backpack.CargoSlots.Add(Mount);
    // A lantern hook on the pack's right flank, a little under the top (86 x 116 x 121 cm at MeshScale): a hung lantern
    // hangs beside the pack wherever it goes.
    Backpack.LanternHookOffset = TOptional<FTransform>(FTransform(FRotator::ZeroRotator, FVector(0.0, 62.0, 95.0)));
    _ItemTraits.Add(Backpack);
}

// Melee items. Use swings them (UMars_SmState_ItemUse_Strike); the Strike trait holds the damage knobs. The cleaver
// severs (preserves parts), the tenderizer crushes (ruins soft parts).
asset Mars_ItemDef_Cleaver of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Cleaver"));

    // MeatCleaver_Mars_SM (station_spec.py): pivot at the rear grip, blade along +X, edge down; its Grip_R / Grip_L sockets
    // are the two-handed authored grips the gloves take (Mars_FPHands_Grips.as), Strike / EdgeHeel / EdgeToe mark the edge.
    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::MeatCleaver_Mars_SM();
    Presentation.Grip.Pose = EMars_HandGripPose::Power;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
    // Carried upright at the ready: the handle stands on end (+X up, so the hands stack on it and the edge faces
    // forward), its top leaning a little outward, with the rear grip low and to the right of the view. The left glove
    // (the front grip, the upper hand) is turned so its arm comes across the body from the left; the right glove bends
    // in from the lower right.
    Presentation.Mounting.HeldOffset = utils_fphands::Make_UprightHeldOffset(FVector(-4.0, 22.0, -14.0), 80.0f, -8.0f);
    Presentation.Grip.SocketTwist_L = -60.0f;
    Presentation.Grip.SocketTwist_R = -25.0f;
    _ItemTraits.Add(Presentation);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_Strike;
    UseAction.HintText = FText::FromString("swing");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;
    _ItemTraits.Add(UseAction);

    auto Strike = Cast<UMars_ItemTrait_Strike>(NewObject(this, UMars_ItemTrait_Strike));
    Strike.Damage = 20.0f;
    Strike.DamageType = GameplayTags::DamageType_Mars_Sever;
    Strike.Swing = utils_hand_swing::Make_ChopArc();
    Strike.HitShake = assets::Impact_Light_CameraShake_Mars_BP_Class();
    _ItemTraits.Add(Strike);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Tenderizer of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Tenderizer"));

    // MeatTenderizer_Mars_SM (station_spec.py): pivot at the rear grip, head along +X, teeth down; Grip_R / Grip_L are the
    // two-handed authored grips, Strike the centre of the toothed face.
    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::MeatTenderizer_Mars_SM();
    Presentation.Grip.Pose = EMars_HandGripPose::Power;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
    // Carried upright at the ready like the cleaver, the head up and the teeth forward, the arms turned the same way.
    Presentation.Mounting.HeldOffset = utils_fphands::Make_UprightHeldOffset(FVector(-4.0, 22.0, -14.0), 80.0f, -8.0f);
    Presentation.Grip.SocketTwist_L = -60.0f;
    Presentation.Grip.SocketTwist_R = -25.0f;
    _ItemTraits.Add(Presentation);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_Strike;
    UseAction.HintText = FText::FromString("swing");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;
    _ItemTraits.Add(UseAction);

    auto Strike = Cast<UMars_ItemTrait_Strike>(NewObject(this, UMars_ItemTrait_Strike));
    Strike.Damage = 35.0f;
    Strike.DamageType = GameplayTags::DamageType_Mars_Crush;
    // A heavier tool: a longer rise overhead and a longer settle after the blow.
    Strike.WindupSeconds = 0.3f;
    Strike.RecoverySeconds = 0.45f;
    Strike.Swing = utils_hand_swing::Make_OverheadArc();
    Strike.HitShake = assets::Impact_Light_CameraShake_Mars_BP_Class();
    _ItemTraits.Add(Strike);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

// The foraging tool: blunt, so it cracks husks and knocks the censer.
asset Mars_ItemDef_Pan of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Pan"));

    auto Blockout = FMars_ItemBlockout(engine::Cube(), FVector(0.35, 0.35, 0.04), EMars_ItemPresentation_Handedness::TwoHanded);
    Blockout.Pose = TOptional<EMars_HandGripPose>(EMars_HandGripPose::Power);
    mars_items::Add_BlockoutTraits(this, Blockout);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_Strike;
    UseAction.HintText = FText::FromString("swing");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;
    _ItemTraits.Add(UseAction);

    auto Strike = Cast<UMars_ItemTrait_Strike>(NewObject(this, UMars_ItemTrait_Strike));
    Strike.Damage = 25.0f;
    Strike.DamageType = GameplayTags::DamageType_Mars_Blunt;
    Strike.Swing = utils_hand_swing::Make_SwipeArc();
    Strike.HitShake = assets::Impact_Light_CameraShake_Mars_BP_Class();
    _ItemTraits.Add(Strike);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Rock()       { return Mars_ItemDef_Rock;       }
    UCk_InventoryItem_Definition Ration()     { return Mars_ItemDef_Ration;     }
    UCk_InventoryItem_Definition Cog()        { return Mars_ItemDef_Cog;        }
    UCk_InventoryItem_Definition Backpack()   { return Mars_ItemDef_Backpack;   }
    UCk_InventoryItem_Definition Cleaver()    { return Mars_ItemDef_Cleaver;    }
    UCk_InventoryItem_Definition Tenderizer() { return Mars_ItemDef_Tenderizer; }
    UCk_InventoryItem_Definition Pan()        { return Mars_ItemDef_Pan;        }
}
