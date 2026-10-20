// Every refuel, then the latest shutter request: a refuel and an open in one frame light the lantern. A refuel adds its
// measures capped at full; one that relights a spent lantern starts the new measure from the beginning.
class UMars_Processor_Lantern_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Lantern_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Lantern);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Lantern_Requests& InRequests,
                       FMars_Fragment_Lantern& InState)
    {
        auto Self = InHandle.As_Lantern();

        auto Added = 0;
        for (const auto& Refuel : InRequests.RefuelRequests)
        {
            if (ck::EnsureIfNot(Refuel.Measures > 0, f"[Lantern] [{Self.ToString()}] got a refuel of [{Refuel.Measures}] measures"))
            { continue; }

            Added += Refuel.Measures;
        }

        const auto HasShutter = InRequests.SetShutterRequests.Num() > 0;
        auto Shutter = InState.Shutter;
        if (HasShutter)
        { Shutter = InRequests.SetShutterRequests.Last().Shutter; }

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Lantern_Requests);

        if (Added == 0 && HasShutter == false)
        { return; }

        const auto Before = utils_lantern::Make_Reading(InState);
        const auto& Params = Self.Get_Fragment(FMars_Fragment_Lantern_Params);

        if (Added > 0)
        {
            if (InState.MeasuresLeft <= 0)
            { InState.MeasureElapsed = 0.0f; }

            InState.MeasuresLeft = Math::Min(InState.MeasuresLeft + Added, Params.Measures);
        }

        InState.Shutter = Shutter;
        InState.Flame = utils_lantern::Get_Flame(Params, InState);

        utils_lantern::Apply_Changes(Self, Before, utils_lantern::Make_Reading(InState));
    }
}
