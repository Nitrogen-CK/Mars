// A torch lit in the hand and then stowed (an empty hotbar slot selected) goes out on the belt: snuffed, dark, no probe
// shown, OnLitChanged fired for the lighting and the snuff. Selected again it is still snuffed with its fuel kept, and it
// lights again. Its 90 s measures never tick within the test. Isolated origin: (8000, 0, -60000).
class UMars_AutoTest_Flame_ASnuffsFlameGoesOutWhenStowedAndStaysOutWhenSelected : UMars_AutoTestRig_FlameItem
{
    private TArray<bool> _Lit;
    private int32 _MeasuresInHand = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBelt(InHandle, FVector(8000.0, 0.0, -60000.0));
        Add_Hotbar(_Carrier, 2);
        _HeldItem = utils_held_item::Add(_Carrier);

        SpawnFlameItem(InHandle, FMars_AutoTestHelper_FlameItemSpawn(mars_items::Torch(), UMars_Torch_EntityScript, FVector(8000.0, 150.0, -60000.0)));

        Add_Step_WaitUntil("the torch world item is composed", n"Check_FlameReady", k_SlowPolls, 0);
        Add_Step("stow the torch into the carrier's hotbar and light it", n"Step_StowAndLight");
        Add_Step_WaitUntil("the carrier holds the lit torch at its Held pool", n"Check_FlameHeldAndLit", k_SlowPolls, 0);
        Add_Step("in hand it lights its Held radius", n"Step_AssertLitInHand");
        Add_Step("select the empty slot", n"Step_SelectEmptySlot");
        Add_Step_WaitUntil("the torch's pool has been Stowed for a pass", n"Check_PoolPassedStowed", k_SlowPolls, 0);
        Add_Step_WaitSeconds("let the snuff settle", 0.1f);
        Add_Step("on the belt it is snuffed and dark", n"Step_AssertSnuffedOnTheBelt");
        Add_Step("select the torch again", n"Step_SelectZero");
        Add_Step_WaitUntil("the torch's pool has been Held for a pass", n"Check_PoolPassedHeld", k_SlowPolls, 0);
        Add_Step("back in hand it is still snuffed, its fuel kept", n"Step_AssertStillSnuffedInHand");
        Add_Step("light it again", n"Step_Light");
        Add_Step_WaitUntil("the carrier holds the relit torch at its Held pool", n"Check_FlameHeldAndLit", k_SlowPolls, 0);
        Add_Step("it relit on the fuel it kept", n"Step_AssertRelit");
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
    private void Step_AssertLitInHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Flame = Get_Flame();
        Assert_Equals_Float(Flame.Get_LightRadius(), 600.0f, 0.01f, "it lights its Held radius");
        Assert_True(Get_OnlyProbeEnabled(EMars_Flame_Pool::Held), "its Held probe is the only one enabled");
        Assert_False(ck::IsValid(Flame.Get_LightProbe(EMars_Flame_Pool::Stowed)), "a flame that snuffs when stowed has no Stowed probe");

        _MeasuresInHand = Flame.Get_MeasuresLeft();
        Assert_Equals_Int(_MeasuresInHand, 3, "it is full");
    }

    // The Pool processor writes LastPool after its snuff rule, so a Stowed LastPool means the rule has run.
    UFUNCTION()
    private void Check_PoolPassedStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto LastPool = Get_FlameState().LastPool;
        auto Res = OutResult;
        Res.Set(LastPool.IsSet() && LastPool.GetValue() == EMars_Flame_Pool::Stowed);
    }

    UFUNCTION()
    private void Check_PoolPassedHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto LastPool = Get_FlameState().LastPool;
        auto Res = OutResult;
        Res.Set(_FlameItem.Get_Mount() == EMars_WorldItem_Mount::Held && LastPool.IsSet() && LastPool.GetValue() == EMars_Flame_Pool::Held);
    }

    UFUNCTION()
    private void Step_AssertSnuffedOnTheBelt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Flame = Get_Flame();
        Assert_True(Flame.Get_IsStowed(), f"it rides the belt ({Get_FlameStateText()})");
        Assert_True(Flame.Get_Ignition() == EMars_Flame_Ignition::Snuffed, "stowing snuffed it");
        Assert_False(Flame.Get_IsLit(), "a snuffed torch is dark");
        Assert_False(Flame.Get_ShownLightPool().IsSet(), "no light probe is shown");
        Assert_True(Flame.Get_LightRadius() == 0.0f, "it lights nothing");
        Assert_False(Flame.Has_Fragment(FMars_Tag_Flame_Burning), "a snuffed torch does not burn");
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the carrier's hands are empty");

        Assert_Equals_Int(_Lit.Num(), 2, "OnLitChanged fired for the lighting and the snuff");
        if (_Lit.Num() == 2)
        {
            Assert_True(_Lit[0], "lighting lit it");
            Assert_False(_Lit[1], "stowing put it out");
        }

        Assert_Equals_Int(Flame.Get_MeasuresLeft(), _MeasuresInHand, "the snuff burnt no fuel");
    }

    UFUNCTION()
    private void Step_AssertStillSnuffedInHand(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Flame = Get_Flame();
        Assert_True(_HeldItem.Get_CurrentItem() == Get_FlameItem(), "the carrier holds the torch");
        Assert_True(Flame.Get_Ignition() == EMars_Flame_Ignition::Snuffed, f"selecting it did not relight it ({Get_FlameStateText()})");
        Assert_False(Flame.Get_IsLit(), "it is still dark");
        Assert_False(Flame.Get_ShownLightPool().IsSet(), "still no light probe is shown");
        Assert_Equals_Int(Flame.Get_MeasuresLeft(), _MeasuresInHand, "its fuel is kept");
        Assert_Equals_Int(_Lit.Num(), 2, "OnLitChanged did not fire on the way back to the hand");
    }

    UFUNCTION()
    private void Step_AssertRelit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Flame = Get_Flame();
        Assert_True(Flame.Get_IsLit(), "it lights again");
        Assert_Equals_Int(Flame.Get_MeasuresLeft(), _MeasuresInHand, "on the fuel it kept");
        Assert_Equals_Float(Flame.Get_LightRadius(), 600.0f, 0.01f, "at its Held radius");
        Assert_Equals_Int(_Lit.Num(), 3, "OnLitChanged fired once more, for the relighting");
        if (_Lit.Num() == 3)
        { Assert_True(_Lit[2], "the last edge is the relighting"); }
    }
}
