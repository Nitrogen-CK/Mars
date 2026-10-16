// Colour-coded keys for the sandbox locks (UMars_KeyLock_EntityScript). A key is a proxy bar, its shaft along +X so a lock
// can push it in along its keyhole; the colour comes from constants_key_colors, which the locks paint their keyholes with.

namespace constants_key_colors
{
    const FLinearColor k_Red    = FLinearColor(0.85f, 0.08f, 0.06f, 1.0f);
    const FLinearColor k_Blue   = FLinearColor(0.08f, 0.3f, 1.0f, 1.0f);
    const FLinearColor k_Green  = FLinearColor(0.1f, 0.75f, 0.15f, 1.0f);
    const FLinearColor k_Yellow = FLinearColor(1.0f, 0.8f, 0.05f, 1.0f);
    const FLinearColor k_Purple = FLinearColor(0.55f, 0.12f, 0.9f, 1.0f);
    // A key tag with no colour of its own.
    const FLinearColor k_Unknown = FLinearColor(0.6f, 0.6f, 0.6f, 1.0f);

    FLinearColor Get_Color(FGameplayTag InKeyId)
    {
        if (InKeyId == GameplayTags::Key_Mars_Red)
        { return k_Red; }

        if (InKeyId == GameplayTags::Key_Mars_Blue)
        { return k_Blue; }

        if (InKeyId == GameplayTags::Key_Mars_Green)
        { return k_Green; }

        if (InKeyId == GameplayTags::Key_Mars_Yellow)
        { return k_Yellow; }

        if (InKeyId == GameplayTags::Key_Mars_Purple)
        { return k_Purple; }

        return k_Unknown;
    }
}

namespace utils_key_item
{
    // Every key's traits: one shape; only the tag and the colour differ. The asset names it (_CoreInfo is read-only here).
    void Add_Traits(UCk_InventoryItem_Definition InDefinition, FGameplayTag InKeyId)
    {
        auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(InDefinition, UMars_ItemTrait_Presentation));
        Presentation.Visual.Mesh = engine::Cube();
        Presentation.Visual.MeshScale = FVector(0.3, 0.08, 0.05);
        Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
        Presentation.Visual.PrimaryColor = TOptional<FLinearColor>(constants_key_colors::Get_Color(InKeyId));
        Presentation.Grip.Pose = EMars_HandGripPose::Power;
        Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
        InDefinition._ItemTraits.Add(Presentation);

        auto Key = Cast<UMars_ItemTrait_Key>(NewObject(InDefinition, UMars_ItemTrait_Key));
        Key.KeyId = InKeyId;
        InDefinition._ItemTraits.Add(Key);

        auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(InDefinition, UMars_ItemTrait_Throwable));
        InDefinition._ItemTraits.Add(Throwable);
    }
}

asset Mars_ItemDef_Key_Red of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Red key"));
    utils_key_item::Add_Traits(this, GameplayTags::Key_Mars_Red);
}

asset Mars_ItemDef_Key_Blue of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Blue key"));
    utils_key_item::Add_Traits(this, GameplayTags::Key_Mars_Blue);
}

asset Mars_ItemDef_Key_Green of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Green key"));
    utils_key_item::Add_Traits(this, GameplayTags::Key_Mars_Green);
}

asset Mars_ItemDef_Key_Yellow of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Yellow key"));
    utils_key_item::Add_Traits(this, GameplayTags::Key_Mars_Yellow);
}

asset Mars_ItemDef_Key_Purple of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Purple key"));
    utils_key_item::Add_Traits(this, GameplayTags::Key_Mars_Purple);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Key_Red()    { return Mars_ItemDef_Key_Red;    }
    UCk_InventoryItem_Definition Key_Blue()   { return Mars_ItemDef_Key_Blue;   }
    UCk_InventoryItem_Definition Key_Green()  { return Mars_ItemDef_Key_Green;  }
    UCk_InventoryItem_Definition Key_Yellow() { return Mars_ItemDef_Key_Yellow; }
    UCk_InventoryItem_Definition Key_Purple() { return Mars_ItemDef_Key_Purple; }
}
