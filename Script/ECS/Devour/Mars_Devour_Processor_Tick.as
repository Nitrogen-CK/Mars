// Runs the held victim through the phases, in two halves. With authority over the devourer: each phase lasts its Timing
// seconds, and a frame long enough to cross several enters each of them in order; past Swallowed the victim is let go
// (Completed), and a victim that is gone cancels the run; the ledger is published once after the writes, then the
// signals are raised. A copy without authority only keeps the phase's clock, capped at the phase's length: its phases
// and its end arrive through the ledger (UMars_Processor_Devour_Mirror).
class UMars_Processor_Devour_Tick : UMars_Processor_Devour_Base
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Devour);
        Query.Require(FMars_Tag_Devour_Running);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Devour& InState)
    {
        auto Self = InHandle.As_Devour();
        const auto Timing = Self.Get_Timing();

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            InState.PhaseSeconds = Math::Min(InState.PhaseSeconds + float32(InDeltaT.Get_Seconds()), Timing.Get_Seconds(InState.Phase));
            return;
        }

        TArray<EMars_Devour_Phase> Entered;
        auto End = TOptional<EMars_Devour_End>();
        if (ck::Is_NOT_Valid(InState.Victim))
        { End = TOptional<EMars_Devour_End>(EMars_Devour_End::Cancelled); }
        else
        {
            InState.PhaseSeconds += float32(InDeltaT.Get_Seconds());
            while (InState.PhaseSeconds >= Timing.Get_Seconds(InState.Phase))
            {
                InState.PhaseSeconds -= Timing.Get_Seconds(InState.Phase);
                if (InState.Phase == EMars_Devour_Phase::Swallowed)
                {
                    End = TOptional<EMars_Devour_End>(EMars_Devour_End::Completed);
                    break;
                }

                InState.Phase = EMars_Devour_Phase(int32(InState.Phase) + 1);
                Entered.Add(InState.Phase);
            }
        }

        auto Released = FCk_Handle();
        if (End.IsSet())
        { Released = DoRelease(Self, InState, End.GetValue()); }

        utils_devour::Publish(Self);

        // Handlers react on the devourer and its victim (a view, a state machine): scope the script world to its own.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InHandle));
        for (const auto Phase : Entered)
        {
            if (Self.Has_Fragment(FMars_Fragment_Devour_Signals))
            { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnPhaseChanged.Broadcast(Self, Phase); }
        }

        if (End.IsSet() && Self.Has_Fragment(FMars_Fragment_Devour_Signals))
        { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Broadcast(Self, Released, End.GetValue()); }
    }
}
