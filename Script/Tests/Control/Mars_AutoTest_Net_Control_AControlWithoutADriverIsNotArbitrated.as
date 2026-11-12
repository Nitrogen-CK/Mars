// On the server, a Control on a scene node of a replicated root (no replication driver of its own) is gripped, claimed
// directly and pulled past its threshold, then engaged twice: both engages apply as they always did, and
// its grip ledger stays Released with serial 0.
// Surface: Ck.Control.Net.AS_Control_AControlWithoutADriverIsNotArbitrated
class UCk_AutoTest_Net_Control_AControlWithoutADriverIsNotArbitrated : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(136000.0, 0.0, 5000.0);
    private const float32 k_ClientWindowSeconds = 1.0f;

    private FCk_Handle_Control _NodeControl;
    private bool _Arbitrated = true;
    private bool _CrossedWithoutClaim = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_NodeControlFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_NodeControlFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::IsValid(_NodeControl))
        {
            Result.Set(true);
            return;
        }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetNodeControl"))
        {
            auto Control = Candidate.As_Control(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Control))
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Control.As_Transform()).GetLocation();
            if ((Location - k_Location).Size() > 10.0)
            { continue; }

            _NodeControl = Control;
            if (Get_IsServer())
            { Track_ForCleanup(utils_entity_lifetime::Get_LifetimeOwner(Candidate)); }

            Result.Set(true);
            return;
        }

        Result.Set(false);
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClientWindowSeconds, n"OnClientWindowOver");
    }

    UFUNCTION()
    private void OnClientWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AControlWithoutADriverIsNotArbitrated client: arbitrated {_NodeControl.Get_IsGripArbitrated()}, {Get_GripText(_NodeControl)}, ensures {Get_NewEnsures()}");
        Assert_False(_NodeControl.Get_IsGripArbitrated(), "the client's node control is not arbitrated");
        Assert_True(_NodeControl.Get_GripSerial() == 0 && _NodeControl.Get_IsGripped() == false, "the client's grip ledger stays Released with serial 0");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetNodeControlApart_EntityScript, FInstancedStruct());
        WaitUntil(n"Is_NodeControlFound", n"OnServerFound", k_SlowPolls);
    }

    // The old path: a grip with no interaction, a direct claim beside it, and the pull in the same drain.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Arbitrated = _NodeControl.Get_IsGripArbitrated();
        _NodeControl.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
        _NodeControl.Request_Grip(FMars_Request_Control_Grip(Get_SubjectEntity(), EMars_Control_GripVerb::Begin));
        _NodeControl.Request_Nudge(FMars_Request_Control_Nudge(60.0f));
        WaitUntil(n"Is_NodeGripped", n"OnServerGripped", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_NodeGripped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_NodeControl.Get_IsManipulating());
    }

    UFUNCTION()
    private void OnServerGripped(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_NodeCrossed", n"OnServerCrossed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_NodeCrossed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_NodeControl.Get_IsManipulating() == false);
    }

    UFUNCTION()
    private void OnServerCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _CrossedWithoutClaim = _NodeControl.Get_GripSerial() == 0;
        _NodeControl.Request_Engage(FMars_Request_Control_Engage());
        WaitFrames(2, n"OnServerFirstEngage");
    }

    UFUNCTION()
    private void OnServerFirstEngage(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _NodeControl.Request_Engage(FMars_Request_Control_Engage());
        WaitSeconds(k_SettleSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Engagements = _NodeControl.Get_Fragment(FMars_Fragment_Control).Engagements;
        Log(f"[ControlNetTest] AControlWithoutADriverIsNotArbitrated server: arbitrated {_Arbitrated}, crossedWithoutClaim {_CrossedWithoutClaim}, engagements {Engagements}, active {_NodeControl.Get_IsActive()}, {Get_GripText(_NodeControl)}, ensures {Get_NewEnsures()}");
        Assert_False(_Arbitrated, "the node control is not arbitrated");
        Assert_True(_CrossedWithoutClaim, "the grip crossed its threshold with no claim recorded");
        Assert_True(Engagements == 2, f"both engages applied as before (got {Engagements})");
        Assert_True(_NodeControl.Get_GripSerial() == 0 && _NodeControl.Get_IsGripped() == false && _NodeControl.Get_RefusalSerial() == 0,
            "the grip ledger stays Released with serial 0");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
