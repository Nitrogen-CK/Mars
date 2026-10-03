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

        const auto UntrackSourceRequests = InRequests.UntrackSourceRequests;
        const auto UntrackSinkRequests = InRequests.UntrackSinkRequests;
        const auto TrackSourceRequests = InRequests.TrackSourceRequests;
        const auto TrackSinkRequests = InRequests.TrackSinkRequests;
        const auto HasRecompute = InRequests.RecomputeRequests.Num() > 0;

        // InRequests is invalid past this line; a request enqueued during the drain survives to the next pass.
        Self.Request_TryRemove(FMars_Fragment_MechanismDriver_Requests);

        auto Changed = false;

        for (const auto& Request : UntrackSourceRequests)
        {
            const auto Source = Request.Source;
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

        for (const auto& Request : UntrackSinkRequests)
        {
            if (InDriverComp.Sinks.Contains(Request.Sink) == false)
            { continue; }

            InDriverComp.Sinks.Remove(Request.Sink);
            Changed = true;
        }

        // A source or sink destroyed between its track request and this drain is skipped.
        for (const auto& Request : TrackSourceRequests)
        {
            const auto Source = Request.Source;
            if (ck::Is_NOT_Valid(Source) || InDriverComp.Sources.Contains(Source))
            { continue; }

            InDriverComp.Sources.Add(Source);
            Changed = true;

            auto MutableSource = Source;
            MutableSource.BindTo_OnAssertedChanged(
                FMars_Delegate_MechanismSource_OnAssertedChanged(this, n"OnSourceAssertedChanged"));
        }

        for (const auto& Request : TrackSinkRequests)
        {
            if (ck::Is_NOT_Valid(Request.Sink) || InDriverComp.Sinks.Contains(Request.Sink))
            { continue; }

            InDriverComp.Sinks.Add(Request.Sink);
            Changed = true;
        }

        if (Changed || HasRecompute)
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

    // Edges go out immediately so their order across sources is the signal order; counts only flag a recompute, so
    // several same-frame flips coalesce into one pass.
    UFUNCTION()
    private void OnSourceAssertedChanged(FCk_Handle_MechanismSource InSource, EMars_MechanismSource_Output InOutput)
    {
        if (ck::Is_NOT_Valid(_Driver))
        { return; }

        if (ck::IsValid(InSource))
        {
            const auto Channel = InSource.Get_OutputChannel();
            const TSet<FCk_Handle_MechanismSink> Sinks = _Driver.Get_Sinks();
            for (const auto& Sink : Sinks)
            {
                if (ck::Is_NOT_Valid(Sink))
                { continue; }

                if (Sink.Get_InputChannels().Contains(Channel) == false)
                { continue; }

                auto MutableSink = Sink;
                MutableSink.Request_NotifyInputEdge(FMars_Request_MechanismSink_NotifyInputEdge(Channel, InOutput));
            }
        }

        _Driver.Request_Recompute();
    }
}
