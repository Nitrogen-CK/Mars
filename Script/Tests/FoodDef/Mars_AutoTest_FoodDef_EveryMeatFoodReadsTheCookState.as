// The prep standard's material half (CLAUDE.md, "Prep standard for cuttable meat"): every meat food goes to the cutting
// bench and then the pan, so every part of it that cooks must read the cook state. For every food on the roster whose kind
// is meat, each display material loads and its base material is a cook-state master (Food_Mars_M or Meat_Mars_M), never
// Accent_Mars_M (which reads nothing), except a slot the mesh names as a non-cooking accent (Bone, Horn); the cap's slot
// is never an accent. The roster's meats validate (UMars_Food_Def::Validate_CookLook included). Validate_CookLook refuses
// a copy of the slab whose cap colour carries no cavity (alpha 0) or whose cap slot wears nothing, and does not hold a
// vegetable to the meat rule.
class UMars_AutoTest_FoodDef_EveryMeatFoodReadsTheCookState : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("every meat food's materials read the cook state", n"Step_AssertMaterials");
        Add_Step("the cook-look rule refuses a meat without cavity or cap material", n"Step_AssertValidation");
        Run_Steps(InHandle);
    }

    // Every food definition the game ships; a new food joins here.
    private TArray<UMars_Food_Def> Get_Roster() const
    {
        TArray<UMars_Food_Def> Foods;
        Foods.Add(mars::Food_MeatSlab_Mars);
        Foods.Add(mars::Food_MushroomSlice_Mars);
        Foods.Add(mars::Food_Drumstick_Mars);
        Foods.Add(mars::Food_Tentacle_Mars);
        Foods.Add(mars::Food_Puffer_Mars);
        Foods.Add(mars::Food_SpikedBerry_Mars);
        Foods.Add(mars::Food_Mushroom_Mars);
        Foods.Add(mars::Food_Fish_Mars);
        return Foods;
    }

    UFUNCTION()
    private void Step_AssertMaterials(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto FoodMaster = assets::Food_Mars_M().ToSoftObjectPath().ToString();
        const auto MeatMaster = assets::Meat_Mars_M().ToSoftObjectPath().ToString();

        auto MeatCount = 0;
        for (auto Food : Get_Roster())
        {
            if (Food.Data.Kind.HasTag(GameplayTags::Food_Meat) == false)
            { continue; }

            MeatCount += 1;
            const auto Validation = Food.Validate();
            Assert_True(Validation.IsValid(), f"[{Food.GetName()}] validates: {Validation.Get_Error()}");

            auto Mesh = System::LoadAsset_Blocking(Food.Data.Mesh);
            Assert_True(ck::IsValid(Mesh), f"[{Food.GetName()}] has a mesh that loads");
            if (ck::Is_NOT_Valid(Mesh))
            { continue; }

            TArray<int32> AccentSlots;
            AccentSlots.Add(Mesh.GetMaterialIndex(n"Bone"));
            AccentSlots.Add(Mesh.GetMaterialIndex(n"Horn"));
            const auto CapSlot = Food.Visuals.Cap.Get_MaterialID();

            const auto Materials = Food.Visuals.Display.Get_Materials();
            for (int32 Slot = 0; Slot < Materials.Num(); ++Slot)
            {
                auto Material = System::LoadAsset_Blocking(Materials[Slot]);
                Assert_True(ck::IsValid(Material), f"[{Food.GetName()}] slot {Slot} [{Materials[Slot].ToSoftObjectPath().ToString()}] loads");
                if (ck::Is_NOT_Valid(Material))
                { continue; }

                const auto Base = Material.GetBaseMaterial();
                const auto BasePath = ck::IsValid(Base) ? Base.GetPathName() : "none";
                const auto ReadsCookState = BasePath == FoodMaster || BasePath == MeatMaster;
                ck::Trace(f"[FoodDef test] {Food.GetName()} slot {Slot}: {Material.GetName()} on {BasePath}");

                if (Slot != CapSlot && AccentSlots.Contains(Slot))
                { continue; }

                const FString SlotName = Slot == CapSlot ? f"{Slot} (the cap)" : f"{Slot}";
                Assert_True(ReadsCookState,
                    f"[{Food.GetName()}] slot {SlotName} wears [{Material.GetName()}] on [{BasePath}]: it must read the cook state (Food_Mars_M or Meat_Mars_M)");
            }
        }

        Assert_True(MeatCount >= 5, f"the roster holds the slab, the three prep meats and the fish (found {MeatCount} meat foods)");
    }

    UFUNCTION()
    private void Step_AssertValidation(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(mars::Food_MeatSlab_Mars.Validate_CookLook().IsValid(), "the slab meets the cook-look rule");

        auto NoCavity = Make_Copy(mars::Food_MeatSlab_Mars);
        auto Color = NoCavity.Visuals.Cap.Get_Color();
        Color.A = 0.0f;
        NoCavity.Visuals.Cap.Set_Color(Color);
        AssertRejected(NoCavity, "a meat cap colour with no cavity (alpha 0)");

        auto NoCapMaterial = Make_Copy(mars::Food_MeatSlab_Mars);
        auto Materials = NoCapMaterial.Visuals.Display.Get_Materials();
        Materials[NoCapMaterial.Visuals.Cap.Get_MaterialID()] = TSoftObjectPtr<UMaterialInterface>();
        NoCapMaterial.Visuals.Display.Set_Materials(Materials);
        AssertRejected(NoCapMaterial, "a meat with no material on its cap slot");

        auto Vegetable = Make_Copy(mars::Food_Mushroom_Mars);
        auto VegetableColor = Vegetable.Visuals.Cap.Get_Color();
        VegetableColor.A = 0.0f;
        Vegetable.Visuals.Cap.Set_Color(VegetableColor);
        Assert_True(Vegetable.Validate_CookLook().IsValid(), "a vegetable is not held to the meat's cook-look rule");
    }

    private UMars_Food_Def Make_Copy(UMars_Food_Def InSource)
    {
        auto Copy = NewObject(this, UMars_Food_Def);
        Copy.Data = InSource.Data;
        Copy.Tuners = InSource.Tuners;
        Copy.Body = InSource.Body;
        Copy.Visuals = InSource.Visuals;
        Copy.Layout = InSource.Layout;
        return Copy;
    }

    private void AssertRejected(UMars_Food_Def InFood, const FString& InWhat)
    {
        const auto Result = InFood.Validate_CookLook();
        Assert_False(Result.IsValid(), f"{InWhat} is rejected");
        Assert_True(Result.Get_Error().Len() > 0, f"the rejection of {InWhat} names its rule (error: {Result.Get_Error()})");
    }
}
