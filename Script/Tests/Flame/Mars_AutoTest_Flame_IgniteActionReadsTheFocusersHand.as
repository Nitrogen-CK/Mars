// A torch whose one measure of pitch burns out in a fifth of a second. Otherwise Mars_ItemDef_Torch.
asset Mars_TestItemDef_ShortTorch of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Short Torch"));

    auto Blockout = FMars_ItemBlockout(engine::Cylinder(), constants_torch_item::k_ShaftScale, EMars_ItemPresentation_Handedness::OneHanded);
    auto Presentation = mars_items::Add_BlockoutTraits(this, Blockout);
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    Presentation.WorldItem.ScriptClass = UMars_Torch_EntityScript;

    auto Fuel = FMars_Flame_Fuel();
    Fuel.Measures = 3;
    Fuel.SecondsPerMeasure = 0.2f;
    Fuel.GutterSeconds = 0.05f;
    Fuel.StartMeasures = TOptional<int32>(1);
    Fuel.Refuel = EMars_Flame_Refuel::NotRefuelable;

    auto Flame = Cast<UMars_ItemTrait_Flame>(NewObject(this, UMars_ItemTrait_Flame));
    Flame.Spec.Fuel = TOptional<FMars_Flame_Fuel>(Fuel);
    Flame.Spec.Enclosure = EMars_Flame_Enclosure::Open;
    Flame.Spec.Lighting = EMars_Flame_Lighting::SelfLighting;
    Flame.Spec.OnStow = EMars_Flame_OnStow::Snuffs;
    Flame.Spec.Radius.Held = 800.0f;
    Flame.Spec.Radius.World = 800.0f;
    _ItemTraits.Add(Flame);
}

// What a fixture flame (bare, needs a flame, unlimited) offers a carrier by what it holds: nothing or an unlit torch at the
// unlit fixture -> Blocked_NeedsAFlame; the torch lit -> Light; the fixture lit from it -> None; the torch snuffed ->
// TakeLight; a lantern at the unlit fixture -> Blocked_Enclosed; a spent torch -> Blocked_Spent. The torch rides slot 0,
// the lantern slot 1, the short torch slot 2. Isolated origin: (14000, 0, -60000).
class UMars_AutoTest_Flame_IgniteActionReadsTheFocusersHand : UMars_AutoTestRig_FlameItem
{
    private const FVector k_Origin = FVector(14000.0, 0.0, -60000.0);

    private FCk_Handle_Flame _Fixture;
    private FCk_Handle_WorldItem _Lantern;
    private FCk_Handle_Item _LanternItem;
    private FCk_Handle_WorldItem _ShortTorch;
    private FCk_Handle_Item _ShortTorchItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBelt(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 3);
        _HeldItem = utils_held_item::Add(_Carrier);

