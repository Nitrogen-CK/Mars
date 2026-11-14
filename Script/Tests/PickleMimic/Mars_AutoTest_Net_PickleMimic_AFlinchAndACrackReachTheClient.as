// A standing Pickle Mimic takes a zone hit of 50 on the server: it flinches once there (found Standing, its body Health
// 70) and its glass cracks (stage 1); the client's copy reads the flinch from the ledger (count 1, found Standing),
// flinches on its own clock and stops, its body Health reading 70, and derives the same crack stage from it.
// Surface: Ck.PickleMimic.Net.AS_PickleMimic_AFlinchAndACrackReachTheClient
class UCk_AutoTest_Net_PickleMimic_AFlinchAndACrackReachTheClient : UMars_AutoTestRig_NetPickleMimic
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(614000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(380.0, 0.0, 0.0);
    private const float32 k_ZoneHit = 50.0f;
    private const float32 k_StruckBody = 70.0f;
    private const int32 k_StruckCrack = 1;

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
        WaitUntil(n"Is_MimicSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MimicStanding", n"OnServerStanding", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hit_MimicZone(k_ZoneHit);
        const auto Line = f"[PickleMimicNetTest] AFlinchAndACrackReachTheClient server hit frame={utils_time::Get_FrameCounter()}";
        Log(Line);
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Hurt = _Mimic.Get_Hurt();
        Assert_Equals_Int(Hurt.FlinchCount, 1, "the server's mimic flinched once");
        Assert_True(Hurt.FlinchFoundIn == EMars_PickleMimic_Stance::Standing, "the server's flinch found the mimic standing");
        Assert_Equals_Float(_Health.Get_Current(), k_StruckBody, 0.01f, "the server's body Health reads 70");
        Assert_Equals_Int(_Mimic.Get_CrackStage(), k_StruckCrack, "the server's glass is cracked (stage 1)");
        Hold_MimicServerRow("AFlinchAndACrackReachTheClient", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientFlinched", n"OnClientFlinched", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientFlinched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_IsMimicGone() == false && _Mimic.Get_Hurt().FlinchCount == 1);
    }

    UFUNCTION()
    private void OnClientFlinched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[PickleMimicNetTest] AFlinchAndACrackReachTheClient client flinch frame={utils_time::Get_FrameCounter()}";
        Log(Line);
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Hurt = _Mimic.Get_Hurt();
        Assert_Equals_Int(Hurt.FlinchCount, 1, "the client's copy reads one flinch");
        Assert_True(Hurt.FlinchFoundIn == EMars_PickleMimic_Stance::Standing, "the client's flinch found the mimic standing");
        Assert_True(_MimicEverFlinched, "the client's copy read flinching");
        Assert_False(_Mimic.Get_IsFlinching(), "the client's copy no longer flinches");
        Assert_Equals_Float(_Health.Get_Current(), k_StruckBody, 0.01f, "the client's body Health reads 70");
        Assert_Equals_Int(_Mimic.Get_CrackStage(), k_StruckCrack, "the client's glass is cracked (stage 1)");
        Finish_MimicRow("AFlinchAndACrackReachTheClient", "");
    }
}
