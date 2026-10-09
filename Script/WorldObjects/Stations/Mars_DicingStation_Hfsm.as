// The dicing station's control layer: its own state machine (FMars_Station_Spec.MinigameStateClass =
// UMars_SmState_Dicing_Idle). It runs on the STATION entity (context = the station, which also carries the Dicing feature
// and the FoodBoard; its two platter docks are lifetime children of it) and reads the station's operator; it only issues
// Dicing, FoodBoard and Platter requests and registers the operator's legend rows.
//
//   Idle      ->Operated [StationIsOperated]      tasks: Dicing_ResetOnEnter (a fresh band and hand for the next operator),
//                                                         Dicing_Intake, Dicing_SweepBridge
//   Operated  ->Idle     [StationIsNotOperated]   tasks: Dicing_OperatorInput (Tick), Dicing_CutBridge, Dicing_Intake,
//                                                         Dicing_SweepBridge, Dicing_OperatorHints
//
// The intake and the sweep bridge run in both states: neither needs an operator, and a joint coming off the input platter
// or a piece the board handed off lands whoever is standing there.
//
// The conditions are the shared station ones (Mars_Station_SmConditions.as). The player's Operating state owns the pose,
// the camera (Captured: the view stays still, the look delta is ours), the glove grip and the Leave intent.

namespace utils_dicing
{
    // Where the food lies on the board, in the station frame: over the board's middle, on its top (the counter and the 4 cm
    // board). Here, beside the control that lays pieces there. A function: a global's initializer cannot read another
    // module's constant.
    FTransform Get_PileLocal()
    {
        return FTransform(FRotator::ZeroRotator, FVector(0.0, 0.0, constants_station::k_CounterHeight + 4.0));
    }

    // The blade as a cutting plane at contact: through the hand's lateral position, its normal along the hand's travel (the
    // station's local Y), its face along the board's depth. Read from the station root and Dicing's HandLateral rather than
    // the lateral node, which lags a nudge drained in the chop's own frame. Here, beside the control that captures it, so
    // the minigame kernel never learns about food.
    FMars_FoodPiece_WorldPlane Get_BladePlane(const FTransform& InStationWorld, float32 InHandLateral)
    {
        return FMars_FoodPiece_WorldPlane(
            InStationWorld.TransformPosition(FVector(0.0, float64(InHandLateral), 0.0)),
            InStationWorld.TransformVectorNoScale(FVector::RightVector),
            InStationWorld.TransformVectorNoScale(FVector::ForwardVector));
    }

    // The pose InPiece takes on the board: the pile, with its food's layout applied (yaw about the station's Z, lift along
    // it), at unit scale. A piece with no definition lies unrotated.
    FTransform Get_PileWorld(const FTransform& InStationWorld, const FCk_Handle_FoodPiece& InPiece)
    {
        auto LayoutLocal = FTransform::Identity;
        const UMars_Food_Def Def = InPiece.Get_Definition().Get();
        if (ck::IsValid(Def))
        { LayoutLocal = FTransform(FRotator(0.0, Def.Layout.YawDegrees, 0.0), FVector(0.0, 0.0, Def.Layout.LiftCm)); }

        auto PileWorld = LayoutLocal * Get_PileLocal() * InStationWorld;
        PileWorld.SetScale3D(FVector::OneVector);
        return PileWorld;
    }

    // The platter docked on the station's finished-tray dock; invalid with nothing docked.
    FCk_Handle_Platter TryGet_Tray(FCk_Handle InStation)
    {
        const auto Dock = utils_platter_dock::Find_OnStation(InStation, EMars_PlatterDock_Role::Output);
        if (ck::Is_NOT_Valid(Dock))
        { return FCk_Handle_Platter(); }

        return Dock.Get_Platter();
    }

