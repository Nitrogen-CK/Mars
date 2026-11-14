// The server stands its Pickle Mimic up and latches a gape of 0.8 as soon as its behaviour reads Disguised and it
// carries no pending requests, before the client's copy can be sure to have composed: the client's copy reads standing
// with its lid at 0.8 and its ledger Standing and 0.8, having raised OnStance(Standing) at most once (0: the ledger
// stood when the copy bound and it shows the mimic where it is; 1: the ledger arrived after and it played the stand).
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_ALateBinderSeesAStandingMimic
class UCk_AutoTest_Net_PickleMimic_ALateBinderSeesAStandingMimic : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(616000.0, 0.0, 5000.0);
    private const float32 k_LateGape = 0.8f;
    private const float32 k_HoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MimicRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MimicFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMimic(Make_RowSpec());
        WaitUntil(n"Is_DisguisedAndQuiet", n"OnServerQuiet", k_SlowPolls);
    }

    // Its behaviour reads Disguised (the state's own requests were issued) and the drain has taken them.
    UFUNCTION()
    private void Is_DisguisedAndQuiet(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && _Mimic.Get_BehaviorStateClass() == UMars_SmState_PickleMimic_Disguised
            && _Mimic.Has_Fragment(FMars_Fragment_PickleMimic_Requests) == false);
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, n"OnServerStand");
    }

    UFUNCTION()
    private void OnServerStand(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Mimic.Request_SetStance(FMars_Request_PickleMimic_SetStance(EMars_PickleMimic_Stance::Standing));
        _Mimic.Request_Gape(FMars_Request_PickleMimic_Gape(k_LateGape));
        WaitSampling(k_HoldSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Mimic.Get_IsStanding(), "the server's mimic stands");
        Assert_True(Get_HasMimicLedger(), "the server's mimic has its ledger");
        const auto Ledger = Get_MimicLedger();
        Assert_True(Ledger.Stance == EMars_PickleMimic_Stance::Standing, "the server's ledger reads Standing");
        Assert_True(Math::IsNearlyEqual(Ledger.Gape, k_LateGape, 0.0001f), "the server's ledger reads a gape of 0.8");
        Hold_MimicServerRow("ALateBinderSeesAStandingMimic", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_MimicStanding", n"OnClientStanding", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Math::IsNearlyEqual(_Mimic.Get_Rise(), 1.0f, 0.0001f), "the client's mimic is fully up");
        const auto Lid = _Mimic.Get_LidOpen();
        Assert_True(Math::Abs(Lid - k_LateGape) <= 0.05f, f"the client's lid is within 0.05 of 0.8 (reads {Lid})");
        Assert_True(Get_HasMimicLedger(), "the client's copy has its ledger");
        const auto Ledger = Get_MimicLedger();
        Assert_True(Ledger.Stance == EMars_PickleMimic_Stance::Standing, "the client's ledger reads Standing");
        Assert_True(Math::IsNearlyEqual(Ledger.Gape, k_LateGape, 0.0001f), "the client's ledger reads a gape of 0.8");
        Assert_True(_MimicStandingStances <= 1, "the client raised OnStance(Standing) at most once");
        Finish_MimicRow("ALateBinderSeesAStandingMimic", f"path={_MimicStandingStances}");
    }
}
