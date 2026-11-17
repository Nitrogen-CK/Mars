// A harness fixture: the production turnip bed whose authority, as it composes, grips it with the server's stand-in and
// reports a pull, so its drain applies both in the spawn frame and a copy is born into the held grip.
class UMars_TESTONLY_NetScreamingTurnipBed_BornHeld_EntityScript : UMars_ScreamingTurnipBed_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false || InHandle.Is_Control() == false)
        { return Flow; }

        auto StandIn = FCk_Handle();
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsTestNetGripper"))
        { StandIn = Candidate; }

        if (ck::EnsureIfNot(ck::IsValid(StandIn), "[NetScreamingTurnipBed_BornHeld] the server's stand-in was not found"))
        { return Flow; }

        auto Control = InHandle.As_Control();
        Control.Request_Grip(FMars_Request_Control_Grip(StandIn, EMars_Control_GripVerb::Begin));
        Control.Request_ReportPull(FMars_Request_Control_ReportPull(StandIn, 0.6f));
        return Flow;
    }
}

// The server spawns a turnip bed whose authority grips it with the stand-in and reports a pull of 0.6 as it composes,
// so the client's copy is born held and its planted root comes into being while another machine holds the grip. Once
// the client reads the holder AnotherMachine and its planted presentation has a mesh, its clip is sampled every frame
// for 1.5 s: no sample plays the planted idle, the last plays SRC_Tug at the shown grip alpha, and the client raised
// OnGripHolderChanged to AnotherMachine exactly once.
// Surface: Ck.ScreamingTurnip.Net.AS_ScreamingTurnip_ACopyBornWhileHeldShowsTheStrain
class UCk_AutoTest_Net_ScreamingTurnip_ACopyBornWhileHeldShowsTheStrain : UMars_AutoTestRig_NetScreamingTurnip
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(806000.0, 0.0, 5000.0);
    private const float32 k_HeldSeconds = 4.0f;
    private const float64 k_SampleSeconds = 1.5;
    private const float32 k_PlayedAlphaTolerance = 0.05f;

    private UMars_ScreamingTurnipPresentationComponent _HeldPresentation;
    private TOptional<float64> _HeldSamplingSince;
    private int32 _HeldSampleCount = 0;
    private int32 _HeldIdleSamples = 0;
    private FString _HeldFirstClip;
    private float32 _HeldFirstAlpha = 0.0f;
    private FString _HeldLastClip;
    private float32 _HeldLastAlpha = 0.0f;
    // The client's frames: the bed first found, the holder first read AnotherMachine, the presentation first found.
    private int64 _HeldBedFoundFrame = -1;
    private int64 _HeldHolderFrame = -1;
    private int64 _HeldPresentationFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_TurnipTest(InHandle, k_Location);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientHeldPresentationReady", n"OnClientHeldPresentationReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    // The planted presentation on this machine's copy of the bed, through its transform tree.
    private void Find_HeldPresentation()
    {
        if (ck::IsValid(_HeldPresentation))
        { return; }

        FCk_Handle Bed = _Control;
        for (auto Node : utils_fphands::Get_TransformTree(Bed))
        {
            const auto Components = utils_unreal_component::Get_ComponentsByType(Node, UMars_ScreamingTurnipPresentationComponent);
            if (Components.Num() == 1)
            { _HeldPresentation = Cast<UMars_ScreamingTurnipPresentationComponent>(Components[0]); }
        }

        if (ck::IsValid(_HeldPresentation))
        { _HeldPresentationFrame = int64(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void Is_ClientHeldPresentationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsBedFound() == false || ck::Is_NOT_Valid(_Control))
        {
            Result.Set(false);
            return;
        }

        const auto Frame = int64(utils_time::Get_FrameCounter());
        if (_HeldBedFoundFrame < 0)
        { _HeldBedFoundFrame = Frame; }

        if (_HeldHolderFrame < 0 && _Control.Get_GripHolder() == EMars_Control_GripHolder::AnotherMachine)
        { _HeldHolderFrame = Frame; }

        Find_HeldPresentation();
        Result.Set(_HeldHolderFrame >= 0 && ck::IsValid(_HeldPresentation) && _HeldPresentation.Get_HasMesh());
    }

    UFUNCTION()
    private void OnClientHeldPresentationReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientSampled", n"OnClientSampled", k_SlowPolls);
    }

    // Samples the presentation's clip every frame until k_SampleSeconds have passed since the first sample.
    UFUNCTION()
    private void Is_ClientSampled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_HeldPresentation) || ck::Is_NOT_Valid(_Control))
        {
            Result.Set(false);
            return;
        }

        const auto Now = float64(System::GetGameTimeInSeconds());
        if (_HeldSamplingSince.IsSet() == false)
        { _HeldSamplingSince = Now; }

        const auto Clip = _HeldPresentation.Get_PlayingClip();
        const auto Alpha = _HeldPresentation.Get_PlayedAlpha();
        if (_HeldSampleCount == 0)
        {
            _HeldFirstClip = Clip;
            _HeldFirstAlpha = Alpha;
        }

        _HeldLastClip = Clip;
        _HeldLastAlpha = Alpha;
        _HeldSampleCount += 1;
        if (Clip == constants_screaming_turnip_assets::k_Clip_PlantedIdle)
        { _HeldIdleSamples += 1; }

        Result.Set(Now - _HeldSamplingSince.GetValue() >= k_SampleSeconds);
    }

    UFUNCTION()
    private void OnClientSampled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Shown = _Control.TryGet_ShownGripAlpha();
        const auto ShownText = Shown.IsSet() ? f"{Shown.GetValue() :.3}" : "unset";
        const auto Line = f"[TurnipNetTest] ACopyBornWhileHeldShowsTheStrain client: holder {_Control.Get_GripHolder() :n}, samples {_HeldSampleCount}, idleSamples {_HeldIdleSamples}, first {_HeldFirstClip} {_HeldFirstAlpha :.3}, last {_HeldLastClip} {_HeldLastAlpha :.3}, shownGripAlpha {ShownText}, frames bedFound {_HeldBedFoundFrame} holder {_HeldHolderFrame} presentation {_HeldPresentationFrame}, {Get_BedText()}";
        Log(Line);

        Assert_True(_HeldSampleCount > 0 && _HeldIdleSamples == 0,
            f"no sample played {constants_screaming_turnip_assets::k_Clip_PlantedIdle} (got {_HeldIdleSamples} of {_HeldSampleCount})");
        Assert_True(_HeldLastClip == constants_screaming_turnip_assets::k_Clip_Tug,
            f"the last sample plays {constants_screaming_turnip_assets::k_Clip_Tug} (got {_HeldLastClip})");
        Assert_True(Shown.IsSet() && Math::Abs(_HeldLastAlpha - Shown.GetValue()) <= k_PlayedAlphaTolerance,
            f"the last sample's played alpha follows the shown grip alpha (got {_HeldLastAlpha :.3} vs {ShownText})");
        Assert_True(Count_HolderChangesTo(EMars_Control_GripHolder::AnotherMachine) == 1,
            f"the client raised OnGripHolderChanged to AnotherMachine exactly once (got [{Get_HolderChangesText()}])");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        WaitUntil(n"Is_StandInFound", n"OnServerStandInFound", k_SlowPolls);
    }

    // The bed grips itself with the stand-in as it composes.
    UFUNCTION()
    private void OnServerStandInFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_ScreamingTurnipBed_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Location);
        Params.Pull = _BedPull;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_NetScreamingTurnipBed_BornHeld_EntityScript, Params);
        WaitUntil(n"Is_BedFound", n"OnServerBedFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerBedFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_HeldSeconds, n"OnServerHeldPull");
    }

    UFUNCTION()
    private void OnServerHeldPull(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::LetGo);
        WaitSeconds(k_ServerHoldSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Line = f"[TurnipNetTest] ACopyBornWhileHeldShowsTheStrain server: {Get_BedText()}";
        Log(Line);
        Assert_True(_Control.Get_IsGripped() == false && _Control.Get_LastGripRelease() == EMars_Control_GripRelease::Ended,
            f"the stand-in's grip was released Ended (got {_Control.Get_LastGripRelease() :n})");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
