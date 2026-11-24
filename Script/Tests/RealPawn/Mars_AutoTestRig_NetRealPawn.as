// The real-pawn net tests' shared steps, on top of the player-combat net rig: the production AMars_PlayerCharacter, spawned
// by the server and possessed by the client's controller (or by the host's own), composes and runs its own state machine,
// hotbar, hands and held item, so a row reads what a player would see on each machine rather than a test carrier. The
// server also lays a Jolt slab at the floor's top (world items are Jolt bodies; the engine cube under the pawn is not one)
// and spawns world items under the replicated spawn owner. The server reports to the client through a test-only
// replicated fragment on the subject.

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only: a feature's processors are
// the only writers in game code).
struct FMars_Fragment_TESTONLY_NetRealPawnReport
{
    // Where the server's thrown world item was when the server first saw it.
    UPROPERTY()
    FVector LaunchOrigin = FVector::ZeroVector;

    // The server's copy of the thrower's hand attach point at that moment.
    UPROPERTY()
    FVector ServerHand = FVector::ZeroVector;

    // A held item on the server's copy of its holder (Write_HandReport): its root's distance from the body's grip_r, and
    // from HeldOffset on the server's hand attach point; -1 without a settled presentation in the hand.
    UPROPERTY()
    float64 HeldFromBodyGripCm = -1.0;

    UPROPERTY()
    float64 HeldFromHandMountCm = -1.0;

    // The server's copy of the hand mount rides the body (Player.BodyGrip).
    UPROPERTY()
    bool IsMountOnBody = false;

    // Write_ViewReport: the largest angle, measured at the end of every frame the server sampled, between the server's
    // copy of the client's view forward and the forward the client turned to; -1 before it is measured.
    UPROPERTY()
    float64 ViewMaxAngleDeg = -1.0;

    UPROPERTY()
    int32 ViewSamples = 0;

    UPROPERTY()
    int32 Serial = 0;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetRealPawn : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 28.0f;

    protected const float64 k_JoltFloorHalfExtent = 900.0;
    // Where a world item is spawned for the pawn, from the base: in front of it, clear of the capsule.
    protected const FVector k_ItemFromBase = FVector(120.0, 0.0, 20.0);

    private APlayerController _LocalController;
    private APawn _LocalPreviousPawn;
    private float64 _DeadlineAt = 0.0;

    //------------------------------------------------------------------------------------------------------------------
    // Spawning
    //------------------------------------------------------------------------------------------------------------------

    // Server: the Jolt slab under InTestEntity (it dies with the test), its top at the base's Z.
    protected void Spawn_ServerJoltFloor(FCk_Handle InTestEntity)
    {
        Spawn_ServerJoltFloorAt(InTestEntity, _Base);
    }

