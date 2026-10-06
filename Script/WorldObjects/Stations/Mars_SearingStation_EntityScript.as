// The searing station: a table (width along local Y, depth along local X) with a stove slab and a burner on top, and over
// the burner a flat oiled pan the operator's look tilts and, flicked up, tosses. The pan node carries an Implement (the
// tilt and lift) and, on its own child node, the kinematic Jolt disc the steak rests on; every mesh part under the pan
// node is a NoCollision visual. The Searing feature lives on the station entity and its own state machine
// (UMars_SmState_Searing_Idle) reads the operator; the feature spawns the steak (a dynamic body on its own entity) and
// this script only builds the nodes and dresses the steak and the station from the Searing signals. While operating, the
// right glove holds the pan handle (riding the tilt and the toss) and the left rests flat on the table's left side.
class UMars_SearingStation_EntityScript : UMars_Station_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Searing_Spec Searing;

    // The pan's tilt and lift; its Nodes are set here.
    UPROPERTY(ExposeOnSpawn)
    FMars_Implement_Spec Implement;

    private const float64 TableWidth = 140.0;
    private const float64 TableDepth = 80.0;
    private const float64 TableHeight = 90.0;
    // Close in: the capsule (radius 34) stands almost touching the table edge, the view pitched hard onto the pan.
    private const float64 StandGap = 38.0;
    private const float32 CameraPitch = -48.0f;
    // The Use probe's margin around the table.
    private const float64 ProbePadding = 5.0;

    private const float64 StoveSize = 50.0;
    private const float64 StoveHeight = 8.0;
    private const float64 StoveX = 0.0;
    // Engine cylinder scales (100 uu across and tall): a burner ring 36 across and 2 tall on the slab.
    private const float64 BurnerRadiusScale = 0.36;
    private const float64 BurnerHeightScale = 0.02;
    // The pan base's bottom above the stove slab.
    private const float64 PanLift = 6.0;
    private const float64 HandleLength = 30.0;
    private const float64 HandleThickness = 3.0;
    // Each steak face is a thin slab on the cube's face plane.
    private const float64 FaceThickness = 1.2;

    // The left glove's grip, in from the table's left (-Y) edge, a palm's thickness above the top.
    private const float64 LeftGripEdgeInset = 6.0;
    private const float64 PalmLift = 2.5;

    // The state label above the table's far edge.
    private const float64 LabelInset = 5.0;
    private const float64 LabelHeight = 40.0;
    private const float32 LabelWorldSize = 10.0f;
    private const FColor LabelColor = FColor(255, 238, 0, 255);

    private const FLinearColor k_RawColor = FLinearColor(0.85f, 0.35f, 0.40f, 1.0f);
    private const FLinearColor k_SearedColor = FLinearColor(0.35f, 0.17f, 0.08f, 1.0f);
    private const FLinearColor k_PanColor = FLinearColor(0.12f, 0.12f, 0.13f, 1.0f);
    private const FLinearColor k_StoveColor = FLinearColor(0.22f, 0.22f, 0.24f, 1.0f);
    private const FLinearColor k_BurnerHot = FLinearColor(0.9f, 0.3f, 0.1f, 1.0f);
    private const FLinearColor k_BurnerCold = FLinearColor(0.3f, 0.3f, 0.3f, 1.0f);

    private const int32 k_SizzleBehavior = 47; // SteamJet
    private const float64 SizzleLift = 2.0;
    private const float32 SizzleSize = 0.5f;
    private const float32 SizzleColorIntensity = 1.0f;
    private const float32 SizzleAlpha = 0.6f;
    private const float32 SizzlePlaybackSpeed = 1.0f;

    private const int32 k_SearedBurstBehavior = 13; // SparksBurst
    private const float32 SearedBurstSize = 0.35f;
    private const float32 SearedBurstColorIntensity = 0.8f;
    private const float32 SearedBurstPlaybackSpeed = 1.6f;

    private FCk_Handle_Transform _Root;
    // Searing as exposed, with the nodes set (DoConstruct); what the feature and the visuals read.
    private FMars_Searing_Spec _SearingSpec;
    private FCk_Handle_Searing _SearingHandle;
    private FCk_Handle_SceneNode _PanNode;
    private FCk_Handle_Implement _PanImplement;
    private FCk_Handle_JoltBody _PanBaseBody;
    private FCk_Handle_UnrealComponent _BurnerPart;
    // The right glove's grip: the pan handle, under the pan node so it rides the tilt and the toss.
    private FCk_Handle_Transform _HandleGripNode;
    // The left glove's grip: flat on the table's left side.
    private FCk_Handle_Transform _SurfaceGripNode;
    // The live steak's six face slabs, indexed by int32(EMars_Searing_Face); empty while there is no live steak (a lost
    // steak keeps its parts, which die with its entity).
    private TArray<FCk_Handle_UnrealComponent> _FaceParts;
    private FCk_Handle_UnrealComponent _Label;
    // The entity script is a UObject, not a fragment, so it may hold the components. Null under nullrhi.
    private UNiagaraComponent _Sizzle;
    private bool _SizzleActive = false;
    private UNiagaraComponent _SearedBurst;

    // The base composes the transform, the visuals and nodes (AddVisuals: the pan node and its base body) and the Station
    // (Configure_Spec, grips on the registered nodes); the pan Implement and the minigame need them, so they come after.
    // The Searing signals are bound here, not at begin play: the first steak spawns on the kernel's first tick and its
    // visuals must not miss it.
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        // Before the base: its AddVisuals reads the pan radius from it.
        _SearingSpec = Searing;

        const auto Flow = Super::DoConstruct(InHandle);

        // A rejected station already ensured in utils_station::Add; there is nothing to sear on.
        auto StationHandle = InHandle.As_Station(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(StationHandle))
        { return Flow; }

        // A rejected pan spec already ensured in utils_implement::Add.
        auto PanSpec = Implement;
        PanSpec.Nodes = FMars_Implement_Nodes(_PanNode);
        _PanImplement = utils_implement::Add(_PanNode.H(), PanSpec);
        if (ck::Is_NOT_Valid(_PanImplement))
        { return Flow; }

        // A rejected Searing spec already ensured in utils_searing::Add.
        _SearingSpec.Nodes = FMars_Searing_Nodes(_PanImplement, _PanBaseBody);
        _SearingHandle = utils_searing::Add(InHandle, _SearingSpec);
        if (ck::Is_NOT_Valid(_SearingHandle))
        { return Flow; }

        _SearingHandle.BindTo_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnHeatChanged"));
        _SearingHandle.BindTo_OnSteakSpawned(FMars_Delegate_Searing_OnSteakSpawned(this, n"OnSteakSpawned"));
        _SearingHandle.BindTo_OnPanContactChanged(FMars_Delegate_Searing_OnPanContactChanged(this, n"OnPanContactChanged"));
        _SearingHandle.BindTo_OnSearProgress(FMars_Delegate_Searing_OnSearProgress(this, n"OnSearProgress"));
        _SearingHandle.BindTo_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnFaceSeared"));
        _SearingHandle.BindTo_OnSizzleChanged(FMars_Delegate_Searing_OnSizzleChanged(this, n"OnSizzleChanged"));
        _SearingHandle.BindTo_OnSteakLost(FMars_Delegate_Searing_OnSteakLost(this, n"OnSteakLost"));
        _SearingHandle.BindTo_OnCompleted(FMars_Delegate_Searing_OnCompleted(this, n"OnCompleted"));
        return Flow;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_BurnerPart))
        { utils_unreal_component::BindTo_OnAdded(_BurnerPart, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        if (ck::IsValid(_Label))
        { utils_unreal_component::BindTo_OnAdded(_Label, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

        Refresh_All();
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_SearingHandle))
        {
            _SearingHandle.UnbindFrom_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnHeatChanged"));
            _SearingHandle.UnbindFrom_OnSteakSpawned(FMars_Delegate_Searing_OnSteakSpawned(this, n"OnSteakSpawned"));
            _SearingHandle.UnbindFrom_OnPanContactChanged(FMars_Delegate_Searing_OnPanContactChanged(this, n"OnPanContactChanged"));
            _SearingHandle.UnbindFrom_OnSearProgress(FMars_Delegate_Searing_OnSearProgress(this, n"OnSearProgress"));
            _SearingHandle.UnbindFrom_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnFaceSeared"));
            _SearingHandle.UnbindFrom_OnSizzleChanged(FMars_Delegate_Searing_OnSizzleChanged(this, n"OnSizzleChanged"));
            _SearingHandle.UnbindFrom_OnSteakLost(FMars_Delegate_Searing_OnSteakLost(this, n"OnSteakLost"));
            _SearingHandle.UnbindFrom_OnCompleted(FMars_Delegate_Searing_OnCompleted(this, n"OnCompleted"));
        }

        if (ck::IsValid(_Sizzle))
        { _Sizzle.DestroyComponent(); }

        _Sizzle = nullptr;
        _SizzleActive = false;

        if (ck::IsValid(_SearedBurst))
        { _SearedBurst.DestroyComponent(); }

        _SearedBurst = nullptr;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-(TableDepth * 0.5 + StandGap), 0.0, 0.0));

        auto Grips = TArray<FMars_Station_Grip>();
        // Both grips take their node's frame: the handle node wraps the right glove around the horizontal handle, the
        // table node lays the left glove flat on the table.
        Grips.Add(FMars_Station_Grip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, NAME_None,
            EMars_HandGripPose::Power, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        Grips.Add(FMars_Station_Grip(EMars_Hand::Left, GameplayTags::Station_Node_Surface, NAME_None,
            EMars_HandGripPose::Open, TOptional<float32>(), EMars_FPHands_GripFrame::Node, EMars_FPHands_GripRoll::Fixed));
        InOutSpec.Grips = Grips;

        InOutSpec.Camera.LookControl = EMars_Station_LookControl::Captured;
        InOutSpec.Camera.PitchOffset = CameraPitch;
        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "SearSteakPrompt", "Sear steak"),
            NSLOCTEXT("MarsInteraction", "SearingStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Searing_Idle;
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

    // Engine cube and cylinder are 100 uu with the pivot at the centre.
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;
        auto CubeMesh = engine::load::Cube();
        const auto StoveTop = Get_StoveTop();

        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, TableHeight * 0.5), FVector(TableDepth, TableWidth, TableHeight) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Wall_Mars_MI(), collision::profile::BlockAll, n"SearingStation_Table"));

        auto Stove = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(StoveX, 0.0, TableHeight + StoveHeight * 0.5), FVector(StoveSize, StoveSize, StoveHeight) * 0.01),
            CubeMesh, assets::load::ProtoGrid_Platform_Mars_MI(), collision::profile::NoCollision, n"SearingStation_Stove");
        Stove.PrimaryColor = TOptional<FLinearColor>(k_StoveColor);
        InRoot.Add_MeshPart(this, Stove);

        auto Burner = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(StoveX, 0.0, StoveTop + BurnerHeightScale * 50.0),
                FVector(BurnerRadiusScale, BurnerRadiusScale, BurnerHeightScale)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Interactable_Mars_MI(), collision::profile::NoCollision, n"SearingStation_Burner");
        Burner.PrimaryColor = TOptional<FLinearColor>(k_BurnerCold);
        _BurnerPart = InRoot.Add_MeshPart(this, Burner);

        AddPan(InRoot);

        _Label = AddLabel(InRoot,
            FTransform(FRotator(0.0, 180.0, 0.0), FVector(TableDepth * 0.5 - LabelInset, 0.0, StoveTop + LabelHeight)));

        // Grip frame (X across the palm toward the index finger, Z out of the palm): a left hand flat on the table with its
        // fingers forward has its index side to the right (+Y) and its palm down (-Z); the grip bone sits a palm's
        // thickness above the top.
        _SurfaceGripNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::MakeFromXZ(FVector::RightVector, -FVector::UpVector),
                FVector(0.0, -TableWidth * 0.5 + LeftGripEdgeInset, TableHeight + PalmLift))).As_Transform();
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _HandleGripNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Surface, _SurfaceGripNode));
    }

    // The pan node is the base disc's centre; the Implement (composed in DoConstruct) writes its offset. Under it: the disc
    // visual, the kinematic disc body on its own child node (the only collision under the pan: a moving baked part would
    // re-bake every frame, and a static body never imparts velocity), the handle toward the operator and its grip node.
    // No rim: a cube on a slope only tips over a rim past 45 degrees, so at the 30-degree tilt clamp a rim would keep the
    // steak on; it slides off the disc's edge instead.
    private void AddPan(FCk_Handle_Transform& InRoot)
    {
        const auto PanRadius = float64(_SearingSpec.Loss.PanRadius);
        const auto BaseHalfHeight = float64(utils_searing::k_PanBaseHalfHeight);

        _PanNode = utils_scene_node::Create(InRoot,
            FTransform(FRotator::ZeroRotator, FVector(StoveX, 0.0, Get_StoveTop() + PanLift + BaseHalfHeight)));
        auto PanTransform = _PanNode.As_Transform();

        auto Disc = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(PanRadius * 0.02, PanRadius * 0.02, BaseHalfHeight * 0.02)),
            engine::load::Cylinder(), assets::load::ProtoGrid_Item_Mars_MI(), collision::profile::NoCollision, n"SearingStation_PanDisc");
        Disc.PrimaryColor = TOptional<FLinearColor>(k_PanColor);
        PanTransform.Add_MeshPart(this, Disc);

        auto BodyNode = utils_scene_node::Create(PanTransform, FTransform::Identity);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Cylinder);
        Shape.Set_Radius(_SearingSpec.Loss.PanRadius);
        Shape.Set_HalfHeight(utils_searing::k_PanBaseHalfHeight);
        auto BodySpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BodySpec.Set_ShapeDimensions(Shape);
        BodySpec.Set_MotionType(ECk_MotionType::Kinematic);
        // Oiled: the steak's friction combines with this one as sqrt(a * b).
        BodySpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BodySpec.Set_Friction(0.3f);
        BodySpec.Set_Restitution(0.1f);
        BodySpec.Set_CollisionProfileName(n"BlockAll");
        _PanBaseBody = utils_jolt_body::Add(BodyNode.H(), BodySpec);

        // The handle runs from the disc's edge toward the operator (-X) at the disc's mid height.
        const auto HandleCenter = FVector(-(PanRadius + HandleLength * 0.5), 0.0, 0.0);
        auto Handle = FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, HandleCenter, FVector(HandleLength, HandleThickness, HandleThickness) * 0.01),
            engine::load::Cube(), assets::load::ProtoGrid_Item_Mars_MI(), collision::profile::NoCollision, n"SearingStation_PanHandle");
        Handle.PrimaryColor = TOptional<FLinearColor>(k_PanColor);
        PanTransform.Add_MeshPart(this, Handle);

        // Grip frame (X across the palm toward the index finger, Z out of the palm): along the handle toward the pan (+X),
        // palm facing the operator's left (-Y) - a handshake grip on a horizontal handle.
        _HandleGripNode = utils_scene_node::Create(PanTransform,
            FTransform(FRotator::MakeFromXZ(FVector::ForwardVector, -FVector::RightVector), HandleCenter)).As_Transform();
    }

    // The steak's look: six thin face slabs on a visual node under its entity (Jolt owns the entity's pose; the kernel
    // never writes the node), painted from the ledger.
    private void AddSteakVisuals(FCk_Handle InSteak)
    {
        auto SteakTransform = InSteak.As_Transform();
        auto VisualNode = utils_scene_node::Create(SteakTransform, FTransform::Identity);
        auto VisualTransform = VisualNode.As_Transform();

        const auto HalfSize = float64(_SearingSpec.Steak.HalfSize);
        const auto Side = HalfSize * 2.0;
        auto CubeMesh = engine::load::Cube();
        auto ItemMaterial = assets::load::ProtoGrid_Item_Mars_MI();

        _FaceParts.Empty();
        for (int32 Index = 0; Index < utils_searing::k_FaceCount; ++Index)
        {
            const auto Normal = utils_searing::Get_FaceNormal(EMars_Searing_Face(Index));
            // Thin along the face's normal, Side across it.
            const auto Scale = FVector(
                Math::Abs(Normal.X) > 0.5 ? FaceThickness : Side,
                Math::Abs(Normal.Y) > 0.5 ? FaceThickness : Side,
                Math::Abs(Normal.Z) > 0.5 ? FaceThickness : Side) * 0.01;

            auto Face = FMars_MeshPart(FTransform(FRotator::ZeroRotator, Normal * HalfSize, Scale),
                CubeMesh, ItemMaterial, collision::profile::NoCollision, n"SearingStation_SteakFace");
            Face.PrimaryColor = TOptional<FLinearColor>(k_RawColor);
            auto Part = VisualTransform.Add_MeshPart(this, Face);
            if (ck::IsValid(Part))
            { utils_unreal_component::BindTo_OnAdded(Part, FCk_Delegate_UnrealComponent_OnAdded(this, n"OnPartAdded")); }

            _FaceParts.Add(Part);
        }
    }

    // The state label above the table's far edge, yawed to face the operator. Its text is set once the component exists.
    private FCk_Handle_UnrealComponent AddLabel(FCk_Handle_Transform& InAttachTo, FTransform InLocalTransform)
    {
        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);

        auto Archetype = NewObject(this, UTextRenderComponent);
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetCollisionEnabled(ECollisionEnabled::NoCollision);
        Archetype.SetHorizontalAlignment(EHorizTextAligment::EHTA_Center);
        Archetype.SetWorldSize(LabelWorldSize);
        Archetype.SetTextRenderColor(LabelColor);
        Archetype.SetText(FText::FromString("Steak: 0/6 seared"));

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            Archetype, ECk_UnrealComponent_TickPolicy::DoNotTick, n"SearingStation_Label");
        return utils_unreal_component::Add(Node, ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals (the Searing feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    private float64 Get_StoveTop() const
    {
        return TableHeight + StoveHeight;
    }

    private void Refresh_All()
    {
        Refresh_Burner();
        Refresh_Faces();
        Refresh_Label();
    }

    private void Refresh_Burner()
    {
        if (ck::Is_NOT_Valid(_SearingHandle))
        { return; }

        _BurnerPart.Paint_MeshPart(_SearingHandle.Get_IsHot() ? k_BurnerHot : k_BurnerCold);
    }

    private void Refresh_Faces()
    {
        for (int32 Index = 0; Index < _FaceParts.Num(); ++Index)
        { Refresh_Face(EMars_Searing_Face(Index)); }
    }

    // Raw to seared by the face's sear.
    private void Refresh_Face(EMars_Searing_Face InFace)
    {
        const auto Index = int32(InFace);
        if (ck::Is_NOT_Valid(_SearingHandle) || _FaceParts.IsValidIndex(Index) == false)
        { return; }

        _FaceParts[Index].Paint_MeshPart(Math::Lerp(k_RawColor, k_SearedColor, _SearingHandle.Get_FaceSear(InFace)));
    }

    private void Refresh_Label()
    {
        if (ck::Is_NOT_Valid(_SearingHandle) || ck::Is_NOT_Valid(_Label))
        { return; }

        // Null until the component is created (asynchronously); OnPartAdded refreshes then.
        auto Text = Cast<UTextRenderComponent>(utils_unreal_component::Get_Component(_Label));
        if (ck::Is_NOT_Valid(Text))
        { return; }

        Text.SetText(utils_searing::Get_StateLabel(_SearingHandle));
    }

    // One steam component at the pan centre aimed up: spawned at the first sizzle whose template is ready (a cold template
    // never stalls the game thread; that sizzle just goes without steam), then moved to the pan and re-activated on each
    // Quiet -> Sizzling edge. Activate(true) resets the system, so it only runs on an edge. Null under nullrhi.
    private void Set_SizzleActive(bool InActive)
    {
        if (InActive == _SizzleActive)
        { return; }

        if (InActive == false)
        {
            _SizzleActive = false;
            if (ck::IsValid(_Sizzle))
            { _Sizzle.Deactivate(); }

            return;
        }

        const auto PanBaseWorld = utils_transform::Get_EntityCurrentTransform(_PanBaseBody.As_Transform());
        const auto Location = PanBaseWorld.GetLocation()
            + PanBaseWorld.GetRotation().GetUpVector() * (float64(utils_searing::k_PanBaseHalfHeight) + SizzleLift);
        // The jet fires along its local +X.
        const auto Up = FRotator(90.0, 0.0, 0.0);

        if (ck::Is_NOT_Valid(_Sizzle))
        {
            if (utils_particles::Get_IsBehaviorTemplateReady(k_SizzleBehavior) == false)
            { return; }

            _Sizzle = utils_particles::Spawn_BehaviorAtLocation(k_SizzleBehavior, Location, Up);
            if (ck::Is_NOT_Valid(_Sizzle))
            { return; }
        }

        _SizzleActive = true;
        _Sizzle.SetWorldLocationAndRotation(Location, Up);
        _Sizzle.Activate(true);
        utils_particles::Request_ApplyTuningValues(_Sizzle, SizzleSize, SizzleColorIntensity, SizzleAlpha, SizzlePlaybackSpeed);
    }

    // One reused burst component at the steak: spawned at the first seared face whose template is ready, then moved and
    // re-activated per face. Null under nullrhi.
    private void Play_SearedBurst()
    {
        if (ck::Is_NOT_Valid(_SearingHandle))
        { return; }

        const auto Steak = _SearingHandle.Get_Steak();
        if (ck::Is_NOT_Valid(Steak))
        { return; }

        const auto Location = utils_transform::Get_EntityCurrentLocation(Steak.As_Transform());

        if (ck::IsValid(_SearedBurst))
        {
            _SearedBurst.SetWorldLocation(Location);
            _SearedBurst.Activate(true);
            return;
        }

        if (utils_particles::Get_IsBehaviorTemplateReady(k_SearedBurstBehavior) == false)
        { return; }

        _SearedBurst = utils_particles::Spawn_BehaviorAtLocation(k_SearedBurstBehavior, Location, FRotator::ZeroRotator);
        if (ck::IsValid(_SearedBurst))
        { utils_particles::Request_ApplyTuningValues(_SearedBurst, SearedBurstSize, SearedBurstColorIntensity, 1.0f, SearedBurstPlaybackSpeed); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPartAdded(FCk_Handle_UnrealComponent InHandle)
    {
        Refresh_All();
    }

    UFUNCTION()
    private void OnHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat)
    {
        Refresh_Burner();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnSteakSpawned(FCk_Handle_Searing InSearing, FCk_Handle InSteak)
    {
        AddSteakVisuals(InSteak);
        Refresh_Faces();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnPanContactChanged(FCk_Handle_Searing InSearing, EMars_Searing_Phase InPhase)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnSearProgress(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace, float32 InAlpha)
    {
        Refresh_Face(InFace);
    }

    UFUNCTION()
    private void OnFaceSeared(FCk_Handle_Searing InSearing, EMars_Searing_Face InFace)
    {
        Refresh_Faces();
        Play_SearedBurst();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnSizzleChanged(FCk_Handle_Searing InSearing, EMars_Searing_Sizzle InSizzle)
    {
        Set_SizzleActive(InSizzle == EMars_Searing_Sizzle::Sizzling);
        Refresh_Label();
    }

    // The lost steak flies on with its parts (they die with its entity); the next steak gets its own.
    UFUNCTION()
    private void OnSteakLost(FCk_Handle_Searing InSearing, FCk_Handle InSteak)
    {
        _FaceParts.Empty();
        Refresh_Label();
    }

    UFUNCTION()
    private void OnCompleted(FCk_Handle_Searing InSearing, FMars_Searing_Tally InTally)
    {
        Refresh_Label();
    }
}
