// Leaving Locomotion while climbing (Downed, or Operating a station) leaves the ladder: UMars_SmState_Locomotion's exit
// issues Request_Dismount(Lost), which ends the climb with LastDismount == Lost and OnClimbingChanged(NotClimbing). A state
// machine on the test entity starts in the real state's exit hook and is transitioned out of it mid-climb.

// UMars_SmState_Locomotion's DoExitState without its tasks and transitions: those need the full player (an
// AMars_PlayerCharacter for the Loco sub-SM's speed tasks, its viewpoint and resolver for the free-roam tasks).
class UMars_AutoTestState_BareLocomotion : UMars_SmState_Locomotion
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
    }
}

// Where the machine goes when it leaves Locomotion.
class UMars_AutoTestState_LeftLocomotion : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
    }
}

class UMars_AutoTest_Climber_LocomotionExitDismounts : UCk_AutoTest_Base
{
    private FCk_Handle_Ladder _Ladder;
    private FCk_Handle_Climber _Climber;
    private FCk_Handle_StateMachine _Machine;
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
        _Machine = utils_state_machine::Add(LocalHandle, FCk_StateMachine_Spec(UMars_AutoTestState_BareLocomotion));

        Add_Step_WaitUntil("the machine is in Locomotion", n"Check_InLocomotion", 0, 2.0f);
        Add_Step("mount from the front", n"Step_MountFront");
        Add_Step_WaitUntil("the climber is climbing", n"Check_Climbing", 0, 2.0f);
        Add_Step_WaitUntil("climbing up reaches 0.3", n"Check_AboveFoot", 0, 3.0f);
        Add_Step("leave Locomotion while climbing", n"Step_LeaveLocomotion");
        Add_Step_WaitUntil("the machine left Locomotion and the climber is off the ladder", n"Check_LeftAndDismounted", 0, 2.0f);
        Add_Step("the climb ended Lost, mid-ladder", n"Step_AssertLost");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnClimbingChanged(FCk_Handle_Climber InClimber, EMars_Climber_ClimbState InClimbState)
    {
        _ClimbingChanges.Add(InClimbState == EMars_Climber_ClimbState::Climbing);
    }

    UFUNCTION()
    private void Check_InLocomotion(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::IsInState(_Machine, UMars_AutoTestState_BareLocomotion));
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

    UFUNCTION()
    private void Step_LeaveLocomotion(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Climber.Get_IsClimbing(), "climbing before the exit");
        utils_state_machine::Request_Transition(_Machine, UMars_AutoTestState_LeftLocomotion);
    }

    UFUNCTION()
    private void Check_LeftAndDismounted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_state_machine::IsInState(_Machine, UMars_AutoTestState_LeftLocomotion) && _Climber.Get_IsClimbing() == false);
    }

    UFUNCTION()
    private void Step_AssertLost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastDismount = _Climber.Get_LastDismount();
        Assert_True(LastDismount.IsSet(), "the climb recorded how it ended");
        if (LastDismount.IsSet())
        {
            const auto Reason = LastDismount.GetValue();
            Assert_True(Reason == EMars_Climber_Dismount::Lost, f"the climb ended Lost (dismount {Reason :n})");
        }

        Assert_Equals_Int(_ClimbingChanges.Num(), 2, "OnClimbingChanged fired twice: on, then off");
        if (_ClimbingChanges.Num() == 2)
        {
            Assert_True(_ClimbingChanges[0], "the first change is the mount");
            Assert_False(_ClimbingChanges[1], "the second change is the dismount");
        }
    }
}
