// The real heat stations' net tests' shared steps, on the feed station net rig (its platter, its reports, its docks, its
// operator, its sampler and its clean endings). A protected hook names the station the server spawns
// (EMars_TESTONLY_HeatStation) and its exposed spec; the server spawns it through the heat-station fixture under the
// replicated spawn owner, as the map's spawner makes it (its own context), and each machine finds its own copy as the
// base rig finds its station, then its kernel, whose signals it records in order from then on. The rig adds: a remote
// sample (the server applies one FMars_InputIntents_RemoteSample built from a look total, its seconds and every operator
// row it keeps, each with its running press serial and hold), a remote look, holding a row and letting it go, pressing it;
// admitting a piece (the server queues a release of it over the station's release node in the station's admission inbox,
// as the feed does); the
// subject's dip and take-out rows; a tray (an empty large platter docked on the Output dock); and a third test-only
// replicated report on the subject with the followed pieces, the bowl's ids, a coat and the bowl's serial (the pan's ids,
// a number and a face at the searing station). The Searing branch spawns the real searing station with the test's exposed
// Searing spec (ready once its pan body is in the simulation on the server), records the kernel's signals and samples the
// pan every frame (its roll, its lift, its node's location). The Fry branch spawns the real fry station with the test's
// exposed Fry spec (ready once its scoop and basket bodies are in the simulation on the server), records the kernel's
// signals and samples the scoop every frame (its root-frame location, the skim, the first row's face heats); its report also
// carries a root-frame target and a scoop location. The Tumbler branch spawns the real tumbler station with the test's
// exposed Tumbler spec (ready once its drum body is in the simulation on the server), records the kernel's signals and
// samples its Movers every frame (the axle's alpha, target, tween and rest, the hinge's alpha and rest, the hand node's
// offset, the first row's coverage); its remote rows add Use, and it points the cursor and rocks the lever, on the server's
// own kernel or in the operator's stream. A test that sets _HeatStationBirth to Born has the server spawn the hooked
// station's born class (its authority issues its kernel's requests as it composes), and each machine watches its copy
// by the born test tag from its construct, whatever its docks: the kernel's signals with their frames and, off
// authority, each rep-notify of the kernel's ledger and every frame a born bowl's piece sits under its bowl node; at a
// born fryer also each rep-notify of the skimmer's ledger and every frame its skimmer has taken that ledger's command.
// One [BatterNetTest], [SearingNetTest], [FryNetTest] or [TumblerNetTest] line per test per machine.

namespace constants_heat_station_net_autotest
{
    const float32 k_CoatSeconds = 0.6f;
    // The generation of every release the rig queues by hand: never one a feed hands out in these tests.
    const int32 k_RigGeneration = 9000;
    const float64 k_OffsetToleranceCm = 0.5;
    // Where the rig's loose foods lie, beside the platter (away from the station's counter), k_FoodSpacingCm apart in X.
    const FVector k_FoodLocal = FVector(-90.0, -150.0, 5.0);
    const float64 k_FoodSpacingCm = 90.0;
    // What a pointing look took on the sender.
    const float32 k_PointLookSeconds = 0.1f;
    // Where a look away puts the tumbler's cursor, as a share of the reach's half extents (down and to the left).
    const float64 k_AwayCursorShare = 0.6;
    // The server's axle is still once its alpha moved less than this between the first polls of this many frames in a row.
    const float32 k_StillAlpha = 0.0005f;
    const int32 k_StillFrames = 10;
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

    // At the fryer: a root-frame target (Z 0) and the scoop's root-frame location the test reports.
    UPROPERTY()
    FVector Target = FVector::ZeroVector;

    UPROPERTY()
    FVector Scoop = FVector::ZeroVector;
}

// One frame of this machine's scoop, as the sampler read it.
struct FMars_TESTONLY_NetHeatScoopSample
{
    int32 Step = 0;
    int64 Frame = 0;
    float64 Seconds = 0.0;
    FVector Root = FVector::ZeroVector;
    EMars_Fry_Skim Skim = EMars_Fry_Skim::Carry;
    int32 Rows = 0;
    // The first ledger row's six face heats on this machine (empty without a row).
    TArray<float32> FirstRowHeat;
}

// One frame of this machine's tumbler Movers and hand node, as the sampler read it.
struct FMars_TESTONLY_NetHeatMoverSample
{
    int32 Step = 0;
    int64 Frame = 0;
    float64 Seconds = 0.0;
    float32 AxleAlpha = 0.0f;
    EMars_Mover_Pose AxleTarget = EMars_Mover_Pose::Start;
    bool AxleTweening = false;
    bool AxleResting = false;
    // This machine's lever Control holds a manipulation (only the authority's should).
    bool LeverManipulating = false;
    float32 HingeAlpha = 0.0f;
    bool HingeResting = false;
    FVector HandOffset = FVector::ZeroVector;
    // The first ledger row's coverage on this machine; -1 without a row.
    float32 FirstCoverage = -1.0f;
}

// How the rig sends a look at the tumbler: on the server's own copy of the kernel, or in the remote operator's stream.
enum EMars_TESTONLY_NetTumblerLook
{
    Kernel,
    Remote
}

