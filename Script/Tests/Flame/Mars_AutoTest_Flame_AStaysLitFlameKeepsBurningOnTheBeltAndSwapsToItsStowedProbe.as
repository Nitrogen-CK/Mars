// A lantern with quick measures (twenty of 0.3 s), so a measure burns down within the test.
asset Mars_TestItemDef_QuickLantern of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Quick Lantern"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::CampLantern_Mars_SM();
    Presentation.Visual.MeshScale = FVector(constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale);
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    Presentation.WorldItem.ScriptClass = UMars_Lantern_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Fuel = FMars_Flame_Fuel();
    Fuel.Measures = 20;
    Fuel.SecondsPerMeasure = 0.3f;
    Fuel.GutterSeconds = 0.1f;

    auto Flame = Cast<UMars_ItemTrait_Flame>(NewObject(this, UMars_ItemTrait_Flame));
    Flame.Spec = mars_test_items::Make_LanternFlameSpec(Fuel);
    _ItemTraits.Add(Flame);

    auto Lantern = Cast<UMars_ItemTrait_Lantern>(NewObject(this, UMars_ItemTrait_Lantern));
    _ItemTraits.Add(Lantern);
}

// A lantern lit in the hand and then stowed (an empty hotbar slot selected) stays lit on the belt: its Stowed probe is the
// one shown, it lights its Stowed radius, OnLitChanged fired only for the lighting, and it keeps burning there, a measure
// every SecondsPerMeasure. Isolated origin: (4000, 0, -60000).
class UMars_AutoTest_Flame_AStaysLitFlameKeepsBurningOnTheBeltAndSwapsToItsStowedProbe : UMars_AutoTestRig_FlameItem
{
    private TArray<bool> _Lit;
    private int32 _MeasuresAtStow = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBelt(InHandle, FVector(4000.0, 0.0, -60000.0));
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);

        SpawnLantern(InHandle, Mars_TestItemDef_QuickLantern, FVector(4000.0, 150.0, -60000.0));

        Add_Step_WaitUntil("the lantern world item is composed", n"Check_FlameReady", k_SlowPolls, 0);
        Add_Step("stow the lantern into the carrier's hotbar and light it", n"Step_StowAndLight");
        Add_Step_WaitUntil("the carrier holds the lit lantern at its Held pool", n"Check_FlameHeldAndLit", k_SlowPolls, 0);
        Add_Step("select the empty slot", n"Step_SelectEmptySlot");
        Add_Step_WaitUntil("the lantern rides the belt, its Stowed probe the only one enabled", n"Check_StowedProbeShown", k_SlowPolls, 0);
        Add_Step("on the belt it is still lit at its Stowed radius", n"Step_AssertLitOnTheBelt");
        Add_Step_WaitSeconds("let a measure burn", 0.3f);
        Add_Step_WaitUntil("a measure burns while stowed", n"Check_BurntAMeasure", k_SlowPolls, 0);
        Add_Step("it burnt one measure on the belt and never went dark", n"Step_AssertBurntOnTheBelt");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnLitChanged(FCk_Handle_Flame InFlame, bool InIsLit)
    {
        _Lit.Add(InIsLit);
    }

    UFUNCTION()
    private void Step_StowAndLight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Flame = Get_Flame();
        Flame.BindTo_OnLitChanged(FMars_Delegate_Flame_OnLitChanged(this, n"OnLitChanged"));
        Step_StowFlame(InHandle, InPayload);
        Step_Light(InHandle, InPayload);
    }

    UFUNCTION()
    private void Check_StowedProbeShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FlameItem.Get_Mount() == EMars_WorldItem_Mount::Carried && Get_Flame().Get_IsStowed()
            && Get_OnlyProbeEnabled(EMars_Flame_Pool::Stowed));
    }

    UFUNCTION()
    private void Step_AssertLitOnTheBelt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Flame = Get_Flame();
        const auto Shown = Flame.Get_ShownLightPool();
        Assert_True(Flame.Get_IsLit(), f"a lantern stays lit on the belt ({Get_FlameStateText()})");
        Assert_True(Flame.Get_Ignition() == EMars_Flame_Ignition::Lit, "stowing did not snuff it");
        Assert_True(Shown.IsSet() && Shown.GetValue() == EMars_Flame_Pool::Stowed, "its Stowed probe is the one shown");
        Assert_Equals_Float(Flame.Get_LightRadius(), 800.0f, 0.01f, "it lights its Stowed radius");
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the carrier's hands are empty");

        Assert_Equals_Int(_Lit.Num(), 1, "OnLitChanged fired once, for the lighting");
        if (_Lit.Num() == 1)
        { Assert_True(_Lit[0], "the one edge is the lighting"); }

        _MeasuresAtStow = Flame.Get_MeasuresLeft();
        Assert_True(_MeasuresAtStow > 1, f"measures are left to burn on the belt ({_MeasuresAtStow})");
    }

    UFUNCTION()
    private void Check_BurntAMeasure(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Flame().Get_MeasuresLeft() < _MeasuresAtStow);
    }

    UFUNCTION()
    private void Step_AssertBurntOnTheBelt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Flame = Get_Flame();
        Assert_Equals_Int(Flame.Get_MeasuresLeft(), _MeasuresAtStow - 1, "one measure burnt on the belt");
        Assert_True(Flame.Get_IsStowed(), "it is still on the belt");
        Assert_True(Flame.Get_IsLit(), "it is still lit");
        Assert_True(Get_OnlyProbeEnabled(EMars_Flame_Pool::Stowed), "its Stowed probe is still the only one enabled");
        Assert_Equals_Int(_Lit.Num(), 1, "OnLitChanged never fired again");
    }
}
