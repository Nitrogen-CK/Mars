// SetArmed is absolute: Armed, Disarmed, Armed queued in one frame leave the hazard armed with one OnArmedChanged(Armed);
// an Armed request on an armed hazard broadcasts nothing (proven by the Disarmed that follows it broadcasting exactly once).
class UMars_AutoTest_Hazard_LatestArmRequestWinsAndOnlyAChangeBroadcasts : UMars_AutoTestRig_Hazard
{
    private FCk_Handle_Hazard _Hazard;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTriggerAndOccupant(InHandle, FVector(20000.0, 330000.0, -41000.0));
        _Hazard = AddHazard(InHandle, EMars_Hazard_Arming::Disarmed);
        BindSignals(_Hazard);

        Add_Step("the hazard composed disarmed", n"Step_AssertComposed");
        Add_Step("queue Armed, Disarmed, Armed in one frame", n"Step_QueueThree");
        Add_Step_WaitUntil("the hazard is armed", n"Check_Armed", 0, 0);
        Add_Step("one Armed edge", n"Step_AssertOneEdge");
        Add_Step("queue Armed on the armed hazard", n"Step_ArmAgain");
        Add_Step_WaitUntil("the repeated Armed is drained", n"Check_Drained", 0, 0);
        Add_Step("queue Disarmed", n"Step_Disarm");
        Add_Step_WaitUntil("the hazard is disarmed", n"Check_Disarmed", 0, 0);
        Add_Step("the repeated Armed broadcast nothing; the Disarmed once", n"Step_AssertTwoEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Hazard, "utils_hazard::Add accepted a spec with a trigger");
        Assert_False(_Hazard.Get_IsArmed(), "StartArmed false starts disarmed");
        Assert_True(_Hazard.Get_Trigger() == _Trigger, "the hazard keeps its spec's trigger");
    }

    UFUNCTION()
    private void Step_QueueThree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Armed));
        _Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Disarmed));
        _Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Armed));
    }

    UFUNCTION()
    private void Check_Armed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hazard.Get_IsArmed() && _Hazard.Has_Fragment(FMars_Fragment_Hazard_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertOneEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ArmingChanges.Num(), 1, "three requests in one drain broadcast once");
        Assert_True(_ArmingChanges.Num() == 1 && _ArmingChanges[0] == EMars_Hazard_Arming::Armed, "the edge is Armed");
    }

    UFUNCTION()
    private void Step_ArmAgain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Armed));
    }

    UFUNCTION()
    private void Check_Drained(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hazard.Has_Fragment(FMars_Fragment_Hazard_Requests) == false);
    }

    UFUNCTION()
    private void Step_Disarm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Disarmed));
    }

    UFUNCTION()
    private void Check_Disarmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hazard.Get_IsArmed() == false && _Hazard.Has_Fragment(FMars_Fragment_Hazard_Requests) == false);
    }

    UFUNCTION()
    private void Step_AssertTwoEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ArmingChanges.Num(), 2, "Armed on an armed hazard is silent; the Disarmed broadcasts once");
        Assert_True(_ArmingChanges.Num() == 2 && _ArmingChanges[1] == EMars_Hazard_Arming::Disarmed, "the second edge is Disarmed");
        Assert_Equals_Int(_HitEntities.Num(), 0, "nothing was inside, so nothing was hit");
    }
}
