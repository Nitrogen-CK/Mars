// The drip clock (Mars_DripSchedule mirrors Shaders/Water/MarsDrip.ush) releases drops in order however hard it is
// jittered: a release moves at most 0.45 P either way, so consecutive releases stay at least 0.1 P apart at Jitter 1.
// The mean interval is the period (350 cm at 0.8 /s: P = 1.25 s, under the slot cap), Jitter 0.6 makes the spacing
// irregular (coefficient of variation 0.22 in the reference), Jitter 0 is a metronome, and 0.25 x Jitter of the drops
// are skipped (0.142 over the first 4000 at Jitter 0.6 in drip_reference.py).
class UMars_AutoTest_DripSchedule_ReleasesStayOrderedAndAverageTheRate : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("releases stay ordered and average the period", n"Step_Assert");
        Run_Steps(InHandle);
    }

    private FMars_DripSchedule Make_Schedule(float InJitter)
    {
        auto Schedule = FMars_DripSchedule();
        Schedule.Length = 350.0;
        Schedule.Rate = 0.8;
        Schedule.Seed = 0.3;
        Schedule.Jitter = InJitter;
        Schedule.Setup();
        return Schedule;
    }

    // Coefficient of variation of the first InCount release intervals.
    private float Get_IntervalSpread(const FMars_DripSchedule& InSchedule, int32 InCount)
    {
        float Sum = 0.0;
        float SumSq = 0.0;
        for (int32 K = 0; K < InCount; ++K)
        {
            const float Gap = InSchedule.Get_Release(K + 1) - InSchedule.Get_Release(K);
            Sum += Gap;
            SumSq += Gap * Gap;
        }
        const float Mean = Sum / float(InCount);
        const float Variance = Math::Max(SumSq / float(InCount) - Mean * Mean, 0.0);
        return Math::Sqrt(Variance) / Mean;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Wild = Make_Schedule(1.0);
        Assert_Equals_Float(Wild.Period, 1.25, 1e-6, "350 cm at 0.8 /s keeps the nominal period (under the slot cap)");

        int32 OutOfOrder = 0;
        for (int32 K = 0; K < 500; ++K)
        {
            if (Wild.Get_Release(K + 1) <= Wild.Get_Release(K))
            { OutOfOrder += 1; }
        }
        Assert_Equals_Int(OutOfOrder, 0, "500 releases strictly increase at Jitter 1");

        const float Mean = (Wild.Get_Release(500) - Wild.Get_Release(0)) / 500.0;
        Assert_Equals_Float(Mean, Wild.Period, Wild.Period * 0.02, "the mean interval is the period");

        const auto Irregular = Make_Schedule(0.6);
        const float Spread = Get_IntervalSpread(Irregular, 500);
        Assert_True(Spread > 0.1, f"Jitter 0.6 spaces drops irregularly (cv {Spread})");

        const auto Metronome = Make_Schedule(0.0);
        Assert_True(Get_IntervalSpread(Metronome, 500) < 1e-6, "Jitter 0 is a metronome");

        int32 Skips = 0;
        int32 MetronomeSkips = 0;
        for (int32 K = 0; K < 4000; ++K)
        {
            if (Irregular.Is_Skipped(K))
            { Skips += 1; }

            if (Metronome.Is_Skipped(K))
            { MetronomeSkips += 1; }
        }
        Assert_Equals_Float(float(Skips) / 4000.0, 0.25 * 0.6, 0.02, "0.25 x Jitter of the drops are skipped");
        Assert_Equals_Int(MetronomeSkips, 0, "Jitter 0 skips nothing");
    }
}
