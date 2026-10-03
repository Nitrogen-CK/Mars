// A gate with a threshold does not close on someone: told to close while a Probe.Mars.Player stands in its doorway it stays
// open with the close deferred; an open request meanwhile cancels the wait; told to close again, it closes as soon as the
// occupant leaves. The gate and the occupant (a kinematic Silent Probe.Mars.Player sphere in its own context, like the
// player's body probe) are built in the test, so no placeable or driver is involved. Isolated Z band: -76000.
class UMars_AutoTest_Gate_ThresholdDefersCloseUntilClear : UCk_AutoTest_Base
{
    private FVector _Origin = FVector(0.0, 0.0, -76000.0);
    private FCk_Handle_Gate _Gate;
    private FCk_Handle_Transform _Occupant;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto GateEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto GateRoot = utils_transform::Add(GateEntity, FTransform(FRotator::ZeroRotator, _Origin), ECk_Replication::DoesNotReplicate);

        auto Threshold = FMars_Trigger_Spec();
        Threshold.Shape = EMars_Trigger_Shape::Box;
        Threshold.BoxHalfExtents = FVector(80.0, 100.0, 110.0);
        Threshold.LocalOffset = FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, 110.0));
        Threshold.DetectionFilter.AddTag(GameplayTags::Probe_Mars_Player);

        auto GateSpec = FMars_Gate_Spec();
        GateSpec.StartOpen = true;
        GateSpec.Threshold = Threshold;
        _Gate = utils_gate::Add(GateRoot, GateSpec);

        _Occupant = MakeOccupant(InHandle, _Origin + FVector(0.0, 0.0, 110.0));

        Add_Step("the gate made its threshold", n"Step_AssertThreshold");
        Add_Step_WaitUntil("the occupant stands in the threshold", n"Check_Occupied", 0, 5.0f);
        Add_Step("tell the gate to close", n"Step_Close");
        Add_Step_WaitUntil("the close is deferred", n"Check_Deferred", 0, 5.0f);
        Add_Step_WaitSeconds("give a wrongful close time to land", 0.2f);
        Add_Step("still open, still waiting", n"Step_AssertStillOpen");
        Add_Step("tell the gate to open", n"Step_Open");
        Add_Step_WaitUntil("the open cancels the waiting close", n"Check_OpenNotDeferred", 0, 5.0f);
        Add_Step("tell the gate to close again", n"Step_Close");
        Add_Step_WaitUntil("the close is deferred again", n"Check_Deferred", 0, 5.0f);
        Add_Step("the occupant leaves", n"Step_Leave");
        Add_Step_WaitUntil("the gate closes once the threshold clears", n"Check_Closed", 0, 5.0f);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertThreshold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Gate), "utils_gate::Add returned a gate");
        Assert_True(ck::IsValid(_Gate.Get_Threshold()), "a spec with a Threshold gives the gate a threshold trigger");
        Assert_True(_Gate.Get_IsOpen(), "StartOpen opens the gate");
    }

    UFUNCTION()
    private void Check_Occupied(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gate.Get_IsThresholdOccupied());
    }

    UFUNCTION()
    private void Step_Close(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Gate.Request_SetOpen(false);
    }

    UFUNCTION()
    private void Check_Deferred(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gate.Get_IsCloseDeferred());
    }

    UFUNCTION()
    private void Step_AssertStillOpen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Gate.Get_IsOpen(), "a close does not go through while the threshold is occupied");
        Assert_True(_Gate.Get_IsCloseDeferred(), "the close waits");
    }

    UFUNCTION()
    private void Step_Open(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Gate.Request_SetOpen(true);
    }

    UFUNCTION()
    private void Check_OpenNotDeferred(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gate.Get_IsOpen() && _Gate.Get_IsCloseDeferred() == false);
    }

    UFUNCTION()
    private void Step_Leave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_transform::Request_SetLocation(_Occupant, FCk_Request_Transform_SetLocation(_Origin + FVector(1000.0, 0.0, 110.0)));
    }

    UFUNCTION()
    private void Check_Closed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Gate.Get_IsOpen() == false && _Gate.Get_IsCloseDeferred() == false && _Gate.Get_IsThresholdOccupied() == false);
    }

    // Its own owner and context, so the gate's threshold may overlap it.
    private FCk_Handle_Transform MakeOccupant(FCk_Handle InHandle, FVector InLocation)
    {
        auto Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        Owner.Request_OverrideToSelf();
        auto Root = utils_transform::Add(Owner, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);

        auto ProbeSpec = FCk_Probe_Spec(GameplayTags::Probe_Mars_Player);
        ProbeSpec.Set_MotionType(ECk_MotionType::Kinematic)
                 .Set_ResponsePolicy(ECk_ProbeResponse_Policy::Silent);
        utils_prefab::Create_ProbeNode_Sphere(Root, 30.0f, ProbeSpec);
        return Root;
    }
}
