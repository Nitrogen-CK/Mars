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
// (utils_platter_dock::Start_PlaceReach), and the Dock is requested at its Grip, so the platter mounts on the dock
// from where the gloves hold it; a Take waits for the gloves to close on the dock, then requests the Undock, its next
// mount riding the gloves home. Without gloves both act at once. The task then runs until the dock reports the platter
// docked or undocked, or that the dock or the undock was refused (the task fails).
// PlaceFood succeeds at once (UMars_SmTask_PlaceHeldFood places the food). A Blocked_ action fails (ActionBlocked): the
// prompt processor disables the target for it, but can lag the initiator's hands by a frame.
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

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        auto Dock = Owner.As_PlatterDock(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Dock), f"[PlatterDock] Interaction owner [{Owner.ToString()}] is no dock")
            || ck::EnsureIfNot(ck::IsValid(Initiator), f"[PlatterDock] [{Dock.ToString()}] interaction has no initiator"))
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
            utils_platter_dock::Start_PlaceReach(Dock, _Item, Hands);
            return;
        }

        if (Action == EMars_PlatterDock_Action::Take)
        {
            DoStart(Dock, Dock.Get_Item(), Action);
            Await_Grip(Initiator);
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
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

        if (_Dock.Get_Item() != _Item)
        {
            DoFail(EMars_Interaction_FailReason::NoLongerDocked);
            return;
        }

        const auto Target = _Initiator.As_Hotbar().TryGet_StowTarget(_Item);
        if (ck::Is_NOT_Valid(Target))
        {
            DoFail(EMars_Interaction_FailReason::NowhereToStow);
            return;
        }

        // The take reaches the hands through the hotbar: the platter's next mount rides the gloves home.
        const auto Ride = TryGet_RideHome();
        auto WorldItem = _Item.Get_PersistentWorldItem();
        if (Ride.IsSet() && ck::IsValid(WorldItem))
        { WorldItem.Request_ArriveNextMount(FMars_Request_WorldItem_ArriveNextMount(Ride.GetValue())); }

        _Dock.Request_Undock(FMars_Request_PlatterDock_Undock(_Item, Target));
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
        DoFail(EMars_Interaction_FailReason::DockRefused);
    }

    UFUNCTION()
    private void OnUndockRefused(FCk_Handle_PlatterDock InDock, FCk_Handle_Item InItem, EMars_PlatterDock_Refusal InRefusal)
    {
        if (_Action != EMars_PlatterDock_Action::Take || InItem != _Item)
        { return; }

        DoUnbind();
        DoFail(EMars_Interaction_FailReason::UndockRefused);
    }

    // Place waits on OnDocked of the item's platter (or its refusal), Take on OnUndocked of the docked one (or its refusal).
    private void DoStart(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, EMars_PlatterDock_Action InAction)
    {
        _Dock = InDock;
        _Item = InItem;
        _Action = InAction;
        _Platter = utils_platter_dock::TryGet_PlatterOf(InItem);
        _Dock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
        _Dock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnUndocked"));
        _Dock.BindTo_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefused"));
        _Dock.BindTo_OnUndockRefused(FMars_Delegate_PlatterDock_OnUndockRefused(this, n"OnUndockRefused"));
    }

    private void DoUnbind()
    {
        if (ck::IsValid(_Dock))
        {
            _Dock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnDocked"));
            _Dock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnUndocked"));
            _Dock.UnbindFrom_OnDockRefused(FMars_Delegate_PlatterDock_OnDockRefused(this, n"OnDockRefused"));
            _Dock.UnbindFrom_OnUndockRefused(FMars_Delegate_PlatterDock_OnUndockRefused(this, n"OnUndockRefused"));
        }

        _Dock = FCk_Handle_PlatterDock();
    }
}

namespace utils_platter_dock
{
    // Starts setting InItem (the held platter) down on InDock: the gloves carry it in a Place reach whose spot is the dock's
    // node lifted by the platter's held half height (its bounds centre lands there), anchored to the node. The dock is
    // asked to take it at the reach's Grip (UMars_SmTask_PlatterDock_PlaceOrTake).
    void Start_PlaceReach(const FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, FCk_Handle_FPHands InHands)
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
