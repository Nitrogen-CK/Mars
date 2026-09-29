// Sandbox items: enough variety to fill the bag, the overflow slot, and exercise use/drop/throw.

asset Mars_ItemDef_Rock of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Rock"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Sphere();
    Presentation.MeshScale = FVector(0.3, 0.3, 0.3);
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Interactable_Mars_MI().ToSoftObjectPath());
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
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Interactable_Mars_MI().ToSoftObjectPath());
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
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Interactable_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Rock()   { return Mars_ItemDef_Rock;   }
    UCk_InventoryItem_Definition Ration() { return Mars_ItemDef_Ration; }
    UCk_InventoryItem_Definition Cog()    { return Mars_ItemDef_Cog;    }
}
