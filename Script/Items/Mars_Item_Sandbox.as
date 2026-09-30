// Sandbox items: enough variety to fill the bag, the overflow slot, and exercise use/drop/throw.

asset Mars_ItemDef_Rock of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Rock"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Sphere();
    Presentation.MeshScale = FVector(0.3, 0.3, 0.3);
    Presentation.GripShape = EMars_FPHands_GripShape::Sphere;
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Ration of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Ration"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Cube();
    Presentation.MeshScale = FVector(0.3, 0.3, 0.3);
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
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
    Presentation.Mesh = engine::Cylinder();
    Presentation.MeshScale = FVector(0.3, 0.3, 0.3);
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

// The engine cube has no sockets, so the cargo mounts are root-relative offsets on one face (a 2x2 grid). A socketed
// mesh names its sockets in the mounts instead.
asset Mars_ItemDef_Backpack of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Backpack"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Cube();
    Presentation.MeshScale = FVector(0.45, 0.35, 0.6);
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.HeldOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -10.0));
    Presentation.PickupProbeRadius = 45.0f;
    Presentation.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
    Presentation.CarryOffset = FTransform::Identity;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    Throwable.ThrowSpeed = 500.0f;
    Throwable.DropSpeed = 100.0f;
    Throwable.AngularVelocityDeg = FVector::ZeroVector;
    _ItemTraits.Add(Throwable);

    auto Backpack = Cast<UMars_ItemTrait_Backpack>(NewObject(this, UMars_ItemTrait_Backpack));
    auto Mount = FMars_CargoSlot_Mount();
    Mount.ProbeRadius = 10.0f;
    Mount.Offset = FTransform(FRotator::ZeroRotator, FVector(-25.0, -12.0, 14.0));
    Backpack.CargoSlots.Add(Mount);
    Mount.Offset = FTransform(FRotator::ZeroRotator, FVector(-25.0, 12.0, 14.0));
    Backpack.CargoSlots.Add(Mount);
    Mount.Offset = FTransform(FRotator::ZeroRotator, FVector(-25.0, -12.0, -14.0));
    Backpack.CargoSlots.Add(Mount);
    Mount.Offset = FTransform(FRotator::ZeroRotator, FVector(-25.0, 12.0, -14.0));
    Backpack.CargoSlots.Add(Mount);
    _ItemTraits.Add(Backpack);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Rock()     { return Mars_ItemDef_Rock;     }
    UCk_InventoryItem_Definition Ration()   { return Mars_ItemDef_Ration;   }
    UCk_InventoryItem_Definition Cog()      { return Mars_ItemDef_Cog;      }
    UCk_InventoryItem_Definition Backpack() { return Mars_ItemDef_Backpack; }
}
