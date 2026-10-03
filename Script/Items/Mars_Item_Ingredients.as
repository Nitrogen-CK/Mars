// Forage ingredients: the rewards behind the sandbox gauntlets (Script/WorldObjects/Mechanisms/Mars_SandboxGauntlets.as).
// Blockout shapes only; each reads by silhouette, as the gauntlets' clues do.

asset Mars_ItemDef_Truffle of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Truffle"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Sphere();
    Presentation.MeshScale = FVector(0.28, 0.28, 0.22);
    Presentation.GripShape = EMars_FPHands_GripShape::Sphere;
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Root of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Root"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Cylinder();
    Presentation.MeshScale = FVector(0.12, 0.12, 0.45);
    Presentation.GripShape = EMars_FPHands_GripShape::Capsule;
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Salt of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Salt"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Cube();
    Presentation.MeshScale = FVector(0.25, 0.2, 0.2);
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Fungus of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Fungus"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Mesh = engine::Cone();
    Presentation.MeshScale = FVector(0.3, 0.3, 0.25);
    Presentation.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Truffle() { return Mars_ItemDef_Truffle; }
    UCk_InventoryItem_Definition Root()    { return Mars_ItemDef_Root;    }
    UCk_InventoryItem_Definition Salt()    { return Mars_ItemDef_Salt;    }
    UCk_InventoryItem_Definition Fungus()  { return Mars_ItemDef_Fungus;  }
}
