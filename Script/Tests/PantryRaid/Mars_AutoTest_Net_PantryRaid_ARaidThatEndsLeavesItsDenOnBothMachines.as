// The server's court emerges one rat and then destroys its raid: the rat, which lives under the raid, goes with it, and
// the den stays on both machines with slot 0 out and the eyes on slot 1 (nothing brings a rat of an ended raid home).
// Nothing tagged as a raid or a rat is left near the base on either machine.
// Surface: Ck.PantryRaid.Net.AS_PantryRaid_ARaidThatEndsLeavesItsDenOnBothMachines
class UCk_AutoTest_Net_PantryRaid_ARaidThatEndsLeavesItsDenOnBothMachines : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(675000.0, 0.0, 5000.0);
    private const float32 k_RatOutSeconds = 1.0f;
    private const float32 k_RatGoneSeconds = 5.0f;
    private const FString k_Row = "ARaidThatEndsLeavesItsDenOnBothMachines";

    private FCk_Handle _RatEntity;
    private float64 _RatGoneUntil = 0.0;
    private int32 _RaidDestroyedFrame = -1;
    private int32 _RatGoneFrame = -1;
    private FString _RatAtSpawn;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_PantryRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_RowCourtFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_RowSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Spec = Make_RowSpec();
        Spec.Population.MaxActiveRats = 1;
        Spawn_ServerCourt(Spec);
        WaitUntil(n"Is_RowFloorJoined", n"OnServerFloorJoined", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFloorJoined(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerFieldBuild();
        WaitUntil(n"Is_RowPackAndCheeseReady", n"OnServerPackReady", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPackReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerStowCheese();
        WaitUntil(n"Is_RowCheeseStowed", n"OnServerStowed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStowed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RowFirstRatOut", n"OnServerRatOut", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRatOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _RatEntity = Get_RowFirstRat();
        const auto Driver = utils_entity_replication_driver::Has(_RatEntity);
        const auto NetParams = utils_net::Has(_RatEntity);
        const auto Replication = NetParams ? utils_net::Get_EntityReplication(_RatEntity) : ECk_Replication::DoesNotReplicate;
        _RatAtSpawn = f"rat=[authority {utils_net::Get_HasAuthority(_RatEntity)} driver {Driver} netParams {NetParams} replication {Replication :n}]";
        WaitSeconds(k_RatOutSeconds, n"OnServerRatWasOut");
    }

    UFUNCTION()
    private void OnServerRatWasOut(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle RaidEntity = _RowRaid;
        utils_entity_lifetime::Request_DestroyEntity(RaidEntity);
        _RaidDestroyedFrame = int32(utils_time::Get_FrameCounter());
        _RatGoneUntil = Get_RowWorldSeconds() + k_RatGoneSeconds;
        WaitUntil(n"Is_ServerRatGone", n"OnServerRatGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRatGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Gone = ck::Is_NOT_Valid(_RatEntity);
        if (Gone && _RatGoneFrame < 0)
        { _RatGoneFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(Gone || Get_RowWorldSeconds() >= _RatGoneUntil);
    }

    UFUNCTION()
    private void OnServerRatGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerEnd");
    }

    UFUNCTION()
    private void OnServerEnd(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Extra = f"{_RatAtSpawn} raidDestroyed={_RaidDestroyedFrame} ratGone={_RatGoneFrame} {Describe_CourtFrames()}";
        Log_PantryRow(k_Row, Extra);
        Assert_True(ck::Is_NOT_Valid(_RatEntity), "the server's rat went with its raid");
        Assert_Equals_Int(Count_TaggedNearBase(utils_pantry_raid::RaidTag), 0, "no raid is left near the base on the server");
        Assert_Equals_Int(Count_TaggedNearBase(utils_pantry_rat::RatTag), 0, "no rat is left near the base on the server");
        Assert_False(Get_IsRowEnding(_RowDen), "the server's den stands");
        Assert_True(Get_IsRowEnding(_RowDen) == false && _RowDen.Get_SlotState(0) == EMars_RatDen_SlotState::Outside,
            "the server's den slot 0 is Outside");
        Assert_True(Get_IsRowEyeSlot(1), "the server's den eyes stand for slot 1");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Shown, 1), "the server's den ledger reads Shown and 1");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        TearDown();
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RowEyeSlotOne", n"OnClientEyesMoved", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEyesMoved(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientRaidGone", n"OnClientRaidGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientRaidGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowEnding(_RowRaid));
    }

    UFUNCTION()
    private void OnClientRaidGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowEnding(_RowDen))
        {
            Log_PantryRow(k_Row, "den=gone");
            FinishFailure("the client's den copy was gone before it asserted");
            return;
        }

        Assert_True((Get_RowRootLocation(_RowDen) - _DenSpot).Size() <= 5.0, "the client's den copy stands within 5 of its spot");
        Assert_True(Get_IsRowEyeSlot(1), "the client's den copy: eye slot 1");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Shown, 1), "the client's den ledger reads Shown and 1");
        Assert_Equals_Int(Count_TaggedNearBase(utils_pantry_raid::RaidTag), 0, "no raid is left near the base on the client");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat exists on the client");
        Finish_PantryRow(k_Row, "");
    }
}
