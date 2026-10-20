// Runs the held victim through the phases: each lasts its Timing seconds, and a frame long enough to cross several
// enters each of them in order. Past Swallowed the victim is let go (Completed). A victim that is gone cancels the run.
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

        if (ck::Is_NOT_Valid(InState.Victim))
        {
            const auto Gone = DoRelease(Self, InState);
            if (Self.Has_Fragment(FMars_Fragment_Devour_Signals))
            { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Broadcast(Self, Gone, EMars_Devour_End::Cancelled); }
            return;
        }

        const auto Timing = Self.Get_Timing();
        InState.PhaseSeconds += float32(InDeltaT.Get_Seconds());

        TArray<EMars_Devour_Phase> Entered;
        auto IsOver = false;
        while (InState.PhaseSeconds >= Timing.Get_Seconds(InState.Phase))
        {
            InState.PhaseSeconds -= Timing.Get_Seconds(InState.Phase);
            if (InState.Phase == EMars_Devour_Phase::Swallowed)
            {
                IsOver = true;
                break;
            }

            InState.Phase = EMars_Devour_Phase(int32(InState.Phase) + 1);
            Entered.Add(InState.Phase);
        }

        auto Released = FCk_Handle();
        if (IsOver)
        { Released = DoRelease(Self, InState); }

        if (Self.Has_Fragment(FMars_Fragment_Devour_Signals) == false)
        { return; }

        for (const auto Phase : Entered)
        { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnPhaseChanged.Broadcast(Self, Phase); }

        if (IsOver)
        { Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Broadcast(Self, Released, EMars_Devour_End::Completed); }
    }
}
