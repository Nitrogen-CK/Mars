// The client grips its copy of a replicated lever, pulls it about halfway and lets go: its handle settles back to rest,
// and after a hold the server's ledger is untouched.
// Surface: Ck.Control.Net.AS_Control_AClientLetsGoBeforeTheThreshold
class UCk_AutoTest_Net_Control_AClientLetsGoBeforeTheThreshold : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(119000.0, 0.0, 5000.0);
    // 25 degrees at 0.02 alpha per degree: a pull to 0.5, short of the 0.85 threshold.
    private const float32 k_HalfPullDegrees = 25.0f;
    private const float32 k_HalfAlpha = 0.4f;
    private const float32 k_ServerWindowSeconds = 6.0f;

    private float32 _AlphaAtRelease = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_LeverFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_Manipulating", n"OnClientGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_Nudge(FMars_Request_Control_Nudge(k_HalfPullDegrees));
        WaitUntil(n"Is_AboutHalfway", n"OnClientHalfway", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_AboutHalfway(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_HandleAlpha() >= k_HalfAlpha);
    }

    UFUNCTION()
    private void OnClientHalfway(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _AlphaAtRelease = Get_HandleAlpha();
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        WaitUntil(n"Is_HandleAtRest", n"OnClientAtRest", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAtRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientLetsGoBeforeTheThreshold client: alphaAtRelease {_AlphaAtRelease}, mover {_Mover.Get_Alpha()}, manipulating {_Control.Get_IsManipulating()}, active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, ensures {Get_NewEnsures()}");
        Assert_True(_AlphaAtRelease >= k_HalfAlpha && _AlphaAtRelease < 0.85f, f"the client's handle was about halfway when it let go (got {_AlphaAtRelease})");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the client's handle settled to rest (got {_Mover.Get_Alpha()})");
        Assert_True(_EngagedCount == 0 && Get_Engagements() == 0, f"nothing engaged on the client (got {_EngagedCount}, {Get_Engagements()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
        WaitUntil(n"Is_LeverFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AClientLetsGoBeforeTheThreshold server: active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, mover {_Mover.Get_Alpha()}, ensures {Get_NewEnsures()}");
        Assert_False(_Control.Get_IsActive(), "the server's lever stayed inactive");
        Assert_True(Get_Engagements() == 0 && _EngagedCount == 0, f"the server counted no engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the server's handle never moved (got {_Mover.Get_Alpha()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
