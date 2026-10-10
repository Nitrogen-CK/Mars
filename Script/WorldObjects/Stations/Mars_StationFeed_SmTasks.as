// The shared control layer of a feeding station (a station whose entity carries a CookingFeed: the cooking stations, and
// the cutting station, whose feed brings a joint to its board): tasks the station's own state machine adds beside its
// kernel's. They run on the STATION entity (context = the station) and read its operator and its docks; they issue
// CookingFeed requests, hand each release (a piece the feed carried off the source platter) to the station's admission
// inbox, ask the station's kernel to take its finished pieces out through the station's take-out contract, and register
// the operator's add-food and take-out rows. They never name the kernel: whichever one the station composed receives. The
// feed itself gives back every piece it took and nobody admitted; the kernel lands what it hands back on the docked
// finished tray and takes back what the tray refuses.
//
//   Idle      tasks: StationFeed_Source, StationFeed_Bridge
//   Operated  tasks: StationFeed_Source, StationFeed_OperatorInput (Tick), StationFeed_Bridge, StationFeed_OperatorHints
//                    (Tick), StationFeed_TakeOutInput (Tick, a station whose kernel hands pieces back: Searing, Fry,
//                    Tumbler)

// The feed draws from whatever platter has landed on the station's input dock: set on enter (only a platter that has
// arrived), and again on every arrival and undock (an undock leaves the feed unsourced, which cancels a transfer in
// flight). A platter still travelling onto the dock is no source yet. The bindings live as long as the state. No feed or no
// input dock on the context (a composition that failed and already ensured; a station without a dock) = the feed stays
// unsourced.
class UMars_SmTask_StationFeed_Source : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_PlatterDock _InputDock;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Feed = StationEntity.As_CookingFeed(ECk_SanityCheck::UnChecked);
        _InputDock = utils_platter_dock::Find_OnStation(StationEntity, EMars_PlatterDock_Role::Input);
        if (ck::Is_NOT_Valid(_Feed) || ck::Is_NOT_Valid(_InputDock))
        { return; }

        _InputDock.BindTo_OnArrived(FMars_Delegate_PlatterDock_OnArrived(this, n"OnInputArrived"));
        _InputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnInputUndocked"));
        const auto Source = _InputDock.Get_HasArrived() ? _InputDock.Get_Platter() : FCk_Handle_Platter();
        _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(Source));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_InputDock))
        {
            _InputDock.UnbindFrom_OnArrived(FMars_Delegate_PlatterDock_OnArrived(this, n"OnInputArrived"));
            _InputDock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnInputUndocked"));
        }

        _Feed = FCk_Handle_CookingFeed();
        _InputDock = FCk_Handle_PlatterDock();
    }

    UFUNCTION()
    private void OnInputArrived(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (ck::IsValid(_Feed))
        { _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(InPlatter)); }
    }

    UFUNCTION()
    private void OnInputUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (ck::IsValid(_Feed))
        { _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(FCk_Handle_Platter())); }
    }
}

// The operator's add-food presses, read off its InputIntents: each fresh activation of the StationAddFood row is one
// BeginTransfer, which the feed refuses while the hand is busy or the source is missing or empty. A station may shut its
// own gate on the edge (a subclass overrides Get_CanBeginTransfer): the press still goes to the feed, gated Shut, and the
// feed refuses it StationGate (OnTransferRefused). Every edge is consumed whether or not it is taken (nothing is queued),
// and the seen frame is seeded on enter, so a press held from before the station was taken never counts. No operator
// intents (headless) = nothing to read.
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

        const auto Gate = Get_CanBeginTransfer() ? EMars_CookingFeed_StationGate::Open : EMars_CookingFeed_StationGate::Shut;
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer(Gate));
        return ECk_SmTaskResult::Running;
    }

    // The operator leaving cancels the transfer; the feed decides what that means: a hand still reaching for or grasping its
    // piece stops (a piece already taken off the platter goes back onto it), and a transfer past its grasp is committed and
    // lands through the bridge running in every state, so nothing strands either way.
    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Feed))
        { _Feed.Request_Cancel(FMars_Request_CookingFeed_Cancel()); }

        _Feed = FCk_Handle_CookingFeed();
        _Intents = FCk_Handle_InputIntents();
        _SeenAddFoodFrame.Reset();
    }

    // The station's own gate on a fresh press, ahead of the feed's (a tumbler refuses while its hatch is shut).
    protected bool Get_CanBeginTransfer() const { return true; }
}

