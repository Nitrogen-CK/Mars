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

// Re-evaluates Get_ActionFor for the initiator and acts at the Grip of the initiator's gloves (UMars_SmTask_ActAtGrip):
// a Place is a Place reach that sets the held platter down over the dock's node (utils_platter_dock::Start_PlaceReach); a
// Take waits for the gloves to close on the dock, checks the platter is still docked and the hotbar has a stow target, and
// lets the platter ride the gloves home. Without gloves both act at once. The dock moves nothing for the task:
// utils_platter_dock::Request_ActFor asks the dock's authority, which docks or undocks the platter, and the task runs
// until the effect is visible here (the dock holds the captured item; or no longer holds it and the initiator's hotbar
// does) or the dock's ledger names this initiator's refusal (DockRefused, UndockRefused, NoLongerDocked, NowhereToStow).
// PlaceFood succeeds at once (UMars_SmTask_PlaceHeldFood places the food). A Blocked_ action fails (ActionBlocked): the
// prompt processor disables the target for it, but can lag the initiator's hands by a frame.
class UMars_SmTask_PlatterDock_PlaceOrTake : UMars_SmTask_MoveItemAtGrip
{
    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle _Initiator;
    // The item the Act moves, captured on enter: the effect is it landing where the action puts it.
    private FCk_Handle_Item _Item;
    private EMars_PlatterDock_Action _Action = EMars_PlatterDock_Action::Place;
    // The dock's refusal serial when this task acted: only a later refusal is about it.
    private int32 _RefusalSerialAtAct = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Dock = FCk_Handle_PlatterDock();
        _Initiator = FCk_Handle();
        _Item = FCk_Handle_Item();

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

    // The take's stow target is asked at the grip: the hotbar may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        if (_Action == EMars_PlatterDock_Action::Place)
        {
            DoAct();
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

        // The take reaches the hands through the hotbar: the platter rides the gloves home from the dock.
        FCk_Handle DockEntity = _Dock;
        Ride_IntoHand(_Initiator, _Item, utils_transform::Get_EntityCurrentTransform(DockEntity.As_Transform()));

        DoAct();
    }

    // A place lands when the dock holds the item; a take when the dock no longer holds it and the initiator's hotbar does.
    protected bool DoGet_EffectLanded() override
    {
        if (ck::Is_NOT_Valid(_Dock))
        { return false; }

        if (_Action == EMars_PlatterDock_Action::Place)
        { return _Dock.Get_Item() == _Item; }

        const auto Hotbar = _Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        return _Dock.Get_Item() != _Item && ck::IsValid(Hotbar) && Hotbar.TryGet_SlotIndexOf(_Item).IsSet();
    }

    protected bool DoTryGet_Refusal(EMars_Interaction_FailReason& OutReason) override
    {
        if (ck::Is_NOT_Valid(_Dock) || _Dock.Get_RefusalSerial() <= _RefusalSerialAtAct)
        { return false; }

        if (_Dock.Get_LastRefused() != _Initiator)
        { return false; }

        OutReason = _Dock.Get_LastRefusal();
        return true;
    }

    private void DoStart(FCk_Handle_PlatterDock& InDock, const FCk_Handle_Item& InItem, EMars_PlatterDock_Action InAction)
    {
        _Dock = InDock;
        _Item = InItem;
        _Action = InAction;
    }

    private void DoAct()
    {
        _RefusalSerialAtAct = _Dock.Get_RefusalSerial();
        utils_platter_dock::Request_ActFor(_Dock, _Initiator, _Action);
        Await_ReplicatedEffect();
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
