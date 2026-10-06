// The implement rig: an Implement on a transform-only root at an isolated origin, its node 100 uu up. No physics: the
// tests pin the tilt and lift model and the node write. The handlers record both signals.
UCLASS(Abstract)
class UMars_AutoTestRig_Implement : UCk_AutoTest_Base
{
    protected const FVector k_Origin = FVector(-60000.0, 18000.0, -60000.0);

    protected FCk_Handle_Implement _Implement;
    // The spec the implement was built from, nodes included.
    protected FMars_Implement_Spec _Spec;
    protected FCk_Handle_SceneNode _Node;

    protected TArray<EMars_Implement_Drive> _Drives;
    protected TArray<float32> _KickExcess;
    // The target pitch as the kick fired: the tilt has taken the look's slow part that frame, never the excess.
    protected TArray<float32> _KickTargetPitch;

    protected void BuildImplement(FCk_Handle InHandle, FMars_Implement_Spec InSpec)
    {
        _Spec = InSpec;

        auto RootEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(RootEntity, FTransform(FRotator::ZeroRotator, k_Origin), ECk_Replication::DoesNotReplicate);
        _Node = utils_scene_node::Create(Root, FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 100.0)));

        _Spec.Nodes = FMars_Implement_Nodes(_Node);
        _Implement = utils_implement::Add(RootEntity, _Spec);

        _Implement.BindTo_OnDriveChanged(FMars_Delegate_Implement_OnDriveChanged(this, n"OnDriveChanged"));
        _Implement.BindTo_OnLiftKicked(FMars_Delegate_Implement_OnLiftKicked(this, n"OnLiftKicked"));
    }

    protected void Drive()
    {
        _Implement.Request_SetDrive(FMars_Request_Implement_SetDrive(EMars_Implement_Drive::Driven));
    }

    protected void Look(FVector InLookDelta)
    {
        _Implement.Request_Look(FMars_Request_Implement_Look(InLookDelta));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void OnDriveChanged(FCk_Handle_Implement InImplement, EMars_Implement_Drive InDrive)
    {
        _Drives.Add(InDrive);
    }

    UFUNCTION()
    protected void OnLiftKicked(FCk_Handle_Implement InImplement, float32 InExcessDegrees)
    {
        _KickExcess.Add(InExcessDegrees);
        _KickTargetPitch.Add(InImplement.Get_TargetTilt().Pitch);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Check_Driven(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Implement.Get_IsDriven());
    }
}
