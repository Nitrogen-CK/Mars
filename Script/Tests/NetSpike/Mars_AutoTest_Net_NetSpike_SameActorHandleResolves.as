// Probe A of the handle spike: a replicated fragment on A holds a handle to B, and A and B both replicate under the spawn
// owner (the same relay actor). The server spawns both, waits for both to construct, then writes the handle. The client
// records, at every notify and every frame for a bounded window, whether the handle is valid and names its own copy of B.
// It passes by recording: it logs one [NetSpike] A line and asserts only that it ran to the end.
// Surface: Ck.NetSpike.Net.AS_NetSpike_SameActorHandleResolves
class UCk_AutoTest_Net_NetSpike_SameActorHandleResolves : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const int32 k_PayloadA = 3101;
    private const int32 k_PayloadB = 3102;
    private const float32 k_ServerHoldSeconds = 4.0f;
    private const int32 k_SlowPolls = 5000;
    // Frames the client keeps watching once the write arrived (3 s at the pinned 60 fps).
    private const int32 k_WatchFrames = 180;
    // Frames the client waits for the write at all before it records what it has.
    private const int32 k_MaxFrames = 720;

    private FCk_Handle _A;
    private FCk_Handle _B;
    private int32 _Constructed = 0;

    private int32 _Frame = 0;
    private int32 _Notifies = 0;
    private TOptional<int32> _WriteSeenFrame;
    private TOptional<int32> _FirstValidFrame;
    private TOptional<bool> _ValidAtFirstNotify;
    private bool _ArrivedBeforeBind = false;
    private bool _ValidByPollOnly = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_AOnClient", n"OnClientAArrived", k_SlowPolls);
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

        auto BParams = FMars_NetSpike_SpawnParams(FVector(14000.0, 0.0, 0.0), k_PayloadB);
        auto PendingB = utils_entity_script::Request_SpawnEntity(Owner, UMars_NetSpike_EntityScript, BParams);
        utils_pending_entity_script::Promise_OnConstructed(PendingB, FCk_Delegate_EntityScript_Constructed(this, n"OnServerBConstructed"));

        auto AParams = FMars_NetSpike_SpawnParams(FVector(14000.0, 300.0, 0.0), k_PayloadA);
        AParams.WithRef = true;
        auto PendingA = utils_entity_script::Request_SpawnEntity(Owner, UMars_NetSpike_EntityScript, AParams);
        utils_pending_entity_script::Promise_OnConstructed(PendingA, FCk_Delegate_EntityScript_Constructed(this, n"OnServerAConstructed"));
    }

    UFUNCTION()
    private void OnServerBConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _B = FCk_Handle(InEntityScriptHandle);
        Track_ForCleanup(_B);
        OnServerOneConstructed();
    }

    UFUNCTION()
    private void OnServerAConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _A = FCk_Handle(InEntityScriptHandle);
        Track_ForCleanup(_A);
        OnServerOneConstructed();
    }

    private void OnServerOneConstructed()
    {
        _Constructed += 1;
        if (_Constructed < 2)
        { return; }

        auto& Ref = _A.Get_Fragment(FMars_Fragment_NetSpike_Ref);
        Ref.Target = _B;
        Ref.Serial = 1;
        _A.Request_MarkReplicationDirty(FMars_Fragment_NetSpike_Ref);

        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_AOnClient(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto A = utils_net_spike::Find(Get_SubjectEntity(), k_PayloadA);
        Result.Set(ck::IsValid(A) && A.Has_Fragment(FMars_Fragment_NetSpike_Ref));
    }

    UFUNCTION()
    private void OnClientAArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _A = utils_net_spike::Find(Get_SubjectEntity(), k_PayloadA);
        if (ck::Is_NOT_Valid(_A))
        { FinishFailure("A left the client between the poll and the bind"); return; }

        _A.BindTo_OnRepNotify(FMars_Fragment_NetSpike_Ref, FCk_DynamicFragment_OnRepNotify(this, n"OnRefNotify"));
        _ArrivedBeforeBind = Get_Ref().Serial == 1;
        WaitUntil(n"Poll_Client", n"OnClientWatched", k_MaxFrames + k_WatchFrames + 10);
    }

    UFUNCTION()
    private void OnRefNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        _Notifies += 1;
        if (Get_Ref().Serial != 1 || _ValidAtFirstNotify.IsSet())
        { return; }

        _ValidAtFirstNotify = TOptional<bool>(Get_IsTargetB());
    }

    // One call per frame: records the frame the write arrived and the first frame its handle named B.
    UFUNCTION()
    private void Poll_Client(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Frame += 1;
        if (Get_Ref().Serial == 1 && _WriteSeenFrame.IsSet() == false)
        { _WriteSeenFrame = TOptional<int32>(_Frame); }

        if (_WriteSeenFrame.IsSet() && _FirstValidFrame.IsSet() == false && Get_IsTargetB())
        {
            _FirstValidFrame = TOptional<int32>(_Frame);
            _ValidByPollOnly = _ValidAtFirstNotify.IsSet() == false || _ValidAtFirstNotify.GetValue() == false;
        }

        const auto Watched = _WriteSeenFrame.IsSet() && _Frame - _WriteSeenFrame.GetValue() >= k_WatchFrames;
        auto Result = OutResult;
        Result.Set(Watched || _Frame >= k_MaxFrames + k_WatchFrames);
    }

    UFUNCTION()
    private void OnClientWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto WriteSeen = _WriteSeenFrame.IsSet();
        const auto ValidAtNotify = _ValidAtFirstNotify.IsSet() ? utils_net_spike::Get_ValidWord(_ValidAtFirstNotify.GetValue()) : "no-notify-with-write";
        const auto FirstValid = _FirstValidFrame.IsSet() ? f"{_FirstValidFrame.GetValue() - _WriteSeenFrame.GetValue()}" : "never";
        const auto BOnClient = ck::IsValid(utils_net_spike::Find(Get_SubjectEntity(), k_PayloadB));
        const auto EndValid = Get_IsTargetB();
        Log(f"[NetSpike] A writeSeen={WriteSeen} arrivedBeforeBind={_ArrivedBeforeBind} notifies={_Notifies} targetAtFirstNotify={ValidAtNotify} firstValidFramesAfterWrite={FirstValid} validByPollOnly={_ValidByPollOnly} bOnClient={BOnClient} endValid={EndValid} frames={_Frame}");
        FinishSuccess();
    }

    private FMars_Fragment_NetSpike_Ref Get_Ref()
    {
        return _A.Get_Fragment(FMars_Fragment_NetSpike_Ref);
    }

    // The stored handle is valid and is this machine's copy of B.
    private bool Get_IsTargetB()
    {
        const auto Target = Get_Ref().Target;
        if (ck::Is_NOT_Valid(Target))
        { return false; }

        return Target == utils_net_spike::Find(Get_SubjectEntity(), k_PayloadB);
    }
}
