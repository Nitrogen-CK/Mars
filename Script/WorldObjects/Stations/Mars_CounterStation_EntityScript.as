namespace constants_station
{
    // A counter station's operator stands this far in front of its counter's near (-X) edge: close in, the capsule (radius
    // 39) almost touching it.
    const float64 k_StandGap = 43.0;

    // The Use probe's margin around a counter.
    const float64 k_ProbePadding = 5.0;

    // A palm's thickness: the glove's grip bone above what its palm rests on (FMars_FPHands_Spec.PalmSurfaceOffset).
    const float64 k_PalmLift = 2.5;

    const float32 k_LabelWorldSize = 10.0f;

    // How long the label's last line says why a press or an interaction at the station did nothing.
    const float32 k_RefusalFlashSeconds = 2.0f;

    // How often the label re-reads the station's state between the edges that refresh it at once (a refusal, its expiry,
    // a station's own signal): its counts and percentages may lag by this much.
    const float32 k_LabelRefreshSeconds = 0.2f;

    // The reused burst a station plays where something happens (the SparksBurst behavior).
    const int32 k_BurstBehavior = 13;
    const float32 k_BurstSize = 0.35f;
    const float32 k_BurstColorIntensity = 0.8f;
    const float32 k_BurstPlaybackSpeed = 1.6f;
}

// The base of a station built on a counter (a table of Get_CounterFootprint at k_CounterHeight): the stand Get_StandGap in
// front of its near edge, the Use probe round it, the station's kernel composed after the Station (Prepare_Kernel before
// the base, Compose_Kernel after it), and the dressing: a tick that runs the station's Dress and keeps the world label
// (AddLabel: one cached text over Get_StateLabel, whose last line says, for k_RefusalFlashSeconds, why a press or an
// interaction at the station did nothing: Flash_Refusal, and every failed interaction on the station's own targets). The
// label re-reads the state on its own edges and every k_LabelRefreshSeconds, never every frame.
UCLASS(Abstract)
class UMars_CounterStation_EntityScript : UMars_Station_EntityScript
{
    // The station's root (set in AddVisuals by the station).
    protected FCk_Handle_Transform _Root;

    private FCk_Handle_Timer _DressingTick;
    private FCk_Handle_UnrealComponent _Label;
    // The text last written to the label: it is rewritten only when it changes.
    private FString _LabelText;
    // The label's last line while _FlashSecondsLeft runs.
    private FString _FlashText;
    private float32 _FlashSecondsLeft = 0.0f;
    private float32 _LabelRefreshLeft = 0.0f;
    // The station's own interactables whose failed interactions the label says.
    private TArray<FCk_Handle_Interactable> _FailureSources;
    // The entity script is a UObject, not a fragment, so it may hold the component.
    private UNiagaraComponent _Burst;

    // The base composes the transform, the visuals and nodes (AddVisuals) and the Station (Configure_Spec, grips on the
    // registered nodes); the kernel and what follows it need the station, so they are composed after, and their signals are
    // bound then, not at begin play, so no edge can be missed.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        Prepare_Kernel();
        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to work at.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        if (Compose_Kernel(InHandle) == false)
        { return Flow; }

        Compose_AfterKernel(InHandle);
        Watch_Failures(StationHandle.Get_Interactable());

        // The timer dies with the entity; nothing to unbind.
        if (Get_HasDressing())
        { _DressingTick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDressingTick")); }

        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLabelAdded")); }

        Refresh_Label();
    }

    // The label is a hosted entity: it dies with the station. Only the burst is spawned loose.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        for (int32 Index = 0; Index < _FailureSources.Num(); ++Index)
        {
            auto Interactable = _FailureSources[Index];
            if (ck::IsValid(Interactable))
            { Interactable.UnbindFrom_OnInteractionFailed(FMars_Delegate_Interactable_OnInteractionFailed(this, n"OnTargetInteractionFailed")); }
        }

        _FailureSources.Empty();

        if (ck::IsValid(_Burst))
        { _Burst.DestroyComponent(); }

