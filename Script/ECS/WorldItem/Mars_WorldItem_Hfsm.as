// An interaction state that replaces UMars_SmState_InteractTarget_Enter: it runs TaskClass and exits the interaction
// once the task succeeds or fails. Subclasses only set TaskClass.
UCLASS(Abstract)
class UMars_SmState_InteractTarget_RunTask : UCk_SmState_EntityScript
{
    protected TSubclassOf<UCk_SmTask_EntityScript> TaskClass;

    UFUNCTION(BlueprintOverride)
    TArray<FGameplayTag> DoGet_StatesToOverride() const
    {
        return GameplayTag::MakeGameplayTagArrayFromTag(
            UCk_SmState_EntityScript::Get_StateTagForClass(UMars_SmState_InteractTarget_Enter));
    }

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        AddTask(InHandle, TaskClass);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// What picking up a World-mode item does: stow it into the initiator's hotbar.
class UMars_SmState_WorldItem_PickUp : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_WorldItem_StowIntoInitiator;
}

// Transfers the world item's held item into the initiator's hotbar stow target and runs until the transfer reports.
// A Transient world item destroys itself once its holder empties; a Persistent one is asked to Carry itself onto the
// initiator once the stow succeeds. A full hotbar fails (the pickup is normally disabled before it gets here).
class UMars_SmTask_WorldItem_StowIntoInitiator : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;
    private FCk_Handle _Initiator;
    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Initiator = FCk_Handle();
        _WorldItem = FCk_Handle_WorldItem();

        // The context is the InteractTarget; the initiator is stamped on the per-interaction sub-SM root.
        auto Context = Get_StateMachineContext();
        FCk_Handle SubSm = Get_OwningStateMachine();
        const auto HasContext = Context.Has_Fragment(FMars_Fragment_InteractionContext)
            && ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(HasContext, "[WorldItem] Pickup ran without an interaction context"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Owner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Initiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        auto WorldItem = Owner.As_WorldItem();
        auto Hotbar = Initiator.As_Hotbar();
        if (ck::Is_NOT_Valid(WorldItem) || ck::Is_NOT_Valid(Hotbar))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Item = WorldItem.Get_HeldItem();
        auto Target = Hotbar.TryGet_StowTarget(Item);
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Target))
        {
            DoFail("the world item holds nothing, or the hotbar has nowhere to stow it");
            return;
        }

        _Initiator = Initiator;
        _WorldItem = WorldItem;

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
            auto Item = ck::IsValid(InNewItemInTarget) ? InNewItemInTarget : InItem;
            if (ck::IsValid(Item) && Item.Has_PersistentWorldItem() && ck::IsValid(_WorldItem))
            { _WorldItem.Request_Carry(FMars_Request_WorldItem_Carry(_Initiator)); }

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
