// A disarmed hazard does not hit an occupant standing in its trigger; arming it hits that occupant once (the setup
// processor's reaction to OnArmedChanged), and an occupant entering an armed hazard is hit on entry.
class UMars_AutoTest_Hazard_ArmingHitsWhatIsAlreadyInside : UMars_AutoTestRig_Hazard
{
    private FCk_Handle_Hazard _Hazard;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTriggerAndOccupant(InHandle, FVector(24000.0, 330000.0, -41000.0));
        _Hazard = AddHazard(InHandle, EMars_Hazard_Arming::Disarmed);
        BindSignals(_Hazard);

        Add_Step("the occupant steps in", n"Step_In");
        Add_Step_WaitUntil("the trigger holds the occupant", n"Check_OccupantInside", k_SlowPolls, 0);
        Add_Step("disarmed: nothing hit", n"Step_AssertNoHit");
        Add_Step("arm the hazard", n"Step_Arm");
        Add_Step_WaitUntil("arming hits the occupant", n"Check_OneHit", 0, 0);
        Add_Step("one hit, on the occupant's probe", n"Step_AssertHitOccupant");
        Add_Step("the occupant steps out", n"Step_Out");
        Add_Step_WaitUntil("the trigger is empty", n"Check_Empty", k_SlowPolls, 0);
        Add_Step("the occupant steps back in", n"Step_In");
        Add_Step_WaitUntil("entering an armed hazard hits", n"Check_TwoHits", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_In(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveIn();
    }

    UFUNCTION()
    private void Step_Out(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        MoveOut();
    }

    UFUNCTION()
    private void Step_AssertNoHit(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hazard.Get_IsArmed(), "the hazard is disarmed");
        Assert_Equals_Int(_HitEntities.Num(), 0, "a disarmed hazard hits nothing on entry");
    }

    UFUNCTION()
    private void Step_Arm(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hazard.Request_SetArmed(FMars_Request_Hazard_SetArmed(EMars_Hazard_Arming::Armed));
    }

    UFUNCTION()
    private void Check_OneHit(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HitEntities.Num() >= 1);
    }

    UFUNCTION()
    private void Step_AssertHitOccupant(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_HitEntities.Num(), 1, "arming hits the one occupant once");
        const auto Inside = _Trigger.Get_EntitiesInside();
        Assert_True(_HitEntities.Num() == 1 && Inside.Num() == 1 && _HitEntities[0] == Inside[0], "the hit entity is the one inside the trigger");
        Assert_True(_HitHazards.Num() == 1 && _HitHazards[0] == _Hazard, "the hit names the hazard");
    }

    UFUNCTION()
    private void Check_Empty(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Trigger.Get_EntityCount() == 0);
    }

    UFUNCTION()
    private void Check_TwoHits(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_HitEntities.Num() == 2 && _Trigger.Get_EntityCount() == 1);
    }
}
