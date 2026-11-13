// The real heat stations' net tests' shared steps, on the feed station net rig (its platter, its reports, its docks, its
// operator, its sampler and its clean endings). A protected hook names the station the server spawns
// (EMars_TESTONLY_HeatStation) and its exposed spec; the server spawns it through the heat-station fixture under the
// replicated spawn owner, as the map's spawner makes it (its own context), and each machine finds its own copy as the
// base rig finds its station, then its kernel, whose signals it records in order from then on. The rig adds: a remote
// sample (the server applies one FMars_InputIntents_RemoteSample built from a look total and every operator row it keeps,
// each with its running press serial and hold), holding a row and letting it go, pressing it; admitting a piece (the
// server queues a release of it over the station's release node in the station's admission inbox, as the feed does); the
// subject's dip and take-out rows; a tray (an empty large platter docked on the Output dock); and a third test-only
// replicated report on the subject with the followed pieces, the bowl's ids, a coat and the bowl's serial (the pan's ids,
// a number and a face at the searing station). The Searing branch spawns the real searing station with the test's exposed
// Searing spec (ready once its pan body is in the simulation on the server), records the kernel's signals and samples the
// pan every frame (its roll, its lift, its node's location). One [BatterNetTest] or [SearingNetTest] line per test per
// machine. Only the Batter and Searing branches are built; the other stations ensure.

namespace constants_heat_station_net_autotest
{
    const float32 k_CoatSeconds = 0.6f;
    // The generation of every release the rig queues by hand: never one a feed hands out in these tests.
    const int32 k_RigGeneration = 9000;
    const float64 k_OffsetToleranceCm = 0.5;
    // Where the rig's loose foods lie, beside the platter (away from the station's counter), k_FoodSpacingCm apart in X.
    const FVector k_FoodLocal = FVector(-90.0, -150.0, 5.0);
    const float64 k_FoodSpacingCm = 90.0;
}

enum EMars_TESTONLY_HeatStation
{
    Batter,
    Searing,
    Fry,
    Tumbler
}

// One operator row the rig sends: its running press serial and whether it is held.
struct FMars_TESTONLY_NetHeatRemoteRow
{
    FGameplayTag Intent;
    int32 PressSerial = 0;
    EMars_InputIntents_Hold Hold = EMars_InputIntents_Hold::Released;
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only).
struct FMars_Fragment_TESTONLY_NetHeatStationReport
{
    UPROPERTY()
    int32 Serial = 0;

    UPROPERTY()
    int32 Step = 0;

    // The pieces the test follows, in the order it admitted them.
    UPROPERTY()
    TArray<FGuid> PieceGuids;

    // The bowl's ids as the server's Get_PieceIds gives them.
    UPROPERTY()
    TArray<FMars_CookingFeed_PieceId> BowlIds;

    // The first followed piece's coat on the server; -1 when it is not in the bowl.
    UPROPERTY()
    float32 Coat = -1.0f;

    UPROPERTY()
    int32 BowlSerial = 0;

    // The frame counter of the server's last marked event (Mark_EventFrame); -1 without one.
    UPROPERTY()
    int32 EventFrame = -1;

    // A number the test reports (the pan's roll, a kick total), and a face (int32(EMars_FoodPiece_Face); -1 without one).
    UPROPERTY()
    float32 Value = 0.0f;

    UPROPERTY()
    int32 Face = -1;
}

// One frame of this machine's pan, as the sampler read it.
struct FMars_TESTONLY_NetHeatPanSample
{
    int32 Step = 0;
    int64 Frame = 0;
    // Game seconds when sampled, and since the previous sample.
    float64 Seconds = 0.0;
    float32 DeltaSeconds = 0.0f;
    float32 Roll = 0.0f;
    float32 Lift = 0.0f;
    FVector NodeLocation = FVector::ZeroVector;
    EMars_Searing_Heat Heat = EMars_Searing_Heat::Cold;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetHeatStation : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    // This machine's copy of the bowl, once found.
    protected FCk_Handle_Batter _Batter;

    // Every bowl signal this machine's copy raised since it was found (or since Clear_BatterRecord), in order.
    protected TArray<EMars_Batter_Bowl> _BowlChanges;
    // The frame counter of each bowl change, in parallel.
    protected TArray<int64> _BowlChangeFrames;
    protected TArray<FMars_CookingFeed_PieceId> _AddedIds;
    // Of _AddedIds: the rows this copy had announced before the rig bound it (each announce raised OnPieceAdded).
    protected int32 _AddedBeforeBind = 0;
    protected TArray<EMars_Batter_AdmissionRefusal> _AdmissionRefusals;
    protected TArray<EMars_Batter_TakeOutRefusal> _TakeOutRefusals;
    protected TArray<FMars_CookingFeed_PieceId> _TakenOutIds;

    // This machine's copy of the pan's kernel, once found, and every signal it raised since (or since Clear_SearingRecord).
    protected FCk_Handle_Searing _Searing;
    protected TArray<EMars_Searing_Heat> _HeatChanges;
    protected TArray<FMars_CookingFeed_PieceId> _PanAddedIds;
    protected TArray<FMars_CookingFeed_PieceId> _SearedIds;
    // In parallel with _SearedIds.
    protected TArray<EMars_FoodPiece_Face> _SearedFaces;
    protected TArray<EMars_CookingFeed_TakeOutRefusal> _PanTakeOutRefusals;
    protected TArray<FMars_CookingFeed_PieceId> _LostIds;
    // Every sampled frame of this machine's pan since it was found.
    protected TArray<FMars_TESTONLY_NetHeatPanSample> _PanSamples;

