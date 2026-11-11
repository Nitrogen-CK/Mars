// A hotbar slot root spawned straight under an entity that is not a hotbar (not through utils_hotbar::Add) ensures once in
// its construction (the expected error below) and is destroyed, leaving its owner without a slot fragment anywhere.
class UMars_AutoTest_Hotbar_ASlotSpawnedOutsideAddEnsures : UCk_AutoTest_Base
{
    private FCk_Handle _Owner;
    private FCk_Handle _Slot;
    private int32 _EnsuresBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("spawn a slot root under a plain entity", n"Step_Spawn");
        Add_Step_WaitUntil("the slot root ended", n"Check_SlotEnded");
        Add_Step("the guard ensured once", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Spawn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _EnsuresBefore = utils_ensure::Get_EnsureCount();
        _Slot = utils_entity_script::Request_SpawnEntity(_Owner, UMars_HotbarSlot_Local_EntityScript,
            FMars_HotbarSlot_SpawnParams(0, EMars_Hotbar_SlotKind::Bag)).Get_EntityUnderConstruction();
    }

    UFUNCTION()
    private void Check_SlotEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Slot)
            || utils_entity_lifetime::Get_IsPendingDestroy(_Slot, ECk_EntityLifetime_DestructionPhase::BeginDestroy));
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(utils_ensure::Get_EnsureCount() - _EnsuresBefore, 1, "the slot's guard ensured exactly once");
        Assert_False(ck::IsValid(_Slot) && _Slot.Has_Fragment(FMars_Fragment_HotbarSlot), "the misplaced slot never composed its slot");
    }
}

// Hand-authored so the guard's ensure is an expected error rather than a failure.
class AMars_AutoTest_Hotbar_ASlotSpawnedOutsideAddEnsures_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_Hotbar_ASlotSpawnedOutsideAddEnsures;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("which is not a hotbar: spawn slots through utils_hotbar::Add");
        return Out;
    }
}
