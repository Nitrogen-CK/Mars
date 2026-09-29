class UMars_Processor_MechanismDriver_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_MechanismDriver_Requests;

    // The source signal carries only the source, so the handler reaches the (per-world singleton) driver through this.
    private FCk_Handle_MechanismDriver _Driver;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_MechanismDriver);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_MechanismDriver_Requests& InRequests,
                       FMars_Fragment_MechanismDriver& InDriverComp)
    {
        auto Self = InHandle.As_MechanismDriver();
        _Driver = Self;

        const auto UntrackSources = InRequests.UntrackSources;
        const auto UntrackSinks = InRequests.UntrackSinks;
        const auto TrackSources = InRequests.TrackSources;
        const auto TrackSinks = InRequests.TrackSinks;
        const auto Recompute = InRequests.Recompute;

        // Swap-and-pop - InRequests is dead past this line; a request enqueued during the drain survives to next pass.
        Self.Request_TryRemove(FMars_Fragment_MechanismDriver_Requests);

        auto Changed = false;

        for (const auto& Source : UntrackSources)
        {
            if (InDriverComp.Sources.Contains(Source) == false)
            { continue; }

            InDriverComp.Sources.Remove(Source);
            Changed = true;

            if (ck::IsValid(Source))
            {
                auto MutableSource = Source;
                MutableSource.UnbindFrom_OnAssertedChanged(
                    FMars_Delegate_MechanismSource_OnAssertedChanged(this, n"OnSourceAssertedChanged"));
            }
        }

        for (const auto& Sink : UntrackSinks)
        {
            if (InDriverComp.Sinks.Contains(Sink) == false)
            { continue; }

            InDriverComp.Sinks.Remove(Sink);
            Changed = true;
        }

        for (const auto& Source : TrackSources)
        {
            if (ck::Is_NOT_Valid(Source) || InDriverComp.Sources.Contains(Source))
            { continue; }

            InDriverComp.Sources.Add(Source);
            Changed = true;

            auto MutableSource = Source;
            MutableSource.BindTo_OnAssertedChanged(
                FMars_Delegate_MechanismSource_OnAssertedChanged(this, n"OnSourceAssertedChanged"));
        }

        for (const auto& Sink : TrackSinks)
        {
            if (ck::Is_NOT_Valid(Sink) || InDriverComp.Sinks.Contains(Sink))
            { continue; }

            InDriverComp.Sinks.Add(Sink);
            Changed = true;
        }

        if (Changed || Recompute)
        { RecomputeAllChannels(InDriverComp); }
    }

    // Full recompute on every change: N is tiny, it stays deterministic, and late-tracked sinks catch up for free.
    private void RecomputeAllChannels(FMars_Fragment_MechanismDriver& InDriverComp)
    {
        TArray<FCk_Handle_MechanismSource> InvalidSources;
        for (const auto& Source : InDriverComp.Sources)
        {
            if (ck::Is_NOT_Valid(Source))
            { InvalidSources.Add(Source); }
        }
        for (const auto& Source : InvalidSources)
        { InDriverComp.Sources.Remove(Source); }

        TArray<FCk_Handle_MechanismSink> InvalidSinks;
        for (const auto& Sink : InDriverComp.Sinks)
        {
            if (ck::Is_NOT_Valid(Sink))
            { InvalidSinks.Add(Sink); }
        }
        for (const auto& Sink : InvalidSinks)
        { InDriverComp.Sinks.Remove(Sink); }

        for (const auto& Sink : InDriverComp.Sinks)
        {
            auto MutableSink = Sink;
            const auto InputChannels = Sink.Get_InputChannels();

            for (const auto& Channel : InputChannels)
            {
                int32 AssertedCount = 0;
                int32 TotalCount = 0;

                for (const auto& Source : InDriverComp.Sources)
                {
                    if (Source.Get_OutputChannel() != Channel)
                    { continue; }

                    ++TotalCount;
                    if (Source.Get_IsAsserted())
                    { ++AssertedCount; }
                }

                MutableSink.Request_SetChannelInput(
                    FMars_Request_MechanismSink_SetChannelInput(Channel, AssertedCount, TotalCount));
            }
        }
    }

    // Only flags a recompute, so several same-frame flips coalesce into one pass.
    UFUNCTION()
    private void OnSourceAssertedChanged(FCk_Handle_MechanismSource InSource, bool InAsserted)
    {
        if (ck::Is_NOT_Valid(_Driver))
        { return; }

        _Driver.Request_Recompute();
    }
}
