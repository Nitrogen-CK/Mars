// Every cuttable-food definition validates, and its display materials follow its mesh's material slots (a display material
// per slot, by the slot's name, then the cap's): the meat's Flesh and Skin (fat cap) slots and its cap wear its Food
// instance (MeatSlab_Mars_MI, which reads the cook state); the mushroom slice's Skin and Flesh slots and its cap wear its
// Food instance, and it is not batterable (batter is for whole ingredients; the slice is already cut); each prep food's cooking slot (Flesh or Skin) and its cap wear its prep instance (<Name>_Prep_Mars_MI) and
// it is batterable. Each cap's slot is the one after the mesh's last section, so the display covers every material ID a cut
// can carry. Each carries its kind (the beef is also meat, by hierarchy), and a definition without one does not validate.
class UMars_AutoTest_CuttingStation_FoodDefinitionsFollowTheirMeshes : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("each definition's materials follow its mesh's slots", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Meat = mars::Food_MeatSlab_Mars;
        const auto MeatMesh = Assert_Definition(Meat);
        if (ck::IsValid(MeatMesh))
        {
            const auto Materials = Meat.Visuals.Display.Get_Materials();
            const auto Slab = assets::MeatSlab_Mars_MI().ToSoftObjectPath();
            Assert_Slot(Meat, n"Flesh", Slab);
            Assert_Slot(Meat, n"Skin", Slab);
            Assert_Equals_String(Materials[Meat.Visuals.Cap.Get_MaterialID()].ToSoftObjectPath().ToString(),
                Slab.ToString(), "the meat's cap wears its Food instance");
        }

        auto Mushroom = mars::Food_MushroomSlice_Mars;
        const auto MushroomMesh = Assert_Definition(Mushroom);
        if (ck::IsValid(MushroomMesh))
        {
            const auto Materials = Mushroom.Visuals.Display.Get_Materials();
            const auto Slice = assets::Mushroom_Slice_Mars_MI().ToSoftObjectPath();
            Assert_Slot(Mushroom, n"Skin", Slice);
            Assert_Slot(Mushroom, n"Flesh", Slice);
            Assert_Equals_String(Materials[Mushroom.Visuals.Cap.Get_MaterialID()].ToSoftObjectPath().ToString(),
                Slice.ToString(), "the mushroom's cap wears its Food instance");
        }

        Assert_True(Meat.Data.Kind.HasTag(GameplayTags::Food_Meat_Beef), "the meat is beef");
        Assert_True(Meat.Data.Kind.HasTag(GameplayTags::Food_Meat), "beef is meat (hierarchy)");
        Assert_True(Mushroom.Data.Kind.HasTag(GameplayTags::Food_Vegetable_Mushroom), "the mushroom slice is a mushroom");
        Assert_False(Mushroom.Get_IsBatterable(), "the mushroom slice is already cut: not batterable");

        Assert_Prep(mars::Food_Drumstick_Mars, n"Flesh", assets::Drumstick_Prep_Mars_MI().ToSoftObjectPath());
        Assert_Prep(mars::Food_Tentacle_Mars, n"Flesh", assets::Tentacle_Prep_Mars_MI().ToSoftObjectPath());
        Assert_Prep(mars::Food_Puffer_Mars, n"Skin", assets::Puffer_Prep_Mars_MI().ToSoftObjectPath());
        Assert_Prep(mars::Food_SpikedBerry_Mars, n"Skin", assets::SpikedBerry_Prep_Mars_MI().ToSoftObjectPath());
        Assert_Prep(mars::Food_Mushroom_Mars, n"Skin", assets::Mushroom_Prep_Mars_MI().ToSoftObjectPath());
        Assert_True(mars::Food_Drumstick_Mars.Data.Kind.HasTag(GameplayTags::Food_Meat), "the drumstick is meat");
        Assert_True(mars::Food_Tentacle_Mars.Data.Kind.HasTag(GameplayTags::Food_Meat), "the tentacle is meat");
        Assert_True(mars::Food_Puffer_Mars.Data.Kind.HasTag(GameplayTags::Food_Meat), "the puffer is meat");
        Assert_True(mars::Food_SpikedBerry_Mars.Data.Kind.HasTag(GameplayTags::Food_Vegetable), "the spiked berry is a vegetable");
        Assert_True(mars::Food_Mushroom_Mars.Data.Kind.HasTag(GameplayTags::Food_Vegetable_Mushroom), "the mushroom is a mushroom");

        // The meat with its Kind cleared: everything else validates, so only the missing kind can refuse it.
        auto Unkinded = NewObject(this, UMars_Food_Def);
        Unkinded.Data = Meat.Data;
        Unkinded.Visuals = Meat.Visuals;
        Unkinded.Data.Kind = FGameplayTagContainer();
        Assert_False(Unkinded.Validate().IsValid(), "a definition with no Kind does not validate");
    }

    // The definition's mesh once it validates and its cap follows the last section; null otherwise.
    private UStaticMesh Assert_Definition(UMars_Food_Def InFood)
    {
        const auto Validation = InFood.Validate();
        Assert_True(Validation.IsValid(), f"[{InFood.GetName()}] validates: {Validation.Get_Error()}");

        auto Mesh = System::LoadAsset_Blocking(InFood.Data.Mesh);
        Assert_True(ck::IsValid(Mesh), f"[{InFood.GetName()}] has a mesh that loads");
        if (ck::Is_NOT_Valid(Mesh))
        { return nullptr; }

        const auto Sections = Mesh.GetNumSections(0);
        const auto FleshSlot = Mesh.GetMaterialIndex(n"Flesh");
        const auto SkinSlot = Mesh.GetMaterialIndex(n"Skin");
        ck::Trace(f"[CuttingStation test] {Mesh.GetName()}: {Sections} sections, Flesh slot {FleshSlot}, Skin slot {SkinSlot}");
        Assert_Equals_Int(InFood.Visuals.Display.Get_Materials().Num(), Sections + 1, f"[{InFood.GetName()}] has a material per section and the cap's");
        Assert_Equals_Int(InFood.Visuals.Cap.Get_MaterialID(), Sections, f"[{InFood.GetName()}] caps on the slot after the last section");
        return Mesh;
    }

    // A prep food: it validates, its cooking slot InSlot and its cap wear InExpected, and it is batterable.
    private void Assert_Prep(UMars_Food_Def InFood, FName InSlot, FSoftObjectPath InExpected)
    {
        if (ck::Is_NOT_Valid(Assert_Definition(InFood)))
        { return; }

        Assert_Slot(InFood, InSlot, InExpected);
        const auto Materials = InFood.Visuals.Display.Get_Materials();
        Assert_Equals_String(Materials[InFood.Visuals.Cap.Get_MaterialID()].ToSoftObjectPath().ToString(), InExpected.ToString(),
            f"[{InFood.GetName()}] cap wears its prep instance");
        Assert_True(InFood.Get_IsBatterable(), f"[{InFood.GetName()}] is batterable");
    }

    // InFood's mesh is loaded (Assert_Definition).
    private void Assert_Slot(UMars_Food_Def InFood, FName InSlot, FSoftObjectPath InExpected)
    {
        const auto Index = InFood.Data.Mesh.Get().GetMaterialIndex(InSlot);
        const auto Materials = InFood.Visuals.Display.Get_Materials();
        Assert_True(Materials.IsValidIndex(Index), f"[{InFood.GetName()}] covers its mesh's {InSlot} slot (index {Index})");
        if (Materials.IsValidIndex(Index) == false)
        { return; }

        Assert_Equals_String(Materials[Index].ToSoftObjectPath().ToString(), InExpected.ToString(),
            f"[{InFood.GetName()}] slot {InSlot} ({Index}) wears the definition's material for it");
    }
}