        _Burst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    // The stand Get_StandGap in front of the counter's near edge, then the station's own operation.
    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(Get_CounterFootprint().X * 0.5 + Get_StandGap()), 0.0, 0.0));
        Configure_Operation(InOutSpec);
    }

    // The Use probe: the counter's footprint and height, k_ProbePadding all round.
    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        const auto Footprint = Get_CounterFootprint();
        const auto Padding = constants_station::k_ProbePadding;
        const auto Height = constants_station::k_CounterHeight;

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(Footprint.X * 0.5 + Padding, Footprint.Y * 0.5 + Padding, Height * 0.5 + Padding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, Height * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Counter station hooks (each station overrides what differs)
    //----------------------------------------------------------------------------------------------------------------------

    // Before the base composes the station: the kernel spec the visuals read.
    protected void Prepare_Kernel()
    {
    }

    // After the station: composes the station's kernel and binds its signals. False = there is none (it already ensured),
    // and the station stands without anything that follows the kernel or any dressing.
    protected bool Compose_Kernel(FCk_Handle& InHandle)
    {
        return true;
    }

    // After the kernel: what the station composes on top of it (a feed station's feed and docks).
    protected void Compose_AfterKernel(FCk_Handle& InHandle)
    {
    }

    // The station's grips, its camera, its prompt and its minigame. The base sets the stand.
    protected void Configure_Operation(FMars_Station_Spec& InOutSpec)
    {
    }

    // The counter's depth (X) and width (Y): the stand and the Use probe are built from it.
    protected FVector2D Get_CounterFootprint() const
    {
        return FVector2D(0.0, 0.0);
    }

    protected float64 Get_StandGap() const
    {
        return constants_station::k_StandGap;
    }

    // False: no dressing tick (nothing to dress, no label).
    protected bool Get_HasDressing() const
    {
        return true;
    }

    // Every frame, before the station's Dress: the base's own presentation (a feed station's glove and piece looks).
    protected void Advance_Presentation(float32 InDeltaSeconds)
    {
    }

    // Every frame, before the label: the station's own dressing.
    protected void Dress(float32 InDeltaSeconds)
    {
    }

    // What the label reads; the base adds the refusal line.
    protected FText Get_StateLabel() const
    {
        return FText();
    }

    // The label's text height in world units.
    protected float32 Get_LabelWorldSize() const
    {
        return constants_station::k_LabelWorldSize;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Building blocks for the stations
    //----------------------------------------------------------------------------------------------------------------------

    // The label at InLocalTransform under the root (yaw it to face the operator), tagged TAG_MarsStationLabel so a test can
    // read it back. Its text is set once the component exists. Called from AddVisuals, after _Root is set.
    protected void AddLabel(FTransform InLocalTransform, EVerticalTextAligment InVerticalAlignment, FName InDebugName)
    {
        auto Node = utils_scene_node::Create(_Root, InLocalTransform);

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetVerticalAlignment(InVerticalAlignment);
        Archetype.SetWorldSize(Get_LabelWorldSize());
        Archetype.SetTextRenderColor(constants_ui_colors::k_StationLabel);
        Archetype.SetText(FText::FromString(""));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        _Label = utils_unreal_component::Add(Node, ComponentParams);
        if (ck::IsValid(_Label))
        { utils_entity_tag::Add(_Label, n"TAG_MarsStationLabel"); }
    }

    // The label's last line reads InText for k_RefusalFlashSeconds.
    protected void Flash_Refusal(const FString& InText)
    {
        _FlashText = InText;
        _FlashSecondsLeft = constants_station::k_RefusalFlashSeconds;
        Refresh_Label();
    }

    // InInteractable's failed interactions flash on the label.
    protected void Watch_Failures(FCk_Handle_Interactable InInteractable)
    {
        if (ck::Is_NOT_Valid(InInteractable))
        { return; }

        auto Interactable = InInteractable;
        Interactable.BindTo_OnInteractionFailed(FMars_Delegate_Interactable_OnInteractionFailed(this, n"OnTargetInteractionFailed"));
        _FailureSources.Add(Interactable);
    }

    // One reused burst component: spawned at the first call whose template is ready (a cold template never stalls the game
    // thread; that call just goes without a burst), then moved to InLocation and re-activated. None under nullrhi.
    protected void Play_Burst(FVector InLocation, FRotator InRotation)
    {
        if (ck::IsValid(_Burst))
        {
            _Burst.SetWorldLocation(InLocation);
            _Burst.Activate(true);
            return;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(constants_station::k_BurstBehavior) == false)
        { return; }

        _Burst = utils_particles::Spawn_BehaviorAtLocation(constants_station::k_BurstBehavior, InLocation, InRotation);
        if (ck::IsValid(_Burst))
        {
            utils_particles::Request_ApplyTuningValues(_Burst, constants_station::k_BurstSize, constants_station::k_BurstColorIntensity,
                1.0f, constants_station::k_BurstPlaybackSpeed);
        }
    }

    // Rewritten only when the text changes. Null until the component is created (asynchronously); OnLabelAdded refreshes
    // then.
    protected void Refresh_Label()
    {
        _LabelRefreshLeft = constants_station::k_LabelRefreshSeconds;
        if (ck::Is_NOT_Valid(_Label))
        { return; }

        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        auto LabelText = Get_StateLabel().ToString();
        if (_FlashText.IsEmpty() == false)
        { LabelText = f"{LabelText}\n{_FlashText}"; }

        if (LabelText == _LabelText)
        { return; }

        _LabelText = LabelText;
        Text.SetText(FText::FromString(LabelText));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the kernel is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDressingTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        Advance_Presentation(DeltaSeconds);
        Dress(DeltaSeconds);
        Advance_Label(DeltaSeconds);
    }

    // A flash that runs out refreshes at once; otherwise the label re-reads the state every k_LabelRefreshSeconds.
    private void Advance_Label(float32 InDeltaSeconds)
    {
        if (_FlashText.IsEmpty() == false)
        {
            _FlashSecondsLeft -= InDeltaSeconds;
            if (_FlashSecondsLeft <= 0.0f)
            {
                _FlashText = "";
                Refresh_Label();
                return;
            }
        }

        _LabelRefreshLeft -= InDeltaSeconds;
        if (_LabelRefreshLeft <= 0.0f)
        { Refresh_Label(); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLabelAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnTargetInteractionFailed(FCk_Handle_Interactable InInteractable, FMars_Interactable_Failure InFailure)
    {
        Flash_Refusal(Get_FailText(InFailure.Reason));
    }

    private FString Get_FailText(EMars_Interaction_FailReason InReason) const
    {
        if (InReason == EMars_Interaction_FailReason::GlovesLeftBeforeGrip)
        { return "let go too soon"; }

        if (InReason == EMars_Interaction_FailReason::GlovesLostTarget)
        { return "lost hold"; }

        if (InReason == EMars_Interaction_FailReason::PlaceReachRefused || InReason == EMars_Interaction_FailReason::PlaceReachUnanswered)
        { return "hands busy"; }

        if (InReason == EMars_Interaction_FailReason::NowhereToStow)
        { return "nowhere to stow it"; }

        if (InReason == EMars_Interaction_FailReason::TransferRefused)
        { return "it does not fit"; }

        if (InReason == EMars_Interaction_FailReason::PlatterFull)
        { return "platter full"; }

        if (InReason == EMars_Interaction_FailReason::NoFoodInHand)
        { return "no food in hand"; }

        if (InReason == EMars_Interaction_FailReason::ReleaseRefused)
        { return "cannot let go of it"; }

        if (InReason == EMars_Interaction_FailReason::LoadRefused)
        { return "the platter refused it"; }

        if (InReason == EMars_Interaction_FailReason::LeftTheBooks)
        { return "it was taken"; }

        if (InReason == EMars_Interaction_FailReason::NoLongerDocked)
        { return "no longer docked"; }

        if (InReason == EMars_Interaction_FailReason::DockRefused)
        { return "the dock refused it"; }

        if (InReason == EMars_Interaction_FailReason::UndockRefused)
        { return "cannot take it now"; }

        // ActionBlocked: the prompt lagged the hands by a frame.
        return "not now";
    }
}
