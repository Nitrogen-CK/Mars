// The attack tick's clocks advance only on positive time: a zero (or negative) delta leaves a countdown (entry reuse, the
// global recovery) and a countup (the readiness wait, the claimed limbs' cleanup) exactly where they were, a positive
// delta moves them by that delta, and a countdown never passes 0. Pure: the tick's own clock functions, nothing spawned.
class UMars_AutoTest_CrawlerMelee_ZeroDeltaClocksHold : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("zero and negative deltas hold every attack clock; positive ones move it", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Float(utils_crawler::Get_CountdownAfter(0.7f, 0.0f), 0.7f, 1.0e-6f, "a zero delta holds a countdown");
        Assert_Equals_Float(utils_crawler::Get_CountdownAfter(0.7f, -0.25f), 0.7f, 1.0e-6f, "a negative delta holds a countdown");
        Assert_Equals_Float(utils_crawler::Get_CountdownAfter(0.7f, 0.25f), 0.45f, 1.0e-6f, "a positive delta counts down by the delta");
        Assert_Equals_Float(utils_crawler::Get_CountdownAfter(0.1f, 0.25f), 0.0f, 1.0e-6f, "a countdown stops at 0");

        Assert_Equals_Float(utils_crawler::Get_CountupAfter(1.5f, 0.0f), 1.5f, 1.0e-6f, "a zero delta holds a countup");
        Assert_Equals_Float(utils_crawler::Get_CountupAfter(1.5f, -0.25f), 1.5f, 1.0e-6f, "a negative delta holds a countup");
        Assert_Equals_Float(utils_crawler::Get_CountupAfter(1.5f, 0.25f), 1.75f, 1.0e-6f, "a positive delta counts up by the delta");
    }
}
