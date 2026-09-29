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

    UFUNCTION()
    private void OnNewInteraction(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction)
    {
        auto Interactable = InTarget.Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        auto& State = Interactable.Get_Fragment(FMars_Fragment_Interactable);
        State.CurrentInteractTarget = InTarget;
        State.CurrentInteraction = InInteraction;

        if (Interactable.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
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
        auto Interactable = InTarget.Get_Fragment(FMars_Fragment_InteractionContext).Interactable;
        if (ck::Is_NOT_Valid(Interactable) || Interactable.Has_Fragment(FMars_Fragment_Interactable_Signals) == false)
        { return; }

        auto& Signals = Interactable.Get_Fragment(FMars_Fragment_Interactable_Signals);
        const auto Channel = utils_interact_target::Get_InteractionChannel(InTarget);
        for (int32 Index = 0; Index < Signals.ChanneledOnInteractionFinished.Num(); ++Index)
        {
            if (Signals.ChanneledOnInteractionFinished[Index].Channel == Channel)
            { Signals.ChanneledOnInteractionFinished[Index].Delegates.Broadcast(Interactable, InInteraction, InResult); }
        }
    }
}