    // Server: what the next report carries as its number and its face.
    protected float32 _ReportValue = 0.0f;
    protected int32 _ReportFace = -1;

    // Server: the foods it spawned loose, the half of a cut it keeps, the pieces the report follows.
    protected TArray<FCk_Handle> _Foods;
    protected FCk_Handle_FoodPiece _CutHalf;
    protected TArray<FCk_Handle_FoodPiece> _Followed;

    // Server: whether On_ServerFeedStationReady runs in the continuation in which it first finds its station (a late binder's
    // premise) or k_StepGapSeconds later, once the client's copy has had time to compose and be found.
    protected bool _ServerActsOnFirstFind = false;

    // Server: the tray it spawned; this machine's copy of it, once found.
    protected FCk_Handle _TrayEntity;
    protected FCk_Handle_Platter _Tray;

    // Server: the frame counter of its last marked event, for the report.
    protected int64 _EventFrame = -1;

    private bool _WasHeatStationFound = false;
    private int32 _AdmitIndex = 0;
    private TArray<FMars_TESTONLY_NetHeatRemoteRow> _RemoteRows;
    private FVector _LookTotal = FVector::ZeroVector;
    private FCk_Handle _CutSlab;
    private FName _FoodsContinuation;
    private FName _CutContinuation;
    private FName _TrayContinuation;
    private FName _OperatorContinuation;
    private FCk_Handle_FoodPiece _SearAllRoundPiece;
    private FName _SearAllRoundContinuation;
    private float64 _LastPanSampleSeconds = -1.0;

    //----------------------------------------------------------------------------------------------------------------------
    // Hooks
    //----------------------------------------------------------------------------------------------------------------------

    protected EMars_TESTONLY_HeatStation Get_HeatStation() const
    {
        return EMars_TESTONLY_HeatStation::Batter;
    }

    // The station's exposed spec: the fixture spawns the bowl with its coat seconds.
    protected FMars_Batter_Spec Make_BatterSpec() const
    {
        auto Spec = FMars_Batter_Spec();
        Spec.Coat.CoatSeconds = constants_heat_station_net_autotest::k_CoatSeconds;
        return Spec;
    }

    // The searing station's exposed spec.
    protected FMars_Searing_Spec Make_SearingSpec() const
    {
        return FMars_Searing_Spec();
    }

    // Every sampled frame, once this machine found its heat station.
    protected void On_HeatStationSample() {}

    //----------------------------------------------------------------------------------------------------------------------
    // Either machine
    //----------------------------------------------------------------------------------------------------------------------

    // Call first, on both machines.
    protected void Begin_HeatStationRig(FCk_Handle InTestEntity, float64 InX)
    {
        // Not the cutting station: the base rig then looks for no board.
        _FeedStationKind = EMars_TESTONLY_RealFeedStationKind::Searing;
        Begin_FeedStationRig(InTestEntity, InX);
        Add_HeatStationReport();
        Reset_RemoteRows();
    }

    protected void Log_HeatStation(FString InText)
    {
        const auto Machine = Get_MachineName();
        const auto TestName = GetClass().GetName();
        const auto Ensures = Get_EnsureDelta();
        Log(f"{Get_LogTag()} {TestName} {Machine}: {InText} times=[{_Times}] ensures={Ensures}");
    }

    protected FString Get_LogTag() const
    {
        return Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing ? "[SearingNetTest]" : "[BatterNetTest]";
    }

    // Finds this machine's station (its docks and its feed composed) and its kernel, and records the kernel's signals from
    // then on.
    protected bool Try_FindHeatStation()
    {
        if (_WasHeatStationFound)
        { return true; }

        if (Try_FindFeedStation() == false)
        { return false; }

        if (ck::EnsureIfNot(Get_HeatStation() == EMars_TESTONLY_HeatStation::Batter || Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing,
            f"[NetHeatStation] the {Get_HeatStation() :n} branch is not built yet"))
        { return false; }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        { return Try_FindSearing(); }

        if (_Station.Is_Batter() == false)
        { return false; }

        _WasHeatStationFound = true;
        _Batter = _Station.As_Batter();
        const auto Announced = Get_AnnouncedRows();
        _AddedBeforeBind = Announced.Num();
        _AddedIds.Append(Announced);
        _Batter.BindTo_OnBowlChanged(FMars_Delegate_Batter_OnBowlChanged(this, n"OnRigBowlChanged"));
        _Batter.BindTo_OnPieceAdded(FMars_Delegate_Batter_OnPieceAdded(this, n"OnRigPieceAdded"));
        _Batter.BindTo_OnAdmissionRefused(FMars_Delegate_Batter_OnAdmissionRefused(this, n"OnRigAdmissionRefused"));
        _Batter.BindTo_OnTakeOutRefused(FMars_Delegate_Batter_OnTakeOutRefused(this, n"OnRigTakeOutRefused"));
        _Batter.BindTo_OnPieceTakenOut(FMars_Delegate_Batter_OnPieceTakenOut(this, n"OnRigPieceTakenOut"));
        return true;
    }

    private bool Try_FindSearing()
    {
        if (_Station.Is_Searing() == false)
        { return false; }

        _WasHeatStationFound = true;
        _Searing = _Station.As_Searing();
        // A row this copy announced before the rig bound raised OnPieceAdded all the same.
        _PanAddedIds.Append(Get_PanAnnouncedRows());
        _Searing.BindTo_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnRigHeatChanged"));
        _Searing.BindTo_OnPieceAdded(FMars_Delegate_Searing_OnPieceAdded(this, n"OnRigPanPieceAdded"));
        _Searing.BindTo_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnRigFaceSeared"));
        _Searing.BindTo_OnTakeOutRefused(FMars_Delegate_Searing_OnTakeOutRefused(this, n"OnRigPanTakeOutRefused"));
        _Searing.BindTo_OnPieceLost(FMars_Delegate_Searing_OnPieceLost(this, n"OnRigPieceLost"));
        return true;
    }

