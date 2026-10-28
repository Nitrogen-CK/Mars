// One persistent physical book: the closed proxy supplies collision, glove contact and the remote held-item view;
// UMars_Cookbook_EntityScript substitutes the animated skeletal presentation on the owning copy.
asset Mars_ItemDef_Cookbook of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Cookbook"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Meshes/SM_Cookbook_Closed.SM_Cookbook_Closed"));
    // One physical scale for the static proxy, collision, pickup fit and animated visual.
    Presentation.Visual.MeshScale = FVector(1.2, 1.2, 1.2);
    Presentation.Grip.Pose = EMars_HandGripPose::Cradle;
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::TwoHanded;
    Presentation.Grip.Layout = EMars_HandGripLayout::Sides;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Back;
    // Source +Z faces the camera; centre the closed book in the hand frame. The visual child recentres the open spine.
    Presentation.Mounting.HeldOffset = FTransform(FRotator(0.0, 90.0, 90.0),
        FVector(0.9746, -constants_cookbook::k_ClosedSpineOffset, 1.0813) * Presentation.Visual.MeshScale);
    Presentation.WorldItem.ScriptClass = UMars_Cookbook_EntityScript;
    _ItemTraits.Add(Presentation);

    auto UseAction = Cast<UMars_ItemTrait_UseAction>(NewObject(this, UMars_ItemTrait_UseAction));
    UseAction.UseStateClass = UMars_SmState_ItemUse_ToggleCookbook;
    UseAction.HintText = FText::FromString("open / close book");
    _ItemTraits.Add(UseAction);
    _ItemTraits.Add(Cast<UMars_ItemTrait_Throwable>(NewObject(this, UMars_ItemTrait_Throwable)));
}

namespace mars_items
{
    UCk_InventoryItem_Definition Cookbook() { return Mars_ItemDef_Cookbook; }
}
