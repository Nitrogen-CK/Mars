// A spec with Camera.ViewLocal gives the station a View child node that rides the station frame: the placeable station's
// entity script builds it and the Station hands it out (Get_View). A test station (UMars_TESTONLY_Station) placed at a
// turned, raised root gets the node settled at ViewLocal composed onto the root, so the operator's framing is the
// station's whatever the operator's eye height. A spec without ViewLocal leaves View invalid (the operator keeps its own
// eye).
class UMars_AutoTest_Station_ViewLocalMakesAViewNode : UMars_AutoTestRig_Station
{
    private FCk_Handle_Station _Viewed;
    private FCk_Handle_Station _Unviewed;
    private FVector _ExpectedViewLocation;
    private FRotator _ExpectedViewRotation;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto RootWorld = FTransform(FRotator(0.0, 90.0, 0.0), FVector(100.0, -200.0, 30.0));
        const auto ViewLocal = FTransform(FRotator(-48.0, 0.0, 0.0), FVector(-78.0, 0.0, 152.0));
        _ExpectedViewLocation = RootWorld.TransformPosition(ViewLocal.GetLocation());
        // The root turns 90 about Z only, so it adds 90 to the view's yaw and keeps its pitch.
        _ExpectedViewRotation = FRotator(-48.0, 90.0, 0.0);

        auto Spec = FMars_Station_Spec();
        Spec.Camera.ViewLocal = TOptional<FTransform>(ViewLocal);
        auto ViewedPending = Spawn_TestStation(InHandle, UMars_TESTONLY_Station_EntityScript, FMars_TESTONLY_StationSpawnParams(RootWorld, Spec));
        utils_pending_entity_script::Promise_OnConstructed(ViewedPending, FCk_Delegate_EntityScript_Constructed(this, n"OnViewedConstructed"));

        auto UnviewedPending = Spawn_TestStation(InHandle, UMars_TESTONLY_Station_EntityScript, FMars_TESTONLY_StationSpawnParams(FTransform::Identity, FMars_Station_Spec()));
        utils_pending_entity_script::Promise_OnConstructed(UnviewedPending, FCk_Delegate_EntityScript_Constructed(this, n"OnUnviewedConstructed"));

        Add_Step_WaitUntil("both test stations are composed", n"Check_Composed", 0, 0);
        Add_Step("ViewLocal makes a View node; no ViewLocal leaves it invalid", n"Step_AssertViewNodes");
        Add_Step_WaitUntil("the View node settles at ViewLocal in the station frame", n"Check_ViewSettled", 0, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnViewedConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        Track_ForCleanup(InEntityScriptHandle);
        _Viewed = InEntityScriptHandle.As_Station(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void OnUnviewedConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        Track_ForCleanup(InEntityScriptHandle);
        _Unviewed = InEntityScriptHandle.As_Station(ECk_SanityCheck::UnChecked);
    }

    UFUNCTION()
    private void Check_Composed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Viewed) && ck::IsValid(_Unviewed));
    }

    UFUNCTION()
    private void Step_AssertViewNodes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Viewed.Get_View(), "ViewLocal makes a View node");
        Assert_Invalid(_Unviewed.Get_View(), "no ViewLocal leaves View invalid");

        FCk_Handle ViewEntity = _Viewed.Get_View();
        auto ViewNode = ViewEntity.As_SceneNode(ECk_SanityCheck::UnChecked);
        FCk_Handle ViewedEntity = _Viewed;
        Assert_True(ck::IsValid(ViewNode) && utils_scene_node::Get_Parent(ViewNode) == ViewedEntity.As_Transform(),
            "the View node is a scene node directly under the station root");
    }

    UFUNCTION()
    private void Check_ViewSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Viewed.Get_View()))
        {
            Res.Set(false);
            return;
        }

        const auto ViewWorld = utils_transform::Get_EntityCurrentTransform(_Viewed.Get_View());
        Res.Set(ViewWorld.GetLocation().Equals(_ExpectedViewLocation, 0.01) &&
            ViewWorld.Rotator().Equals(_ExpectedViewRotation, 0.01));
    }
}
