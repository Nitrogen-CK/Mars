// Local composition bridge: replicated CampPartyState is the sole mission state. This never commits or departs.
// Local X crosses the gate, Y spans its opening, Z rises from its feet. No root scaling: tune Spec dimensions.
class UMars_CampMissionGate_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;
    UPROPERTY(ExposeOnSpawn)
    FMars_CampMissionGate_Spec Spec;

    private FCk_Handle_Gate _Gate;
    private FCk_Handle_Timer _StateWait;
    private TWeakObjectPtr<AMars_Camp_GameState> _State;
    private UStaticMesh _Box;
    private UMaterialInterface _Material;

    UFUNCTION()
    FCk_Handle_Gate Get_Gate() const
    { return _Gate; }

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Validation = Spec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[CampMissionGate] {Validation.Get_Error()}"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }
        if (ck::EnsureIfNot(SpawnTransform.IsValid() && SpawnTransform.GetScale3D().Equals(FVector::OneVector),
            "[CampMissionGate] root must be finite with unit scale; tune Spec.Opening instead"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        _Box = System::LoadAsset_Blocking(Spec.Look.UnitBox);
        _Material = System::LoadAsset_Blocking(Spec.Look.Material);
        if (ck::EnsureIfNot(ck::IsValid(_Box) && ck::IsValid(_Material), "[CampMissionGate] configured box or material did not load"))
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);
        auto GateSpec = FMars_Gate_Spec();
        GateSpec.OpenOffset = FVector(0.0, 0.0, Spec.Opening.Height + Spec.Motion.Clearance);
        GateSpec.MoveDuration = Spec.Motion.Duration;
        GateSpec.Threshold = MakeThreshold();
        _Gate = utils_gate::Add(Root, GateSpec);
        if (ck::Is_NOT_Valid(_Gate))
        { return ECk_EntityScript_ConstructionFlow::Finished; }
        utils_entity_tag::Add(InHandle, n"TAG_MarsCampMissionGate");
        AddFrame(Root);
        auto Leaf = _Gate.Get_MovingNode().As_Transform();
        AddLeaf(Leaf);
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(_Gate))
        { return; }
        if (TryBindState() == false)
        { _StateWait = utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWaitForState")); }
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        auto State = _State.Get();
        if (ck::IsValid(State))
        { State.OnPartyStateChanged.Unbind(this, n"OnPartyChanged"); }
        _State = nullptr;
        StopStateWait();
    }

    private bool TryBindState()
    {
        auto State = Cast<AMars_Camp_GameState>(Gameplay::GetGameState());
        if (ck::Is_NOT_Valid(State))
        { return false; }
        _State = TWeakObjectPtr<AMars_Camp_GameState>(State);
        State.OnPartyStateChanged.AddUFunction(this, n"OnPartyChanged");
        // Bind before reading: construction/late joins reconcile the current atomic value even without another edge.
        OnPartyChanged();
        return true;
    }

    UFUNCTION()
    private void OnPartyChanged()
    {
        auto State = _State.Get();
        if (ck::IsValid(State))
        { utils_camp_mission_gate::Request_Project(_Gate, State.Get_PartyState(), State.ServiceCatalog); }
    }

    UFUNCTION()
    private void OnWaitForState(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (TryBindState())
        { StopStateWait(); }
    }

    private void StopStateWait()
    {
        if (ck::IsValid(_StateWait))
        { utils_entity_lifetime::Request_DestroyEntity(_StateWait.H()); }
        _StateWait = FCk_Handle_Timer();
    }

    private FMars_Trigger_Spec MakeThreshold() const
    {
        auto Threshold = FMars_Trigger_Spec();
        Threshold.Shape = EMars_Trigger_Shape::Box;
        Threshold.BoxHalfExtents = FVector(Spec.Motion.ThresholdDepth, Spec.Opening.Width * 0.5, Spec.Opening.Height * 0.5);
        Threshold.LocalOffset = FTransform(FVector(0.0, 0.0, Spec.Opening.Height * 0.5));
        Threshold.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
        Threshold.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Backpack);
        return Threshold;
    }

    private void AddFrame(FCk_Handle_Transform& InRoot)
    {
        const auto& Opening = Spec.Opening;
        const auto PostY = (Opening.Width + Opening.FrameThickness) * 0.5;
        const auto FrameHeight = Opening.Height + Opening.FrameThickness;
        AddBox(InRoot, FVector(0.0, -PostY, FrameHeight * 0.5), FVector(Opening.FrameDepth, Opening.FrameThickness, FrameHeight));
        AddBox(InRoot, FVector(0.0, PostY, FrameHeight * 0.5), FVector(Opening.FrameDepth, Opening.FrameThickness, FrameHeight));
        AddBox(InRoot, FVector(0.0, 0.0, Opening.Height + Opening.FrameThickness * 0.5),
            FVector(Opening.FrameDepth, Opening.Width + Opening.FrameThickness * 2.0, Opening.FrameThickness));
    }

    private void AddLeaf(FCk_Handle_Transform& InLeaf)
    {
        const auto& Opening = Spec.Opening;
        const auto& Bars = Spec.Bars;
        const auto Spacing = Opening.Width / Bars.Count;
        const auto FirstY = -(Bars.Count - 1) * Spacing * 0.5;
        for (int32 Index = 0; Index < Bars.Count; ++Index)
        {
            AddBox(InLeaf, FVector(0.0, FirstY + Index * Spacing, Opening.Height * 0.5),
                FVector(Bars.Thickness, Bars.Thickness, Opening.Height));
        }
        AddBox(InLeaf, FVector(0.0, 0.0, Opening.Height - Bars.RailHeight * 0.5),
            FVector(Bars.Thickness + 4.0, Opening.Width, Bars.RailHeight));
        AddBox(InLeaf, FVector(0.0, 0.0, Opening.Height * 0.4),
            FVector(Bars.Thickness + 4.0, Opening.Width, Bars.RailHeight));
    }

    // UE mesh collision blocks CharacterMovement; explicit Jolt boxes block loose physics objects.
    // Bodies retain unit scale; only the mesh child scales the authored 100cm box. Both follow the mover.
    private void AddBox(FCk_Handle_Transform& InParent, FVector InCenter, FVector InSize)
    {
        auto Node = utils_scene_node::Create(InParent, FTransform(InCenter)).As_Transform();
        Node.Add_MeshPart(this, FMars_MeshPart(FTransform(FRotator::ZeroRotator, FVector::ZeroVector, InSize * 0.01),
            _Box, _Material, collision::profile::BlockAllDynamic, n"CampMissionGate.Box"));
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InSize * 0.5);
        auto Body = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        Body.Set_ShapeDimensions(Shape);
        Body.Set_MotionType(ECk_MotionType::Kinematic);
        Body.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        Body.Set_MassKg(100.0f);
        Body.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        Body.Set_CollisionProfileName(collision::profile::BlockAll);
        utils_jolt_body::Add(Node.H(), Body);
    }
}
