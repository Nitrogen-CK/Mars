// Every strand draws its falling drops on 4 cards, drop k on card k mod 4, so drop k + 4 must not release before drop
// k has fallen and splashed (Busy = FallSeconds + 0.28 s): the clock lengthens the period when a fast rate on a long
// fall would break that (the slot cap), never shortening it. The period divides the 3600 s Time wrap into a multiple
// of 4 drops and the hash index wraps with it, so drop -1 is drop N - 1 one wrap earlier (no pop at T = 3600 -> 0).
// Get_SlotDrop picks, for any time, the newest drop of that slot already released. Strands are rolled from a fixed
// stream (40 of them, 0.05..10 /s, 10 cm..30 m).
class UMars_AutoTest_DripSchedule_SlotsNeverOverlapAndWrapSeamlessly : UCk_AutoTest_Base
{
    default _AutoStageOriginField = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("slots never overlap and the wrap is seamless", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Stream = FRandomStream(1234);
        int32 Overlaps = 0;
        int32 BadCounts = 0;
        int32 BadWraps = 0;
        int32 FastRates = 0;
        int32 BadSlotPicks = 0;
        const int32 Slots = utils_drip::k_Slots;
        for (int32 Strand = 0; Strand < 40; ++Strand)
        {
            auto Schedule = FMars_DripSchedule();
            Schedule.Length = Math::Exp(Stream.RandRange(Math::Loge(10.0), Math::Loge(3000.0)));
            Schedule.Rate = Math::Exp(Stream.RandRange(Math::Loge(0.05), Math::Loge(10.0)));
            Schedule.Seed = Stream.RandRange(0.0, 0.999);
            Schedule.Jitter = Stream.RandRange(0.0, 1.0);
            Schedule.Setup();

            for (int32 K = -8; K < 200; ++K)
            {
                if (Schedule.Get_Release(K + Slots) < Schedule.Get_Release(K) + Schedule.Get_BusySeconds() - 1e-9)
                { Overlaps += 1; }
            }

            if (Schedule.Count % Slots != 0 || Math::Abs(float(Schedule.Count) * Schedule.Period - 3600.0) > 1e-6)
            { BadCounts += 1; }

            if (Math::Abs((Schedule.Get_Release(Schedule.Count - 1) - 3600.0) - Schedule.Get_Release(-1)) > 1e-3)
            { BadWraps += 1; }

            if (Schedule.Get_EffectiveRate() > Schedule.Rate * (1.0 + 1e-9))
            { FastRates += 1; }

            for (int32 Probe = 0; Probe < 20; ++Probe)
            {
                const float Time = Stream.RandRange(0.0, 3599.0);
                const int32 Slot = Probe % Slots;
                const int32 K = Schedule.Get_SlotDrop(Time, Slot);
                const bool OnSlot = ((K % Slots) + Slots) % Slots == Slot;
                const bool Newest = Schedule.Get_Release(K) <= Time && Schedule.Get_Release(K + Slots) > Time;
                if (!OnSlot || !Newest)
                { BadSlotPicks += 1; }
            }
        }

        Assert_Equals_Int(Overlaps, 0, "drop k + 4 never releases before drop k has fallen and splashed");
        Assert_Equals_Int(BadCounts, 0, "the period divides the wrap into a multiple of 4 drops");
        Assert_Equals_Int(BadWraps, 0, "drop -1 is drop N - 1 one wrap earlier");
        Assert_Equals_Int(FastRates, 0, "the slot cap only ever lowers the rate");
        Assert_Equals_Int(BadSlotPicks, 0, "Get_SlotDrop picks the newest released drop of the slot");
    }
}
