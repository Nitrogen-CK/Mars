// The link: rising edges from the MechanismSink on the sequence's own entity become the sequence's inputs, and the
// optional MechanismSource on that entity is asserted while the sequence is complete.
class UMars_Processor_Sequence_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Sequence_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Sequence);
        Query.Require(FMars_Tag_Sequence_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Sequence = InHandle.As_Sequence();

        auto Sink = InHandle.As_MechanismSink();
        const auto InputChannels = Sink.Get_InputChannels();
        for (const auto& Step : Sequence.Get_Fragment(FMars_Fragment_Sequence_Params).Steps)
        {
            ck::EnsureIfNot(InputChannels.Contains(Step),
                f"[Sequence] [{Sequence.ToString()}] has step [{Step.ToString()}] that its sink does not listen to; the combination can never complete");
        }

        Sink.BindTo_OnInputEdge(FMars_Delegate_MechanismSink_OnInputEdge(this, n"OnSinkInputEdge"));

        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            const auto Output = Sequence.Get_IsComplete() ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
            Source.Request_SetOutput(FMars_Request_MechanismSource_SetOutput(Output));
        }

        Sequence.Request_TryRemove(FMars_Tag_Sequence_NeedsSetup);
    }

    UFUNCTION()
    private void OnSinkInputEdge(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel, EMars_MechanismSource_Output InOutput)
    {
        if (InOutput == EMars_MechanismSource_Output::Deasserted)
        { return; }

        auto Sequence = InSink.As_Sequence();
        Sequence.Request_Input(FMars_Request_Sequence_Input(InChannel));
    }
}
