// The target is destroyed while the bat telegraphs: the swoop ends TargetLost and the bat returns. Its roost is then
// destroyed while it flies home: OnPerchLost fires and it hovers in the air instead of landing, and stays hovering.
class UMars_AutoTest_Bat_LostTargetAndInvalidPerchHaveOutcomes : UMars_AutoTestRig_Bat
{
    default _TimeoutSeconds = 60.0f;
    default _Origin = FVector(320000.0, -156000.0, 2000.0);

    private int32 _PhasesAtPerchLoss = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_World(InHandle);
        SpawnTarget(InHandle, FVector(600.0, 0.0, 0.0));

        Add_WorldSteps();
        Add_Step_WaitUntil("it telegraphs a swoop", n"Check_Telegraphing", 0, k_FlightSeconds);
        Add_Step("the target is destroyed", n"Step_DestroyTarget");
        Add_Step_WaitUntil("the swoop ends TargetLost and it returns", n"Check_Returning", 0, 5.0f);
        Add_Step("its roost is destroyed", n"Step_DestroyRoost");
        Add_Step_WaitUntil("it reports the lost perch and hovers", n"Check_Hovering", 0, 5.0f);
        Add_Step_WaitUntil("it keeps hovering", n"Check_StillHovering", 0, 6.0f);
        Add_Step("both losses had an outcome and it never landed", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Telegraphing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::IsValid(_Bat) && _Bat.Get_SwoopStage() == EMars_Bat_SwoopStage::Telegraphing);
    }

    UFUNCTION()
    private void Step_DestroyTarget(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        DestroyTarget();
    }

    UFUNCTION()
    private void Check_Returning(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cancels.Contains(EMars_Bat_SwoopCancel::TargetLost) && _Bat.Get_Phase() == EMars_Bat_Phase::Returning);
    }

    UFUNCTION()
    private void Step_DestroyRoost(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhasesAtPerchLoss = _Phases.Num();
        utils_entity_lifetime::Request_DestroyEntity(_Roost);
    }

    UFUNCTION()
    private void Check_Hovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PerchLost >= 1 && _Bat.Get_Phase() == EMars_Bat_Phase::Hovering);
    }

    UFUNCTION()
    private void Check_StillHovering(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Bat.Get_Phase() == EMars_Bat_Phase::Hovering && _Bat.Get_PhaseClock() >= 3.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Cancels.Num(), 1, "one swoop was cancelled");
        Assert_True(_Cancels.Num() > 0 && _Cancels[0] == EMars_Bat_SwoopCancel::TargetLost, "its reason is TargetLost");
        Assert_Equals_Int(_PerchLost, 1, "OnPerchLost fired once");
        Assert_True(_Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Lost, "its claim reads Lost");
        Assert_False(_Bat.Get_HasPerch(), "it has no perch");

        auto Landed = false;
        for (int32 Index = _PhasesAtPerchLoss; Index < _Phases.Num(); ++Index)
        {
            const auto Phase = _Phases[Index];
            if (Phase == EMars_Bat_Phase::Braking || Phase == EMars_Bat_Phase::Perching || Phase == EMars_Bat_Phase::Roosting)
            { Landed = true; }
        }

        Assert_False(Landed, f"it never braked, perched or roosted after the perch went (saw {Get_PhaseTrail()})");
        Assert_True(_Bat.Get_Location().Z - _Origin.Z > 100.0, "it is in the air");
        Assert_Equals_Int(_TargetDamaged, 0, "nothing was dealt");
    }
}
