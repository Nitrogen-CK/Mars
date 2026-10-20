// An interaction state that replaces UMars_SmState_InteractTarget_Enter: it runs TaskClass and ends the interaction with
// the tasks' outcome (a WhileLive target's live interaction ends with it; an AfterCompletion one had ended already).
// Subclasses only set TaskClass.
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

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_InteractTarget_Succeeded);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_InteractTarget_Failed);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// What picking up a World-mode item does: stow it into the initiator's hotbar.
class UMars_SmState_WorldItem_PickUp : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_WorldItem_StowIntoInitiator;
}

// Transfers the world item's held item into the initiator's hotbar stow target at the Grip of the initiator's gloves on it
// (UMars_SmTask_ActAtGrip: at once without gloves, or when they do not reach for it), and runs until the transfer reports:
// the item lands when the gloves close on it, never before they get there. A Transient world item destroys itself once its
// holder empties; a Persistent one mounts on the initiator from where its item lands (UMars_Processor_WorldItem_Reconcile),
// riding the gloves home when they took it. A full hotbar fails (the pickup is normally disabled before it gets here); so
// do gloves that return or lose it before their Grip.
class UMars_SmTask_WorldItem_StowIntoInitiator : UMars_SmTask_ActAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Initiator = FCk_Handle();
        _WorldItem = FCk_Handle_WorldItem();

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        // The pickup state runs only on a world item's own target, for an initiator that stows into a hotbar.
        auto WorldItem = Owner.As_WorldItem(ECk_SanityCheck::UnChecked);
        auto Hotbar = Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(WorldItem) && ck::IsValid(Hotbar),
            f"[WorldItem] Pickup ran for world item [{WorldItem.ToString()}] and hotbar [{Hotbar.ToString()}]: one is invalid"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Item = WorldItem.Get_HeldItem();
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Hotbar.TryGet_StowTarget(Item)))
        {
            DoFail(EMars_Interaction_FailReason::NowhereToStow);
            return;
        }

        _Initiator = Initiator;
        _WorldItem = WorldItem;
        Await_Grip(Initiator);
    }

    // The hotbar is asked again: its slots may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        auto Item = _WorldItem.Get_HeldItem();
        const auto Hotbar = _Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        auto Target = ck::IsValid(Hotbar) ? Hotbar.TryGet_StowTarget(Item) : FCk_Handle_Inventory_DataOnly();
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Target))
        {
            DoFail(EMars_Interaction_FailReason::NowhereToStow);
            return;
        }

        // A Persistent item taken at the grip rides the gloves home: its next mount is wherever the stow puts it.
        const auto Ride = TryGet_RideHome();
        if (Ride.IsSet() && _WorldItem.Get_Persistence() == EMars_WorldItem_Persistence::Persistent)
        { _WorldItem.Request_ArriveNextMount(FMars_Request_WorldItem_ArriveNextMount(Ride.GetValue())); }

        auto Holder = _WorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnStowComplete"));
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

        DoFail(EMars_Interaction_FailReason::TransferRefused);
    }
}
