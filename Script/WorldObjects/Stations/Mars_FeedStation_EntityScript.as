namespace constants_station
{
    // A feed station's operator stands this far in front of its counter's near (-X) edge: close in, the capsule (radius 39)
    // almost touching it.
    const float64 k_StandGap = 43.0;

    // The Use probe's margin around a feed station's counter.
    const float64 k_ProbePadding = 5.0;

    // A palm's thickness: the glove's grip bone above what its palm rests on (FMars_FPHands_Spec.PalmSurfaceOffset).
    const float64 k_PalmLift = 2.5;

    // A carried piece's nominal half extent: the feed's glove holds a piece's middle this far under its palm.
    const float64 k_CarriedHalfExtent = 6.0;

    const float32 k_LabelWorldSize = 10.0f;

    // How long the label's last line says why a press or an interaction at the station did nothing.
    const float32 k_RefusalFlashSeconds = 2.0f;

    // The reused burst a station plays where something happens (the SparksBurst behavior).
    const int32 k_BurstBehavior = 13;
    const float32 k_BurstSize = 0.35f;
    const float32 k_BurstColorIntensity = 0.8f;
    const float32 k_BurstPlaybackSpeed = 1.6f;

    // The scene node under a piece that carries its battered shell (utils_station::Write_PieceLook).
    const FName k_BatteredShellTag = n"TAG_MarsBatteredShell";
}

// The station's record of one piece its kernel admitted. The piece wears its own display (or, battered, its food's battered
// shell); the station adds no part of its own to it.
struct FMars_Station_PieceDisplay
{
    UPROPERTY()
    FMars_CookingFeed_PieceId Id;

    UPROPERTY()
    FCk_Handle Entity;

    UPROPERTY()
    FCk_Handle_FoodPiece Piece;

    // This piece's look; a lost piece keeps its last one.
    UPROPERTY()
    FMars_CookState CookState;

    // The look last sent to the piece's display.
    UPROPERTY()
    FMars_CookState Written;
}

namespace utils_station
{
    // InPiece's record: its look as its ledger says it arrived (utils_cookstate::Make_DisplayParams; Jolt owns its pose), sent
    // to its display at once.
    FMars_Station_PieceDisplay Make_PieceDisplay(const FMars_CookingFeed_PieceId& InPieceId, FCk_Handle InPiece)
    {
        auto Display = FMars_Station_PieceDisplay();
        Display.Id = InPieceId;
        Display.Entity = InPiece;
        Display.Piece = InPiece.As_FoodPiece();
        Display.CookState = utils_cookstate::Make_DisplayParams(Display.Piece.Get_CookState());
        if (Write_PieceLook(Display.Piece, Display.CookState))
        { Display.Written = Display.CookState; }

        return Display;
    }

    // The display follows the look on its edges, never per frame: a write once any float has moved by the threshold since
    // the last one. A piece without a display (a bare test piece) is legal and gets none.
    void Write_PieceDisplay(FMars_Station_PieceDisplay& InOutDisplay)
    {
        if (utils_cookstate::Get_HasMovedBeyond(InOutDisplay.Written, InOutDisplay.CookState, constants_cookstate::k_WriteThreshold) == false)
        { return; }

        if (Write_PieceLook(InOutDisplay.Piece, InOutDisplay.CookState))
        { InOutDisplay.Written = InOutDisplay.CookState; }
    }

    // The one place a piece's look (InLook, its 14 cook-state floats) reaches what the piece wears: its RuntimeMesh display,
    // and, while it is a battered whole piece of a batterable food (utils_batter::Get_IsBatterable), the battered shell its
    // food shows in the display's place: made, and the display hidden, the first time the look says battered. Every write
    // reaches both, so the shell and the hidden display always carry the same block. False for a piece without a display
    // (a bare test piece, or one not dressed yet), which wears nothing.
    bool Write_PieceLook(FCk_Handle_FoodPiece InPiece, const FMars_CookState& InLook)
    {
        FCk_Handle Entity = InPiece;
        if (Entity.Is_RuntimeMeshDisplay() == false)
        { return false; }

        auto Display = Entity.As_RuntimeMeshDisplay();
        utils_cookstate::Request_Write(Display, InLook);

        if (InLook.Battered < 0.5f || utils_batter::Get_IsBatterable(InPiece) == false)
        { return true; }

        auto Shell = TryGet_BatteredShell(InPiece);
        if (ck::Is_NOT_Valid(Shell))
        { Shell = Add_BatteredShell(InPiece, Display); }

        if (ck::IsValid(Shell))
        { utils_cookstate::Request_WriteComponent(Shell, InLook); }

        return true;
    }

