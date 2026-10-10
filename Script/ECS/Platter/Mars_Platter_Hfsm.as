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

// Where a deposit stands once the gloves are at their Grip.
enum EMars_Platter_DepositStage
{
    // Waiting for the place reach's Grip (or nothing to place).
    AtTheGloves,
    // The food's release is asked for: it lands in the World (OnMountSettled) or is refused (OnReleaseRefused).
    Releasing,
    // Released: the platter is asked to load it once it is off the hand node (a piece hanging off a node is one something
    // else took).
    Leaving,
    // The platter is asked to load it: it lands on the tray (OnLoaded) or is refused (OnLoadRefused).
    Loading,
    // The platter took it on its books (queued or settling): it lands (OnLoaded), is refused (OnLoadRefused), or leaves the
    // books before it landed (taken by hand, or gone), which the platter does not answer.
    OnTheBooks,
    // The deposit has its outcome.
    Done
}

// Places the initiator's selected food on the platter the interaction is about (utils_platter::TryGet_PlaceTarget: the
// platter itself, or a dock's docked platter when the dock offers PlaceFood). The gloves carry the food over the
// platter (an FPHands Place reach, utils_platter::Request_DepositHeldFood); at the reach's Grip (UMars_SmTask_ActAtGrip)
// the food's world item is released back to its own holder, and only once that release has landed - the World commit
// (OnMountSettled) and the food off the hand node - is the platter asked to Load its joint, whose drop queue poses it. The
// task ends with the load: it succeeds when the joint lands (OnLoaded) and fails when the platter refuses it (OnLoadRefused:
// the food lies where it was let go) or forgets it before it landed (taken by hand while it dropped, or destroyed: the
// platter answers neither). A refused release (OnReleaseRefused) fails it with the food still in the hands, still on the
// hand node. An interaction this task does not apply to succeeds at once. Fails, the food still in hand, when the
// platter is full, when the gloves refuse the place reach, or when they return or lose the target before the Grip.
class UMars_SmTask_PlaceHeldFood : UMars_SmTask_ActAtGrip
{
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_Hotbar _Holder;
    private FCk_Handle_FPHands _Hands;
    // The food being deposited: its world item and its joint.
    private FCk_Handle_WorldItem _Food;
    private FCk_Handle_FoodPiece _Piece;
    private EMars_Platter_DepositStage _Stage = EMars_Platter_DepositStage::AtTheGloves;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Outcome = ECk_SmTaskResult::Running;
        _Stage = EMars_Platter_DepositStage::AtTheGloves;

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
            DoFail(EMars_Interaction_FailReason::PlatterFull);
            return;
        }

        Await_PlaceGrip(_Hands);
        utils_platter::Request_DepositHeldFood(_Platter, _Holder, _Hands);
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        Super::DoTick(InHandle, InDeltaT, InNetContext);

        if (_Stage == EMars_Platter_DepositStage::Leaving && utils_platter::Get_IsTaken(_Piece) == false)
        { Request_Load(); }
        else if (_Stage == EMars_Platter_DepositStage::Loading || _Stage == EMars_Platter_DepositStage::OnTheBooks)
        { Tick_Books(); }

        return _Outcome;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);
        Unbind_Food();
        Unbind_Platter();
    }

    // The food is released where the gloves carried it; the platter loads it once it is free.
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

        auto WorldItem = Food.Get_PersistentWorldItem();
        FCk_Handle FoodEntity = WorldItem;
        const auto Piece = FoodEntity.As_FoodPiece(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(WorldItem) && ck::IsValid(Piece),
            f"[Platter] Food item [{Food.ToString()}] has no world item that is a FoodPiece (world item [{WorldItem.ToString()}])"))
        {
            _Outcome = ECk_SmTaskResult::Failed;
            return;
        }

        _Food = WorldItem;
        _Piece = Piece;
        _Stage = EMars_Platter_DepositStage::Releasing;
        _Food.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnFoodMountSettled"));
        _Food.BindTo_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnFoodReleaseRefused"));
        _Food.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
    }

    UFUNCTION()
    private void OnFoodMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        if (_Stage != EMars_Platter_DepositStage::Releasing || InMount != EMars_WorldItem_Mount::World)
        { return; }

        Unbind_Food();
        _Stage = EMars_Platter_DepositStage::Leaving;
    }

    UFUNCTION()
    private void OnFoodReleaseRefused(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        if (_Stage != EMars_Platter_DepositStage::Releasing)
        { return; }

        Unbind_Food();
        _Stage = EMars_Platter_DepositStage::Done;
        DoFail(EMars_Interaction_FailReason::ReleaseRefused);
    }

    private void Request_Load()
    {
        _Stage = EMars_Platter_DepositStage::Loading;
        _Platter.BindTo_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnPlatterLoaded"));
        _Platter.BindTo_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnPlatterLoadRefused"));
        _Platter.Request_Load(FMars_Request_Platter_Load(_Piece));
    }

    // Taken on the platter's books, or gone from them before it landed.
    private void Tick_Books()
    {
        const auto IsOnTheBooks = ck::IsValid(_Piece) && _Piece.TryGet_Platter() == _Platter;
        if (_Stage == EMars_Platter_DepositStage::Loading)
        {
            if (IsOnTheBooks)
            { _Stage = EMars_Platter_DepositStage::OnTheBooks; }

            return;
        }

        if (IsOnTheBooks)
        { return; }

        Unbind_Platter();
        _Stage = EMars_Platter_DepositStage::Done;
        DoFail(EMars_Interaction_FailReason::LeftTheBooks);
    }

    UFUNCTION()
    private void OnPlatterLoaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        if (Get_IsLoading() == false || InPiece != _Piece)
        { return; }

        Unbind_Platter();
        _Stage = EMars_Platter_DepositStage::Done;
        _Outcome = ECk_SmTaskResult::Succeeded;
    }

    // The food was released already: it lies where the gloves let it go.
    UFUNCTION()
    private void OnPlatterLoadRefused(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece, EMars_Platter_LoadRefusal InRefusal)
    {
        if (Get_IsLoading() == false || InPiece != _Piece)
        { return; }

        Unbind_Platter();
        _Stage = EMars_Platter_DepositStage::Done;
        DoFail(EMars_Interaction_FailReason::LoadRefused);
    }

    private bool Get_IsLoading() const
    {
        return _Stage == EMars_Platter_DepositStage::Loading || _Stage == EMars_Platter_DepositStage::OnTheBooks;
    }

    private void Unbind_Food()
    {
        if (ck::Is_NOT_Valid(_Food))
        { return; }

        _Food.UnbindFrom_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnFoodMountSettled"));
        _Food.UnbindFrom_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnFoodReleaseRefused"));
    }

    private void Unbind_Platter()
    {
        if (ck::Is_NOT_Valid(_Platter))
        { return; }

        _Platter.UnbindFrom_OnLoaded(FMars_Delegate_Platter_OnLoaded(this, n"OnPlatterLoaded"));
        _Platter.UnbindFrom_OnLoadRefused(FMars_Delegate_Platter_OnLoadRefused(this, n"OnPlatterLoadRefused"));
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
    // the platter's world item). The food is let go at the reach's Grip (UMars_SmTask_PlaceHeldFood), which checks the food
    // and the room before it asks: holding no food, or a full platter, here is a defect and starts nothing.
    void Request_DepositHeldFood(FCk_Handle_Platter InPlatter, FCk_Handle_Hotbar InHolder, FCk_Handle_FPHands InHands)
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
