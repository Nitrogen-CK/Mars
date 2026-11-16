// An omen anchor resolved on the listen host builds its eyes under the replicated spawn owner, and the eyes stand on
// the client where the anchor stands, placed by the spawn transform every machine receives, with no authority there.
// The anchor itself never reaches the client.
// Surface: Ck.Anchor.Net.AS_Anchor_AnOmensEyesReachTheClient
class UCk_AutoTest_Net_Anchor_AnOmensEyesReachTheClient : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_AnchorLocation = FVector(771000.0, 0.0, 5000.0);
    private const int32 k_EyesRow = 0;
    private const float64 k_NearCm = 600.0;
    private const float64 k_RootToleranceCm = 1.0;
    private const float32 k_SettleSeconds = 1.0f;
    private const float32 k_ServerHoldSeconds = 3.0f;
    private const int32 k_SlowPolls = 5000;

    private FCk_Handle _Runner;
    private FCk_Handle _Anchor;
    private FCk_Handle _Eyes;
    private int32 _EnsuresAtBegin = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Runner = InHandle;
        _EnsuresAtBegin = utils_ensure::Get_EnsureCount();
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_OneEyesNear", n"OnClientEyesArrived", k_SlowPolls);
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

    // The anchor is local to the server and owned by this runner: it dies with the test.
    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_AnchorLocation);
        Params.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        Params.PinnedRow = TOptional<int32>(k_EyesRow);
        auto Pending = utils_entity_script::Request_SpawnEntity(_Runner, UMars_Anchor_Omen_EntityScript, Params);
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
        Anchor.Request_Resolve(FMars_Request_Anchor_Resolve(k_EyesRow, EMars_Anchor_Role::Other, Context));
        WaitUntil(n"Is_ServerEyesBuilt", n"OnServerEyesBuilt", k_SlowPolls);
    }

    // The anchor's candidate has composed: it carries its tag.
    UFUNCTION()
    private void Is_ServerEyesBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Candidate = _Anchor.As_Anchor().Get_Spawned();
        auto Result = OutResult;
        Result.Set(ck::IsValid(Candidate) && utils_entity_tag::Has(Candidate, n"TAG_MarsOmenEyes"));
    }

    UFUNCTION()
    private void OnServerEyesBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Anchor = _Anchor.As_Anchor();
        _Eyes = Anchor.Get_Spawned();
        Assert_True(_Eyes.Get_LifetimeOwner() != _Anchor, "the eyes live under the spawn owner, not the anchor");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_Eyes), "the server's eyes replicate");
        Assert_True(Anchor.Get_State() == EMars_Anchor_State::Spawned, "the anchor is spawned");
        Track_ForCleanup(_Eyes);
        Log_Eyes("found");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_RowEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_OneEyesNear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Eyes = DoFind_Near(n"TAG_MarsOmenEyes");
        auto Result = OutResult;
        Result.Set(Count_Near(n"TAG_MarsOmenEyes") == 1);
    }

    UFUNCTION()
    private void OnClientEyesArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Eyes))
        { FinishFailure("the client's eyes were gone a second after they arrived"); return; }

        Log_Eyes("settled");
        Assert_Equals_Int(Count_Near(n"TAG_MarsOmenEyes"), 1, "one pair of eyes stands near the anchor on the client");
        Assert_False(utils_net::Get_HasAuthority(_Eyes), "the client's eyes have no authority");
        Assert_True(utils_mars_net::Get_ReplicatesHere(_Eyes), "the client's eyes are a replicated copy");
        const auto Location = utils_transform::Get_EntityCurrentTransform(_Eyes.As_Transform()).GetLocation();
        Assert_True(Location.Equals(k_AnchorLocation, k_RootToleranceCm), f"the client's eyes stand at the anchor (at {Location})");
        Assert_Equals_Int(utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsAnchor").Num(), 0, "the anchor itself never reaches the client");
        Assert_Equals_Int(Get_RowEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    private void Log_Eyes(FString InWhen)
    {
        const auto Machine = utils_net::Get_HasAuthority(Get_SubjectEntity()) ? "server" : "client";
        const auto Location = utils_transform::Get_EntityCurrentTransform(_Eyes.As_Transform()).GetLocation();
        const auto Owner = utils_handle::Get_DebugName(_Eyes.Get_LifetimeOwner());
        const auto Line = f"[AnchorNetTest] AnOmensEyesReachTheClient {Machine} {InWhen} place={Location} authority={utils_net::Get_HasAuthority(_Eyes)} owner={Owner} replicatesHere={utils_mars_net::Get_ReplicatesHere(_Eyes)} ensures={Get_RowEnsures()} frame={utils_time::Get_FrameCounter()}";
        Log(Line);
    }

    private int32 Get_RowEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtBegin;
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
