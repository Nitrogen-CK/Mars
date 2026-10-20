// Two armed hazards share one trigger: the trigger links both and binds its entry signal once, so an occupant entering
// is hit exactly once by each (a second binding would double every hit).
class UMars_AutoTest_Hazard_TwoHazardsOnOneTriggerEachHitOnce : UMars_AutoTestRig_Hazard
{
    private FCk_Handle_Hazard _First;
    private FCk_Handle_Hazard _Second;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTriggerAndOccupant(InHandle, FVector(28000.0, 330000.0, -41000.0));
        _First = AddHazard(InHandle, EMars_Hazard_Arming::Armed);
        _Second = AddHazard(InHandle, EMars_Hazard_Arming::Armed);
        BindSignals(_First);
        BindSignals(_Second);

        Add_Step_WaitUntil("both hazards are set up", n"Check_SetUp", 0, 0);
        Add_Step("the trigger links both", n"Step_AssertLink");
        Add_Step("the occupant steps in", n"Step_In");
        Add_Step_WaitUntil("both hazards hit", n"Check_BothHit", k_SlowPolls, 0);
        Add_Step_WaitSeconds("give a doubled hit time to land", 0.2f);
        Add_Step("each hit exactly once", n"Step_AssertOnceEach");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_SetUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_First.Has_Fragment(FMars_Tag_Hazard_NeedsSetup) == false && _Second.Has_Fragment(FMars_Tag_Hazard_NeedsSetup) == false);
    }

    UFUNCTION()
    private void Step_AssertLink(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto& Link = _Trigger.Get_Fragment(FMars_Fragment_Hazard_TriggerLink);
        Assert_Equals_Int(Link.Hazards.Num(), 2, "the trigger links both hazards");
        Assert_True(Link.IsBound, "the trigger's entry signal is bound");
        Assert_True(_First.Get_IsArmed() && _Second.Get_IsArmed(), "both start armed");
    }

    UFUNCTION()
    private void Step_In(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveIn();
    }

    UFUNCTION()
    private void Check_BothHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_HitCount(_First) >= 1 && Get_HitCount(_Second) >= 1);
    }

    UFUNCTION()
    private void Step_AssertOnceEach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_HitCount(_First), 1, "the first hazard hit once");
        Assert_Equals_Int(Get_HitCount(_Second), 1, "the second hazard hit once");
    }
}
