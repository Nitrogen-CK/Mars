// Exercises the same Camera layer and holder requests as CampUiPresenter against a real headless director.
// It does not claim presenter/WBP/input integration coverage. The independent helper entity is explicitly cleanup-tracked.
class UMars_AutoTest_CampServiceView_TargetBlendsAndCampMenuHoldsUntilRelease : UCk_AutoTest_Base
{
    private ACkAutoTest_GameplayCamera_Helper _Helper;
    private FCk_Handle_Transform _CameraOwner;
    private FCk_Handle_Transform _Target;
    private FCk_Handle_Camera _Camera;
    private FCk_Handle_PlayerViewpoint _Viewpoint;
    private FVector _TargetLocation = FVector(1000.0, 0.0, 300.0);
    private bool _SawBlendIn = false;
    private bool _SawBlendOut = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Helper = Cast<ACkAutoTest_GameplayCamera_Helper>(SpawnActor(
            ACkAutoTest_GameplayCamera_Helper, FVector::ZeroVector, FRotator::ZeroRotator));
        if (ck::Is_NOT_Valid(_Helper))
        { FinishFailure("camera helper did not spawn"); return; }
        utils_pending_entity_script::Promise_OnConstructed(_Helper.PendingEntity,
            FCk_Delegate_EntityScript_Constructed(this, n"OnHelperReady"));

        Add_Step_WaitUntil("helper has composed", n"Check_HelperReady", 0, 0);
        Add_Step("compose director and player viewpoint", n"Step_Compose");
        Add_Step_WaitUntil("baseline view has settled", n"Check_BaseView", 0, 0);
        Add_Step("CampMenu holds and requests the production service layer", n"Step_Open");
        Add_Step_WaitUntil("target and FOV blend to service view", n"Check_ServiceView", 0, 0);
        Add_Step("hold survives another owner's release", n"Step_ReleaseOtherHolder");
        Add_Step_WaitUntil("other holder released", n"Check_HoldDrain", 0, 0);
        Add_Step_WaitSeconds("remain open beyond the complete blend", 0.2f);
        Add_Step("service view retained until close", n"Step_AssertRetainedAndClose");
        Add_Step_WaitUntil("layer blends away and view returns", n"Check_Returned", 0, 0);
        Add_Step("release restored orientation and removed layer", n"Step_AssertRestored");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnHelperReady(FCk_Handle_EntityScript InScript)
    {
        Track_ForCleanup(InScript);
        _CameraOwner = InScript.As_Transform();
    }

    UFUNCTION()
    private void Check_HelperReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_CameraOwner));
    }

    UFUNCTION()
    private void Step_Compose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto ViewSpec = FMars_PlayerViewpoint_Spec();
        auto CameraSpec = FCk_Camera_Spec(_Helper.CameraComponent);
        CameraSpec.Set_Profile(utils_player_viewpoint::Make_CameraProfile(ViewSpec));
        _Camera = utils_camera::Add(_CameraOwner, CameraSpec);
        if (ck::Is_NOT_Valid(_Camera))
        { FinishFailure("headless director did not compose"); return; }
        ViewSpec.Camera = _Camera;
        auto Player = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Viewpoint = utils_player_viewpoint::Add(Player, ViewSpec);
        auto Target = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _Target = utils_transform::Add(Target, FTransform(FRotator(0.0, 35.0, 0.0), _TargetLocation), ECk_Replication::DoesNotReplicate);
    }

    UFUNCTION()
    private void Check_BaseView(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        const auto View = _Camera.Get_ViewInfo();
        Result.Set(ck::IsValid(_Viewpoint) && View.Location.Equals(FVector::ZeroVector, 0.1)
            && Math::Abs(View.FOV - 90.0f) < 0.1f && _Camera.Get_Profile().Get_HasOrientationControl());
    }

    UFUNCTION()
    private void Step_Open(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Camera.Has_Layer(UMars_CameraLayer_CampService), "no service layer initially");
        _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::CampMenu));
        _Viewpoint.Request_HoldView(FMars_Request_PlayerViewpoint_HoldView(EMars_PlayerViewpoint_ViewHolder::Station));
        auto Request = FCk_Request_Camera_AddLayer(UMars_CameraLayer_CampService);
        Request.Set_StackingBehavior(ECk_Camera_StackingBehavior::OneOnly);
        Request.Set_Priority(10);
        Request.Set_BlendInTime(FCk_Time(0.65));
        Request.Set_CameraTarget(FCk_Camera_Target(_Target, ECk_Camera_TargetMode::ViewTarget));
        _Camera.Request_AddLayer(Request);
    }

    UFUNCTION()
    private void Check_ServiceView(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto View = _Camera.Get_ViewInfo();
        if (View.Location.X > 1.0 && View.Location.X < _TargetLocation.X - 1.0)
        { _SawBlendIn = true; }
        auto Result = OutResult;
        Result.Set(_Camera.Has_Layer(UMars_CameraLayer_CampService) && View.Location.Equals(_TargetLocation, 0.1)
            && Math::Abs(View.Rotation.Yaw - 35.0) < 0.1
            && Math::Abs(View.FOV - mars::Mars_StewardService_Config.View.FieldOfView) < 0.1f);
    }

    UFUNCTION()
    private void Step_ReleaseOtherHolder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawBlendIn, "observed an intermediate target pose, not a cut");
        _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::Station));
    }

    UFUNCTION()
    private void Check_HoldDrain(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Viewpoint.Has_Fragment(FMars_Fragment_PlayerViewpoint_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertRetainedAndClose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Viewpoint.Get_IsViewHeld(), "CampMenu still owns its hold after Station releases");
        Assert_False(_Camera.Get_Profile().Get_HasOrientationControl(), "CampMenu keeps look orientation frozen");
        Assert_True(_Camera.Get_ViewInfo().Location.Equals(_TargetLocation, 0.1), "target remains the composed view until close");
        Assert_Equals_Int(_Camera.Get_LayerCount(), 1, "one service layer remains");
        auto Request = FCk_Request_Camera_RemoveLayer(UMars_CameraLayer_CampService);
        Request.Set_BlendOutTime(FCk_Time(0.35));
        _Camera.Request_RemoveLayer(Request);
        _Viewpoint.Request_ReleaseView(FMars_Request_PlayerViewpoint_ReleaseView(EMars_PlayerViewpoint_ViewHolder::CampMenu));
    }

    UFUNCTION()
    private void Check_Returned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto View = _Camera.Get_ViewInfo();
        if (View.Location.X > 1.0 && View.Location.X < _TargetLocation.X - 1.0)
        { _SawBlendOut = true; }
        auto Result = OutResult;
        Result.Set(_Camera.Has_Layer(UMars_CameraLayer_CampService) == false && View.Location.Equals(FVector::ZeroVector, 0.1)
            && Math::Abs(View.FOV - 90.0f) < 0.1f && _Camera.Get_Profile().Get_HasOrientationControl());
    }

    UFUNCTION()
    private void Step_AssertRestored(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_SawBlendOut, "observed an intermediate return pose");
        Assert_False(_Viewpoint.Get_IsViewHeld(), "CampMenu release frees the view");
        Assert_False(_Camera.Has_Layer(UMars_CameraLayer_CampService), "service layer removed after blend-out");
        Assert_Equals_Int(_Camera.Get_LayerCount(), 0, "no layer leaked");
    }
}
