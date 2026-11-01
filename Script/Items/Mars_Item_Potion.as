// Potions: a round-bottom flask of liquid, or a jar of pickles in brine. Its world item (in the world and in the hand) is
// UMars_Potion_EntityScript, which puts the liquid inside the glass and keeps its surface level and sloshing; the Potion
// Look trait picks the vessel and the liquid (the green potion, a boiling one, pickling brine, the pickle jar's brine with
// its pickles drawn in it). Nothing drinks them yet: they are held props.

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

    // PickleJar_Mars_SM is 8.8 x 8.8 x 10.7 cm, pivot at its base: at the flask's scale 15.8 x 15.8 x 19 cm, too wide for
    // the glove to wrap. Carried on the palm: the right glove cradles it under its base (the Grip socket), the fingers
    // closing up round the foot on its bounds box, the jar standing over the hand node.
    const FString k_JarMeshPath = "/Game/Mars/Gameplay/Items/Potion/Meshes/PickleJar_Mars_SM.PickleJar_Mars_SM";
    const FVector k_JarHeldLocation = FVector(6.0, -2.0, -12.0);

    const FString k_BubblingMaterialPath = "/Game/Mars/Gameplay/Items/Potion/Materials/PotionBubbling_Mars_MI.PotionBubbling_Mars_MI";
    const FString k_BrineMaterialPath = "/Game/Mars/Gameplay/Items/Potion/Materials/PickleBrine_Mars_MI.PickleBrine_Mars_MI";
    const FString k_PickleJarMaterialPath = "/Game/Mars/Gameplay/Items/Potion/Materials/PickleJarBrine_Mars_MI.PickleJarBrine_Mars_MI";
}

namespace mars_items
{
    // The vessel InLook names (the flask by its neck, the jar round its body), held and thrown the same way; InLook also
    // picks its liquid.
    void Add_PotionTraits(UCk_InventoryItem_Definition InDefinition, const FMars_PotionLook& InLook)
    {
        const auto IsJar = InLook.Vessel == EMars_PotionVessel::Jar;
        auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(InDefinition, UMars_ItemTrait_Presentation));
        Presentation.Visual.Mesh = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(
            IsJar ? constants_potion_item::k_JarMeshPath : constants_potion_item::k_FlaskMeshPath));
        Presentation.Visual.MeshScale = FVector(constants_potion_item::k_MeshScale, constants_potion_item::k_MeshScale, constants_potion_item::k_MeshScale);
        Presentation.Grip.Pose = IsJar ? EMars_HandGripPose::Cradle : EMars_HandGripPose::Power;
        Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
        Presentation.Grip.Shape = IsJar ? EMars_FPHands_GripShape::Box : EMars_FPHands_GripShape::Handle;
        Presentation.Mounting.HeldOffset = FTransform(FRotator::ZeroRotator,
            IsJar ? constants_potion_item::k_JarHeldLocation : constants_potion_item::k_HeldLocation);
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

// Pickling brine in the flask (PickleBrine_Mars_MI: the master's Brine switch).
asset Mars_ItemDef_Brine of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Pickle Brine"));
    mars_items::Add_PotionTraits(this, mars_items::Make_PotionLook(0.75f, constants_potion_item::k_BrineMaterialPath));
}

// A jar of pickles: brine in the jar with upright pickles drawn in it (PickleJarBrine_Mars_MI: the Brine and Pickle Jar
// switches). The pickles are the shader's, not items: none can be taken out yet.
asset Mars_ItemDef_PickleJar of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Pickle Jar"));
    auto Look = mars_items::Make_PotionLook(0.88f, constants_potion_item::k_PickleJarMaterialPath);
    Look.Vessel = EMars_PotionVessel::Jar;
    mars_items::Add_PotionTraits(this, Look);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Potion() { return Mars_ItemDef_Potion; }
    UCk_InventoryItem_Definition BoilingPotion() { return Mars_ItemDef_BoilingPotion; }
    UCk_InventoryItem_Definition Brine() { return Mars_ItemDef_Brine; }
    UCk_InventoryItem_Definition PickleJar() { return Mars_ItemDef_PickleJar; }
}