    // Server: the Jolt slab under InTestEntity, its top centre at InTop.
    protected void Spawn_ServerJoltFloorAt(FCk_Handle InTestEntity, FVector InTop)
    {
        auto Owner = InTestEntity;
        auto Slab = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Slab, FTransform(FRotator::ZeroRotator, InTop - FVector(0.0, 0.0, 10.0)), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(FVector(k_JoltFloorHalfExtent, k_JoltFloorHalfExtent, 10.0));
        auto SlabSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        SlabSpec.Set_ShapeDimensions(Shape);
        SlabSpec.Set_MotionType(ECk_MotionType::Static);
        SlabSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Slab, SlabSpec);
    }

    // Server: a World-mode item of InDefinition at InLocation under the replicated spawn owner, tracked for cleanup.
    protected FCk_Handle Spawn_ServerWorldItem(UCk_InventoryItem_Definition InDefinition, FVector InLocation)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto Spec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(InDefinition), FTransform(FRotator::ZeroRotator, InLocation));
        auto Entity = utils_world_item::Request_SpawnWorld(Owner, Spec);
        Track_ForCleanup(Entity);
        return Entity;
    }

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // Server: the pawn's copy is composed and the spawn owner is published.
    UFUNCTION()
    protected void Is_ServerPawnAndOwnerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    //------------------------------------------------------------------------------------------------------------------
    // Finding
    //------------------------------------------------------------------------------------------------------------------

    // This machine's linked World-mode world item of InDefinition within InRadius of InNear in X and Y; invalid without one.
    protected FCk_Handle_WorldItem Find_WorldItemNear(UCk_InventoryItem_Definition InDefinition, FVector InNear, float64 InRadius)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Item = WorldItem.Get_HeldItem();
            if (ck::Is_NOT_Valid(Item) || Item.Get_Definition() != InDefinition)
            { continue; }

            const auto Location = Get_RootLocation(Candidate);
            if (FVector2D(Location.X - InNear.X, Location.Y - InNear.Y).Size() < InRadius)
            { return WorldItem; }
        }

        return FCk_Handle_WorldItem();
    }

    // This machine's World-mode world item nearest InNear, anywhere; invalid without one.
    protected FCk_Handle_WorldItem Find_AnyWorldModeItem(FVector InNear)
    {
        FCk_Handle_WorldItem Found;
        auto Nearest = -1.0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            auto WorldItem = Candidate.As_WorldItem(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(WorldItem) || WorldItem.Get_Mode() != EMars_WorldItem_Mode::World)
            { continue; }

            const auto Distance = (Get_RootLocation(Candidate) - InNear).Size();
            if (Nearest >= 0.0 && Distance >= Nearest)
            { continue; }

            Found = WorldItem;
            Nearest = Distance;
        }

        return Found;
    }

    protected FVector Get_RootLocation(FCk_Handle InEntity)
    {
        return utils_transform::Get_EntityCurrentTransform(InEntity.As_Transform()).GetLocation();
    }

    protected bool Get_IsDefinition(FCk_Handle_Item InItem, UCk_InventoryItem_Definition InDefinition)
    {
        return ck::IsValid(InItem) && InItem.Get_Definition() == InDefinition;
    }

    //------------------------------------------------------------------------------------------------------------------
    // The player's state machine, every level
    //------------------------------------------------------------------------------------------------------------------

    // The current state class of InSm and of every running sub-SM under it, depth first (a sub-SM is a lifetime dependent
    // of its hosting state, a level or two down: the task's entity, then the sub-SM).
    protected TArray<UClass> Get_ActiveStates(FCk_Handle_StateMachine InSm)
    {
        auto States = TArray<UClass>();
        Collect_ActiveStates(InSm, States, 0);
        return States;
    }

    private void Collect_ActiveStates(FCk_Handle_StateMachine InSm, TArray<UClass>& OutStates, int32 InDepth)
    {
        if (ck::Is_NOT_Valid(InSm) || InDepth > 4)
        { return; }

        const auto StateClass = utils_state_machine::Get_CurrentStateClass(InSm);
        const auto State = utils_state_machine::Get_CurrentStateHandle(InSm);
        if (ck::Is_NOT_Valid(State))
        { return; }

        OutStates.Add(StateClass.Get());
        auto Frontier = utils_entity_lifetime::Get_LifetimeDependents(State);
        for (int32 Level = 0; Level < 2 && Frontier.Num() > 0; ++Level)
        {
            auto Next = TArray<FCk_Handle>();
            for (auto Entity : Frontier)
            {
                const auto SubSm = Entity.As_StateMachine(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(SubSm))
                {
                    Collect_ActiveStates(SubSm, OutStates, InDepth + 1);
                    continue;
                }

                Next.Append(Entity.Get_LifetimeDependents());
            }

            Frontier = Next;
        }
    }

    protected bool Get_IsStateActive(TSubclassOf<UCk_SmState_EntityScript> InStateClass)
    {
        return Get_HasState(Get_ActiveStates(_Sm), InStateClass);
    }

    protected bool Get_HasState(const TArray<UClass>& InStates, TSubclassOf<UCk_SmState_EntityScript> InStateClass)
    {
        return InStates.Contains(InStateClass.Get());
    }

    protected FString Describe_ActiveStates()
    {
        auto Text = "";
        for (auto StateClass : Get_ActiveStates(_Sm))
        { Text += f"{StateClass.GetName()} "; }

        return Text;
    }

    //------------------------------------------------------------------------------------------------------------------
    // The player
    //------------------------------------------------------------------------------------------------------------------

    // The client's own copy is composed, locally controlled, its state machine has entered Locomotion's idle and its hotbar
    // has adopted every slot.
    protected bool Get_IsClientOwnerReady()
    {
        if (Get_IsPawnComposed() == false || _Pawn.IsLocallyControlled() == false)
        { return false; }

        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Hotbar) && Hotbar.Get_IsReady() && Get_IsStateActive(UMars_SmState_Loco_Idle);
    }

    UFUNCTION()
    protected void Is_ClientOwnerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsClientOwnerReady());
    }

    protected FCk_Handle_HeldItem Get_HeldItem()
    {
        return _Player.As_HeldItem(ECk_SanityCheck::UnChecked);
    }

    // This machine's HeldItem holds an item of InDefinition.
    protected bool Get_IsHolding(UCk_InventoryItem_Definition InDefinition)
    {
        const auto HeldItem = Get_HeldItem();
        return ck::IsValid(HeldItem) && Get_IsDefinition(HeldItem.Get_CurrentItem(), InDefinition);
    }

    // This machine's held presentation sits at the hand: in the hand and settled, its root within InToleranceCm of the hand
    // attach point composed with the item's HeldOffset.
    protected bool Get_IsPresentationAtHand(float64 InToleranceCm)
    {
        const auto Error = Get_PresentationErrorCm();
        return Error >= 0.0 && Error <= InToleranceCm;
    }

    // How far the held presentation's root is from the hand attach point composed with the item's HeldOffset; -1 without a
    // settled presentation in the hand. A settle check (the item rides its mount at HeldOffset), not a placement check: it
    // holds wherever this machine's hand mount is, so a row about where the hand is pairs it with a distance to the body's
    // grip (Get_PresentationFromBodyGripCm) or to the other machine's report.
    protected float64 Get_PresentationErrorCm()
    {
        const auto HeldItem = Get_HeldItem();
        if (ck::Is_NOT_Valid(HeldItem) || HeldItem.Get_IsPresentationInHand() == false || HeldItem.Get_IsPresentationSettled() == false)
        { return -1.0; }

        const auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item.Has_Presentation() == false)
        { return -1.0; }

        const auto Expected = Item.Get_Presentation().Mounting.HeldOffset * utils_transform::Get_EntityCurrentTransform(HeldItem.Get_HandAttachPoint());
        return (Get_RootLocation(HeldItem.Get_PresentationEntity()) - Expected.GetLocation()).Size();
    }

    // How far the held presentation's root is from this machine's copy of the body's grip_r; -1 without a settled
    // presentation in the hand.
    protected float64 Get_PresentationFromBodyGripCm()
    {
        const auto HeldItem = Get_HeldItem();
        if (ck::Is_NOT_Valid(_Pawn) || ck::Is_NOT_Valid(HeldItem) || HeldItem.Get_IsPresentationInHand() == false
            || HeldItem.Get_IsPresentationSettled() == false)
        { return -1.0; }

        const auto Grip = _Pawn.Mesh.GetSocketTransform(n"grip_r").GetLocation();
        return (Get_RootLocation(HeldItem.Get_PresentationEntity()) - Grip).Size();
    }

    // This machine's copy of the hand mount is under the body's grip node.
    protected bool Get_IsMountOnBody()
    {
        return Get_MountParent() == _Pawn.Get_BodyGrip().As_Transform();
    }

    // This machine's copy of the hand mount is under the gloves' hand node.
    protected bool Get_IsMountFirstPerson()
    {
        const auto Hands = _Player.As_FPHands(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Hands) && Get_MountParent() == Hands.Get_HandNode();
    }

    private FCk_Handle_Transform Get_MountParent()
    {
        if (ck::Is_NOT_Valid(_Pawn))
        { return FCk_Handle_Transform(); }

        FCk_Handle MountEntity = _Pawn.Get_HandMount();
        const auto SceneNode = MountEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(SceneNode))
        { return FCk_Handle_Transform(); }

        return utils_scene_node::Get_Parent(SceneNode);
    }

    // The machine that controls the pawn: its view turns to InWorldRotation (the camera director drives the controller's
    // rotation, and the pawn takes the controller's yaw).
    protected void Request_ServerTurnView(FRotator InWorldRotation)
    {
        auto Camera = _Player.As_PlayerViewpoint().Get_Camera();
        utils_camera::Request_SnapBoomRotation(Camera, InWorldRotation);
    }

    // This machine's copy of the pawn faces within InToleranceDeg of InYaw.
    protected bool Get_IsFacingYaw(float64 InYaw, float64 InToleranceDeg)
    {
        return ck::IsValid(_Pawn) && Math::Abs(Math::FindDeltaAngleDegrees(_Pawn.GetActorRotation().Yaw, InYaw)) <= InToleranceDeg;
    }

    // The mesh this machine's copy of the pawn draws for its owner's held-item shadow (HeldItemShadow); null for none.
    protected UStaticMesh Get_HeldItemShadowMesh()
    {
        if (ck::Is_NOT_Valid(_Pawn))
        { return nullptr; }

        return _Pawn.HeldItemShadow.GetStaticMesh();
    }

    protected FString Describe_Mesh(const UStaticMesh InMesh)
    {
        return ck::IsValid(InMesh) ? InMesh.GetName().ToString() : "none";
    }

    // This machine's held presentation is a Visual-mode world item (the one HeldItem spawns for a transient item).
    protected bool Get_IsPresentationVisual()
    {
        const auto HeldItem = Get_HeldItem();
        if (ck::Is_NOT_Valid(HeldItem))
        { return false; }

        const auto WorldItem = HeldItem.Get_PresentationEntity().As_WorldItem(ECk_SanityCheck::UnChecked);
        return ck::IsValid(WorldItem) && WorldItem.Get_Mode() == EMars_WorldItem_Mode::Visual;
    }

    // This machine's held presentation has an Arrival in flight (a start pose still travelling to, or anchored off, its
    // hold offset).
    protected bool Get_IsPresentationArriving()
    {
        const auto HeldItem = Get_HeldItem();
        return ck::IsValid(HeldItem) && HeldItem.Get_PresentationEntity().Has_Fragment(FMars_Fragment_WorldItem_Arrival);
    }

    // The first static mesh component of this machine's held presentation; null for none.
    protected UStaticMeshComponent Get_PresentationMeshComponent()
    {
        const auto HeldItem = Get_HeldItem();
        if (ck::Is_NOT_Valid(HeldItem))
        { return nullptr; }

        for (auto Primitive : utils_fphands::Get_TreePrimitives(HeldItem.Get_PresentationEntity()))
        {
            auto Mesh = Cast<UStaticMeshComponent>(Primitive);
            if (ck::IsValid(Mesh))
            { return Mesh; }
        }

        return nullptr;
    }

    // This machine's copy of the player's view forward (the view anchor's +X).
    protected FVector Get_ViewForward()
    {
        return utils_transform::Get_EntityCurrentTransform(_Player.As_PlayerViewpoint().Get_Viewpoint()).GetRotation().GetForwardVector();
    }

    // A probe on this machine that samples, at the end of every frame, the angle between this machine's copy of the
    // player's view forward and InTargetForward (AMars_AutoTestProbe_ViewForward); null when it does not spawn. Not
    // sampling until told.
    protected AMars_AutoTestProbe_ViewForward Spawn_ViewProbe(FVector InTargetForward)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Probe = Cast<AMars_AutoTestProbe_ViewForward>(SpawnActor(AMars_AutoTestProbe_ViewForward, _Base));
        if (ck::Is_NOT_Valid(Probe))
        { return nullptr; }

        Probe.Player = _Player;
        Probe.TargetForward = InTargetForward.GetSafeNormal();
        return Probe;
    }

    // A probe on this machine that samples, at the end of every frame, how far InItemRoot trails this machine's copy of
    // the body's grip_r (AMars_AutoTestProbe_BodyHandLag); null when it does not spawn. Not sampling until told.
    protected AMars_AutoTestProbe_BodyHandLag Spawn_BodyHandProbe(FCk_Handle_Transform InItemRoot, FTransform InHeldOffset)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Probe = Cast<AMars_AutoTestProbe_BodyHandLag>(SpawnActor(AMars_AutoTestProbe_BodyHandLag, _Base));
        if (ck::Is_NOT_Valid(Probe))
        { return nullptr; }

        Probe.Pawn = _Pawn;
        Probe.ItemRoot = InItemRoot;
        Probe.HeldOffset = InHeldOffset;
        return Probe;
    }

    //------------------------------------------------------------------------------------------------------------------
    // The host's own controller
    //------------------------------------------------------------------------------------------------------------------

    // Server: hands InPawn to the one player controller in its world that is local (the host's own). False (nothing
    // possessed) without exactly one.
    protected bool Request_ServerPossessByLocal(APawn InPawn)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Controllers = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(APlayerController, Controllers);

        APlayerController Local;
        auto Count = 0;
        for (auto Actor : Controllers)
        {
            auto Controller = Cast<APlayerController>(Actor);
            if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController() == false)
            { continue; }

            Local = Controller;
            Count += 1;
        }

        if (Count != 1)
        { return false; }

        _LocalController = Local;
        _LocalPreviousPawn = Local.GetControlledPawn();
        Local.Possess(InPawn);
        return true;
    }

    // Server: the host's own controller gets its old pawn back. Safe to call twice.
    protected void Request_ServerReturnLocal()
    {
        if (ck::Is_NOT_Valid(_LocalController))
        { return; }

        if (ck::IsValid(_Pawn) && _LocalController.GetControlledPawn() == _Pawn)
        { _LocalController.UnPossess(); }

        if (ck::IsValid(_LocalPreviousPawn) && _LocalController.GetControlledPawn() != _LocalPreviousPawn)
        { _LocalController.Possess(_LocalPreviousPawn); }

        _LocalController = nullptr;
    }

    protected void TearDown() override
    {
        Request_ServerReturnLocal();
        Super::TearDown();
    }

    //------------------------------------------------------------------------------------------------------------------
    // The server's report
    //------------------------------------------------------------------------------------------------------------------

    // Composed on the subject on both machines; a second call adds nothing.
    protected void Add_Report()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetRealPawnReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetRealPawnReport(), ECk_Replication::Replicates); }
    }

    protected void Write_Report(FVector InLaunchOrigin, FVector InServerHand)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetRealPawnReport);
        Report.LaunchOrigin = InLaunchOrigin;
        Report.ServerHand = InServerHand;
        Report.Serial += 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetRealPawnReport);
    }

    // Where the server's copy of the held presentation sits on its holder (see the report's fields).
    protected void Write_HandReport()
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetRealPawnReport);
        Report.HeldFromBodyGripCm = Get_PresentationFromBodyGripCm();
        Report.HeldFromHandMountCm = Get_PresentationErrorCm();
        Report.IsMountOnBody = Get_IsMountOnBody();
        Report.Serial += 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetRealPawnReport);
    }

    // What the server's view probe measured (see the report's fields).
    protected void Write_ViewReport(float64 InMaxAngleDeg, int32 InSamples)
    {
        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetRealPawnReport);
        Report.ViewMaxAngleDeg = InMaxAngleDeg;
        Report.ViewSamples = InSamples;
        Report.Serial += 1;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetRealPawnReport);
    }

    protected FMars_Fragment_TESTONLY_NetRealPawnReport Get_Report()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetRealPawnReport);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Deadlines: a waiting side stops waiting and asserts, so a red row names what it did not see
    //------------------------------------------------------------------------------------------------------------------

    // InSeconds from now; the net stub's hard limit is 30 s per world, from its start.
    protected void Mark_Deadline(float64 InSeconds)
    {
        _DeadlineAt = Get_NowSeconds() + InSeconds;
    }

    protected bool Get_IsPastDeadline()
    {
        return Get_NowSeconds() >= _DeadlineAt;
    }

    private float64 Get_NowSeconds()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        return System::GetGameTimeInSeconds();
    }

    // The row's one log line on this machine.
    protected void Log_RealPawnRow(FString InRow, FString InExtra)
    {
        const auto IsLocal = ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled();
        const auto Line = f"[RealPawnNetTest] {InRow} {Get_MachineName()} local={IsLocal} states=[{Describe_ActiveStates()}] ensures={Get_NewEnsures()} {InExtra}";
        Log(Line);
    }
}