    // The sweep: hands the board's free pieces to the docked finished tray, no more than it has room for (the sweep bridge
    // loads each one the board lets go). No tray docked = refused; the station's label already says so.
    void Request_Sweep(FCk_Handle InStation)
    {
        const auto Tray = TryGet_Tray(InStation);
        if (ck::Is_NOT_Valid(Tray))
        {
            ck::Trace("[Dicing] sweep refused: no tray");
            return;
        }

        auto Board = InStation.As_FoodBoard();
        Board.Request_Release(FMars_Request_FoodBoard_Release(EMars_FoodBoard_ReleaseMode::Handoff, TOptional<int32>(Tray.Get_FreeSlotCount())));
    }
}

class UMars_SmState_Dicing_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToOperated = AddTransition(InHandle, UMars_SmState_Dicing_Operated);
        AddCondition(ToOperated, UMars_SmCondition_StationIsOperated);

        AddTask(InHandle, UMars_SmTask_Dicing_ResetOnEnter);
        AddTask(InHandle, UMars_SmTask_Dicing_Intake);
        AddTask(InHandle, UMars_SmTask_Dicing_SweepBridge);
    }
}

class UMars_SmState_Dicing_Operated : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToIdle = AddTransition(InHandle, UMars_SmState_Dicing_Idle);
        AddCondition(ToIdle, UMars_SmCondition_StationIsNotOperated);

        AddTask(InHandle, UMars_SmTask_Dicing_OperatorInput);
        AddTask(InHandle, UMars_SmTask_Dicing_CutBridge);
        AddTask(InHandle, UMars_SmTask_Dicing_Intake);
        AddTask(InHandle, UMars_SmTask_Dicing_SweepBridge);
        AddTask(InHandle, UMars_SmTask_Dicing_OperatorHints);
    }
}

// A fresh pile, band and hand for the next operator. The board keeps whatever the last one left: the player's food is never
// cleared by an operator change. No Dicing on the context yet (the SM can enter before the entity script composes it) =
// nothing to reset.
class UMars_SmTask_Dicing_ResetOnEnter : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Station = ck::Ctx(InHandle);

        auto Dicing = Station.As_Dicing(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Dicing))
        { Dicing.Request_Reset(FMars_Request_Dicing_Reset()); }
    }
}

// The operator's input, read off its InputIntents: one nudge per drained look delta (its horizontal component, degrees;
// positive = mouse right = the board's +Y, the operator's right), one chop per rising edge of Interact_Primary and one sweep
// (utils_dicing::Request_Sweep) per rising edge of Interact_Secondary. All are seeded on enter, so a delta or a press from
// before the station was taken does not count. No operator intents (headless) = nothing to read.
class UMars_SmTask_Dicing_OperatorInput : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle _Station;
    private FCk_Handle_Dicing _Dicing;
    private FCk_Handle_InputIntents _Intents;
    private int32 _SeenLookSequence = 0;
    // The activation frame of the Interact_Primary hold last seen; unset while it is not held.
    private TOptional<int32> _SeenChopFrame;
    // The same for Interact_Secondary.
    private TOptional<int32> _SeenSweepFrame;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Station = StationEntity;
        _Dicing = StationEntity.As_Dicing();
        _Intents = FCk_Handle_InputIntents();

        auto Station = StationEntity.As_Station();
        auto Operator = Station.Get_Operator();
        _Intents = Operator.As_InputIntents(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Intents))
        { return; }

        _SeenLookSequence = _Intents.Get_LookDeltaSequence();
        _SeenChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        _SeenSweepFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Operated is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Dicing) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        const auto Sequence = _Intents.Get_LookDeltaSequence();
        if (Sequence != _SeenLookSequence)
        {
            _SeenLookSequence = Sequence;
            _Dicing.Request_Nudge(FMars_Request_Dicing_Nudge(float32(_Intents.Get_LookDelta().X)));
        }

        const auto ChopFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Primary);
        if (ChopFrame != _SeenChopFrame)
        {
            _SeenChopFrame = ChopFrame;
            if (ChopFrame.IsSet())
            { _Dicing.Request_Chop(FMars_Request_Dicing_Chop()); }
        }

        const auto SweepFrame = _Intents.TryGet_IntentActivationFrame(GameplayTags::Mars_Intent_Interact_Secondary);
        if (SweepFrame != _SeenSweepFrame)
        {
            _SeenSweepFrame = SweepFrame;
            if (SweepFrame.IsSet())
            { utils_dicing::Request_Sweep(_Station); }
        }

        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Station = FCk_Handle();
        _Dicing = FCk_Handle_Dicing();
        _Intents = FCk_Handle_InputIntents();
        _SeenLookSequence = 0;
        _SeenChopFrame.Reset();
        _SeenSweepFrame.Reset();
    }
}