    // The ledger rows a copy without authority has announced (it raised OnPieceAdded for each); none with authority.
    protected TArray<FMars_CookingFeed_PieceId> Get_PanAnnouncedRows()
    {
        TArray<FMars_CookingFeed_PieceId> Ids;
        if (Get_IsServer() || ck::Is_NOT_Valid(_Searing) || _Searing.Has_Fragment(FMars_Fragment_Searing_Local) == false)
        { return Ids; }

        return _Searing.Get_Fragment(FMars_Fragment_Searing_Local).Announced;
    }

    protected void Clear_SearingRecord()
    {
        _HeatChanges.Empty();
        _PanAddedIds.Empty();
        _SearedIds.Empty();
        _SearedFaces.Empty();
        _PanTakeOutRefusals.Empty();
        _LostIds.Empty();
    }

    protected int32 Get_PanAddedCount(FMars_CookingFeed_PieceId InId)
    {
        auto Count = 0;
        for (const auto& Id : _PanAddedIds)
        {
            if (Id.Get_IsSame(InId))
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_HeatChangeCount(EMars_Searing_Heat InHeat)
    {
        auto Count = 0;
        for (const auto Heat : _HeatChanges)
        {
            if (Heat == InHeat)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_SearingRecord()
    {
        FString Heats = "";
        for (const auto Heat : _HeatChanges)
        { Heats += f"{Heat :n} "; }

        FString Added = "";
        for (const auto& Id : _PanAddedIds)
        { Added += f"{Id.Generation}.{Id.TransferIndex} "; }

        FString Seared = "";
        for (int32 Index = 0; Index < _SearedIds.Num(); ++Index)
        { Seared += f"{_SearedIds[Index].TransferIndex}:{_SearedFaces[Index] :n} "; }

        FString TakeOuts = "";
        for (const auto Refusal : _PanTakeOutRefusals)
        { TakeOuts += f"{Refusal :n} "; }

        return f"heats=[{Heats}] added=[{Added}] seared=[{Seared}] takeOutRefused=[{TakeOuts}] lost={_LostIds.Num()}";
    }

    // The kernel's ledger and the pan's as this machine reads them.
    protected FString Describe_SearingLedger()
    {
        if (ck::Is_NOT_Valid(_Searing))
        { return "ledger=[none]"; }

        const auto Ledger = _Searing.Get_Ledger();
        FString Rows = "";
        for (const auto& Row : Ledger.Pieces)
        {
            FString Sears = "";
            for (const auto Sear : Row.FaceSear)
            { Sears += f"{Sear} "; }

            Rows += f"{Row.Id.Generation}.{Row.Id.TransferIndex}:{Row.Status :n}/{Row.Contact :n}/{Row.RestingFace :n}[{Sears}] ";
        }

        const auto Pan = _Searing.Get_PanLedger().Pan;
        return f"ledger=[heat={Ledger.Heat :n} sizzle={Ledger.Sizzle :n} flips={Ledger.Counts.Flips} losses={Ledger.Counts.Losses} takenOut={Ledger.Counts.TakenOut} "
            + f"rows=[{Rows}] takeOutRefusals={Ledger.TakeOutRefusalSerial} last={Ledger.LastTakeOutRefusal :n}] "
            + f"pan=[drive={Pan.Drive :n} tilt={Pan.Tilt} lift={Pan.Lift} kick={Pan.KickTotal} phase={Pan.OrbitPhase}]";
    }

    protected FString Describe_Pan()
    {
        if (ck::Is_NOT_Valid(_Searing))
        { return "pan=[none]"; }

        const auto Pan = _Searing.Get_Pan();
        const auto Summary = _Searing.Get_Summary();
        return f"pan=[hot={_Searing.Get_IsHot()} tilt={Pan.Get_Tilt()} lift={Pan.Get_Lift()} drive={Pan.Get_Drive() :n} steering={Pan.Get_Steering() :n} "
            + f"pieces={_Searing.Get_PieceIds().Num()} admitted={Summary.Admitted} cooking={Summary.Cooking} ready={Summary.Ready} lost={Summary.Lost} takenOut={Summary.TakenOut}] "
            + f"takeable={utils_cooking_feed::Get_TakeableCount(_Station)}";
    }

    // This machine's copy of the piece the pan holds as InId (the ledger row's handle without authority); invalid when it
    // holds none or that copy is not here.
    protected FCk_Handle_FoodPiece Get_PanCopy(FMars_CookingFeed_PieceId InId)
    {
        if (_Searing.Get_HasPiece(InId) == false)
        { return FCk_Handle_FoodPiece(); }

        const auto Entity = _Searing.Get_PieceEntity(InId);
        if (Get_IsLive(Entity) == false || Entity.Is_FoodPiece() == false)
        { return FCk_Handle_FoodPiece(); }

        return Entity.As_FoodPiece();
    }

    // The rows a copy without authority has announced (it raised OnPieceAdded for each); none with authority.
    protected TArray<FMars_CookingFeed_PieceId> Get_AnnouncedRows()
    {
        TArray<FMars_CookingFeed_PieceId> Ids;
        if (Get_IsServer() || ck::Is_NOT_Valid(_Batter) || _Batter.Has_Fragment(FMars_Fragment_Batter_Local) == false)
        { return Ids; }

        for (const auto& Row : _Batter.Get_Fragment(FMars_Fragment_Batter_Local).Rows)
        {
            if (Row.Announce == EMars_Batter_Announce::Announced)
            { Ids.Add(Row.Id); }
        }

        return Ids;
    }

    // InId's row on this machine was announced (always false with authority).
    protected bool Get_IsAnnounced(FMars_CookingFeed_PieceId InId)
    {
        for (const auto& Id : Get_AnnouncedRows())
        {
            if (Id.Get_IsSame(InId))
            { return true; }
        }

        return false;
    }

    // The client steps only once it has its kernel and the heat report reached InStep too.
    protected bool Get_IsStepArrived(int32 InStep) override
    {
        return Super::Get_IsStepArrived(InStep) && Try_FindHeatStation() && Get_HeatStationReport().Step >= InStep;
    }

    // What this copy raised before is not counted from here on.
    protected void Clear_BatterRecord()
    {
        _BowlChanges.Empty();
        _BowlChangeFrames.Empty();
        _AddedIds.Empty();
        _AddedBeforeBind = 0;
        _AdmissionRefusals.Empty();
        _TakeOutRefusals.Empty();
        _TakenOutIds.Empty();
    }

    protected int32 Get_AddedCount(FMars_CookingFeed_PieceId InId)
    {
        auto Count = 0;
        for (const auto& Id : _AddedIds)
        {
            if (Id.Get_IsSame(InId))
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_BowlChangeCount(EMars_Batter_Bowl InBowl)
    {
        auto Count = 0;
        for (const auto Bowl : _BowlChanges)
        {
            if (Bowl == InBowl)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_BatterRecord()
    {
        FString Bowls = "";
        for (const auto Bowl : _BowlChanges)
        { Bowls += f"{Bowl :n} "; }

        FString Added = "";
        for (const auto& Id : _AddedIds)
        { Added += f"{Id.Generation}.{Id.TransferIndex} "; }

        FString Admissions = "";
        for (const auto Refusal : _AdmissionRefusals)
        { Admissions += f"{Refusal :n} "; }

        FString TakeOuts = "";
        for (const auto Refusal : _TakeOutRefusals)
        { TakeOuts += f"{Refusal :n} "; }

        return f"bowls=[{Bowls}] added=[{Added}] addedBeforeBind={_AddedBeforeBind} admissionRefused=[{Admissions}] takeOutRefused=[{TakeOuts}] takenOut={_TakenOutIds.Num()}";
    }

    // The bowl's ledger as this machine reads it.
    protected FString Describe_BatterLedger()
    {
        if (ck::Is_NOT_Valid(_Batter))
        { return "ledger=[none]"; }

        const auto Ledger = _Batter.Get_Ledger();
        FString Rows = "";
        for (const auto& Row : Ledger.Pieces)
        { Rows += f"{Row.Id.Generation}.{Row.Id.TransferIndex}@{Row.Slot}:{Row.Coat} "; }

        return f"ledger=[bowl={Ledger.Bowl :n} serial={Ledger.BowlSerial} rows=[{Rows}] admissionRefusals={Ledger.AdmissionRefusalSerial} last={Ledger.LastAdmissionRefusal :n} takeOutRefusals={Ledger.TakeOutRefusalSerial} last={Ledger.LastTakeOutRefusal :n}]";
    }

    protected FString Describe_Bowl()
    {
        if (ck::Is_NOT_Valid(_Batter))
        { return "bowl=[none]"; }

        return f"bowl=[{_Batter.Get_Bowl() :n} pieces={_Batter.Get_PieceCount()} coated={_Batter.Get_CoatedCount()}] takeable={utils_cooking_feed::Get_TakeableCount(_Station)}";
    }

    // This machine's bowl node.
    protected FCk_Handle_Transform Get_BowlNode()
    {
        return _Batter.Get_Spec().Nodes.Bowl;
    }

    protected bool Get_IsUnderBowl(FCk_Handle_FoodPiece InPiece)
    {
        if (Get_IsLive(InPiece) == false)
        { return false; }

        const auto Parent = Get_Parent(InPiece);
        return ck::IsValid(Parent) && Parent == Get_BowlNode();
    }

    // How far InPiece's offset under this machine's bowl node is from where slot InSlot at InImmersion puts it (cm); -1 when
    // it is not under the bowl.
    protected float64 Get_SlotErrorCm(FCk_Handle_FoodPiece InPiece, int32 InSlot, float32 InImmersion)
    {
        if (Get_IsLive(InPiece) == false || Get_IsUnderBowl(InPiece) == false)
        { return -1.0; }

        auto State = FMars_Batter_PieceState();
        State.Piece = InPiece;
        State.Slot = InSlot;
        State.Immersion = InImmersion;
        const auto Expected = utils_batter::Get_PieceOffset(_Batter.Get_Spec().Bowl, State);
        return Get_Offset(InPiece).GetLocation().Distance(Expected.GetLocation());
    }

    // InPiece wears its battered shell in its display's place on this machine, the shell's dip slot written (logged only:
    // the look is the station's dressing).
    protected bool Get_WearsShell(FCk_Handle_FoodPiece InPiece)
    {
        if (Get_IsLive(InPiece) == false)
        { return false; }

        FCk_Handle Entity = InPiece;
        const auto Shell = utils_food::TryGet_BatteredShell(InPiece);
        return Entity.Is_RuntimeMeshDisplay() && Entity.As_RuntimeMeshDisplay().Get_Visibility() == ECk_EnableDisable::Disable
            && ck::IsValid(Shell) && ck::IsValid(utils_unreal_component::Get_Component(Shell))
            && utils_unreal_component::Get_CustomPrimitiveDataFloat(Shell, 13) > 0.5f;
    }

    // The bowl's slot for InId on this machine; -1 when it holds no such piece.
    protected int32 Get_SlotOf(FMars_CookingFeed_PieceId InId)
    {
        if (_Batter.Get_HasPiece(InId) == false)
        { return -1; }

        return _Batter.Get_PieceState(InId).Slot;
    }

    // This machine's copy of the piece the bowl holds as InId (the ledger row's handle without authority); invalid when it
    // holds none.
    protected FCk_Handle_FoodPiece Get_BowlCopy(FMars_CookingFeed_PieceId InId)
    {
        if (_Batter.Get_HasPiece(InId) == false)
        { return FCk_Handle_FoodPiece(); }

        return _Batter.Get_PieceHandle(InId);
    }

    // This machine's copy of the report's InIndex-th followed piece; invalid when there is none.
    protected FCk_Handle_FoodPiece Get_FollowedCopy(int32 InIndex)
    {
        const auto Report = Get_HeatStationReport();
        if (InIndex >= Report.PieceGuids.Num())
        { return FCk_Handle_FoodPiece(); }

        return Find_PieceById(Report.PieceGuids[InIndex]);
    }

    // This machine's text of the subject's visible row under InOwnerKey on InAction; unset while it shows none.
    protected TOptional<FString> TryGet_Row(FName InOwnerKey, UInputAction InAction)
    {
        if (ck::Is_NOT_Valid(_Display))
        { return TOptional<FString>(); }

        for (auto Row : _Display.Get_VisibleHints())
        {
            const auto Spec = Row.Get_Spec();
            if (Spec.OwnerKey == InOwnerKey && Spec.InputAction.Get() == InAction)
            { return TOptional<FString>(Spec.Text.ToString()); }
        }

        return TOptional<FString>();
    }

    // The dip row (the bowl's operator hints, on the primary action).
    protected FString Get_DipRowText()
    {
        const auto Row = TryGet_Row(n"Batter", mars::Mars_IA_Interact_Primary);
        return Row.IsSet() ? Row.GetValue() : "<no row>";
    }

    // The take-out row (the feed's operator hints, on the secondary action).
    protected FString Get_TakeOutRowText()
    {
        const auto Row = TryGet_Row(n"StationFeed", mars::Mars_IA_Interact_Secondary);
        return Row.IsSet() ? Row.GetValue() : "<no row>";
    }

    // Some sampled frame, at any step, showed a label containing InText.
    protected bool Get_SawLabelAtAnyStep(FString InText)
    {
        for (const auto& Seen : _LabelsSeen)
        {
            if (Seen.Text.Contains(InText))
            { return true; }
        }

        return false;
    }

    // This machine's tray: the large platter world item near the test's X that is not the rig's platter.
    protected bool Try_FindTray()
    {
        if (ck::IsValid(_Tray))
        { return true; }

        if (Try_FindPlatter() == false)
        { return false; }

        const auto Capacity = Get_CapacityOf(mars_items::Platter_Large());
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) == false || Candidate.Is_Transform() == false || Candidate.Is_Platter() == false
                || Candidate.Has_Fragment(FMars_Fragment_Platter_Params) == false || Get_IsNear(Candidate, _FloorTop) == false)
            { continue; }

            if (Candidate.As_Platter().Get_Capacity() == Capacity && Candidate.As_Platter() != _Platter)
            {
                _Tray = Candidate.As_Platter();
                return true;
            }
        }

        return false;
    }

    protected FCk_Handle_WorldItem Get_TrayWorldItem()
    {
        FCk_Handle Entity = _Tray;
        return Entity.As_WorldItem(ECk_SanityCheck::UnChecked);
    }

    protected void On_FeedStationSample() override
    {
        if (Try_FindHeatStation() == false)
        { return; }

        Sample_Pan();
        On_HeatStationSample();
    }

    // The pan as this machine shows it this frame (the searing station only).
    private void Sample_Pan()
    {
        if (ck::Is_NOT_Valid(_Searing))
        { return; }

        const auto Now = System::GetGameTimeInSeconds();
        const auto Pan = _Searing.Get_Pan();
        auto Sample = FMars_TESTONLY_NetHeatPanSample();
        Sample.Step = Get_HeatStationReport().Step;
        Sample.Frame = utils_time::Get_FrameCounter();
        Sample.Seconds = Now;
        Sample.DeltaSeconds = _LastPanSampleSeconds < 0.0 ? 0.0f : float32(Now - _LastPanSampleSeconds);
        Sample.Roll = float32(_Searing.Get_PanTilt().Roll);
        Sample.Lift = _Searing.Get_PanLift();
        Sample.NodeLocation = Pan.Get_NodeWorld().GetLocation();
        Sample.Heat = _Searing.Get_IsHot() ? EMars_Searing_Heat::Hot : EMars_Searing_Heat::Cold;
        _PanSamples.Add(Sample);
        _LastPanSampleSeconds = Now;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Report
    //----------------------------------------------------------------------------------------------------------------------

    protected void Add_HeatStationReport()
    {
        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetHeatStationReport) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetHeatStationReport(), ECk_Replication::Replicates); }
    }

    protected FMars_Fragment_TESTONLY_NetHeatStationReport Get_HeatStationReport()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetHeatStationReport);
    }

    // Server: step InStep in all three reports, the followed pieces' ids, the bowl's ids and serial and the first followed
    // piece's coat.
    protected void Report_HeatStep(int32 InStep)
    {
        Write_HeatStationReport(InStep);
        Report_Step(InStep, Get_FirstFollowed());
    }

    // Server: as Report_HeatStep, with InPlatter's frozen pieces as the platter report's rides.
    protected void Report_HeatStepWithRidesOf(int32 InStep, FCk_Handle_Platter InPlatter)
    {
        Write_HeatStationReport(InStep);
        Report_StepWithRidesOf(InStep, InPlatter, Get_FirstFollowed());
    }

    private FCk_Handle_FoodPiece Get_FirstFollowed()
    {
        return _Followed.Num() > 0 ? _Followed[0] : FCk_Handle_FoodPiece();
    }

    private void Write_HeatStationReport(int32 InStep)
    {
        TArray<FGuid> Guids;
        for (const auto& Piece : _Followed)
        { Guids.Add(Piece.Get_Id()); }

        TArray<FMars_CookingFeed_PieceId> BowlIds;
        auto Coat = -1.0f;
        auto BowlSerial = 0;
        if (ck::IsValid(_Searing))
        { BowlIds = _Searing.Get_PieceIds(); }
        else
        {
            BowlIds = _Batter.Get_PieceIds();
            for (const auto& Id : BowlIds)
            {
                if (_Followed.Num() > 0 && _Batter.Get_PieceHandle(Id) == _Followed[0])
                { Coat = _Batter.Get_PieceCoat(Id); }
            }

            BowlSerial = _Batter.Get_Ledger().BowlSerial;
        }

        auto Subject = Get_SubjectEntity();
        auto& Report = Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetHeatStationReport);
        Report.Serial += 1;
        Report.Step = InStep;
        Report.PieceGuids = Guids;
        Report.BowlIds = BowlIds;
        Report.Coat = Coat;
        Report.BowlSerial = BowlSerial;
        Report.EventFrame = int32(_EventFrame);
        Report.Value = _ReportValue;
        Report.Face = _ReportFace;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetHeatStationReport);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the station, the foods, the tray
    //----------------------------------------------------------------------------------------------------------------------

