// Room 5 as its map builder places it, at Room 5's own coordinates on this machine's floor: the spider, the pale
// crawler and the aggression lever, their placed classes through the channel a spawner with authority queues them
// under, and the production pawn a client possesses between them. Before the pull the spider is armed but passive with
// no target and the pale crawler unarmed. The client throws the lever through the control's engage cue: its copy of the
// lever reads active within 1 s of the server's, the server's spider turns aggressive within 1 s of its lever and takes
// the pawn as its target within 5 s; the pale crawler never turns aggressive or takes a target. The client throws it
// back: within 1 s the spider is calm, within 2 s it holds no target and it begins no attack after that. The client's
// spider copy is unarmed and carries the sink's replicated ledger; its pale copy carries none.
// Surface: Ck.Crawler.Net.AS_Crawler_AClientsLeverRousesTheRoomFiveSpider
class UCk_AutoTest_Net_Crawler_AClientsLeverRousesTheRoomFiveSpider : UMars_AutoTestRig_NetCrawlerPawn
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(-3000.0, 0.0, 0.0);
    private const FVector k_PawnOffset = FVector(-100.0, 300.0, 0.0);
    private const FVector k_SpiderAt = FVector(-3400.0, 300.0, 80.0);
    private const FVector k_PaleAt = FVector(-2600.0, 350.0, 30.0);
    private const FVector k_LeverAt = FVector(-3978.0, 0.0, 110.0);
    private const FRotator k_LeverRotation = FRotator(90.0, 180.0, 0.0);
    private const FString k_Row = "AClientsLeverRousesTheRoomFiveSpider";
    private const float64 k_AggressiveWithinSeconds = 1.0;
    private const float64 k_TargetWithinSeconds = 5.0;
    private const float64 k_CalmWithinSeconds = 1.0;
    private const float64 k_UntargetWithinSeconds = 2.0;
    private const float32 k_CalmWatchSeconds = 1.0f;
    private const float64 k_CopyLeverWithinSeconds = 1.0;

    private FCk_Handle_Crawler _Pale;
    private FCk_Handle _PaleRoot;
    private float64 _StepSince = -1.0;
    private bool _PaleEverAggressive = false;
    private bool _PaleEverTargeted = false;
    private bool _LastPowered = false;
    private FString _PowerChanges = "";
    private int32 _LeverActiveFrame = -1;
    private int32 _AggressiveFrame = -1;
    private int32 _LeverInactiveFrame = -1;
    private int32 _CalmFrame = -1;
    private int32 _UntargetFrame = -1;
    private int32 _GenerationAtUntarget = 0;
    // A client: its cues' frames and the frames its copy of the lever read active and inactive.
    private int32 _FirstCueFrame = -1;
    private int32 _SecondCueFrame = -1;
    private int32 _CopyLeverActiveFrame = -1;
    private int32 _CopyLeverInactiveFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _LegCount = 6;
        _Layout = EMars_Crawler_Layout::Spider;
        _LimbNearCm = 1500.0;
        Begin_CrawlerPawnRow(k_Base, k_PawnOffset);
        _CrawlerAt = FVector(k_SpiderAt.X, k_SpiderAt.Y, k_Base.Z);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_EverythingFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // This machine's pale crawler near its spot, with its eight leg parts; the server tracks it the first time.
    private bool Get_IsPaleFound()
    {
        if (ck::IsValid(_Pale))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsCrawler"))
        {
            if (Get_IsNear(Candidate, k_PaleAt) == false)
            { continue; }

            const auto Crawler = Candidate.As_Crawler(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Crawler) || Crawler.Get_LegParts().Num() != 8)
            { continue; }

            _Pale = Crawler;
            _PaleRoot = Candidate;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    UFUNCTION()
    private void Is_EverythingFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && Get_IsPaleFound() && Get_IsLeverFound(k_LeverAt));
    }

    // One sample: the crawler rig's, the sink's power, the pale crawler's aggression and target, the lever's state.
    private void Sample_Room()
    {
        Sample_Crawler();
        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (Get_IsServer() && Get_IsCrawlerGone() == false)
        {
            const auto Sink = _CrawlerRoot.As_MechanismSink(ECk_SanityCheck::UnChecked);
            const auto Powered = ck::IsValid(Sink) && Sink.Get_IsPowered();
            if (Powered != _LastPowered)
            {
                _PowerChanges += f"{Frame}:{Powered},";
                _LastPowered = Powered;
            }

            if (_AggressiveFrame < 0 && _Crawler.Get_IsAggressive())
            { _AggressiveFrame = Frame; }
        }

        if (Get_IsServer() && ck::IsValid(_Pale))
        {
            _PaleEverAggressive = _PaleEverAggressive || _Pale.Get_IsAggressive();
            _PaleEverTargeted = _PaleEverTargeted || ck::IsValid(_Pale.Get_CombatTarget());
        }

        if (ck::IsValid(_Lever))
        {
            const auto Active = _Lever.Get_IsActive();
            if (Get_IsServer())
            {
                if (Active && _LeverActiveFrame < 0)
                { _LeverActiveFrame = Frame; }

                if (Active == false && _LeverActiveFrame >= 0 && _LeverInactiveFrame < 0)
                { _LeverInactiveFrame = Frame; }
            }
            else
            {
                if (Active && _CopyLeverActiveFrame < 0)
                { _CopyLeverActiveFrame = Frame; }

                if (Active == false && _CopyLeverActiveFrame >= 0 && _CopyLeverInactiveFrame < 0)
                { _CopyLeverInactiveFrame = Frame; }
            }
        }
    }

    private FString Describe_Room()
    {
        const auto SpiderSink = Get_IsCrawlerGone() == false && _CrawlerRoot.Has_Fragment(FMars_Fragment_MechanismSink);
        const auto PaleSink = ck::IsValid(_PaleRoot) && _PaleRoot.Has_Fragment(FMars_Fragment_MechanismSink);
        const auto SpiderTarget = Get_IsCrawlerGone() == false && ck::IsValid(_Crawler.Get_CombatTarget());
        const auto SpiderAggressive = Get_IsCrawlerGone() == false && Get_IsServer() && _Crawler.Get_IsAggressive();
        return f"room=[leverActive {_LeverActiveFrame} aggressive {_AggressiveFrame} target {_BlowTargetFrame} leverInactive {_LeverInactiveFrame} "
            + f"calm {_CalmFrame} untarget {_UntargetFrame} genAtUntarget {_GenerationAtUntarget} power [{_PowerChanges}] "
            + f"spiderSinkLedger {SpiderSink} paleSinkLedger {PaleSink} spiderTargetNow {SpiderTarget} spiderAggressiveNow {SpiderAggressive} "
            + f"paleEverAggressive {_PaleEverAggressive} paleEverTargeted {_PaleEverTargeted} cues {_FirstCueFrame}/{_SecondCueFrame} "
            + f"copyLever {_CopyLeverActiveFrame}/{_CopyLeverInactiveFrame}] {Describe_BlowPawn()}";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLever(UMars_Sandbox_AggressionLever_EntityScript, FTransform(k_LeverRotation, k_LeverAt));
        Spawn_ServerCrawlerAt(Make_RowSpec(k_StaysPut), UMars_Sandbox_Crawler6_EntityScript, FTransform(FRotator::ZeroRotator, k_SpiderAt), false);
        Spawn_ServerCrawlerAt(Make_RowSpec(k_StaysPut), UMars_Sandbox_PaleCrawler8_EntityScript, FTransform(FRotator::ZeroRotator, k_PaleAt), false);
        WaitUntil(n"Is_ServerRoomSettled", n"OnServerRoomSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRoomSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        auto Result = OutResult;
        Result.Set(Get_IsCrawlerFound() && Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready
            && _CrawlerMonster.Get_Parts().Num() == _LegCount && Get_IsPaleFound() && Get_IsLeverFound(k_LeverAt));
    }

    UFUNCTION()
    private void OnServerRoomSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerReadout();
        Begin_AttackRecord();
        Spawn_ServerBlowPawn();
        WaitUntil(n"Is_BlowPawnComposed", n"OnServerPawnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPawnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Crawler.Get_IsCombatArmed(), "the server's spider is armed");
        Assert_False(_Crawler.Get_IsAggressive(), "the server's spider is not aggressive before the pull");
        Assert_False(ck::IsValid(_Crawler.Get_CombatTarget()), "the server's spider holds no target before the pull");
        Assert_False(_Pale.Get_IsCombatArmed(), "the server's pale crawler is unarmed");
        Assert_False(_Pale.Get_IsAggressive(), "the server's pale crawler is not aggressive");
        Assert_False(_Lever.Get_IsActive(), "the server's lever starts inactive");
        if (Request_ServerPossessBlowPawn() == false)
        {
            Log_CrawlerRow(k_Row, f"remoteController=none {Describe_Room()}");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        WaitUntil(n"Is_ServerLeverActive", n"OnServerLeverActive", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLeverActive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        auto Result = OutResult;
        Result.Set(_LeverActiveFrame >= 0);
    }

    UFUNCTION()
    private void OnServerLeverActive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerMark("LeverActive", _LeverActiveFrame);
        _StepSince = Get_WorldSeconds();
        WaitUntil(n"Is_ServerSpiderOnThePawn", n"OnServerSpiderOnThePawn", k_SlowPolls);
    }

    // The spider aggressive and holding the pawn, or the time it had to ran out.
    UFUNCTION()
    private void Is_ServerSpiderOnThePawn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        Sample_BlowTarget();
        auto Result = OutResult;
        Result.Set((_AggressiveFrame >= 0 && _BlowTargetFrame >= 0) || Get_WorldSeconds() - _StepSince > k_TargetWithinSeconds);
    }

    UFUNCTION()
    private void OnServerSpiderOnThePawn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto ToAggressive = Get_SecondsBetweenFrames(_LeverActiveFrame, _AggressiveFrame);
        const auto ToTarget = Get_SecondsBetweenFrames(_LeverActiveFrame, _BlowTargetFrame);
        Assert_True(_AggressiveFrame >= 0 && ToAggressive <= k_AggressiveWithinSeconds,
            f"the server's spider turned aggressive within 1 s of its lever going active ({ToAggressive} s, {Describe_Room()})");
        Assert_True(_BlowTargetFrame >= 0 && ToTarget <= k_TargetWithinSeconds,
            f"the server's spider took the pawn as its target within 5 s of its lever ({ToTarget} s)");
        if (_BlowTargetFrame < 0)
        {
            Log_CrawlerRow(k_Row, f"{Describe_Room()} {Describe_AttackState()}");
            FinishFailure("the server's spider did not take the pawn within 5 s of the lever");
            return;
        }

        Publish_ServerMark("Target", _BlowTargetFrame);
        WaitUntil(n"Is_ServerLeverInactive", n"OnServerLeverInactive", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLeverInactive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        auto Result = OutResult;
        Result.Set(_LeverInactiveFrame >= 0);
    }

    UFUNCTION()
    private void OnServerLeverInactive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _StepSince = Get_WorldSeconds();
        WaitUntil(n"Is_ServerSpiderCalm", n"OnServerSpiderCalm", k_SlowPolls);
    }

    // Calm and without a target, or the time it had to ran out.
    UFUNCTION()
    private void Is_ServerSpiderCalm(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (_CalmFrame < 0 && _Crawler.Get_IsAggressive() == false)
        { _CalmFrame = Frame; }

        if (_UntargetFrame < 0 && ck::Is_NOT_Valid(_Crawler.Get_CombatTarget()))
        {
            _UntargetFrame = Frame;
            _GenerationAtUntarget = _Crawler.Get_AttackGeneration();
        }

        auto Result = OutResult;
        Result.Set((_CalmFrame >= 0 && _UntargetFrame >= 0) || Get_WorldSeconds() - _StepSince > k_UntargetWithinSeconds);
    }

    UFUNCTION()
    private void OnServerSpiderCalm(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto ToCalm = Get_SecondsBetweenFrames(_LeverInactiveFrame, _CalmFrame);
        const auto ToUntarget = Get_SecondsBetweenFrames(_LeverInactiveFrame, _UntargetFrame);
        Assert_True(_CalmFrame >= 0 && ToCalm <= k_CalmWithinSeconds, f"the server's spider was calm within 1 s of its lever going inactive ({ToCalm} s)");
        Assert_True(_UntargetFrame >= 0 && ToUntarget <= k_UntargetWithinSeconds, f"the server's spider held no target within 2 s ({ToUntarget} s)");
        WaitSampling(k_CalmWatchSeconds, n"OnServerCalmWatched");
    }

    UFUNCTION()
    private void OnServerCalmWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_UntargetFrame >= 0 && _Crawler.Get_AttackGeneration() == _GenerationAtUntarget,
            f"the server's spider began no attack once it held no target (generation {_GenerationAtUntarget} -> {_Crawler.Get_AttackGeneration()})");
        Assert_False(_PaleEverAggressive, "the server's pale crawler never turned aggressive");
        Assert_False(_PaleEverTargeted, "the server's pale crawler never took a target");
        Publish_ServerMark("Calm", int32(utils_time::Get_FrameCounter()));
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSampling(2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_CrawlerRow(k_Row, f"{Describe_Room()} {Describe_AttackState()}");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerReturned");
    }

    UFUNCTION()
    private void OnServerReturned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TearDown_BlowPawn();
        FinishSuccess();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientPossessedWithReadout", n"OnClientPossessed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientPossessedWithReadout(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        auto Result = OutResult;
        Result.Set(_HasReadout && Get_IsBlowPawnComposed() && ck::IsValid(_BlowPawn) && _BlowPawn.IsLocallyControlled());
    }

    UFUNCTION()
    private void OnClientPossessed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_CopyLikeTheServer();
        Assert_False(utils_net::Get_HasAuthority(_Lever), "the client's lever has no authority");
        _FirstCueFrame = int32(utils_time::Get_FrameCounter());
        Fire_LeverEngageCue();
        WaitUntil(n"Is_ClientServerTargeted", n"OnClientServerTargeted", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientServerTargeted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        auto Result = OutResult;
        Result.Set(Get_ServerMark("Target") >= 0 && _CopyLeverActiveFrame >= 0);
    }

    UFUNCTION()
    private void OnClientServerTargeted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Behind = Get_SecondsBetweenFrames(Get_ServerMark("LeverActive"), _CopyLeverActiveFrame);
        // Either side: the copy may read the engage it sent before the server's next sample.
        Assert_True(_CopyLeverActiveFrame >= 0 && Math::Abs(Behind) <= k_CopyLeverWithinSeconds,
            f"the client's lever read active within 1 s of the server's ({Behind} s)");
        _SecondCueFrame = int32(utils_time::Get_FrameCounter());
        Fire_LeverEngageCue();
        WaitUntil(n"Is_ClientServerCalm", n"OnClientServerCalm", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientServerCalm(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Room();
        auto Result = OutResult;
        Result.Set(Get_ServerMark("Calm") >= 0);
    }

    UFUNCTION()
    private void OnClientServerCalm(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(1.0f, n"OnClientCalmArrived");
    }

    UFUNCTION()
    private void OnClientCalmArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Sample_Room();
        Log_CrawlerRow(k_Row, f"{Describe_Room()} {Describe_Readout()}");
        Assert_False(_Lever.Get_IsActive(), "the client's lever reads inactive after its second cue");
        Assert_True(_CopyLeverInactiveFrame >= 0, "the client's lever read inactive after it read active");
        Assert_False(_Crawler.Get_IsCombatArmed(), "the client's spider copy is not armed");
        Assert_True(_CrawlerRoot.Has_Fragment(FMars_Fragment_MechanismSink), "the client's spider copy carries the sink's replicated ledger");
        Assert_False(_PaleRoot.Has_Fragment(FMars_Fragment_MechanismSink), "the client's pale copy carries no sink ledger");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_BlowPawn();
        FinishSuccess();
    }
}
