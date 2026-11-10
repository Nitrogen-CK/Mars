// A route anchor whose resolve the anchor drain executes in the script group's main pass (stamped on the anchor and
// issued by a processor ordered before the anchor drain, so the lever-gate candidate's spawn executes before the spawn
// processor in that pass): the candidate replicates, and so do its gate and both levers, each on its own side of the
// doorway (the levers stand k_LeverSetbackCm before and after the gate along the street). The candidate requests its
// parts in its DoConstruct, so their spawns execute in the script group's settle barrier.
// Surface: Ck.Anchor.Net.AS_Anchor_CandidateOfAMainPassResolveReachesTheClientWithItsGateAndLevers
class UCk_AutoTest_Net_Anchor_CandidateOfAMainPassResolveReachesTheClientWithItsGateAndLevers : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_AnchorLocation = FVector(24000.0, 0.0, 0.0);
    private const int32 k_LeverGateRow = 1;
    private const float64 k_NearCm = 600.0;
    private const float64 k_RootToleranceCm = 1.0;
    // UMars_Anchor_LeverGate_EntityScript's lever setback along the street.
    private const float64 k_LeverSetbackCm = 150.0;
    private const float32 k_ServerHoldSeconds = 9.0f;
    private const int32 k_SlowPolls = 5000;
    // The client's window for the parts (8 s at the pinned 60 fps).
    private const int32 k_ClientMaxFrames = 480;

    private FCk_Handle _Runner;
    private FCk_Handle _Anchor;
    private FCk_Handle _Gate;
    private int32 _Frame = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Runner = InHandle;
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Poll_ClientParts", n"OnClientPartsWatched", k_ClientMaxFrames + 10);
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

    // The anchor is local to the server and owned by this runner: it dies with the test, and its end of play destroys the
    // candidate under the spawn owner.
    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_AnchorLocation);
        Params.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        Params.PinnedRow = TOptional<int32>(k_LeverGateRow);
        auto Pending = utils_entity_script::Request_SpawnEntity(_Runner, UMars_Anchor_Route_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnServerAnchorConstructed"));
    }

    UFUNCTION()
    private void OnServerAnchorConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _Anchor = FCk_Handle(InEntityScriptHandle);
        auto Anchor = _Anchor.As_Anchor();

        auto Context = FMars_Anchor_Context();
        Context.AnchorId = Anchor.Get_AnchorId();
        Context.Channel = Anchor.Get_Channel();
        Context.SpanCm = Anchor.Get_SpanCm();
        Context.HomeRadiusCm = Anchor.Get_HomeRadiusCm();

        auto Resolve = FMars_TESTONLY_NetSpawn_ResolveAtMain();
        Resolve.Request = FMars_Request_Anchor_Resolve(k_LeverGateRow, EMars_Anchor_Role::Open, Context);
        _Anchor.Add_Fragment(Resolve);
        WaitUntil(n"Is_CandidateOnThisMachine", n"OnServerCandidateBuilt", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerCandidateBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Candidate = _Anchor.As_Anchor().Get_Spawned();
        Assert_True(ck::IsValid(Candidate), "the anchor kept its candidate");
        Track_ForCleanup(Candidate);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Candidate = _Anchor.As_Anchor().Get_Spawned();
        const auto CandidateState = utils_net_spawn_test::Get_HostState(Candidate);
        const auto GateState = utils_net_spawn_test::Get_HostState(DoFind_Near(n"TAG_MarsGate"));
        const auto Levers = Count_Near(n"TAG_MarsLever");
        Log(f"[AnchorTest-server] main-pass candidate={CandidateState} gate={GateState} levers={Levers}");
        FinishSuccess();
    }

    // A gate and two levers near the anchor, on this machine.
    UFUNCTION()
    private void Is_CandidateOnThisMachine(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Gate = DoFind_Near(n"TAG_MarsGate");
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Gate) && Count_Near(n"TAG_MarsLever") == 2);
    }

    UFUNCTION()
    private void Poll_ClientParts(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Frame += 1;
        _Gate = DoFind_Near(n"TAG_MarsGate");
        auto Result = OutResult;
        Result.Set((ck::IsValid(_Gate) && Count_Near(n"TAG_MarsLever") == 2) || _Frame >= k_ClientMaxFrames);
    }

    UFUNCTION()
    private void OnClientPartsWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto LeverCount = Count_Near(n"TAG_MarsLever");
        const auto HasGate = ck::IsValid(_Gate);
        Log(f"[AnchorTest] main-pass candidate on the client: gate={HasGate} levers={LeverCount} at poll {_Frame}");
        Assert_True(HasGate, f"the client has the candidate's gate (window {k_ClientMaxFrames} frames)");
        Assert_Equals_Int(LeverCount, 2, "the client has both of the candidate's levers");
        if (HasGate == false || LeverCount != 2)
        { FinishSuccess(); return; }

        Assert_False(utils_net::Get_HasAuthority(_Gate), "the client's gate has no authority");
        const auto Location = utils_transform::Get_EntityCurrentTransform(_Gate.As_Transform()).GetLocation();
        Assert_True(Location.Equals(k_AnchorLocation, k_RootToleranceCm), f"the client's gate stands at the anchor (at {Location})");

        // Each lever by its own params: one before the gate, one after it.
        auto Before = 0;
        auto After = 0;
        for (auto Lever : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsLever"))
        {
            if (Get_IsNear(Lever) == false)
            { continue; }

            const auto Along = utils_transform::Get_EntityCurrentTransform(Lever.As_Transform()).GetLocation().X - k_AnchorLocation.X;
            if (Math::Abs(Along + k_LeverSetbackCm) <= k_RootToleranceCm)
            { Before += 1; }
            else if (Math::Abs(Along - k_LeverSetbackCm) <= k_RootToleranceCm)
            { After += 1; }
        }

        Assert_Equals_Int(Before, 1, "one lever stands before the gate");
        Assert_Equals_Int(After, 1, "one lever stands after the gate");
        FinishSuccess();
    }

    private FCk_Handle DoFind_Near(FName InTag)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            if (Get_IsNear(Candidate))
            { return Candidate; }
        }

        return FCk_Handle();
    }

    private int32 Count_Near(FName InTag)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            if (Get_IsNear(Candidate))
            { Count += 1; }
        }

        return Count;
    }

    private bool Get_IsNear(FCk_Handle InEntity)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        return (utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - k_AnchorLocation).Size() < k_NearCm;
    }
}
