// The shared control layer of a feeding station (a cooking station whose entity carries a CookingFeed): tasks the station's
// own state machine adds beside its kernel's. They run on the STATION entity (context = the station) and read its operator;
// they only issue CookingFeed requests and register the operator's add-food row.
//
//   Idle      task: StationFeed_ResetOnEnter (before the kernel's own reset: the generation bump comes first)
//   Operated  tasks: StationFeed_OperatorInput (Tick), StationFeed_Bridge, StationFeed_OperatorHints

// A new attempt: every older piece goes stale and the platter refills. No feed on the context yet (the SM can enter before
// the entity script composes it) = nothing to reset.
class UMars_SmTask_StationFeed_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Feed = ck::Ctx(InHandle).As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Feed))
        { return; }

        Feed.Request_Reset(FMars_Request_CookingFeed_Reset());
    }
}

// The operator's add-food presses, read off its InputIntents: each fresh activation of the StationAddFood row is one
// BeginTransfer, which the feed refuses while the hand is busy or the platter is empty. Every edge is consumed whether or not
// the feed takes it (nothing is queued), and the seen frame is seeded on enter, so a press held from before the station was
// taken never counts. No operator intents (headless) = nothing to read.
class UMars_SmTask_StationFeed_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_InputIntents _Intents;
    // The activation frame of the StationAddFood hold last seen; unset while it is not held.
    private TOptional<int32> _SeenAddFoodFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Feed = StationEntity.As_CookingFeed();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenAddFoodFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_StationAddFood);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Feed) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto AddFoodFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_StationAddFood);
        if (AddFoodFrame == _SeenAddFoodFrame)
        { return ECk_SmTaskResult::Running; }

        _SeenAddFoodFrame = AddFoodFrame;
        if (AddFoodFrame.IsSet() == false)
        { return ECk_SmTaskResult::Running; }

        ck::Trace(f"[StationFeed] [{_Feed.ToString()}] operator pressed add food ({_Feed.Get_Phase() :n}, {_Feed.Get_Available()} left)");
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Feed = FCk_Handle_CookingFeed();
        _Intents = FCk_Handle_InputIntents();
        _SeenAddFoodFrame.Reset();
    }
}

// Routes each release to the cooking kernel on the station by its typed handle (Searing, then Fry) and forwards that
// kernel's admission answer back to the feed; leaving mid-transfer cancels it, so no reservation outlives the operator (the
// Idle state's reset follows anyway). Both bindings live exactly as long as the Operated state.
class UMars_SmTask_StationFeed_Bridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Station;
    private FCk_Handle_CookingFeed _Feed;
    // Invalid on a station without a Searing.
    private FCk_Handle_Searing _Searing;
    // Invalid on a station without a Fry.
    private FCk_Handle_Fry _Fry;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = ck::Ctx(InHandle);
        _Feed = _Station.As_CookingFeed();
        _Feed.BindTo_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested"));

        _Searing = _Station.As_Searing(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Searing))
        { _Searing.BindTo_OnPieceAdmission(FMars_Delegate_Searing_OnPieceAdmission(this, n"OnSearingPieceAdmission")); }

        _Fry = _Station.As_Fry(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Fry))
        { _Fry.BindTo_OnPieceAdmission(FMars_Delegate_Fry_OnPieceAdmission(this, n"OnFryPieceAdmission")); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Searing))
        { _Searing.UnbindFrom_OnPieceAdmission(FMars_Delegate_Searing_OnPieceAdmission(this, n"OnSearingPieceAdmission")); }

        if (ck::IsValid(_Fry))
        { _Fry.UnbindFrom_OnPieceAdmission(FMars_Delegate_Fry_OnPieceAdmission(this, n"OnFryPieceAdmission")); }

        if (ck::IsValid(_Feed))
        {
            _Feed.UnbindFrom_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested"));
            if (_Feed.Get_IsBusy())
            { _Feed.Request_Cancel(FMars_Request_CookingFeed_Cancel()); }
        }

        _Station = FCk_Handle();
        _Feed = FCk_Handle_CookingFeed();
        _Searing = FCk_Handle_Searing();
        _Fry = FCk_Handle_Fry();
    }

    UFUNCTION()
    private void OnReleaseRequested(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease)
    {
        Forward_Release(InRelease);
    }

    // The Searing kernel's answer goes to the feed as it is; the feed honours it only for the piece it is awaiting.
    UFUNCTION()
    private void OnSearingPieceAdmission(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        if (ck::Is_NOT_Valid(_Feed))
        { return; }

        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(InPieceId, InAdmission, InReason));
    }

    // The Fry kernel's answer goes to the feed as it is, as the Searing one's does.
    UFUNCTION()
    private void OnFryPieceAdmission(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        if (ck::Is_NOT_Valid(_Feed))
        { return; }

        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(InPieceId, InAdmission, InReason));
    }

    // Searing, else Fry, admits through its AddPiece (answered by its OnPieceAdmission above). A station with neither has
    // its releases refused, so the hand carries, restores the slot and returns, and no stock is spent.
    private void Forward_Release(const FMars_CookingFeed_Release& InRelease)
    {
        if (ck::IsValid(_Searing))
        {
            _Searing.Request_AddPiece(FMars_Request_Searing_AddPiece(InRelease));
            return;
        }

        if (ck::IsValid(_Fry))
        {
            _Fry.Request_AddPiece(FMars_Request_Fry_AddPiece(InRelease));
            return;
        }

        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(
            InRelease.PieceId, EMars_CookingFeed_Admission::Rejected, "no receiver kernel"));
    }
}

