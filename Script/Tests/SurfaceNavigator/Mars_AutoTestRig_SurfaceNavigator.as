// The navigator rig: a plain SurfaceMotion body (no legs, so it rides its rays) 65 uu above a runtime static Jolt floor
// (3000 x 3000 uu, top face at _Origin.Z), steered by a SurfaceNavigator. The handlers record every navigator signal.
// Each test sets _Origin to an isolated spot: the Mars autotest map has no floor of its own there.
UCLASS(Abstract)
class UMars_AutoTestRig_SurfaceNavigator : UCk_AutoTest_Base
{
    protected FVector _Origin;
    protected FCk_Handle_SurfaceMotion _Motion;
    protected FCk_Handle_SurfaceNavigator _Nav;

    protected int32 _ArrivedCount = 0;
    protected FVector _ArrivedGoal;
    protected int32 _FailedCount = 0;
    protected FVector _FailedGoal;
    // The latest OnFailed's reason; unset until it fires.
    protected TOptional<EMars_SurfaceNavigator_FailReason> _FailedReason;

    protected FCk_SurfaceMotion_Spec Make_MotionSpec() const
    {
        auto Contact = FCk_SurfaceMotion_Contact();
        Contact.Set_Clearance(65.0f);
        Contact.Set_ProbeReach(180.0f);
        Contact.Set_HeightSource(ECk_SurfaceMotion_HeightSource::Rays);
        Contact.Set_WallPolicy(ECk_SurfaceMotion_WallPolicy::Slide);
        Contact.Set_MaxStepHeight(85.0f);

        auto Movement = FCk_SurfaceMotion_Movement();
        Movement.Set_MaxSpeed(180.0f);
        Movement.Set_SurfaceTurnRate(180.0f);

        auto Spec = FCk_SurfaceMotion_Spec();
        Spec.Set_Contact(Contact);
        Spec.Set_Movement(Movement);
        return Spec;
    }

    protected FCk_Handle_JoltBody SpawnStaticBox(FCk_Handle InHandle, FVector InCentre, FVector InHalfExtents)
    {
        auto Entity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, InCentre), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        return utils_jolt_body::Add(Entity, BoxSpec);
    }

    protected FCk_Handle_JoltBody SpawnFloor(FCk_Handle InHandle)
    {
        return SpawnStaticBox(InHandle, _Origin - FVector(0.0, 0.0, 10.0), FVector(1500.0, 1500.0, 10.0));
    }

    protected void SpawnBody(FCk_Handle InHandle)
    {
        auto BodyEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Body = utils_transform::Add(BodyEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 0.0, 65.0)), ECk_Replication::DoesNotReplicate);
        _Motion = utils_surface_motion::Add(Body, Make_MotionSpec());
        _Nav = utils_surface_navigator::Add(_Motion, FMars_SurfaceNavigator_Spec());
    }

    protected void SpawnFloorAndBody(FCk_Handle InHandle)
    {
        SpawnFloor(InHandle);
        SpawnBody(InHandle);
    }

    protected void BindNavigatorSignals()
    {
        _Nav.BindTo_OnArrived(FMars_Delegate_SurfaceNavigator_OnArrived(this, n"OnArrived"));
        _Nav.BindTo_OnFailed(FMars_Delegate_SurfaceNavigator_OnFailed(this, n"OnFailed"));
    }

    protected FVector Get_BodyLocation() const
    {
        return utils_transform::Get_EntityCurrentLocation(_Motion.As_Transform());
    }

    UFUNCTION()
    protected void OnArrived(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal)
    {
        ++_ArrivedCount;
        _ArrivedGoal = InGoal;
    }

    UFUNCTION()
    protected void OnFailed(FCk_Handle_SurfaceNavigator InNavigator, FVector InGoal, EMars_SurfaceNavigator_FailReason InReason)
    {
        ++_FailedCount;
        _FailedGoal = InGoal;
        _FailedReason = TOptional<EMars_SurfaceNavigator_FailReason>(InReason);
    }

    UFUNCTION()
    protected void Check_MotionReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Motion) && utils_surface_motion::Get_Status(_Motion) == ECk_ProceduralAnimation_Status::Ready);
    }
}
