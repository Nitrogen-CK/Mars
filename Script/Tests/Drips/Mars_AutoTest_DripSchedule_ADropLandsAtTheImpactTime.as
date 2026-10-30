// A drop released at the source starts StartDepth below it (the bead centre, 1.6 x 0.45 cm) and after FallSeconds of
// quadratic-drag fall its leading edge (centre + radius) is exactly the strand length below the source, for a 10 cm
// pipe drip up to a 12 m atrium. Get_AgeAt inverts Get_DistanceAt, the speed rises monotonically toward but never past
// the 750 cm/s terminal speed, and two drops a fixed time apart drift further apart the deeper they are (accelerating
// spacing).
class UMars_AutoTest_DripSchedule_ADropLandsAtTheImpactTime : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("drops land on the impact at FallSeconds", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TArray<float> Lengths;
        Lengths.Add(10.0);
        Lengths.Add(100.0);
        Lengths.Add(350.0);
        Lengths.Add(1050.0);
        Lengths.Add(1200.0);
        for (float Length : Lengths)
        {
            auto Schedule = FMars_DripSchedule();
            Schedule.Length = Length;
            Schedule.Rate = 0.5;
            Schedule.Seed = 0.4;
            Schedule.Jitter = 0.5;
            Schedule.Setup();
            const float Landed = Schedule.StartDepth + utils_drip::Get_DistanceAt(Schedule.FallSeconds) + Schedule.DropRadius;
            Assert_Equals_Float(Landed, Length, 0.05, f"a {Length} cm strand lands its drops on the impact");
        }

        TArray<float> Ages;
        Ages.Add(0.0);
        Ages.Add(0.05);
        Ages.Add(0.4);
        Ages.Add(1.0);
        Ages.Add(2.5);
        Ages.Add(5.0);
        for (float Age : Ages)
        {
            Assert_Equals_Float(utils_drip::Get_AgeAt(utils_drip::Get_DistanceAt(Age)), Age, 1e-4,
                f"AgeAt inverts DistanceAt at {Age} s");
        }

        float LastSpeed = -1.0;
        float LastGap = -1.0;
        bool Monotonic = true;
        bool Accelerating = true;
        for (int32 Step = 0; Step < 60; ++Step)
        {
            const float Age = float(Step) * 0.1;
            const float Speed = utils_drip::Get_SpeedAt(Age);
            if (Speed < LastSpeed || Speed >= utils_drip::k_Terminal)
            { Monotonic = false; }
            LastSpeed = Speed;

            const float Gap = utils_drip::Get_DistanceAt(Age + 0.25) - utils_drip::Get_DistanceAt(Age);
            if (Gap <= LastGap)
            { Accelerating = false; }
            LastGap = Gap;
        }
        Assert_True(Monotonic, "the speed rises monotonically and stays below terminal");
        Assert_True(Accelerating, "drops 0.25 s apart spread out as they fall");
        Assert_True(utils_drip::Get_SpeedAt(6.0) > 0.99 * utils_drip::k_Terminal, "a long fall settles at terminal speed");
    }
}