    // The battered shell Write_PieceLook made under InPiece; invalid while it wears none.
    FCk_Handle_UnrealComponent TryGet_BatteredShell(FCk_Handle_FoodPiece InPiece)
    {
        FCk_Handle Entity = InPiece;
        for (auto Dependent : utils_entity_lifetime::Get_LifetimeDependents(Entity))
        {
            if (ck::Is_NOT_Valid(Dependent) || utils_entity_tag::Has(Dependent, constants_station::k_BatteredShellTag) == false)
            { continue; }

            const auto Components = utils_unreal_component::Get_AllHandles(Dependent);
            if (Components.Num() > 0)
            { return Components[0]; }
        }

        return FCk_Handle_UnrealComponent();
    }

    // InPiece's food's battered mesh on a tagged scene node under the piece at its pivot offset (no collision: the piece's
    // RuntimeMesh stays its body), and InDisplay hidden. A battered mesh that does not load ensures, and the piece keeps
    // showing its display.
    FCk_Handle_UnrealComponent Add_BatteredShell(FCk_Handle_FoodPiece InPiece, FCk_Handle_RuntimeMeshDisplay InDisplay)
    {
        const UMars_Food_Def Food = InPiece.Get_Definition().Get();
        const auto Battered = Food.Visuals.Battered;
        auto Mesh = System::LoadAsset_Blocking(Battered.Mesh);
        if (ck::EnsureIfNot(ck::IsValid(Mesh),
            f"[Station] [{Food.GetName()}] battered mesh [{Battered.Mesh.ToSoftObjectPath().ToString()}] did not load: piece [{InPiece.ToString()}] keeps its display"))
        { return FCk_Handle_UnrealComponent(); }

        FCk_Handle Entity = InPiece;
        auto Node = utils_scene_node::Create(Entity.As_Transform(), FTransform(FRotator::ZeroRotator, Battered.PivotOffset));
        utils_entity_tag::Add(Node.H(), constants_station::k_BatteredShellTag);

        // A template the hosted component is instanced from; nothing keeps it once it has been.
        auto Archetype = NewObject(GetTransientPackage(), UStaticMeshComponent);
        // Movable: the component is registered first and then follows the piece.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(Mesh);
        for (int32 Slot = 0; Slot < Battered.Materials.Num(); ++Slot)
        { Archetype.SetMaterial(Slot, System::LoadAsset_Blocking(Battered.Materials[Slot])); }
        Archetype.SetCollisionProfileName(collision::profile::NoCollision);

        const auto Params = utils_unreal_component::Make_Params_FromArchetype(Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"Food_BatteredShell");
        const auto Shell = utils_unreal_component::Add(Node.H(), Params);

        auto Display = InDisplay;
        Display.Request_SetVisibility(FCk_Request_RuntimeMeshDisplay_SetVisibility(ECk_EnableDisable::Disable), FCk_Delegate_Request_OnCompleted());
        return Shell;
    }

    // One reused burst component: spawned at the first call whose template is ready (a cold template never stalls the game
    // thread; that call just goes without a burst), then moved to InLocation and re-activated. Returns the burst to keep;
    // null under nullrhi.
    UNiagaraComponent Play_Burst(UNiagaraComponent InBurst, FVector InLocation, FRotator InRotation)
    {
        if (ck::IsValid(InBurst))
        {
            InBurst.SetWorldLocation(InLocation);
            InBurst.Activate(true);
            return InBurst;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(constants_station::k_BurstBehavior) == false)
        { return nullptr; }

        auto Burst = utils_particles::Spawn_BehaviorAtLocation(constants_station::k_BurstBehavior, InLocation, InRotation);
        if (ck::IsValid(Burst))
        {
            utils_particles::Request_ApplyTuningValues(Burst, constants_station::k_BurstSize, constants_station::k_BurstColorIntensity,
                1.0f, constants_station::k_BurstPlaybackSpeed);
        }

        return Burst;
    }

