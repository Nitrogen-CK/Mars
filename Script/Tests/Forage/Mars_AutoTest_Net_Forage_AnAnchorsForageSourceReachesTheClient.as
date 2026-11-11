// A forage anchor resolved on the listen host builds its fig vine (a Replicated row) under the replicated spawn owner:
// the vine replicates, re-runs its construction on the client, and the client's copy has no authority and reads the
// server's charges. The anchor itself is placed on the server only and never replicates.
// Surface: Ck.Forage.Net.AS_Forage_AnAnchorsForageSourceReachesTheClient
class UCk_AutoTest_Net_Forage_AnAnchorsForageSourceReachesTheClient : UMars_AutoTestRig_NetForage
{
    private const FVector k_Base = FVector(73000.0, 0.0, 5000.0);
    private const int32 k_FigVineRow = 0;

    private FCk_Handle _Runner;
    private FCk_Handle _Anchor;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Runner = InHandle;
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_VineFound", n"OnClientVineFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The anchor is local to the server and owned by this runner: it dies with the test, and its end of play destroys the
    // vine under the spawn owner.
    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = FMars_TESTONLY_AnchorSpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.AnchorId = GameplayTags::Anchor_Mars_Test_A;
        Params.Channel = GameplayTags::ResolveGameplayTag(n"Mechanism.Channel.Anchor.Test.A");
        Params.PinnedRow = TOptional<int32>(k_FigVineRow);
        auto Pending = utils_entity_script::Request_SpawnEntity(_Runner, UMars_Anchor_Forage_EntityScript, Params);
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
        Anchor.Request_Resolve(FMars_Request_Anchor_Resolve(k_FigVineRow, EMars_Anchor_Role::Other, Context));
        WaitUntil(n"Is_VineFound", n"OnServerVineFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_VineFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsForageVine"));
    }

    UFUNCTION()
    private void OnServerVineFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Candidate = _Anchor.As_Anchor().Get_Spawned();
        Assert_True(Candidate == _Source, "the anchor kept the vine as its candidate");
        Assert_True(Candidate.Get_LifetimeOwner() != _Anchor, "the vine lives under the spawn owner, not the anchor");
        Assert_Equals_Int(_Forage.Get_ChargesLeft(), 1, "the server's vine holds its fig");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientVineFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Authority = utils_net::Get_HasAuthority(_Source);
        const auto Charges = _Forage.Get_ChargesLeft();
        const auto Anchors = utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsAnchor").Num();
        Assert_False(Authority, "the client's vine has no authority");
        Assert_Equals_Int(Charges, 1, "the client's vine reads the server's charges");
        Assert_Equals_Int(Anchors, 0, "the anchor itself never reaches the client");
        Log(f"[ForageNetTest] AnAnchorsForageSourceReachesTheClient authority={Authority} charges={Charges} anchors={Anchors}");
        FinishSuccess();
    }
}
