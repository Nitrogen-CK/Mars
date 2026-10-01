// Placeable stand-in head for the eyes (+X is its facing): a body, a hood and an eye plate on a face node that composes
// Gaze and Eyes, so the eyes blink and look at the nearest player in front. A looping timer plays the catalog's timed
// expressions in turn and moves to the next style after each full pass. Placed by Mars.Sandbox.PlaceEyesDummy
// (Script/Editor/Mars_SandboxMapBuilder.as); not under Script/Editor because the saved map references it at runtime.
class UMars_EyesDummy_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY(ExposeOnSpawn)
    FTransform SpawnTransform = FTransform::Identity;

    private FCk_Handle_Eyes _Eyes;
    private FCk_Handle_Timer _CycleTimer;
    private int32 _ExpressionIndex = -1;
    private int32 _StyleIndex = 0;

    private const float32 CycleSeconds = 2.5f;

    // Engine shapes are 100 uu with a centered pivot. Body: 60 across, 120 tall, standing on the origin; hood: 50 across
    // around the head node; the face node sits just in front of the hood.
    private const FVector BodyOffset = FVector(0.0, 0.0, 60.0);
    private const FVector BodyScale = FVector(0.6, 0.6, 1.2);
    private const FVector HeadOffset = FVector(0.0, 0.0, 135.0);
    private const FVector HoodScale = FVector(0.5, 0.5, 0.5);
    private const FVector FaceOffset = FVector(27.0, 0.0, 0.0);

    // Taking the engine plane's face as local +Z with U along local +X and V along local +Y: the yaw and roll turn its face
    // to the face node's +X with U along +Y, and the negative Y scale sends V down. U must grow toward +Y because the look
    // moves the shapes toward +U for a target on the face's right (Get_LookOffset X > 0). 24 x 12 cm.
    private const FRotator PlateRotation = FRotator(0.0, 90.0, -90.0);
    private const FVector PlateScale = FVector(0.24, -0.12, 1.0);

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        auto Root = utils_transform::Add(InHandle, SpawnTransform, ECk_Replication::DoesNotReplicate);

        // Where cosmetics cannot run (a dedicated server) the dummy is only its nodes, its Head attach point and the
        // eyes' logic: no meshes, no look master, no gaze and no expression cycling.
        const auto CanShowCosmetics = utils_net::Get_CanExecuteCosmeticEvents(InHandle);

        UMaterialInterface LookMaster = nullptr;
        if (CanShowCosmetics)
        {
            LookMaster = utils_usf::Get_LookMasterMaterial(mars_eyes::Look_EyePlate());
            // No stand-in material: without the generated look there is no hood and no plate; gaze and eyes stay.
            ck::EnsureIfNot(ck::IsValid(LookMaster),
                f"[EyesDummy] [{InHandle.ToString()}] the MarsEyePlate look master is not generated - run Ck_Usf_GenerateLooks MarsEyePlate");

            AddMesh(Root, FTransform(FRotator::ZeroRotator, BodyOffset, BodyScale),
                MakeArchetype(engine::load::Cylinder(), assets::load::ProtoGrid_Item_Mars_MI()), n"EyesDummy_Body");
        }
        const auto HasLookMaster = ck::IsValid(LookMaster);

        auto Head = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, HeadOffset)).As_Transform();
        utils_handle::Set_DebugName(FCk_Handle(Head), n"EyesDummy.Head");

        // With no custom primitive data written the look's strength is 0, so the hood renders as the black void.
        if (HasLookMaster)
        {
            AddMesh(Head, FTransform(FRotator::ZeroRotator, FVector::ZeroVector, HoodScale),
                MakeArchetype(engine::load::Sphere(), LookMaster), n"EyesDummy_Hood");
        }

        auto Face = utils_scene_node::Create(Head, FTransform(FRotator::ZeroRotator, FaceOffset)).As_Transform();
        utils_handle::Set_DebugName(FCk_Handle(Face), n"EyesDummy.Face");

        auto Plate = FCk_Handle_UnrealComponent();
        if (HasLookMaster)
        {
            auto PlateArchetype = MakeArchetype(engine::load::Plane(), LookMaster);
            if (ck::IsValid(PlateArchetype))
            { PlateArchetype.SetCastShadow(false); }

            Plate = AddMesh(Face, FTransform(PlateRotation, FVector::ZeroVector, PlateScale), PlateArchetype, n"EyesDummy_Plate");
        }

        // Other gazes look at the dummy's head.
        auto AttachPointsSpec = FMars_AttachPoints_Spec();
        AttachPointsSpec.Points.Add(FMars_AttachPoint_Entry(GameplayTags::AttachPoint_Mars_Head, Head));
        utils_attach_points::Add(InHandle, AttachPointsSpec);

        if (CanShowCosmetics)
        {
            auto GazeSpec = FMars_Gaze_Spec();
            GazeSpec.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);
            GazeSpec.AimPoint = GameplayTags::AttachPoint_Mars_Head;
            utils_gaze::Add(Face, GazeSpec);
        }

        auto EyesSpec = FMars_Eyes_Spec();
        EyesSpec.Style = mars_eyes::Catalog().Styles[_StyleIndex].Def;
        _Eyes = utils_eyes::Add(Face, EyesSpec);

        if (ck::IsValid(_Eyes) && ck::IsValid(Plate))
        { _Eyes.Set_Plate(Plate); }

        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(_Eyes) || utils_net::Get_CanExecuteCosmeticEvents(InHandle) == false)
        { return; }

        auto TimerSpec = FCk_Timer_Spec(FCk_Time(CycleSeconds));
        TimerSpec.Set_StartingState(ECk_Timer_State::Running)
                 .Set_Behavior(ECk_Timer_Behavior::ResetOnDone);

        _CycleTimer = utils_timer::Add(InHandle, TimerSpec);
        if (ck::IsValid(_CycleTimer))
        { _CycleTimer.BindTo_OnDone(FCk_Delegate_Timer(this, n"OnCycleDone")); }
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (ck::IsValid(_CycleTimer))
        {
            _CycleTimer.UnbindFrom_OnDone(FCk_Delegate_Timer(this, n"OnCycleDone"));
            utils_entity_lifetime::Request_DestroyEntity(FCk_Handle(_CycleTimer));
        }

        _CycleTimer = FCk_Handle_Timer();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Visuals
    //----------------------------------------------------------------------------------------------------------------------

    // NewObject needs a UObject outer, hence a private method on the entity script. Nothing on the dummy collides.
    private UStaticMeshComponent MakeArchetype(UStaticMesh InMesh, UMaterialInterface InMaterial)
    {
        if (ck::Is_NOT_Valid(InMesh))
        { return nullptr; }

        auto Archetype = NewObject(this, UStaticMeshComponent);
        // Movable: the component is registered first and then receives the entity transform, which a Static component
        // refuses once the world has begun play.
        Archetype.SetMobility(EComponentMobility::Movable);
        Archetype.SetStaticMesh(InMesh);
        if (ck::IsValid(InMaterial))
        { Archetype.SetMaterial(0, InMaterial); }
        Archetype.SetCollisionProfileName(collision::profile::NoCollision);
        return Archetype;
    }

    private FCk_Handle_UnrealComponent AddMesh(
        FCk_Handle_Transform& InAttachTo,
        FTransform InLocalTransform,
        UStaticMeshComponent InArchetype,
        FName InDebugName)
    {
        if (ck::Is_NOT_Valid(InArchetype))
        { return FCk_Handle_UnrealComponent(); }

        auto Node = utils_scene_node::Create(InAttachTo, InLocalTransform);
        auto NodeEntity = FCk_Handle(Node);

        auto ComponentParams = utils_unreal_component::Make_Params_FromArchetype(
            InArchetype, ECk_UnrealComponent_TickPolicy::DoNotTick, InDebugName);
        return utils_unreal_component::Add(NodeEntity, ComponentParams);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    // Plays the next catalog expression that runs out on its own; state expressions (no duration, e.g. Downed) would
    // never expire, so they are skipped. Wrapping past the last expression moves to the next style.
    UFUNCTION()
    private void OnCycleDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (ck::Is_NOT_Valid(_Eyes))
        { return; }

        auto Catalog = mars_eyes::Catalog();
        const auto NumExpressions = Catalog.Expressions.Num();
        for (int32 Tried = 0; Tried < NumExpressions; ++Tried)
        {
            _ExpressionIndex++;
            if (_ExpressionIndex >= NumExpressions)
            {
                _ExpressionIndex = 0;
                _StyleIndex = (_StyleIndex + 1) % Catalog.Styles.Num();
                _Eyes.Request_SetStyle(FMars_Request_Eyes_SetStyle(Catalog.Styles[_StyleIndex].Def));
            }

            const auto Expression = Catalog.Expressions[_ExpressionIndex].Def;
            if (Expression.DurationSeconds <= 0.0f)
            { continue; }

            _Eyes.Request_PlayExpression(FMars_Request_Eyes_PlayExpression(Expression));
            return;
        }
    }
}
