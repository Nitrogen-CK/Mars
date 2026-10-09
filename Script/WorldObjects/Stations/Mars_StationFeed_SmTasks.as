// The shared control layer of a feeding station (a cooking station whose entity carries a CookingFeed): tasks the station's
// own state machine adds beside its kernel's. They run on the STATION entity (context = the station) and read its operator
// and its docks; they issue CookingFeed requests, unload and reload the source platter's pieces around a release, take the
// cooking kernel's finished pieces out onto the docked tray, and register the operator's add-food and take-out rows.
//
//   Idle      tasks: StationFeed_ResetOnEnter (an idle hand only; before the kernel's own reset: the generation bump
//                    comes first),
//                    StationFeed_Source, StationFeed_Bridge, StationFeed_TakeOutBridge (Searing, Fry)
//   Operated  tasks: StationFeed_Source, StationFeed_OperatorInput (Tick), StationFeed_Bridge, StationFeed_OperatorHints,
//                    StationFeed_TakeOutInput (Tick), StationFeed_TakeOutBridge (a station whose kernel hands pieces
//                    back: Searing, Fry)

// A new attempt: every older piece goes stale; the source platter keeps what it holds. A reset is for an idle hand: a
// transfer the last operator started lands whoever is standing there, and the next Idle enter resets. No feed on the
// context yet (the SM can enter before the entity script composes it) = nothing to reset.
class UMars_SmTask_StationFeed_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Feed = ck::Ctx(InHandle).As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Feed) || Feed.Get_Phase() != EMars_CookingFeed_Phase::Idle)
        { return; }

        Feed.Request_Reset(FMars_Request_CookingFeed_Reset());
    }
}

// The feed draws from whatever platter sits on the station's input dock: set on enter, and again on every dock and undock
// (an undock leaves the feed unsourced, which cancels a transfer in flight). The bindings live as long as the state. No
// feed or no input dock on the context (the SM can enter before the entity script composes them; a station without a dock)
// = the feed stays unsourced.
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

        _InputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnInputDocked"));
        _InputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnInputUndocked"));
        _Feed.Request_SetSource(FMars_Request_CookingFeed_SetSource(_InputDock.Get_Platter()));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_InputDock))
        {
            _InputDock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnInputDocked"));
            _InputDock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnInputUndocked"));
        }

        _Feed = FCk_Handle_CookingFeed();
        _InputDock = FCk_Handle_PlatterDock();
    }

    UFUNCTION()
    private void OnInputDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
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
// BeginTransfer, which the feed refuses while the hand is busy or the source is missing or empty. A station may refuse the
// edge before the feed sees it (a subclass overrides Get_CanBeginTransfer). Every edge is consumed whether or not it is
// taken (nothing is queued), and the seen frame is seeded on enter, so a press held from before the station was taken
// never counts. No operator intents (headless) = nothing to read.
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

        if (Get_CanBeginTransfer() == false)
        {
            ck::Trace(f"[StationFeed] [{_Feed.ToString()}] operator pressed add food; press refused by the station");
            return ECk_SmTaskResult::Running;
        }

        ck::Trace(f"[StationFeed] [{_Feed.ToString()}] operator pressed add food ({_Feed.Get_Phase() :n}, {_Feed.Get_Available()} left)");
        _Feed.Request_BeginTransfer(FMars_Request_CookingFeed_BeginTransfer());
        return ECk_SmTaskResult::Running;
    }

    // The operator leaving cancels a transfer only while the hand is still reaching for or grasping its piece. A carry
    // finishes without the operator: its release lands through the bridge, which runs in every state, and until the release
    // the piece is still on the platter, so nothing strands either way.
    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Feed) && Get_IsBeforeGrasped(_Feed.Get_Phase()))
        { _Feed.Request_Cancel(FMars_Request_CookingFeed_Cancel()); }

        _Feed = FCk_Handle_CookingFeed();
        _Intents = FCk_Handle_InputIntents();
        _SeenAddFoodFrame.Reset();
    }

    private bool Get_IsBeforeGrasped(EMars_CookingFeed_Phase InPhase) const
    {
        return InPhase == EMars_CookingFeed_Phase::Reach || InPhase == EMars_CookingFeed_Phase::Grasp;
    }

    // The station's own gate on a fresh press, ahead of the feed's (a tumbler refuses while its hatch is shut).
    protected bool Get_CanBeginTransfer() const { return true; }
}

