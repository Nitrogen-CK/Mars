// The dicing station: a table (width along local Y, depth along local X) with a cutting board on top, an herb pile on the
// board, a highlighted band the cleaver must be over to chop usefully, and a cleaver that slides along the board under the
// operator's hand. The operator stands StandGap uu in front of the table's -X edge facing +X; the view is Captured (the
// look delta slides the hand). The Dicing feature lives on the station entity and its own state machine
// (UMars_SmState_Dicing_Idle) reads the operator; this script only builds the nodes and moves visuals from the Dicing
// signals. While operating, the right glove holds the cleaver handle (riding the slide and the chop) and the left rests
// flat near the board's left edge, outside the cleaver's travel (the script sets the Dicing spec's BoardHalfWidth to
// HandHalfTravel).
class UMars_DicingStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Dicing_Spec Dicing;

    private const float64 TableWidth = 140.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;
    // Close in: the capsule (radius 39) stands almost touching the table edge.
    private const float64 StandGap = 43.0;
    // The operating view, pitched hard onto the board from ViewGap uu off the table edge and ViewAboveBoard uu over the
    // board top. It lives in the station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height.
    private const float32 CameraPitch = -48.0f;
    private const float64 ViewGap = 38.0;
    private const float64 ViewAboveBoard = 58.0;
    // The Use probe's margin around the table.
    private const float64 ProbePadding = 5.0;

    private const float64 BoardWidth = 90.0;
    private const float64 BoardDepth = 50.0;
    private const float64 BoardThickness = 4.0;
    private const float64 BoardX = -5.0;

    // The hand's (and the cleaver's) lateral travel each side of the board centre: the Dicing spec's BoardHalfWidth, set
    // here because it is bound to the geometry - the cleaver (and the band table's extreme fraction of it) must stop
    // short of the left glove at -(BoardWidth / 2) + LeftGripEdgeInset.
    private const float32 HandHalfTravel = 28.0f;
    // The left glove's grip, in from the board's left (-Y) edge.
    private const float64 LeftGripEdgeInset = 6.0;

    // The left glove's grip bone above the board (the palm's thickness, FMars_FPHands_Spec.PalmSurfaceOffset).
    private const float64 PalmLift = 2.5;

    // The pile and the cleaver sit over the board's middle; the band marks the strip in front of the pile (operator side),
    // just above the board so it never z-fights it.
    private const float64 PileX = 0.0;
    private const float64 BandX = -24.0;
    private const float64 BandDepth = 10.0;
    private const float64 BandLift = 0.5;
    private const float64 CleaverX = 0.0;

    // Blade 30 long (X), 2 thick (Y), 12 tall, pivot at its centre: contact puts its bottom on the board.
    private const float64 BladeHalfHeight = 6.0;
    private const float64 CleaverRaise = 25.0;
    // The handle runs from the blade's near end toward the operator, near the blade's top.
    private const FVector HandleOffset = FVector(-21.0, 0.0, 4.0);

    // The state label above the board's far edge.
    private const float64 LabelInset = 5.0;
    private const float64 LabelHeight = 40.0;
    private const float32 LabelWorldSize = 10.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);

    private const int32 k_ChopBurstBehavior = 13; // SparksBurst
    private const float64 ChopBurstLift = 1.0;
    private const float32 ChopBurstSize = 0.35f;
    private const float32 ChopBurstColorIntensity = 0.8f;
    private const float32 ChopBurstPlaybackSpeed = 1.6f;

    private FCk_Handle_Transform _Root;
    // Dicing with the geometry-bound fields set (DoConstruct); what the feature and the visuals read.
    private FMars_Dicing_Spec _DicingSpec;
    private FCk_Handle_Dicing _DicingHandle;
    private FCk_Handle_SceneNode _PileNode;
    private FCk_Handle_SceneNode _BandNode;
    private FCk_Handle_SceneNode _LateralNode;
    private FCk_Handle_Mover _ChopMover;
    // The right glove's grip: the cleaver handle, under the Mover node so it rides the chop and the lateral slide.
    private FCk_Handle_Transform _HandleGripNode;
    // The left glove's grip: flat near the board's left edge, outside the cleaver's travel.
    private FCk_Handle_Transform _BoardGripNode;
    private FCk_Handle_UnrealComponent _PileMesh;
    private FCk_Handle_UnrealComponent _Label;
    private UNiagaraComponent _ChopBurst;
    private bool _OutlineClaimed = false;

    // The base composes the transform, the visuals and nodes (AddVisuals) and the Station (Configure_Spec, grips on the
    // registered nodes); the minigame needs the station, so it is composed after.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals reads the band and the strike from it.
        _DicingSpec = Dicing;
        _DicingSpec.BoardHalfWidth = HandHalfTravel;

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to dice on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected Dicing spec already ensured in utils_dicing::Add.
        _DicingSpec.Nodes = FMars_Dicing_Nodes(_LateralNode, _ChopMover);
        _DicingHandle = utils_dicing::Add(InHandle, _DicingSpec);
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_PileMesh))
        { utils_unreal_component::BindTo_OnAdded(_PileMesh, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_BandNode) && ck::IsValid(_Root))
        {
            UCk_Utils_Usf_Outline_UE::Set_OutlineClaim(_BandNode.H(), _Root,
                UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag(), ECk_Usf_OutlineScope::EntityAndDependents);
            _OutlineClaimed = true;
        }

        if (ck::Is_NOT_Valid(_DicingHandle))
        { return; }

        _DicingHandle.BindTo_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
        _DicingHandle.BindTo_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));
        _DicingHandle.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));

        Refresh_Pile();
        Refresh_Label();
        Move_Band(_DicingHandle.Get_BandCenter());
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_DicingHandle))
        {
            _DicingHandle.UnbindFrom_OnStateChanged(FMars_Delegate_Dicing_OnStateChanged(this, n"OnStateChanged"));
            _DicingHandle.UnbindFrom_OnBandMoved(FMars_Delegate_Dicing_OnBandMoved(this, n"OnBandMoved"));
            _DicingHandle.UnbindFrom_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
        }

        if (_OutlineClaimed && ck::IsValid(_BandNode) && ck::IsValid(_Root))
        {
            UCk_Utils_Usf_Outline_UE::Clear_OutlineClaim(_BandNode.H(), _Root,
                UCk_Utils_Usf_Outline_Settings_UE::Get_GameplayInteractionOutlineTag());
        }

        _OutlineClaimed = false;

        if (ck::IsValid(_ChopBurst))
        { _ChopBurst.DestroyComponent(); }

        _ChopBurst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(TableDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        // Both grips take their node's frame: the handle node wraps the right glove around the horizontal handle, the
        // board node lays the left glove flat on the board.
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Surface, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(FTransform(FRotator(CameraPitch, 0.0, 0.0),
            FVector(-(TableDepth * 0.5 + ViewGap), 0.0, Get_BoardTop() + ViewAboveBoard)));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "DiceHerbsPrompt", "Dice herbs"),
            NSLOCTEXT("MarsInteraction", "DicingStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Dicing_Idle;
    }

    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(TableDepth * 0.5 + ProbePadding, TableWidth * 0.5 + ProbePadding, TableHeight * 0.5 + ProbePadding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    // Engine cube and sphere are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        auto CubeMesh = engine::load::Cube();
        const auto BoardTop = Get_BoardTop();

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5), FVector(TableDepth, TableWidth, TableHeight) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"DicingStation_Table"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(BoardX, 0.0, TableHeight + BoardThickness * 0.5), FVector(BoardDepth, BoardWidth, BoardThickness) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::BlockAll, n"DicingStation_Board"));

        // The pile node is yawed 90 so its scale's X spans the board (local Y); its scale is the pile's size per state.
        _PileNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator(0.0, 90.0, 0.0), FVector(PileX, 0.0, BoardTop), Get_PileScale(EMars_Dicing_State::WholeLeaves)));
        auto PileTransform = _PileNode.As_Transform();
        _PileMesh = PileTransform.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity,
            engine::load::Sphere(), assets::load::ProtoGrid_Item_Mars_MI(), collision::profile::NoCollision, n"DicingStation_Pile"));

        // The band: a flat slab across the strip in front of the pile, centred on the band; outlined in DoBeginPlay.
        _BandNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::ZeroRotator, FVector(BandX, utils_dicing::Get_BandCenterAt(_DicingSpec, 0), BoardTop + BandLift)));
        auto BandTransform = _BandNode.As_Transform();
        BandTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(BandDepth * 0.01, _DicingSpec.BandHalfWidth * 0.02, 0.01)),
            CubeMesh, assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"DicingStation_Band"));

        _Label = AddLabel(InRoot,
            FTransform(FRotator(0.0, 180.0, 0.0), FVector(TableDepth * 0.5 - LabelInset, 0.0, BoardTop + LabelHeight)));

        // Grip frame (X across the palm toward the index finger, Z out of the palm): a left hand flat on the board with its
        // fingers forward has its index side to the right (+Y) and its palm down (-Z); the grip bone sits a palm's
        // thickness above the surface.
        _BoardGripNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::MakeFromXZ(FVector::RightVector, -FVector::UpVector),
                FVector(BoardX, -BoardWidth * 0.5 + LeftGripEdgeInset, BoardTop + PalmLift))).As_Transform();

        AddCleaver(InRoot);
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandleGripNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _BoardGripNode));
    }

    // The cleaver: a lateral node the hand slides along the board (Y), a Mover node under it for the chop (Z), the blade
    // and handle parts, and the handle's grip node, all under the Mover node so they ride both.
    private void AddCleaver(FCk_Handle_Transform& InRoot)
    {
        _LateralNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(CleaverX, 0.0, Get_BoardTop())));
        auto LateralTransform = _LateralNode.As_Transform();
        auto CleaverNode = utils_scene_node::Create(LateralTransform,
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, BladeHalfHeight + CleaverRaise)));

        // One Duration for both directions: the recover takes ChopDownSeconds too.
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 0.0, BladeHalfHeight + CleaverRaise);
        MoverSpec.EndLocation = FVector(0.0, 0.0, BladeHalfHeight);
        MoverSpec.Duration = _DicingSpec.ChopDownSeconds;
        MoverSpec.Easing = ECk_TweenEasing::InQuad;
        _ChopMover = utils_mover::Add(CleaverNode, MoverSpec);

        auto CubeMesh = engine::load::Cube();
        auto CleaverTransform = CleaverNode.As_Transform();
        auto ToolMaterial = assets::load::ProtoGrid_Interactable_Mars_MI();
        CleaverTransform.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(0.3, 0.02, 0.12)),
            CubeMesh, ToolMaterial, collision::profile::NoCollision, n"DicingStation_Blade"));
        CleaverTransform.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, HandleOffset, FVector(0.12, 0.025, 0.025)),
            CubeMesh, ToolMaterial, collision::profile::NoCollision, n"DicingStation_Handle"));

        // Grip frame (X across the palm toward the index finger, Z out of the palm): along the handle toward the blade
        // (+X), palm facing the operator's left (-Y) - a handshake grip on a horizontal handle, blade edge down.
        _HandleGripNode = utils_scene_node::Create(CleaverTransform,
            FTransform(FRotator::MakeFromXZ(FVector::ForwardVector, -FVector::RightVector), HandleOffset)).As_Transform();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals (the Dicing feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    private float64 Get_BoardTop() const
    {
        return TableHeight + BoardThickness;
    }

    private FVector Get_PileScale(EMars_Dicing_State InState) const
    {
        switch (InState)
        {
            case EMars_Dicing_State::WholeLeaves: return FVector(0.5, 0.35, 0.22);
            case EMars_Dicing_State::CoarseChop: return FVector(0.5, 0.38, 0.14);
            case EMars_Dicing_State::FineFlecks: return FVector(0.55, 0.42, 0.08);
            default: return FVector(0.6, 0.45, 0.04);
        }
    }

    private FLinearColor Get_PileColor(EMars_Dicing_State InState) const
    {
        switch (InState)
        {
            case EMars_Dicing_State::WholeLeaves: return FLinearColor(0.25f, 0.55f, 0.2f, 1.0f);
            case EMars_Dicing_State::CoarseChop: return FLinearColor(0.2f, 0.5f, 0.18f, 1.0f);
            case EMars_Dicing_State::FineFlecks: return FLinearColor(0.3f, 0.6f, 0.25f, 1.0f);
            default: return FLinearColor(0.12f, 0.35f, 0.1f, 1.0f);
        }
    }

    private void Refresh_Pile()
    {
        if (ck::Is_NOT_Valid(_DicingHandle))
        { return; }

        const auto State = _DicingHandle.Get_MaterialState();
        if (ck::IsValid(_PileNode))
        { utils_scene_node::Request_UpdateOffset_Scale(_PileNode, Get_PileScale(State), ECk_RelativeAbsolute::Absolute); }

        if (ck::Is_NOT_Valid(_PileMesh))
        { return; }

        // Null until the component is created (asynchronously); OnPartAdded refreshes then.
        auto Mesh = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(_PileMesh));
        if (ck::Is_NOT_Valid(Mesh))
        { return; }

        // A dynamic instance of ProtoGrid_Item (returns the existing one on later calls).
        auto Material = Mesh.CreateDynamicMaterialInstance(0);
        if (ck::Is_NOT_Valid(Material))
        { return; }

        const auto Color = Get_PileColor(State);
        Material.SetVectorParameterValue(n"PrimaryColor", Color);
        Material.SetVectorParameterValue(n"SecondaryColor", FLinearColor(Color.R * 0.7f, Color.G * 0.7f, Color.B * 0.7f, 1.0f));
        Material.SetVectorParameterValue(n"LineColor", FLinearColor(Color.R * 1.6f, Color.G * 1.6f, Color.B * 1.6f, 1.0f));
    }

    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_DicingHandle) || ck::Is_NOT_Valid(_Label))
        { return; }

        // Null until the component is created (asynchronously); OnPartAdded refreshes then.
        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        Text.SetText(utils_dicing::Get_StateLabel(_DicingHandle.Get_MaterialState(), _DicingHandle.Get_RequestedState()));
    }

    private void Move_Band(float32 InCenter)
    {
        if (ck::Is_NOT_Valid(_BandNode))
        { return; }

        utils_scene_node::Request_UpdateOffset_Location(_BandNode, FVector(BandX, InCenter, Get_BoardTop() + BandLift), ECk_RelativeAbsolute::Absolute);
    }

    // One reused burst component: spawned at the first aligned chop whose template is ready (a cold template never stalls
    // the game thread; the chop just goes without a burst), then moved and re-activated per chop. Null under nullrhi.
    private void Play_ChopBurst()
    {
        if (ck::Is_NOT_Valid(_DicingHandle) || ck::Is_NOT_Valid(_Root))
        { return; }

        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        const auto Contact = RootWorld.TransformPosition(FVector(CleaverX, _DicingHandle.Get_HandLateral(), Get_BoardTop() + ChopBurstLift));

        if (ck::IsValid(_ChopBurst))
        {
            _ChopBurst.SetWorldLocation(Contact);
            _ChopBurst.Activate(true);
            return;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(k_ChopBurstBehavior) == false)
        { return; }

        _ChopBurst = utils_particles::Spawn_BehaviorAtLocation(k_ChopBurstBehavior, Contact, RootWorld.Rotator());
        if (ck::IsValid(_ChopBurst))
        { utils_particles::Request_ApplyTuningValues(_ChopBurst, ChopBurstSize, ChopBurstColorIntensity, 1.0f, ChopBurstPlaybackSpeed); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Parts
    //----------------------------------------------------------------------------------------------------------------------

    // The state label above the board's far edge, yawed to face the operator. Its text is set once the component exists.
    private FCk_Handle_UnrealComponent AddLabel(FCk_Handle_Transform& InAttachTo, FTransform InLocalTransform)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetWorldSize(LabelWorldSize);
        Archetype.SetTextRenderColor(LabelColor);
        Archetype.SetText(utils_dicing::Get_StateLabel(EMars_Dicing_State::WholeLeaves, _DicingSpec.RequestedState));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"DicingStation_Label");
        return utils_unreal_component::Add(Node, ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Pile();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnStateChanged(FCk_Handle_Dicing InDicing, EMars_Dicing_State InState)
    {
        Refresh_Pile();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnBandMoved(FCk_Handle_Dicing InDicing, float32 InCenter)
    {
        Move_Band(InCenter);
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        if (InResult == EMars_Dicing_ChopResult::Aligned)
        { Play_ChopBurst(); }
    }
}
