// Phases far shorter than a frame (a zero-length Grasp among them): one tick crosses Reach -> Grasp -> Carry ->
// AwaitAdmission, each boundary once and in order, with exactly one release; after the answer one tick crosses Return ->
// Idle once.
class UMars_AutoTest_CookingFeed_ALongFrameCrossesEachBoundaryOnce : UMars_AutoTestRig_CookingFeed
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = Make_TestSpec();
        Spec.Timing = FMars_CookingFeed_TimingSpec(0.001f, 0.0f, 0.001f, 0.001f);
        BuildFeed(InHandle, Spec);

        Add_Step("press add food", n"Step_Begin");
        Add_Step_WaitUntil("the hand awaits admission", n"Check_AwaitingAdmission", 4, 1.0f);
        Add_Step_WaitFrames("nothing more happens while awaiting", 2);
        Add_Step("each boundary once, in one tick, one release; accept", n"Step_AssertBoundariesAndAccept");
        Add_Step_WaitUntil("the hand is back at rest", n"Check_Idle", 4, 1.0f);
        Add_Step_WaitFrames("nothing more happens at rest", 2);
        Add_Step("Return and Idle once each", n"Step_AssertReturn");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertBoundariesAndAccept(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Phases.Num(), 4, "four phase changes");
        if (_Phases.Num() == 4)
        {
            Assert_True(_Phases[0] == EMars_CookingFeed_Phase::Reach, f"first Reach (got {_Phases[0] :n})");
            Assert_True(_Phases[1] == EMars_CookingFeed_Phase::Grasp, f"then Grasp (got {_Phases[1] :n})");
            Assert_True(_Phases[2] == EMars_CookingFeed_Phase::Carry, f"then Carry (got {_Phases[2] :n})");
            Assert_True(_Phases[3] == EMars_CookingFeed_Phase::AwaitAdmission, f"then AwaitAdmission (got {_Phases[3] :n})");
            Assert_Equals_Float(_PhaseTimes[3], _PhaseTimes[1], 0.0001, "Grasp, Carry and AwaitAdmission came in one tick");
            Assert_Equals_Float(_PhaseTimes[2], _PhaseTimes[1], 0.0001, "Grasp and Carry came in the same tick");
        }

        Assert_Equals_Int(_Releases.Num(), 1, "exactly one release");
        Assert_Ledger(k_Stock - 1, 0, "awaiting admission");
        Step_AcceptPending(InHandle, InPayload);
    }

    UFUNCTION()
    private void Step_AssertReturn(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Phases.Num(), 6, "two more phase changes");
        if (_Phases.Num() == 6)
        {
            Assert_True(_Phases[4] == EMars_CookingFeed_Phase::Return, f"Return (got {_Phases[4] :n})");
            Assert_True(_Phases[5] == EMars_CookingFeed_Phase::Idle, f"then Idle (got {_Phases[5] :n})");
        }

        Assert_Equals_Int(_Releases.Num(), 1, "still one release");
        Assert_Ledger(k_Stock - 1, 1, "at rest");
    }
}