// Samples, at the end of every frame (TG_LastDemotable: after the camera composed the view and the late pose pass ran),
// the angle between this machine's copy of Player's view forward and TargetForward, while IsSampling.
class AMars_AutoTestProbe_ViewForward : AActor
{
    FCk_Handle Player;
    FVector TargetForward = FVector::ForwardVector;
    bool IsSampling = false;

    float64 MaxAngleDeg = 0.0;
    float64 LastAngleDeg = -1.0;
    int32 Samples = 0;

    UFUNCTION(BlueprintOverride)
    void BeginPlay()
    {
        SetTickGroup(ETickingGroup::TG_LastDemotable);
    }

    UFUNCTION(BlueprintOverride)
    void Tick(float DeltaSeconds)
    {
        if (IsSampling == false || ck::Is_NOT_Valid(Player))
        { return; }

        const auto Viewpoint = Player.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Viewpoint))
        { return; }

        const auto Forward = utils_transform::Get_EntityCurrentTransform(Viewpoint.Get_Viewpoint()).GetRotation().GetForwardVector();
        LastAngleDeg = Math::RadiansToDegrees(Math::Acos(Math::Clamp(Forward.DotProduct(TargetForward), -1.0, 1.0)));
        MaxAngleDeg = Math::Max(MaxAngleDeg, LastAngleDeg);
        Samples += 1;
    }
}
