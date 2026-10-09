// The gait emitter's count diff: one footstep per footfall increment and one landing per landing increment since the last
// look, nothing when the counters stand still, and nothing when a counter is behind the last look (a replaced gait).
class UMars_AutoTest_SurfaceFx_GaitEmitsOncePerIncrement : UCk_AutoTest_Base
{
    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_Step("diff a sequence of gait counters", n"Step_Diff");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Diff(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Seen = Make_Counts(0, 0);
        Seen = Assert_Emits(Seen, Make_Counts(0, 0), Make_Emits(0, 0));
        Seen = Assert_Emits(Seen, Make_Counts(1, 0), Make_Emits(1, 0));
        Seen = Assert_Emits(Seen, Make_Counts(1, 0), Make_Emits(0, 0));
        Seen = Assert_Emits(Seen, Make_Counts(3, 0), Make_Emits(2, 0));
        Seen = Assert_Emits(Seen, Make_Counts(3, 1), Make_Emits(0, 1));
        Seen = Assert_Emits(Seen, Make_Counts(4, 2), Make_Emits(1, 1));
        Seen = Assert_Emits(Seen, Make_Counts(0, 0), Make_Emits(0, 0));
        Assert_Emits(Seen, Make_Counts(1, 0), Make_Emits(1, 0));
    }

    private FMars_SurfaceFx_GaitCounts Make_Counts(int32 InFootfalls, int32 InLandings) const
    {
        auto Counts = FMars_SurfaceFx_GaitCounts();
        Counts.Footfalls = InFootfalls;
        Counts.Landings = InLandings;
        return Counts;
    }

    private FMars_SurfaceFx_GaitEmits Make_Emits(int32 InFootsteps, int32 InLands) const
    {
        auto Emits = FMars_SurfaceFx_GaitEmits();
        Emits.Footsteps = InFootsteps;
        Emits.Lands = InLands;
        return Emits;
    }

    // Returns InNow, the emitter's next seen.
    private FMars_SurfaceFx_GaitCounts Assert_Emits(const FMars_SurfaceFx_GaitCounts& InSeen, const FMars_SurfaceFx_GaitCounts& InNow,
        const FMars_SurfaceFx_GaitEmits& InExpected)
    {
        const auto Emits = utils_surface_fx::Get_GaitEmits(InSeen, InNow);
        const auto What = f"footfalls {InSeen.Footfalls} -> {InNow.Footfalls}, landings {InSeen.Landings} -> {InNow.Landings}";
        Assert_Equals_Int(Emits.Footsteps, InExpected.Footsteps, f"{What}: footsteps");
        Assert_Equals_Int(Emits.Lands, InExpected.Lands, f"{What}: landings");
        return InNow;
    }
}
