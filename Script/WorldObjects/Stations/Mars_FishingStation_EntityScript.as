// The fishing station: a spot on a bank. The operator stands k_StandBack uu behind the root on the bank's edge facing +X,
// the water out along +X at Fishing.Water.SurfaceZ; the view is Free inside the cast's yaw fence, so the operator looks
// where the bait goes. While operating, the right glove holds the rod's rear grip and the left its fore grip (the reel), both
// riding the rod as it aims, whips and strains.
//
// The station entity carries the Fishing feature (the kernel: the bait's flight, the bite, the hook, the fight, the catch,
// the spot's presence) and its state machine (Mars_FishingStation_Hfsm.as) turns the operator's look and presses into
// Fishing requests. This script assembles what is seen: the rod (its aim, its whip on a cast and a landing, its strain under
// tension), the reel handle turning while the reel is held, the line from the rod tip to the bait, the bait on the water,
// the landed fish's fling to the catch point, the spot's marker on the water, and the label. Milestone 2: engine primitives
// stand in for the rod, reel, line, bait, fish and spot; the authored meshes, materials, rings and sparkles follow.
class UMars_FishingStation_EntityScript : UMars_CounterStation_EntityScript
{
    default _ShowInPlaceActors = true;

    UPROPERTY(ExposeOnSpawn)
    FMars_Fishing_Spec Fishing;

    // The operator's stand behind the root (the bank's edge); the Use probe's box round the root.
    private const float64 k_StandBack = 45.0;
    private const FVector k_ProbeHalfExtents = FVector(45.0, 60.0, 60.0);

    // The rod: its root at the right hand's height on the operator's right, pointed +X and pitched RodRestPitch up; the fore
    // grip ForeGripAlong along it, the reel under it at ReelAlong, the tip at RodLength. The engine's cylinder is 100 uu
    // tall on Z and 100 wide.
    private const FVector RodRootLocal = FVector(-20.0, 22.0, 100.0);
    private const float32 RodRestPitch = 15.0f;
    private const float64 RodLength = 180.0;
    private const float64 RodRadius = 1.2;
    private const float64 ForeGripAlong = 22.0;
    private const float64 ReelAlong = 30.0;
    private const float64 ReelDrop = 5.0;
    private const float64 ReelHandleLength = 7.0;
    private const float64 k_PrimitiveSpan = 100.0;

    // The whip on a cast (down and through) and the landing's flick (up): a pitch arc over WhipSeconds.
    private const float32 WhipSeconds = 0.4f;
    private const float32 WhipPitchDeg = 30.0f;
    // The strain: the rod bows StrainPitchMax degrees down at full tension, easing at StrainRate a second, with a jerk
    // of JerkPitchDeg over JerkSeconds as a fish bites or the hook sets.
    private const float32 StrainPitchMax = 25.0f;
    private const float32 StrainRate = 8.0f;
    private const float32 JerkPitchDeg = 8.0f;
    private const float32 JerkSeconds = 0.25f;
    // Degrees a second the reel handle turns while the reel is held, and its extra while the fish runs.
    private const float32 ReelTurnDegPerS = 540.0f;
    private const float32 ReelRunTurnScale = 1.6f;
    // Degrees a node must move before it is written again.
    private const float32 k_WriteToleranceDeg = 0.05f;
    private const float64 k_WriteToleranceCm = 0.05;

    // The line's and the bait's primitives.
    private const float64 LineRadius = 0.4;
    private const float64 BaitSize = 6.0;
    private const float64 FishSize = 30.0;
    private const float64 SpotRadius = 60.0;
    private const float64 SpotLift = 0.5;

    // Where the catch arrives: in front of the operator's chest.
    private const FVector CatchLocal = FVector(-10.0, 0.0, 110.0);

    // The view: the operator's own eye, pitched CameraPitch at engage, free inside the cast's yaw fence.
    private const float32 CameraPitch = -10.0f;

