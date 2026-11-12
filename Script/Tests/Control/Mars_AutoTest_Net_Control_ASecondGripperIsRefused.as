// A stand-in holds the grip on the server; the client then grips its copy through an interaction. The authority refuses
// it: the refusal serial advances once and names the subject on both machines, the client raises OnGripRefused once,
// its local grip ends, its interaction ends Failed and its handle comes back to rest; the stand-in still holds the grip.
// Surface: Ck.Control.Net.AS_Control_ASecondGripperIsRefused
class UCk_AutoTest_Net_Control_ASecondGripperIsRefused : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(129000.0, 0.0, 5000.0);

    private bool _GrippedLocally = false;

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
        WaitUntil(n"Is_GrippedByStandIn", n"OnClientSawStandIn", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSawStandIn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_GripBeganOrRefused", n"OnClientGripAsked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_GripBeganOrRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (_Control.Get_IsManipulating())
        { _GrippedLocally = true; }

        auto Result = OutResult;
        Result.Set(_GrippedLocally || _GripRefusals.Num() > 0);
    }

    UFUNCTION()
    private void OnClientGripAsked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_RefusedAndAtRest", n"OnClientLetGo", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RefusedAndAtRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_GripRefusals.Num() > 0 && _FinishedResults.Num() > 0 && _Control.Get_IsManipulating() == false
            && ck::IsValid(_Mover) && _Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void OnClientLetGo(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Refused = _GripRefusals.Num() > 0 ? _GripRefusals[0] : FCk_Handle();
        const auto Result = _FinishedResults.Num() > 0 ? _FinishedResults[0] : ECk_SucceededFailed::Succeeded;
        Log(f"[ControlNetTest] ASecondGripperIsRefused client: grippedLocally {_GrippedLocally}, refusalsRaised {_GripRefusals.Num()} first {Get_WhoText(Refused)}, finished {_FinishedResults.Num()} first {Result :n}, manipulating {_Control.Get_IsManipulating()}, mover {_Mover.Get_Alpha()}, {Get_GripText(_Control)}, engagements {Get_Engagements()}, ensures {Get_NewEnsures()}");
        Assert_True(_GripRefusals.Num() == 1 && Refused == Get_SubjectEntity(), f"OnGripRefused fired once, naming the subject (got {_GripRefusals.Num()}, {Get_WhoText(Refused)})");
        Assert_True(_Control.Get_RefusalSerial() == 1 && _Control.Get_LastRefused() == Get_SubjectEntity(),
            f"the client's ledger counts one refusal naming the subject (got {_Control.Get_RefusalSerial()}, {Get_WhoText(_Control.Get_LastRefused())})");
        Assert_True(_Control.Get_Gripper() == _StandIn, f"the stand-in still holds the grip (got {Get_WhoText(_Control.Get_Gripper())})");
        Assert_False(_Control.Get_IsManipulating(), "the client's local grip ended");
        Assert_True(_FinishedResults.Num() == 1 && Result == ECk_SucceededFailed::Failed, f"the client's interaction ended Failed once (got {_FinishedResults.Num()}, {Result :n})");
        Assert_True(_Mover.Get_Alpha() < 0.01f, f"the client's handle is back at rest (got {_Mover.Get_Alpha()})");
        Assert_True(Get_Engagements() == 0, f"nothing engaged (got {Get_Engagements()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
        WaitUntil(n"Is_LeverAndStandInFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_LeverAndStandInFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsControlFound(n"TAG_MarsLever") && Get_IsStandInFound());
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        WaitUntil(n"Is_Refused", n"OnServerRefused", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerRefused(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] ASecondGripperIsRefused server: {Get_GripText(_Control)}, engagements {Get_Engagements()}, ensures {Get_NewEnsures()}");
        Assert_True(_Control.Get_RefusalSerial() == 1 && _Control.Get_LastRefused() == Get_SubjectEntity(),
            f"the server refused the subject once (got {_Control.Get_RefusalSerial()}, {Get_WhoText(_Control.Get_LastRefused())})");
        Assert_True(_Control.Get_Gripper() == _StandIn && _Control.Get_GripSerial() == 1,
            f"the stand-in still holds the one granted grip (got {Get_WhoText(_Control.Get_Gripper())}, serial {_Control.Get_GripSerial()})");
        Assert_True(Get_Engagements() == 0, f"nothing engaged (got {Get_Engagements()})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