// Every chop the cleaver lands cuts the board along the blade, on the band or off it: the band scores the herbs, the board
// holds the food under the blade, and the cut never feeds the score. The binding lives exactly as long as the Operated state,
// so a chop that lands after the operator left cuts nothing. It needs no operator input, so a headless operator drives it
// too. No board or Dicing on the context (a composition that failed and already ensured) = nothing to cut.
class UMars_SmTask_Dicing_CutBridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_Transform _Root;
    private FCk_Handle_Dicing _Dicing;
    private FCk_Handle_FoodBoard _Board;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        _Dicing = StationEntity.As_Dicing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Board) || ck::Is_NOT_Valid(_Dicing))
        { return; }

        _Root = StationEntity.As_Transform();
        _Dicing.BindTo_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Dicing))
        { _Dicing.UnbindFrom_OnChopResolved(FMars_Delegate_Dicing_OnChopResolved(this, n"OnChopResolved")); }

        _Root = FCk_Handle_Transform();
        _Dicing = FCk_Handle_Dicing();
        _Board = FCk_Handle_FoodBoard();
    }

    UFUNCTION()
    private void OnChopResolved(FCk_Handle_Dicing InDicing, EMars_Dicing_ChopResult InResult)
    {
        const auto StationWorld = utils_transform::Get_EntityCurrentTransform(_Root);
        _Board.Request_Cut(FMars_Request_FoodBoard_Cut(utils_dicing::Get_BladePlane(StationWorld, InDicing.Get_HandLateral())));
    }
}