// Hands each release to whichever kernel receives at the station, through the station's admission inbox
// (utils_cooking_feed::Request_Admit), and forwards that kernel's one answer (the station's OnAdmission) back to the feed.
// The feed itself takes the piece off its platter at the grasp; a release whose piece is still on it (its unload had not
// landed by the release) goes to the inbox only on that platter's OnUnloaded (a piece another ledger holds is no kernel's
// to take), unless the feed has given the release up by then; a release with no piece, or one already off any platter, goes
// at once. A station no kernel receives at has its releases refused, so the hand carries, the piece goes back
// and the hand returns. A rejected piece is the feed's to put back (it does so as it takes the answer); an admitted one is
// the kernel's, its pickup's Ledger claim with it. The bridge runs in every state of the station, so a transfer in flight
// completes whoever operates: a bridge entering while the feed awaits an admission takes that release over (and its
// unload, if the piece is still coming off), and a forwarded piece is always answered through a bridge. The bindings live
// as long as the state.
class UMars_SmTask_StationFeed_Bridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Station;
    private FCk_Handle_CookingFeed _Feed;
    // The release in flight, from OnReleaseRequested until its admission answer.
    private TOptional<FMars_CookingFeed_Release> _Release;
    // The platter the released piece is still coming off (the feed's unload), until its OnUnloaded.
    private FCk_Handle_Platter _UnloadingFrom;

    // No feed on the context (a composition that failed and already ensured) = nothing to bridge.
    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = ck::Ctx(InHandle);
        _Feed = _Station.As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Feed))
        { return; }

        _Feed.BindTo_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested"));
        if (utils_cooking_feed::Get_IsAdmitting(_Station))
        { utils_cooking_feed::BindTo_OnAdmission(_Station, FMars_Delegate_StationAdmission_OnAdmission(this, n"OnAdmission")); }

        Resume_InFlight();
    }

    // Nothing is cancelled or put back here: the next state's bridge takes the release in flight over.
    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Station))
        { utils_cooking_feed::UnbindFrom_OnAdmission(_Station, FMars_Delegate_StationAdmission_OnAdmission(this, n"OnAdmission")); }

        Unwatch_Platter();
        _Release.Reset();

        if (ck::IsValid(_Feed))
        { _Feed.UnbindFrom_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested")); }

        _Station = FCk_Handle();
        _Feed = FCk_Handle_CookingFeed();
    }

    UFUNCTION()
    private void OnReleaseRequested(FCk_Handle_CookingFeed InFeed, FMars_CookingFeed_Release InRelease)
    {
        Unwatch_Platter();
        _Release = TOptional<FMars_CookingFeed_Release>(InRelease);

        auto Platter = InRelease.Piece.TryGet_Platter();
        if (ck::Is_NOT_Valid(Platter))
        {
            Forward_Release(InRelease);
            return;
        }

        _UnloadingFrom = Platter;
        _UnloadingFrom.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded"));
    }

    // A release the previous state's bridge took and nobody has answered yet (the feed still awaits its admission): this
    // bridge sees it through. A piece still coming off its platter is watched as OnReleaseRequested would; one already off
    // it was forwarded, and its answer comes here.
    private void Resume_InFlight()
    {
        if (_Feed.Get_Phase() != EMars_CookingFeed_Phase::AwaitAdmission)
        { return; }

        const auto Release = _Feed.Get_PendingRelease();
        _Release = TOptional<FMars_CookingFeed_Release>(Release);

        auto Platter = Release.Piece.TryGet_Platter();
        if (ck::Is_NOT_Valid(Platter))
        { return; }

        _UnloadingFrom = Platter;
        _UnloadingFrom.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded"));
    }

    // Off the platter at its world pose: now a kernel may take it, unless the feed gave the release up meanwhile (a new source,
    // or its admission budget ran out) and has already sent the piece back.
    UFUNCTION()
    private void OnUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        if (_Release.IsSet() == false || InPiece != _Release.GetValue().Piece)
        { return; }

        const auto Release = _Release.GetValue();
        Unwatch_Platter();
        if (ck::IsValid(_Feed) && _Feed.Get_IsAwaiting(Release.PieceId))
        {
            Forward_Release(Release);
            return;
        }

        _Release.Reset();
    }

    UFUNCTION()
    private void OnAdmission(FCk_Handle InStation, FMars_CookingFeed_PieceId InPieceId, EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        Answer(InPieceId, InAdmission, InReason);
    }

    // A kernel's answer goes to the feed as it is; the feed honours it only for the piece it is awaiting, and puts a rejected
    // piece back itself. The release's own answer ends it here.
    private void Answer(const FMars_CookingFeed_PieceId& InPieceId, EMars_CookingFeed_Admission InAdmission, const FString& InReason)
    {
        if (ck::Is_NOT_Valid(_Feed))
        { return; }

        if (_Release.IsSet() && _Release.GetValue().PieceId.Get_IsSame(InPieceId))
        { _Release.Reset(); }

        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(InPieceId, InAdmission, InReason));
    }

    // Into the station's inbox; a station no kernel receives at refuses the release here.
    private void Forward_Release(const FMars_CookingFeed_Release& InRelease)
    {
        if (utils_cooking_feed::Request_Admit(_Station, InRelease))
        { return; }

        Answer(InRelease.PieceId, EMars_CookingFeed_Admission::Rejected, "no receiver kernel");
    }

    private void Unwatch_Platter()
    {
        if (ck::IsValid(_UnloadingFrom))
        { _UnloadingFrom.UnbindFrom_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded")); }

        _UnloadingFrom = FCk_Handle_Platter();
    }
}