    // A station's view (FMars_Station_CameraSpec.ViewLocal, station frame) InDistance back from InFocus along the line pitched
    // InPitchDegrees (negative looks down), so InFocus is dead centre on screen.
    FTransform Make_ViewLocal(FVector InFocus, float32 InPitchDegrees, float64 InDistance)
    {
        const auto PitchRadians = Math::DegreesToRadians(float64(-InPitchDegrees));
        return FTransform(FRotator(InPitchDegrees, 0.0, 0.0),
            FVector(InFocus.X - InDistance * Math::Cos(PitchRadians), InFocus.Y, InFocus.Z + InDistance * Math::Sin(PitchRadians)));
    }
}

// One dock on the counter top: SurfaceLocal in the station frame (Z above the top: 0 rests on it), what its prompt calls it,
// its prompt's reason when its Kind query refuses a piece (empty: the dock's own) and its marker's name.
struct FMars_FeedStation_DockSpot
{
    FVector SurfaceLocal = FVector::ZeroVector;
    FText Name;
    FText KindRejectedText;
    FName MarkerName;

    FMars_FeedStation_DockSpot() {}

    FMars_FeedStation_DockSpot(FVector InSurfaceLocal, FText InName, FName InMarkerName)
    {
        SurfaceLocal = InSurfaceLocal;
        Name = InName;
        MarkerName = InMarkerName;
    }
}

// The input platter's dock and the finished tray's.
struct FMars_FeedStation_DockLayout
{
    FMars_FeedStation_DockSpot Input;
    FMars_FeedStation_DockSpot Output;
}

// The base of a station whose entity carries a CookingFeed beside its own kernel (the searing, fry, cutting, tumbler and
// batter stations):
// the assembly every one of them shares. It composes, after the base station and the kernel (Compose_Kernel), the feed
// (its release node, its glove's hand node and the hand geometry the feed moves that node by, Add_FeedHand) and the two
// docks (Get_DockLayout) with their markers; it runs the dressing tick (the left glove's pose override, then the
// station's Dress, then the label); it owns the label (AddLabel, one cached text over Get_StateLabel), the probe and the
// stand from the counter's footprint, the left glove's feed grip and the reused burst. Where the station's food goes is
// its kernels': the feed hands each release to the station's admission inbox, and the kernel loads what it hands back onto
// the tray and takes back what the tray refuses. The label's last line says, for k_RefusalFlashSeconds, why a press or an
// interaction at the station did nothing: the feed's refusals and let-go pieces, any failed interaction on the station's
// own targets (its Use and its docks) and whatever the station's kernel refuses (Flash_Refusal).
UCLASS(Abstract)
class UMars_FeedStation_EntityScript : UMars_Station_EntityScript
{
    // The transfer's timing and release motion; its nodes and its held offset are set here. The stock is the platter docked
    // on the input dock.
    UPROPERTY(ExposeOnSpawn)
    FMars_CookingFeed_Spec Feed;

    // The input platter's and the finished tray's dock policies; each station sets its own defaults.
    UPROPERTY(EditDefaultsOnly, Category = "Docks")
    FMars_Station_DockPolicies Docks;

    protected FCk_Handle_Transform _Root;
    protected FCk_Handle_CookingFeed _FeedHandle;
    // Where the feed's glove lets a carried piece go (the station builds it in AddVisuals).
    protected FCk_Handle_Transform _ReleaseNode;