    // The label stands beside the root, facing the operator.
    private const FVector LabelLocal = FVector(0.0, -60.0, 60.0);

    // The spot's marker sits this fraction of the max cast out on the water.
    private const float32 SpotDistanceFraction = 0.6f;

    private FCk_Handle_Fishing _FishingHandle;
    // The rod chain: aim (yaw, pitch and the whip) -> strain (the bow) -> the rod's parts and the grips.
    private FCk_Handle_SceneNode _RodAimNode;
    private FCk_Handle_SceneNode _RodStrainNode;
    private FCk_Handle_Transform _RearGripNode;
    private FCk_Handle_Transform _ForeGripNode;
    private FCk_Handle_SceneNode _ReelNode;
    private FCk_Handle_Transform _TipNode;
    private FCk_Handle_Transform _CatchNode;
    // World-placed every frame from the kernel, written as root-local offsets.
    private FCk_Handle_SceneNode _BaitNode;
    private FCk_Handle_SceneNode _LineNode;
    private FCk_Handle_SceneNode _FishNode;
    private FCk_Handle_SceneNode _SpotNode;
    private FCk_Handle_UnrealComponent _BaitPart;
    private FCk_Handle_UnrealComponent _LinePart;
    private FCk_Handle_UnrealComponent _FishPart;
    private FCk_Handle_UnrealComponent _SpotPart;

    // The dressing's own state: what was last written, the whip's and the jerk's clocks, the strain's bow, the reel's angle.
    private FRotator _WrittenAim = FRotator::ZeroRotator;
    private FRotator _WrittenStrain = FRotator::ZeroRotator;
    private float32 _WrittenReel = 0.0f;
    private FVector _WrittenBait = FVector::ZeroVector;
    private FTransform _WrittenLine = FTransform::Identity;
    private FVector _WrittenFish = FVector::ZeroVector;
    private float32 _WrittenSpotScale = -1.0f;
    private float32 _WhipLeft = 0.0f;
    private float32 _WhipSign = 1.0f;
    private float32 _JerkLeft = 0.0f;
    private float32 _StrainPitch = 0.0f;
    private float32 _ReelAngle = 0.0f;
    private TOptional<bool> _BaitShown;
    private TOptional<bool> _LineShown;
    private TOptional<bool> _FishShown;

    // A placed spot with no catch table fishes meat slabs (the fish food lands later); a spec with one keeps it.
    protected void Prepare_Kernel() override
    {
        if (Fishing.Fish.Table.Num() == 0)
        { Fishing.Fish.Table.Add(FMars_Fishing_FishEntry(utils_held_item::Make_DefinitionSoft(mars_items::Food_MeatSlab()), 1.0f, 1.0f)); }
    }

    // A rejected Fishing spec already ensured in utils_fishing::Add: the station stands with nothing to fish.
    protected bool Compose_Kernel(FCk_Handle& InHandle) override
    {
        Fishing.Setup.Frame = _Root;
        Fishing.Setup.Anchor = _TipNode;
        Fishing.Setup.Catch = _CatchNode;
        _FishingHandle = utils_fishing::Add(InHandle, Fishing);
        if (ck::Is_NOT_Valid(_FishingHandle))
        { return false; }

        _FishingHandle.BindTo_OnPhaseChanged(FMars_Delegate_Fishing_OnPhaseChanged(this, n"OnPhaseChanged"));
        _FishingHandle.BindTo_OnPresenceChanged(FMars_Delegate_Fishing_OnPresenceChanged(this, n"OnPresenceChanged"));
        _FishingHandle.BindTo_OnCast(FMars_Delegate_Fishing_OnCast(this, n"OnCast"));
        _FishingHandle.BindTo_OnBite(FMars_Delegate_Fishing_OnBite(this, n"OnBite"));
        _FishingHandle.BindTo_OnBiteEnded(FMars_Delegate_Fishing_OnBiteEnded(this, n"OnBiteEnded"));
        _FishingHandle.BindTo_OnLanded(FMars_Delegate_Fishing_OnLanded(this, n"OnLanded"));
        _FishingHandle.BindTo_OnCollected(FMars_Delegate_Fishing_OnCollected(this, n"OnCollected"));
        return true;
    }

