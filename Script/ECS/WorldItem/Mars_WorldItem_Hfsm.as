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

// Transfers the world item's held item into the initiator's hotbar stow target at the Grip of the initiator's gloves on it
// (UMars_SmTask_ActAtGrip: at once without gloves, or when they do not reach for it), and runs until the transfer reports:
// the item lands when the gloves close on it, never before they get there. A Transient world item destroys itself once its
// holder empties; a Persistent one is asked to Carry itself onto the initiator once the stow succeeds. A full hotbar fails
// (the pickup is normally disabled before it gets here); so do gloves that return or lose it before their Grip.
class UMars_SmTask_WorldItem_StowIntoInitiator : UMars_SmTask_ActAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_WorldItem _WorldItem;
    // Set at the grip: the Carry rides the gloves home (aged by the time since _RideAtSeconds).
    private TOptional<FMars_WorldItem_ArriveSpec> _Ride;
    private float64 _RideAtSeconds = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Initiator = FCk_Handle();
        _WorldItem = FCk_Handle_WorldItem();
        _Ride.Reset();

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
            ck::Trace(f"[WorldItem] Pickup fails at enter: world item [{WorldItem.ToString()}] or hotbar [{Hotbar.ToString()}] is invalid");
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Item = WorldItem.Get_HeldItem();
        if (ck::Is_NOT_Valid(Item) || ck::Is_NOT_Valid(Hotbar.TryGet_StowTarget(Item)))
        {
            DoFail("the world item holds nothing, or the hotbar has nowhere to stow it");
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
            DoFail("at the grip the world item holds nothing, or the hotbar has nowhere to stow it");
            return;
        }

        // A Persistent item taken at the grip rides the gloves home: its Carry here and the Hold that follows its selection.
        _Ride = TryGet_RideHome();
        _RideAtSeconds = System::GetGameTimeInSeconds();
        auto HeldItem = _Initiator.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (_Ride.IsSet() && ck::IsValid(HeldItem))
        { HeldItem.Request_SetNextHoldArrive(FMars_Request_HeldItem_SetNextHoldArrive(_WorldItem, _Ride.GetValue())); }

        auto Holder = _WorldItem.Get_Holder();
        Holder.Request_TransferItem_ToDataOnly(FCk_Request_Inventory_TransferItem_ToDataOnly(Item, Target),
            FCk_Delegate_Inventory_OnOperationResult_Transfer(this, n"OnStowComplete"));
    }

    protected void DoFail(const FString& InReason) override
    {
        ck::Warning(f"[WorldItem] Pickup failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
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
            {
                auto Carry = FMars_Request_WorldItem_Carry(_Initiator);
                if (_Ride.IsSet())
                {
                    const auto Since = float32(System::GetGameTimeInSeconds() - _RideAtSeconds);
                    Carry.Arrive = TOptional<FMars_WorldItem_ArriveSpec>(utils_world_item::Get_ArriveSpecAfter(_Ride.GetValue(), Since));
                }

                _WorldItem.Request_Carry(Carry);
            }

            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        DoFail(f"the stow transfer failed with [{InResult :n}]");
    }
}