// Takes the piece on the docked input platter onto an empty board, at the pile in its food's layout: on enter, whenever a
// platter docks on the input dock and whenever the board lets a piece go (an emptied board takes the next joint). The
// platter lets the piece go first; only on its OnUnloaded is the piece moved and placed, since the board refuses a piece
// another ledger still holds. One intake at a time: the next waits for the board's answer to the place (an empty board has
// room, so a refusal is a defect). It runs in both states, so the joint lands with or without an operator: an unload the
// last state asked for is asked for again on enter, and the platter drains the two as one, so this task hears its
// OnUnloaded. The bindings live as long as the state. No board or input dock on the context (a composition that failed
// and already ensured) = nothing to take in.
class UMars_SmTask_Dicing_Intake : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle_Transform _Root;
    private FCk_Handle_FoodBoard _Board;
    private FCk_Handle_PlatterDock _InputDock;
    // The platter the piece is coming off and the piece, from the unload until the board answers the place.
    private FCk_Handle_Platter _Platter;
    private FCk_Handle_FoodPiece _Piece;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        _InputDock = utils_platter_dock::Find_OnStation(StationEntity, EMars_PlatterDock_Role::Input);
        if (ck::Is_NOT_Valid(_Board) || ck::Is_NOT_Valid(_InputDock))
        { return; }

        _Root = StationEntity.As_Transform();
        _Board.BindTo_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnPlaced"));
        _Board.BindTo_OnPlaceRefused(FMars_Delegate_FoodBoard_OnPlaceRefused(this, n"OnPlaceRefused"));
        _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        _InputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnInputDocked"));

        Try_Intake();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Board))
        {
            _Board.UnbindFrom_OnPlaced(FMars_Delegate_FoodBoard_OnPlaced(this, n"OnPlaced"));
            _Board.UnbindFrom_OnPlaceRefused(FMars_Delegate_FoodBoard_OnPlaceRefused(this, n"OnPlaceRefused"));
            _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnBoardReleased"));
        }

        if (ck::IsValid(_InputDock))
        { _InputDock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnInputDocked")); }

        Unwatch_Platter();

        _Root = FCk_Handle_Transform();
        _Board = FCk_Handle_FoodBoard();
        _InputDock = FCk_Handle_PlatterDock();
        _Piece = FCk_Handle_FoodPiece();
    }

    private void Try_Intake()
    {
        if (ck::IsValid(_Piece) || _Board.Get_HeldCount() > 0)
        { return; }

        auto Platter = _InputDock.Get_Platter();
        if (ck::Is_NOT_Valid(Platter) || Platter.Get_HeldCount() == 0)
        { return; }

        _Platter = Platter;
        _Piece = Platter.Get_Held()[0];
        _Platter.BindTo_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded"));
        _Platter.Request_Unload(FMars_Request_Platter_Unload(_Piece));

        ck::Trace(f"[Dicing] intake: [{_Piece.ToString()}] comes off [{_Platter.ToString()}] onto [{_Board.ToString()}]");
    }

    private void Unwatch_Platter()
    {
        if (ck::IsValid(_Platter))
        { _Platter.UnbindFrom_OnUnloaded(FMars_Delegate_Platter_OnUnloaded(this, n"OnUnloaded")); }

        _Platter = FCk_Handle_Platter();
    }

    UFUNCTION()
    private void OnInputDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Try_Intake();
    }

    // A release that left pieces on the board takes nothing (Try_Intake wants an empty board).
    UFUNCTION()
    private void OnBoardReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        Try_Intake();
    }

    // Detached at its world pose: the piece is moved to the pile, then placed.
    UFUNCTION()
    private void OnUnloaded(FCk_Handle_Platter InPlatter, FCk_Handle_FoodPiece InPiece)
    {
        if (InPiece != _Piece)
        { return; }

        Unwatch_Platter();

        const auto PileWorld = utils_dicing::Get_PileWorld(utils_transform::Get_EntityCurrentTransform(_Root), _Piece);
        FCk_Handle PieceEntity = _Piece;
        utils_transform::Request_SetLocation(PieceEntity.As_Transform(), FCk_Request_Transform_SetLocation(PileWorld.GetLocation()));
        utils_transform::Request_SetRotation(PieceEntity.As_Transform(), FCk_Request_Transform_SetRotation(PileWorld.Rotator()));
        _Board.Request_Place(FMars_Request_FoodBoard_Place(_Piece));
    }

    UFUNCTION()
    private void OnPlaced(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        if (InPiece == _Piece)
        { _Piece = FCk_Handle_FoodPiece(); }
    }

    UFUNCTION()
    private void OnPlaceRefused(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece, EMars_FoodBoard_PlaceRefusal InRefusal)
    {
        if (InPiece != _Piece)
        { return; }

        ck::EnsureIfNot(false, f"[Dicing] the empty board [{InBoard.ToString()}] refused the intake's [{InPiece.ToString()}]: {InRefusal :n}");
        _Piece = FCk_Handle_FoodPiece();
    }
}

