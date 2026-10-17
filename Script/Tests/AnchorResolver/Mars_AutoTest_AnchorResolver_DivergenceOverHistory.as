// Planning check (docs/plans/anchor-slice/PHASE_1.md): the same algorithm over 200 Python-RNG chains never averaged
// under 0.77, so a mean under 0.5 here means the solve deviates from the spec, not bad luck.
class UMars_AutoTest_AnchorResolver_DivergenceOverHistory : UMars_AutoTestRig_AnchorResolverPure
{
    default _TimeoutSeconds = 15.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("twenty chained runs never repeat the entrance or the quarry and diverge by at least 0.5", n"Step_Chain");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Chain(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Plan = utils_anchor_resolver::Plan_Warrens();
        auto History = TArray<FMars_AnchorRun_Record>();
        auto Previous = FMars_AnchorRun_Result();
        auto Sum = 0.0f;
        for (int32 Run = 0; Run < 20; ++Run)
        {
            auto Input = FMars_AnchorRun_Input();
            Input.Seed = 101 + Run;
            Input.History = History;
            const auto Result = utils_anchor_resolver::Solve(Plan, Input);

            Assert_False(Result.UsedFallback, f"run {Run + 1} (seed {Input.Seed}) needs no fallback");
            if (Run > 0)
            {
                Assert_True(Result.Entrance != Previous.Entrance, f"run {Run + 1} does not repeat entrance {Previous.Entrance.ToString()}");
                Assert_True(Result.Quarry != Previous.Quarry, f"run {Run + 1} does not repeat quarry {Previous.Quarry.ToString()}");
                Sum += Result.Divergence;
            }

            History.Insert(Result.To_Record(), 0);
            if (History.Num() > 3)
            { History.RemoveAt(3); }
            Previous = Result;
        }

        const auto Mean = Sum / 19.0f;
        Assert_True(Mean >= 0.5f, f"mean divergence over runs 2..20 is {Mean :.3} (needs 0.5)");
    }
}
