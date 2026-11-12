// The server grants a stand-in a grip on a fresh lever and applies its report of about half in the same frame, as soon as
// the lever composes, so the client's copy binds while the stand-in holds the grip at that pull: the client's handle goes
// to that pull and stays there, moving by its spring from where its Mover stood, never in one jump.
// Surface: Ck.Control.Net.AS_Control_ALateBinderSeesTheHandleWhereItIs
class UCk_AutoTest_Net_Control_ALateBinderSeesTheHandleWhereItIs : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(147000.0, 0.0, 5000.0);
    // A frame-to-frame change this large is a jump, not a spring's step.
    private const float32 k_JumpAlpha = 0.25f;
    // Long enough for the client to bind, follow and finish.
    private const float32 k_HoldSeconds = 6.0f;

    private EMars_Control_Grip _GripAtBind = EMars_Control_Grip::Released;
    private float32 _PullAtBind = -1.0f;
    private float32 _AlphaAtBind = -1.0f;
    private float32 _LargestStep = 0.0f;
    private TOptional<float32> _PreviousAlpha;
    private float32 _SettledSeconds = 0.0f;

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
        _GripAtBind = _Control.Get_IsGripped() ? EMars_Control_Grip::Gripped : EMars_Control_Grip::Released;
        _PullAtBind = _Control.Get_GripPull();
        _AlphaAtBind = _Mover.Get_Alpha();
        WaitUntil(n"Is_ClientAtThePull", n"OnClientAtThePull", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientAtThePull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Track_Step();

        auto Result = OutResult;
        Result.Set(_Control.Get_Gripper() == _StandIn && Math::Abs(_Mover.Get_Alpha() - k_HalfPull) < k_FollowTolerance);
    }

    private void Track_Step()
    {
        Get_IsStandInFound();
        const auto Alpha = _Mover.Get_Alpha();
        if (_PreviousAlpha.IsSet())
        { _LargestStep = Math::Max(_LargestStep, Math::Abs(Alpha - _PreviousAlpha.GetValue())); }

        _PreviousAlpha = Alpha;
    }

    UFUNCTION()
    private void OnClientAtThePull(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientHeldAWhile", n"OnClientSettled", k_SlowPolls);
    }

    // Client: half a second more of steps, the handle staying at the pull.
    UFUNCTION()
    private void Is_ClientHeldAWhile(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Track_Step();
        _SettledSeconds += Get_FrameSeconds();

        auto Result = OutResult;
        Result.Set(_SettledSeconds >= k_SettleSeconds * 0.5f);
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ALateBinderSeesTheHandleWhereItIs client: gripAtBind {_GripAtBind :n}, pullAtBind {_PullAtBind :.3}, alphaAtBind {_AlphaAtBind :.3}, largestStep {_LargestStep :.4}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.TryGet_MirroredGripAlpha().IsSet(), "the client shows the stand-in's grip");
        Assert_True(Math::Abs(_Mover.Get_Alpha() - k_HalfPull) < k_FollowTolerance, f"the client's handle stands at the held pull (got {_Mover.Get_Alpha()})");
        Assert_True(_LargestStep < k_JumpAlpha, f"the handle moved there by steps, not a jump (largest step {_LargestStep})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        WaitUntil(n"Is_StandInFound", n"OnServerStandInFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerStandInFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
        WaitUntil(n"Is_LeverFound", n"OnServerFound", k_SlowPolls);
    }

    // The claim and its report in one frame: the report is read after the grant.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        _Control.Request_ReportPull(FMars_Request_Control_ReportPull(_StandIn, k_HalfPull));
        WaitUntil(n"Is_ServerHeldAtHalf", n"OnServerHeldAtHalf", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHeldAtHalf(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_Gripper() == _StandIn && Math::Abs(_Control.Get_GripPull() - k_HalfPull) < 0.0001f);
    }

    UFUNCTION()
    private void OnServerHeldAtHalf(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ALateBinderSeesTheHandleWhereItIs server: {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }
}