    // Server: the hooked station beside the platter under the spawn owner, through the heat-station fixture, tracked;
    // On_ServerFeedStationReady once this machine finds it composed with its kernel.
    protected void Spawn_HeatStation()
    {
        if (ck::EnsureIfNot(Get_HeatStation() == EMars_TESTONLY_HeatStation::Batter || Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing,
            f"[NetHeatStation] the {Get_HeatStation() :n} branch is not built yet"))
        { return; }

        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        { _FeedStationEntity = Spawn_SearingStation(Owner); }
        else
        {
            auto Fixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation));
            auto Pending = Fixture.Spawn_Batter(Owner, Get_StationLocation(), Make_BatterSpec().Coat.CoatSeconds);
            _FeedStationEntity = Pending.Get_EntityUnderConstruction();
        }

        Track_ForCleanup(_FeedStationEntity);
        WaitUntil(n"Is_RigHeatStationReady", n"OnRigHeatStationReady", k_SlowPolls);
    }

    // The real searing station with the test's exposed Searing spec, as the map's spawner makes it (its own context).
    private FCk_Handle Spawn_SearingStation(FCk_Handle InOwner)
    {
        auto Params = UMars_SearingStation_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, Get_StationLocation());
        Params.Searing = Make_SearingSpec();
        auto Station = utils_entity_script::Request_SpawnEntity(InOwner, UMars_SearingStation_EntityScript, Params).Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        return Station;
    }

    // The searing station is ready once its pan body is in the simulation (the pan admits nothing before).
    UFUNCTION()
    private void Is_RigHeatStationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_FeedStationEntity) && _FeedStationEntity.Is_CookingFeed() && Try_FindHeatStation()
            && (ck::Is_NOT_Valid(_Searing) || utils_jolt_body::Get_IsBodyAdded(_Searing.Get_Spec().Nodes.PanBaseBody)));
    }

    UFUNCTION()
    private void OnRigHeatStationReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Station == _FeedStationEntity, "the server finds the station it spawned");
        if (_ServerActsOnFirstFind)
        {
            On_ServerFeedStationReady();
            return;
        }

        WaitSeconds(k_StepGapSeconds, n"OnRigHeatStationListened");
    }

    UFUNCTION()
    private void OnRigHeatStationListened(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        On_ServerFeedStationReady();
    }

    // Server: InCount whole foods of InItem lying loose beside the platter, tracked, in _Foods; InContinuation once every
    // one is Ready.
    protected void Spawn_FoodsThen(UCk_InventoryItem_Definition InItem, int32 InCount, FName InContinuation)
    {
        for (int32 Index = 0; Index < InCount; ++Index)
        {
            const auto Local = constants_heat_station_net_autotest::k_FoodLocal
                + FVector(constants_heat_station_net_autotest::k_FoodSpacingCm * float64(Index), 0.0, 0.0);
            _Foods.Add(Spawn_ServerFood(InItem, _FloorTop + Local));
        }

        _FoodsContinuation = InContinuation;
        WaitUntil(n"Is_RigFoodsReady", n"OnRigFoodsReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigFoodsReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto IsReady = true;
        for (const auto& Food : _Foods)
        {
            if (Get_IsFoodReady(Food) == false)
            { IsReady = false; }
        }

        auto Result = OutResult;
        Result.Set(IsReady);
    }

    UFUNCTION()
    private void OnRigFoodsReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _FoodsContinuation);
    }

    // Server: a meat slab lying loose beyond the foods, cut through its middle; InContinuation once its positive half is
    // Ready (in _CutHalf).
    protected void Spawn_CutHalfThen(FName InContinuation)
    {
        const auto Local = constants_heat_station_net_autotest::k_FoodLocal
            + FVector(-constants_heat_station_net_autotest::k_FoodSpacingCm, -60.0, 0.0);
        _CutSlab = Spawn_ServerFood(mars_items::Food_MeatSlab(), _FloorTop + Local);
        _CutContinuation = InContinuation;
        WaitUntil(n"Is_RigSlabReady", n"OnRigSlabReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigSlabReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsFoodReady(_CutSlab));
    }

    UFUNCTION()
    private void OnRigSlabReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Cut(_CutSlab.As_FoodPiece(), Make_CentrePlane());
        WaitUntil(n"Is_RigCutHalfReady", n"OnRigCutHalfReady", k_SlowPolls);
    }

    // The positive half of the first cut that cut; invalid while none did.
    private FCk_Handle_FoodPiece Get_CutPositive()
    {
        for (const auto& CutResult : _Cuts)
        {
            if (CutResult.Outcome == EMars_FoodPiece_CutOutcome::Cut)
            { return CutResult.Positive; }
        }

        return FCk_Handle_FoodPiece();
    }

    UFUNCTION()
    private void Is_RigCutHalfReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Half = Get_CutPositive();
        auto Result = OutResult;
        Result.Set(Get_IsLive(Half) && Half.Get_Status() == EMars_FoodPiece_Status::Ready);
    }

    UFUNCTION()
    private void OnRigCutHalfReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _CutHalf = Get_CutPositive();
        WaitFrames(1, _CutContinuation);
    }

    // Server: an empty large platter beside the platter, tracked, docked on the Output dock; InContinuation once it arrived.
    protected void Dock_TrayThen(FName InContinuation)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        const auto Root = FTransform(FRotator::ZeroRotator,
            _FloorTop + FVector(k_BesideCm, 0.0, constants_platter::k_FloorAboveBase + 0.5));
        _TrayEntity = utils_platter::Request_SpawnWorld(Owner, FMars_Platter_SpawnSpec(Root, mars_items::Platter_Large()));
        Track_ForCleanup(_TrayEntity);
        _TrayContinuation = InContinuation;
        WaitUntil(n"Is_RigTrayBuilt", n"OnRigTrayBuilt", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigTrayBuilt(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_TrayEntity) && _TrayEntity.Is_Platter() && _TrayEntity.Has_Fragment(FMars_Feature_WorldItem) && Try_FindTray()
            && ck::IsValid(Get_TrayWorldItem().Get_Item()));
    }

    UFUNCTION()
    private void OnRigTrayBuilt(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_Tray == _TrayEntity, "the server finds the tray it spawned");
        auto Dock = _OutputDock;
        Dock.Request_Dock(FMars_Request_PlatterDock_Dock(Get_TrayWorldItem().Get_Item()));
        WaitUntil(n"Is_RigTrayArrived", n"OnRigTrayArrived", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigTrayArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_OutputDock.Get_Platter() == _Tray && _OutputDock.Get_HasArrived());
    }

    UFUNCTION()
    private void OnRigTrayArrived(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _TrayContinuation);
    }

    // Server: InPiece released over the station's release node into its admission inbox, as piece {k_RigGeneration, N}
    // (N counting the rig's admissions); the id.
    protected FMars_CookingFeed_PieceId Admit(FCk_Handle_FoodPiece InPiece)
    {
        const auto PieceId = FMars_CookingFeed_PieceId(constants_heat_station_net_autotest::k_RigGeneration, _AdmitIndex);
        ++_AdmitIndex;
        const auto ReleaseWorld = utils_transform::Get_EntityCurrentTransform(_Feed.Get_ReleaseNode());
        auto Release = FMars_CookingFeed_Release(PieceId, ReleaseWorld, FVector::ZeroVector);
        Release.Piece = InPiece;
        auto Station = _Station;
        Assert_True(utils_cooking_feed::Request_Admit(Station, Release), "the station takes the release into its inbox");
        return PieceId;
    }

    // Server: a station take-out onto the tray, capped at the tray's room as the press reads it.
    protected void Request_TakeOutToTray()
    {
        auto Station = _Station;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(4, _Tray));
    }

    // Server: a station take-out naming no tray (the press with none docked).
    protected void Request_TakeOutWithoutTray()
    {
        auto Station = _Station;
        utils_cooking_feed::Request_StationTakeOut(Station, FMars_Request_StationTakeOut(4, FCk_Handle_Platter()));
    }

    // Server: InPiece's cook state with all six faces seared; InContinuation once it reads so.
    protected void Sear_AllRoundThen(FCk_Handle_FoodPiece InPiece, FName InContinuation)
    {
        auto Piece = InPiece;
        auto CookState = Piece.Get_CookState();
        for (int32 Index = 0; Index < CookState.Sear.Num(); ++Index)
        { CookState.Sear[Index] = 1.0f; }

        Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        _SearAllRoundPiece = Piece;
        _SearAllRoundContinuation = InContinuation;
        WaitUntil(n"Is_RigSearedAllRound", n"OnRigSearedAllRound", k_SlowPolls);
    }

    // Every face of InCookState reads seared (six of them).
    protected bool Get_IsSearedAllRound(FMars_FoodPiece_CookState InCookState)
    {
        if (InCookState.Sear.Num() != 6)
        { return false; }

        for (const auto Sear : InCookState.Sear)
        {
            if (Sear < 1.0f)
            { return false; }
        }

        return true;
    }

    UFUNCTION()
    private void Is_RigSearedAllRound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSearedAllRound(_SearAllRoundPiece.Get_CookState()));
    }

    UFUNCTION()
    private void OnRigSearedAllRound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _SearAllRoundContinuation);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the operator
    //----------------------------------------------------------------------------------------------------------------------

    // Every row starts at the seed serial, released, and the look total at zero.
    private void Reset_RemoteRows()
    {
        _RemoteRows.Empty();
        _LookTotal = FVector::ZeroVector;
        auto Intents = TArray<FGameplayTag>();
        Intents.Add(GameplayTags::Mars_Intent_Interact_Primary);
        Intents.Add(GameplayTags::Mars_Intent_Interact_Secondary);
        Intents.Add(GameplayTags::Mars_Intent_StationAddFood);
        for (const auto& Intent : Intents)
        {
            auto Row = FMars_TESTONLY_NetHeatRemoteRow();
            Row.Intent = Intent;
            Row.PressSerial = constants_feed_station_net_autotest::k_SeedSerial;
            _RemoteRows.Add(Row);
        }
    }

    // Server: one remote sample carrying the look total and every row as it stands now.
    protected void Apply_RemoteSample()
    {
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.LookTotal = _LookTotal;
        for (const auto& Row : _RemoteRows)
        { Sample.Intents.Add(FMars_InputIntents_RemoteIntent(Row.Intent, Row.PressSerial, Row.Hold)); }

        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
    }

    // Server: InIntent goes down (one press more, held), in one sample.
    protected void Hold_Remote(FGameplayTag InIntent)
    {
        Edit_RemoteRow(InIntent, 1, EMars_InputIntents_Hold::Held);
        Apply_RemoteSample();
    }

    // Server: InIntent comes up (no press more, released), in one sample.
    protected void LetGo_Remote(FGameplayTag InIntent)
    {
        Edit_RemoteRow(InIntent, 0, EMars_InputIntents_Hold::Released);
        Apply_RemoteSample();
    }

    // Server: InIntent pressed and released between two samples (one press more, released), in one sample.
    protected void Press_Remote(FGameplayTag InIntent)
    {
        if (InIntent == GameplayTags::Mars_Intent_StationAddFood)
        { _PressFrame = utils_time::Get_FrameCounter(); }

        Edit_RemoteRow(InIntent, 1, EMars_InputIntents_Hold::Released);
        Apply_RemoteSample();
    }

    private void Edit_RemoteRow(FGameplayTag InIntent, int32 InPresses, EMars_InputIntents_Hold InHold)
    {
        for (int32 Index = 0; Index < _RemoteRows.Num(); ++Index)
        {
            if (_RemoteRows[Index].Intent != InIntent)
            { continue; }

            auto Row = _RemoteRows[Index];
            Row.PressSerial += InPresses;
            Row.Hold = InHold;
            _RemoteRows[Index] = Row;
            return;
        }

        ck::EnsureIfNot(false, f"[NetHeatStation] keeps no remote row for {InIntent.ToString()}");
    }

    // Server: the seed (every row at the seed serial, released), then InContinuation k_SeedFrames frames later.
    protected void Seed_HeatRemoteThen(FName InContinuation)
    {
        Reset_RemoteRows();
        Apply_RemoteSample();
        WaitFrames(constants_feed_station_net_autotest::k_SeedFrames, InContinuation);
    }

    // Server: seats the subject, seeds its remote state, then InContinuation.
    protected void Seat_OperatorThen(FName InContinuation)
    {
        auto Station = _Station.As_Station();
        Station.Request_Reserve(FMars_Request_Station_Reserve(Get_SubjectEntity()));
        _OperatorContinuation = InContinuation;
        WaitUntil(n"Is_RigHeatOperating", n"OnRigHeatOperating", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigHeatOperating(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSubjectOperating());
    }

    UFUNCTION()
    private void OnRigHeatOperating(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Seed_HeatRemoteThen(_OperatorContinuation);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Endings
    //----------------------------------------------------------------------------------------------------------------------

    // The server's last step: logs InText, then the base rig's ending (it holds while the client asserts).
    protected void End_HeatServer(FString InText)
    {
        Log_HeatStation(InText);
        End_FeedStationServer(f"see {Get_LogTag()}");
    }

    protected void End_HeatClient(FString InText)
    {
        Log_HeatStation(InText);
        End_FeedStationClient(f"see {Get_LogTag()}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRigBowlChanged(FCk_Handle_Batter InBatter, EMars_Batter_Bowl InBowl)
    {
        _BowlChanges.Add(InBowl);
        _BowlChangeFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRigPieceAdded(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _AddedIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnRigAdmissionRefused(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_AdmissionRefusal InRefusal)
    {
        _AdmissionRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigTakeOutRefused(FCk_Handle_Batter InBatter, EMars_Batter_TakeOutRefusal InRefusal)
    {
        _TakeOutRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigPieceTakenOut(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle_FoodPiece InPiece)
    {
        _TakenOutIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnRigHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat)
    {
        _HeatChanges.Add(InHeat);
    }

    UFUNCTION()
    private void OnRigPanPieceAdded(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _PanAddedIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnRigFaceSeared(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_FoodPiece_Face InFace)
    {
        _SearedIds.Add(InPieceId);
        _SearedFaces.Add(InFace);
    }

    UFUNCTION()
    private void OnRigPanTakeOutRefused(FCk_Handle_Searing InSearing, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        _PanTakeOutRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigPieceLost(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _LostIds.Add(InPieceId);
    }
}
