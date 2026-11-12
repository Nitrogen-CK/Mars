// A Control composed on a scene node of a replicated root has no replication driver of its own: on the client its
// BeginManipulation is dropped, as it always was, so it is never manipulated and nothing ensures.
// Surface: Ck.Control.Net.AS_Control_AControlWithoutADriverKeepsItsRule
class UCk_AutoTest_Net_Control_AControlWithoutADriverKeepsItsRule : UMars_AutoTestRig_NetControl
{
    private const float32 k_ClientWindowSeconds = 1.0f;
    private const float32 k_ServerWindowSeconds = 4.0f;

    private FCk_Handle_Control _NodeControl;
    private bool _HasDriver = false;

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
        _HasDriver = utils_entity_replication_driver::Has(_NodeControl);
        _NodeControl.Request_BeginManipulation(FMars_Request_Control_BeginManipulation());
        WaitSeconds(k_ClientWindowSeconds, n"OnClientWindowOver");
    }

    UFUNCTION()
    private void OnClientWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AControlWithoutADriverKeepsItsRule client: authority {utils_net::Get_HasAuthority(_NodeControl)}, hasDriver {_HasDriver}, manipulating {_NodeControl.Get_IsManipulating()}, ensures {Get_NewEnsures()}");
        Assert_False(utils_net::Get_HasAuthority(_NodeControl), "the client's node control has no authority");
        Assert_False(_HasDriver, "the client's node control has no replication driver");
        Assert_False(_NodeControl.Get_IsManipulating(), "the client's BeginManipulation was dropped");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetNodeControl_EntityScript, FInstancedStruct());
        WaitUntil(n"Is_NodeControlFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerWindowSeconds, n"OnServerWindowOver");
    }

    UFUNCTION()
    private void OnServerWindowOver(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AControlWithoutADriverKeepsItsRule server: manipulating {_NodeControl.Get_IsManipulating()}, ensures {Get_NewEnsures()}");
        Assert_False(_NodeControl.Get_IsManipulating(), "the server's node control was never gripped");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