        auto FixtureEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(FixtureEntity, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, -300.0, 0.0)), ECk_Replication::DoesNotReplicate);
        auto FixtureSpec = FMars_Flame_Spec();
        FixtureSpec.Lighting = EMars_Flame_Lighting::NeedsAFlame;
        _Fixture = utils_flame::Add(FixtureEntity, FixtureSpec);

        SpawnFlameItem(InHandle, FMars_AutoTestHelper_FlameItemSpawn(mars_items::Torch(), UMars_Torch_EntityScript, k_Origin + FVector(0.0, 150.0, 0.0)));
        Spawn_WorldItem(InHandle, FMars_AutoTestHelper_FlameItemSpawn(mars_items::Lantern(), UMars_Lantern_EntityScript, k_Origin + FVector(0.0, 300.0, 0.0)), n"OnLanternConstructed");
        Spawn_WorldItem(InHandle, FMars_AutoTestHelper_FlameItemSpawn(Mars_TestItemDef_ShortTorch, UMars_Torch_EntityScript, k_Origin + FVector(0.0, 450.0, 0.0)), n"OnShortTorchConstructed");

        Add_Step_WaitUntil("the torch, the lantern and the short torch are composed", n"Check_AllReady", k_SlowPolls, 0);
        Add_Step("holding nothing at the unlit fixture", n"Step_AssertNothingHeld");
        Add_Step("stow the torch (slot 0, selected)", n"Step_StowFlame");
        Add_Step_WaitUntil("the carrier holds the torch", n"Check_TorchHeld", k_SlowPolls, 0);
        Add_Step("holding the unlit torch at the unlit fixture", n"Step_AssertUnlitTorch");
        Add_Step("light the torch", n"Step_Light");
        Add_Step_WaitUntil("the carrier holds the lit torch", n"Check_FlameHeldAndLit", k_SlowPolls, 0);
        Add_Step("holding the lit torch at the unlit fixture", n"Step_AssertLitTorch");
        Add_Step("light the fixture from the torch", n"Step_LightFixtureFromTorch");
        Add_Step_WaitUntil("the fixture lights", n"Check_FixtureLit", 0, 0);
        Add_Step("holding the lit torch at the lit fixture", n"Step_AssertBothLit");
        Add_Step("snuff the torch", n"Step_Snuff");
        Add_Step_WaitUntil("the torch goes out", n"Check_TorchDark", 0, 0);
        Add_Step("holding the snuffed torch at the lit fixture", n"Step_AssertTakeLight");
        Add_Step("snuff the fixture, stow the lantern (slot 1)", n"Step_SnuffFixtureAndStowLantern");
        Add_Step_WaitUntil("the fixture is dark and the lantern is in slot 1", n"Check_LanternStowed", k_SlowPolls, 0);
        Add_Step("stow the short torch (slot 2), light the lantern, select it", n"Step_StowShortTorchAndSelectLantern");
        Add_Step_WaitUntil("the carrier holds the lit lantern, the short torch is in slot 2", n"Check_LanternHeldAndLit", k_SlowPolls, 0);
        Add_Step("holding the lit lantern at the unlit fixture", n"Step_AssertLantern");
        Add_Step("select the short torch", n"Step_SelectShortTorch");
        Add_Step_WaitUntil("the carrier holds the short torch", n"Check_ShortTorchHeld", k_SlowPolls, 0);
        Add_Step("light the short torch", n"Step_LightShortTorch");
        Add_Step_WaitUntil("the short torch burns out", n"Check_ShortTorchSpent", k_SlowPolls, 0);
        Add_Step("holding the spent torch at the unlit fixture", n"Step_AssertSpent");
        Run_Steps(InHandle);
    }

    // The world items outlive the test entity: they are owned by the transient entity.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        DoDestroy(_FlameItem);
        DoDestroy(_Lantern);
        DoDestroy(_ShortTorch);
    }

    private void DoDestroy(FCk_Handle_WorldItem InWorldItem)
    {
        if (ck::Is_NOT_Valid(InWorldItem))
        { return; }

        auto Entity = InWorldItem.H();
        utils_entity_lifetime::Request_DestroyEntity(Entity);
    }

    // A World-mode world item of InSpawn's definition and script; InOnConstructed hears its construction.
    private void Spawn_WorldItem(FCk_Handle InHandle, FMars_AutoTestHelper_FlameItemSpawn InSpawn, FName InOnConstructed)
    {
        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = InSpawn.Definition;
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InSpawn.Location);

        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, InSpawn.ScriptClass, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, InOnConstructed));
    }

    UFUNCTION()
    private void OnLanternConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Lantern = InEntityScriptHandle.As_WorldItem();
    }

    UFUNCTION()
    private void OnShortTorchConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _ShortTorch = InEntityScriptHandle.As_WorldItem();
    }

    private FCk_Handle_Flame Get_LanternFlame() const
    {
        return _Lantern.H().As_Flame(ECk_SanityCheck::UnChecked);
    }

    private FCk_Handle_Flame Get_ShortTorchFlame() const
    {
        return _ShortTorch.H().As_Flame(ECk_SanityCheck::UnChecked);
    }

    private EMars_Flame_Action Get_Action() const
    {
        return _Fixture.Get_ActionFor(_Carrier);
    }

    private void Assert_Action(EMars_Flame_Action InExpected, const FString& InMessage)
    {
        const auto Action = Get_Action();
        Assert_True(Action == InExpected, f"{InMessage}: expected [{InExpected :n}], got [{Action :n}]");
    }

    // Each world item is composed and its holder holds its item; records the items the first time.
    UFUNCTION()
    private void Check_AllReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_LanternItem) && ck::IsValid(_Lantern) && ck::IsValid(Get_LanternFlame()))
        { _LanternItem = _Lantern.Get_HeldItem(); }

        if (ck::Is_NOT_Valid(_ShortTorchItem) && ck::IsValid(_ShortTorch) && ck::IsValid(Get_ShortTorchFlame()))
        { _ShortTorchItem = _ShortTorch.Get_HeldItem(); }

        auto Res = OutResult;
        Res.Set(Get_IsFlameReady() && ck::IsValid(_LanternItem) && ck::IsValid(_ShortTorchItem));
    }

    UFUNCTION()
    private void Step_AssertNothingHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::Is_NOT_Valid(_HeldItem.Get_CurrentItem()), "the carrier's hands are empty");
        Assert_False(_Fixture.Get_IsLit(), "the fixture starts dark");
        Assert_Action(EMars_Flame_Action::Blocked_NeedsAFlame, "empty hands at an unlit fixture");
    }

    UFUNCTION()
    private void Check_TorchHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == Get_FlameItem());
    }

    UFUNCTION()
    private void Step_AssertUnlitTorch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(Get_Flame().Get_IsLit(), "the torch is unlit");
        Assert_Action(EMars_Flame_Action::Blocked_NeedsAFlame, "an unlit torch at an unlit fixture");
    }

    UFUNCTION()
    private void Step_AssertLitTorch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Action(EMars_Flame_Action::Light, "a lit torch at an unlit fixture");
    }

    UFUNCTION()
    private void Step_LightFixtureFromTorch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fixture.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit, Get_Flame()));
    }

    UFUNCTION()
    private void Check_FixtureLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsLit());
    }

    UFUNCTION()
    private void Step_AssertBothLit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_Flame().Get_IsLit(), "lighting the fixture left the torch lit");
        Assert_Action(EMars_Flame_Action::None, "a lit torch at a lit fixture");
    }

    UFUNCTION()
    private void Check_TorchDark(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_Flame().Get_IsLit() == false);
    }

    UFUNCTION()
    private void Step_AssertTakeLight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fixture.Get_IsLit(), "the fixture stays lit");
        Assert_Action(EMars_Flame_Action::TakeLight, "a snuffed torch at a lit fixture");
    }

    UFUNCTION()
    private void Step_SnuffFixtureAndStowLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fixture.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Snuffed));
        Stow(_Lantern, _LanternItem);
    }

    UFUNCTION()
    private void Check_LanternStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Fixture.Get_IsLit() == false && _Hotbar.Get_ItemAt(1) == _LanternItem);
    }

    // Stowed one at a time: a stow target is the first empty slot when asked, so two stows in one frame name the same one.
    UFUNCTION()
    private void Step_StowShortTorchAndSelectLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Stow(_ShortTorch, _ShortTorchItem);

        auto Lantern = Get_LanternFlame();
        Lantern.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(1));
    }

    UFUNCTION()
    private void Check_LanternHeldAndLit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _LanternItem && Get_LanternFlame().Get_IsLit() && _Hotbar.Get_ItemAt(2) == _ShortTorchItem);
    }

    UFUNCTION()
    private void Step_AssertLantern(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Fixture.Get_IsLit(), "the fixture is dark");
        Assert_Action(EMars_Flame_Action::Blocked_Enclosed, "a lit lantern at an unlit fixture");
    }

    UFUNCTION()
    private void Step_SelectShortTorch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hotbar.Request_Select(FMars_Request_Hotbar_Select(2));
    }

    UFUNCTION()
    private void Check_ShortTorchHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HeldItem.Get_CurrentItem() == _ShortTorchItem && _ShortTorch.Get_Mount() == EMars_WorldItem_Mount::Held);
    }

    UFUNCTION()
    private void Step_LightShortTorch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto ShortTorch = Get_ShortTorchFlame();
        ShortTorch.Request_SetIgnition(FMars_Request_Flame_SetIgnition(EMars_Flame_Ignition::Lit));
    }

    UFUNCTION()
    private void Check_ShortTorchSpent(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ShortTorchFlame().Get_Condition() == EMars_Flame_Condition::Spent);
    }

    UFUNCTION()
    private void Step_AssertSpent(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_HeldItem.Get_CurrentItem() == _ShortTorchItem, "the carrier still holds the short torch");
        Assert_False(Get_ShortTorchFlame().Get_IsLit(), "a spent torch is dark");
        Assert_Action(EMars_Flame_Action::Blocked_Spent, "a spent torch at an unlit fixture");
    }

    // What the pickup task does for a Persistent item: its holder -> the hotbar's stow target.
    private void Stow(FCk_Handle_WorldItem InWorldItem, FCk_Handle_Item InItem)
    {
        auto Target = _Hotbar.TryGet_StowTarget(InItem);
        if (ck::Is_NOT_Valid(Target))
        {
            FinishFailure("stow precondition: the item has a stow target");
            return;
        }

        auto Holder = InWorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(InItem, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }
}