// The operator's take-out presses. Each fresh activation of Interact_Secondary asks the station's kernel, through the
// station's take-out contract (utils_cooking_feed::Request_StationTakeOut), to hand every piece that is ready onto the
// docked finished tray, no more than it has room for (none with no tray docked): the kernel loads them, takes back what the
// tray refuses, and refuses a take-out that hands nothing back (OnTakeOutRefused: NoRoom, NothingReady), which the station's
// label says. The press is seeded on enter, so a hold from before the station was taken never counts. No kernel that hands
// pieces back (no take-out readout on the station) or no output dock on the context (a composition that failed and already
// ensured) = nothing to take out; no operator intents (headless) = no presses.
class UMars_SmTask_StationFeed_TakeOutInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Station;
    private FCk_Handle_PlatterDock _OutputDock;
    private FCk_Handle_InputIntents _Intents;
    // The activation frame of the Interact_Secondary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenTakeOutFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = ck::Ctx(InHandle);
        _OutputDock = utils_platter_dock::Find_OnStation(_Station, EMars_PlatterDock_Role::Output);
        _Intents = FCk_Handle_InputIntents();
        if (ck::Is_NOT_Valid(_OutputDock) || utils_cooking_feed::Get_HasTakeOut(_Station) == false)
        { return; }

        auto Station = _Station.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenTakeOutFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_OutputDock) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto TakeOutFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
        if (TakeOutFrame != _SeenTakeOutFrame)
        {
            _SeenTakeOutFrame = TakeOutFrame;
            if (TakeOutFrame.IsSet())
            { Request_TakeOut(); }
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = FCk_Handle();
        _OutputDock = FCk_Handle_PlatterDock();
        _Intents = FCk_Handle_InputIntents();
        _SeenTakeOutFrame.Reset();
    }

    // Every ready piece onto the docked tray, capped at its free room: no tray caps it at none.
    private void Request_TakeOut()
    {
        const auto Tray = _OutputDock.Get_Platter();
        const auto Room = ck::IsValid(Tray) ? Tray.Get_FreeCount() : 0;
        utils_cooking_feed::Request_StationTakeOut(_Station, FMars_Request_StationTakeOut(Room, Tray));
    }
}

