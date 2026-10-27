// Burns a lit flame's measured fuel wherever it is (a lantern on the belt burns too): one measure every SecondsPerMeasure,
// guttering through the last GutterSeconds of the last; the last measure gone removes the Burning tag and the flame is
// spent. Unlimited fuel never burns down.
class UMars_Processor_Flame_Burn : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Flame);
        Query.Require(FMars_Tag_Flame_Burning);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Flame& InState)
    {
        auto Self = InHandle.As_Flame();
        const auto& Params = Self.Get_Fragment(FMars_Fragment_Flame_Params);
        if (Params.Fuel.IsSet() == false)
        { return; }

        const auto& Fuel = Params.Fuel.GetValue();
        const auto Before = utils_flame::Make_Reading(Params, InState);

        InState.MeasureElapsed += float32(InDeltaT.Get_Seconds());
        while (InState.MeasuresLeft > 0 && InState.MeasureElapsed >= Fuel.SecondsPerMeasure)
        {
            InState.MeasuresLeft -= 1;
            InState.MeasureElapsed -= Fuel.SecondsPerMeasure;
        }

        if (InState.MeasuresLeft <= 0)
        {
            InState.MeasuresLeft = 0;
            InState.MeasureElapsed = 0.0f;
        }

        InState.Condition = utils_flame::Get_Condition(Params, InState);

        utils_flame::Apply_Changes(Self, Before, utils_flame::Make_Reading(Params, InState));
    }
}
