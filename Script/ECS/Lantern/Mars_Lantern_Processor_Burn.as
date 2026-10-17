// Burns an open lantern's tallow: one measure every SecondsPerMeasure, the flame guttering through the last GutterSeconds
// of the last; the last measure gone removes the Burning tag and the flame is spent. A stowed lantern's clock waits.
class UMars_Processor_Lantern_Burn : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Lantern);
        Query.Require(FMars_Tag_Lantern_Burning);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Lantern& InState)
    {
        auto Self = InHandle.As_Lantern();
        if (Self.Get_IsStowed())
        { return; }

        const auto& Params = Self.Get_Fragment(FMars_Fragment_Lantern_Params);
        const auto Before = utils_lantern::Make_Reading(InState);

        InState.MeasureElapsed += float32(InDeltaT.Get_Seconds());
        while (InState.MeasuresLeft > 0 && InState.MeasureElapsed >= Params.SecondsPerMeasure)
        {
            InState.MeasuresLeft -= 1;
            InState.MeasureElapsed -= Params.SecondsPerMeasure;
        }

        if (InState.MeasuresLeft <= 0)
        {
            InState.MeasuresLeft = 0;
            InState.MeasureElapsed = 0.0f;
        }

        InState.Flame = utils_lantern::Get_Flame(Params, InState);

        utils_lantern::Apply_Changes(Self, Before, utils_lantern::Make_Reading(InState));
    }
}
