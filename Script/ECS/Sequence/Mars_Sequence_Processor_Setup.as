// The link, on the authority: rising edges from the MechanismSink on the sequence's own entity become the sequence's
// inputs, and the optional MechanismSource on that entity is asserted while the sequence is complete. A client wires none
// of it: it binds the ledger's rep-notify and its first pass shows the ledger this machine composed. The ledger's first
// application is the state the copy was born into, taken once as it stands: its standing steps announced one by one
// (and its completion), no rejection the ledger already counts raised. Each later change is reconciled as it arrives:
// it broadcasts the signals the replicated change implies.
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

        if (utils_net::Get_HasAuthority(InHandle) == false)
        {
            InHandle.BindTo_OnRepNotify(FMars_Fragment_Sequence, FCk_DynamicFragment_OnRepNotify(this, n"OnLedgerReplicated"));
            Reconcile(Sequence, EMars_Net_Reconcile::AsItStands);
            Sequence.Request_TryRemove(FMars_Tag_Sequence_NeedsSetup);
            return;
        }

        Sequence.Request_TryRemove(FMars_Fragment_Sequence_Mirror);

        auto Sink = InHandle.As_MechanismSink();
        const auto InputChannels = Sink.Get_InputChannels();
        for (const auto& Step : Sequence.Get_Fragment(FMars_Fragment_Sequence_Params).Steps)
        {
            ck::EnsureIfNot(InputChannels.Contains(Step),
                f"[Sequence] [{Sequence.ToString()}] has step [{Step.ToString()}] that its sink does not listen to; the combination can never complete");
        }

        Sink.BindTo_OnInputRose(FMars_Delegate_MechanismSink_OnInputRose(this, n"OnSinkInputRose"));

        // The source asserts while the sequence is complete.
        auto Source = InHandle.As_MechanismSource(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Source))
        {
            const auto Output = Sequence.Get_IsComplete() ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;
            Source.Request_SetOutput(utils_mechanism_source::Make_SetOutput(Output));
        }

        Sequence.Request_TryRemove(FMars_Tag_Sequence_NeedsSetup);
    }

    // An expected absence, not a defect: a notify can land on a sequence already ending.
    UFUNCTION()
    private void OnLedgerReplicated(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || utils_entity_lifetime::Get_IsPendingDestroy(InHandle, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
            || InHandle.Is_Sequence() == false)
        { return; }

        auto Sequence = InHandle.As_Sequence();
        if (Sequence.Get_Fragment(FMars_Fragment_Sequence_Mirror).InitialState == EMars_Net_InitialState::Awaited)
        {
            Sequence.Get_Fragment(FMars_Fragment_Sequence_Mirror).InitialState = EMars_Net_InitialState::Taken;
            Reconcile(Sequence, EMars_Net_Reconcile::AsItStands);
            return;
        }

        Reconcile(Sequence, EMars_Net_Reconcile::AsItArrives);
    }

    // The authority's order: a rejection, then the reset it caused (progress fell), then each step gained since, then the
    // completion. Several changes between two replications broadcast as one diff.
    private void Reconcile(FCk_Handle_Sequence& InSequence, EMars_Net_Reconcile InHow)
    {
        const auto Ledger = InSequence.Get_Fragment(FMars_Fragment_Sequence);
        auto& Mirror = InSequence.Get_Fragment(FMars_Fragment_Sequence_Mirror);
        auto Last = Mirror.Last;
        Mirror.Last = Ledger;

        // As it stands, every rejection the ledger counts came before this copy took its state; the standing progress
        // is still announced step by step, so a listener lights its steps.
        if (InHow == EMars_Net_Reconcile::AsItStands)
        { Last.Rejections = Ledger.Rejections; }

        if (InSequence.Has_Fragment(FMars_Fragment_Sequence_Signals) == false)
        { return; }

        // Handlers light and flash a node's indicators: scope the script world to the sequence's.
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(utils_entity_lifetime::Get_WorldForEntity(InSequence));

        if (Ledger.Rejections > Last.Rejections)
        { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnInputRejected.Broadcast(InSequence, Ledger.LastRejectedChannel); }

        auto FirstGained = Last.Progress;
        if (Ledger.Progress < Last.Progress)
        {
            FirstGained = 0;
            InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnReset.Broadcast(InSequence);
        }

        for (int32 Index = FirstGained; Index < Ledger.Progress; ++Index)
        { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnStepAccepted.Broadcast(InSequence, Index); }

        if (FirstGained < Ledger.Progress && InSequence.Get_IsComplete())
        { InSequence.Get_Fragment(FMars_Fragment_Sequence_Signals).OnCompleted.Broadcast(InSequence); }
    }

    UFUNCTION()
    private void OnSinkInputRose(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel)
    {
        auto Sequence = InSink.As_Sequence();
        Sequence.Request_Input(FMars_Request_Sequence_Input(InChannel));
    }
}
