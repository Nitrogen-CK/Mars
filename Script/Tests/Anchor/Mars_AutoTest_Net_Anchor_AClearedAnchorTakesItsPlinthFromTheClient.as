// A cleared pack anchor destroys its plinth on the listen host, and that destroy reaches the client: the client's copy
// goes with it, and nothing on the client destroys it on its own.
// Surface: Ck.Anchor.Net.AS_Anchor_AClearedAnchorTakesItsPlinthFromTheClient
class UCk_AutoTest_Net_Anchor_AClearedAnchorTakesItsPlinthFromTheClient : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_AnchorLocation = FVector(772000.0, 0.0, 5000.0);
    private const int32 k_PlinthRow = 0;
    private const float64 k_NearCm = 600.0;
    // The client's copy has composed before the server clears.
    private const float32 k_ClearAfterSeconds = 2.5f;
    private const float32 k_SettleSeconds = 1.0f;
    private const float32 k_ServerHoldSeconds = 2.0f;
    private const int32 k_SlowPolls = 5000;

    private FCk_Handle _Runner;
    private FCk_Handle _Anchor;
    private int32 _EnsuresAtBegin = 0;
    private int64 _ClearFrame = -1;
    private int64 _LastFrameWithPlinth = -1;

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
            WaitUntil(n"Is_PlinthNear", n"OnClientPlinthArrived", k_SlowPolls);
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

    // The anchor is local to the server and owned by this runner; its plinth is not tracked, so only the clear
    // removes it.
    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_AnchorLocation);
        Params.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        Params.PinnedRow = TOptional<int32>(k_PlinthRow);
        auto Pending = utils_entity_script::Request_SpawnEntity(_Runner, UMars_Anchor_Pack_EntityScript, Params);
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
        Anchor.Request_Resolve(FMars_Request_Anchor_Resolve(k_PlinthRow, EMars_Anchor_Role::Other, Context));
        WaitUntil(n"Is_ServerPlinthBuilt", n"OnServerPlinthBuilt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerPlinthBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Candidate = _Anchor.As_Anchor().Get_Spawned();
        auto Result = OutResult;
        Result.Set(ck::IsValid(Candidate) && utils_entity_tag::Has(Candidate, n"TAG_MarsPackPlinth"));
    }

    UFUNCTION()
    private void OnServerPlinthBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ClearAfterSeconds, n"OnServerClear");
    }

    UFUNCTION()
    private void OnServerClear(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ClearFrame = int64(utils_time::Get_FrameCounter());
        auto Anchor = _Anchor.As_Anchor();
        Anchor.Request_Clear(FMars_Request_Anchor_Clear());
        WaitUntil(n"Is_ServerCleared", n"OnServerCleared", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCleared(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Anchor = _Anchor.As_Anchor();
        auto Result = OutResult;
        Result.Set(Anchor.Get_State() == EMars_Anchor_State::Cleared && ck::Is_NOT_Valid(Anchor.Get_Spawned()));
    }

    UFUNCTION()
    private void OnServerCleared(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("held");
        Assert_Equals_Int(Count_Near(n"TAG_MarsPackPlinth"), 0, "no plinth stands near the cleared anchor on the server");
        Assert_Equals_Int(Get_RowEnsures(), 0, "no ensure on the server");
        FinishSuccess();
    }

    UFUNCTION()
    private void Is_PlinthNear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Count_Near(n"TAG_MarsPackPlinth") > 0);
    }

    UFUNCTION()
    private void OnClientPlinthArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("arrived");
        WaitUntil(n"Is_NoPlinthNear", n"OnClientPlinthGone", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_NoPlinthNear(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Count = Count_Near(n"TAG_MarsPackPlinth");
        if (Count > 0)
        { _LastFrameWithPlinth = int64(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(Count == 0);
    }

    UFUNCTION()
    private void OnClientPlinthGone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_Row("settled");
        Assert_Equals_Int(Count_Near(n"TAG_MarsPackPlinth"), 0, "the client's plinth stays gone");
        Assert_Equals_Int(Get_RowEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    private void Log_Row(FString InWhen)
    {
        const auto Machine = utils_net::Get_HasAuthority(Get_SubjectEntity()) ? "server" : "client";
        auto Place = "none";
        auto Authority = "none";
        auto Owner = "none";
        const auto Plinth = DoFind_Near(n"TAG_MarsPackPlinth");
        if (ck::IsValid(Plinth))
        {
            Place = f"{utils_transform::Get_EntityCurrentTransform(Plinth.As_Transform()).GetLocation()}";
            Authority = f"{utils_net::Get_HasAuthority(Plinth)}";
            Owner = f"{utils_handle::Get_DebugName(Plinth.Get_LifetimeOwner())}";
        }

        const auto Plinths = Count_Near(n"TAG_MarsPackPlinth");
        const auto Line = f"[AnchorNetTest] AClearedAnchorTakesItsPlinthFromTheClient {Machine} {InWhen} place={Place} authority={Authority} owner={Owner} plinths={Plinths} clearFrame={_ClearFrame} lastFrameWithPlinth={_LastFrameWithPlinth} ensures={Get_RowEnsures()} frame={utils_time::Get_FrameCounter()}";
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
