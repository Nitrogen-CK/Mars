// A pendulum braked on the server before the client can look arrives caught: the client's swing holds at the catch
// angle, its pivot node shows that angle, and the server's rest disarmed the hazard on the client too.
// Surface: Ck.Hazard.Net.AS_Hazard_CaughtPendulumHoldsOnTheClientAndDisarms
class UCk_AutoTest_Net_Hazard_CaughtPendulumHoldsOnTheClientAndDisarms : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 12.0f;

    private const float32 k_ServerHoldSeconds = 2.0f;
    private const float32 k_CatchAngleDegrees = -20.0f;
    private const float32 k_AngleToleranceDegrees = 0.5f;
    private const int32 k_SlowPolls = 5000;

    // Far from anything else the harness world holds.
    private const float64 k_PendulumX = 12000.0;

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
            WaitUntil(n"Is_PendulumOnThisMachine", n"OnClientPendulumArrived", k_SlowPolls);
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
        Params.Oscillator.PeriodSeconds = 1.5f;
        Params.Oscillator.StartRunning = true;
        Params.Oscillator.CatchAngleDegrees = TOptional<float32>(k_CatchAngleDegrees);
        _PendingPendulum = utils_entity_script::Request_SpawnEntity(Owner, UMars_Pendulum_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(
            _PendingPendulum, FCk_Delegate_EntityScript_Constructed(this, n"OnServerPendulumConstructed"));
    }

    // Braked at once: the catch happens before the client can look.
    UFUNCTION()
    private void OnServerPendulumConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _PendingPendulum = FCk_Handle_PendingEntityScript();
        _Pendulum = FCk_Handle(InEntityScriptHandle).As_Pendulum();
        Track_ForCleanup(_Pendulum);

        auto Oscillator = _Pendulum.Get_Oscillator();
        Oscillator.Request_SetRunning(FMars_Request_Oscillator_SetRunning(EMars_Oscillator_RunState::Stopped));
        WaitUntil(n"Is_Caught", n"OnServerCaught", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_Caught(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Pendulum.Get_Oscillator().Get_IsCaught());
    }

    UFUNCTION()
    private void OnServerCaught(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_PendulumOnThisMachine(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Pendulum = DoFind_Pendulum();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Pendulum));
    }

    UFUNCTION()
    private void OnClientPendulumArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Pendulum), "the client's pendulum has no authority");
        WaitUntil(n"Is_ClientCaughtAndDisarmed", n"OnClientConverged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientCaughtAndDisarmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsHeldAtCatch() && _Pendulum.Get_Hazard().Get_IsArmed() == false);
    }

    UFUNCTION()
    private void OnClientConverged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // Caught at the catch angle, and the pivot node shows it: the Tick skips a caught swing, so the Align wrote the node.
    private bool Get_IsHeldAtCatch() const
    {
        const auto Oscillator = _Pendulum.Get_Oscillator();
        if (Oscillator.Get_IsCaught() == false)
        { return false; }

        const auto Angle = Oscillator.Get_Angle();
        if (Math::Abs(Angle - k_CatchAngleDegrees) >= k_AngleToleranceDegrees)
        { return false; }

        const auto& Params = Oscillator.Get_Fragment(FMars_Fragment_Oscillator_Params);
        const auto Expected = utils_oscillator::Make_NodeRotation(Params.RestRotation, Params.Axis, Angle);
        const auto Shown = utils_scene_node::Get_Offset_Rotation(Oscillator.As_SceneNode());
        return Shown.Equals(Expected, 0.1f);
    }

    private FCk_Handle_Pendulum DoFind_Pendulum()
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsPendulum"))
        { return Candidate.As_Pendulum(ECk_SanityCheck::UnChecked); }

        return FCk_Handle_Pendulum();
    }
}
