// The model half of "leaving Locomotion dismounts": UMars_SmState_Locomotion's exit (Downed, or Operating a station)
// issues Request_Dismount(Lost) when the climber is climbing, and that request ends the climb with LastDismount == Lost and
// OnClimbingChanged(false). The exit hook itself is NOT exercised here: a Locomotion SM rig needs an AMars_PlayerCharacter
// (its Loco sub-SM's speed tasks ensure on one) and the player's viewpoint for the free-roam tasks; it is covered by review.
class UMars_AutoTest_Climber_LocomotionExitDismounts : UCk_AutoTest_Base
{
    private FCk_Handle_Ladder _Ladder;
    private FCk_Handle_Climber _Climber;
    private TArray<bool> _ClimbingChanges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LadderEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(LadderEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Ladder = utils_ladder::Add(Root, FMars_Ladder_Spec());

        auto LocalHandle = InHandle;
        _Climber = utils_climber::Add(LocalHandle, FMars_Climber_Spec(300.0f));
        _Climber.BindTo_OnClimbingChanged(FMars_Delegate_Climber_OnClimbingChanged(this, n"OnClimbingChanged"));

        Add_Step("mount from the front", n"Step_MountFront");
        Add_Step_WaitUntil("the climber is climbing", n"Check_Climbing", 0, 2.0f);
        Add_Step_WaitUntil("climbing up reaches 0.3", n"Check_AboveFoot", 0, 3.0f);
        Add_Step("the state the climber is in leaves: dismount Lost", n"Step_DismountLost");
        Add_Step_WaitUntil("the climber is off the ladder", n"Check_NotClimbing", 0, 2.0f);
        Add_Step("the climb ended Lost, mid-ladder", n"Step_AssertLost");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnClimbingChanged(FCk_Handle_Climber InClimber, bool InClimbing)
    {
        _ClimbingChanges.Add(InClimbing);
    }

    UFUNCTION()
    private void Step_MountFront(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Ladder), "the ladder composed");
        Assert_True(ck::IsValid(_Climber), "the climber composed");
        _Climber.Request_Mount(FMars_Request_Climber_Mount(_Ladder, EMars_Ladder_Zone::Front));
    }

    UFUNCTION()
    private void Check_Climbing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_IsClimbing());
    }

    UFUNCTION()
    private void Check_AboveFoot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Res.Set(_Climber.Get_Alpha() >= 0.3f);
    }

    // What UMars_SmState_Locomotion::DoExitState issues.
    UFUNCTION()
    private void Step_DismountLost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Climber.Get_IsClimbing(), "climbing before the exit");
        _Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Lost));
    }

    UFUNCTION()
    private void Check_NotClimbing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_IsClimbing() == false);
    }

    UFUNCTION()
    private void Step_AssertLost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastDismount = _Climber.Get_LastDismount();
        Assert_True(LastDismount == EMars_Climber_Dismount::Lost, f"the climb ended Lost (dismount {LastDismount :n})");

        Assert_Equals_Int(_ClimbingChanges.Num(), 2, "OnClimbingChanged fired twice: on, then off");
        if (_ClimbingChanges.Num() == 2)
        {
            Assert_True(_ClimbingChanges[0], "the first change is the mount");
            Assert_False(_ClimbingChanges[1], "the second change is the dismount");
        }
    }
}
