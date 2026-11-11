// What interacting with a hook does: hang the initiator's held lantern, take the hung lantern into the initiator's hotbar,
// or feed it the initiator's held tallow.
class UMars_SmState_LanternHook_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_LanternHook_Interact;
}

// Acts at the Grip of the initiator's gloves on the hook (UMars_SmTask_MoveItemAtGrip: at once without gloves, or when
// they do not reach for it): the lantern leaves the hand once the glove carrying it closes on the hook, a taken lantern
// rides the glove home, a refuel pours once the glove with the tallow is there. Re-evaluates Get_ActionFor for the
// initiator at the Grip. The hook moves nothing for the task: utils_lantern_hook::Request_ActFor asks its authority, and
// the task runs until the effect is visible here (the hook holds the lantern, the hook is empty and the initiator's hotbar
// holds it, the tallow has left the initiator's hotbar) or the hook's ledger names this initiator's refusal. A Blocked_
// action fails (ActionBlocked): the prompt processor disables the target for it, but can lag the initiator's hands by a
// frame.
class UMars_SmTask_LanternHook_Interact : UMars_SmTask_MoveItemAtGrip
{
    private FCk_Handle _Initiator;
    private FCk_Handle_LanternHook _Hook;
    // The lantern or the tallow the Act moves, captured at the Grip.
    private FCk_Handle_Item _Item;
    private EMars_LanternHook_Action _Action = EMars_LanternHook_Action::Hang;
    // The hook's refusal serial when this task acted: only a later refusal is about it.
    private int32 _RefusalSerialAtAct = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Initiator = FCk_Handle();
        _Hook = FCk_Handle_LanternHook();
        _Item = FCk_Handle_Item();

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        auto Hook = Owner.As_LanternHook(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Hook), f"[LanternHook] Interaction owner [{Owner.ToString()}] is no lantern hook")
            || ck::EnsureIfNot(ck::IsValid(Initiator), f"[LanternHook] [{Hook.ToString()}] interaction has no initiator"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Action = Hook.Get_ActionFor(Initiator);
        const auto IsActionable = Action == EMars_LanternHook_Action::Hang || Action == EMars_LanternHook_Action::Take
            || Action == EMars_LanternHook_Action::Refuel;
        if (IsActionable == false)
        {
            DoFail(EMars_Interaction_FailReason::ActionBlocked);
            return;
        }

        _Initiator = Initiator;
        _Hook = Hook;
        Await_Grip(Initiator);
    }

    // The hook is asked again: the hands may have changed while the gloves reached.
    protected void DoAtGrip() override
    {
        const auto Action = _Hook.Get_ActionFor(_Initiator);
        if (Action == EMars_LanternHook_Action::Hang || Action == EMars_LanternHook_Action::Refuel)
        {
            DoAct(_Initiator.As_HeldItem().Get_CurrentItem(), Action);
            return;
        }

        if (Action == EMars_LanternHook_Action::Take)
        {
            auto Item = _Hook.Get_Item();
            FCk_Handle HookEntity = _Hook;
            Ride_IntoHand(_Initiator, Item, utils_transform::Get_EntityCurrentTransform(HookEntity.As_Transform()));
            DoAct(Item, Action);
            return;
        }

        DoFail(EMars_Interaction_FailReason::ActionBlocked);
    }

    protected bool DoGet_EffectLanded() override
    {
        if (ck::Is_NOT_Valid(_Hook))
        { return false; }

        if (_Action == EMars_LanternHook_Action::Hang)
        { return _Hook.Get_Item() == _Item; }

        const auto Hotbar = _Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hotbar))
        { return false; }

        const auto InHotbar = Hotbar.TryGet_SlotIndexOf(_Item).IsSet();
        if (_Action == EMars_LanternHook_Action::Refuel)
        { return InHotbar == false; }

        return ck::Is_NOT_Valid(_Hook.Get_Item()) && InHotbar;
    }

    protected bool DoTryGet_Refusal(EMars_Interaction_FailReason& OutReason) override
    {
        if (ck::Is_NOT_Valid(_Hook) || _Hook.Get_RefusalSerial() <= _RefusalSerialAtAct)
        { return false; }

        if (_Hook.Get_LastRefused() != _Initiator)
        { return false; }

        OutReason = _Hook.Get_LastRefusal();
        return true;
    }

    private void DoAct(const FCk_Handle_Item& InItem, EMars_LanternHook_Action InAction)
    {
        _Item = InItem;
        _Action = InAction;
        _RefusalSerialAtAct = _Hook.Get_RefusalSerial();
        utils_lantern_hook::Request_ActFor(_Hook, _Initiator, InAction);
        Await_ReplicatedEffect();
    }
}
