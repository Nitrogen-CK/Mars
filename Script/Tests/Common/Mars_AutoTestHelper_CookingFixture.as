// What a cooking test's interaction ended with: every finish of a watched target with its result and every failure a
// watched interactable reported with its reason, in arrival order. A test watches the target it starts an interaction on
// and the interactable that owns it, then asserts the outcome by target.
class UMars_AutoTestHelper_InteractionOutcomes : UObject
{
    // In parallel: one entry per OnInteractionFinished of a watched target.
    private TArray<FCk_Handle_InteractTarget> _FinishedTargets;
    private TArray<ECk_SucceededFailed> _FinishedResults;
    // One entry per OnInteractionFailed of a watched interactable.
    private TArray<FMars_Interactable_Failure> _Failures;

    void Watch_Target(FCk_Handle_InteractTarget InTarget)
    {
        auto Target = InTarget;
        Target.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnTargetFinished"));
    }

    void Watch_Interactable(FCk_Handle_Interactable InInteractable)
    {
        auto Interactable = InInteractable;
        Interactable.BindTo_OnInteractionFailed(FMars_Delegate_Interactable_OnInteractionFailed(this, n"OnInteractableFailed"));
    }

    int32 Get_FinishedCount(FCk_Handle_InteractTarget InTarget) const
    {
        auto Count = 0;
        for (const auto& Target : _FinishedTargets)
        {
            if (Target == InTarget)
            { ++Count; }
        }

        return Count;
    }

    // The result InTarget's first watched interaction finished with; unset while none has.
    TOptional<ECk_SucceededFailed> TryGet_Result(FCk_Handle_InteractTarget InTarget) const
    {
        const auto Index = _FinishedTargets.FindIndex(InTarget);
        if (Index < 0)
        { return TOptional<ECk_SucceededFailed>(); }

        return TOptional<ECk_SucceededFailed>(_FinishedResults[Index]);
    }

    // The reasons every failure on InTarget was reported with, in order.
    TArray<EMars_Interaction_FailReason> Get_FailReasons(FCk_Handle_InteractTarget InTarget) const
    {
        TArray<EMars_Interaction_FailReason> Reasons;
        for (const auto& Failure : _Failures)
        {
            if (Failure.Target == InTarget)
            { Reasons.Add(Failure.Reason); }
        }

        return Reasons;
    }

    int32 Get_FailureCount() const
    {
        return _Failures.Num();
    }

    UFUNCTION()
    private void OnTargetFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedTargets.Add(InTarget);
        _FinishedResults.Add(InResult);
    }

    UFUNCTION()
    private void OnInteractableFailed(FCk_Handle_Interactable InInteractable, FMars_Interactable_Failure InFailure)
    {
        _Failures.Add(InFailure);
    }
}

// The cooking tests' shared fixtures: the box food piece (a CPU-readable 1000 cm3 cube), a static floor, a World-mode
// platter lying still on one (a platter drops what it is given only while it lies still), and a kinematic box riding a
// node. Rigs on any chain (the FoodPiece, Carrier or Base rigs) make one with NewObject; nothing it builds is tracked for
// cleanup, so a caller tracks what outlives its own subtree (a piece under the world's transient entity).
class UMars_AutoTestHelper_CookingFixture : UObject
{
    TSoftObjectPtr<UStaticMesh> Get_BoxMesh() const
    {
        return TSoftObjectPtr<UStaticMesh>(FSoftObjectPath("/CkTests/CkRuntimeMesh/Cooked/SM_Import_CPU.SM_Import_CPU"));
    }

    // The box as a piece of InKind (none when invalid) weighing InMassKg, with portion minimums no box cut in these tests
    // comes near: Transform, RuntimeMesh and FoodPiece on a new entity under the world's transient entity.
    FCk_Handle_FoodPiece Build_Box(FTransform InWorld, FGameplayTag InKind, float InMassKg) const
    {
        auto Spec = FMars_FoodPiece_Spec();
        Spec.Data.MassKg = InMassKg;
        if (InKind.IsValid())
        { Spec.Data.Kind.AddTag(InKind); }

        Spec.Tuners = FMars_FoodPiece_Tuners(0.0001, 0.05);

        auto Entity = utils_entity_lifetime::Request_CreateEntity(ck::TransientEntity());
        utils_transform::Add(Entity, InWorld, ECk_Replication::DoesNotReplicate);
        utils_runtime_mesh::Add(Entity, FCk_RuntimeMesh_Spec(Get_BoxMesh()));
        return utils_foodpiece::Add(Entity, Spec);
    }

    // A static BlockAll box centred at InCentre, a child of InOwner. Every test floor, wall and stand is one.
    FCk_Handle Spawn_StaticSlab(FCk_Handle InOwner, FVector InCentre, FVector InHalfExtents) const
    {
        auto Owner = InOwner;
        auto Slab = utils_entity_lifetime::Request_CreateEntity(Owner);
        utils_transform::Add(Slab, FTransform(FRotator::ZeroRotator, InCentre), ECk_Replication::DoesNotReplicate);

        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto SlabSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        SlabSpec.Set_ShapeDimensions(Shape);
        SlabSpec.Set_MotionType(ECk_MotionType::Static);
        SlabSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Slab, SlabSpec);
        return Slab;
    }

    // A static floor 2 cm thick under InOwner, InHalfExtent square, its top at InTop.
    FCk_Handle Spawn_Floor(FCk_Handle InOwner, FVector InTop, float64 InHalfExtent) const
    {
        return Spawn_StaticSlab(InOwner, InTop - FVector(0.0, 0.0, 1.0), FVector(InHalfExtent, InHalfExtent, 1.0));
    }

    // InSpec's World-mode platter under InOwner lying on a floor (InFloorHalfExtent square) whose top is InSpec.World's
    // location: its root (the inner floor) sits the tray's base above the top. Returns the platter entity, under
    // construction.
    FCk_Handle Spawn_PlatterOnFloor(FCk_Handle InOwner, FMars_Platter_SpawnSpec InSpec, float64 InFloorHalfExtent) const
    {
        const auto FloorTop = InSpec.World.GetLocation();
        Spawn_Floor(InOwner, FloorTop, InFloorHalfExtent);

        auto Owner = InOwner;
        auto Spec = InSpec;
        Spec.World = FTransform(InSpec.World.Rotator(), FloorTop + FVector(0.0, 0.0, constants_platter::k_FloorAboveBase + 0.5));
        return utils_platter::Request_SpawnWorld(Owner, Spec);
    }

    // A kinematic BlockAll box of InHalfExtents on InNode, riding it.
    FCk_Handle_JoltBody Add_KinematicBox(FCk_Handle_SceneNode InNode, FVector InHalfExtents) const
    {
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);

        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Kinematic);
        BoxSpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BoxSpec.Set_MassKg(1.0f);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        auto Node = InNode;
        return utils_jolt_body::Add(Node.H(), BoxSpec);
    }

    // A kinematic box under a platter's whole floor (InBounds plus a 5 cm margin), its top at InRoot's Z, riding InRoot: the
    // part a platter item's tray body plays.
    FCk_Handle_JoltBody Add_PlatterFloorBox(FCk_Handle_Transform InRoot, FMars_Platter_Bounds InBounds) const
    {
        auto Root = InRoot;
        const auto Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, -1.0)));
        return Add_KinematicBox(Node, FVector(InBounds.InnerHalfExtents.X + 5.0, InBounds.InnerHalfExtents.Y + 5.0, 1.0));
    }
}
