// A risen Root Maw takes a zone hit of 10 on the server: it flinches once there (its body Health 130), and the client's
// copy reads the flinch from the ledger (count 1, found Emerged), flinches on its own clock and stops, its body Health
// reading 130.
// Surface: Ck.RootMaw.Net.AS_RootMaw_AFlinchReachesTheClient
class UCk_AutoTest_Net_RootMaw_AFlinchReachesTheClient : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(581000.0, 0.0, 5000.0);
    private const FVector k_PreyOffset = FVector(400.0, 0.0, 0.0);
    private const float32 k_ZoneHit = 10.0f;
    private const float32 k_StruckBody = 130.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMawFloor();
        Spawn_ServerMaw(FMars_RootMaw_Spec());
        WaitUntil(n"Is_MawStanding", n"OnServerGrounded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGrounded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_StandSeconds, n"OnServerStands");
    }

    UFUNCTION()
    private void OnServerStands(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerPrey(k_PreyOffset);
        WaitUntil(n"Is_MawEmerged", n"OnServerEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Hit_MawZone(k_ZoneHit);
        const auto Line = f"[RootMawNetTest] AFlinchReachesTheClient server hit frame={utils_time::Get_FrameCounter()}";
        Log(Line);
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_Maw.Get_Hurt().FlinchCount, 1, "the server's Maw flinched once");
        Assert_Equals_Float(_Health.Get_Current(), k_StruckBody, 0.01f, "the server's body Health reads 130");
        Hold_MawServerRow("AFlinchReachesTheClient", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientFlinched", n"OnClientFlinched", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientFlinched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawGone() == false && _Maw.Get_Hurt().FlinchCount == 1);
    }

    UFUNCTION()
    private void OnClientFlinched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[RootMawNetTest] AFlinchReachesTheClient client flinch frame={utils_time::Get_FrameCounter()}";
        Log(Line);
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Hurt = _Maw.Get_Hurt();
        Assert_Equals_Int(Hurt.FlinchCount, 1, "the client's copy reads one flinch");
        Assert_True(Hurt.FlinchFoundIn == EMars_RootMaw_Stance::Emerged, "the client's flinch found the Maw emerged");
        Assert_True(_MawEverFlinched, "the client's copy read flinching");
        Assert_False(_Maw.Get_IsFlinching(), "the client's copy no longer flinches");
        Assert_Equals_Float(_Health.Get_Current(), k_StruckBody, 0.01f, "the client's body Health reads 130");
        Finish_MawRow("AFlinchReachesTheClient", "");
    }
}
