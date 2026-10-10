// What interacting with a dock does: place the initiator's held platter on it, take its platter into the initiator's
// hands (UMars_SmTask_PlatterDock_PlaceOrTake), or put the initiator's food on the docked platter
// (UMars_SmTask_PlaceHeldFood). Both tasks run, and the one that does not apply succeeds at once.
class UMars_SmState_PlatterDock_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_PlatterDock_PlaceOrTake;

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        Super::DoDefineState(InHandle);
        AddTask(InHandle, UMars_SmTask_PlaceHeldFood);
    }
}

// Re-evaluates Get_ActionFor for the initiator and moves the platter at the Grip of the initiator's gloves
// (UMars_SmTask_ActAtGrip): a Place is a Place reach that sets the held platter down over the dock's node
// (utils_platter_dock::Request_PlaceHeldPlatter), and the Dock is requested at its Grip, so the dock's Carry takes the tray
// from where the gloves hold it; a Take waits for the gloves to close on the dock, then requests the Undock. Without gloves
// both act at once. The task then runs until the dock reports the platter docked or undocked, or that the dock was
// refused. No arrival to hand over: a Persistent world item's mount lerps on its own. PlaceFood succeeds at once
// (UMars_SmTask_PlaceHeldFood places the food). A Blocked_ action fails with a warning: the prompt processor disables the
// target for it, but can lag the initiator's hands by a frame.
class UMars_SmTask_PlatterDock_PlaceOrTake : UMars_SmTask_ActAtGrip
{
    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle _Initiator;
    private FCk_Handle_Item _Item;
    private FCk_Handle_Platter _Platter;
    private EMars_PlatterDock_Action _Action = EMars_PlatterDock_Action::Place;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Dock = FCk_Handle_PlatterDock();
        _Initiator = FCk_Handle();
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
        if (Action == EMars_PlatterDock_Action::PlaceFood)
        {
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        _Initiator = Initiator;
        if (Action == EMars_PlatterDock_Action::Place)
        {
            DoStart(Dock, Initiator.As_HeldItem().Get_CurrentItem(), Action);

            auto Hands = Initiator.As_FPHands(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Hands))
            {
                DoAtGrip();
                return;
            }

            Await_PlaceGrip(Hands);
            utils_platter_dock::Request_PlaceHeldPlatter(Dock, _Item, Hands);
            return;
        }

        if (Action == EMars_PlatterDock_Action::Take)
        {
            DoStart(Dock, Dock.Get_Item(), Action);
            Await_Grip(Initiator);
            return;
        }

        DoFail(f"the dock refuses the initiator: [{Action :n}]");
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        DoUnbind();
    }

    // The take's stow target is asked at the grip: the hotbar may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        if (_Action == EMars_PlatterDock_Action::Place)
        {
            _Dock.Request_Dock(FMars_Request_PlatterDock_Dock(_Item));
            return;
        }

        const auto Target = _Initiator.As_Hotbar().TryGet_StowTarget(_Item);
        if (ck::Is_NOT_Valid(Target) || _Dock.Get_Item() != _Item)
        {
            DoFail(f"at the grip [{_Item.ToString()}] is no longer docked, or the hotbar has nowhere to take it");
            return;
        }

        // The take reaches the hands through the hotbar and HeldItem's Hold: that Hold rides the gloves home.
        const auto Ride = TryGet_RideHome();
        auto HeldItem = _Initiator.As_HeldItem(ECk_SanityCheck::UnChecked);
        const auto WorldItem = _Item.Get_PersistentWorldItem();
        if (Ride.IsSet() && ck::IsValid(HeldItem) && ck::IsValid(WorldItem))
        { HeldItem.Request_SetNextHoldArrive(FMars_Request_HeldItem_SetNextHoldArrive(WorldItem, Ride.GetValue())); }

        _Dock.Request_Undock(FMars_Request_PlatterDock_Undock(_Item, Target));
    }

    protected void DoFail(const FString& InReason) override
    {
        ck::Warning(f"[PlatterDock] Interaction failed: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
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
}

namespace utils_platter_dock
{
    // Starts setting InItem (the held platter) down on InDock: the gloves carry it in a Place reach whose spot is the dock's
    // node lifted by the platter's held half height (its bounds centre lands there), anchored to the node. The dock is
    // asked to take it at the reach's Grip (UMars_SmTask_PlatterDock_PlaceOrTake).
    void Request_PlaceHeldPlatter(const FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, FCk_Handle_FPHands InHands)
    {
        const auto WorldItem = InItem.Get_PersistentWorldItem();
        const auto HalfHeight = ck::IsValid(WorldItem) ? WorldItem.Get_BoundsFit().HalfExtents.Z : 0.0;
        const auto NodeWorld = utils_transform::Get_EntityCurrentTransform(InDock.Get_Node());
        const auto SpotWorld = FTransform(NodeWorld.GetRotation(),
            NodeWorld.GetLocation() + NodeWorld.GetRotation().GetUpVector() * HalfHeight, FVector::OneVector);

        FCk_Handle DockEntity = InDock;
        auto Request = FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(InDock.Get_Interactable(), DockEntity),
            ECk_Interaction_CompletionPolicy::Instant, EMars_FPHands_ReachKind::Place);
        Request.PlaceAtWorld = TOptional<FTransform>(SpotWorld);

        auto Hands = InHands;
        Hands.Request_StartReach(Request);
    }
}