// The operator's add-food row while operating (IA_StationAddFood): "add food · N left" while the hand is idle,
// "adding food… · N left" while it is busy, "platter empty" once nothing is left. Registered once on enter under the
// Operating state's owner key (its leave-unregister clears it) and re-texted on every stock and phase edge (the display
// drains registers before unregisters, so the row is never re-registered). An operator without a display (headless) gets
// no row.
class UMars_SmTask_StationFeed_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Station";
    private const int32 k_AddFoodSortOrder = 6;

    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _AddFoodRow;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Display = FCk_Handle_ActionHintDisplay();

        auto StationEntity = ck::Ctx(InHandle);
        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Display = Operator.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Feed = StationEntity.As_CookingFeed();
        _AddFoodRow = _Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_StationAddFood, Get_AddFoodText(), k_AddFoodSortOrder, k_OwnerKey));
        _Feed.BindTo_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnStockChanged"));
        _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Feed))
        {
            _Feed.UnbindFrom_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnStockChanged"));
            _Feed.UnbindFrom_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged"));
        }

        if (ck::IsValid(_Display) && ck::IsValid(_AddFoodRow))
        { _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_AddFoodRow)); }

        _Feed = FCk_Handle_CookingFeed();
        _Display = FCk_Handle_ActionHintDisplay();
        _AddFoodRow = FCk_Handle_ActionHintRow();
    }

    UFUNCTION()
    private void OnStockChanged(FCk_Handle_CookingFeed InFeed, int32 InAvailable, int32 InAdmitted)
    {
        Refresh_AddFoodRow();
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_CookingFeed InFeed, EMars_CookingFeed_Phase InPhase)
    {
        Refresh_AddFoodRow();
    }

    private void Refresh_AddFoodRow()
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_AddFoodRow))
        { return; }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_AddFoodRow, Get_AddFoodText()));
    }

    private FText Get_AddFoodText() const
    {
        const auto Available = _Feed.Get_Available();
        if (_Feed.Get_IsBusy())
        { return FText::FromString(f"adding food… · {Available} left"); }

        if (Available <= 0)
        { return FText::FromString("platter empty"); }

        return FText::FromString(f"add food · {Available} left");
    }
}