// The rig's rocking loop: Seconds of one look a frame of Degrees along the lever's pull, its sign flipping every
// HalfCycleFrames frames (0: never).
struct FMars_TESTONLY_NetTumblerRock
{
    float32 Seconds = 1.0f;
    float64 Degrees = 0.5;
    int32 HalfCycleFrames = 0;
    EMars_TESTONLY_NetTumblerLook Look = EMars_TESTONLY_NetTumblerLook::Kernel;
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

// Which class of the hooked station the server spawns: the station itself, or its born class (whose authority issues
// its kernel's requests as it composes, so a copy is born into what that drain wrote).
enum EMars_TESTONLY_HeatStationBirth
{
    Plain,
    Born
}

enum EMars_TESTONLY_NetHeatBornEventKind
{
    BowlChanged,
    PieceAdded,
    AdmissionRefused,
    TakeOutRefused,
    HeatChanged,
    FaceSeared,
    PressRefused,
    HatchChanged,
    SkimChanged,
    SkimRefused
}

// One signal the watched born station's kernel raised on this machine: its frame, and the level it carries (the bowl,
// the heat, the hatch or the skim; 0 for the others).
struct FMars_TESTONLY_NetHeatBornEvent
{
    EMars_TESTONLY_NetHeatBornEventKind Kind = EMars_TESTONLY_NetHeatBornEventKind::BowlChanged;
    int64 Frame = 0;
    int32 Value = 0;
}

// One frame of a born bowl's piece seated under its bowl node on this machine: the ledger's bowl then, and how far the
// piece's offset is from where its slot puts it fully under (cm).
struct FMars_TESTONLY_NetHeatBornBowlSample
{
    int64 Frame = 0;
    EMars_Batter_Bowl Bowl = EMars_Batter_Bowl::Resting;
    float64 DippedErrorCm = -1.0;
}

// One frame of a born fryer's skimmer on this machine once it has taken its ledger's command: that ledger, and how far
// its shown lift and slide are from their targets (cm).
struct FMars_TESTONLY_NetHeatBornSkimmerSample
{
    int64 Frame = 0;
    FMars_Fragment_Fry_SkimmerNet Ledger;
    float64 LiftErrorCm = -1.0;
    float64 SlideErrorCm = -1.0;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetHeatStation : UMars_AutoTestRig_NetFeedStation
{
    default _TimeoutSeconds = 25.0f;

    // A scoop this close to its commanded slide or lift has arrived there.
    protected const float64 k_ScoopSettledCm = 0.5;

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

    // This machine's copy of the fryer's kernel, once found, and every signal it raised since (or since Clear_FryRecord).
    protected FCk_Handle_Fry _Fry;
    protected TArray<EMars_Fry_Skim> _SkimChanges;
    protected TArray<FMars_CookingFeed_PieceId> _FryAddedIds;
    protected TArray<EMars_Fry_Skim> _SkimRefusals;
    protected TArray<EMars_CookingFeed_TakeOutRefusal> _FryTakeOutRefusals;
    protected TArray<EMars_Fry_AdmissionRefusal> _FryAdmissionRefusals;
    protected TArray<FMars_CookingFeed_PieceId> _StageIds;
    // In parallel with _StageIds.
    protected TArray<EMars_FoodPiece_Face> _StageFaces;
    protected TArray<EMars_Fry_HeatStage> _Stages;
    protected TArray<FMars_CookingFeed_PieceId> _DrainedIds;
    // Every sampled frame of this machine's scoop since it was found.
    protected TArray<FMars_TESTONLY_NetHeatScoopSample> _ScoopSamples;

    // This machine's copy of the tumbler's kernel, once found, and every signal it raised since (or since
    // Clear_TumblerRecord).
    protected FCk_Handle_Tumbler _Tumbler;
    protected TArray<EMars_Tumbler_Hatch> _HatchChanges;
    protected TArray<EMars_Tumbler_Target> _HoverChanges;
    protected TArray<EMars_Tumbler_Drum> _DrumChanges;
    protected TArray<EMars_Tumbler_HandMode> _HandModeChanges;
    protected TArray<EMars_Tumbler_Refusal> _PressRefusals;
    protected TArray<EMars_CookingFeed_TakeOutRefusal> _TumblerTakeOutRefusals;
    protected TArray<FMars_CookingFeed_PieceId> _TumblerAddedIds;
    // Every sampled frame of this machine's tumbler since it was found.
    protected TArray<FMars_TESTONLY_NetHeatMoverSample> _MoverSamples;

    // Server: what the next report carries as its number, its face, its target and its scoop.
    protected float32 _ReportValue = 0.0f;
    protected int32 _ReportFace = -1;
    protected FVector _ReportTarget = FVector::ZeroVector;
    protected FVector _ReportScoop = FVector::ZeroVector;

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

    // Set before Begin_HeatStationRig: Born spawns the hooked station's born class, which every machine watches by its
    // test tag from its construct, whatever its docks.
    protected EMars_TESTONLY_HeatStationBirth _HeatStationBirth = EMars_TESTONLY_HeatStationBirth::Plain;
    // This machine's born station once watched, the frame it was found, its kernel's InitialState then, every signal
    // its kernel raised from then on, and (off authority) each rep-notify of the kernel's ledger: its frame and the
    // ledger as it then read. Also the frame the sampler first saw the rig's own find (which waits for the docks) done.
    protected FCk_Handle _BornStation;
    protected int64 _BornFoundFrame = -1;
    protected EMars_Net_InitialState _BornInitialAtFind = EMars_Net_InitialState::Awaited;
    protected int64 _BornRigFoundFrame = -1;
    protected TArray<FMars_TESTONLY_NetHeatBornEvent> _BornEvents;
    // In parallel with the PieceAdded events.
    protected TArray<FMars_CookingFeed_PieceId> _BornAddedIds;
    protected TArray<int64> _BornNotifyFrames;
    protected TArray<FMars_Fragment_Batter_Net> _BornBatterLedgers;
    protected TArray<FMars_Fragment_Searing_Net> _BornSearingLedgers;
    protected TArray<FMars_Fragment_Tumbler_Net> _BornTumblerLedgers;
    protected TArray<FMars_Fragment_Fry_Net> _BornFryLedgers;
    // Off authority, at a born bowl: every sampled frame its ledger has a row whose piece sits under the bowl node.
    protected TArray<FMars_TESTONLY_NetHeatBornBowlSample> _BornBowlSamples;
    // At a born fryer: its SkimmerInitialState at the find; off authority, each rep-notify of the skimmer's ledger (its
    // frame and the ledger as it then read) and every sampled frame the skimmer had taken the ledger's command.
    protected EMars_Net_InitialState _BornSkimmerInitialAtFind = EMars_Net_InitialState::Awaited;
    protected TArray<int64> _BornSkimmerNotifyFrames;
    protected TArray<FMars_Fragment_Fry_SkimmerNet> _BornSkimmerLedgers;
    protected TArray<FMars_TESTONLY_NetHeatBornSkimmerSample> _BornSkimmerSamples;

    private bool _WasHeatStationFound = false;
    private int32 _AdmitIndex = 0;
    private TArray<FMars_TESTONLY_NetHeatRemoteRow> _RemoteRows;
    private FVector _LookTotal = FVector::ZeroVector;
    private float32 _LookSeconds = 0.0f;
    private FCk_Handle _CutSlab;
    private FName _FoodsContinuation;
    private FName _CutContinuation;
    private FName _TrayContinuation;
    private FName _OperatorContinuation;
    private FCk_Handle_FoodPiece _SearAllRoundPiece;
    private FName _SearAllRoundContinuation;
    private float64 _LastPanSampleSeconds = -1.0;
    private TArray<FCk_Handle_FoodPiece> _BatterPieces;
    private FName _BatterContinuation;
    private TArray<FCk_Handle_FoodPiece> _CrumbPieces;
    private float32 _Crumb = 0.0f;
    private FName _CrumbContinuation;
    private FMars_TESTONLY_NetTumblerRock _TumblerRock;
    private FName _RockContinuation;
    private float64 _RockStartSeconds = 0.0;
    private float64 _RockLastSeconds = 0.0;
    private int32 _RockFrames = 0;
    private EMars_Tumbler_Target _PointTarget = EMars_Tumbler_Target::None;
    private EMars_TESTONLY_NetTumblerLook _LookRoute = EMars_TESTONLY_NetTumblerLook::Kernel;
    private FName _PointContinuation;
    private FName _StillContinuation;
    private int32 _StillFrames = 0;
    private int64 _StillFrame = -1;
    private float32 _StillAlpha = -1.0f;
    private bool _WasBornStationWatched = false;

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

    // The fry station's exposed spec.
    protected FMars_Fry_Spec Make_FrySpec() const
    {
        return FMars_Fry_Spec();
    }

    // The tumbler station's exposed spec.
    protected FMars_Tumbler_Spec Make_TumblerSpec() const
    {
        return FMars_Tumbler_Spec();
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
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        { return "[FryNetTest]"; }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        { return "[TumblerNetTest]"; }

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

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        { return Try_FindSearing(); }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        { return Try_FindFry(); }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        { return Try_FindTumbler(); }

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

    private bool Try_FindFry()
    {
        if (_Station.Is_Fry() == false)
        { return false; }

        _WasHeatStationFound = true;
        _Fry = _Station.As_Fry();
        // A row this copy announced before the rig bound raised OnPieceAdded all the same.
        _FryAddedIds.Append(Get_FryAnnouncedRows());
        _Fry.BindTo_OnPieceAdded(FMars_Delegate_Fry_OnPieceAdded(this, n"OnRigFryPieceAdded"));
        _Fry.BindTo_OnSkimChanged(FMars_Delegate_Fry_OnSkimChanged(this, n"OnRigSkimChanged"));
        _Fry.BindTo_OnSkimRefused(FMars_Delegate_Fry_OnSkimRefused(this, n"OnRigSkimRefused"));
        _Fry.BindTo_OnTakeOutRefused(FMars_Delegate_Fry_OnTakeOutRefused(this, n"OnRigFryTakeOutRefused"));
        _Fry.BindTo_OnAdmissionRefused(FMars_Delegate_Fry_OnAdmissionRefused(this, n"OnRigFryAdmissionRefused"));
        _Fry.BindTo_OnFaceHeatStage(FMars_Delegate_Fry_OnFaceHeatStage(this, n"OnRigFaceHeatStage"));
        _Fry.BindTo_OnPieceDrained(FMars_Delegate_Fry_OnPieceDrained(this, n"OnRigPieceDrained"));
        return true;
    }

    private bool Try_FindTumbler()
    {
        if (_Station.Is_Tumbler() == false)
        { return false; }

        _WasHeatStationFound = true;
        _Tumbler = _Station.As_Tumbler();
        // A row this copy announced before the rig bound raised OnPieceAdded all the same.
        _TumblerAddedIds.Append(Get_TumblerAnnouncedRows());
        _Tumbler.BindTo_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnRigHatchChanged"));
        _Tumbler.BindTo_OnHoverChanged(FMars_Delegate_Tumbler_OnHoverChanged(this, n"OnRigHoverChanged"));
        _Tumbler.BindTo_OnDrumChanged(FMars_Delegate_Tumbler_OnDrumChanged(this, n"OnRigDrumChanged"));
        _Tumbler.BindTo_OnHandModeChanged(FMars_Delegate_Tumbler_OnHandModeChanged(this, n"OnRigHandModeChanged"));
        _Tumbler.BindTo_OnPressRefused(FMars_Delegate_Tumbler_OnPressRefused(this, n"OnRigPressRefused"));
        _Tumbler.BindTo_OnTakeOutRefused(FMars_Delegate_Tumbler_OnTakeOutRefused(this, n"OnRigTumblerTakeOutRefused"));
        _Tumbler.BindTo_OnPieceAdded(FMars_Delegate_Tumbler_OnPieceAdded(this, n"OnRigTumblerPieceAdded"));
        return true;
    }

    // The ledger rows a copy without authority has announced (it raised OnPieceAdded for each); none with authority.
    protected TArray<FMars_CookingFeed_PieceId> Get_TumblerAnnouncedRows()
    {
        TArray<FMars_CookingFeed_PieceId> Ids;
        if (Get_IsServer() || ck::Is_NOT_Valid(_Tumbler) || _Tumbler.Has_Fragment(FMars_Fragment_Tumbler_Local) == false)
        { return Ids; }

        return _Tumbler.Get_Fragment(FMars_Fragment_Tumbler_Local).Announced;
    }

    protected void Clear_TumblerRecord()
    {
        _HatchChanges.Empty();
        _HoverChanges.Empty();
        _DrumChanges.Empty();
        _HandModeChanges.Empty();
        _PressRefusals.Empty();
        _TumblerTakeOutRefusals.Empty();
        _TumblerAddedIds.Empty();
    }

    protected int32 Get_TumblerAddedCount(FMars_CookingFeed_PieceId InId)
    {
        auto Count = 0;
        for (const auto& Id : _TumblerAddedIds)
        {
            if (Id.Get_IsSame(InId))
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_HatchChangeCount(EMars_Tumbler_Hatch InHatch)
    {
        auto Count = 0;
        for (const auto Hatch : _HatchChanges)
        {
            if (Hatch == InHatch)
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_HoverChangeCount(EMars_Tumbler_Target InTarget)
    {
        auto Count = 0;
        for (const auto Target : _HoverChanges)
        {
            if (Target == InTarget)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_TumblerRecord()
    {
        FString Hatches = "";
        for (const auto Hatch : _HatchChanges)
        { Hatches += f"{Hatch :n} "; }

        FString Hovers = "";
        for (const auto Target : _HoverChanges)
        { Hovers += f"{Target :n} "; }

        FString Drums = "";
        for (const auto Drum : _DrumChanges)
        { Drums += f"{Drum :n} "; }

        FString Modes = "";
        for (const auto Mode : _HandModeChanges)
        { Modes += f"{Mode :n} "; }

        FString Presses = "";
        for (const auto Refusal : _PressRefusals)
        { Presses += f"{Refusal :n} "; }

        FString TakeOuts = "";
        for (const auto Refusal : _TumblerTakeOutRefusals)
        { TakeOuts += f"{Refusal :n} "; }

        FString Added = "";
        for (const auto& Id : _TumblerAddedIds)
        { Added += f"{Id.Generation}.{Id.TransferIndex} "; }

        return f"hatches=[{Hatches}] hovers=[{Hovers}] drums=[{Drums}] modes=[{Modes}] pressRefused=[{Presses}] takeOutRefused=[{TakeOuts}] added=[{Added}]";
    }

    // The kernel's ledger and the motion ledger as this machine reads them.
    protected FString Describe_TumblerLedger()
    {
        if (ck::Is_NOT_Valid(_Tumbler))
        { return "ledger=[none]"; }

        const auto Ledger = _Tumbler.Get_Ledger();
        FString Rows = "";
        for (const auto& Row : Ledger.Pieces)
        { Rows += f"{Row.Id.Generation}.{Row.Id.TransferIndex}:{Row.Coverage} "; }

        const auto Motion = _Tumbler.Get_MotionLedger();
        return f"ledger=[mode={Ledger.HandMode :n} hovered={Ledger.Hovered :n} hatch={Ledger.Hatch :n} drum={Ledger.Drum :n} rows=[{Rows}] reseats={Ledger.Reseats} "
            + f"pressRefusals={Ledger.PressRefusalSerial} last={Ledger.LastPressRefusal :n} takeOutRefusals={Ledger.TakeOutRefusalSerial} last={Ledger.LastTakeOutRefusal :n}] "
            + f"motion=[alpha={Motion.DrumAlpha} hand={Motion.HandLocal}]";
    }

    protected FString Describe_Tumbler()
    {
        if (ck::Is_NOT_Valid(_Tumbler))
        { return "tumbler=[none]"; }

        const auto Axle = Get_AxleMover();
        const auto Hinge = Get_HingeMover();
        return f"tumbler=[mode={_Tumbler.Get_HandMode() :n} hovered={_Tumbler.Get_Hovered() :n} hatch={_Tumbler.Get_Hatch() :n} drum={_Tumbler.Get_Drum() :n} "
            + f"pieces={_Tumbler.Get_PieceCount()} axle={Axle.Get_Alpha()}/{Axle.Get_Target() :n} resting={Axle.Get_IsResting()} "
            + f"hinge={Hinge.Get_Alpha()}/{Hinge.Get_Target() :n} hand={_Tumbler.Get_HandLocal()}] takeable={utils_cooking_feed::Get_TakeableCount(_Station)}";
    }

    // This machine's axle Mover (the drum's turn) and hinge Mover (the hatch).
    protected FCk_Handle_Mover Get_AxleMover()
    {
        return _Tumbler.Get_Spec().Nodes.Lever.Get_Mover();
    }

    protected FCk_Handle_Mover Get_HingeMover()
    {
        return _Tumbler.Get_Spec().Nodes.Hatch;
    }

    // This machine's copy of the piece the drum holds as InId (the ledger row's handle without authority); invalid when it
    // holds none or that copy is not here.
    protected FCk_Handle_FoodPiece Get_TumblerCopy(FMars_CookingFeed_PieceId InId)
    {
        if (_Tumbler.Get_HasPiece(InId) == false)
        { return FCk_Handle_FoodPiece(); }

        const auto Entity = _Tumbler.Get_PieceEntity(InId);
        if (Get_IsLive(Entity) == false || Entity.Is_FoodPiece() == false)
        { return FCk_Handle_FoodPiece(); }

        return Entity.As_FoodPiece();
    }

    // The look (degrees: X yaw right+, Y pitch down+) that puts the server's cursor on InAnchor's point on the reach plane,
    // sized by the hand's CmPerLookDegree from the cursor as it stands.
    protected FVector Get_LookToAnchor(FCk_Handle_Transform InAnchor)
    {
        const auto Spec = _Tumbler.Get_Spec();
        const auto AnchorLocal = _Tumbler.Get_RootWorld().InverseTransformPosition(utils_transform::Get_EntityCurrentLocation(InAnchor));
        const auto Centre = Spec.Hand.WorkspaceCentreLocal;
        const auto Delta = FVector2D(AnchorLocal.Y - Centre.Y, AnchorLocal.Z - Centre.Z) - _Tumbler.Get_Cursor();
        const auto Step = float64(Spec.Hand.CmPerLookDegree);
        return FVector(Delta.X / Step, -Delta.Y / Step, 0.0);
    }

    // InDegrees of look along the lever's pull as the operator's view shows it (the projection the kernel's look uses).
    protected FVector Get_LookAlongPull(float64 InDegrees)
    {
        const auto Spec = _Tumbler.Get_Spec();
        const auto Pull = Spec.Nodes.Lever.Get_PullDirectionWorld();
        const auto View = utils_transform::Get_EntityCurrentTransform(Spec.Nodes.View).GetRotation();
        auto Screen = FVector2D(Pull.DotProduct(View.GetRightVector()), -Pull.DotProduct(View.GetUpVector()));
        if (Screen.Size() < 0.01)
        { return FVector(0.0, InDegrees, 0.0); }

        Screen.Normalize();
        return FVector(Screen.X * InDegrees, Screen.Y * InDegrees, 0.0);
    }

    // The largest change of this machine's axle alpha between the first samples of two successive frames since sample
    // InFrom, and where it happened.
    protected float32 Get_LargestAxleStep(int32 InFrom, FString& OutWhere)
    {
        auto Largest = 0.0f;
        auto Previous = InFrom;
        for (int32 Index = InFrom + 1; Index < _MoverSamples.Num(); ++Index)
        {
            const auto Sample = _MoverSamples[Index];
            const auto Before = _MoverSamples[Previous];
            if (Sample.Frame == Before.Frame)
            { continue; }

            const auto Step = Math::Abs(Sample.AxleAlpha - Before.AxleAlpha);
            if (Step > Largest)
            {
                Largest = Step;
                OutWhere = f"sample {Index}/{_MoverSamples.Num()} step={Sample.Step} {Before.AxleAlpha}->{Sample.AxleAlpha} frames={Sample.Frame - Before.Frame}";
            }

            Previous = Index;
        }

        return Largest;
    }

    // The first sampled frame at or after InFrame at which this machine's axle rested under 0.01; -1 when none did.
    protected int64 Find_AxleHomeFrame(int64 InFrame)
    {
        for (const auto& Sample : _MoverSamples)
        {
            if (Sample.Frame >= InFrame && Sample.AxleResting && Sample.AxleAlpha < 0.01f)
            { return Sample.Frame; }
        }

        return -1;
    }

    // The first sampled frame at or after InFrame at which this machine's hinge alpha was within 0.02 of InAlpha; -1 when
    // none was.
    protected int64 Find_HingeFrame(int64 InFrame, float32 InAlpha)
    {
        for (const auto& Sample : _MoverSamples)
        {
            if (Sample.Frame >= InFrame && Math::Abs(Sample.HingeAlpha - InAlpha) <= 0.02f)
            { return Sample.Frame; }
        }

        return -1;
    }

    // Every sample since InFrom: the axle and hinge alphas stayed within InTolerance of the first, and this machine's lever
    // never held a manipulation; OutWhere names the last sample that did not.
    protected bool Get_AreMoversStill(int32 InFrom, float32 InTolerance, FString& OutWhere)
    {
        if (InFrom >= _MoverSamples.Num())
        { return true; }

        const auto First = _MoverSamples[InFrom];
        auto IsStill = true;
        for (int32 Index = InFrom; Index < _MoverSamples.Num(); ++Index)
        {
            const auto Sample = _MoverSamples[Index];
            if (Math::Abs(Sample.AxleAlpha - First.AxleAlpha) > InTolerance || Math::Abs(Sample.HingeAlpha - First.HingeAlpha) > InTolerance
                || Sample.LeverManipulating)
            {
                IsStill = false;
                OutWhere = f"sample {Index}: axle {First.AxleAlpha}->{Sample.AxleAlpha} hinge {First.HingeAlpha}->{Sample.HingeAlpha} manipulating={Sample.LeverManipulating}";
            }
        }

        return IsStill;
    }

    // Some sample since InFrom shows this machine's lever holding a manipulation (only the authority's should).
    protected bool Get_SawLocalManipulation(int32 InFrom)
    {
        for (int32 Index = InFrom; Index < _MoverSamples.Num(); ++Index)
        {
            if (_MoverSamples[Index].LeverManipulating)
            { return true; }
        }

        return false;
    }

    // The tumbler's use row (its operator hints, on the Use action).
    protected FString Get_UseRowText()
    {
        const auto Row = TryGet_Row(n"Tumbler", mars::Mars_IA_Interact_Use);
        return Row.IsSet() ? Row.GetValue() : "<no row>";
    }

    // The ledger rows a copy without authority has announced (it raised OnPieceAdded for each); none with authority.
    protected TArray<FMars_CookingFeed_PieceId> Get_FryAnnouncedRows()
    {
        TArray<FMars_CookingFeed_PieceId> Ids;
        if (Get_IsServer() || ck::Is_NOT_Valid(_Fry) || _Fry.Has_Fragment(FMars_Fragment_Fry_Local) == false)
        { return Ids; }

        return _Fry.Get_Fragment(FMars_Fragment_Fry_Local).Announced;
    }

    protected void Clear_FryRecord()
    {
        _SkimChanges.Empty();
        _FryAddedIds.Empty();
        _SkimRefusals.Empty();
        _FryTakeOutRefusals.Empty();
        _FryAdmissionRefusals.Empty();
        _StageIds.Empty();
        _StageFaces.Empty();
        _Stages.Empty();
        _DrainedIds.Empty();
    }

    protected int32 Get_FryAddedCount(FMars_CookingFeed_PieceId InId)
    {
        auto Count = 0;
        for (const auto& Id : _FryAddedIds)
        {
            if (Id.Get_IsSame(InId))
            { ++Count; }
        }

        return Count;
    }

    protected int32 Get_SkimChangeCount(EMars_Fry_Skim InSkim)
    {
        auto Count = 0;
        for (const auto Skim : _SkimChanges)
        {
            if (Skim == InSkim)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_FryRecord()
    {
        FString Skims = "";
        for (const auto Skim : _SkimChanges)
        { Skims += f"{Skim :n} "; }

        FString Added = "";
        for (const auto& Id : _FryAddedIds)
        { Added += f"{Id.Generation}.{Id.TransferIndex} "; }

        FString Refused = "";
        for (const auto Skim : _SkimRefusals)
        { Refused += f"{Skim :n} "; }

        FString Admissions = "";
        for (const auto Refusal : _FryAdmissionRefusals)
        { Admissions += f"{Refusal :n} "; }

        FString TakeOuts = "";
        for (const auto Refusal : _FryTakeOutRefusals)
        { TakeOuts += f"{Refusal :n} "; }

        return f"skims=[{Skims}] added=[{Added}] skimRefused=[{Refused}] admissionRefused=[{Admissions}] takeOutRefused=[{TakeOuts}] "
            + f"stages={_Stages.Num()} drained={_DrainedIds.Num()}";
    }

    // The kernel's ledger and the skimmer's as this machine reads them.
    protected FString Describe_FryLedger()
    {
        if (ck::Is_NOT_Valid(_Fry))
        { return "ledger=[none]"; }

        const auto Ledger = _Fry.Get_Ledger();
        FString Rows = "";
        for (const auto& Row : Ledger.Pieces)
        {
            FString Heats = "";
            for (const auto Heat : Row.FaceHeat)
            { Heats += f"{Heat} "; }

            Rows += f"{Row.Id.Generation}.{Row.Id.TransferIndex}:{Row.Whereabouts :n}/{Row.Drain :n}/{Row.DrainProgress}[{Heats}] ";
        }

        const auto Skimmer = _Fry.Get_SkimmerLedger();
        const auto& Counts = Ledger.Counts;
        return f"ledger=[losses={Counts.Losses} takenOut={Counts.TakenOut} catches={Counts.Catches} retrievals={Counts.Retrievals} ejections={Counts.Ejections} "
            + f"rows=[{Rows}] skimRefusals={Ledger.SkimRefusalSerial} takeOutRefusals={Ledger.TakeOutRefusalSerial} admissionRefusals={Ledger.AdmissionRefusalSerial}] "
            + f"skimmer=[drive={Skimmer.Drive :n} skim={Skimmer.Skim :n} target={Skimmer.Target}]";
    }

    protected FString Describe_Fry()
    {
        if (ck::Is_NOT_Valid(_Fry))
        { return "fry=[none]"; }

        const auto Skimmer = _Fry.Get_Skimmer();
        const auto Summary = _Fry.Get_Summary();
        return f"fry=[drive={_Fry.Get_Drive() :n} skim={_Fry.Get_Skim() :n} target={_Fry.Get_SkimmerTarget()} scoop={_Fry.Get_ScoopRoot()} "
            + f"implement=[drive={Skimmer.Get_Drive() :n} lift={Skimmer.Get_Lift()}/{Skimmer.Get_TargetLift()} tilt={Skimmer.Get_Tilt()}/{Skimmer.Get_TargetTilt()} slide={Skimmer.Get_Slide()}/{Skimmer.Get_TargetSlide()}] "
            + f"pieces={_Fry.Get_PieceIds().Num()} admitted={Summary.Admitted} oil={Summary.InOil} basket={Summary.InBasket} drained={Summary.Drained} takenOut={Summary.TakenOut}] "
            + f"takeable={utils_cooking_feed::Get_TakeableCount(_Station)}";
    }

    // This machine's copy of the piece the fryer holds as InId (the ledger row's handle without authority); invalid when it
    // holds none or that copy is not here.
    protected FCk_Handle_FoodPiece Get_FryCopy(FMars_CookingFeed_PieceId InId)
    {
        if (_Fry.Get_HasPiece(InId) == false)
        { return FCk_Handle_FoodPiece(); }

        const auto Entity = _Fry.Get_PieceEntity(InId);
        if (Get_IsLive(Entity) == false || Entity.Is_FoodPiece() == false)
        { return FCk_Handle_FoodPiece(); }

        return Entity.As_FoodPiece();
    }

    // The look (degrees: X yaw right+, Y pitch down+) that moves the skimmer's target InShare of the way to the basket's
    // centre, sized by the reach's CmPerLookDegree.
    protected FVector Get_LookTowardBasket(float64 InShare)
    {
        const auto Spec = _Fry.Get_Spec();
        const auto Delta = (Spec.Reach.BasketCentre - _Fry.Get_SkimmerTarget()) * InShare;
        const auto Step = float64(Spec.Reach.CmPerLookDegree);
        return FVector(Delta.Y / Step, -Delta.X / Step, 0.0);
    }

    // The scoop's centre is within k_ScoopSettledCm of the skimmer's target (root-frame XY).
    protected bool Get_IsScoopAtTarget()
    {
        const auto Scoop = _Fry.Get_ScoopRoot();
        return (FVector2D(Scoop.X, Scoop.Y) - _Fry.Get_SkimmerTarget()).Size() <= k_ScoopSettledCm;
    }

    // The scoop is at its target and its lift at its commanded lift (k_ScoopSettledCm each).
    protected bool Get_IsScoopSettled()
    {
        const auto Skimmer = _Fry.Get_Skimmer();
        return Get_IsScoopAtTarget() && Math::Abs(Skimmer.Get_Lift() - Skimmer.Get_TargetLift()) <= float32(k_ScoopSettledCm);
    }

    // The kernel reads Dip and the skimmer's lift, commanded to the dip, is within k_ScoopSettledCm of it.
    protected bool Get_IsDipSettled()
    {
        const auto Skimmer = _Fry.Get_Skimmer();
        const auto DipLift = _Fry.Get_Spec().Scoop.DipLift;
        return _Fry.Get_Skim() == EMars_Fry_Skim::Dip && Math::Abs(Skimmer.Get_TargetLift() - DipLift) <= 0.01f
            && Math::Abs(Skimmer.Get_Lift() - DipLift) <= float32(k_ScoopSettledCm);
    }

    // The largest move of this machine's scoop between the first samples of two successive frames since sample InFrom, and
    // where it happened.
    protected float64 Get_LargestScoopStep(int32 InFrom, FString& OutWhere)
    {
        auto Largest = 0.0;
        auto Previous = InFrom;
        for (int32 Index = InFrom + 1; Index < _ScoopSamples.Num(); ++Index)
        {
            const auto Sample = _ScoopSamples[Index];
            const auto Before = _ScoopSamples[Previous];
            if (Sample.Frame == Before.Frame)
            { continue; }

            const auto Step = Sample.Root.Distance(Before.Root);
            if (Step > Largest)
            {
                Largest = Step;
                OutWhere = f"sample {Index}/{_ScoopSamples.Num()} step={Sample.Step} {Before.Root}->{Sample.Root} dt={Sample.Seconds - Before.Seconds} frames={Sample.Frame - Before.Frame}";
            }

            Previous = Index;
        }

        return Largest;
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
        Sample_Scoop();
        Sample_Movers();
        On_HeatStationSample();
    }

    // The born station is watched and its bowl sampled before the base rig's sampling, which waits for the docks.
    protected void On_Sample(TArray<FCk_Handle> InEntities, TArray<FCk_Handle_FoodPiece> InStanding) override
    {
        Watch_BornHeatStation();
        Sample_BornBowl();
        Sample_BornSkimmer();
        Super::On_Sample(InEntities, InStanding);
        if (_HeatStationBirth == EMars_TESTONLY_HeatStationBirth::Born && _WasHeatStationFound && _BornRigFoundFrame < 0)
        { _BornRigFoundFrame = utils_time::Get_FrameCounter(); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The born station's watch
    //----------------------------------------------------------------------------------------------------------------------

    // Once: this machine's live station carrying the born test tag near the floor whose hooked kernel has composed; its
    // kernel's signals are recorded from then on, and off authority each rep-notify of its ledger.
    private void Watch_BornHeatStation()
    {
        if (_HeatStationBirth != EMars_TESTONLY_HeatStationBirth::Born || _WasBornStationWatched)
        { return; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetBornHeatStation"))
        {
            if (Get_IsLive(Candidate) == false || Candidate.Is_Transform() == false || Get_IsNear(Candidate, _FloorTop) == false
                || Get_IsBornKernelComposed(Candidate) == false)
            { continue; }

            _WasBornStationWatched = true;
            _BornStation = Candidate;
            _BornFoundFrame = utils_time::Get_FrameCounter();
            _BornInitialAtFind = Get_BornInitialState();
            _BornSkimmerInitialAtFind = Get_BornSkimmerInitialState();
            Bind_BornKernel();
            return;
        }
    }

    private bool Get_IsBornKernelComposed(FCk_Handle InStation) const
    {
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        { return InStation.Is_Searing(); }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        { return InStation.Is_Tumbler(); }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        { return InStation.Is_Fry(); }

        return Get_HeatStation() == EMars_TESTONLY_HeatStation::Batter && InStation.Is_Batter();
    }

    private void Bind_BornKernel()
    {
        const auto IsCopy = Get_IsServer() == false;
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        {
            auto Searing = _BornStation.As_Searing();
            Searing.BindTo_OnHeatChanged(FMars_Delegate_Searing_OnHeatChanged(this, n"OnBornHeatChanged"));
            Searing.BindTo_OnTakeOutRefused(FMars_Delegate_Searing_OnTakeOutRefused(this, n"OnBornPanTakeOutRefused"));
            Searing.BindTo_OnFaceSeared(FMars_Delegate_Searing_OnFaceSeared(this, n"OnBornFaceSeared"));
            Searing.BindTo_OnPieceAdded(FMars_Delegate_Searing_OnPieceAdded(this, n"OnBornPanPieceAdded"));
            if (IsCopy)
            { _BornStation.BindTo_OnRepNotify(FMars_Fragment_Searing_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnBornSearingNotify")); }

            return;
        }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        {
            auto Tumbler = _BornStation.As_Tumbler();
            Tumbler.BindTo_OnPressRefused(FMars_Delegate_Tumbler_OnPressRefused(this, n"OnBornPressRefused"));
            Tumbler.BindTo_OnTakeOutRefused(FMars_Delegate_Tumbler_OnTakeOutRefused(this, n"OnBornTumblerTakeOutRefused"));
            Tumbler.BindTo_OnHatchChanged(FMars_Delegate_Tumbler_OnHatchChanged(this, n"OnBornHatchChanged"));
            Tumbler.BindTo_OnPieceAdded(FMars_Delegate_Tumbler_OnPieceAdded(this, n"OnBornTumblerPieceAdded"));
            if (IsCopy)
            { _BornStation.BindTo_OnRepNotify(FMars_Fragment_Tumbler_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnBornTumblerNotify")); }

            return;
        }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        {
            auto Fry = _BornStation.As_Fry();
            Fry.BindTo_OnSkimChanged(FMars_Delegate_Fry_OnSkimChanged(this, n"OnBornSkimChanged"));
            Fry.BindTo_OnSkimRefused(FMars_Delegate_Fry_OnSkimRefused(this, n"OnBornSkimRefused"));
            Fry.BindTo_OnTakeOutRefused(FMars_Delegate_Fry_OnTakeOutRefused(this, n"OnBornFryTakeOutRefused"));
            Fry.BindTo_OnAdmissionRefused(FMars_Delegate_Fry_OnAdmissionRefused(this, n"OnBornFryAdmissionRefused"));
            Fry.BindTo_OnPieceAdded(FMars_Delegate_Fry_OnPieceAdded(this, n"OnBornFryPieceAdded"));
            if (IsCopy)
            {
                _BornStation.BindTo_OnRepNotify(FMars_Fragment_Fry_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnBornFryNotify"));
                _BornStation.BindTo_OnRepNotify(FMars_Fragment_Fry_SkimmerNet, FCk_DynamicFragment_OnRepNotify(this, n"OnBornSkimmerNotify"));
            }

            return;
        }

        auto Batter = _BornStation.As_Batter();
        Batter.BindTo_OnBowlChanged(FMars_Delegate_Batter_OnBowlChanged(this, n"OnBornBowlChanged"));
        Batter.BindTo_OnPieceAdded(FMars_Delegate_Batter_OnPieceAdded(this, n"OnBornBatterPieceAdded"));
        Batter.BindTo_OnAdmissionRefused(FMars_Delegate_Batter_OnAdmissionRefused(this, n"OnBornAdmissionRefused"));
        Batter.BindTo_OnTakeOutRefused(FMars_Delegate_Batter_OnTakeOutRefused(this, n"OnBornBatterTakeOutRefused"));
        if (IsCopy)
        { _BornStation.BindTo_OnRepNotify(FMars_Fragment_Batter_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnBornBatterNotify")); }
    }

    // Off authority, once a born bowl is watched, every frame its ledger has a row whose piece is a live food piece
    // under the bowl node: the ledger's bowl and the piece's distance from its fully-under offset.
    private void Sample_BornBowl()
    {
        if (Get_HeatStation() != EMars_TESTONLY_HeatStation::Batter || Get_IsServer() || Get_IsLive(_BornStation) == false
            || _BornStation.Is_Batter() == false)
        { return; }

        const auto Batter = _BornStation.As_Batter();
        const auto Ledger = Batter.Get_Ledger();
        const auto Spec = Batter.Get_Spec();
        for (const auto& Row : Ledger.Pieces)
        {
            const auto Entity = Row.Piece;
            if (Get_IsLive(Entity) == false || Entity.Is_FoodPiece() == false)
            { continue; }

            const auto Piece = Entity.As_FoodPiece();
            const auto Parent = Get_Parent(Piece);
            if (ck::Is_NOT_Valid(Parent) || Parent != Spec.Nodes.Bowl)
            { continue; }

            auto State = FMars_Batter_PieceState();
            State.Piece = Piece;
            State.Slot = Row.Slot;
            State.Immersion = 1.0f;
            const auto Dipped = utils_batter::Get_PieceOffset(Spec.Bowl, State);
            auto Sample = FMars_TESTONLY_NetHeatBornBowlSample();
            Sample.Frame = utils_time::Get_FrameCounter();
            Sample.Bowl = Ledger.Bowl;
            Sample.DippedErrorCm = Get_Offset(Piece).GetLocation().Distance(Dipped.GetLocation());
            _BornBowlSamples.Add(Sample);
        }
    }

    // Off authority, once a born fryer is watched, every frame its skimmer's targets are the skimmer ledger's command
    // (the lift of its skim, its target's offset from this machine's park): the ledger and how far the shown lift and
    // slide are from those targets. A frame before the skimmer's drain has taken the command is not sampled.
    private void Sample_BornSkimmer()
    {
        if (Get_HeatStation() != EMars_TESTONLY_HeatStation::Fry || Get_IsServer() || Get_IsLive(_BornStation) == false
            || _BornStation.Is_Fry() == false)
        { return; }

        const auto Fry = _BornStation.As_Fry();
        const auto Ledger = Fry.Get_SkimmerLedger();
        const auto Skimmer = Fry.Get_Skimmer();
        const auto Scoop = Fry.Get_Spec().Scoop;
        const auto CommandedLift = Ledger.Skim == EMars_Fry_Skim::Dip ? Scoop.DipLift : Scoop.CarryLift;
        const auto CommandedSlide = Ledger.Target - Fry.Get_SkimmerPark();
        const auto HasTaken = Math::Abs(Skimmer.Get_TargetLift() - CommandedLift) <= 0.01f
            && (Skimmer.Get_TargetSlide() - CommandedSlide).Size() <= 0.01;
        if (HasTaken == false)
        { return; }

        auto Sample = FMars_TESTONLY_NetHeatBornSkimmerSample();
        Sample.Frame = utils_time::Get_FrameCounter();
        Sample.Ledger = Ledger;
        Sample.LiftErrorCm = float64(Math::Abs(Skimmer.Get_Lift() - Skimmer.Get_TargetLift()));
        Sample.SlideErrorCm = (Skimmer.Get_Slide() - Skimmer.Get_TargetSlide()).Size();
        _BornSkimmerSamples.Add(Sample);
    }

    // The born kernel's InitialState on this machine; Awaited while there is none.
    protected EMars_Net_InitialState Get_BornInitialState()
    {
        if (Get_IsLive(_BornStation) == false)
        { return EMars_Net_InitialState::Awaited; }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        {
            return _BornStation.Has_Fragment(FMars_Fragment_Searing_Local)
                ? _BornStation.Get_Fragment(FMars_Fragment_Searing_Local).InitialState : EMars_Net_InitialState::Awaited;
        }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        {
            return _BornStation.Has_Fragment(FMars_Fragment_Tumbler_Local)
                ? _BornStation.Get_Fragment(FMars_Fragment_Tumbler_Local).InitialState : EMars_Net_InitialState::Awaited;
        }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        {
            return _BornStation.Has_Fragment(FMars_Fragment_Fry_Local)
                ? _BornStation.Get_Fragment(FMars_Fragment_Fry_Local).InitialState : EMars_Net_InitialState::Awaited;
        }

        return _BornStation.Has_Fragment(FMars_Fragment_Batter_Local)
            ? _BornStation.Get_Fragment(FMars_Fragment_Batter_Local).InitialState : EMars_Net_InitialState::Awaited;
    }

    // The born pan's PanInitialState on this machine; Awaited while there is none.
    protected EMars_Net_InitialState Get_BornPanInitialState()
    {
        if (Get_IsLive(_BornStation) == false || _BornStation.Has_Fragment(FMars_Fragment_Searing_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _BornStation.Get_Fragment(FMars_Fragment_Searing_Local).PanInitialState;
    }

    // The born fryer's SkimmerInitialState on this machine; Awaited while there is none.
    protected EMars_Net_InitialState Get_BornSkimmerInitialState()
    {
        if (Get_IsLive(_BornStation) == false || _BornStation.Has_Fragment(FMars_Fragment_Fry_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _BornStation.Get_Fragment(FMars_Fragment_Fry_Local).SkimmerInitialState;
    }

    protected bool Get_HasBornFirstNotify() const
    {
        return _BornNotifyFrames.Num() > 0;
    }

    // The frame of the first recorded rep-notify of the born kernel's ledger; -1 while none is recorded.
    protected int64 Get_BornFirstNotifyFrame() const
    {
        if (_BornNotifyFrames.Num() == 0)
        { return -1; }

        return _BornNotifyFrames[0];
    }

    // The ledger the first recorded rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_Batter_Net Get_BornFirstBatterLedger() const
    {
        if (_BornBatterLedgers.Num() == 0)
        { return FMars_Fragment_Batter_Net(); }

        return _BornBatterLedgers[0];
    }

    protected FMars_Fragment_Searing_Net Get_BornFirstSearingLedger() const
    {
        if (_BornSearingLedgers.Num() == 0)
        { return FMars_Fragment_Searing_Net(); }

        return _BornSearingLedgers[0];
    }

    protected FMars_Fragment_Tumbler_Net Get_BornFirstTumblerLedger() const
    {
        if (_BornTumblerLedgers.Num() == 0)
        { return FMars_Fragment_Tumbler_Net(); }

        return _BornTumblerLedgers[0];
    }

    protected FMars_Fragment_Fry_Net Get_BornFirstFryLedger() const
    {
        if (_BornFryLedgers.Num() == 0)
        { return FMars_Fragment_Fry_Net(); }

        return _BornFryLedgers[0];
    }

    // The skimmer ledger the first recorded skimmer rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_Fry_SkimmerNet Get_BornFirstSkimmerLedger() const
    {
        if (_BornSkimmerLedgers.Num() == 0)
        { return FMars_Fragment_Fry_SkimmerNet(); }

        return _BornSkimmerLedgers[0];
    }

    protected bool Get_HasBornFirstSkimmerNotify() const
    {
        return _BornSkimmerNotifyFrames.Num() > 0;
    }

    // The frame of the first recorded rep-notify of the born fryer's skimmer ledger; -1 while none is recorded.
    protected int64 Get_BornFirstSkimmerNotifyFrame() const
    {
        if (_BornSkimmerNotifyFrames.Num() == 0)
        { return -1; }

        return _BornSkimmerNotifyFrames[0];
    }

    // The skimmer samples taken while the skimmer ledger read the first skimmer notify's command, and the largest lift
    // and slide errors among them (-1 without one).
    protected int32 Get_BornCommandSampleCount() const
    {
        auto Count = 0;
        for (const auto& Sample : _BornSkimmerSamples)
        {
            if (Get_IsBornFirstCommand(Sample.Ledger))
            { ++Count; }
        }

        return Count;
    }

    protected float64 Get_BornWorstLiftCm() const
    {
        auto Worst = -1.0;
        for (const auto& Sample : _BornSkimmerSamples)
        {
            if (Get_IsBornFirstCommand(Sample.Ledger) && Sample.LiftErrorCm > Worst)
            { Worst = Sample.LiftErrorCm; }
        }

        return Worst;
    }

    protected float64 Get_BornWorstSlideCm() const
    {
        auto Worst = -1.0;
        for (const auto& Sample : _BornSkimmerSamples)
        {
            if (Get_IsBornFirstCommand(Sample.Ledger) && Sample.SlideErrorCm > Worst)
            { Worst = Sample.SlideErrorCm; }
        }

        return Worst;
    }

    // InLedger carries the first skimmer notify's command: its drive and skim, its target within 0.01 (none before).
    private bool Get_IsBornFirstCommand(const FMars_Fragment_Fry_SkimmerNet& InLedger) const
    {
        if (Get_HasBornFirstSkimmerNotify() == false)
        { return false; }

        const auto First = Get_BornFirstSkimmerLedger();
        return InLedger.Drive == First.Drive && InLedger.Skim == First.Skim && (InLedger.Target - First.Target).Size() <= 0.01;
    }

    protected int32 Get_BornEventCount(EMars_TESTONLY_NetHeatBornEventKind InKind) const
    {
        return Get_BornEvents(InKind).Num();
    }

    // Every recorded signal in InFrame, of any kind.
    protected int32 Get_BornEventsInFrame(int64 InFrame) const
    {
        auto Count = 0;
        for (const auto& Event : _BornEvents)
        {
            if (Event.Frame == InFrame)
            { ++Count; }
        }

        return Count;
    }

    // The recorded signals of InKind, in order.
    protected TArray<FMars_TESTONLY_NetHeatBornEvent> Get_BornEvents(EMars_TESTONLY_NetHeatBornEventKind InKind) const
    {
        TArray<FMars_TESTONLY_NetHeatBornEvent> Events;
        for (const auto& Event : _BornEvents)
        {
            if (Event.Kind == InKind)
            { Events.Add(Event); }
        }

        return Events;
    }

    // The recorded signals of InKind in InFrame.
    protected int32 Get_BornEventCountInFrame(EMars_TESTONLY_NetHeatBornEventKind InKind, int64 InFrame) const
    {
        auto Count = 0;
        for (const auto& Event : Get_BornEvents(InKind))
        {
            if (Event.Frame == InFrame)
            { ++Count; }
        }

        return Count;
    }

    // The bowl samples taken while the ledger read Dipped, and the largest distance among them (-1 without one).
    protected int32 Get_BornDippedSampleCount() const
    {
        auto Count = 0;
        for (const auto& Sample : _BornBowlSamples)
        {
            if (Sample.Bowl == EMars_Batter_Bowl::Dipped)
            { ++Count; }
        }

        return Count;
    }

    protected float64 Get_BornWorstDippedCm() const
    {
        auto Worst = -1.0;
        for (const auto& Sample : _BornBowlSamples)
        {
            if (Sample.Bowl == EMars_Batter_Bowl::Dipped && Sample.DippedErrorCm > Worst)
            { Worst = Sample.DippedErrorCm; }
        }

        return Worst;
    }

    protected FString Describe_Born()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _BornNotifyFrames.Num(); ++Index)
        { Notifies += f"{_BornNotifyFrames[Index]}:{Describe_BornNotify(Index)} "; }

        auto Events = "";
        for (const auto& Event : _BornEvents)
        { Events += f"{Event.Kind :n}{Describe_BornValue(Event)}@{Event.Frame} "; }

        auto Text = f"watched@{_BornFoundFrame} rigFound@{_BornRigFoundFrame} initialAtFind={_BornInitialAtFind :n} "
            + f"initial={Get_BornInitialState() :n}";
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        { Text += f" panInitial={Get_BornPanInitialState() :n}"; }

        Text += f" notifies=[{Notifies}] events=[{Events}]";
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Batter)
        { Text += f" bowlSamples={_BornBowlSamples.Num()} dippedSamples={Get_BornDippedSampleCount()} worstDippedCm={Get_BornWorstDippedCm()}"; }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        {
            auto SkimmerNotifies = "";
            for (int32 Index = 0; Index < _BornSkimmerNotifyFrames.Num(); ++Index)
            {
                const auto& Ledger = _BornSkimmerLedgers[Index];
                SkimmerNotifies += f"{_BornSkimmerNotifyFrames[Index]}:{Ledger.Drive :n}/{Ledger.Skim :n}/{Ledger.Target} ";
            }

            Text += f" skimmerInitialAtFind={_BornSkimmerInitialAtFind :n} skimmerInitial={Get_BornSkimmerInitialState() :n}"
                + f" skimmerNotifies=[{SkimmerNotifies}] skimmerSamples={_BornSkimmerSamples.Num()}"
                + f" commandSamples={Get_BornCommandSampleCount()} worstLiftCm={Get_BornWorstLiftCm()} worstSlideCm={Get_BornWorstSlideCm()}";
        }

        return Text;
    }

    // The counts the InIndex-th recorded notify carried: the bowl's bowl/serial/rows/admission and take-out refusals,
    // the pan's heat/rows/take-out refusals, the tumbler's hatch/press and take-out refusals, the fryer's
    // rows/skim, take-out and admission refusals.
    private FString Describe_BornNotify(int32 InIndex) const
    {
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        {
            const auto& Ledger = _BornFryLedgers[InIndex];
            return f"{Ledger.Pieces.Num()}/{Ledger.SkimRefusalSerial}/{Ledger.TakeOutRefusalSerial}/{Ledger.AdmissionRefusalSerial}";
        }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        {
            const auto& Ledger = _BornSearingLedgers[InIndex];
            return f"{Ledger.Heat :n}/{Ledger.Pieces.Num()}/{Ledger.TakeOutRefusalSerial}";
        }

        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        {
            const auto& Ledger = _BornTumblerLedgers[InIndex];
            return f"{Ledger.Hatch :n}/{Ledger.PressRefusalSerial}/{Ledger.TakeOutRefusalSerial}";
        }

        const auto& Ledger = _BornBatterLedgers[InIndex];
        return f"{Ledger.Bowl :n}/{Ledger.BowlSerial}/{Ledger.Pieces.Num()}/{Ledger.AdmissionRefusalSerial}/{Ledger.TakeOutRefusalSerial}";
    }

    private FString Describe_BornValue(const FMars_TESTONLY_NetHeatBornEvent& InEvent) const
    {
        if (InEvent.Kind == EMars_TESTONLY_NetHeatBornEventKind::BowlChanged)
        { return f":{EMars_Batter_Bowl(InEvent.Value) :n}"; }

        if (InEvent.Kind == EMars_TESTONLY_NetHeatBornEventKind::HeatChanged)
        { return f":{EMars_Searing_Heat(InEvent.Value) :n}"; }

        if (InEvent.Kind == EMars_TESTONLY_NetHeatBornEventKind::HatchChanged)
        { return f":{EMars_Tumbler_Hatch(InEvent.Value) :n}"; }

        if (InEvent.Kind == EMars_TESTONLY_NetHeatBornEventKind::SkimChanged)
        { return f":{EMars_Fry_Skim(InEvent.Value) :n}"; }

        return "";
    }

    private void Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind InKind, int32 InValue)
    {
        auto Event = FMars_TESTONLY_NetHeatBornEvent();
        Event.Kind = InKind;
        Event.Frame = utils_time::Get_FrameCounter();
        Event.Value = InValue;
        _BornEvents.Add(Event);
    }

    // The tumbler's Movers and hand node as this machine shows them this frame (the tumbler station only).
    private void Sample_Movers()
    {
        if (ck::Is_NOT_Valid(_Tumbler))
        { return; }

        const auto Axle = Get_AxleMover();
        const auto Hinge = Get_HingeMover();
        const auto Ledger = _Tumbler.Get_Ledger();
        auto Sample = FMars_TESTONLY_NetHeatMoverSample();
        Sample.Step = Get_HeatStationReport().Step;
        Sample.Frame = utils_time::Get_FrameCounter();
        Sample.Seconds = System::GetGameTimeInSeconds();
        Sample.AxleAlpha = Axle.Get_Alpha();
        Sample.AxleTarget = Axle.Get_Target();
        Sample.AxleTweening = ck::IsValid(Axle.Get_Fragment(FMars_Fragment_Mover).Tween);
        Sample.AxleResting = Axle.Get_IsResting();
        Sample.LeverManipulating = _Tumbler.Get_Spec().Nodes.Lever.Get_IsManipulating();
        Sample.HingeAlpha = Hinge.Get_Alpha();
        Sample.HingeResting = Hinge.Get_IsResting();
        Sample.HandOffset = utils_scene_node::Get_Offset(_Tumbler.Get_Spec().Nodes.Hand).GetLocation();
        if (Ledger.Pieces.Num() > 0)
        { Sample.FirstCoverage = Ledger.Pieces[0].Coverage; }

        _MoverSamples.Add(Sample);
    }

    // The scoop as this machine shows it this frame (the fry station only).
    private void Sample_Scoop()
    {
        if (ck::Is_NOT_Valid(_Fry))
        { return; }

        const auto Ledger = _Fry.Get_Ledger();
        auto Sample = FMars_TESTONLY_NetHeatScoopSample();
        Sample.Step = Get_HeatStationReport().Step;
        Sample.Frame = utils_time::Get_FrameCounter();
        Sample.Seconds = System::GetGameTimeInSeconds();
        Sample.Root = _Fry.Get_ScoopRoot();
        Sample.Skim = _Fry.Get_Skim();
        Sample.Rows = Ledger.Pieces.Num();
        if (Ledger.Pieces.Num() > 0)
        { Sample.FirstRowHeat = Ledger.Pieces[0].FaceHeat; }

        _ScoopSamples.Add(Sample);
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
        if (ck::IsValid(_Fry))
        { BowlIds = _Fry.Get_PieceIds(); }
        else if (ck::IsValid(_Tumbler))
        { BowlIds = _Tumbler.Get_PieceIds(); }
        else if (ck::IsValid(_Searing))
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
        Report.Target = _ReportTarget;
        Report.Scoop = _ReportScoop;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetHeatStationReport);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the station, the foods, the tray
    //----------------------------------------------------------------------------------------------------------------------

    // Server: the hooked station beside the platter under the spawn owner, through the heat-station fixture, tracked;
    // On_ServerFeedStationReady once this machine finds it composed with its kernel.
    protected void Spawn_HeatStation()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        if (_HeatStationBirth == EMars_TESTONLY_HeatStationBirth::Born)
        { _FeedStationEntity = Spawn_BornHeatStation(Owner); }
        else if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        { _FeedStationEntity = Spawn_SearingStation(Owner); }
        else if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        { _FeedStationEntity = Spawn_FryStation(Owner); }
        else if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        { _FeedStationEntity = Spawn_TumblerStation(Owner); }
        else
        {
            auto Fixture = Cast<UMars_AutoTestHelper_HeatStation>(NewObject(this, UMars_AutoTestHelper_HeatStation));
            auto Pending = Fixture.Spawn_Batter(Owner, Get_StationLocation(), Make_BatterSpec().Coat.CoatSeconds);
            _FeedStationEntity = Pending.Get_EntityUnderConstruction();
        }

        Track_ForCleanup(_FeedStationEntity);
        WaitUntil(n"Is_RigHeatStationReady", n"OnRigHeatStationReady", k_SlowPolls);
    }

    // The born class of the hooked station with that station's spawn params and the hook's spec, as the map's spawner
    // makes it (its own context).
    private FCk_Handle Spawn_BornHeatStation(FCk_Handle InOwner)
    {
        const auto Transform = FTransform(FRotator::ZeroRotator, Get_StationLocation());
        auto Station = FCk_Handle();
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Batter)
        {
            auto Params = UMars_BatterStation_EntityScript::Params();
            Params.SpawnTransform = Transform;
            Params.Batter = Make_BatterSpec();
            Station = utils_entity_script::Request_SpawnEntity(InOwner, UMars_TESTONLY_NetBatterStation_Born_EntityScript, Params).Get_EntityUnderConstruction();
        }
        else if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Searing)
        {
            auto Params = UMars_SearingStation_EntityScript::Params();
            Params.SpawnTransform = Transform;
            Params.Searing = Make_SearingSpec();
            Station = utils_entity_script::Request_SpawnEntity(InOwner, UMars_TESTONLY_NetSearingStation_Born_EntityScript, Params).Get_EntityUnderConstruction();
        }
        else if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        {
            auto Params = UMars_TumblerStation_EntityScript::Params();
            Params.SpawnTransform = Transform;
            Params.Tumbler = Make_TumblerSpec();
            Station = utils_entity_script::Request_SpawnEntity(InOwner, UMars_TESTONLY_NetTumblerStation_Born_EntityScript, Params).Get_EntityUnderConstruction();
        }
        else if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Fry)
        {
            auto Params = UMars_FryStation_EntityScript::Params();
            Params.SpawnTransform = Transform;
            Params.Fry = Make_FrySpec();
            Station = utils_entity_script::Request_SpawnEntity(InOwner, UMars_TESTONLY_NetFryStation_Born_EntityScript, Params).Get_EntityUnderConstruction();
        }

        if (ck::EnsureIfNot(ck::IsValid(Station), f"{Get_LogTag()} there is no born {Get_HeatStation() :n} station"))
        { return Station; }

        Station.Request_OverrideToSelf();
        return Station;
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

    // The real fry station with the test's exposed Fry spec, as the map's spawner makes it (its own context).
    private FCk_Handle Spawn_FryStation(FCk_Handle InOwner)
    {
        auto Params = UMars_FryStation_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, Get_StationLocation());
        Params.Fry = Make_FrySpec();
        auto Station = utils_entity_script::Request_SpawnEntity(InOwner, UMars_FryStation_EntityScript, Params).Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        return Station;
    }

    // The real tumbler station with the test's exposed Tumbler spec, as the map's spawner makes it (its own context).
    private FCk_Handle Spawn_TumblerStation(FCk_Handle InOwner)
    {
        auto Params = UMars_TumblerStation_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, Get_StationLocation());
        Params.Tumbler = Make_TumblerSpec();
        auto Station = utils_entity_script::Request_SpawnEntity(InOwner, UMars_TumblerStation_EntityScript, Params).Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        return Station;
    }

    // The searing station is ready once its pan body is in the simulation (the pan admits nothing before); the fry station
    // once its scoop and basket bodies are; the tumbler station once its drum body is.
    UFUNCTION()
    private void Is_RigHeatStationReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsLive(_FeedStationEntity) && _FeedStationEntity.Is_CookingFeed() && Try_FindHeatStation()
            && (ck::Is_NOT_Valid(_Searing) || utils_jolt_body::Get_IsBodyAdded(_Searing.Get_Spec().Nodes.PanBaseBody))
            && (ck::Is_NOT_Valid(_Fry) || (utils_jolt_body::Get_IsBodyAdded(_Fry.Get_Spec().Nodes.ScoopBody)
                && utils_jolt_body::Get_IsBodyAdded(_Fry.Get_Spec().Nodes.BasketBody)))
            && (ck::Is_NOT_Valid(_Tumbler) || utils_jolt_body::Get_IsBodyAdded(_Tumbler.Get_Spec().Nodes.DrumBody)));
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

    // Server: InPieces' cook states battered, as the batter station's take-out leaves them; InContinuation once each reads so.
    protected void Batter_Then(TArray<FCk_Handle_FoodPiece> InPieces, FName InContinuation)
    {
        for (const auto& InPiece : InPieces)
        {
            auto Piece = InPiece;
            auto CookState = Piece.Get_CookState();
            CookState.Battered = 1.0f;
            Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        }

        _BatterPieces = InPieces;
        _BatterContinuation = InContinuation;
        WaitUntil(n"Is_RigBattered", n"OnRigBattered", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigBattered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto IsBattered = true;
        for (const auto& Piece : _BatterPieces)
        {
            if (utils_batter::Get_IsBattered(Piece.Get_CookState()) == false)
            { IsBattered = false; }
        }

        auto Result = OutResult;
        Result.Set(IsBattered);
    }

    UFUNCTION()
    private void OnRigBattered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _BatterContinuation);
    }

    // Server: InPieces' cook states carrying a crumb of InCrumb, as an earlier tumble leaves them; InContinuation once each
    // reads so.
    protected void Crumb_Then(TArray<FCk_Handle_FoodPiece> InPieces, float32 InCrumb, FName InContinuation)
    {
        for (const auto& InPiece : InPieces)
        {
            auto Piece = InPiece;
            auto CookState = Piece.Get_CookState();
            CookState.Crumb = InCrumb;
            Piece.Request_SetCookState(FMars_Request_FoodPiece_SetCookState(CookState));
        }

        _CrumbPieces = InPieces;
        _Crumb = InCrumb;
        _CrumbContinuation = InContinuation;
        WaitUntil(n"Is_RigCrumbed", n"OnRigCrumbed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigCrumbed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto IsCrumbed = true;
        for (const auto& Piece : _CrumbPieces)
        {
            if (Piece.Get_CookState().Crumb != _Crumb)
            { IsCrumbed = false; }
        }

        auto Result = OutResult;
        Result.Set(IsCrumbed);
    }

    UFUNCTION()
    private void OnRigCrumbed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _CrumbContinuation);
    }

    // Server: one look, on its own kernel (Kernel) or in the operator's stream (Remote), that puts its cursor on InTarget's
    // anchor (the hatch tab or the lever grip) wherever it stands now; InContinuation once its kernel hovers InTarget.
    protected void Point_AtThen(EMars_Tumbler_Target InTarget, EMars_TESTONLY_NetTumblerLook InRoute, FName InContinuation)
    {
        const auto Nodes = _Tumbler.Get_Spec().Nodes;
        const auto Anchor = InTarget == EMars_Tumbler_Target::Hatch ? Nodes.HatchTab : Nodes.LeverGrip;
        _PointTarget = InTarget;
        _LookRoute = InRoute;
        _PointContinuation = InContinuation;
        Send_Look(Get_LookToAnchor(Anchor), constants_heat_station_net_autotest::k_PointLookSeconds);
        WaitUntil(n"Is_RigPointed", n"OnRigPointed", k_SlowPolls);
    }

    // Server: one look that puts its cursor at k_AwayCursorShare of the reach's half extents down and to the left, far from
    // the hatch tab and the lever grip (the cursor starts on the shut hatch's tab); InContinuation once nothing is hovered.
    protected void Point_AwayThen(EMars_TESTONLY_NetTumblerLook InRoute, FName InContinuation)
    {
        const auto Hand = _Tumbler.Get_Spec().Hand;
        const auto Share = constants_heat_station_net_autotest::k_AwayCursorShare;
        const auto Away = FVector2D(-float64(Hand.HalfExtentY) * Share, -float64(Hand.HalfExtentZ) * Share);
        const auto Delta = Away - _Tumbler.Get_Cursor();
        const auto Step = float64(Hand.CmPerLookDegree);
        _PointTarget = EMars_Tumbler_Target::None;
        _LookRoute = InRoute;
        _PointContinuation = InContinuation;
        Send_Look(FVector(Delta.X / Step, -Delta.Y / Step, 0.0), constants_heat_station_net_autotest::k_PointLookSeconds);
        WaitUntil(n"Is_RigPointed", n"OnRigPointed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigPointed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Tumbler.Get_Hovered() == _PointTarget);
    }

    UFUNCTION()
    private void OnRigPointed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _PointContinuation);
    }

    // Server: InLook (that took InSeconds on the sender) the way the last point or rock asked.
    private void Send_Look(FVector InLook, float32 InSeconds)
    {
        if (_LookRoute == EMars_TESTONLY_NetTumblerLook::Remote)
        {
            Look_Remote(InLook, InSeconds);
            return;
        }

        _Tumbler.Request_Look(FMars_Request_Tumbler_Look(InLook));
    }

    // Server: InContinuation once its axle Mover's alpha moved less than k_StillAlpha between the first polls of
    // k_StillFrames successive frames (the lever's spring has caught up with the last look).
    protected void Await_AxleStillThen(FName InContinuation)
    {
        _StillContinuation = InContinuation;
        _StillFrames = 0;
        _StillFrame = -1;
        _StillAlpha = -1.0f;
        WaitUntil(n"Is_RigAxleStill", n"OnRigAxleStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigAxleStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Frame = utils_time::Get_FrameCounter();
        if (Frame != _StillFrame)
        {
            const auto Alpha = Get_AxleMover().Get_Alpha();
            _StillFrames = Math::Abs(Alpha - _StillAlpha) < constants_heat_station_net_autotest::k_StillAlpha ? _StillFrames + 1 : 0;
            _StillAlpha = Alpha;
            _StillFrame = Frame;
        }

        auto Result = OutResult;
        Result.Set(_StillFrames >= constants_heat_station_net_autotest::k_StillFrames);
    }

    UFUNCTION()
    private void OnRigAxleStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(1, _StillContinuation);
    }

    // Server: InRock's looks, one a frame, then InContinuation the frame after the last.
    protected void Rock_LeverThen(FMars_TESTONLY_NetTumblerRock InRock, FName InContinuation)
    {
        _TumblerRock = InRock;
        _LookRoute = InRock.Look;
        _RockContinuation = InContinuation;
        _RockStartSeconds = System::GetGameTimeInSeconds();
        _RockLastSeconds = _RockStartSeconds;
        _RockFrames = 0;
        WaitFrames(1, n"OnRigRock");
    }

    UFUNCTION()
    private void OnRigRock(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Now = System::GetGameTimeInSeconds();
        if (Now - _RockStartSeconds >= float64(_TumblerRock.Seconds))
        {
            WaitFrames(1, _RockContinuation);
            return;
        }

        const auto IsFlipped = _TumblerRock.HalfCycleFrames > 0 && Math::IntegerDivisionTrunc(_RockFrames, _TumblerRock.HalfCycleFrames) % 2 == 1;
        Send_Look(Get_LookAlongPull(IsFlipped ? -_TumblerRock.Degrees : _TumblerRock.Degrees), float32(Now - _RockLastSeconds));
        _RockLastSeconds = Now;
        _RockFrames += 1;
        WaitFrames(1, n"OnRigRock");
    }

    // Server: the fryer's piece InId moved to rest on the basket floor's centre, level with the basket, its bottom 1 cm above
    // the floor.
    protected void Put_IntoBasket(FMars_CookingFeed_PieceId InId)
    {
        const auto Basket = _Fry.Get_BasketWorld();
        const auto Piece = _Fry.Get_PieceState(InId);
        const auto Rotation = Basket.GetRotation();
        const auto Centre = Basket.TransformPosition(FVector(0.0, 0.0, Piece.HalfExtents.Z + 1.0));
        auto Body = Piece.Body;
        utils_jolt_body::Request_Teleport(Body, FCk_Request_JoltBody_Teleport(Centre - Rotation.RotateVector(Piece.CentreLocal), Rotation.Rotator()));
    }

    // Server: the fryer holds InId in the oil.
    protected bool Get_IsInOil(FMars_CookingFeed_PieceId InId)
    {
        return _Fry.Get_HasPiece(InId) && _Fry.Get_PieceWhereabouts(InId) == EMars_Fry_Whereabouts::Oil;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the operator
    //----------------------------------------------------------------------------------------------------------------------

    // Every row starts at the seed serial, released, and the look total and its seconds at zero.
    private void Reset_RemoteRows()
    {
        _RemoteRows.Empty();
        _LookTotal = FVector::ZeroVector;
        _LookSeconds = 0.0f;
        auto Intents = TArray<FGameplayTag>();
        Intents.Add(GameplayTags::Mars_Intent_Interact_Primary);
        Intents.Add(GameplayTags::Mars_Intent_Interact_Secondary);
        Intents.Add(GameplayTags::Mars_Intent_StationAddFood);
        if (Get_HeatStation() == EMars_TESTONLY_HeatStation::Tumbler)
        { Intents.Add(GameplayTags::Mars_Intent_Interact_Use); }

        for (const auto& Intent : Intents)
        {
            auto Row = FMars_TESTONLY_NetHeatRemoteRow();
            Row.Intent = Intent;
            Row.PressSerial = constants_feed_station_net_autotest::k_SeedSerial;
            _RemoteRows.Add(Row);
        }
    }

    // Server: one remote sample carrying the look total, its seconds and every row as it stands now.
    protected void Apply_RemoteSample()
    {
        auto Sample = FMars_InputIntents_RemoteSample();
        Sample.LookTotal = _LookTotal;
        Sample.LookSeconds = _LookSeconds;
        for (const auto& Row : _RemoteRows)
        { Sample.Intents.Add(FMars_InputIntents_RemoteIntent(Row.Intent, Row.PressSerial, Row.Hold)); }

        _Intents.Request_ApplyRemoteSample(FMars_Request_InputIntents_ApplyRemoteSample(Sample));
    }

    // Server: a remote look of InDegrees (X yaw right+, Y pitch down+) that took InSeconds on the sender, in one sample.
    protected void Look_Remote(FVector InDegrees, float32 InSeconds)
    {
        _LookTotal += InDegrees;
        _LookSeconds += InSeconds;
        Apply_RemoteSample();
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

    UFUNCTION()
    private void OnRigFryPieceAdded(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _FryAddedIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnRigSkimChanged(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        _SkimChanges.Add(InSkim);
    }

    UFUNCTION()
    private void OnRigSkimRefused(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        _SkimRefusals.Add(InSkim);
    }

    UFUNCTION()
    private void OnRigFryTakeOutRefused(FCk_Handle_Fry InFry, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        _FryTakeOutRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigFryAdmissionRefused(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_Fry_AdmissionRefusal InRefusal)
    {
        _FryAdmissionRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigFaceHeatStage(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_FoodPiece_Face InFace, EMars_Fry_HeatStage InStage)
    {
        _StageIds.Add(InPieceId);
        _StageFaces.Add(InFace);
        _Stages.Add(InStage);
    }

    UFUNCTION()
    private void OnRigPieceDrained(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId)
    {
        _DrainedIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnRigHatchChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Hatch InHatch)
    {
        _HatchChanges.Add(InHatch);
    }

    UFUNCTION()
    private void OnRigHoverChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Target InTarget)
    {
        _HoverChanges.Add(InTarget);
    }

    UFUNCTION()
    private void OnRigDrumChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Drum InDrum)
    {
        _DrumChanges.Add(InDrum);
    }

    UFUNCTION()
    private void OnRigHandModeChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_HandMode InHandMode)
    {
        _HandModeChanges.Add(InHandMode);
    }

    UFUNCTION()
    private void OnRigPressRefused(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Refusal InRefusal)
    {
        _PressRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigTumblerTakeOutRefused(FCk_Handle_Tumbler InTumbler, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        _TumblerTakeOutRefusals.Add(InRefusal);
    }

    UFUNCTION()
    private void OnRigTumblerPieceAdded(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        _TumblerAddedIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnBornBowlChanged(FCk_Handle_Batter InBatter, EMars_Batter_Bowl InBowl)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::BowlChanged, int32(InBowl));
    }

    UFUNCTION()
    private void OnBornBatterPieceAdded(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::PieceAdded, 0);
        _BornAddedIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnBornAdmissionRefused(FCk_Handle_Batter InBatter, FMars_CookingFeed_PieceId InPieceId, EMars_Batter_AdmissionRefusal InRefusal)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::AdmissionRefused, 0);
    }

    UFUNCTION()
    private void OnBornBatterTakeOutRefused(FCk_Handle_Batter InBatter, EMars_Batter_TakeOutRefusal InRefusal)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused, 0);
    }

    UFUNCTION()
    private void OnBornHeatChanged(FCk_Handle_Searing InSearing, EMars_Searing_Heat InHeat)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::HeatChanged, int32(InHeat));
    }

    UFUNCTION()
    private void OnBornPanTakeOutRefused(FCk_Handle_Searing InSearing, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused, 0);
    }

    UFUNCTION()
    private void OnBornFaceSeared(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, EMars_FoodPiece_Face InFace)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::FaceSeared, 0);
    }

    UFUNCTION()
    private void OnBornPanPieceAdded(FCk_Handle_Searing InSearing, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::PieceAdded, 0);
        _BornAddedIds.Add(InPieceId);
    }

    UFUNCTION()
    private void OnBornPressRefused(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Refusal InRefusal)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::PressRefused, 0);
    }

    UFUNCTION()
    private void OnBornTumblerTakeOutRefused(FCk_Handle_Tumbler InTumbler, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused, 0);
    }

