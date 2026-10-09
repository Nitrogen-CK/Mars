// What interacting with a dock does: place the initiator's held platter on it, or take its platter into the initiator's
// hands.
class UMars_SmState_PlatterDock_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_PlatterDock_PlaceOrTake;
}

// Re-evaluates Get_ActionFor for the initiator, requests the Dock / Undock and runs until the dock reports the platter
// docked or undocked, or that the dock was refused. No arrival to hand over: a Persistent world item's mount lerps on its
// own. A Blocked_ action fails with a warning: the prompt processor disables the target for it, but can lag the
// initiator's hands by a frame.
class UMars_SmTask_PlatterDock_PlaceOrTake : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ECk_SmTaskResult _Outcome = ECk_SmTaskResult::Running;
    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle_Item _Item;
    private FCk_Handle_Platter _Platter;
    private EMars_PlatterDock_Action _Action = EMars_PlatterDock_Action::Place;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Dock = FCk_Handle_PlatterDock();
        _Item = FCk_Handle_Item();
        _Platter = FCk_Handle_Platter();

        // The context is the InteractTarget; the initiator is stamped on the per-interaction sub-SM root.
        auto Context = Get_StateMachineContext();
        FCk_Handle SubSm = Get_OwningStateMachine();
        const auto HasContext = Context.Has_Fragment(FMars_Fragment_InteractionContext)
            && ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(HasContext, "[PlatterDock] Interaction ran without an interaction context"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        auto Owner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        auto Initiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        auto Dock = Owner.As_PlatterDock();
        if (ck::Is_NOT_Valid(Dock) || ck::EnsureIfNot(ck::IsValid(Initiator), f"[PlatterDock] [{Dock.ToString()}] interaction has no initiator"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Action = Dock.Get_ActionFor(Initiator);
        if (Action == EMars_PlatterDock_Action::Place)
        {
            auto Item = Initiator.As_HeldItem().Get_CurrentItem();

            DoStart(Dock, Item, Action);
            Dock.Request_Dock(FMars_Request_PlatterDock_Dock(Item));
            return;
        }

        if (Action == EMars_PlatterDock_Action::Take)
        {
            auto Item = Dock.Get_Item();
            const auto Target = Initiator.As_Hotbar().TryGet_StowTarget(Item);

            DoStart(Dock, Item, Action);
            Dock.Request_Undock(FMars_Request_PlatterDock_Undock(Item, Target));
            return;
        }

        DoFail(f"the dock refuses the initiator: [{Action :n}]");
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
    private void OnDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (_Action != EMars_PlatterDock_Action::Place || InPlatter != _Platter)
        { return; }

        DoUnbind();
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    UFUNCTION()
    private void OnUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (_Action != EMars_PlatterDock_Action::Take || InPlatter != _Platter)
        { return; }

        DoUnbind();
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    UFUNCTION()
    private void OnDockRefused(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        if (InItem != _Item)
        { return; }

        DoUnbind();
        DoFail(f"placing [{InItem.ToString()}] was refused: [{InRefusal :n}]");
    }

    // Place waits on OnDocked of the item's platter (or its refusal), Take on OnUndocked of the docked one.
    private void DoStart(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, EMars_PlatterDock_Action InAction)
    {
        _Dock = InDock;
        _Item = InItem;
        _Action = InAction;
        _Platter = utils_platter_dock::TryGet_PlatterOf(InItem);
        _Dock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
        _Dock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnUndocked"));
        _Dock.BindTo_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefused"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Dock))
        {
            _Dock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
            _Dock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnUndocked"));
            _Dock.UnbindFrom_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefused"));
        }

        _Dock = FCk_Handle_PlatterDock();
    }

    private void DoFail(const FString& InReason)
    {
        ck::Warning(f"[PlatterDock] Interaction failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
    }
}
