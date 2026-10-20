// A spike trap's phases drive its parts: Warn raises the part with the hazard still disarmed, Active keeps it raised and
// arms the hazard, and the next Safe lowers it and disarms; the cycle loops Safe, Warn, Active, Safe.
class UMars_AutoTest_Trap_PhasesDriveTheMoverAndTheHazard : UMars_AutoTestRig_Trap
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddTrap(InHandle, FVector(36000.0, 330000.0, -41000.0), EMars_PoweredBehavior::SuppressWhilePowered);

        Add_Step("the trap composed its cycle around the parts", n"Step_AssertComposed");
        Add_Step_WaitUntil("Warn raised the part", n"Check_WarnRaised", k_SlowPolls, 0);
        Add_Step("Warn leaves the hazard disarmed", n"Step_AssertWarn");
        Add_Step_WaitUntil("Active armed the hazard", n"Check_ActiveArmed", k_SlowPolls, 0);
        Add_Step("the part stays raised while Active", n"Step_AssertActive");
        Add_Step_WaitUntil("the next Safe lowered the part and disarmed", n"Check_SafeReset", k_SlowPolls, 0);
        Add_Step("the phases ran in order and looped", n"Step_AssertOrder");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertComposed(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Valid(_Trap, "utils_trap::Add accepted the spike spec with its parts");
        Assert_True(_Trap.Get_Hazard() == _Hazard, "the trap keeps its hazard");
        Assert_True(_Trap.Get_Mover() == _Mover, "the trap keeps its mover");
        Assert_Valid(_Cycle, "the trap composed a cycle on its entity");
    }

    UFUNCTION()
    private void Check_WarnRaised(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Warn && _Mover.Get_Target() == EMars_Mover_Pose::End);
    }

    UFUNCTION()
    private void Step_AssertWarn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Hazard.Get_IsArmed(), "Warn does not arm the hazard");
    }

    UFUNCTION()
    private void Check_ActiveArmed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Active && _Hazard.Get_IsArmed());
    }

    UFUNCTION()
    private void Step_AssertActive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Mover.Get_Target() == EMars_Mover_Pose::End, "the part stays raised while Active");
    }

    UFUNCTION()
    private void Check_SafeReset(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Phases.Num() >= 4 && _Cycle.Get_CurrentPhase() == GameplayTags::Mechanism_Phase_Safe
            && _Hazard.Get_IsArmed() == false && _Mover.Get_Target() == EMars_Mover_Pose::Start);
    }

    UFUNCTION()
    private void Step_AssertOrder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Phases.Num() >= 4, f"four phase entries seen ({_Phases.Num()})");
        if (_Phases.Num() < 4)
        { return; }

        Assert_True(_Phases[0] == GameplayTags::Mechanism_Phase_Safe, "the cycle starts in Safe");
        Assert_True(_Phases[1] == GameplayTags::Mechanism_Phase_Warn, "then Warn");
        Assert_True(_Phases[2] == GameplayTags::Mechanism_Phase_Active, "then Active");
        Assert_True(_Phases[3] == GameplayTags::Mechanism_Phase_Safe, "then loops to Safe");
    }
}
