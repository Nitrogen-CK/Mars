// One-shot per interactable: relays each target's new and finished interactions to the interactable's channeled signals,
// and records a Succeeded finish on an AfterCompletion target as the interactable's completion (with who finished it)
// before relaying it, so a listener of the relay reads it.
class UMars_Processor_Interactable_Setup : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Tag_Interactable_NeedsSetup;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Interactable);
        Query.Require(FMars_Tag_Interactable_NeedsSetup);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle)
    {
        auto Self = InHandle.As_Interactable();

        for (auto InteractTarget : Self.Get_AllInteractTargets())
        {
            utils_interact_target::BindTo_OnNewInteraction(InteractTarget,
                FCk_Delegate_InteractTarget_OnNewInteraction(this, n"OnNewInteraction"));
            utils_interact_target::BindTo_OnInteractionFinished(InteractTarget,
                FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnInteractionFinished"));
        }

        Self.Request_TryRemove(FMars_Tag_Interactable_NeedsSetup);
    }

    // An invalid interactable here is a teardown race: the target outlived its interactable by a frame.
    UFUNCTION()
    private void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        auto Interactable = InTarget.Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::Is_NOT_Valid(Interactable) || Interactable.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
        { return; }

        auto& Signals = Interactable.Get_Fragment(FMars_Fragment_Interactable_Signals);
        const auto Channel = utils_interact_target::Get_InteractionChannel(InTarget);
        for (int32 Index = 0; Index < Signals.ChanneledOnInteractionStarted.Num(); ++Index)
        {
            if (Signals.ChanneledOnInteractionStarted[Index].Channel == Channel)
            { Signals.ChanneledOnInteractionStarted[Index].Delegates.Broadcast(Interactable, InInteraction); }
        }
    }

    UFUNCTION()
    private void OnInteractionFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        const auto& Context = InTarget.Get_Fragment(FMars_Fragment_InteractionContext);
        auto Interactable = Context.Interactable;
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        if (InResult == ECk_SucceededFailed::Succeeded && Context.Work == EMars_Interactable_Work::AfterCompletion)
        { Record_Completion(Interactable, InTarget, InInteraction); }

        if (Interactable.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
        { return; }

        auto& Signals = Interactable.Get_Fragment(FMars_Fragment_Interactable_Signals);
        const auto Channel = utils_interact_target::Get_InteractionChannel(InTarget);
        for (int32 Index = 0; Index < Signals.ChanneledOnInteractionFinished.Num(); ++Index)
        {
            if (Signals.ChanneledOnInteractionFinished[Index].Channel == Channel)
            { Signals.ChanneledOnInteractionFinished[Index].Delegates.Broadcast(Interactable, InInteraction, InResult); }
        }
    }

    // The latest completion replaces an unconsumed one: a target's state machine runs the work for the latest finish.
    private void Record_Completion(FCk_Handle_Interactable& InInteractable, const FCk_Handle_InteractTarget& InTarget,
                                   const FCk_Handle_Interaction& InInteraction)
    {
        auto& State = InInteractable.Get_Fragment(FMars_Fragment_Interactable);
        State.CompletionSerial += 1;

        auto Completion = FMars_Interactable_Completion();
        Completion.Target = InTarget;
        Completion.Initiator = utils_interaction::Get_InteractionSource(InInteraction);
        Completion.Serial = State.CompletionSerial;
        State.Completion = TOptional<FMars_Interactable_Completion>(Completion);
    }
}