// Routes each release to the cooking kernel on the station by its typed handle (Searing, then Fry, then Tumbler) and
// forwards that kernel's admission answer back to the feed. A release whose piece sits on a platter is unloaded first and
// goes to the kernel only on that platter's OnUnloaded (a piece another ledger holds is no kernel's to take); a release with
// no piece, or one already off any platter, goes at once. A rejected piece goes back onto the feed's source before the
// answer is forwarded. The bridge runs in every state of the station, so a transfer in flight completes whoever operates:
// a bridge entering while the feed awaits an admission takes that release over (and its unload, if the piece is still
// coming off), and a forwarded piece is always answered through a bridge. The bindings live as long as the state.
class UMars_SmTask_StationFeed_Bridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Station;
    private FCk_Handle_CookingFeed _Feed;
    // Invalid on a station without a Searing.
    private FCk_Handle_Searing _Searing;
    // Invalid on a station without a Fry.
    private FCk_Handle_Fry _Fry;
    // Invalid on a station without a Tumbler.
    private FCk_Handle_Tumbler _Tumbler;
    // The release in flight, from OnReleaseRequested until its admission answer.
    private TOptional<FMars_CookingFeed_Release> _Release;
    // The platter the released piece is coming off, from the unload until its OnUnloaded.
    private FCk_Handle_Platter _UnloadingFrom;

    // No feed on the context yet (the SM can enter Idle before the entity script composes it) = nothing to bridge.
    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = ck::Ctx(InHandle);
        _Feed = _Station.As_CookingFeed(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Feed))
        { return; }

        _Feed.BindTo_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested"));

        _Searing = _Station.As_Searing(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Searing))
        { _Searing.BindTo_OnPieceAdmission(FMars_Delegate_Searing_OnPieceAdmission(this, n"OnSearingPieceAdmission")); }

        _Fry = _Station.As_Fry(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Fry))
        { _Fry.BindTo_OnPieceAdmission(FMars_Delegate_Fry_OnPieceAdmission(this, n"OnFryPieceAdmission")); }

        _Tumbler = _Station.As_Tumbler(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(_Tumbler))
        { _Tumbler.BindTo_OnPieceAdmission(FMars_Delegate_Tumbler_OnPieceAdmission(this, n"OnTumblerPieceAdmission")); }

        Resume_InFlight();
    }

    // Nothing is cancelled or put back here: the next state's bridge takes the release in flight over.
    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Searing))
        { _Searing.UnbindFrom_OnPieceAdmission(FMars_Delegate_Searing_OnPieceAdmission(this, n"OnSearingPieceAdmission")); }

        if (ck::IsValid(_Fry))
        { _Fry.UnbindFrom_OnPieceAdmission(FMars_Delegate_Fry_OnPieceAdmission(this, n"OnFryPieceAdmission")); }

        if (ck::IsValid(_Tumbler))
        { _Tumbler.UnbindFrom_OnPieceAdmission(FMars_Delegate_Tumbler_OnPieceAdmission(this, n"OnTumblerPieceAdmission")); }

        Unwatch_Platter();
        _Release.Reset();

        if (ck::IsValid(_Feed))
        { _Feed.UnbindFrom_OnReleaseRequested(FMars_Delegate_CookingFeed_OnReleaseRequested(this, n"OnReleaseRequested")); }

        _Station = FCk_Handle();
        _Feed = FCk_Handle_CookingFeed();
        _Searing = FCk_Handle_Searing();
        _Fry = FCk_Handle_Fry();
        _Tumbler = FCk_Handle_Tumbler();
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
        _UnloadingFrom.Request_Unload(FMars_Request_Platter_Unload(InRelease.Piece));

        ck::Trace(f"[StationFeed] [{_Feed.ToString()}] {utils_cooking_feed::Get_PieceName(InRelease.PieceId)} [{InRelease.Piece.ToString()}] comes off [{Platter.ToString()}] for its release");
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
        ck::Trace(f"[StationFeed] [{_Feed.ToString()}] takes over {utils_cooking_feed::Get_PieceName(Release.PieceId)} [{Release.Piece.ToString()}] in flight (on a platter: {ck::IsValid(Platter)})");
        if (ck::Is_NOT_Valid(Platter))
        { return; }

        _UnloadingFrom = Platter;
        _UnloadingFrom.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded"));
    }

    // Off the platter at its world pose: now a kernel may take it.
    UFUNCTION()
    private void OnUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        if (_Release.IsSet() == false || InPiece != _Release.GetValue().Piece)
        { return; }

        Unwatch_Platter();
        Forward_Release(_Release.GetValue());
    }

    UFUNCTION()
    private void OnSearingPieceAdmission(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        Answer(InPieceId, InAdmission, InReason);
    }

    UFUNCTION()
    private void OnFryPieceAdmission(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        Answer(InPieceId, InAdmission, InReason);
    }

    UFUNCTION()
    private void OnTumblerPieceAdmission(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId,
        EMars_CookingFeed_Admission InAdmission, FString InReason)
    {
        Answer(InPieceId, InAdmission, InReason);
    }

    // A kernel's answer goes to the feed as it is; the feed honours it only for the piece it is awaiting. The release's own
    // answer ends it here, and a rejected piece goes back onto the source first.
    private void Answer(const FMars_CookingFeed_PieceId& InPieceId, EMars_CookingFeed_Admission InAdmission, const FString& InReason)
    {
        if (ck::Is_NOT_Valid(_Feed))
        { return; }

        if (_Release.IsSet() && _Release.GetValue().PieceId.Get_IsSame(InPieceId))
        {
            if (InAdmission == EMars_CookingFeed_Admission::Rejected)
            { Put_Back(_Release.GetValue().Piece); }

            _Release.Reset();
        }

        _Feed.Request_ResolveAdmission(FMars_Request_CookingFeed_ResolveAdmission(InPieceId, InAdmission, InReason));
    }

    // Searing, else Fry, else Tumbler admits through its AddPiece (answered by its OnPieceAdmission above). A station with
    // none of them has its releases refused, so the hand carries, the piece goes back and the hand returns.
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

        if (ck::IsValid(_Tumbler))
        {
            _Tumbler.Request_AddPiece(FMars_Request_Tumbler_AddPiece(InRelease));
            return;
        }

        Answer(InRelease.PieceId, EMars_CookingFeed_Admission::Rejected, "no receiver kernel");
    }

    // The rejected piece goes back onto the feed's source, arriving from where it lies. Mid-unload it is still on its
    // platter: a load queued now drains after that unload (Unload before Load) and lands it back. A piece that is gone, or
    // already on a platter, stays as it is; without a source it stays where it was released.
    private void Put_Back(const FCk_Handle_FoodPiece& InPiece)
    {
        if (ck::Is_NOT_Valid(_Feed) || ck::Is_NOT_Valid(InPiece)
            || utils_entity_lifetime::Get_IsPendingDestroy(InPiece, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        { return; }

        auto Source = _Feed.Get_Source();
        if (ck::Is_NOT_Valid(Source))
        {
            ck::Trace(f"[StationFeed] [{_Feed.ToString()}] [{InPiece.ToString()}] stays where it is: no source to put it back on");
            return;
        }

        const auto Holder = InPiece.TryGet_Platter();
        const auto IsUnloadingFromSource = ck::IsValid(_UnloadingFrom) && Holder == _UnloadingFrom && Holder == Source;
        if (ck::IsValid(Holder) && IsUnloadingFromSource == false)
        { return; }

        FCk_Handle PieceEntity = InPiece;
        Source.Request_Load(FMars_Request_Platter_Load(InPiece, utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform())));
        ck::Trace(f"[StationFeed] [{_Feed.ToString()}] [{InPiece.ToString()}] goes back onto [{Source.ToString()}]");
    }

    private void Unwatch_Platter()
    {
        if (ck::IsValid(_UnloadingFrom))
        { _UnloadingFrom.UnbindFrom_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded")); }

        _UnloadingFrom = FCk_Handle_Platter();
    }
}

// The operator's take-out presses. Each fresh activation of Interact_Secondary asks the station's cooking kernel (Searing,
// else Fry) to hand back every piece that is ready, no more than the docked finished tray has room for; a press with no
// tray, a full tray or nothing ready traces and does nothing (the station's label says why). Where the pieces land is
// StationFeed_TakeOutBridge's. The press is seeded on enter, so a hold from before the station was taken never counts. No
// kernel that hands pieces back or no output dock on the context (a composition that failed and already ensured) = nothing
// to take out; no operator intents (headless) = no presses.
class UMars_SmTask_StationFeed_TakeOutInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_PlatterDock _OutputDock;
    // Invalid on a station without a Searing.
    private FCk_Handle_Searing _Searing;
    // Invalid on a station without a Fry.
    private FCk_Handle_Fry _Fry;
    private FCk_Handle_InputIntents _Intents;
    // The activation frame of the Interact_Secondary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenTakeOutFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _OutputDock = utils_platter_dock::Find_OnStation(StationEntity, EMars_PlatterDock_Role::Output);
        _Searing = StationEntity.As_Searing(ECk_SanityCheck::UnChecked);
        _Fry = StationEntity.As_Fry(ECk_SanityCheck::UnChecked);
        _Intents = FCk_Handle_InputIntents();
        if (ck::Is_NOT_Valid(_OutputDock) || (ck::Is_NOT_Valid(_Searing) && ck::Is_NOT_Valid(_Fry)))
        { return; }

        auto Station = StationEntity.As_Station();
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
        _OutputDock = FCk_Handle_PlatterDock();
        _Searing = FCk_Handle_Searing();
        _Fry = FCk_Handle_Fry();
        _Intents = FCk_Handle_InputIntents();
        _SeenTakeOutFrame.Reset();
    }

    // Every ready piece, capped at the tray's free slots; the tray, its room and the ready count are checked here so a
    // refused press costs the kernel nothing.
    private void Request_TakeOut()
    {
        const auto Tray = _OutputDock.Get_Platter();
        if (ck::Is_NOT_Valid(Tray))
        {
            ck::Trace(f"[StationFeed] [{_OutputDock.ToString()}] take-out refused: no tray");
            return;
        }

        const auto FreeSlots = Tray.Get_FreeSlotCount();
        const auto Takeable = Get_TakeableCount();
        if (FreeSlots <= 0 || Takeable <= 0)
        {
            ck::Trace(f"[StationFeed] [{Tray.ToString()}] take-out refused: {FreeSlots} free slot(s), {Takeable} ready");
            return;
        }

        ck::Trace(f"[StationFeed] [{Tray.ToString()}] take out: {Takeable} ready, {FreeSlots} free slot(s)");
        const auto MaxPieces = TOptional<int32>(FreeSlots);
        if (ck::IsValid(_Searing))
        {
            _Searing.Request_TakeOut(FMars_Request_Searing_TakeOut(TOptional<FCk_Handle_FoodPiece>(), MaxPieces));
            return;
        }

        _Fry.Request_TakeOut(FMars_Request_Fry_TakeOut(TOptional<FCk_Handle_FoodPiece>(), MaxPieces));
    }

    private int32 Get_TakeableCount() const
    {
        if (ck::IsValid(_Searing))
        { return _Searing.Get_TakeableCount(); }

        if (ck::IsValid(_Fry))
        { return _Fry.Get_TakeableCount(); }

        return 0;
    }
}