// The operator's rows while operating. The add-food row (IA_StationAddFood): "add food - N left" while the hand is idle,
// "adding food... - N left" while it is busy, the station's own refusal while it would refuse a press (a subclass's
// TryGet_StationRefusal: the cutting station's "board busy"), "no platter" without a source, "platter empty" once nothing
// is left on it, "settling - N left" while the pile re-settles (a press then is refused until a piece freezes);
// registered once on enter under the Operating state's owner key (its leave-unregister clears it) and re-texted on every
// stock and phase edge (the display drains registers before unregisters, so the row is never re-registered). The take-out
// row (IA_Interact_Secondary), on a station whose kernel hands pieces back (it keeps the station's take-out readout) and
// only while a finished tray is docked: "take out - N ready", re-texted on the frame the readout's count changes. An
// operator without a display (headless) gets no rows.
class UMars_SmTask_StationFeed_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private const FName k_OwnerKey = n"Station";
    private const int32 k_AddFoodSortOrder = 6;
    private const int32 k_TakeOutSortOrder = 9;

    private FCk_Handle _Station;
    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _AddFoodRow;
    private FCk_Handle_PlatterDock _OutputDock;
    // Registered while a finished tray is docked.
    private FCk_Handle_ActionHintRow _TakeOutRow;
    // The ready count the take-out row last said.
    private int32 _ShownTakeable = 0;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Display = FCk_Handle_ActionHintDisplay();

        _Station = ck::Ctx(InHandle);
        auto Station = _Station.As_Station();
        auto Operator = Station.Get_Operator();
        _Display = Operator.As_ActionHintDisplay(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Display))
        { return; }

        _Feed = _Station.As_CookingFeed();
        _AddFoodRow = _Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_StationAddFood, Get_AddFoodText(), k_AddFoodSortOrder, k_OwnerKey));
        _Feed.BindTo_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnStockChanged"));
        _Feed.BindTo_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged"));

        Watch_TakeOut();
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_TakeOutRow) && utils_cooking_feed::Get_Takeable(_Station).Num() != _ShownTakeable)
        { Refresh_TakeOutRow(); }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Feed))
        {
            _Feed.UnbindFrom_OnStockChanged(FMars_Delegate_CookingFeed_OnStockChanged(this, n"OnStockChanged"));
            _Feed.UnbindFrom_OnPhaseChanged(FMars_Delegate_CookingFeed_OnPhaseChanged(this, n"OnPhaseChanged"));
        }

        Unwatch_TakeOut();

        if (ck::IsValid(_Display) && ck::IsValid(_AddFoodRow))
        { _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_AddFoodRow)); }

        if (ck::IsValid(_Display) && ck::IsValid(_TakeOutRow))
        { _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_TakeOutRow)); }

        _Station = FCk_Handle();
        _Feed = FCk_Handle_CookingFeed();
        _Display = FCk_Handle_ActionHintDisplay();
        _AddFoodRow = FCk_Handle_ActionHintRow();
        _TakeOutRow = FCk_Handle_ActionHintRow();
        _ShownTakeable = 0;
    }

    // The take-out row follows the output dock. A station without an output dock or a kernel that hands pieces back has no
    // take-out row.
    private void Watch_TakeOut()
    {
        _OutputDock = utils_platter_dock::Find_OnStation(_Station, EMars_PlatterDock_Role::Output);
        if (ck::Is_NOT_Valid(_OutputDock) || utils_cooking_feed::Get_HasTakeOut(_Station) == false)
        {
            _OutputDock = FCk_Handle_PlatterDock();
            return;
        }

        _OutputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
        _OutputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));

        if (ck::IsValid(_OutputDock.Get_Platter()))
        { Register_TakeOut(); }
    }

    private void Unwatch_TakeOut()
    {
        if (ck::IsValid(_OutputDock))
        {
            _OutputDock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
            _OutputDock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        }

        _OutputDock = FCk_Handle_PlatterDock();
    }

    private void Register_TakeOut()
    {
        if (ck::IsValid(_TakeOutRow))
        { return; }

        _ShownTakeable = utils_cooking_feed::Get_Takeable(_Station).Num();
        _TakeOutRow = _Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_Interact_Secondary, Get_TakeOutText(), k_TakeOutSortOrder, k_OwnerKey));
    }

    private void Refresh_TakeOutRow()
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_TakeOutRow))
        { return; }

        _ShownTakeable = utils_cooking_feed::Get_Takeable(_Station).Num();
        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_TakeOutRow, Get_TakeOutText()));
    }

    private FText Get_TakeOutText() const
    {
        return FText::FromString(f"take out - {_ShownTakeable} ready");
    }

    UFUNCTION()
    private void OnOutputDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Register_TakeOut();
    }

    UFUNCTION()
    private void OnOutputUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (ck::Is_NOT_Valid(_TakeOutRow))
        { return; }

        _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_TakeOutRow));
        _TakeOutRow = FCk_Handle_ActionHintRow();
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

    // Also for a subclass, on the edges of its own refusal.
    protected void Refresh_AddFoodRow()
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_AddFoodRow))
        { return; }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_AddFoodRow, Get_AddFoodText()));
    }

    // Why the station's own gate would refuse a press now (its OperatorInput's Get_CanBeginTransfer); unset = it would not.
    protected TOptional<FString> TryGet_StationRefusal() const { return TOptional<FString>(); }

    private FText Get_AddFoodText() const
    {
        const auto Available = _Feed.Get_Available();
        if (_Feed.Get_IsBusy())
        { return FText::FromString(f"adding food... - {Available} left"); }

        const auto StationRefusal = TryGet_StationRefusal();
        if (StationRefusal.IsSet())
        { return FText::FromString(StationRefusal.GetValue()); }

        if (_Feed.Get_IsSourced() == false)
        { return FText::FromString("no platter"); }

        if (Available <= 0)
        { return FText::FromString("platter empty"); }

        if (_Feed.Get_IsSettling())
        { return FText::FromString(f"settling - {Available} left"); }

        return FText::FromString(f"add food - {Available} left");
    }
}
