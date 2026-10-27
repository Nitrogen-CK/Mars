// A MechanismSource on the flame's own entity follows the flame: asserted while lit, deasserted otherwise, asked only
// when that reading changes. A flame entity with no source records the reading and asks nothing.
class UMars_Processor_Flame_Source : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Flame);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Flame& InState)
    {
        const auto Self = InHandle.As_Flame();
        const auto Output = Self.Get_IsLit() ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
        if (InState.LastSourceOutput.IsSet() && InState.LastSourceOutput.GetValue() == Output)
        { return; }

        InState.LastSourceOutput = TOptional<EMars_MechanismSource_Output>(Output);

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Source))
        { return; }

        Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Output));
    }
}