// Loads every piece the board lets go onto the docked finished tray, arriving from where it lay on the board. The sweep
// releases only with a tray docked and only as many as it has room for (utils_dicing::Request_Sweep); a piece released
// with no tray docked is left where it is. It runs in both states, so a sweep in the frame the operator leaves still
// lands on the tray; the binding lives as long as the state. No board on the context (a composition that failed and
// already ensured) = nothing to bridge.
class UMars_SmTask_Dicing_SweepBridge : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private FCk_Handle _Station;
    private FCk_Handle_FoodBoard _Board;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto StationEntity = ck::Ctx(InHandle);
        _Board = StationEntity.As_FoodBoard(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Board))
        { return; }

        _Station = StationEntity;
        _Board.BindTo_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnReleased"));
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Board))
        { _Board.UnbindFrom_OnReleased(FMars_Delegate_FoodBoard_OnReleased(this, n"OnReleased")); }

        _Station = FCk_Handle();
        _Board = FCk_Handle_FoodBoard();
    }

    UFUNCTION()
    private void OnReleased(FCk_Handle_FoodBoard InBoard, FCk_Handle_FoodPiece InPiece)
    {
        auto Tray = utils_dicing::TryGet_Tray(_Station);
        if (ck::Is_NOT_Valid(Tray))
        {
            ck::Trace(f"[Dicing] [{InPiece.ToString()}] was released with no tray docked: it stays where it is");
            return;
        }

        FCk_Handle PieceEntity = InPiece;
        Tray.Request_Load(FMars_Request_Platter_Load(InPiece, utils_transform::Get_EntityCurrentTransform(PieceEntity.As_Transform())));
    }
}

// The operator's legend rows while operating, under owner key k_OwnerKey: "move hand" (IA_Look), "chop"
// (IA_Interact_Primary) and, while a finished tray is docked, "sweep to tray" (IA_Interact_Secondary). The pile's state is
// the station's world label, not a row: a legend row without an InputAction does not render. An operator without a display
// (headless) gets no rows.
class UMars_SmTask_Dicing_OperatorHints : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    private const FName k_OwnerKey = n"Dicing";
    private const int32 k_MoveHandSortOrder = 7;
    private const int32 k_ChopSortOrder = 8;
    private const int32 k_SweepSortOrder = 9;

    private FCk_Handle_ActionHintDisplay _Display;
    private FCk_Handle_PlatterDock _OutputDock;
    // Registered while a finished tray is docked.
    private FCk_Handle_ActionHintRow _SweepRow;

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

        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Look, FText::FromString("move hand"), k_MoveHandSortOrder, k_OwnerKey));
        _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Primary, FText::FromString("chop"), k_ChopSortOrder, k_OwnerKey));

        _OutputDock = utils_platter_dock::Find_OnStation(StationEntity, EMars_PlatterDock_Role::Output);
        if (ck::Is_NOT_Valid(_OutputDock))
        { return; }

        _OutputDock.BindTo_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
        _OutputDock.BindTo_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        if (ck::IsValid(_OutputDock.Get_Platter()))
        { Register_Sweep(); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_OutputDock))
        {
            _OutputDock.UnbindFrom_OnDocked(FMars_Delegate_PlatterDock_OnDocked(this, n"OnOutputDocked"));
            _OutputDock.UnbindFrom_OnUndocked(FMars_Delegate_PlatterDock_OnUndocked(this, n"OnOutputUndocked"));
        }

        if (ck::IsValid(_Display))
        { _Display.Request_UnregisterHintsByOwner(FMars_Request_ActionHintDisplay_UnregisterByOwner(k_OwnerKey)); }

        _Display = FCk_Handle_ActionHintDisplay();
        _OutputDock = FCk_Handle_PlatterDock();
        _SweepRow = FCk_Handle_ActionHintRow();
    }

    private void Register_Sweep()
    {
        if (ck::IsValid(_SweepRow))
        { return; }

        _SweepRow = _Display.Request_RegisterHint(FMars_ActionHint_Spec(mars::Mars_IA_Interact_Secondary, FText::FromString("sweep to tray"), k_SweepSortOrder, k_OwnerKey));
    }

    UFUNCTION()
    private void OnOutputDocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        Register_Sweep();
    }

    UFUNCTION()
    private void OnOutputUndocked(FCk_Handle_PlatterDock InDock, FCk_Handle_Platter InPlatter)
    {
        if (ck::Is_NOT_Valid(_SweepRow))
        { return; }

        _Display.Request_UnregisterHint(FMars_Request_ActionHintDisplay_Unregister(_SweepRow));
        _SweepRow = FCk_Handle_ActionHintRow();
    }
}
