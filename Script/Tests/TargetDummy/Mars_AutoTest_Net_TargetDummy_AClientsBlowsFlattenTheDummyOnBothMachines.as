// A client claims two cleaver blows 0.6 s apart on a 30 hit point dummy: the server applies both, and on both machines
// the dummy's Health reads depleted, OnDepleted is raised once and the body is flattened to 0.2.
// Surface: Ck.TargetDummy.Net.AS_TargetDummy_AClientsBlowsFlattenTheDummyOnBothMachines
class UCk_AutoTest_Net_TargetDummy_AClientsBlowsFlattenTheDummyOnBothMachines : UMars_AutoTestRig_NetTargetDummy
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(560000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsBlowsFlattenTheDummyOnBothMachines";
    private const float32 k_WatchSeconds = 2.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TargetDummy(k_Base, 30.0f, 30.0f);
        _DummyRowArms = ECk_EnableDisable::Enable;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientReadyToClaimDummy", n"OnClientReady", k_SlowPolls);
            return;
        }

        Start_ServerDummyRow();
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_DummyDepleted", n"OnServerDepleted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Tally(2, 0, TOptional<EMars_HeldItemUse_StrikeRefusal>());
        Assert_Equals_Int(_DummyDepleted, 1, "the server raised OnDepleted once");
        Assert_BodyHeight(k_FlattenedHeight, "the server");
        Hold_ServerDummyRow(k_Row, Describe_Distances(Get_DummyClaimLocation()));
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _FirstClaimFrame = int32(utils_time::Get_FrameCounter());
        Fire_Claim(Make_DummyClaim());
        WaitSeconds(k_ClaimSpacingSeconds, n"OnClientSecondClaim");
    }

    UFUNCTION()
    private void OnClientSecondClaim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SecondClaimFrame = int32(utils_time::Get_FrameCounter());
        Fire_Claim(Make_DummyClaim());
        WaitUntil(n"Is_DummyDepleted", n"OnClientDepleted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientDepleted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsCurrent(0.0f), "the client's dummy reads 0");
        Assert_True(_Health.Get_IsDepleted(), "the client's dummy reads depleted");
        Assert_True(_DummyDamaged >= 1, "the client raised OnDamaged at least once");
        Assert_Equals_Int(_DummyDepleted, 1, "the client raised OnDepleted exactly once");
        Assert_BodyHeight(k_FlattenedHeight, "the client");
        const auto Frames = _DepletedFrame - _SecondClaimFrame;
        Finish_DummyRow(k_Row, f"secondClaimToDepletedFrames={Frames}");
    }
}
