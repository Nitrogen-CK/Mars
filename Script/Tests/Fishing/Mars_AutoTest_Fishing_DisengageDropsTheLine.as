// Disengage with the bait on the water pulls the line in at once (Idle, no line out, no bait position, the reel released)
// and stops the clocks (no bite ever comes), and a Disengage and the next Engage in one drain leave the spot engaged and
// Idle.
class UMars_AutoTest_Fishing_DisengageDropsTheLine : UMars_AutoTestRig_Fishing
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_SpecWithNodes(InHandle);
        Spec.Bite.MinWaitSeconds = 0.3f;
        Spec.Bite.MaxWaitSeconds = 0.3f;
        BuildFishing(InHandle, Spec);

        Add_Step("engage", n"Step_Engage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("cast at full power and hold the reel", n"Step_CastAndHold");
        Add_Step_WaitUntil("the bait is on the water", n"Check_Waiting");
        Add_Step("disengage", n"Step_Disengage");
        Add_Step_WaitUntil("the operator has left", n"Check_Disengaged");
        Add_Step("the line came in", n"Step_AssertLineIn");
        Add_Step_WaitSeconds("longer than the bite wait", 0.6f);
        Add_Step("no bite came with the clocks stopped", n"Step_AssertNoBite");
        Add_Step("disengage and engage in one drain", n"Step_DisengageAndEngage");
        Add_Step_WaitUntil("the spot is engaged", n"Check_Engaged");
        Add_Step("the spot is engaged and Idle", n"Step_AssertEngagedIdle");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_CastAndHold(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
        _Fishing.Request_ReelHold(FMars_Request_Fishing_ReelHold());
    }

    UFUNCTION()
    private void Step_AssertLineIn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, "the spot is Idle");
        Assert_False(_Fishing.Get_HasLineOut(), "no line is out");
        Assert_Equals_Float(_Fishing.Get_LineLengthCm(), 0.0f, 0.0f, "no line length");
        Assert_True(_Fishing.Get_Bait().Position.IsNearlyZero(), "the bait position cleared");
        Assert_True(_Fishing.Get_Reel() == EMars_Fishing_Reel::Released, "the reel was let go");
        Assert_Equals_Int(Count_PhaseSeen(EMars_Fishing_Phase::Idle), 1, "Idle was broadcast once");
    }

    UFUNCTION()
    private void Step_AssertNoBite(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Bites, 0, "no OnBite with the clocks stopped");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, "still Idle");
    }

    UFUNCTION()
    private void Step_DisengageAndEngage(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Fishing.Request_Disengage(FMars_Request_Fishing_Disengage());
        _Fishing.Request_Engage(FMars_Request_Fishing_Engage());
    }

    UFUNCTION()
    private void Step_AssertEngagedIdle(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Fishing.Get_IsEngaged(), "engaged");
        Assert_True(_Fishing.Get_Phase() == EMars_Fishing_Phase::Idle, "Idle");
    }
}
