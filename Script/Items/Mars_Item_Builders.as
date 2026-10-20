// The trait blocks item definitions share, added to a definition from its asset block (`mars_items::Add_X(this, ...)`).

// A blockout item: a proxy mesh over the ProtoGrid item material, held as Handedness says.
struct FMars_ItemBlockout
{
    TSoftObjectPtr<UStaticMesh> Mesh;

    FVector Scale = FVector::OneVector;

    // Unset: the presentation's default grip shape.
    TOptional<EMars_FPHands_GripShape> Shape;

    EMars_ItemPresentation_Handedness Handedness = EMars_ItemPresentation_Handedness::TwoHanded;

    // Unset: the presentation's default grip pose.
    TOptional<EMars_HandGripPose> Pose;

    // Unset: the material's own colour.
    TOptional<FLinearColor> Color;

    FMars_ItemBlockout() {}

    FMars_ItemBlockout(TSoftObjectPtr<UStaticMesh> InMesh, FVector InScale, EMars_ItemPresentation_Handedness InHandedness)
    {
        Mesh = InMesh;
        Scale = InScale;
        Handedness = InHandedness;
    }
}

// A whole food's item look (its world item is the food's own joint, so no mesh): held at HeldOffset with the palms
// HalfWidth either side, and the food it is.
struct FMars_FoodItemLook
{
    FTransform HeldOffset = FTransform::Identity;

    float32 HalfWidth = 0.0f;

    UMars_Food_Def Food;

    FMars_FoodItemLook() {}

    FMars_FoodItemLook(FTransform InHeldOffset, float32 InHalfWidth, UMars_Food_Def InFood)
    {
        HeldOffset = InHeldOffset;
        HalfWidth = InHalfWidth;
        Food = InFood;
    }
}

namespace mars_items
{
    // The blockout's Presentation and a default Throwable. Returns the Presentation for what only this item sets (its world
    // item script, its mounting).
    UMars_ItemTrait_Presentation Add_BlockoutTraits(UCk_InventoryItem_Definition InDefinition, const FMars_ItemBlockout& InBlockout)
    {
        auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(InDefinition, UMars_ItemTrait_Presentation));
        Presentation.Visual.Mesh = InBlockout.Mesh;
        Presentation.Visual.MeshScale = InBlockout.Scale;
        Presentation.Visual.MaterialOverride = TSoftObjectPtr<UMaterialInterface>(assets::ProtoGrid_Item_Mars_MI().ToSoftObjectPath());
        Presentation.Visual.PrimaryColor = InBlockout.Color;
        if (InBlockout.Shape.IsSet())
        { Presentation.Grip.Shape = InBlockout.Shape.GetValue(); }

        if (InBlockout.Pose.IsSet())
        { Presentation.Grip.Pose = InBlockout.Pose.GetValue(); }

        Presentation.Grip.Handedness = InBlockout.Handedness;
        InDefinition._ItemTraits.Add(Presentation);

        InDefinition._ItemTraits.Add(Cast<UMars_ItemTrait_Throwable>(NewObject(InDefinition, UMars_ItemTrait_Throwable)));
        return Presentation;
    }

    // A whole food: its cradle presentation (Make_FoodPresentation), a platter's throw (Make_PlatterThrowable) and its Food
    // trait.
    void Add_FoodTraits(UCk_InventoryItem_Definition InDefinition, const FMars_FoodItemLook& InLook)
    {
        InDefinition._ItemTraits.Add(Make_FoodPresentation(InDefinition, InLook.HeldOffset, InLook.HalfWidth));
        InDefinition._ItemTraits.Add(Make_PlatterThrowable(InDefinition));

        auto Food = Cast<UMars_ItemTrait_Food>(NewObject(InDefinition, UMars_ItemTrait_Food));
        Food.Food = InLook.Food;
        InDefinition._ItemTraits.Add(Food);
    }

    // Every key: one bar shape, its shaft along +X so a lock can push it in along its keyhole; only the tag and the colour
    // differ. The asset names it (_CoreInfo is read-only here).
    void Add_KeyTraits(UCk_InventoryItem_Definition InDefinition, FGameplayTag InKeyId)
    {
        auto Blockout = FMars_ItemBlockout(engine::Cube(), FVector(0.3, 0.08, 0.05), EMars_ItemPresentation_Handedness::OneHanded);
        Blockout.Pose = TOptional<EMars_HandGripPose>(EMars_HandGripPose::Power);
        Blockout.Color = TOptional<FLinearColor>(constants_key_colors::Get_Color(InKeyId));
        Add_BlockoutTraits(InDefinition, Blockout);

        auto Key = Cast<UMars_ItemTrait_Key>(NewObject(InDefinition, UMars_ItemTrait_Key));
        Key.KeyId = InKeyId;
        InDefinition._ItemTraits.Add(Key);
    }
}
