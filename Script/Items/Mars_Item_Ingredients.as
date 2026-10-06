// Forage ingredients: the rewards behind the sandbox gauntlets (Script/WorldObjects/Mechanisms/Mars_SandboxGauntlets.as).
// Blockout shapes only; each reads by silhouette, as the gauntlets' clues do.

asset Mars_ItemDef_Truffle of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Truffle"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.28, 0.28, 0.22);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Sphere;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Root of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Root"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cylinder();
    Presentation.Visual.MeshScale = FVector(0.12, 0.12, 0.45);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Capsule;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Salt of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Salt"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cube();
    Presentation.Visual.MeshScale = FVector(0.25, 0.2, 0.2);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Fungus of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Fungus"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Cone();
    Presentation.Visual.MeshScale = FVector(0.3, 0.3, 0.25);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}


// A handful of peppercorns: the censer spills one per strike.
asset Mars_ItemDef_Peppercorns of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Peppercorns"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.18, 0.18, 0.18);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Sphere;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

asset Mars_ItemDef_Fig of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Fig"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.22, 0.22, 0.28);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Sphere;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

// What a cracked Bellnut releases. Declared before the Bellnut, whose Husk names it.
asset Mars_ItemDef_BellnutKernel of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Bellnut Kernel"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.15, 0.15, 0.15);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Sphere;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

// The whole nut: blunt or crushing strikes in the world crack it into a kernel; a blade never does.
asset Mars_ItemDef_Bellnut of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Bellnut"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = engine::Sphere();
    Presentation.Visual.MeshScale = FVector(0.26, 0.26, 0.26);
    Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
    Presentation.Grip.Shape = EMars_FPHands_GripShape::Sphere;
    Presentation.WorldItem.ScriptClass = UMars_WorldItem_Husk_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);

    auto Husk = Cast<UMars_ItemTrait_Husk>(NewObject(this, UMars_ItemTrait_Husk));
    Husk.Kernel = TSoftObjectPtr<UCk_InventoryItem_Definition>(Mars_ItemDef_BellnutKernel);
    Husk.CrackHealth = 50.0f;
    Husk.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Blunt, 1.0f, EMars_HitZone_ConditionImpact::Damages));
    Husk.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Crush, 1.0f, EMars_HitZone_ConditionImpact::Damages));
    Husk.Reactions.Add(FMars_HitZone_Reaction(GameplayTags::DamageType_Mars_Sever, 0.0f, EMars_HitZone_ConditionImpact::None));
    _ItemTraits.Add(Husk);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Truffle()       { return Mars_ItemDef_Truffle;       }
    UCk_InventoryItem_Definition Root()          { return Mars_ItemDef_Root;          }
    UCk_InventoryItem_Definition Salt()          { return Mars_ItemDef_Salt;          }
    UCk_InventoryItem_Definition Fungus()        { return Mars_ItemDef_Fungus;        }
    UCk_InventoryItem_Definition Peppercorns()   { return Mars_ItemDef_Peppercorns;   }
    UCk_InventoryItem_Definition Fig()           { return Mars_ItemDef_Fig;           }
    UCk_InventoryItem_Definition BellnutKernel() { return Mars_ItemDef_BellnutKernel; }
    UCk_InventoryItem_Definition Bellnut()       { return Mars_ItemDef_Bellnut;       }
}
