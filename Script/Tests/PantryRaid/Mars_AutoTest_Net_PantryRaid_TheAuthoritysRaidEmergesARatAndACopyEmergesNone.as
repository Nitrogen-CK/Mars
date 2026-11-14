// The server's court (floor, built field, raid, den, a pack with a Monk's Rind in cargo slot 1) becomes ready and its
// raid emerges one rat, which the server has authority over, which belongs to that raid and which walks off; the den's
// slot 0 is out and the eyes stand for slot 1. The client's den copy shows that one change of eyes and nothing else;
// its raid copy has run nothing although its den and pack copies stand inside its bounds, and no rat exists there.
// Surface: Ck.PantryRaid.Net.AS_PantryRaid_TheAuthoritysRaidEmergesARatAndACopyEmergesNone
class UCk_AutoTest_Net_PantryRaid_TheAuthoritysRaidEmergesARatAndACopyEmergesNone : UMars_AutoTestRig_NetPantryRaid
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(671000.0, 0.0, 5000.0);
    private const float64 k_RatWalkCm = 60.0;
    private const float32 k_RatWalkSeconds = 6.0f;
    private const FString k_Row = "TheAuthoritysRaidEmergesARatAndACopyEmergesNone";

    private FCk_Handle_PantryRat _Rat;
    private FVector _RatFirstSeenAt = FVector::ZeroVector;
    private float64 _RatMoved = 0.0;
    private float64 _RatWalkUntil = 0.0;

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
        Get_IsRowDenFound();
        _Rat = Get_RowFirstRat();
        _RatFirstSeenAt = Get_RowRootLocation(_Rat);
        _RatWalkUntil = Get_RowWorldSeconds() + k_RatWalkSeconds;
        WaitUntil(n"Is_RatWalkedOff", n"OnServerRatWalked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RatWalkedOff(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_IsRowEnding(_Rat) == false)
        { _RatMoved = Math::Max(_RatMoved, Get_PlanarDistance(Get_RowRootLocation(_Rat), _RatFirstSeenAt)); }

        auto Result = OutResult;
        Result.Set(_RatMoved > k_RatWalkCm || Get_RowWorldSeconds() >= _RatWalkUntil);
    }

    UFUNCTION()
    private void OnServerRatWalked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerEnd");
    }

    UFUNCTION()
    private void OnServerEnd(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto RatAlive = Get_IsRowEnding(_Rat) == false;
        FCk_Handle RatEntity = _Rat;
        const auto RatAuthority = RatAlive && utils_net::Get_HasAuthority(RatEntity);
        const auto RatDriver = RatAlive && utils_entity_replication_driver::Has(RatEntity);
        const auto RatNetParams = RatAlive && utils_net::Has(RatEntity);
        const auto RatReplication = RatNetParams ? utils_net::Get_EntityReplication(RatEntity) : ECk_Replication::DoesNotReplicate;
        const auto Extra = f"rat=[alive {RatAlive} authority {RatAuthority} driver {RatDriver} netParams {RatNetParams} replication {RatReplication :n} moved {_RatMoved}] {Describe_CourtFrames()}";
        Log_PantryRow(k_Row, Extra);

        Assert_True(_RowRaid.Get_IsReady(), "the server's raid is ready");
        Assert_True(_RowRaid.Get_EmergencesRequested() >= 1, "the server's raid asked for an emergence");
        Assert_True(_RatSpawnedSignals >= 1, "the server's raid raised OnRatSpawned");
        Assert_True(RatAlive, "the server's rat stands");
        Assert_True(RatAlive && utils_entity_tag::Has(RatEntity, utils_pantry_rat::RatTag), "the server's rat carries the rat tag");
        Assert_True(RatAuthority, "the server has authority over its rat");
        Assert_True(RatAlive && _Rat.Get_Raid() == _RowRaid, "the server's rat belongs to its raid");
        Assert_True(_RatMoved > k_RatWalkCm, f"the server's rat walked more than {k_RatWalkCm} (moved {_RatMoved})");
        Assert_True(_RowDen.Get_SlotState(0) != EMars_RatDen_SlotState::Dormant, "the server's den slot 0 is out");
        Assert_True(Get_IsRowEyeSlot(1), "the server's den eyes stand for slot 1");
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
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsRowEnding(_RowRaid) || Get_IsRowEnding(_RowDen) || Get_IsRowEnding(_RowPack))
        {
            Log_PantryRow(k_Row, "copies=gone");
            FinishFailure("the client's copies were gone before it asserted");
            return;
        }

        Assert_Equals_Int(_EyeChanges.Num(), 1, "the client's den copy raised one eye change");
        Assert_True(Get_IsEyeChange(0, EMars_RatDen_Eyes::Shown, 1), "the client's eye change is Shown on slot 1");
        Assert_True(Get_IsRowDenLedger(EMars_RatDen_Eyes::Shown, 1), "the client's den ledger reads Shown and 1");
        Assert_True(_RowRaid.Get_Clock() == 0.0f, f"the client's raid copy clock reads 0 (reads {_RowRaid.Get_Clock()})");
        Assert_Equals_Int(_RowRaid.Get_EmergencesRequested(), 0, "the client's raid copy asked for no emergence");
        Assert_Equals_Int(_RowRaid.Get_RatCount(), 0, "the client's raid copy has no rat record");
        Assert_True(_RowRaid.Get_IsInsideBounds(Get_RowRootLocation(_RowDen)), "the client's den copy stands inside its raid copy's bounds");
        Assert_True(_RowRaid.Get_IsInsideBounds(Get_RowRootLocation(_RowPack)), "the client's pack copy stands inside its raid copy's bounds");
        Assert_Equals_Int(_RowRaid.Get_Dens().Num(), 0, "the client's raid copy has no den");
        Assert_Equals_Int(_RowRaid.Get_Packs().Num(), 0, "the client's raid copy has no pack");
        Assert_False(_RowRaid.Get_IsReady(), "the client's raid copy is not ready");
        Assert_Equals_Int(Count_RatsHere(), 0, "no rat exists on the client");
        Finish_PantryRow(k_Row, "");
    }
}
