// A local-class slot root spawned under a carrier that has a replication driver ensures once in its construction (the
// expected error below) and is destroyed; the carrier's own hotbar keeps its replicated slots, still ready.
class UMars_AutoTest_Hotbar_ALocalSlotUnderAReplicatedCarrierEnsures : UMars_AutoTestRig_ReplicatedHotbarCarrier
{
    private FCk_Handle _Stray;
    private TArray<FCk_Handle_Inventory_DataOnly> _SlotsBefore;
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierSteps();
        Add_Step("spawn a local slot root under the replicated carrier", n"Step_SpawnStray");
        Add_Step_WaitUntil("the stray slot root ended", n"Check_StrayEnded");
        Add_Step("the guard ensured once and the hotbar is untouched", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_SpawnStray(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _SlotsBefore = Get_CarrierHotbar().Get_Slots();
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        _Stray = utils_entity_script::Request_SpawnEntity(_Carrier, UMars_HotbarSlot_Local_EntityScript,
            FMars_HotbarSlot_SpawnParams(0, EMars_Hotbar_SlotKind::Bag)).Get_EntityUnderConstruction();
    }

    UFUNCTION()
    private void Check_StrayEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Stray)
            || utils_entity_lifetime::Get_IsPendingDestroy(_Stray, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_ensure::Get_EnsureCount() - _EnsuresBefore, 1, "the stray slot's guard ensured exactly once");
        Assert_False(ck::IsValid(_Stray) && _Stray.Has_Fragment(FMars_Fragment_HotbarSlot), "the stray slot never composed its slot");

        auto Hotbar = Get_CarrierHotbar();
        Assert_True(Hotbar.Get_IsReady(), "the carrier's hotbar is still ready");
        const auto SlotsAfter = Hotbar.Get_Slots();
        Assert_Equals_Int(SlotsAfter.Num(), _SlotsBefore.Num(), "the carrier keeps its slot count");
        for (int32 Index = 0; Index < Math::Min(SlotsAfter.Num(), _SlotsBefore.Num()); ++Index)
        { Assert_True(SlotsAfter[Index] == _SlotsBefore[Index], f"slot [{Index}] is the slot it was"); }
    }
}

// Hand-authored so the guard's ensure is an expected error rather than a failure.
class AMars_AutoTest_Hotbar_ALocalSlotUnderAReplicatedCarrierEnsures_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Hotbar_ALocalSlotUnderAReplicatedCarrierEnsures;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("is the local slot class under");
        return Out;
    }
}
