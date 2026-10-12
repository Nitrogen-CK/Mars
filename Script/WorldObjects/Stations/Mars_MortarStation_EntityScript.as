// The mortar station: a table (width along local Y, depth along local X) with a stone mortar in its middle, a batch of
// salt or pepper in the bowl and a pestle over it. The operator stands k_StandGap uu in front of the table's -X edge facing
// +X; the view is Captured and overhead, the eye over the bowl. While operating, the right glove holds the pestle (riding
// the strike and the grind) and the left lies on the table beside the mortar; the pestle leans out over the operator's
// right and the left hand keeps off the bowl, so the overhead view sees into it.
//
// The station entity carries the Mortar feature (the kernel: the batch, the timing window, the strike and the grind) and
// its state machine (Mars_MortarStation_Hfsm.as) turns the operator's presses into Mortar requests. This script assembles
// what is seen and heard: the table, the mortar, the pile (the food library's stage mesh for the batch's seasoning and
// stage, swapped on every step of the batch), and the pestle, whose two motions are drawn here from the kernel's signals:
// the crush is a Mover (down as a strike starts, back up as it lands), the grind is a circle in the bowl while the kernel
// says the pestle is Grinding (this script's dressing tick writes the orbit node). It knocks on every landing and sparks
// on a hit. The operator's timing bar and progress are UMars_MortarMeter_Widget's, on the HUD.
class UMars_MortarStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Mortar_Spec Mortar;

    // PrepTable_Mars_SM: 160 wide, 80 deep (station_spec.py PROPS["PrepTable"]).
    private const float64 TableWidth = 160.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = constants_station::k_CounterHeight;

    // The mortar, the pestle and the piles as build_food_mortar.py authors them (FOOD_LIBRARY.md), in the meshes' own
    // centimetres: a 22 cm mortar whose bowl floor is MortarBowlFloor above its base and whose rim is MortarRimHeight up, an
    // 18 cm pestle standing on its crushing head (its pivot). All of them are multiplied by PropScale on this station, so
    // the bowl reads from the overhead view and the glove fits the pestle.
    private const float64 PropScale = 2.5;
    private const float64 MortarBowlFloor = 3.0;
    private const float64 MortarRimHeight = 12.1;

    // The pestle's rest, in station cm above the bowl floor at the bowl's centre: its head PestleRaise up, leaning
    // PestleLean degrees from upright toward the operator's right (PestleLeanYaw turns the lean from straight back at the
    // operator, clockwise seen from above), so the overhead view sees its length, the shaft crosses the rim at the bottom
    // right and the glove on it sits outside the bowl. A strike brings the head down to PestleContact (the top of a
    // pile); a grind holds it at GrindHeight, circling GrindRadius from the centre GrindHz times a second.
    private const float64 PestleRaise = 18.0;
    private const float64 PestleContact = 7.0;
    private const float32 PestleLean = 52.0f;
    private const float32 PestleLeanYaw = -40.0f;
    // Along the pestle from its head, in the pestle's own cm: where the right glove wraps it.
    private const float64 PestleGripAlong = 13.0;
    private const float64 GrindHeight = 5.0;
    private const float64 GrindRadius = 9.0;
    private const float64 GrindHz = 1.3;
    // Per second: how fast the pestle settles into the grind and back out of it.
    private const float32 GrindBlendRate = 5.0f;
    // uu the orbit node must move before it is written again.
    private const float64 k_OrbitWriteTolerance = 0.01;
    // One turn, in radians.
    private const float64 k_Turn = 6.283185307179586;

    // The operating view: the eye sits ViewDistance uu from the middle of the mortar's rim along the CameraPitch line, so
    // the bowl is the centre of the screen and the eye is over it, not over the hand on the pestle. It lives in the
    // station frame (Camera.ViewLocal), so the framing holds whatever the operator's eye height.
    private const float32 CameraPitch = -80.0f;
    private const float64 ViewDistance = 105.0;

    // The left glove's rest on the table top: on the operator's side and to the left of the mortar, clear of the bowl, its
    // fingers turned LeftHandYaw degrees in toward it.
    private const FVector LeftHandLocal = FVector(-24.0, -52.0, 0.0);
    private const float64 LeftHandYaw = 35.0;

    // The label stands on the table's far edge facing the operator's side, for whoever walks up: the overhead view sees it
    // edge-on, and the operator reads the HUD's meter instead.
    private const float64 LabelInset = 5.0;
    private const float64 LabelLift = 2.0;

    private const float64 BurstLift = 2.0;

    private FCk_Handle_Transform _Root;
    private FCk_Handle_Mortar _MortarHandle;
    // The pestle's strike, drawn from the kernel's strike signals: start = raised, end = on the batch.
    private FCk_Handle_Mover _StrikeMover;
    // Under the strike node: the grind's circle, written by the dressing tick.
    private FCk_Handle_SceneNode _OrbitNode;
    // The right glove's grip on the pestle, under the leaning pestle node so it rides the strike and the grind.
    private FCk_Handle_Transform _PestleGripNode;
    // The left glove's rest on the table beside the mortar.
    private FCk_Handle_Transform _LeftHandNode;
    private FCk_Handle_UnrealComponent _PilePart;
    private FCk_Handle_UnrealComponent _Label;
    private FCk_Handle_Timer _DressingTick;

    // The dressing's own state: the grind's blend (0 at rest, 1 circling), its angle, and the orbit offset last written.
    private float32 _GrindBlend = 0.0f;
    private float64 _GrindAngle = 0.0;
    private FVector _WrittenOrbit = FVector::ZeroVector;
    // The text last written to the label: it is rewritten only when it changes.
    private FString _LabelText;
    // The entity script is a UObject, not a fragment, so it may hold these.
    private USoundBase _KnockSound;
    private UNiagaraComponent _Burst;

    // The base composes the transform, the visuals and nodes (AddVisuals) and the Station (Configure_Spec, grips on the
    // registered nodes); the kernel needs the station entity, so it is composed after, and its signals are bound here, not
    // at begin play, so no edge can be missed.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to work at.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected Mortar spec already ensured in utils_mortar::Add.
        _MortarHandle = utils_mortar::Add(InHandle, Mortar);
        if (ck::Is_NOT_Valid(_MortarHandle))
        { return Flow; }

        _MortarHandle.BindTo_OnStrikeStarted(FMars_Delegate_Mortar_OnStrikeStarted(this, n"OnStrikeStarted"));
        _MortarHandle.BindTo_OnStrikeLanded(FMars_Delegate_Mortar_OnStrikeLanded(this, n"OnStrikeLanded"));
        _MortarHandle.BindTo_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnBatchChanged"));
        _KnockSound = assets::load::KnifeChop_Cue();

        // The timer dies with the entity; nothing to unbind.
        _DressingTick = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnDressingTick"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_PilePart))
        { utils_unreal_component::BindTo_OnAdded(_PilePart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        Refresh_Pile();
        Refresh_Label();
    }

    // The parts are hosted components: they die with their entities. Only the burst is spawned loose.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_MortarHandle))
        {
            _MortarHandle.UnbindFrom_OnStrikeStarted(FMars_Delegate_Mortar_OnStrikeStarted(this, n"OnStrikeStarted"));
            _MortarHandle.UnbindFrom_OnStrikeLanded(FMars_Delegate_Mortar_OnStrikeLanded(this, n"OnStrikeLanded"));
            _MortarHandle.UnbindFrom_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnBatchChanged"));
        }

        if (ck::IsValid(_Burst))
        { _Burst.DestroyComponent(); }

        _Burst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(TableDepth * 0.5 + constants_station::k_StandGap), 0.0, 0.0));

        // The right glove wraps the pestle; the left lies palm down on the table.
        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Surface, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        // Back along the pitched view line from the middle of the mortar's rim, so the bowl is dead centre on screen.
        InOutSpec.Camera.ViewLocal = TOptional<FTransform>(
            utils_station::Make_ViewLocal(FVector(0.0, 0.0, Get_RimZ()), CameraPitch, ViewDistance));
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "GrindSeasoningPrompt", "Grind seasoning"),
            NSLOCTEXT("MarsInteraction", "MortarStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Mortar_Idle;
    }

    // The Use probe: the table's footprint and height, k_ProbePadding all round.
    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        const auto Padding = constants_station::k_ProbePadding;

        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(
            FVector(TableDepth * 0.5 + Padding, TableWidth * 0.5 + Padding, TableHeight * 0.5 + Padding)));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        const auto Scale = FVector(PropScale, PropScale, PropScale);

        // The table pivots at its floor contact; the mortar and the piles at their base centre (the piles' base is the
        // bowl's floor).
        InRoot.Add_MeshPart(this, FMars_MeshPart(FTransform::Identity,
            assets::load::PrepTable_Mars_SM(), nullptr, collision::profile::BlockAll, n"MortarStation_Table"));

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight), Scale),
            assets::load::Mortar_Mars_SM(), nullptr, collision::profile::NoCollision, n"MortarStation_Mortar"));

        _PilePart = InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, Get_BowlFloorZ()), Scale),
            Get_PileMesh(Mortar.StartSeasoning, EMars_Mortar_Stage::Coarse), nullptr, collision::profile::NoCollision, n"MortarStation_Pile"));
        if (ck::IsValid(_PilePart))
        { utils_entity_tag::Add(_PilePart, n"TAG_MarsMortarPile"); }

        AddPestle(InRoot);

        // Palm down k_PalmLift over the table top, the fingers turned in toward the mortar.
        const auto Fingers = FRotator(0.0, LeftHandYaw, 0.0).RotateVector(FVector::ForwardVector);
        _LeftHandNode = utils_scene_node::Create(InRoot, FTransform(
            utils_fphands::Make_GripRotation(EMars_Hand::Left, Fingers, -FVector::UpVector),
            LeftHandLocal + FVector(0.0, 0.0, TableHeight + constants_station::k_PalmLift))).As_Transform();

        AddLabel(InRoot);
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _PestleGripNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _LeftHandNode));
    }

    // The pestle: a strike node (a Mover: raised, or down on the batch) at the bowl's centre, the orbit node under it (the
    // grind's circle, and its drop to the batch), and under that the leaning node that carries the pestle's mesh and the
    // right glove's grip, so both ride the strike and the grind.
    private void AddPestle(FCk_Handle_Transform& InRoot)
    {
        auto BowlNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, Get_BowlFloorZ())));
        auto BowlTransform = BowlNode.As_Transform();
        auto StrikeNode = utils_scene_node::Create(BowlTransform, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, PestleRaise)));

        // One Duration for both directions, the kernel's StrikeSeconds: the head reaches the batch as the strike lands,
        // and the recover takes as long.
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.StartLocation = FVector(0.0, 0.0, PestleRaise);
        MoverSpec.EndLocation = FVector(0.0, 0.0, PestleContact);
        MoverSpec.Duration = Mortar.StrikeSeconds;
        MoverSpec.Easing = ECk_TweenEasing::InQuad;
        _StrikeMover = utils_mover::Add(StrikeNode, MoverSpec);

        auto StrikeTransform = StrikeNode.As_Transform();
        _OrbitNode = utils_scene_node::Create(StrikeTransform, FTransform::Identity);
        auto OrbitTransform = _OrbitNode.As_Transform();

        // Pitched up, the pestle's own +Z (head to grip) leans toward the operator (-X); the yaw then swings that lean round
        // to the operator's right (+Y).
        auto LeanNode = utils_scene_node::Create(OrbitTransform, FTransform(FRotator(PestleLean, PestleLeanYaw, 0.0), FVector::ZeroVector));
        auto LeanTransform = LeanNode.As_Transform();
        LeanTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(PropScale, PropScale, PropScale)),
            assets::load::Pestle_Mars_SM(), nullptr, collision::profile::NoCollision, n"MortarStation_Pestle"));

        // A right-hand fist round the shaft, the head below it: palm facing the operator's left (-Y), the hand leading down
        // to the head, so the fingers point back at the operator in the pestle's frame.
        _PestleGripNode = utils_scene_node::Create(LeanTransform, FTransform(
            utils_fphands::Make_GripRotation(EMars_Hand::Right, -FVector::ForwardVector, -FVector::RightVector),
            FVector(0.0, 0.0, PestleGripAlong * PropScale))).As_Transform();
    }

    // Yawed 180 the text faces the operator's side. Tagged TAG_MarsStationLabel like every station's label.
    private void AddLabel(FCk_Handle_Transform& InRoot)
    {
        auto Node = utils_scene_node::Create(InRoot, FTransform(FRotator(0.0, 180.0, 0.0),
            FVector(TableDepth * 0.5 - LabelInset, 0.0, TableHeight + LabelLift)));

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetVerticalAlignment(EVerticalTextAligment::EVRTA_TextBottom);
        Archetype.SetWorldSize(constants_station::k_LabelWorldSize);
        Archetype.SetTextRenderColor(constants_ui_colors::k_StationLabel);
        Archetype.SetText(FText::FromString(""));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"MortarStation_Label");
        _Label = utils_unreal_component::Add(Node, ComponentParams);
        if (ck::IsValid(_Label))
        { utils_entity_tag::Add(_Label, n"TAG_MarsStationLabel"); }
    }

    private float64 Get_BowlFloorZ() const
    {
        return TableHeight + MortarBowlFloor * PropScale;
    }

    private float64 Get_RimZ() const
    {
        return TableHeight + MortarRimHeight * PropScale;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals (the Mortar feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // The food library's pile for a seasoning at a stage (salt: crystals, grit, dust; pepper: whole, cracked, ground).
    private UStaticMesh Get_PileMesh(EMars_Mortar_Seasoning InSeasoning, EMars_Mortar_Stage InStage) const
    {
        if (InSeasoning == EMars_Mortar_Seasoning::Salt)
        {
            if (InStage == EMars_Mortar_Stage::Coarse)
            { return assets::load::SaltPile_Crystals_Mars_SM(); }

            if (InStage == EMars_Mortar_Stage::Cracked)
            { return assets::load::SaltPile_Grit_Mars_SM(); }

            return assets::load::SaltPile_Dust_Mars_SM();
        }

        if (InStage == EMars_Mortar_Stage::Coarse)
        { return assets::load::PepperPile_Whole_Mars_SM(); }

        if (InStage == EMars_Mortar_Stage::Cracked)
        { return assets::load::PepperPile_Cracked_Mars_SM(); }

        return assets::load::PepperPile_Ground_Mars_SM();
    }

    // The pile wears the batch's mesh (each pile mesh carries its own material). Nothing until its component exists (it
    // is created asynchronously): OnPartAdded refreshes then.
    private void Refresh_Pile()
    {
        if (ck::Is_NOT_Valid(_MortarHandle) || ck::Is_NOT_Valid(_PilePart))
        { return; }

        auto Pile = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(_PilePart));
        if (ck::Is_NOT_Valid(Pile))
        { return; }

        const auto Batch = _MortarHandle.Get_Batch();
        auto Mesh = Get_PileMesh(Batch.Seasoning, Batch.Stage);
        if (ck::IsValid(Mesh) && Pile.StaticMesh != Mesh)
        { Pile.SetStaticMesh(Mesh); }
    }

    // What the batch is and what it needs, then what has been ground so far.
    private FString Get_StateLabel() const
    {
        if (ck::Is_NOT_Valid(_MortarHandle))
        { return ""; }

        const auto Batch = _MortarHandle.Get_Batch();
        const FString Seasoning = Batch.Seasoning == EMars_Mortar_Seasoning::Salt ? "Salt" : "Pepper";
        FString BatchLine = f"{Seasoning}: ground";
        if (Batch.Phase == EMars_Mortar_Phase::Crush)
        { BatchLine = f"{Seasoning}: crush {Batch.CrushHits}/{_MortarHandle.Get_Spec().CrushesNeeded}"; }
        else if (Batch.Phase == EMars_Mortar_Phase::Grind)
        { BatchLine = f"{Seasoning}: grind"; }

        const auto Tally = _MortarHandle.Get_Tally();
        if (Tally.Salt == 0 && Tally.Pepper == 0)
        { return BatchLine; }

        return f"{BatchLine}\nground: {Tally.Salt} salt - {Tally.Pepper} pepper";
    }

    // Rewritten only when the text changes. Nothing until the component exists; OnPartAdded refreshes then.
    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_Label))
        { return; }

        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        const auto LabelText = Get_StateLabel();
        if (LabelText == _LabelText)
        { return; }

        _LabelText = LabelText;
        Text.SetText(FText::FromString(LabelText));
    }

    // The bowl's centre at the top of a pile, in the world.
    private FVector Get_ContactWorld() const
    {
        const auto RootWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        return RootWorld.TransformPosition(FVector(0.0, 0.0, Get_BowlFloorZ() + PestleContact + BurstLift));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Mortar feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    // The grind's circle: while the kernel says the pestle is Grinding, the orbit node swings GrindRadius round the bowl's
    // centre at GrindHz with the head down at GrindHeight; at rest it eases back under the strike node. An idle station
    // writes nothing.
    private void Advance_Grind(float32 InDeltaSeconds)
    {
        const auto IsGrinding = _MortarHandle.Get_Pestle() == EMars_Mortar_Pestle::Grinding;
        _GrindBlend = Math::FInterpConstantTo(_GrindBlend, IsGrinding ? 1.0f : 0.0f, InDeltaSeconds, GrindBlendRate);
        if (IsGrinding)
        {
            _GrindAngle += GrindHz * k_Turn * float64(InDeltaSeconds);
            if (_GrindAngle > k_Turn)
            { _GrindAngle -= k_Turn; }
        }

        const auto Blend = float64(_GrindBlend);
        const auto Offset = FVector(Math::Cos(_GrindAngle) * GrindRadius * Blend, Math::Sin(_GrindAngle) * GrindRadius * Blend,
            -(PestleRaise - GrindHeight) * Blend);
        if (Offset.Distance(_WrittenOrbit) <= k_OrbitWriteTolerance)
        { return; }

        utils_scene_node::Request_UpdateOffset(_OrbitNode,
            FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator::ZeroRotator, Offset)));
        _WrittenOrbit = Offset;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnDressingTick(FCk_Handle_Timer InHandle, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_MortarHandle))
        { return; }

        Advance_Grind(float32(InDeltaT.Get_Seconds()));
        Refresh_Label();
    }

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_Pile();
        Refresh_Label();
    }

    // The pestle drops toward the batch.
    UFUNCTION()
    private void OnStrikeStarted(FCk_Handle_Mortar InMortar)
    {
        _StrikeMover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::End));
    }

    // The pestle knocks wherever it lands, sparks when the timing was right, and goes back up.
    UFUNCTION()
    private void OnStrikeLanded(FCk_Handle_Mortar InMortar, EMars_Mortar_Strike InStrike)
    {
        _StrikeMover.Request_MoveTo(FMars_Request_Mover_MoveTo(EMars_Mover_Pose::Start));

        const auto Contact = Get_ContactWorld();
        if (ck::IsValid(_KnockSound))
        { Gameplay::PlaySoundAtLocation(_KnockSound, Contact, FRotator::ZeroRotator); }

        if (InStrike == EMars_Mortar_Strike::Hit)
        { _Burst = utils_station::Play_Burst(_Burst, Contact, FRotator::ZeroRotator); }
    }

    UFUNCTION()
    private void OnBatchChanged(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch)
    {
        Refresh_Pile();
        Refresh_Label();
    }
}
