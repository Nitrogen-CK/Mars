// A Persistent body links its item on a client from the replicated ledger: the server spawns the Persistent fixture on a
// floor (its holder seeds the item and the authority writes the link); the client finds its copy, links it without ever
// seeding, and reads the same pair both ways: the body names the item its holder holds, and that item names the body.
// The body stays World on both machines.
// Surface: Ck.WorldItem.Net.AS_WorldItem_APersistentBodyLinksItsItemOnTheClient
class UCk_AutoTest_Net_WorldItem_APersistentBodyLinksItsItemOnTheClient : UMars_AutoTestRig_NetWorldItem
{
    private const FVector k_FloorTop = FVector(27000.0, 0.0, 5000.0);

    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientLinkedAndHeld", n"OnClientLinkedAndHeld", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerPersistent(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitUntil(n"Is_ServerLinked", n"OnServerLinked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLinked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = _Rock.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_IsLinked() && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void OnServerLinked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WorldItem.Get_Item() == _WorldItem.Get_HeldItem(), "the server's body links the item its holder holds");
        Assert_True(_WorldItem.Get_Fragment(FMars_Fragment_WorldItem_Net).Item == _WorldItem.Get_Item(),
            "the server wrote the link into the replicated ledger");
        Assert_False(_WorldItem.Has_Fragment(FMars_Tag_WorldItem_AwaitingLink), "the authority never waits for a link");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientLinkedAndHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_WorldItem))
        { _WorldItem = Find_WorldItemNear(k_FloorTop); }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && _WorldItem.Get_IsLinked() && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void OnClientLinkedAndHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Item = _WorldItem.Get_Item();
        Assert_False(utils_net::Get_HasAuthority(_WorldItem), "the client's body has no authority");
        Assert_True(_WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent, "the client's body is Persistent");
        Assert_True(Item == _WorldItem.Get_HeldItem(), "the client's body links the item its own holder holds");
        Assert_True(Item.Has_PersistentWorldItem(), "the client stamped the item's back-link");
        Assert_True(Item.Get_PersistentWorldItem() == _WorldItem, "the client's item names the client's body");
        Assert_False(_WorldItem.Has_Fragment(FMars_Tag_WorldItem_AwaitingLink), "the link processor consumed the wait");
        Assert_True(_WorldItem.Get_Mount() == EMars_WorldItem_Mount::World, "the client's body is mounted World");
        Log(f"[WorldItemNetTest] linked client body=[{_WorldItem.ToString()}] item=[{Item.ToString()}] backLinkIsBody={Item.Get_PersistentWorldItem() == _WorldItem} mount={_WorldItem.Get_Mount() :n} frame={utils_time::Get_FrameCounter()}");
        FinishSuccess();
    }
}