// Where the taken-out pieces land: every piece the station's cooking kernel (Searing, else Fry) hands back
// (OnPieceTakenOut, whoever asked for it) is loaded onto the docked finished tray, arriving from where it lies; with no tray
// docked by then it stays where it is. The bridge runs in every state of the station, so a take-out pressed in the frame
// the operator leaves still lands on the tray. The bindings live as long as the state. No kernel that hands pieces back or
// no output dock on the context (the SM can enter Idle before the entity script composes them) = nothing to land.
class UMars_SmTask_StationFeed_TakeOutBridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_PlatterDock _OutputDock;
    // Invalid on a station without a Searing.
    private FCk_Handle_Searing _Searing;
    // Invalid on a station without a Fry.
    private FCk_Handle_Fry _Fry;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _OutputDock = utils_platter_dock::Find_OnStation(StationEntity, EMars_PlatterDock_Role::Output);
        _Searing = StationEntity.As_Searing(ECk_SanityCheck::UnChecked);
        _Fry = StationEntity.As_Fry(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_OutputDock))
        { return; }

        if (ck::IsValid(_Searing))
        { _Searing.BindTo_OnPieceTakenOut(FMars_Delegate_Searing_OnPieceTakenOut(this, n"OnSearingPieceTakenOut")); }
        else if (ck::IsValid(_Fry))
        { _Fry.BindTo_OnPieceTakenOut(FMars_Delegate_Fry_OnPieceTakenOut(this, n"OnFryPieceTakenOut")); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Searing))
        { _Searing.UnbindFrom_OnPieceTakenOut(FMars_Delegate_Searing_OnPieceTakenOut(this, n"OnSearingPieceTakenOut")); }

        if (ck::IsValid(_Fry))
        { _Fry.UnbindFrom_OnPieceTakenOut(FMars_Delegate_Fry_OnPieceTakenOut(this, n"OnFryPieceTakenOut")); }

        _OutputDock = FCk_Handle_PlatterDock();
        _Searing = FCk_Handle_Searing();
        _Fry = FCk_Handle_Fry();
    }

    UFUNCTION()
    private void OnSearingPieceTakenOut(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        Load_OntoTray(InPiece);
    }

    UFUNCTION()
    private void OnFryPieceTakenOut(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        Load_OntoTray(InPiece);
    }

    private void Load_OntoTray(const FCk_Handle_FoodPiece& InPiece)
    {
        auto Tray = _OutputDock.Get_Platter();
        if (ck::Is_NOT_Valid(Tray))
        {
            ck::Trace(f"[StationFeed] [{InPiece.ToString()}] was taken out with no tray docked: it stays where it is");
            return;
        }

        FCk_Handle PieceEntity = InPiece;
        Tray.Request_Load(FMars_Request_Platter_Load(InPiece, utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform())));
    }
}