    // The parts are hosted components: they die with their entities.
    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_FishingHandle))
        {
            _FishingHandle.UnbindFrom_OnPhaseChanged(FMars_Delegate_Fishing_OnPhaseChanged(this, n"OnPhaseChanged"));
            _FishingHandle.UnbindFrom_OnPresenceChanged(FMars_Delegate_Fishing_OnPresenceChanged(this, n"OnPresenceChanged"));
            _FishingHandle.UnbindFrom_OnCast(FMars_Delegate_Fishing_OnCast(this, n"OnCast"));
            _FishingHandle.UnbindFrom_OnBite(FMars_Delegate_Fishing_OnBite(this, n"OnBite"));
            _FishingHandle.UnbindFrom_OnBiteEnded(FMars_Delegate_Fishing_OnBiteEnded(this, n"OnBiteEnded"));
            _FishingHandle.UnbindFrom_OnLanded(FMars_Delegate_Fishing_OnLanded(this, n"OnLanded"));
            _FishingHandle.UnbindFrom_OnCollected(FMars_Delegate_Fishing_OnCollected(this, n"OnCollected"));
        }

        Super::DoEndPlay(InHandle);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Station hooks
    //----------------------------------------------------------------------------------------------------------------------

    // The stand k_StandBack behind the root (no counter here), then the station's own operation.
    protected void Configure_Spec(FMars_Station_Spec& InOutSpec) override
    {
        InOutSpec.StandLocal = FTransform(FRotator::ZeroRotator, FVector(-k_StandBack, 0.0, 0.0));
        Configure_Operation(InOutSpec);
    }

    // The Use probe: a box round the root, the bank's edge.
    protected TOptional<FMars_Interactable_ProbeInfo> Make_Probe() const override
    {
        auto Probe = FMars_Interactable_ProbeInfo();
        Probe.ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Interact);
        Probe.ProbeShape = utils_shapes::Make_Box(FCk_ShapeBox_Dimensions(k_ProbeHalfExtents));
        Probe.ProbeOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, k_ProbeHalfExtents.Z));
        return TOptional<FMars_Interactable_ProbeInfo>(Probe);
    }

    protected void Configure_Operation(FMars_Station_Spec& InOutSpec) override
    {
        // The right glove wraps the rear grip, the left the fore grip at the reel; both ride the rod.
        auto Grips = TArray<FMars_Station_Grip>();
        Grips.Add(Make_NodeGrip(EMars_Hand::Right, GameplayTags::Station_Node_Tool, EMars_HandGripPose::Power));
        Grips.Add(Make_NodeGrip(EMars_Hand::Left, GameplayTags::Station_Node_Reel, EMars_HandGripPose::Power));
        InOutSpec.Grips = Grips;

        // Free inside the cast's fence: the operator turns to aim and the rod follows.
        auto Camera = InOutSpec.Camera;
        Camera.LookControl = EMars_Station_LookControl::Free;
        Camera.YawHalfAngle = Fishing.Launch.YawHalfAngleDeg;
        Camera.PitchOffset = CameraPitch;
        Camera.ViewLocal = TOptional<FTransform>();
        InOutSpec.Camera = Camera;

        InOutSpec.Prompt = FMars_Station_PromptSpec(
            NSLOCTEXT("MarsInteraction", "FishHerePrompt", "Fish here"),
            NSLOCTEXT("MarsInteraction", "FishingStationInUsePrompt", "In use"));
        InOutSpec.MinigameStateClass = UMars_SmState_Fishing_Idle;
    }

    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        _Root = InRoot;

        // The bank's edge: a low slab at the root the operator stands behind.
        InRoot.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 2.0), FVector(0.3, 0.8, 0.04)),
            engine::load::Cube(), nullptr, collision::profile::NoCollision, n"FishingStation_Bank"));

        AddRod(InRoot);

        _CatchNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, CatchLocal)).As_Transform();

        // The bait, the line and the fish: nodes the dressing places from the kernel, their parts hidden until a line is out.
        _BaitNode = utils_scene_node::Create(InRoot, FTransform::Identity);
        auto BaitTransform = _BaitNode.As_Transform();
        const auto BaitScale = BaitSize / k_PrimitiveSpan;
        _BaitPart = BaitTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -BaitSize * 0.5), FVector(BaitScale, BaitScale, BaitScale)),
            engine::load::Cube(), nullptr, collision::profile::NoCollision, n"FishingStation_Bait"));

        _LineNode = utils_scene_node::Create(InRoot, FTransform::Identity);
        auto LineTransform = _LineNode.As_Transform();
        // Pitched -90, the cylinder's height runs along the node's +X; the dressing scales it to the line's length.
        _LinePart = LineTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator(-90.0, 0.0, 0.0), FVector::ZeroVector, FVector(LineRadius * 2.0 / k_PrimitiveSpan, LineRadius * 2.0 / k_PrimitiveSpan, 1.0)),
            engine::load::Cylinder(), nullptr, collision::profile::NoCollision, n"FishingStation_Line"));

        _FishNode = utils_scene_node::Create(InRoot, FTransform::Identity);
        auto FishTransform = _FishNode.As_Transform();
        const auto FishScale = FishSize / k_PrimitiveSpan;
        _FishPart = FishTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(FishScale, FishScale * 0.4, FishScale * 0.3)),
            engine::load::Cube(), nullptr, collision::profile::NoCollision, n"FishingStation_Fish"));

        // The spot's marker: a disc on the water, scaled by the spot's presence.
        _SpotNode = utils_scene_node::Create(InRoot, FTransform(FRotator::ZeroRotator, Get_SpotLocal()));
        auto SpotTransform = _SpotNode.As_Transform();
        const auto SpotScale = SpotRadius * 2.0 / k_PrimitiveSpan;
        _SpotPart = SpotTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector::ZeroVector, FVector(SpotScale, SpotScale, 0.01)),
            engine::load::Cylinder(), nullptr, collision::profile::NoCollision, n"FishingStation_Spot"));

        // Yawed 180 the text faces the operator's side.
        AddLabel(FTransform(FRotator(0.0, 180.0, 0.0), LabelLocal), EVerticalTextAligment::EVRTA_TextBottom, n"FishingStation_Label");
    }

    protected void Register_GripNodes(TArray<FMars_Station_GripNode>& OutNodes) override
    {
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Tool, _RearGripNode));
        OutNodes.Add(FMars_Station_GripNode(GameplayTags::Station_Node_Reel, _ForeGripNode));
    }

    // The rod: the aim node at the rod's root (yaw and pitch from the kernel's aim, plus the whip), the strain node under
    // it (the bow), and under that the rod's shaft along +X, the two grips, the reel and the tip.
    private void AddRod(FCk_Handle_Transform& InRoot)
    {
        _RodAimNode = utils_scene_node::Create(InRoot, FTransform(FRotator(RodRestPitch, 0.0, 0.0), RodRootLocal));
        _WrittenAim = FRotator(RodRestPitch, 0.0, 0.0);
        auto AimTransform = _RodAimNode.As_Transform();

        _RodStrainNode = utils_scene_node::Create(AimTransform, FTransform::Identity);
        auto StrainTransform = _RodStrainNode.As_Transform();

        // The shaft: the cylinder pitched -90 runs along +X from the rear grip to the tip.
        const auto ShaftWidth = RodRadius * 2.0 / k_PrimitiveSpan;
        StrainTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator(-90.0, 0.0, 0.0), FVector(RodLength * 0.5, 0.0, 0.0), FVector(ShaftWidth, ShaftWidth, RodLength / k_PrimitiveSpan)),
            engine::load::Cylinder(), nullptr, collision::profile::NoCollision, n"FishingStation_Rod"));

        // A right fist round the rear grip and a left fist round the fore grip: the fingers wrap under the rod, the right
        // palm faces the operator's left and the left palm the operator's right.
        _RearGripNode = utils_scene_node::Create(StrainTransform, FTransform(
            utils_fphands::Make_GripRotation(EMars_Hand::Right, -FVector::UpVector, -FVector::RightVector), FVector::ZeroVector)).As_Transform();
        _ForeGripNode = utils_scene_node::Create(StrainTransform, FTransform(
            utils_fphands::Make_GripRotation(EMars_Hand::Left, -FVector::UpVector, FVector::RightVector), FVector(ForeGripAlong, 0.0, 0.0))).As_Transform();

        // The reel under the fore grip, its handle an L the dressing spins about the reel's Y.
        _ReelNode = utils_scene_node::Create(StrainTransform, FTransform(FRotator::ZeroRotator, FVector(ReelAlong, 0.0, -ReelDrop)));
        auto ReelTransform = _ReelNode.As_Transform();
        const auto HandleWidth = 1.0 / k_PrimitiveSpan;
        ReelTransform.Add_MeshPart(this, FMars_MeshPart(
            FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -ReelHandleLength * 0.5), FVector(HandleWidth, HandleWidth, ReelHandleLength / k_PrimitiveSpan)),
            engine::load::Cylinder(), nullptr, collision::profile::NoCollision, n"FishingStation_ReelHandle"));

        _TipNode = utils_scene_node::Create(StrainTransform, FTransform(FRotator::ZeroRotator, FVector(RodLength, 0.0, 0.0))).As_Transform();
    }

    // The spot's marker on the water, out along +X: the water's world Z under the root's.
    private FVector Get_SpotLocal() const
    {
        const auto Distance = Fishing.Launch.MaxDistanceCm * SpotDistanceFraction;
        return FVector(Distance, 0.0, Fishing.Water.SurfaceZ - SpawnTransform.GetLocation().Z + SpotLift);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals (the Fishing feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    protected FText Get_StateLabel() const override
    {
        if (ck::Is_NOT_Valid(_FishingHandle))
        { return FText::FromString("spot not built"); }

        const auto Phase = _FishingHandle.Get_Phase();
        const auto Presence = _FishingHandle.Get_Presence();
        FString Line = f"{Phase :n}";
        if (Phase == EMars_Fishing_Phase::Reeling || Phase == EMars_Fishing_Phase::Hooked)
        { Line = f"{Line}: tension {int32(_FishingHandle.Get_Tension() * 100.0f)}% - line {int32(_FishingHandle.Get_LineLengthCm())} cm"; }
        else if (Phase == EMars_Fishing_Phase::Waiting || Phase == EMars_Fishing_Phase::Bite)
        { Line = f"{Line}: line {int32(_FishingHandle.Get_LineLengthCm())} cm"; }

        if (Presence != EMars_Fishing_Presence::Open)
        { Line = f"{Line}\n{Presence :n}"; }

        const auto Tally = _FishingHandle.Get_Tally();
        if (Tally == 0)
        { return FText::FromString(Line); }

        return FText::FromString(f"{Line}\ncaught: {Tally}");
    }

    private FTransform Get_RootWorld() const
    {
        return utils_transform::Get_EntityCurrentTransform(_Root);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The dressing (every frame; the Fishing feature is the source of truth)
    //----------------------------------------------------------------------------------------------------------------------

    protected void Dress(float32 InDeltaSeconds) override
    {
        if (ck::Is_NOT_Valid(_FishingHandle))
        { return; }

        Advance_Rod(InDeltaSeconds);
        Advance_Reel(InDeltaSeconds);
        Advance_Line();
        Advance_Fish();
        Advance_Spot();
    }

    // The aim node reads the kernel's aim plus the whip's arc; the strain node bows with the tension plus the jerk.
    private void Advance_Rod(float32 InDeltaSeconds)
    {
        const auto Aim = _FishingHandle.Get_Aim();
        auto WhipPitch = 0.0f;
        if (_WhipLeft > 0.0f)
        {
            _WhipLeft = Math::Max(0.0f, _WhipLeft - InDeltaSeconds);
            const auto T = 1.0f - _WhipLeft / WhipSeconds;
            // A short windup against the whip, then the whip through and a settle.
            WhipPitch = _WhipSign * (0.5f * WhipPitchDeg * Math::Sin(2.0f * PI * T) * Math::Exp(-2.0f * T) - WhipPitchDeg * Math::Sin(PI * T));
        }

        const auto AimRotation = FRotator(RodRestPitch + Aim.PitchDeg + WhipPitch, Aim.YawDeg, 0.0);
        Write_Rotation(_RodAimNode, AimRotation, _WrittenAim);

        _StrainPitch = Math::FInterpTo(_StrainPitch, -StrainPitchMax * _FishingHandle.Get_Tension(), InDeltaSeconds, StrainRate);
        auto JerkPitch = 0.0f;
        if (_JerkLeft > 0.0f)
        {
            _JerkLeft = Math::Max(0.0f, _JerkLeft - InDeltaSeconds);
            JerkPitch = -JerkPitchDeg * Math::Sin(PI * (1.0f - _JerkLeft / JerkSeconds));
        }

        Write_Rotation(_RodStrainNode, FRotator(_StrainPitch + JerkPitch, 0.0, 0.0), _WrittenStrain);
    }

    // The reel handle turns while the reel is held, faster through a run.
    private void Advance_Reel(float32 InDeltaSeconds)
    {
        if (_FishingHandle.Get_Reel() != EMars_Fishing_Reel::Held)
        { return; }

        const auto Scale = _FishingHandle.Get_IsRunning() ? ReelRunTurnScale : 1.0f;
        _ReelAngle = Math::Fmod(_ReelAngle + ReelTurnDegPerS * Scale * InDeltaSeconds, 360.0f);
        if (Math::Abs(_ReelAngle - _WrittenReel) < k_WriteToleranceDeg)
        { return; }

        utils_scene_node::Request_UpdateOffset(_ReelNode, FCk_Request_SceneNode_UpdateRelativeTransform(
            FTransform(FRotator(_ReelAngle, 0.0, 0.0), FVector(ReelAlong, 0.0, -ReelDrop))));
        _WrittenReel = _ReelAngle;
    }

    // The bait where the kernel floats or flies it, and the line from the rod tip to it; both hidden with no line out.
    private void Advance_Line()
    {
        const auto HasLine = _FishingHandle.Get_HasLineOut();
        Show_Part(_BaitPart, _BaitShown, HasLine);
        Show_Part(_LinePart, _LineShown, HasLine);
        if (HasLine == false)
        { return; }

        const auto RootWorld = Get_RootWorld();
        const auto BaitWorld = _FishingHandle.Get_BaitWorld();
        const auto BaitLocal = RootWorld.InverseTransformPosition(BaitWorld);
        if (BaitLocal.Distance(_WrittenBait) > k_WriteToleranceCm)
        {
            utils_scene_node::Request_UpdateOffset(_BaitNode, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator::ZeroRotator, BaitLocal)));
            _WrittenBait = BaitLocal;
        }

        const auto TipLocal = RootWorld.InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(_TipNode));
        const auto Span = BaitLocal - TipLocal;
        const auto Length = Span.Size();
        if (Length < 1.0)
        { return; }

        const auto LineTransform = FTransform(FRotator::MakeFromXZ(Span / Length, FVector::UpVector), TipLocal + Span * 0.5,
            FVector(1.0, 1.0, Length / k_PrimitiveSpan));
        if (LineTransform.Equals(_WrittenLine, k_WriteToleranceCm))
        { return; }

        utils_scene_node::Request_UpdateOffset(_LineNode, FCk_Request_SceneNode_UpdateRelativeTransform(LineTransform));
        _WrittenLine = LineTransform;
    }

    // The landed fish on its fling from the water to the catch point; hidden otherwise.
    private void Advance_Fish()
    {
        const auto IsLanded = _FishingHandle.Get_Phase() == EMars_Fishing_Phase::Landed;
        Show_Part(_FishPart, _FishShown, IsLanded);
        if (IsLanded == false)
        { return; }

        const auto FishLocal = Get_RootWorld().InverseTransformPosition(_FishingHandle.Get_FishWorld());
        if (FishLocal.Distance(_WrittenFish) <= k_WriteToleranceCm)
        { return; }

        utils_scene_node::Request_UpdateOffset(_FishNode, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(FRotator::ZeroRotator, FishLocal)));
        _WrittenFish = FishLocal;
    }

    // The spot's marker grows with the spot's presence.
    private void Advance_Spot()
    {
        const auto Scale = Math::Max(0.01f, _FishingHandle.Get_PresenceAlpha());
        if (Math::Abs(Scale - _WrittenSpotScale) < 0.01f)
        { return; }

        utils_scene_node::Request_UpdateOffset(_SpotNode, FCk_Request_SceneNode_UpdateRelativeTransform(
            FTransform(FRotator::ZeroRotator, Get_SpotLocal(), FVector(Scale, Scale, 1.0))));
        _WrittenSpotScale = Scale;
    }

    private void Write_Rotation(FCk_Handle_SceneNode InNode, FRotator InRotation, FRotator& InOutWritten)
    {
        if (InRotation.Equals(InOutWritten, k_WriteToleranceDeg))
        { return; }

        const auto Location = InNode == _RodAimNode ? RodRootLocal : FVector::ZeroVector;
        utils_scene_node::Request_UpdateOffset(InNode, FCk_Request_SceneNode_UpdateRelativeTransform(FTransform(InRotation, Location)));
        InOutWritten = InRotation;
    }

    // InPart shown or hidden once per change; a part whose component is not created yet is retried next frame.
    private void Show_Part(FCk_Handle_UnrealComponent InPart, TOptional<bool>& InOutShown, bool InShow)
    {
        if (InOutShown.IsSet() && InOutShown.GetValue() == InShow)
        { return; }

        if (ck::Is_NOT_Valid(InPart))
        { return; }

        auto Component = Cast<UStaticMeshComponent>(utils_unreal_component::Get_Component(InPart));
        if (ck::Is_NOT_Valid(Component))
        { return; }

        Component.SetVisibility(InShow);
        InOutShown = TOptional<bool>(InShow);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Phase InPhase)
    {
        Refresh_Label();
    }

    UFUNCTION()
    private void OnPresenceChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Presence InPresence)
    {
        Refresh_Label();
    }

    // The rod whips down and through as the bait leaves.
    UFUNCTION()
    private void OnCast(FCk_Handle_Fishing InFishing, FVector InLaunchVelocity)
    {
        _WhipLeft = WhipSeconds;
        _WhipSign = 1.0f;
    }

    UFUNCTION()
    private void OnBite(FCk_Handle_Fishing InFishing)
    {
        _JerkLeft = JerkSeconds;
    }

    UFUNCTION()
    private void OnBiteEnded(FCk_Handle_Fishing InFishing, EMars_Fishing_BiteResult InResult)
    {
        if (InResult == EMars_Fishing_BiteResult::Hooked)
        { _JerkLeft = JerkSeconds; }
    }

    // The rod flicks up as the fish leaves the water.
    UFUNCTION()
    private void OnLanded(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        _WhipLeft = WhipSeconds;
        _WhipSign = -1.0f;
        Refresh_Label();
    }

    UFUNCTION()
    private void OnCollected(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        Refresh_Label();
    }
}
