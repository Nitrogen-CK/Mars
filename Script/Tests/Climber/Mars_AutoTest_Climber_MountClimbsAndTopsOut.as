// A Front mount starts at the foot (no character: Alpha seeds 0), climbing up moves Alpha at the climber's ClimbSpeed /
// the ladder's Height, and holding up past the top ends the climb with a Top dismount. OnClimbingChanged reports true, then
// false. Also: the climber spec accepts the default speed and rejects a zero one.
class UMars_AutoTest_Climber_MountClimbsAndTopsOut : UCk_AutoTest_Base
{
    private FCk_Handle_Ladder _Ladder;
    private FCk_Handle_Climber _Climber;
    private TArray<bool> _ClimbingChanges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto LadderEntity = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Root = utils_transform::Add(LadderEntity, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        auto Spec = FMars_Ladder_Spec();
        Spec.Height = 300.0f;
        _Ladder = utils_ladder::Add(Root, Spec);

        auto LocalHandle = InHandle;
        _Climber = utils_climber::Add(LocalHandle, FMars_Climber_Spec(300.0f));
        _Climber.BindTo_OnClimbingChanged(FMars_Delegate_Climber_OnClimbingChanged(this, n"OnClimbingChanged"));

        Add_Step("the climber spec rejects a zero climb speed", n"Step_ValidateSpec");
        Add_Step("mount from the front", n"Step_Mount");
        Add_Step_WaitUntil("the climber is climbing", n"Check_Climbing", 0, 2.0f);
        Add_Step("a front mount without a character starts at the foot", n"Step_AssertAtFoot");
        Add_Step_WaitUntil("climbing up reaches half way", n"Check_HalfWay", 0, 3.0f);
        Add_Step("still climbing at half way", n"Step_AssertStillClimbing");
        Add_Step_WaitUntil("climbing up past the top ends the climb", n"Check_ToppedOut", 0, 5.0f);
        Add_Step("the climb ended at the top and was signalled", n"Step_AssertToppedOut");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnClimbingChanged(FCk_Handle_Climber InClimber, bool InClimbing)
    {
        _ClimbingChanges.Add(InClimbing);
    }

    UFUNCTION()
    private void Step_ValidateSpec(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Default = FMars_Climber_Spec().Validate();
        Assert_True(Default.IsValid, f"the default climber spec is accepted (error: {Default.Get_Error()})");

        const auto Stuck = FMars_Climber_Spec(0.0f).Validate();
        Assert_False(Stuck.IsValid, "ClimbSpeed 0 is rejected");
        Assert_True(Stuck.Get_Error().Len() > 0, f"ClimbSpeed 0 names its rule (error: {Stuck.Get_Error()})");
        Assert_True(Math::Abs(_Climber.Get_ClimbSpeed() - 300.0f) < 0.001f, f"the climber keeps its spec's speed ({_Climber.Get_ClimbSpeed()})");
    }

    UFUNCTION()
    private void Step_Mount(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(ck::IsValid(_Ladder), "the ladder composed");
        _Climber.Request_Mount(FMars_Request_Climber_Mount(_Ladder, EMars_Ladder_Zone::Front));
    }

    UFUNCTION()
    private void Check_Climbing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Climber.Get_IsClimbing());
    }

    UFUNCTION()
    private void Step_AssertAtFoot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Alpha = _Climber.Get_Alpha();
        Assert_True(Math::Abs(Alpha) < 0.001f, f"Alpha starts at the foot (alpha {Alpha})");
        Assert_True(_Climber.Get_Ladder() == _Ladder, "the climber is on the mounted ladder");
    }

    UFUNCTION()
    private void Check_HalfWay(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        _Climber.Request_Climb(FMars_Request_Climber_Climb(1.0f));
        Res.Set(_Climber.Get_Alpha() >= 0.5f);
    }

    UFUNCTION()
    private void Step_AssertStillClimbing(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Climber.Get_IsClimbing(), f"still climbing at alpha {_Climber.Get_Alpha()}");
    }

    UFUNCTION()
    private void Check_ToppedOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
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

    UFUNCTION()
    private void Step_AssertToppedOut(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto LastDismount = _Climber.Get_LastDismount();
        Assert_True(LastDismount == EMars_Climber_Dismount::Top, f"the climb ended at the top (dismount {LastDismount :n})");
        Assert_False(ck::IsValid(_Climber.Get_Ladder()), "no ladder after the dismount");
        Assert_True(_ClimbingChanges.Num() == 2, f"OnClimbingChanged fired twice (fired {_ClimbingChanges.Num()})");
        if (_ClimbingChanges.Num() == 2)
        {
            Assert_True(_ClimbingChanges[0], "first OnClimbingChanged is true");
            Assert_False(_ClimbingChanges[1], "second OnClimbingChanged is false");
        }
    }
}
