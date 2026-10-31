// Potions: a round-bottom flask of liquid. Its world item (in the world and in the hand) is UMars_Potion_EntityScript,
// which puts the liquid inside the glass and keeps its surface level and sloshing; the Potion Look trait picks the liquid
// (the green potion, a boiling one, pickling brine). Nothing drinks them yet: they are held props.

namespace constants_potion_item
{
    // PotionFlask_Mars_SM is 9.2 x 9.2 x 15 cm with its pivot at its flat base (mars_potion_ue.py); at this scale
    // 16.6 x 16.6 x 27 cm, sized to the gloves rather than to a real hand.
    const FString k_FlaskMeshPath = "/Game/Mars/Gameplay/Items/Potion/Meshes/PotionFlask_Mars_SM.PotionFlask_Mars_SM";
    const float64 k_MeshScale = 1.8;
    // Held upright by the neck: the right glove takes the mesh's Grip socket (mars_potion_ue.add_grip_socket: thumb up the
    // neck, palm toward the viewer, fingers round the front) and closes on it as a handle, while the flask stands where this puts it in
    // the hand node's space: the body about level with the node and a little in, so it hangs in view under the fist (the
    // glove rises to the neck, about 10 cm over the node).
    const FVector k_HeldLocation = FVector(2.0, -3.0, -8.0);

    const FString k_BubblingMaterialPath = "/Game/Mars/Gameplay/Items/Potion/Materials/PotionBubbling_Mars_MI.PotionBubbling_Mars_MI";
    const FString k_BrineMaterialPath = "/Game/Mars/Gameplay/Items/Potion/Materials/PickleBrine_Mars_MI.PickleBrine_Mars_MI";
}

namespace mars_items
{
    // The flask every potion shares, held and thrown the same way; InLook picks its liquid.
    void Add_PotionTraits(UCk_InventoryItem_Definition InDefinition, const FMars_PotionLook& InLook)
    {
        auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(InDefinition, UMars_ItemTrait_Presentation));
        Presentation.Visual.Mesh = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(constants_potion_item::k_FlaskMeshPath));
        Presentation.Visual.MeshScale = FVector(constants_potion_item::k_MeshScale, constants_potion_item::k_MeshScale, constants_potion_item::k_MeshScale);
        Presentation.Grip.Pose = EMars_HandGripPose::Power;
        Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
        Presentation.Grip.Shape = EMars_FPHands_GripShape::Handle;
        Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator, constants_potion_item::k_HeldLocation);
        Presentation.WorldItem.ScriptClass = UMars_Potion_EntityScript;
        InDefinition._ItemTraits.Add(Presentation);

        auto Look = Cast<UMars_ItemTrait_PotionLook>(NewObject(InDefinition, UMars_ItemTrait_PotionLook));
        Look.Look = InLook;
        InDefinition._ItemTraits.Add(Look);

        auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(InDefinition, UMars_ItemTrait_Throwable));
        InDefinition._ItemTraits.Add(Throwable);
    }

    FMars_PotionLook Make_PotionLook(float32 InFill, FString InMaterialPath)
    {
        auto Look = FMars_PotionLook();
        Look.Fill = InFill;
        if (InMaterialPath.IsEmpty() == false)
        { Look.LiquidMaterial = TSoftObjectPtr<UMaterialInterface>(FSoftObjectPath(InMaterialPath)); }
        return Look;
    }
}

asset Mars_ItemDef_Potion of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Potion"));
    mars_items::Add_PotionTraits(this, mars_items::Make_PotionLook(0.65f, ""));
}

// The same flask at a boil (PotionBubbling_Mars_MI: the master's Bubbling switch).
asset Mars_ItemDef_BoilingPotion of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Boiling Potion"));
    mars_items::Add_PotionTraits(this, mars_items::Make_PotionLook(0.7f, constants_potion_item::k_BubblingMaterialPath));
}

// Pickling brine in the flask (PickleBrine_Mars_MI: the master's Brine switch), until it has a jar of its own.
asset Mars_ItemDef_Brine of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Pickle Brine"));
    mars_items::Add_PotionTraits(this, mars_items::Make_PotionLook(0.75f, constants_potion_item::k_BrineMaterialPath));
}

namespace mars_items
{
    UCk_InventoryItem_Definition Potion() { return Mars_ItemDef_Potion; }
    UCk_InventoryItem_Definition BoilingPotion() { return Mars_ItemDef_BoilingPotion; }
    UCk_InventoryItem_Definition Brine() { return Mars_ItemDef_Brine; }
}
