// A potion: a round-bottom flask of glowing liquid. Its world item (in the world and in the hand) is
// UMars_Potion_EntityScript, which puts the liquid inside the glass and keeps its surface level and sloshing. Nothing drinks
// it yet: it is a held prop.

namespace constants_potion_item
{
    // PotionFlask_Mars_SM is 9.2 x 9.2 x 15 cm with its pivot at its flat base (mars_potion_ue.py); at this scale
    // 16.6 x 16.6 x 27 cm, sized to the gloves rather than to a real hand.
    const FString k_FlaskMeshPath = "/Game/Mars/Gameplay/Items/Potion/Meshes/PotionFlask_Mars_SM.PotionFlask_Mars_SM";
    const float64 k_MeshScale = 1.8;
    // The fist cups the base, the flask standing up out of it along the fist's closing axis (as the torch's shaft does),
    // so the body, the surface and the cork stand clear of the fingers. Held by the neck it would hang below the resting
    // fist, off the bottom of the screen. Over the pivot, at k_MeshScale.
    const float64 k_GripHeight = 1.0 * k_MeshScale;
}

asset Mars_ItemDef_Potion of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Potion"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath(constants_potion_item::k_FlaskMeshPath));
    Presentation.Visual.MeshScale = FVector(constants_potion_item::k_MeshScale, constants_potion_item::k_MeshScale, constants_potion_item::k_MeshScale);
    Presentation.Grip.Pose = EMars_HandGripPose::Power;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.HeldOffset = utils_fphands::Make_ShaftHeldOffset(constants_potion_item::k_GripHeight);
    Presentation.WorldItem.ScriptClass = UMars_Potion_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Throwable = Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable));
    _ItemTraits.Add(Throwable);
}

namespace mars_items
{
    UCk_InventoryItem_Definition Potion() { return Mars_ItemDef_Potion; }
}
