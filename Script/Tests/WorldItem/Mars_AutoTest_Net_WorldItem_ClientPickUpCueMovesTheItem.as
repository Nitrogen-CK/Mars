// A client's pickup crosses as Cue.Mars.WorldItem.PickUp, fired at the world item's root with the subject as the
// initiator: the server's drain stows the item into the subject's hotbar there, and the emptied world item ends on the
// server, which the client sees as its rock leaving. The subject stands in for the pawn (the harness has no possessed
// character on the client); its hotbar is composed on both machines, as the pawn's is.
// Surface: Ck.WorldItem.Net.AS_WorldItem_ClientPickUpCueMovesTheItem
class UCk_AutoTest_Net_WorldItem_ClientPickUpCueMovesTheItem : UMars_AutoTestRig_NetWorldItem
{
    private const FVector k_FloorTop = FVector(18000.0, 0.0, 5000.0);

    private FMars_TESTONLY_NetCarrier _Carrier;
    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        _Carrier = Compose_Carrier(k_FloorTop + FVector(-200.0, 0.0, 100.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientRockHeld", n"OnClientRockHeld", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Rock = Spawn_ServerRock(k_FloorTop + FVector(0.0, 0.0, 20.0));
        WaitUntil(n"Is_ServerStowed", n"OnServerStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Carrier.Hotbar.Get_ItemAt(0)));
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_ClientRockHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _WorldItem = Find_WorldItemNear(k_FloorTop);
        auto Result = OutResult;
        Result.Set(ck::IsValid(_WorldItem) && ck::IsValid(_WorldItem.Get_HeldItem()));
    }

    UFUNCTION()
    private void OnClientRockHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_WorldItem), "the client's rock has no authority");
        utils_cue_generic::Request_ExecuteCue(_WorldItem, GameplayTags::Cue_Mars_WorldItem_PickUp,
            FMars_Request_WorldItem_PickUp(Get_SubjectEntity()), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_ClientRockGone", n"OnClientRockGone", k_SlowPolls);
    }

    // The server's stow empties the holder, then the emptied world item ends; either reaching the client is the effect.
    UFUNCTION()
    private void Is_ClientRockGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(_WorldItem) || Get_HolderCount(_WorldItem) == 0);
    }

    UFUNCTION()
    private void OnClientRockGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }
}
