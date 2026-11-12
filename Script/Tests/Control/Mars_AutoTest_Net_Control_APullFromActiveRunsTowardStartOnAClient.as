// The server places the lever active. The client's copy mirrors it, so its grip runs toward the start pose; crossing
// the threshold that way engages the lever off on both machines, and the client's handle comes to rest at the start pose.
// Surface: Ck.Control.Net.AS_Control_APullFromActiveRunsTowardStartOnAClient
class UCk_AutoTest_Net_Control_APullFromActiveRunsTowardStartOnAClient : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(120000.0, 0.0, 5000.0);

    private EMars_Control_PullDirection _DirectionAtGrip = EMars_Control_PullDirection::TowardEnd;
    private float32 _AlphaAtGrip = 0.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();
        _PullDegrees = -4.0f;

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ActiveLeverFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The client's copy mirrors the active start and its handle stands at the end pose.
    UFUNCTION()
    private void Is_ActiveLeverFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsControlFound(n"TAG_MarsLever") && _Control.Get_IsActive() && ck::IsValid(_Mover) && _Mover.Get_Alpha() > 0.99f);
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
        _DirectionAtGrip = _Control.Get_PullDirection();
        _AlphaAtGrip = Get_HandleAlpha();
        WaitUntil(n"Is_PulledUntilEnded", n"OnClientCrossed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_InactiveOnceAndHandleAtStart", n"OnClientConverged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_InactiveOnceAndHandleAtStart(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_IsActive() == false && Get_Engagements() == 1 && _Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void OnClientConverged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] APullFromActiveRunsTowardStartOnAClient client: directionAtGrip {_DirectionAtGrip :n}, alphaAtGrip {_AlphaAtGrip}, travelBeforeEngage {_MaxAlphaBeforeEngage}, active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, activations [{Get_ActivationsText()}], mover {_Mover.Get_Alpha()}, ensures {Get_NewEnsures()}");
        Assert_True(_DirectionAtGrip == EMars_Control_PullDirection::TowardStart, f"the client's pull runs toward the start pose (got {_DirectionAtGrip :n})");
        Assert_True(_AlphaAtGrip > 0.99f, f"the client's grip seeded at the end pose (got {_AlphaAtGrip})");
        Assert_True(_MaxAlphaBeforeEngage >= 0.85f, f"the client's handle travelled to the threshold before any engagement replicated (got {_MaxAlphaBeforeEngage})");
        Assert_True(_EngagedCount == 1, f"OnEngaged fired once on the client (got {_EngagedCount})");
        Assert_True(_Activations.Num() == 1 && _Activations[0] == EMars_Control_Activation::Inactive,
            f"the client saw the lever go inactive once (got [{Get_ActivationsText()}])");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Active);
        WaitUntil(n"Is_LeverFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Control.Get_IsActive(), "the server's lever starts active");
        WaitUntil(n"Is_EngagedOnce", n"OnServerEngaged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] APullFromActiveRunsTowardStartOnAClient server: active {_Control.Get_IsActive()}, engagements {Get_Engagements()}, onEngaged {_EngagedCount}, activations [{Get_ActivationsText()}], mover {_Mover.Get_Alpha()}, ensures {Get_NewEnsures()}");
        Assert_False(_Control.Get_IsActive(), "the server's lever engaged off");
        Assert_True(Get_Engagements() == 1 && _EngagedCount == 1, f"the server counts one engagement (got {Get_Engagements()}, {_EngagedCount})");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the server's handle travelled to the start pose (got {_Mover.Get_Alpha()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
