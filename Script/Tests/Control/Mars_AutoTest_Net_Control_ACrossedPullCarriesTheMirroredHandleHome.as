// The server's subject grips a replicated lever and pulls it steadily past the threshold. The client's handle follows the
// pull, and from the first frame the client sees the grip released or the engagement counted until its handle reaches the
// end pose, its alpha never decreases: it never moves back toward rest on the way home.
// Surface: Ck.Control.Net.AS_Control_ACrossedPullCarriesTheMirroredHandleHome
class UCk_AutoTest_Net_Control_ACrossedPullCarriesTheMirroredHandleHome : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(146000.0, 0.0, 5000.0);
    private const float32 k_SteadyNudgeDegrees = 1.0f;
    // Below this a frame-to-frame change is float noise, not a step back.
    private const float32 k_DecreaseTolerance = 0.001f;

    private float32 _MaxMirroredAlpha = 0.0f;
    private bool _SawEnd = false;
    private int32 _FramesAfterRelease = 0;
    private float32 _AlphaAtRelease = -1.0f;
    private float32 _LargestDecrease = 0.0f;
    private TOptional<float32> _PreviousAlpha;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();
        _PullDegrees = k_SteadyNudgeDegrees;

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
        WaitUntil(n"Is_ClientCarriedHome", n"OnClientHome", k_SlowPolls);
    }

    // Client, every frame: the mirrored follow, then from the release on, every step of the handle until the end pose.
    UFUNCTION()
    private void Is_ClientCarriedHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Mirrored = _Control.TryGet_MirroredGripAlpha();
        if (Mirrored.IsSet())
        { _MaxMirroredAlpha = Math::Max(_MaxMirroredAlpha, Mirrored.GetValue()); }

        const auto Alpha = _Mover.Get_Alpha();
        const auto Released = (_Control.Get_GripSerial() >= 1 && _Control.Get_IsGripped() == false) || Get_Engagements() >= 1;
        if (Released)
        {
            if (_PreviousAlpha.IsSet())
            { _LargestDecrease = Math::Max(_LargestDecrease, _PreviousAlpha.GetValue() - Alpha); }
            else
            { _AlphaAtRelease = Alpha; }

            _FramesAfterRelease += 1;
            _PreviousAlpha = Alpha;
        }

        _SawEnd = Alpha > 0.99f;

        auto Result = OutResult;
        Result.Set(Released && _SawEnd);
    }

    UFUNCTION()
    private void OnClientHome(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EngagedOnce", n"OnClientEngaged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ACrossedPullCarriesTheMirroredHandleHome client: maxMirroredAlpha {_MaxMirroredAlpha :.3}, alphaAtRelease {_AlphaAtRelease :.3}, framesAfterRelease {_FramesAfterRelease}, largestDecrease {_LargestDecrease :.4}, release {_Control.Get_LastGripRelease() :n}, engagements {Get_Engagements()}, active {_Control.Get_IsActive()}, {Get_PullText()}, ensures {Get_NewEnsures()}");
        Assert_True(_MaxMirroredAlpha > 0.2f, f"the client's handle followed the host's pull (got {_MaxMirroredAlpha})");
        Assert_True(_LargestDecrease <= k_DecreaseTolerance, f"the handle never moved back toward rest between the release and the end (largest step back {_LargestDecrease})");
        Assert_True(_SawEnd, "the handle reached the end pose");
        Assert_True(Get_Engagements() == 1 && _Control.Get_IsActive(), "the lever engaged once and is active");
        Assert_True(_Control.Get_LastGripRelease() == EMars_Control_GripRelease::Crossed, "the grip was released as a crossing");
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
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnServerInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_GrippedBySubject", n"OnServerGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_PulledUntilEnded", n"OnServerCrossed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EngagedOnce", n"OnServerEngaged", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEngaged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds * 2.0f, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ACrossedPullCarriesTheMirroredHandleHome server: engagements {Get_Engagements()}, active {_Control.Get_IsActive()}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_LastGripRelease() == EMars_Control_GripRelease::Crossed, "the crossing released the grip as Crossed");
        Assert_True(Get_Engagements() == 1, f"the host's pull engaged once (got {Get_Engagements()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
