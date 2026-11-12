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
        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        if (ck::IsValid(utils_platter::TryGet_PlaceTarget(Owner, Initiator)))
        {
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        Super::DoEnterTask(InHandle, InNetContext);
    }
}

// Where a deposit stands once the gloves are at their Grip.
enum EMars_Platter_DepositStage
{
    // Waiting for the place reach's Grip (or nothing to place).
    AtTheGloves,
    // The deposit is asked for: the platter takes the food on its books (Get_HoldsPiece), or a ledger refuses it.
    Asked,
    // The platter holds the food: it lands (Get_HasLanded), or leaves the books before it landed (taken by hand, or gone).
    OnTheBooks,
    // The deposit has its outcome.
    Done
}

// Places the initiator's selected food on the platter the interaction is about (utils_platter::TryGet_PlaceTarget: the
// platter itself, or a dock's docked platter when the dock offers PlaceFood). The gloves carry the food over the platter (an
// FPHands Place reach, utils_platter::Start_DepositReach); at the reach's Grip (UMars_SmTask_ActAtGrip) the task asks for
// the deposit and moves nothing itself: through utils_platter_dock::Request_ActFor (PlaceFood) at a dock, whose authority
// judges the dock's policy and forwards it, else through utils_platter::Request_DepositFor. The platter's authority lets
// the food go from the initiator's hands, waits until it is free and loads it (UMars_Processor_Platter_Deposits). The task
// then waits, as this machine sees it: Asked until the platter holds the piece (within the awaited effect's budget), or
// until the platter's ledger, or the dock's, has a refusal newer than the ask that names this initiator (the deposit fails
// with its reason: NoFoodInHand, PlatterFull, TransferRefused, ReleaseRefused, LeftTheBooks, LoadRefused, ActionBlocked);
// then OnTheBooks until the piece lands (succeeds), or fails LeftTheBooks when it leaves the books or is gone first. An
// interaction this task does not apply to succeeds at once. Fails, the food still in hand, when the platter is full, when
// the gloves refuse the place reach, or when they return or lose the target before the Grip.
class UMars_SmTask_PlaceHeldFood : UMars_SmTask_ActAtGrip
{
    private FCk_Handle_Platter _Platter;
    // The interaction's owner when it is a dock: the deposit is asked through its Act.
    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle _Initiator;
    private FCk_Handle_Hotbar _Holder;
    private FCk_Handle_FPHands _Hands;
    // The food's joint, captured at the Grip.
    private FCk_Handle_FoodPiece _Piece;
    // The ledgers' refusal serials when this task asked: only a later refusal is about it.
    private int32 _PlatterSerialAtAsk = 0;
    private int32 _DockSerialAtAsk = 0;
    private EMars_Platter_DepositStage _Stage = EMars_Platter_DepositStage::AtTheGloves;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Stage = EMars_Platter_DepositStage::AtTheGloves;
        _Dock = FCk_Handle_PlatterDock();
        _Piece = FCk_Handle_FoodPiece();

        FCk_Handle Owner;
        FCk_Handle Initiator;
        if (TryGet_InteractionEnds(Owner, Initiator) == false)
        { return; }

        _Platter = utils_platter::TryGet_PlaceTarget(Owner, Initiator);
        if (ck::Is_NOT_Valid(_Platter))
        {
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        _Initiator = Initiator;
        _Dock = Owner.As_PlatterDock(ECk_SanityCheck::UnChecked);
        _Holder = Initiator.As_Hotbar();
        _Hands = Initiator.As_FPHands(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(_Hands), f"[Platter] [{Initiator.ToString()}] holds food but has no gloves to place it with"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        if (_Platter.Get_IsFull())
        {
            DoFail(EMars_Interaction_FailReason::PlatterFull);
            return;
        }

        Await_PlaceGrip(_Hands);
        utils_platter::Start_DepositReach(_Platter, _Holder, _Hands);
    }

    // The books are watched before the base ticks the awaited effect: a piece on the books ends the wait in the tick it
    // shows.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_Stage == EMars_Platter_DepositStage::Asked && _Outcome == ECk_SmTaskResult::Running && _Platter.Get_HoldsPiece(_Piece))
        {
            End_AwaitedEffect();
            _Stage = EMars_Platter_DepositStage::OnTheBooks;
        }

        Super::DoTick(InHandle, InDeltaT, InNetContext);

        if (_Stage == EMars_Platter_DepositStage::OnTheBooks && _Outcome == ECk_SmTaskResult::Running)
        { Tick_Books(); }

        return _Outcome;
    }

