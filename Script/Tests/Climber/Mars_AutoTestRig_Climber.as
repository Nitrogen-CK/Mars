// The climber rig: a ladder on a transform-only root and a climber (ClimbSpeed 300) on the test entity itself.
UCLASS(Abstract)
class UMars_AutoTestRig_Climber : UCk_AutoTest_Base
{
    protected FCk_Handle_Ladder _Ladder;
    protected FCk_Handle_Climber _Climber;
    // One entry per OnClimbingChanged: whether the climber is now climbing.
    protected TArray<bool> _ClimbingChanges;

    protected void BuildLadderAndClimber(FCk_Handle InHandle, FMars_Ladder_Spec InLadderSpec)
    {
        auto LadderEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(LadderEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Ladder = utils_ladder::Add(Root, InLadderSpec);

        auto LocalHandle = InHandle;
        _Climber = utils_climber::Add(LocalHandle, FMars_Climber_Spec(300.0f));
    }

    // InHow completes "the climb ended ...".
    protected void AssertDismount(EMars_Climber_Dismount InExpected, const FString& InHow)
    {
        const auto LastDismount = _Climber.Get_LastDismount();
        Assert_True(LastDismount.IsSet(), "the climb recorded how it ended");
        if (LastDismount.IsSet())
        {
            const auto Reason = LastDismount.GetValue();
            Assert_True(Reason == InExpected, f"the climb ended {InHow} (dismount {Reason :n})");
        }
    }

    UFUNCTION()
    protected void OnClimbingChanged(FCk_Handle_Climber InClimber, EMars_Climber_ClimbState InClimbState)
    {
        _ClimbingChanges.Add(InClimbState == EMars_Climber_ClimbState::Climbing);
    }

    UFUNCTION()
    protected void Check_Climbing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_IsClimbing());
    }

    UFUNCTION()
    protected void Check_AboveFoot(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Res.Set(_Climber.Get_Alpha() >= 0.3f);
    }

    // Keeps climbing up until the climb ends.
    UFUNCTION()
    protected void Check_ToppedOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (_Climber.Get_IsClimbing() == false)
        {
            Res.Set(true);
            return;
        }

        _Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Res.Set(false);
    }
}
