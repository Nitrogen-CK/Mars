// Sandbox items: enough variety to fill the bag, the overflow slot, and exercise use/drop/throw.

asset Mars_ItemDef_Rock of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Rock"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.3, 0.3, 0.3);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Sphere;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Ration of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Ration"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cube();
    Presentation.Visual.MeshScale = FVector(0.3, 0.3, 0.3);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_Consume;
    UseAction.HintText = FText::FromString("eat");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Timed;
    UseAction.HoldSeconds = 1.0f;
    UseAction.ConsumeOnSuccess = true;
    _ItemTraits.Add(UseAction);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Cog of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Cog"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cylinder();
    Presentation.Visual.MeshScale = FVector(0.3, 0.3, 0.3);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

// One cargo mount per pocket socket on the mesh (Pocket1..3); stowed items sit on the socket itself.
asset Mars_ItemDef_Backpack of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Backpack"));
    _CoreInfo.Set_Icon(assets::Backpack_T());

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::SM_PlayerBackpack();
    Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -10.0));
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
    // Pushed back off the Back attach point so the worn pack stays out of the camera when looking down.
    Presentation.Mounting.CarryOffset = FTransform(FRotator::ZeroRotator, FVector(-20.0, 0.0, 0.0));
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    Throwable.ThrowSpeed = 500.0f;
    Throwable.DropSpeed = 100.0f;
    Throwable.AngularVelocityDeg = FVector::ZeroVector;
    _ItemTraits.Add(Throwable);

    auto Backpack = Cast<UMars_ItemTrait_Backpack>(NewObject(this, UMars_ItemTrait_Backpack));
    auto Mount = FMars_CargoSlot_Mount();
    Mount.ProbeRadius = 10.0f;
    Mount.Socket = TOptional<FName>(n"Pocket1");
    Backpack.CargoSlots.Add(Mount);
    Mount.Socket = TOptional<FName>(n"Pocket2");
    Backpack.CargoSlots.Add(Mount);
    Mount.Socket = TOptional<FName>(n"Pocket3");
    Backpack.CargoSlots.Add(Mount);
    _ItemTraits.Add(Backpack);
}

// Melee items. Use swings them (UMars_SmState_ItemUse_Strike); the Strike trait holds the damage knobs. The cleaver
// severs (preserves parts), the tenderizer crushes (ruins soft parts).
asset Mars_ItemDef_Cleaver of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Cleaver"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cube();
    Presentation.Visual.MeshScale = FVector(0.08, 0.5, 0.25);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
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
    _ItemTraits.Add(Strike);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Tenderizer of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Tenderizer"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cylinder();
    Presentation.Visual.MeshScale = FVector(0.25, 0.25, 0.5);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
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
    _ItemTraits.Add(Strike);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

// The foraging tool: blunt, so it cracks husks and knocks the censer.
asset Mars_ItemDef_Pan of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Pan"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cube();
    Presentation.Visual.MeshScale = FVector(0.35, 0.35, 0.04);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Pose = EMars_HandGripPose::Power;
    _ItemTraits.Add(Presentation);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_Strike;
    UseAction.HintText = FText::FromString("swing");
    UseAction.CompletionPolicy = ECk_Interaction_CompletionPolicy::Instant;
    _ItemTraits.Add(UseAction);

    auto Strike = Cast<UMars_ItemTrait_Strike>(NewObject(this, UMars_ItemTrait_Strike));
    Strike.Damage = 25.0f;
    Strike.DamageType = GameplayTags::DamageType_Mars_Blunt;
    Strike.Swing = utils_hand_swing::Make_SwipeArc();
    _ItemTraits.Add(Strike);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
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