    // The food and the room are checked as this machine sees them; the deposit is asked of the authority.
    protected void DoAtGrip() override
    {
        const auto Food = _Holder.TryGet_SelectedFood();
        if (ck::Is_NOT_Valid(Food))
        {
            DoFail(EMars_Interaction_FailReason::NoFoodInHand);
            return;
        }

        if (_Platter.Get_IsFull())
        {
            DoFail(EMars_Interaction_FailReason::PlatterFull);
            return;
        }

        const auto WorldItem = Food.Get_PersistentWorldItem();
        FCk_Handle FoodEntity = WorldItem;
        const auto Piece = ck::IsValid(WorldItem) ? FoodEntity.As_FoodPiece(ECk_SanityCheck::UnChecked) : FCk_Handle_FoodPiece();
        if (ck::EnsureIfNot(ck::IsValid(Piece),
            f"[Platter] Food item [{Food.ToString()}] has no world item that is a FoodPiece (world item [{WorldItem.ToString()}])"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        _Piece = Piece;
        _PlatterSerialAtAsk = _Platter.Get_RefusalSerial();
        _Stage = EMars_Platter_DepositStage::Asked;
        if (ck::IsValid(_Dock))
        {
            _DockSerialAtAsk = _Dock.Get_RefusalSerial();
            utils_platter_dock::Request_ActFor(_Dock, _Initiator, EMars_PlatterDock_Action::PlaceFood);
        }
        else
        { utils_platter::Request_DepositFor(_Platter, _Initiator); }

        Await_ReplicatedEffect();
    }

    // A refusal newer than the ask that names this initiator, in the platter's ledger or the dock's.
    protected bool DoTryGet_Refusal(EMars_Interaction_FailReason& OutReason) override
    {
        if (_Stage != EMars_Platter_DepositStage::Asked)
        { return false; }

        if (_Platter.Get_RefusalSerial() > _PlatterSerialAtAsk && _Platter.Get_LastRefused() == _Initiator)
        {
            OutReason = _Platter.Get_LastRefusal();
            return true;
        }

        if (ck::IsValid(_Dock) && _Dock.Get_RefusalSerial() > _DockSerialAtAsk && _Dock.Get_LastRefused() == _Initiator)
        {
            OutReason = _Dock.Get_LastRefusal();
            return true;
        }

        return false;
    }

    // On the books: it lands, or it leaves them (taken by hand while it dropped, or destroyed) before it landed.
    private void Tick_Books()
    {
        if (_Piece.Get_IsGone() == false && _Platter.Get_HasLanded(_Piece))
        {
            _Stage = EMars_Platter_DepositStage::Done;
            _Outcome = ECk_SmTaskResult::Succeeded;
            return;
        }

        if (_Piece.Get_IsGone() == false && _Platter.Get_HoldsPiece(_Piece))
        { return; }

        _Stage = EMars_Platter_DepositStage::Done;
        DoFail(EMars_Interaction_FailReason::LeftTheBooks);
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
    // the platter's world item). The deposit is asked at the reach's Grip (UMars_SmTask_PlaceHeldFood), which checks the
    // food and the room before it asks: holding no food, or a full platter, here is a defect and starts nothing.
    void Start_DepositReach(FCk_Handle_Platter InPlatter, FCk_Handle_Hotbar InHolder, FCk_Handle_FPHands InHands)
    {
        const auto Food = InHolder.TryGet_SelectedFood();
        if (ck::EnsureIfNot(ck::IsValid(Food) && InPlatter.Get_IsFull() == false,
            f"[Platter] Nothing to place on [{InPlatter.ToString()}]: no food in hand, or the platter is full"))
        { return; }

        FCk_Handle PlatterEntity = InPlatter;
        const auto Subject = FMars_FPHands_ReachSubject(PlatterEntity.As_WorldItem().Get_Pickup(), PlatterEntity);
        auto Hands = InHands;
        Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Subject, ECk_Interaction_CompletionPolicy::Instant, EMars_FPHands_ReachKind::Place));
    }
}