    // The left glove's grip (Station.Node.Feed): the feed moves it through each transfer by _FeedHandGeometry and carries its
    // piece under it.
    private FCk_Handle_SceneNode _FeedHandNode;
    private FMars_CookingFeed_HandGeometry _FeedHandGeometry;
    // The carried piece's middle under the hand node (the feed's Motion.HeldOffset).
    private FTransform _FeedHeldLocal;
    // The left glove's pose override.
    private FMars_StationFeed_Presentation _FeedPresentation;
    private FCk_Handle_PlatterDock _InputDock;
    private FCk_Handle_PlatterDock _OutputDock;
    private FCk_Handle_Timer _DressingTick;
    private FCk_Handle_UnrealComponent _Label;
    // The text last written to the label: it is rewritten only when it changes.
    private FString _LabelText;
    // The label's last line while _FlashSecondsLeft runs.
    private FString _FlashText;
    private float32 _FlashSecondsLeft = 0.0f;
    // The station's own interactables whose failed interactions the label says.
    private TArray<FCk_Handle_Interactable> _FailureSources;
    // The entity script is a UObject, not a fragment, so it may hold the component.
    private UNiagaraComponent _Burst;

    // The base composes the transform, the visuals and nodes (AddVisuals) and the Station (Configure_Spec, grips on the
    // registered nodes); the kernel, then the feed and the docks, need the station, so they are composed after.
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

        Compose_Feed(InHandle);

