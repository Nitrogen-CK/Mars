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

asset Mars_ItemDef_Key_Red of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Red key"));
    mars_items::Add_KeyTraits(this, GameplayTags::Key_Mars_Red);
}

asset Mars_ItemDef_Key_Blue of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Blue key"));
    mars_items::Add_KeyTraits(this, GameplayTags::Key_Mars_Blue);
}

asset Mars_ItemDef_Key_Green of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Green key"));
    mars_items::Add_KeyTraits(this, GameplayTags::Key_Mars_Green);
}

asset Mars_ItemDef_Key_Yellow of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Yellow key"));
    mars_items::Add_KeyTraits(this, GameplayTags::Key_Mars_Yellow);
}

asset Mars_ItemDef_Key_Purple of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Purple key"));
    mars_items::Add_KeyTraits(this, GameplayTags::Key_Mars_Purple);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Key_Red()    { return Mars_ItemDef_Key_Red;    }
    UCk_InventoryItem_Definition Key_Blue()   { return Mars_ItemDef_Key_Blue;   }
    UCk_InventoryItem_Definition Key_Green()  { return Mars_ItemDef_Key_Green;  }
    UCk_InventoryItem_Definition Key_Yellow() { return Mars_ItemDef_Key_Yellow; }
    UCk_InventoryItem_Definition Key_Purple() { return Mars_ItemDef_Key_Purple; }
}