// The operator's rows while operating. The add-food row (IA_StationAddFood): "add food · N left" while the hand is idle,
// "adding food… · N left" while it is busy, "no platter" without a source, "platter empty" once nothing is left on it;
// registered once on enter under the Operating state's owner key (its leave-unregister clears it) and re-texted on every
// stock and phase edge (the display drains registers before unregisters, so the row is never re-registered). The take-out
// row (IA_Interact_Secondary), on a station whose kernel hands pieces back (Searing, Fry) and only while a finished tray is
// docked: "take out · N ready", re-texted whenever a piece becomes ready (seared all round; drained), is lost, is taken
// out or (fry) changes whereabouts. An operator without a display (headless) gets no rows.
class UMars_SmTask_StationFeed_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Station";
    private const int32 k_AddFoodSortOrder = 6;
    private const int32 k_TakeOutSortOrder = 9;

    private FCk_Handle_CookingFeed _Feed;
    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_ActionHintRow _AddFoodRow;
    private FCk_Handle_PlatterDock _OutputDock;
    // Invalid on a station without a Searing.
    private FCk_Handle_Searing _Searing;
    // Invalid on a station without a Fry.
    private FCk_Handle_Fry _Fry;
    // Registered while a finished tray is docked.
    private FCk_Handle_ActionHintRow _TakeOutRow;

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

        Watch_TakeOut(StationEntity);
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

        _Feed = FCk_Handle_CookingFeed();
        _Display = FCk_Handle_ActionHintDisplay();
        _AddFoodRow = FCk_Handle_ActionHintRow();
        _TakeOutRow = FCk_Handle_ActionHintRow();
    }

    // The take-out row follows the output dock and the kernel's ready count. A station without an output dock or a kernel
    // that hands pieces back (the tumbler) has no take-out row.
    private void Watch_TakeOut(FCk_Handle InStation)
    {
        _OutputDock = utils_platter_dock::Find_OnStation(InStation, EMars_PlatterDock_Role::Output);
        _Searing = InStation.As_Searing(ECk_SanityCheck::UnChecked);
        _Fry = InStation.As_Fry(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_OutputDock) || (ck::Is_NOT_Valid(_Searing) && ck::Is_NOT_Valid(_Fry)))
        { return; }

        _OutputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
        _OutputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));

        if (ck::IsValid(_Searing))
        {
            _Searing.BindTo_OnPieceReady(FMars_Delegate_Searing_OnPieceReady(this, n"OnSearingPieceReady"));
            _Searing.BindTo_OnPieceLost(FMars_Delegate_Searing_OnPieceLost(this, n"OnSearingPieceLost"));
            _Searing.BindTo_OnPieceTakenOut(FMars_Delegate_Searing_OnPieceTakenOut(this, n"OnSearingPieceTakenOut"));
        }

        if (ck::IsValid(_Fry))
        {
            _Fry.BindTo_OnPieceDrained(FMars_Delegate_Fry_OnPieceDrained(this, n"OnFryPieceDrained"));
            _Fry.BindTo_OnPieceLost(FMars_Delegate_Fry_OnPieceLost(this, n"OnFryPieceLost"));
            _Fry.BindTo_OnPieceTakenOut(FMars_Delegate_Fry_OnPieceTakenOut(this, n"OnFryPieceTakenOut"));
            _Fry.BindTo_OnPieceWhereaboutsChanged(FMars_Delegate_Fry_OnPieceWhereaboutsChanged(this, n"OnFryPieceWhereaboutsChanged"));
        }

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

        if (ck::IsValid(_Searing))
        {
            _Searing.UnbindFrom_OnPieceReady(FMars_Delegate_Searing_OnPieceReady(this, n"OnSearingPieceReady"));
            _Searing.UnbindFrom_OnPieceLost(FMars_Delegate_Searing_OnPieceLost(this, n"OnSearingPieceLost"));
            _Searing.UnbindFrom_OnPieceTakenOut(FMars_Delegate_Searing_OnPieceTakenOut(this, n"OnSearingPieceTakenOut"));
        }

        if (ck::IsValid(_Fry))
        {
            _Fry.UnbindFrom_OnPieceDrained(FMars_Delegate_Fry_OnPieceDrained(this, n"OnFryPieceDrained"));
            _Fry.UnbindFrom_OnPieceLost(FMars_Delegate_Fry_OnPieceLost(this, n"OnFryPieceLost"));
            _Fry.UnbindFrom_OnPieceTakenOut(FMars_Delegate_Fry_OnPieceTakenOut(this, n"OnFryPieceTakenOut"));
            _Fry.UnbindFrom_OnPieceWhereaboutsChanged(FMars_Delegate_Fry_OnPieceWhereaboutsChanged(this, n"OnFryPieceWhereaboutsChanged"));
        }

        _OutputDock = FCk_Handle_PlatterDock();
        _Searing = FCk_Handle_Searing();
        _Fry = FCk_Handle_Fry();
    }

    private void Register_TakeOut()
    {
        if (ck::IsValid(_TakeOutRow))
        { return; }

        _TakeOutRow = _Display.Request_RegisterHint(
            FMars_ActionHint_Spec(mars::Mars_IA_Interact_Secondary, Get_TakeOutText(), k_TakeOutSortOrder, k_OwnerKey));
    }

    private void Refresh_TakeOutRow()
    {
        if (ck::Is_NOT_Valid(_Display) || ck::Is_NOT_Valid(_TakeOutRow))
        { return; }

        _Display.Request_UpdateHint(FMars_Request_ActionHintDisplay_Update(_TakeOutRow, Get_TakeOutText()));
    }

    private FText Get_TakeOutText() const
    {
        if (ck::IsValid(_Searing))
        { return FText::FromString(f"take out · {_Searing.Get_TakeableCount()} ready"); }

        return FText::FromString(f"take out · {_Fry.Get_TakeableCount()} ready");
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
    private void OnSearingPieceReady(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FMars_Searing_Tally InTally)
    {
        Refresh_TakeOutRow();
    }

    UFUNCTION()
    private void OnSearingPieceLost(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        Refresh_TakeOutRow();
    }

    UFUNCTION()
    private void OnSearingPieceTakenOut(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_TakeOutRow();
    }

    UFUNCTION()
    private void OnFryPieceDrained(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId)
    {
        Refresh_TakeOutRow();
    }

    UFUNCTION()
    private void OnFryPieceLost(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        Refresh_TakeOutRow();
    }

    UFUNCTION()
    private void OnFryPieceTakenOut(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        Refresh_TakeOutRow();
    }

    // A drained piece knocked out of the basket is no longer takeable, and one knocked back in is again.
    UFUNCTION()
    private void OnFryPieceWhereaboutsChanged(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId,
        EMars_Fry_Whereabouts InFrom, EMars_Fry_Whereabouts InTo)
    {
        Refresh_TakeOutRow();
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

        if (_Feed.Get_IsSourced() == false)
        { return FText::FromString("no platter"); }

        if (Available <= 0)
        { return FText::FromString("platter empty"); }

        return FText::FromString(f"add food · {Available} left");
    }
}
