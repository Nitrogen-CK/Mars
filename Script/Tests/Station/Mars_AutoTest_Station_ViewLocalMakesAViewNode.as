// A spec with Camera.ViewLocal gives the station a View child node that rides the station frame: on a station placed at
// a turned, raised root the node settles at ViewLocal composed onto the root, so the operator's framing is the station's
// whatever the operator's eye height. A spec without ViewLocal leaves View invalid (the operator keeps its own eye).
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
        auto StationEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(StationEntity, RootWorld, ECk_Replication::DoesNotReplicate);
        _Viewed = utils_station::Add(Root, Spec, FMars_Station_Setup());

        _Unviewed = AddStation(InHandle, FMars_Station_Spec());

        Add_Step("ViewLocal makes a View node; no ViewLocal leaves it invalid", n"Step_AssertViewNodes");
        Add_Step_WaitUntil("the View node settles at ViewLocal in the station frame", n"Check_ViewSettled", 0, 2.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertViewNodes(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Viewed, "the station with ViewLocal is added");
        Assert_Valid(_Unviewed, "the station without ViewLocal is added");
        if (ck::Is_NOT_Valid(_Viewed) || ck::Is_NOT_Valid(_Unviewed))
        { return; }

        Assert_Valid(_Viewed.Get_View(), "ViewLocal makes a View node");
        Assert_Invalid(_Unviewed.Get_View(), "no ViewLocal leaves View invalid");
    }

    UFUNCTION()
    private void Check_ViewSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (ck::Is_NOT_Valid(_Viewed) || ck::Is_NOT_Valid(_Viewed.Get_View()))
        { Res.Set(false); return; }

        const auto ViewWorld = utils_transform::Get_EntityCurrentTransform(_Viewed.Get_View());
        Res.Set(ViewWorld.GetLocation().Equals(_ExpectedViewLocation, 0.01) &&
            ViewWorld.Rotator().Equals(_ExpectedViewRotation, 0.01));
    }
}
