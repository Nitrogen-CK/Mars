// A swinging pendulum's phase is the server's: on the server the anchor advanced by the server clock matches its own
// swing, and the client's swing follows that anchor within the phase tolerance.
// Surface: Ck.Hazard.Net.AS_Hazard_PendulumPhaseFollowsTheServerAnchor
class UCk_AutoTest_Net_Hazard_PendulumPhaseFollowsTheServerAnchor : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 12.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const float32 k_ServerSwingSeconds = 1.0f;
    private const float32 k_ClientSettleSeconds = 0.5f;
    private const float32 k_ServerToleranceSeconds = 0.05f;
    private const float32 k_ClientToleranceSeconds = 0.06f;
    private const int32 k_SlowPolls = 5000;

    // Far from anything else the harness world holds.
    private const float64 k_PendulumX = 11000.0;

    private FCk_Handle_PendingEntityScript _PendingPendulum;
    private FCk_Handle_Pendulum _Pendulum;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_PendulumAnchoredOnThisMachine", n"OnClientAnchored", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Params = UMars_Pendulum_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, FVector(k_PendulumX, 0.0, 0.0));
        Params.Oscillator.AmplitudeDegrees = 30.0f;
        Params.Oscillator.PeriodSeconds = 2.0f;
        Params.Oscillator.SettleSeconds = 0.0f;
        Params.Oscillator.StartRunning = true;
        _PendingPendulum = utils_entity_script::Request_SpawnEntity(Owner, UMars_Pendulum_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingPendulum, FCk_Delegate_EntityScript_Constructed(this, n"OnServerPendulumConstructed"));
    }

    UFUNCTION()
    private void OnServerPendulumConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingPendulum = FCk_Handle_PendingEntityScript();
        _Pendulum = FCk_Handle(InEntityScriptHandle).As_Pendulum();
        Track_ForCleanup(_Pendulum);
        WaitSeconds(k_ServerSwingSeconds, n"OnServerSwung");
    }

    UFUNCTION()
    private void OnServerSwung(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Error = Get_PhaseError();
        Log(f"[MarsNet] pendulum phase error on the server: {Error} s");
        Assert_True(Math::Abs(Error) < k_ServerToleranceSeconds,
            f"the server's anchor agrees with its own swing (error [{Error}] s)");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_PendulumAnchoredOnThisMachine(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Pendulum = DoFind_Pendulum();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Pendulum) && _Pendulum.Get_Fragment(FMars_Fragment_Pendulum).Anchors > 0);
    }

    UFUNCTION()
    private void OnClientAnchored(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Pendulum), "the client's pendulum has no authority");
        WaitSeconds(k_ClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Error = Get_PhaseError();
        Log(f"[MarsNet] pendulum phase error on the client: {Error} s");
        Assert_True(Math::Abs(Error) < k_ClientToleranceSeconds,
            f"the client's swing follows the server's anchor (error [{Error}] s)");
        FinishSuccess();
    }

    private float32 Get_PhaseError() const
    {
        const auto Oscillator = _Pendulum.Get_Oscillator();
        const auto Period = Oscillator.Get_Fragment(FMars_Fragment_Oscillator_Params).PeriodSeconds;
        return utils_oscillator::Get_PhaseError(_Pendulum.Get_AnchoredSample().Time, Oscillator.Get_Sample().Time, Period);
    }

    private FCk_Handle_Pendulum DoFind_Pendulum()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsPendulum"))
        { return Candidate.As_Pendulum(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Pendulum();
    }
}
