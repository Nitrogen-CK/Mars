// What picking up a World-mode item does: stow it into the initiator's hotbar.
class UMars_SmState_WorldItem_PickUp : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, UMars_SmTask_WorldItem_StowIntoInitiator);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// Transfers the world item's held item into the initiator's hotbar stow target and runs until the transfer reports.
// The world item destroys itself once its holder empties.
class UMars_SmTask_WorldItem_StowIntoInitiator : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;

        auto Context = Get_StateMachineContext();
        auto SubSm = FCk_Handle(Get_OwningStateMachine());
        if (Context.Has_Fragment(FMars_Fragment_InteractionContext) == false ||
            ck::Is_NOT_Valid(SubSm) || SubSm.Has_Fragment(FMars_Fragment_InteractionContext) == false)
        {
            DoFail("no interaction context");
            return;
        }

        // The context is the InteractTarget; the initiator is stamped on the per-interaction sub-SM root.
        auto Owner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Initiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        auto WorldItem = Owner.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Hotbar = Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(WorldItem) || ck::Is_NOT_Valid(Hotbar))
        {
            DoFail("the interactable owner is not a world item, or the initiator has no hotbar");
            return;
        }

        auto Item = WorldItem.Get_HeldItem();
        auto Target = Hotbar.TryGet_StowTarget();
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Target))
        {
            DoFail("the world item holds nothing, or the hotbar has nowhere to stow it");
            return;
        }

        auto Holder = WorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnStowComplete"));
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        return _Outcome;
    }

    UFUNCTION()
    private void OnStowComplete(FCk_Handle_Inventory InSource,
                                FCk_Handle_Item InItem,
                                FCk_Handle_Inventory InTarget,
                                int32 InCount,
                                FCk_Handle_Item InNewItemInTarget,
                                ECk_Inventory_OperationResult_Transfer InResult)
    {
        if (InResult == ECk_Inventory_OperationResult_Transfer::Success)
        {
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        DoFail(f"the stow transfer failed with [{InResult :n}]");
    }

    private void DoFail(const FString& InReason)
    {
        ck::Warning(f"[WorldItem] Pickup failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
    }
}