    UFUNCTION()
    private void OnBornHatchChanged(FCk_Handle_Tumbler InTumbler, EMars_Tumbler_Hatch InHatch)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::HatchChanged, int32(InHatch));
    }

    UFUNCTION()
    private void OnBornTumblerPieceAdded(FCk_Handle_Tumbler InTumbler, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::PieceAdded, 0);
        _BornAddedIds.Add(InPieceId);
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnBornBatterNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_IsLive(InHandle) == false || InHandle.Has_Fragment(FMars_Fragment_Batter_Net) == false)
        { return; }

        _BornNotifyFrames.Add(utils_time::Get_FrameCounter());
        _BornBatterLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Batter_Net));
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnBornSearingNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_IsLive(InHandle) == false || InHandle.Has_Fragment(FMars_Fragment_Searing_Net) == false)
        { return; }

        _BornNotifyFrames.Add(utils_time::Get_FrameCounter());
        _BornSearingLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Searing_Net));
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnBornTumblerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_IsLive(InHandle) == false || InHandle.Has_Fragment(FMars_Fragment_Tumbler_Net) == false)
        { return; }

        _BornNotifyFrames.Add(utils_time::Get_FrameCounter());
        _BornTumblerLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Tumbler_Net));
    }

    UFUNCTION()
    private void OnBornSkimChanged(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::SkimChanged, int32(InSkim));
    }

    UFUNCTION()
    private void OnBornSkimRefused(FCk_Handle_Fry InFry, EMars_Fry_Skim InSkim)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::SkimRefused, 0);
    }

    UFUNCTION()
    private void OnBornFryTakeOutRefused(FCk_Handle_Fry InFry, EMars_CookingFeed_TakeOutRefusal InRefusal)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::TakeOutRefused, 0);
    }

    UFUNCTION()
    private void OnBornFryAdmissionRefused(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, EMars_Fry_AdmissionRefusal InRefusal)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::AdmissionRefused, 0);
    }

    UFUNCTION()
    private void OnBornFryPieceAdded(FCk_Handle_Fry InFry, FMars_CookingFeed_PieceId InPieceId, FCk_Handle InPiece)
    {
        Add_BornEvent(EMars_TESTONLY_NetHeatBornEventKind::PieceAdded, 0);
        _BornAddedIds.Add(InPieceId);
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnBornFryNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_IsLive(InHandle) == false || InHandle.Has_Fragment(FMars_Fragment_Fry_Net) == false)
        { return; }

        _BornNotifyFrames.Add(utils_time::Get_FrameCounter());
        _BornFryLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Fry_Net));
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnBornSkimmerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (Get_IsLive(InHandle) == false || InHandle.Has_Fragment(FMars_Fragment_Fry_SkimmerNet) == false)
        { return; }

        _BornSkimmerNotifyFrames.Add(utils_time::Get_FrameCounter());
        _BornSkimmerLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Fry_SkimmerNet));
    }
}
