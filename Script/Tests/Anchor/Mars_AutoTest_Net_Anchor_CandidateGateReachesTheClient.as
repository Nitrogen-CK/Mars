// A route anchor resolved on the listen host builds its candidate under the replicated spawn owner: the lever-gate
// candidate (a Replicated row) replicates, re-runs its construction on the client, and its gate and two levers, spawned
// under it on the server, arrive there as its children. The anchor itself is placed on the server only and never
// replicates; clients never resolve. The gate's root lands where the anchor stands.
// Surface: Ck.Anchor.Net.AS_Anchor_CandidateGateReachesTheClient
class UCk_AutoTest_Net_Anchor_CandidateGateReachesTheClient : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_AnchorLocation = FVector(22000.0, 0.0, 0.0);
    private const int32 k_LeverGateRow = 1;
    private const float64 k_NearCm = 600.0;
    private const float64 k_RootToleranceCm = 1.0;
    private const float32 k_ServerHoldSeconds = 3.0f;
    private const int32 k_SlowPolls = 5000;

    private FCk_Handle _Runner;
    private FCk_Handle _Anchor;
    private FCk_Handle _Gate;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Runner = InHandle;
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_CandidateOnThisMachine", n"OnClientCandidateArrived", k_SlowPolls);
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
        Anchor.Request_Resolve(FMars_Request_Anchor_Resolve(k_LeverGateRow, EMars_Anchor_Role::Open, Context));
        WaitUntil(n"Is_CandidateOnThisMachine", n"OnServerCandidateBuilt", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerCandidateBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Candidate = _Anchor.As_Anchor().Get_Spawned();
        Assert_True(ck::IsValid(Candidate), "the anchor kept its candidate");
        Assert_True(Candidate.Get_LifetimeOwner() != _Anchor, "the candidate lives under the spawn owner, not the anchor");
        Track_ForCleanup(Candidate);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
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
    private void OnClientCandidateArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_Gate), "the client's gate has no authority");
        Assert_Equals_Int(utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsAnchor").Num(), 0, "the anchor itself never reaches the client");
        const auto Location = utils_transform::Get_EntityCurrentTransform(_Gate.As_Transform()).GetLocation();
        Assert_True(Location.Equals(k_AnchorLocation, k_RootToleranceCm), f"the client's gate stands at the anchor (at {Location})");
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