        // The timer dies with the entity; nothing to unbind.
        _DressingTick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDressingTick"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnLabelAdded")); }

        Refresh_Label();
    }

    // The label and the docks are hosted entities: they die with the station. Only the burst is spawned loose.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_FeedHandle))
        {
            _FeedHandle.UnbindFrom_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnFeedTransferRefused"));
            _FeedHandle.UnbindFrom_OnPieceLetGo(FMars_Delegate_CookingFeed_OnPieceLetGo(this, n"OnFeedPieceLetGo"));
        }

        for (int32 Index = 0; Index < _FailureSources.Num(); ++Index)
        {
            auto Interactable = _FailureSources[Index];
            if (ck::IsValid(Interactable))
            { Interactable.UnbindFrom_OnInteractionFailed(FMars_Delegate_Interactable_OnInteractionFailed(this, n"OnTargetInteractionFailed")); }
        }

        _FailureSources.Empty();
        _FeedPresentation.Clear(FCk_Handle());

        if (ck::IsValid(_Burst))
        { _Burst.DestroyComponent(); }

        _Burst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    // The stand k_StandGap in front of the counter's near edge, the station's own operation, then the left glove's grip:
    // the feed node lays it palm down (at rest, and through each transfer).
    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator,
            FVector(-(Get_CounterFootprint().X * 0.5 + constants_station::k_StandGap), 0.0, 0.0));
        Configure_Operation(InOutSpec);
        InOutSpec.Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Feed, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
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

    // A station adds its tool's node and calls this.
    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Feed, _FeedHandNode.As_Transform()));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Feed station hooks (each station overrides what differs)
    //----------------------------------------------------------------------------------------------------------------------

    // Before the base composes the station: the kernel spec the visuals read.
    protected void Prepare_Kernel()
    {
    }

    // After the station: composes the station's kernel and binds its signals. False = there is none (it already ensured),
    // and the station stands without a feed, docks or dressing.
    protected bool Compose_Kernel(FCk_Handle& InHandle)
    {
        return true;
    }

    // The station's own grips (the right glove's tool), its camera, its prompt and its minigame. The base sets the stand and
    // adds the feed's grip.
    protected void Configure_Operation(FMars_Station_Spec& InOutSpec)
    {
    }

    // The counter's depth (X) and width (Y): the stand and the Use probe are built from it.
    protected FVector2D Get_CounterFootprint() const
    {
        return FVector2D(0.0, 0.0);
    }

    protected FMars_FeedStation_DockLayout Get_DockLayout() const
    {
        return FMars_FeedStation_DockLayout();
    }

    // Every frame, after the feed's presentation and before the label: the station's own dressing.
    protected void Dress(float32 InDeltaSeconds)
    {
    }

    // What the label reads; the base adds the refusal line.
    protected FText Get_StateLabel() const
    {
        return FText();
    }

    // What the label says when the station's own gate refused an add-food press.
    protected FString Get_StationGateText() const
    {
        return "station busy";
    }

    // The label's text height in world units.
    protected float32 Get_LabelWorldSize() const
    {
        return constants_station::k_LabelWorldSize;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Building blocks for the stations
    //----------------------------------------------------------------------------------------------------------------------

    // The feed node the left glove follows, at rest palm down with fingers forward k_PalmLift over InPalmRestLocal (station
    // frame, on the surface it rests on); the feed carries a piece's middle k_CarriedHalfExtent under the palm,
    // world-aligned, and moves the node itself (the glove stops so that middle lands on the piece and on the release node).
    // Called from AddVisuals, after _Root is set.
    protected void Add_FeedHand(FVector InPalmRestLocal)
    {
        const auto HandRotation = utils_fphands::Make_GripRotation(EMars_Hand::Left, FVector::ForwardVector, -FVector::UpVector);
        auto Geometry = FMars_StationFeed_Geometry();
        Geometry.RestLocal = FTransform(HandRotation, InPalmRestLocal + FVector(0.0, 0.0, constants_station::k_PalmLift));
        Geometry.HeldLocal = FTransform(HandRotation.Inverse(),
            FVector(0.0, 0.0, constants_station::k_PalmLift + constants_station::k_CarriedHalfExtent));

        _FeedHandGeometry = Geometry.Make_HandGeometry();
        _FeedHeldLocal = Geometry.HeldLocal;
        _FeedHandNode = utils_scene_node::Create(_Root, Geometry.RestLocal);
    }

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

    // A take-out that handed nothing back, as the label says it.
    protected void Flash_TakeOutRefusal(EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        if (InRefusal == EMars_CookingFeed_TakeOutRefusal::NoRoom)
        {
            Flash_Refusal(Get_NoRoomText());
            return;
        }

        Flash_Refusal("nothing ready");
    }

    // A hand-off capped at nothing: the tray is full, or there is none.
    protected FString Get_NoRoomText() const
    {
        if (Get_HasTray())
        { return "tray full"; }

        return "no tray";
    }

    // The platter docked on the finished tray's dock; invalid with none.
    protected FCk_Handle_Platter Get_Tray() const
    {
        if (ck::Is_NOT_Valid(_OutputDock))
        { return FCk_Handle_Platter(); }

        return _OutputDock.Get_Platter();
    }

    protected bool Get_HasTray() const
    {
        return ck::IsValid(Get_Tray());
    }

    protected void Play_Burst(FVector InLocation, FRotator InRotation)
    {
        _Burst = utils_station::Play_Burst(_Burst, InLocation, InRotation);
    }

    // Rewritten only when the text changes. Null until the component is created (asynchronously); OnLabelAdded refreshes
    // then.
    protected void Refresh_Label()
    {
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
    // Composition
    //----------------------------------------------------------------------------------------------------------------------

    private void Compose_Feed(FCk_Handle& InHandle)
    {
        // A rejected feed spec already ensured in utils_cooking_feed::Add; the kernel still works without a platter.
        auto FeedSpec = Feed;
        FeedSpec.Nodes = FMars_CookingFeed_Nodes(_ReleaseNode, _FeedHandNode.As_Transform());
        FeedSpec.Motion.HeldOffset = _FeedHeldLocal;
        FeedSpec.Hand = TOptional<FMars_CookingFeed_HandGeometry>(_FeedHandGeometry);
        _FeedHandle = utils_cooking_feed::Add(InHandle, FeedSpec);
        if (ck::IsValid(_FeedHandle))
        {
            _FeedHandle.BindTo_OnTransferRefused(FMars_Delegate_CookingFeed_OnTransferRefused(this, n"OnFeedTransferRefused"));
            _FeedHandle.BindTo_OnPieceLetGo(FMars_Delegate_CookingFeed_OnPieceLetGo(this, n"OnFeedPieceLetGo"));
        }

        const auto Layout = Get_DockLayout();
        _InputDock = Add_Dock(EMars_PlatterDock_Role::Input, Layout.Input);
        _OutputDock = Add_Dock(EMars_PlatterDock_Role::Output, Layout.Output);

        Watch_Failures(InHandle.As_Station().Get_Interactable());
        if (ck::IsValid(_InputDock))
        { Watch_Failures(_InputDock.Get_Interactable()); }

        if (ck::IsValid(_OutputDock))
        { Watch_Failures(_OutputDock.Get_Interactable()); }
    }

    // A dock on the counter top, a child of the root (it dies with the station), lifted so a docked platter's underside rests
    // on the top, with its marker. A rejected spec already ensured in utils_platter_dock::Create.
    private FCk_Handle_PlatterDock Add_Dock(EMars_PlatterDock_Role InRole, const FMars_FeedStation_DockSpot& InSpot)
    {
        auto Policy = Docks.Input;
        if (InRole == EMars_PlatterDock_Role::Output)
        { Policy = Docks.Output; }

        const auto DockLift = FVector(0.0, 0.0, constants_station::k_CounterHeight + constants_platter::k_FloorAboveBase);
        auto Spec = FMars_PlatterDock_Spec(InRole, Policy, FTransform(FRotator::ZeroRotator, InSpot.SurfaceLocal + DockLift));
        Spec.Name = InSpot.Name;
        Spec.KindRejectedText = InSpot.KindRejectedText;

        auto Dock = utils_platter_dock::Create(_Root, Spec);
        if (ck::IsValid(Dock))
        { Dock.Add_Marker(this, InSpot.MarkerName); }

        return Dock;
    }

    private void Watch_Failures(FCk_Handle_Interactable InInteractable)
    {
        if (ck::Is_NOT_Valid(InInteractable))
        { return; }

        auto Interactable = InInteractable;
        Interactable.BindTo_OnInteractionFailed(FMars_Delegate_Interactable_OnInteractionFailed(this, n"OnTargetInteractionFailed"));
        _FailureSources.Add(Interactable);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the feed and the kernel are the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDressingTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        Advance_Feed(DeltaSeconds);
        Advance_Flash(DeltaSeconds);
        Dress(DeltaSeconds);
        Refresh_Label();
    }

    // The left glove's pose override follows the feed (the feed moves the glove's node and the piece rides it).
    private void Advance_Feed(float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(_FeedHandle))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Operator = _Root.H().As_Station().Get_Operator();
        _FeedPresentation.Advance(FMars_StationFeed_Frame(_FeedHandle, Operator, RootWorld, InDeltaSeconds));
    }

    private void Advance_Flash(float32 InDeltaSeconds)
    {
        if (_FlashText.IsEmpty())
        { return; }

        _FlashSecondsLeft -= InDeltaSeconds;
        if (_FlashSecondsLeft <= 0.0f)
        { _FlashText = ""; }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnLabelAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Label();
    }

    // The station's gate, or a hand mid-transfer or a source pile re-settling (Busy); an empty source is the add-food row's.
    UFUNCTION()
    private void OnFeedTransferRefused(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Refusal InRefusal)
    {
        if (InRefusal == EMars_CookingFeed_Refusal::StationGate)
        {
            Flash_Refusal(Get_StationGateText());
            return;
        }

        if (InRefusal != EMars_CookingFeed_Refusal::Busy)
        { return; }

        if (InFeed.Get_IsBusy())
        {
            Flash_Refusal("hand busy");
            return;
        }

        Flash_Refusal("settling");
    }

    UFUNCTION()
    private void OnFeedPieceLetGo(FCk_Handle_CookingFeed InFeed, FCk_Handle_FoodPiece InPiece)
    {
        Flash_Refusal("dropped: no platter to take it back");
    }

    UFUNCTION()
    private void OnTargetInteractionFailed(FCk_Handle_Interactable InInteractable, FCk_Handle_InteractTarget InTarget,
        FCk_Handle InInitiator, EMars_Interaction_FailReason InReason)
    {
        Flash_Refusal(Get_FailText(InReason));
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
