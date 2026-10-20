// An occupancy needing two is not active with one inside, goes active (one OnActiveChanged) and sends its mover to End
// when the second enters, and with no release delay goes inactive (mover back to Start) as soon as one leaves.
class UMars_AutoTest_Occupancy_RequiredCountActivatesAndMovesTheMover : UMars_AutoTestRig_Occupancy
{
    private FCk_Handle_Occupancy _Occupancy;
    private FCk_Handle_Mover _Mover;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTrigger(InHandle, FVector(0.0, 330000.0, -41000.0));
        AddOccupants(InHandle, 2);

        auto MoverEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto MoverRoot = utils_transform::Add(MoverEntity, FTransform(FRotator::ZeroRotator, _Origin + FVector(0.0, 500.0, 0.0)), ECk_Replication::DoesNotReplicate);
        auto MoverNode = utils_scene_node::Create(MoverRoot, FTransform::Identity);
        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = FVector(0.0, 0.0, -10.0);
        MoverSpec.Duration = 0.1f;
        _Mover = utils_mover::Add(MoverNode, MoverSpec);

        auto Spec = Make_Spec(2, 0.0f);
        Spec.Parts = FMars_Occupancy_Parts(_Trigger, _Mover);
        _Occupancy = AddOccupancy(InHandle, Spec);
        BindActiveChanges(_Occupancy);

        Add_Step("the occupancy composed", n"Step_AssertComposed");
        Add_Step("the first occupant enters", n"Step_FirstIn");
        Add_Step_WaitUntil("the trigger counts one", n"Check_CountOne", k_SlowPolls, 0);
        Add_Step("one of two is not enough", n"Step_AssertInactive");
        Add_Step("the second occupant enters", n"Step_SecondIn");
        Add_Step_WaitUntil("active with the mover at End", n"Check_ActiveAtEnd", k_SlowPolls, 0);
        Add_Step("one activation edge", n"Step_AssertOneEdge");
        Add_Step("the first occupant leaves", n"Step_FirstOut");
        Add_Step_WaitUntil("inactive with the mover back at Start", n"Check_InactiveAtStart", k_SlowPolls, 0);
        Add_Step("two edges: Active then Inactive", n"Step_AssertTwoEdges");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Occupancy, "utils_occupancy::Add accepted a spec with a trigger and a mover");
        Assert_Equals_Int(_Occupancy.Get_RequiredCount(), 2, "the spec's RequiredCount is kept");
    }

    UFUNCTION()
    private void Step_FirstIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveIn(0);
    }

    UFUNCTION()
    private void Check_CountOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 1);
    }

    UFUNCTION()
    private void Step_AssertInactive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Occupancy.Get_IsActive(), "one occupant of the two required leaves it inactive");
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::Start, "the mover stays at Start");
        Assert_Equals_Int(_ActiveChanges.Num(), 0, "no activation edge yet");
    }

    UFUNCTION()
    private void Step_SecondIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveIn(1);
    }

    UFUNCTION()
    private void Check_ActiveAtEnd(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 2 && _Occupancy.Get_IsActive()
            && _Mover.Get_Target() == EMars_Mover_Pose::End && _Mover.Get_IsResting());
    }

    UFUNCTION()
    private void Step_AssertOneEdge(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ActiveChanges.Num(), 1, "reaching RequiredCount broadcasts OnActiveChanged once");
        Assert_True(_ActiveChanges.Num() == 1 && _ActiveChanges[0] == EMars_Occupancy_Activation::Active, "the edge is Active");
    }

    UFUNCTION()
    private void Step_FirstOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveOut(0);
    }

    UFUNCTION()
    private void Check_InactiveAtStart(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Occupancy.Get_Count() == 1 && _Occupancy.Get_IsActive() == false
            && _Mover.Get_Target() == EMars_Mover_Pose::Start && _Mover.Get_IsResting());
    }

    UFUNCTION()
    private void Step_AssertTwoEdges(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_ActiveChanges.Num(), 2, "dropping below RequiredCount with no delay broadcasts once more");
        Assert_True(_ActiveChanges.Num() == 2 && _ActiveChanges[1] == EMars_Occupancy_Activation::Inactive, "the second edge is Inactive");
    }
}
