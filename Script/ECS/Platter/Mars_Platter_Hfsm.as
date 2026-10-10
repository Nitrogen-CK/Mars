// What interacting with a platter does: an initiator holding food places it on the platter (UMars_SmTask_PlaceHeldFood);
// anyone else picks the platter up (UMars_SmTask_Platter_PickUp). Both tasks run, and the one that does not apply succeeds
// at once.
class UMars_SmState_Platter_Interact : UMars_SmState_InteractTarget_RunTask
{
    default TaskClass = UMars_SmTask_Platter_PickUp;

    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        Super::DoDefineState(InHandle);
        AddTask(InHandle, UMars_SmTask_PlaceHeldFood);
    }
}

// The world item's own stow, unless the initiator is placing food on this platter (UMars_SmTask_PlaceHeldFood acts then).
class UMars_SmTask_Platter_PickUp : UMars_SmTask_WorldItem_StowIntoInitiator
{
    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        // The context is the InteractTarget; the initiator is stamped on the per-interaction sub-SM root. The stow ensures
        // on a missing context.
        auto Context = Get_StateMachineContext();
        FCk_Handle SubSm = Get_OwningStateMachine();
        const auto HasContext = Context.Has_Fragment(FMars_Fragment_InteractionContext)
            && ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext);
        if (HasContext == false)
        {
            Super::DoEnterTask(InHandle, InNetContext);
            return;
        }

        const auto Owner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        const auto Initiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        if (ck::IsValid(utils_platter::TryGet_PlaceTarget(Owner, Initiator)))
        {
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        Super::DoEnterTask(InHandle, InNetContext);
    }
}

// Places the initiator's selected food on the platter the interaction is about (utils_platter::TryGet_PlaceTarget: the
// platter itself, or a dock's docked platter when the dock offers PlaceFood). The gloves carry the food over the platter
// (an FPHands Place reach, utils_platter::Request_DepositHeldFood); at the reach's Grip (UMars_SmTask_ActAtGrip) the food's
// world item is released from where the gloves hold it (back to its own holder: World mount, body Dynamic) and the platter
// is asked to Load its joint, whose drop queue poses it; the task then succeeds without waiting for the load (the drop
// waits for a still tray). An interaction this task does not apply to succeeds at once. Fails, the food still in hand, when
// the platter is full, when the gloves never take the reach, or when they return or lose the target before the Grip.
class UMars_SmTask_PlaceHeldFood : UMars_SmTask_ActAtGrip
{
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_Hotbar _Holder;
    private FCk_Handle_FPHands _Hands;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;

        // The context is the InteractTarget; the initiator is stamped on the per-interaction sub-SM root.
        auto Context = Get_StateMachineContext();
        FCk_Handle SubSm = Get_OwningStateMachine();
        const auto HasContext = Context.Has_Fragment(FMars_Fragment_InteractionContext)
            && ck::IsValid(SubSm) && SubSm.Has_Fragment(FMars_Fragment_InteractionContext);
        if (ck::EnsureIfNot(HasContext, "[Platter] Placing food ran without an interaction context"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        const auto Owner = Context.Get_Fragment(FMars_Fragment_InteractionContext).InteractableOwner;
        const auto Initiator = SubSm.Get_Fragment(FMars_Fragment_InteractionContext).Initiator;
        _Platter = utils_platter::TryGet_PlaceTarget(Owner, Initiator);
        if (ck::Is_NOT_Valid(_Platter))
        {
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        _Holder = Initiator.As_Hotbar();
        _Hands = Initiator.As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(_Hands), f"[Platter] [{Initiator.ToString()}] holds food but has no gloves to place it with"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        if (_Platter.Get_IsFull())
        {
            DoFail(f"[{_Platter.ToString()}] is full");
            return;
        }

        Await_PlaceGrip(_Hands);
        utils_platter::Request_DepositHeldFood(_Platter, _Holder, _Hands);
    }

    // The food is let go from where the gloves carried it; the platter's drop queue poses it over the tray.
    protected void DoAtGrip() override
    {
        const auto Food = _Holder.TryGet_SelectedFood();
        if (ck::Is_NOT_Valid(Food) || _Platter.Get_IsFull())
        {
            DoFail(f"at the Grip the hands hold no food [{Food.ToString()}] or [{_Platter.ToString()}] is full");
            return;
        }

        auto WorldItem = Food.Get_PersistentWorldItem();
        FCk_Handle FoodEntity = WorldItem;
        const auto Piece = FoodEntity.As_FoodPiece(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(WorldItem) && ck::IsValid(Piece),
            f"[Platter] Food item [{Food.ToString()}] has no world item that is a FoodPiece (world item [{WorldItem.ToString()}])"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        WorldItem.Request_Release(FMars_Request_WorldItem_Release(Food, _Holder.Get_SelectedSlot(), FVector::ZeroVector, FVector::ZeroVector));
        _Platter.Request_Load(FMars_Request_Platter_Load(Piece));
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    protected void DoFail(const FString& InReason) override
    {
        ck::Warning(f"[Platter] Placing food failed, it stays in the hands: {InReason}");
        _Outcome = ECk_SmTaskResult::Failed;
    }
}

namespace utils_platter
{
    // The platter InInitiator would put its selected food on by interacting with InOwner: InOwner itself when it is a
    // platter, or the platter docked on InOwner when it is a dock whose action for InInitiator is PlaceFood. Invalid when
    // InInitiator holds no food, or InOwner is neither.
    FCk_Handle_Platter TryGet_PlaceTarget(FCk_Handle InOwner, FCk_Handle InInitiator)
    {
        const auto Hotbar = InInitiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hotbar) || ck::Is_NOT_Valid(Hotbar.TryGet_SelectedFood()))
        { return FCk_Handle_Platter(); }

        if (InOwner.Is_Platter())
        { return InOwner.As_Platter(); }

        if (InOwner.Is_PlatterDock() == false)
        { return FCk_Handle_Platter(); }

        const auto Dock = InOwner.As_PlatterDock();
        if (Dock.Get_ActionFor(InInitiator) != EMars_PlatterDock_Action::PlaceFood)
        { return FCk_Handle_Platter(); }

        return Dock.Get_Platter();
    }

    // Starts putting InHolder's selected food on InPlatter: the gloves carry it over the platter (an FPHands Place reach on
    // the platter's world item). The food is let go at the reach's Grip (UMars_SmTask_PlaceHeldFood). Holding no food, or
    // a full platter, starts nothing: the prompts disable the target for both, but can lag the hands by a frame.
    void Request_DepositHeldFood(FCk_Handle_Platter InPlatter, FCk_Handle_Hotbar InHolder, FCk_Handle_FPHands InHands)
    {
        const auto Food = InHolder.TryGet_SelectedFood();
        if (ck::Is_NOT_Valid(Food) || InPlatter.Get_IsFull())
        {
            ck::Warning(f"[Platter] Nothing to place on [{InPlatter.ToString()}]: food [{Food.ToString()}], full [{InPlatter.Get_IsFull()}]");
            return;
        }

        FCk_Handle PlatterEntity = InPlatter;
        const auto Subject = FMars_FPHands_ReachSubject(PlatterEntity.As_WorldItem().Get_Pickup(), PlatterEntity);
        auto Hands = InHands;
        Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Subject, ECk_Interaction_CompletionPolicy::Instant, EMars_FPHands_ReachKind::Place));
    }
}
