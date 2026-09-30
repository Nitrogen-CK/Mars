// What interacting with a cargo slot does: stow the initiator's held item into it, or take its item into the
// initiator's hotbar.
class UMars_SmState_CargoSlot_Interact : UCk_SmState_EntityScript
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
        AddTask(InHandle, UMars_SmTask_CargoSlot_StowOrTake);

        auto OnSuccess = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnSuccess, UMars_SmCondition_AllTasksSucceeded);

        auto OnFailure = AddTransition(InHandle, UMars_SmState_ExitAndTerminate);
        AddCondition(OnFailure, UMars_SmCondition_AnyTaskFailed);
    }
}

// Re-evaluates Get_ActionFor for the initiator, stamps where the moving item visually is (so the next visual spawned
// for it lerps from there), requests the Stow / Take and runs until the slot reports the expected content. A Blocked_
// action fails with a warning; it is unreachable while UMars_Processor_CargoSlot_Prompt keeps the target disabled.
class UMars_SmTask_CargoSlot_StowOrTake : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;
    private FCk_Handle_CargoSlot _Slot;
    private FCk_Handle_Item _Item;
    private bool _IsStow = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Slot = FCk_Handle_CargoSlot();
        _Item = FCk_Handle_Item();
        _IsStow = false;

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
        auto Slot = Owner.As_CargoSlot(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Slot) || ck::Is_NOT_Valid(Initiator))
        {
            DoFail("the interactable owner is not a cargo slot, or there is no initiator");
            return;
        }

        const auto Action = Slot.Get_ActionFor(Initiator);
        if (Action == EMars_CargoSlot_Action::Stow)
        {
            auto HeldItem = Initiator.As_HeldItem();
            auto Item = HeldItem.Get_CurrentItem();
            Item.Request_SetArriveFrom(DoGet_WorldOf(HeldItem.Get_PresentationEntity(), FCk_Handle(HeldItem.Get_HandAttachPoint())));

            DoStart(Slot, Item, true);
            Slot.Request_Stow(FMars_Request_CargoSlot_Stow(Item));
            return;
        }

        if (Action == EMars_CargoSlot_Action::Take)
        {
            auto Item = Slot.Get_Item();
            Item.Request_SetArriveFrom(DoGet_WorldOf(Slot.Get_Visual(), FCk_Handle(Slot)));

            const auto Target = Initiator.As_Hotbar().TryGet_TakeTarget(Item);

            DoStart(Slot, Item, false);
            Slot.Request_Take(FMars_Request_CargoSlot_Take(Item, Target));
            return;
        }

        DoFail(f"the slot refuses the initiator: [{Action :n}]");
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        return _Outcome;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        DoUnbind();
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InMaybeItem)
    {
        const auto Landed = _IsStow ? InMaybeItem == _Item : ck::Is_NOT_Valid(InMaybeItem);
        if (Landed == false)
        { return; }

        DoUnbind();
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    private void DoStart(FCk_Handle_CargoSlot& InSlot, const FCk_Handle_Item& InItem, bool InIsStow)
    {
        _Slot = InSlot;
        _Item = InItem;
        _IsStow = InIsStow;
        _Slot.BindTo_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Slot))
        { _Slot.UnbindFrom_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged")); }

        _Slot = FCk_Handle_CargoSlot();
    }

    // The world pose of InEntity when it has a transform yet (a pending visual may not), else of InFallback.
    private FTransform DoGet_WorldOf(FCk_Handle InEntity, FCk_Handle InFallback) const
    {
        const auto EntityTransform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(EntityTransform))
        { return utils_transform::Get_EntityCurrentTransform(EntityTransform); }

        const auto FallbackTransform = InFallback.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(FallbackTransform))
        { return utils_transform::Get_EntityCurrentTransform(FallbackTransform); }

        return FTransform::Identity;
    }

    private void DoFail(const FString& InReason)
    {
        ck::Warning(f"[CargoSlot] Interaction failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
    }
}
