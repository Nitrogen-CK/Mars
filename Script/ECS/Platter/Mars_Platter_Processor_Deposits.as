// Advances the deposits the drain took on the books (FMars_Fragment_Platter_Deposits), every frame, oldest first, on the
// authority's platters that have any:
//   Asked:     the initiator's selected food (Hotbar.TryGet_SelectedFood) is let go: refused NoFoodInHand when it holds
//              none, PlatterFull on a full platter, TransferRefused when the food is in a deposit already (its
//              FMars_Fragment_Platter_Depositing mark); a food whose world item is no FoodPiece is a defect (an ensure,
//              refused NoFoodInHand). Otherwise the food is marked for this platter, its world item's OnMountSettled and
//              OnReleaseRefused are watched here and its release is asked for, with no velocity.
//   Releasing: answered by the world item: settled World, the deposit is Leaving; a refused release refuses it
//              ReleaseRefused.
//   Leaving:   the piece gone refuses it LeftTheBooks; a piece still hanging off a node waits (the platter's lease check
//              forgets a queued piece something holds); a free one is loaded on this platter.
//   Loading:   answered by the drain, which accepts the load (the deposit ends) or refuses it (LoadRefused).
// A refused deposit leaves the books and its mark, and advances the platter's replicated ledger naming the initiator
// (utils_platter::Close_Deposit). The fragment goes when the last deposit does.
class UMars_Processor_Platter_Deposits : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _RunAfter.Add(n"/Script/Angelscript.Mars_Processor_Platter_HandleRequests");

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Platter);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Platter_Deposits& InDeposits)
    {
        auto Platter = InHandle.As_Platter();
        TArray<FMars_Platter_Deposit> Pending = InDeposits.Pending;

        // InDeposits is not read past this line: a release or a load adds a fragment to another entity or to this one.
        TArray<FMars_Platter_Deposit> Kept;
        TArray<FMars_Platter_Deposit> Refused;
        TArray<EMars_Interaction_FailReason> Reasons;
        for (const auto& Entry : Pending)
        {
            auto Deposit = Entry;
            const auto Refusal = Advance(Platter, Deposit);
            if (Refusal.IsSet())
            {
                Refused.Add(Deposit);
                Reasons.Add(Refusal.GetValue());
                continue;
            }

            Kept.Add(Deposit);
        }

        InHandle.Get_Fragment(FMars_Fragment_Platter_Deposits).Pending = Kept;
        if (Kept.Num() == 0)
        { InHandle.Request_TryRemove(FMars_Fragment_Platter_Deposits); }

        for (int32 Index = 0; Index < Refused.Num(); ++Index)
        { utils_platter::Close_Deposit(Platter, Refused[Index], TOptional<EMars_Interaction_FailReason>(Reasons[Index])); }
    }

    // Moves InOutDeposit on by one step where it can; the reason when it is refused.
    private TOptional<EMars_Interaction_FailReason> Advance(FCk_Handle_Platter& InPlatter, FMars_Platter_Deposit& InOutDeposit)
    {
        if (InOutDeposit.Step == EMars_Platter_DepositStep::Asked)
        { return Release(InPlatter, InOutDeposit); }

        if (InOutDeposit.Step != EMars_Platter_DepositStep::Leaving)
        { return TOptional<EMars_Interaction_FailReason>(); }

        if (InOutDeposit.Piece.Get_IsGone())
        { return TOptional<EMars_Interaction_FailReason>(EMars_Interaction_FailReason::LeftTheBooks); }

        if (utils_platter::Get_IsTaken(InOutDeposit.Piece))
        { return TOptional<EMars_Interaction_FailReason>(); }

        InOutDeposit.Step = EMars_Platter_DepositStep::Loading;
        InPlatter.Request_Load(FMars_Request_Platter_Load(InOutDeposit.Piece));
        return TOptional<EMars_Interaction_FailReason>();
    }

    // The initiator's food, judged as the authority holds it now: the initiating machine asked its own copy, which may be a
    // round trip stale.
    private TOptional<EMars_Interaction_FailReason> Release(FCk_Handle_Platter& InPlatter, FMars_Platter_Deposit& InOutDeposit)
    {
        const auto Hotbar = InOutDeposit.Initiator.As_Hotbar(ECk_SanityCheck::UnChecked);
        const auto Food = ck::IsValid(Hotbar) ? Hotbar.TryGet_SelectedFood() : FCk_Handle_Item();
        if (ck::Is_NOT_Valid(Food))
        { return TOptional<EMars_Interaction_FailReason>(EMars_Interaction_FailReason::NoFoodInHand); }

        if (InPlatter.Get_IsFull())
        { return TOptional<EMars_Interaction_FailReason>(EMars_Interaction_FailReason::PlatterFull); }

        auto WorldItem = Food.Get_PersistentWorldItem();
        FCk_Handle FoodEntity = WorldItem;
        const auto Piece = ck::IsValid(WorldItem) ? FoodEntity.As_FoodPiece(ECk_SanityCheck::UnChecked) : FCk_Handle_FoodPiece();
        if (ck::EnsureIfNot(ck::IsValid(Piece),
            f"[Platter] Food item [{Food.ToString()}] has no world item that is a FoodPiece (world item [{WorldItem.ToString()}])"))
        { return TOptional<EMars_Interaction_FailReason>(EMars_Interaction_FailReason::NoFoodInHand); }

        // Another live platter's deposit of this food refuses this one. A mark left by a platter that ended mid-deposit is
        // nobody's: this deposit takes it over.
        if (FoodEntity.Has_Fragment(FMars_Fragment_Platter_Depositing))
        {
            auto& Mark = FoodEntity.Get_Fragment(FMars_Fragment_Platter_Depositing);
            if (utils_foodpiece::Get_IsLiveEntity(Mark.Platter))
            { return TOptional<EMars_Interaction_FailReason>(EMars_Interaction_FailReason::TransferRefused); }

            Mark.Platter = InPlatter;
        }
        else
        { FoodEntity.Add_Fragment(FMars_Fragment_Platter_Depositing(InPlatter)); }

        InOutDeposit.Food = WorldItem;
        InOutDeposit.Piece = Piece;
        InOutDeposit.Step = EMars_Platter_DepositStep::Releasing;

        WorldItem.UnbindFrom_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnFoodMountSettled"));
        WorldItem.BindTo_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnFoodMountSettled"));
        WorldItem.UnbindFrom_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnFoodReleaseRefused"));
        WorldItem.BindTo_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnFoodReleaseRefused"));
        WorldItem.Request_Release(FMars_Request_WorldItem_Release(FVector::ZeroVector, FVector::ZeroVector));
        return TOptional<EMars_Interaction_FailReason>();
    }

    // The release landed in the World: the deposit waits for the food to be free.
    UFUNCTION()
    private void OnFoodMountSettled(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_Mount InMount, FCk_Handle InCarrier)
    {
        if (InMount != EMars_WorldItem_Mount::World)
        { return; }

        auto Platter = TryGet_ReleasingPlatter(InWorldItem);
        if (ck::Is_NOT_Valid(Platter))
        { return; }

        auto Food = InWorldItem;
        Stop_Watching(Food);
        auto& Deposits = Platter.Get_Fragment(FMars_Fragment_Platter_Deposits);
        for (auto& Deposit : Deposits.Pending)
        {
            if (Deposit.Food == InWorldItem && Deposit.Step == EMars_Platter_DepositStep::Releasing)
            { Deposit.Step = EMars_Platter_DepositStep::Leaving; }
        }
    }

    // The food stayed in the hands.
    UFUNCTION()
    private void OnFoodReleaseRefused(FCk_Handle_WorldItem InWorldItem, EMars_WorldItem_ReleaseRefusal InReason)
    {
        auto Platter = TryGet_ReleasingPlatter(InWorldItem);
        if (ck::Is_NOT_Valid(Platter))
        { return; }

        auto Food = InWorldItem;
        Stop_Watching(Food);
        const auto Deposit = utils_platter::TryGet_Deposit(Platter, InWorldItem);
        utils_platter::Close_Deposit(Platter, Deposit.GetValue(), TOptional<EMars_Interaction_FailReason>(EMars_Interaction_FailReason::ReleaseRefused));
    }

    // The platter InWorldItem's mark names, while that platter's deposit of it is Releasing; invalid otherwise. A mark naming
    // a platter that is gone is removed here: nothing is left to answer.
    private FCk_Handle_Platter TryGet_ReleasingPlatter(const FCk_Handle_WorldItem& InWorldItem)
    {
        FCk_Handle FoodEntity = InWorldItem;
        if (ck::Is_NOT_Valid(FoodEntity) || FoodEntity.Has_Fragment(FMars_Fragment_Platter_Depositing) == false)
        { return FCk_Handle_Platter(); }

        const auto Platter = FoodEntity.Get_Fragment(FMars_Fragment_Platter_Depositing).Platter;
        const auto IsGone = ck::Is_NOT_Valid(Platter)
            || utils_entity_lifetime::Get_IsPendingDestroy(Platter, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
        if (IsGone)
        {
            FoodEntity.Request_TryRemove(FMars_Fragment_Platter_Depositing);
            return FCk_Handle_Platter();
        }

        const auto Deposit = utils_platter::TryGet_Deposit(Platter, InWorldItem);
        if (Deposit.IsSet() == false || Deposit.GetValue().Step != EMars_Platter_DepositStep::Releasing)
        { return FCk_Handle_Platter(); }

        return Platter;
    }

    private void Stop_Watching(FCk_Handle_WorldItem& InWorldItem)
    {
        InWorldItem.UnbindFrom_OnMountSettled(FMars_Delegate_WorldItem_OnMountSettled(this, n"OnFoodMountSettled"));
        InWorldItem.UnbindFrom_OnReleaseRefused(FMars_Delegate_WorldItem_OnReleaseRefused(this, n"OnFoodReleaseRefused"));
    }
}
