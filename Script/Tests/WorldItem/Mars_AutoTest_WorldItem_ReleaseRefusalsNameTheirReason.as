// A release the drain refuses answers OnReleaseRefused with its reason and moves nothing. A backpack lying in the world is
// released: refused NotMounted, still World. It is put on (Carried on the Back), then released twice in one frame: the
// first release goes through (it lands World), the second is refused InFlight. Both refusals ensure (the actor below).
// Isolated origin (61200, -12000, -30000).
class UMars_AutoTest_WorldItem_ReleaseRefusalsNameTheirReason : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(61200.0, -12000.0, -30000.0);
    private const FVector k_PackOffset = FVector(200.0, 0.0, 0.0);

    private FCk_Handle_WorldItem _Pack;
    private TArray<EMars_WorldItem_ReleaseRefusal> _ReleaseRefusals;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBodyWithBack(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);

        Spawn_FloorSlab(InHandle, k_Origin + k_PackOffset);
        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.Definition = mars_items::Backpack();
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Origin + k_PackOffset + FVector(0.0, 0.0, 20.0));
        auto Pending = utils_entity_script::Request_SpawnEntity(InHandle, UMars_WorldItem_EntityScript, SpawnParams);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnPackConstructed"));

        Add_Step_WaitUntil("the backpack is constructed, its item linked and it lies settled", n"Check_LyingSettled", 0, 0);
        Add_Step("release it while it lies in the world", n"Step_ReleaseLying");
        Add_Step_WaitUntil("the release is refused", n"Check_OneRefusal", 0, 0);
        Add_Step("refused NotMounted, still World; put it on", n"Step_AssertNotMountedAndWear");
        Add_Step_WaitUntil("it settles Carried on the Back", n"Check_Worn", 0, 0);
        Add_Step("release it twice in one frame", n"Step_ReleaseTwice");
        Add_Step_WaitUntil("the first release landed World and the second was refused", n"Check_ReleasedAndRefused", 0, 0);
        Add_Step("the second was refused InFlight", n"Step_AssertInFlight");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPackConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Pack = InEntityScriptHandle.As_WorldItem();
        _Pack.BindTo_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnReleaseRefused"));
    }

    UFUNCTION()
    private void OnReleaseRefused(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        _ReleaseRefusals.Add(InReason);
    }

    UFUNCTION()
    private void Check_LyingSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Pack) && ck::IsValid(_Pack.Get_Item()) && _Pack.Get_Mount() == EMars_WorldItem_Mount::World
            && _Pack.Get_IsSettled());
    }

    UFUNCTION()
    private void Step_ReleaseLying(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Pack.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_OneRefusal(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReleaseRefusals.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertNotMountedAndWear(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ReleaseRefusals.Num(), 1, "one refusal");
        Assert_True(_ReleaseRefusals[0] == EMars_WorldItem_ReleaseRefusal::NotMounted,
            f"a lying item is refused NotMounted (got {_ReleaseRefusals[0] :n})");
        Assert_True(_Pack.Get_Mount() == EMars_WorldItem_Mount::World, "it still lies in the world");
        Assert_False(_Pack.Has_Fragment(FMars_Fragment_WorldItem_PendingRelease), "no release is pending");

        auto Holder = _Pack.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(_Pack.Get_Item(), _Hotbar.Get_BackpackSlot()),
            FCk_Delegate_Inventory_OnOperationResult_Transfer());
    }

    UFUNCTION()
    private void Check_Worn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Pack.Get_Mount() == EMars_WorldItem_Mount::Carried && _Pack.Get_IsSettled());
    }

    UFUNCTION()
    private void Step_ReleaseTwice(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Pack.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
        _Pack.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
    }

    UFUNCTION()
    private void Check_ReleasedAndRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReleaseRefusals.Num() >= 2 && _Pack.Get_Mount() == EMars_WorldItem_Mount::World);
    }

    UFUNCTION()
    private void Step_AssertInFlight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ReleaseRefusals.Num(), 2, "exactly one more refusal");
        Assert_True(_ReleaseRefusals[1] == EMars_WorldItem_ReleaseRefusal::InFlight,
            f"the second release in one frame is refused InFlight (got {_ReleaseRefusals[1] :n})");
        Assert_Equals_Int(_Pack.Get_Holder().Get_NumItems(), 1, "the first release put the item back in its holder");
        Assert_False(ck::IsValid(_Hotbar.Get_BackpackItem()), "the backpack slot is empty");
    }
}

// Hand-authored so the two refusals' ensures are expected rather than failures; pinned to each message so an unrelated
// ensure still fails the test.
class AMars_AutoTest_WorldItem_ReleaseRefusalsNameTheirReason_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_WorldItem_ReleaseRefusalsNameTheirReason;
    default _TimeoutSeconds = 20.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("[WorldItem] Illegal release of [");
        Out.Add("while its last release has not answered - skipped");
        return Out;
    }
}
