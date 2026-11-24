// An aggressive armed crawler (it shuns light) stands 220 from the production pawn the server spawns. The server picks
// a lantern up for the pawn and lights it, the way a client's pickup cue lands on the host, before the client's
// controller possesses the pawn, so the crawler's first sight of its prey is a lit lantern raised in its hand. Once the
// crawler holds the pawn as its target, its start at the pawn reads Warded: for 3 s, sampled every 0.25 s, no attack
// is begun and the pawn stays at 100, and the client's copy shows no action. Then the client lowers the lantern through
// its own select cue (the empty slot): within 3 s of the server's hotbar selection changing an attack is admitted and
// runs to Idle. The client's copy recorded that attack, and its pawn's Health and OnDamaged match the server's.
// Surface: Ck.Crawler.Net.AS_Crawler_AShunCrawlerSparesAClientHoldingALitLantern
class UCk_AutoTest_Net_Crawler_AShunCrawlerSparesAClientHoldingALitLantern : UMars_AutoTestRig_NetCrawlerPawn
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(848000.0, 0.0, 5000.0);
    private const FVector k_PawnOffset = FVector(220.0, 0.0, 0.0);
    private const FString k_Row = "AShunCrawlerSparesAClientHoldingALitLantern";
    private const float64 k_LanternWithinSeconds = 4.0;
    private const float64 k_WardWithinSeconds = 6.0;
    private const float64 k_WardHoldSeconds = 3.0;
    private const float64 k_WardSampleSeconds = 0.25;
    private const float64 k_AdmitWithinSeconds = 3.0;

    private float64 _StepSince = -1.0;
    private int32 _PossessFrame = -1;
    private int32 _WardedFrame = -1;
    private int32 _GenerationAtWard = 0;
    private int32 _SelectionAtRaise = -1;
    private float64 _NextWardSample = 0.0;
    private int32 _WardSamples = 0;
    private FString _WardBreaks = "";
    private int32 _SelectionFrame = -1;
    private float64 _SelectionSeconds = -1.0;
    private int32 _StartedBeforeStow = 0;
    private int32 _AdmittedFrame = -1;
    private int32 _AdmittedGeneration = 0;
    // A client: its cue's frame and slot, and what its copy showed until the server's ward hold ended.
    private int32 _CueFrame = -1;
    private int32 _CueSlot = -1;
    private int32 _CopyStartedDuringWard = 0;
    private float32 _PawnLowestDuringWard = 100.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerPawnRow(k_Base, k_PawnOffset);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerSettled", n"OnClientSettled", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    private FString Describe_Ward()
    {
        const auto Rejection = Get_IsCrawlerGone() || ck::Is_NOT_Valid(_BlowPlayer) ? TOptional<EMars_Crawler_AttackReject>()
            : _Crawler.Get_StartRejection(_BlowPlayer);
        const auto RejectionText = Rejection.IsSet() ? f"{Rejection.GetValue() :n}" : FString("none");
        auto LightsOn = -1;
        auto Distance = -1.0;
        auto IsTarget = false;
        if (Get_IsCrawlerGone() == false && Get_IsServer())
        {
            LightsOn = _Crawler.Get_LightsOn().Num();
            IsTarget = ck::IsValid(_BlowPlayer) && _Crawler.Get_CombatTarget() == _BlowPlayer;
            if (ck::IsValid(_BlowPlayer))
            { Distance = (utils_transform::Get_EntityCurrentLocation(_BlowPlayer.As_Transform()) - Get_RootLocation()).Size2D(); }
        }

        return f"ward=[rejection {RejectionText} lightsOn {LightsOn} target {IsTarget} distance {Distance} possessFrame {_PossessFrame} "
            + f"wardedFrame {_WardedFrame} genAtWard {_GenerationAtWard} samples {_WardSamples} breaks [{_WardBreaks}] "
            + f"selectionAtRaise {_SelectionAtRaise} selectionFrame {_SelectionFrame} admittedFrame {_AdmittedFrame} gen {_AdmittedGeneration} "
            + f"cueFrame {_CueFrame} cueSlot {_CueSlot} copyStartedDuringWard {_CopyStartedDuringWard} pawnLowestDuringWard {_PawnLowestDuringWard}] "
            + f"{Describe_PawnLantern()} {Describe_BlowPawn()}";
    }

    private bool Get_IsServerWarded()
    {
        if (Get_IsCrawlerGone() || ck::Is_NOT_Valid(_BlowPlayer))
        { return false; }

        const auto Rejection = _Crawler.Get_StartRejection(_BlowPlayer);
        return Rejection.IsSet() && Rejection.GetValue() == EMars_Crawler_AttackReject::Warded;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCrawler(Make_ArmedRowSpec(k_StaysPut, ECk_EnableDisable::Enable));
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerReadout();
        Begin_AttackRecord();
        Spawn_ServerBlowPawn();
        WaitUntil(n"Is_BlowPawnComposed", n"OnServerPawnComposed", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerPawnComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerLanternForPawn();
        _StepSince = Get_WorldSeconds();
        WaitUntil(n"Is_ServerLanternReady", n"OnServerLanternReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLanternReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_IsServerLanternReady() || Get_WorldSeconds() - _StepSince > k_LanternWithinSeconds);
    }

    UFUNCTION()
    private void OnServerLanternReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsServerLanternReady() == false)
        {
            Log_CrawlerRow(k_Row, Describe_Ward());
            FinishFailure("the server's lantern did not link, or the pawn's hotbar was not ready, within 4 s");
            return;
        }

        Request_ServerRaiseLitLantern();
        _StepSince = Get_WorldSeconds();
        WaitUntil(n"Is_ServerLanternRaised", n"OnServerLanternRaised", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLanternRaised(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Flame = Get_PawnHeldFlame();
        auto Result = OutResult;
        Result.Set((ck::IsValid(Flame) && Flame.Get_IsLit()) || Get_WorldSeconds() - _StepSince > k_LanternWithinSeconds);
    }

    UFUNCTION()
    private void OnServerLanternRaised(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Flame = Get_PawnHeldFlame();
        if (ck::Is_NOT_Valid(Flame) || Flame.Get_IsLit() == false)
        {
            Log_CrawlerRow(k_Row, Describe_Ward());
            FinishFailure("the server's pawn did not come to hold the lit lantern within 4 s");
            return;
        }

        _SelectionAtRaise = Get_PawnSelection();
        if (Request_ServerPossessBlowPawn() == false)
        {
            Log_CrawlerRow(k_Row, f"remoteController=none {Describe_Ward()}");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        _PossessFrame = int32(utils_time::Get_FrameCounter());
        _StepSince = Get_WorldSeconds();
        WaitUntil(n"Is_ServerWardStanding", n"OnServerWardStanding", k_SlowPolls);
    }

    // The pawn is the crawler's target and a start at it reads Warded, or the time it had to ran out.
    UFUNCTION()
    private void Is_ServerWardStanding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        Sample_BlowTarget();
        auto Result = OutResult;
        Result.Set((_BlowTargetFrame >= 0 && Get_IsServerWarded()) || Get_WorldSeconds() - _StepSince > k_WardWithinSeconds);
    }

    UFUNCTION()
    private void OnServerWardStanding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (_BlowTargetFrame < 0 || Get_IsServerWarded() == false)
        {
            Log_CrawlerRow(k_Row, f"{Describe_Ward()} {Describe_AttackState()}");
            FinishFailure("the server's crawler did not hold the pawn as its target with a start at it Warded within 6 s of the possession");
            return;
        }

        _WardedFrame = int32(utils_time::Get_FrameCounter());
        _GenerationAtWard = _Crawler.Get_AttackGeneration();
        _StepSince = Get_WorldSeconds();
        _NextWardSample = _StepSince;
        WaitUntil(n"Is_ServerWardHeld", n"OnServerWardHeld", k_SlowPolls);
    }

    // Every 0.25 s for 3 s: Warded, the attack generation unchanged, the pawn at 100.
    UFUNCTION()
    private void Is_ServerWardHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Now = Get_WorldSeconds();
        if (Now >= _NextWardSample)
        {
            _NextWardSample += k_WardSampleSeconds;
            _WardSamples += 1;
            const auto Health = ck::IsValid(_BlowHealth) ? _BlowHealth.Get_Current() : -1.0f;
            const auto Generation = Get_IsCrawlerGone() ? -1 : _Crawler.Get_AttackGeneration();
            if (Get_IsServerWarded() == false || Generation != _GenerationAtWard || Math::IsNearlyEqual(Health, 100.0f, 0.01f) == false)
            { _WardBreaks += f"{Now - _StepSince}s:warded {Get_IsServerWarded()} gen {Generation} health {Health},"; }
        }

        auto Result = OutResult;
        Result.Set(Now - _StepSince >= k_WardHoldSeconds);
    }

    UFUNCTION()
    private void OnServerWardHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_WardSamples >= 12 && _WardBreaks.IsEmpty(),
            f"for 3 s the start read Warded, no attack began and the pawn stayed at 100 ({_WardSamples} samples, breaks [{_WardBreaks}])");
        _StartedBeforeStow = Count_StartedAttacks();
        Publish_ServerMark("WardHeld", int32(utils_time::Get_FrameCounter()));
        WaitUntil(n"Is_ServerSelectionChanged", n"OnServerSelectionChanged", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerSelectionChanged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Get_PawnSelection() != _SelectionAtRaise);
    }

    UFUNCTION()
    private void OnServerSelectionChanged(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SelectionFrame = int32(utils_time::Get_FrameCounter());
        _SelectionSeconds = Get_WorldSeconds();
        Publish_ServerMark("Selection", _SelectionFrame);
        WaitUntil(n"Is_ServerAdmittedAfterStow", n"OnServerAdmittedAfterStow", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerAdmittedAfterStow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(Count_StartedAttacks() > _StartedBeforeStow || Get_WorldSeconds() - _SelectionSeconds > k_AdmitWithinSeconds);
    }

    UFUNCTION()
    private void OnServerAdmittedAfterStow(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Count_StartedAttacks() <= _StartedBeforeStow)
        {
            Log_CrawlerRow(k_Row, f"{Describe_Ward()} {Describe_AttackState()}");
            FinishFailure("no attack was admitted within 3 s of the server's hotbar selection changing");
            return;
        }

        _AdmittedFrame = int32(utils_time::Get_FrameCounter());
        _AdmittedGeneration = _Attacks[Find_LastStartedAttack()].Generation;
        Publish_ServerMark("Admitted", _AdmittedFrame);
        WaitUntil(n"Is_ServerAttackIdle", n"OnServerAttackIdle", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerAttackIdle(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerDisable();
        WaitSampling(1.0f, n"OnServerDisabledSampled");
    }

    UFUNCTION()
    private void OnServerDisabledSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Publish_ServerAttacks(_AdmittedGeneration, _BlowHealth.Get_Current(), _BlowApplied);
        // The client asserts first: handing the pawn back makes its copy a non-owning one.
        WaitSampling(2.0f, n"OnServerClientAsserted");
    }

    UFUNCTION()
    private void OnServerClientAsserted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_CrawlerRow(k_Row, f"{Describe_Ward()} {Describe_AttackState()}");
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
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_AttackRecord();
        Await_ServerMark("", n"OnClientReadout");
    }

    UFUNCTION()
    private void OnClientReadout(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_CopyLikeTheServer();
        WaitUntil(n"Is_ClientHoldingTheLitLantern", n"OnClientHoldingTheLitLantern", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHoldingTheLitLantern(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        const auto Flame = Get_IsBlowPawnComposed() ? Get_PawnHeldFlame() : FCk_Handle_Flame();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_BlowPawn) && _BlowPawn.IsLocallyControlled() && ck::IsValid(Flame) && Flame.Get_IsLit());
    }

    UFUNCTION()
    private void OnClientHoldingTheLitLantern(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientWardHeld", n"OnClientWardHeld", k_SlowPolls);
    }

    // Until the server's ward hold ended: what the copy showed and the pawn's Health.
    UFUNCTION()
    private void Is_ClientWardHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        _CopyStartedDuringWard = Math::Max(_CopyStartedDuringWard, Get_CopyStarted());
        if (ck::IsValid(_BlowHealth))
        { _PawnLowestDuringWard = Math::Min(_PawnLowestDuringWard, _BlowHealth.Get_Current()); }

        auto Result = OutResult;
        Result.Set(Get_ServerMark("WardHeld") >= 0);
    }

    UFUNCTION()
    private void OnClientWardHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(_CopyStartedDuringWard, 0, "the client's copy showed no action while the lantern was raised");
        Assert_True(Math::IsNearlyEqual(_PawnLowestDuringWard, 100.0f, 0.01f), f"the client's pawn stayed at 100 while the lantern was raised ({_PawnLowestDuringWard})");
        _CueFrame = int32(utils_time::Get_FrameCounter());
        _CueSlot = Fire_ClientStowCue();
        WaitUntil(n"Is_ClientLanternLowered", n"OnClientLanternLowered", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientLanternLowered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Crawler();
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(Get_PawnHeldFlame()));
    }

    UFUNCTION()
    private void OnClientLanternLowered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Await_ServerAttacks(n"OnClientArrived");
    }

    UFUNCTION()
    private void OnClientArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsCrawlerGone())
        { FinishFailure("the client's copy was gone before it asserted"); TearDown_BlowPawn(); return; }

        const auto Readout = Get_ServerAttacks();
        const auto CueToSelection = Get_ServerMark("Selection") - _CueFrame;
        const auto CueToAdmission = Get_ServerMark("Admitted") - _CueFrame;
        Log_CrawlerRow(k_Row, f"cueToSelectionFrames={CueToSelection} cueToAdmissionFrames={CueToAdmission} {Describe_Ward()} {Describe_AttackState()} {Describe_ServerAttacks()} {Describe_Readout()}");
        Assert_True(Get_HasServerAttacks() && Readout.StruckGeneration > 0, "the server's admitted attack reached the client");
        Assert_False(ck::IsValid(Get_PawnHeldFlame()), "the client's pawn no longer holds the lantern");
        const auto Index = Find_Attack(Readout.StruckGeneration, false);
        Assert_True(Index >= 0, f"the client's copy recorded the admitted attack (gen {Readout.StruckGeneration})");
        if (Index >= 0)
        { Assert_Equals_Int(_Attacks[Index].Admitted, 1, "the client's copy raised Admitted once for it"); }

        Assert_True(Math::IsNearlyEqual(_BlowHealth.Get_Current(), Readout.PawnHealth, 0.01f),
            f"the client's pawn's Health equals the server's (reads {_BlowHealth.Get_Current()}, server {Readout.PawnHealth})");
        Assert_Equals_Int(_BlowApplied.Num(), Readout.PawnApplied.Num(), "the client's pawn raised OnDamaged as often as the server's applied");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        TearDown_BlowPawn();
        FinishSuccess();
    }
}
