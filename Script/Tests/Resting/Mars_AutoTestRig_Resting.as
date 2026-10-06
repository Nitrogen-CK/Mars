// The resting rig, at an isolated origin: a kinematic plate (a thin box) on its own child node under a plate node 100 uu
// above a transform-only root, and a dynamic box dropped 2 uu onto it with a Resting on the plate body. Moving the plate
// node moves the plate (the kinematic push), which is how a test hops the box. The handlers record both signals.
UCLASS(Abstract)
class UMars_AutoTestRig_Resting : UCk_AutoTest_Base
{
    protected const FVector k_Origin = FVector(-60000.0, 20000.0, -60000.0);
    protected const float32 k_PlateRestZ = 100.0f;
    protected const float32 k_PlateHalfHeight = 2.0f;
    protected const float32 k_BoxHalfSize = 10.0f;

    protected FCk_Handle_SceneNode _PlateNode;
    protected FCk_Handle_JoltBody _PlateBody;
    protected FCk_Handle _Box;
    protected FCk_Handle_JoltBody _BoxBody;
    protected FCk_Handle_Resting _Resting;

    protected TArray<EMars_Resting_State> _States;
    protected TArray<float32> _Landings;

    protected void BuildRig(FCk_Handle InHandle)
    {
        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _PlateNode = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, k_PlateRestZ)));

        auto PlateTransform = _PlateNode.As_Transform();
        auto PlateBodyNode = utils_scene_node::Create(PlateTransform, FTransform::Identity);
        auto PlateShape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        PlateShape.Set_HalfExtents(FVector(60.0, 60.0, k_PlateHalfHeight));
        auto PlateSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        PlateSpec.Set_ShapeDimensions(PlateShape);
        PlateSpec.Set_MotionType(ECk_MotionType::Kinematic);
        PlateSpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        PlateSpec.Set_Friction(0.6f);
        PlateSpec.Set_CollisionProfileName(n"BlockAll");
        _PlateBody = utils_jolt_body::Add(PlateBodyNode.H(), PlateSpec);

        _Box = utils_entity_lifetime::Request_CreateEntity(InHandle);
        const auto BoxStart = k_Origin + FVector(0.0, 0.0, k_PlateRestZ + k_PlateHalfHeight + k_BoxHalfSize + 2.0);
        utils_transform::Add(_Box, FTransform(FRotator::ZeroRotator, BoxStart), ECk_Replication::DoesNotReplicate);

        auto BoxShape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        BoxShape.Set_HalfExtents(FVector(k_BoxHalfSize, k_BoxHalfSize, k_BoxHalfSize));
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(BoxShape);
        BoxSpec.Set_MotionType(ECk_MotionType::Dynamic);
        BoxSpec.Set_MassSource(ECk_JoltBody_MassSource::Explicit);
        BoxSpec.Set_MassKg(0.4f);
        BoxSpec.Set_SurfaceSource(ECk_JoltBody_SurfaceSource::Explicit);
        BoxSpec.Set_Friction(0.6f);
        // The Resting needs a Persisted contact every step from a resting awake box.
        BoxSpec.Set_PersistContacts(ECk_EnableDisable::Enable);
        _BoxBody = utils_jolt_body::Add(_Box, BoxSpec);

        _Resting = utils_resting::Add(_Box, FMars_Resting_Spec(_PlateBody));
        _Resting.BindTo_OnRestingChanged(FMars_Delegate_Resting_OnRestingChanged(this, n"OnRestingChanged"));
        _Resting.BindTo_OnLanded(FMars_Delegate_Resting_OnLanded(this, n"OnLanded"));
    }

    // The plate node's height above its rest (uu).
    protected void Set_PlateRaise(float32 InRaise)
    {
        utils_scene_node::Request_UpdateOffset_Location(_PlateNode, FVector(0.0, 0.0, k_PlateRestZ + InRaise), ECk_RelativeAbsolute::Absolute);
    }

    protected float32 Get_Now()
    {
        return float32(System::GetGameTimeInSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnRestingChanged(FCk_Handle_Resting InResting, EMars_Resting_State InState)
    {
        _States.Add(InState);
    }

    UFUNCTION()
    protected void OnLanded(FCk_Handle_Resting InResting, float32 InApartSeconds)
    {
        _Landings.Add(InApartSeconds);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_Resting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Resting.Get_IsResting());
    }
}
