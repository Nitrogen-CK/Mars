// A risen Root Maw glides after prey that moved 1200 down +X on the server: the client's copy follows its replicated
// root without a jump (no step of 150 or more between two frames), ends where the server's does, and measures its own
// glide.
// Surface: Ck.RootMaw.Net.AS_RootMaw_TheClientsCopyFollowsTheGlide
class UCk_AutoTest_Net_RootMaw_TheClientsCopyFollowsTheGlide : UMars_AutoTestRig_NetRootMaw
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(572000.0, 0.0, 5000.0);
    private const FVector k_PreyWake = FVector(400.0, 0.0, 0.0);
    private const FVector k_PreyAfar = FVector(1200.0, 0.0, 0.0);
    private const float64 k_FarPast = 900.0;
    private const float64 k_EndMin = 950.0;
    private const float64 k_EndMax = 1400.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MawRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MawFarPast", n"OnClientFarPast", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_MawFarPast(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && Get_MawPastBase() > k_FarPast);
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
        Spawn_ServerPrey(k_PreyWake);
        WaitUntil(n"Is_MawEmerged", n"OnServerEmerged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEmerged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Move_ServerPrey(k_PreyAfar);
        WaitUntil(n"Is_MawFarPast", n"OnServerFarPast", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFarPast(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(2.0f, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Past = Get_MawPastBase();
        Assert_True(Past >= k_EndMin && Past <= k_EndMax, f"the server's root ends 950..1400 past the base (reads {Past})");
        Hold_MawServerRow("TheClientsCopyFollowsTheGlide", "");
    }

    UFUNCTION()
    private void OnClientFarPast(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Past = Get_MawPastBase();
        const auto Side = Math::Abs(_Maw.Get_Location().Y - _Base.Y);
        Assert_True(Past >= k_EndMin && Past <= k_EndMax, f"the client's root ends 950..1400 past the base (reads {Past})");
        Assert_True(Side <= 100.0, f"the client's root is within 100 of the base on Y (reads {Side})");
        Assert_True(_Maw.Get_DistanceTravelled() > 700.0, "the client's copy measured a glide of over 700");
        Assert_True(_MawLargestStep < 150.0, f"the client's root never stepped 150 or more (largest {_MawLargestStep})");
        Finish_MawRow("TheClientsCopyFollowsTheGlide", "");
    }
}
