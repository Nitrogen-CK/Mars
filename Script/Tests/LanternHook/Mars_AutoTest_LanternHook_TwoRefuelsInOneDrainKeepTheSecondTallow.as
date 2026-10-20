// A lantern at two measures of four: room for exactly one tallow (two measures). Otherwise Mars_ItemDef_Lantern.
asset Mars_TestItemDef_HalfLantern of UCk_InventoryItem_Definition
{
    _CoreInfo = FCk_InventoryItem_CoreInfo(FText::FromString("Half Lantern"));

    auto Presentation = Cast<UMars_ItemTrait_Presentation>(NewObject(this, UMars_ItemTrait_Presentation));
    Presentation.Visual.Mesh = assets::CampLantern_Mars_SM();
    Presentation.Visual.MeshScale = FVector(constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale, constants_lantern_item::k_MeshScale);
    Presentation.Grip.Handedness = EMars_ItemPresentation_Handedness::OneHanded;
    Presentation.Mounting.Persistence = EMars_WorldItem_Persistence::Persistent;
    Presentation.Mounting.CarryPoint = GameplayTags::AttachPoint_Mars_Belt;
    Presentation.WorldItem.ScriptClass = UMars_Lantern_EntityScript;
    _ItemTraits.Add(Presentation);

    auto Lantern = Cast<UMars_ItemTrait_Lantern>(NewObject(this, UMars_ItemTrait_Lantern));
    Lantern.Spec.StartMeasures = TOptional<int32>(2);
    _ItemTraits.Add(Lantern);
}

// Two refuels queued in one drain against a lantern with room for one keep the second tallow. A shuttered lantern at two
// measures of four is hung from its world item's holder onto an empty hook. Two tallows, each in its own holder, are
// queued for refuel in the same frame. The drain takes the first: the lantern fills to four and the first tallow is
// destroyed. The second would overfill the lantern counting the measures already queued, so the drain ensures,
// broadcasts OnRequestFailed once naming the second tallow, and keeps it in its holder. The actor below requires the
// ensure. Isolated Z band: -99000.
class UMars_AutoTest_LanternHook_TwoRefuelsInOneDrainKeepTheSecondTallow : UMars_AutoTestRig_LanternHook
{
    // Every OnRequestFailed's item, in order.
    private TArray<FCk_Handle_Item> _FailedItems;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Hook = MakeHook(InHandle, FVector(150.0, 0.0, -99000.0), FGameplayTag());
        _Hook.BindTo_OnRequestFailed(FMars_Delegate_LanternHook_OnRequestFailed(this, n"OnHookRequestFailed"));

        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Tallow()));
        _Holders.Add(MakeSeededHolder(InHandle, mars_items::Tallow()));
        SpawnLantern(InHandle, Mars_TestItemDef_HalfLantern, FVector(0.0, 150.0, -99000.0));

        Add_Step_WaitUntil("both tallows' holders are seeded and the lantern composed", n"Check_Ready", k_SlowPolls, 0);
        Add_Step("hang the lantern from its world item's holder", n"Step_HangFromHolder");
        Add_Step_WaitUntil("the lantern hangs on the hook, settled", n"Check_Hung", k_SlowPolls, 0);
        Add_Step("the hung lantern has room for one tallow; queue both refuels in one frame", n"Step_RefuelTwice");
        Add_Step_WaitUntil("the lantern is full and the first tallow is gone", n"Check_FirstRefuelApplied", k_SlowPolls, 0);
        Add_Step("the second tallow was refused and kept", n"Step_AssertSecondKept");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHookRequestFailed(FCk_Handle_LanternHook InHook, FCk_Handle_Item InItem)
    {
        _FailedItems.Add(InItem);
    }

    UFUNCTION()
    private void Check_Ready(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Seeded = _Holders[0].Get_NumItems() == 1 && _Holders[1].Get_NumItems() == 1;
        if (Seeded && _Items.Num() == 0)
        {
            _Items.Add(_Holders[0].Get_Items()[0]);
            _Items.Add(_Holders[1].Get_Items()[0]);
        }

        const auto Composed = Get_IsLanternReady();
        auto Res = OutResult;
        Res.Set(Seeded && Composed);
    }

    UFUNCTION()
    private void Step_HangFromHolder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Hook, "the hook");
        _Hook.Request_Hang(FMars_Request_LanternHook_Hang(Get_LanternItem()));
    }

    UFUNCTION()
    private void Step_RefuelTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lantern = _Hook.Get_Lantern();
        Assert_Valid(Lantern, "the hung lantern");
        Assert_Equals_Int(Lantern.Get_Measures(), 4, "the lantern holds four measures");
        Assert_Equals_Int(Lantern.Get_MeasuresLeft(), 2, "the half lantern has two measures left");
        Assert_Equals_Int(_Items[0].Get_Tallow().Measures, 2, "the first tallow is two measures");
        Assert_Equals_Int(_Items[1].Get_Tallow().Measures, 2, "the second tallow is two measures");

        _Hook.Request_Refuel(FMars_Request_LanternHook_Refuel(_Items[0]));
        _Hook.Request_Refuel(FMars_Request_LanternHook_Refuel(_Items[1]));
    }

    UFUNCTION()
    private void Check_FirstRefuelApplied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hook.Get_Lantern().Get_MeasuresLeft() == 4 && ck::Is_NOT_Valid(_Items[0]));
    }

    UFUNCTION()
    private void Step_AssertSecondKept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Lantern = _Hook.Get_Lantern();
        Assert_Equals_Int(Lantern.Get_MeasuresLeft(), 4, "the lantern is full");
        Assert_False(Lantern.Get_CanRefuel(), "a full lantern has no room");
        Assert_Equals_Int(_Holders[0].Get_NumItems(), 0, "the first tallow left its holder");
        Assert_Valid(_Items[1], "the second tallow");
        Assert_Equals_Int(_Holders[1].Get_NumItems(), 1, "the second tallow's holder still holds it");
        Assert_True(_Holders[1].Get_Items()[0] == _Items[1], "the kept item is the second tallow");
        Assert_Equals_Int(_FailedItems.Num(), 1, "OnRequestFailed fired once");
        Assert_True(_FailedItems[0] == _Items[1], "the failure names the second tallow");
    }
}

// Hand-authored so the drain's refusal of the second tallow is a required ensure, raised exactly once.
class AMars_AutoTest_LanternHook_TwoRefuelsInOneDrainKeepTheSecondTallow_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_LanternHook_TwoRefuelsInOneDrainKeepTheSecondTallow;
    default _TimeoutSeconds = 30.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Item (Mars_ItemDef_Tallow))] is no tallow in an inventory, or no lantern with room hangs here - skipped");
        return Out;
    }
}
