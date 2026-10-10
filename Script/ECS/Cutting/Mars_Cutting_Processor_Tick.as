// The chop clock, while a chop runs: the strike counts down Spec.ChopSeconds and lands (OnChopLanded, the cleaver at the
// board), then the recover counts down Spec.ChopSeconds and the next press may chop. A long frame finishes at most one
// phase, so the landing is never skipped.
class UMars_Processor_Cutting_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Cutting_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Cutting);
        Query.Require(FMars_Tag_Cutting_Chopping);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Cutting& InState)
    {
        auto Self = InHandle.As_Cutting();

        InState.ChopSecondsLeft = Math::Max(0.0f, InState.ChopSecondsLeft - float32(InDeltaT.Get_Seconds()));
        if (InState.ChopSecondsLeft > 0.0f)
        { return; }

        if (InState.ChopPhase == EMars_Cutting_ChopPhase::Recovering)
        {
            InState.ChopPhase = EMars_Cutting_ChopPhase::Idle;
            Self.Request_TryRemove(FMars_Tag_Cutting_Chopping);
            return;
        }

        InState.ChopPhase = EMars_Cutting_ChopPhase::Recovering;
        InState.ChopSecondsLeft = Self.Get_Spec().ChopSeconds;

        // InState is not read past this line: a listener may add fragments to the station.
        if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals))
        { Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopLanded.Broadcast(Self); }
    }
}
