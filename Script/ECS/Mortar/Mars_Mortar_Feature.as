//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_MortarHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_Mortar";
    RequiredFragments.Add(FMars_Feature_Mortar);
    Description = "A mortar and pestle: a batch of seasoning crushed by timed strikes, then ground while the pestle is held down";
}
struct FMars_Feature_Mortar {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_Mortar_Seasoning
{
    Salt,
    Pepper
}

// How fine the batch is: as loaded, after the crush, after the grind.
enum EMars_Mortar_Stage
{
    Coarse,
    Cracked,
    Ground
}

// What the batch needs next: timed strikes, then a held grind; Done waits to be collected.
enum EMars_Mortar_Phase
{
    Crush,
    Grind,
    Done
}

// A strike's timing: pressed with the window on the marker, or not.
enum EMars_Mortar_Strike
{
    Hit,
    Miss
}

// Where a strike is: the pestle up and ready, on its way down, or on its way back up.
enum EMars_Mortar_StrikePhase
{
    Idle,
    Striking,
    Recovering
}

// Whether the pestle is being borne down on.
enum EMars_Mortar_Press
{
    Released,
    Held
}

// Whether the pestle is circling in the bowl.
enum EMars_Mortar_Pestle
{
    Resting,
    Grinding
}

// The crush's timing bar, in bar lengths (0 its left end, 1 its right): a window pans from off the left end to off the
// right end in SweepSeconds and starts again, and a strike pressed while the window covers the marker is a hit.
struct FMars_Mortar_TimingSpec
{
    UPROPERTY()
    float32 SweepSeconds = 1.4f;

    UPROPERTY()
    float32 WindowHalfWidth = 0.09f;

    UPROPERTY()
    float32 Marker = 0.7f;
}

// A batch is crushed by CrushesNeeded hits (a miss still strikes, and crushes nothing), then ground for GrindSeconds of
// holding the pestle down. Every clock is the kernel's: the timing bar's sweep, the strike (StrikeSeconds down, the
// landing, StrikeSeconds back up) and the grind. Whatever draws the pestle and the pile follows the signals.
struct FMars_Mortar_Spec
{
    UPROPERTY()
    FMars_Mortar_TimingSpec Timing;

    UPROPERTY()
    int32 CrushesNeeded = 4;

    UPROPERTY()
    float32 GrindSeconds = 3.5f;

    // The pestle's strike in seconds; its recover takes as long.
    UPROPERTY()
    float32 StrikeSeconds = 0.12f;

    // The first batch's seasoning.
    UPROPERTY()
    EMars_Mortar_Seasoning StartSeasoning = EMars_Mortar_Seasoning::Salt;
}

mixin FMars_Validation Validate(const FMars_Mortar_Spec& Self)
{
    if (Self.Timing.SweepSeconds <= 0.0f)
    { return FMars_Validation(f"Mortar has a non-positive Timing.SweepSeconds [{Self.Timing.SweepSeconds}]"); }

    if (Self.Timing.WindowHalfWidth <= 0.0f || Self.Timing.WindowHalfWidth > 0.5f)
    { return FMars_Validation(f"Mortar has Timing.WindowHalfWidth [{Self.Timing.WindowHalfWidth}] outside (0, 0.5]"); }

    if (Self.Timing.Marker < 0.0f || Self.Timing.Marker > 1.0f)
    { return FMars_Validation(f"Mortar has Timing.Marker [{Self.Timing.Marker}] outside [0, 1]"); }

    if (Self.CrushesNeeded <= 0)
    { return FMars_Validation(f"Mortar has a non-positive CrushesNeeded [{Self.CrushesNeeded}]"); }

    if (Self.GrindSeconds <= 0.0f)
    { return FMars_Validation(f"Mortar has a non-positive GrindSeconds [{Self.GrindSeconds}]"); }

    if (Self.StrikeSeconds <= 0.0f)
    { return FMars_Validation(f"Mortar has a non-positive StrikeSeconds [{Self.StrikeSeconds}]"); }

    return FMars_Validation();
}

// On the Mortar entity while an operator works it: the sweep, the strike and the grind clocks run only then.
struct FMars_Tag_Mortar_Engaged {}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_Mortar_Params
{
    UPROPERTY()
    FMars_Mortar_Spec Spec;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// The seasoning in the bowl and how far it has come.
struct FMars_Mortar_Batch
{
    UPROPERTY()
    EMars_Mortar_Seasoning Seasoning = EMars_Mortar_Seasoning::Salt;

    UPROPERTY()
    EMars_Mortar_Stage Stage = EMars_Mortar_Stage::Coarse;

    UPROPERTY()
    EMars_Mortar_Phase Phase = EMars_Mortar_Phase::Crush;

    // Hits landed so far in the Crush phase.
    UPROPERTY()
    int32 CrushHits = 0;

    // 0..1 of the Grind phase.
    UPROPERTY()
    float32 GrindProgress = 0.0f;
}

struct FMars_Mortar_PestleState
{
    UPROPERTY()
    EMars_Mortar_StrikePhase StrikePhase = EMars_Mortar_StrikePhase::Idle;

    // Seconds left in the current phase of the strike (Spec.StrikeSeconds at each phase's start); 0 while Idle.
    UPROPERTY()
    float32 StrikeSecondsLeft = 0.0f;

    // The strike in flight's timing, judged at its press and applied at its landing.
    UPROPERTY()
    EMars_Mortar_Strike Pending = EMars_Mortar_Strike::Miss;

    UPROPERTY()
    EMars_Mortar_Press Press = EMars_Mortar_Press::Released;

    UPROPERTY()
    EMars_Mortar_Pestle Motion = EMars_Mortar_Pestle::Resting;
}

// Batches collected since the mortar was made.
struct FMars_Mortar_Tally
{
    UPROPERTY()
    int32 Salt = 0;

    UPROPERTY()
    int32 Pepper = 0;
}

// Written only by the Mortar processors (and Add). The station SM and the operator only issue requests.
struct FMars_Fragment_Mortar
{
    UPROPERTY()
    FMars_Mortar_Batch Batch;

    UPROPERTY()
    FMars_Mortar_PestleState Pestle;

    // Seconds into the timing window's current pass, in [0, Timing.SweepSeconds).
    UPROPERTY()
    float32 SweepSeconds = 0.0f;

    UPROPERTY()
    FMars_Mortar_Tally Tally;
}

// The timing bar as its meter draws it, in bar lengths: the window's middle (off the bar at the ends of a pass), its half
// width, and the marker a strike is judged against.
struct FMars_Mortar_Window
{
    UPROPERTY()
    float32 Centre = 0.0f;

    UPROPERTY()
    float32 HalfWidth = 0.0f;

    UPROPERTY()
    float32 Marker = 0.0f;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Broadcast as a strike starts: the pestle leaves its raised pose for the bowl, reaching it StrikeSeconds later.
delegate void FMars_Delegate_Mortar_OnStrikeStarted(FCk_Handle_Mortar InMortar);
event void FMars_Delegate_Mortar_OnStrikeStarted_MC(FCk_Handle_Mortar InMortar);

// Broadcast at the pestle's contact with the batch, as it starts back up, with the strike's timing.
delegate void FMars_Delegate_Mortar_OnStrikeLanded(FCk_Handle_Mortar InMortar, EMars_Mortar_Strike InStrike);
event void FMars_Delegate_Mortar_OnStrikeLanded_MC(FCk_Handle_Mortar InMortar, EMars_Mortar_Strike InStrike);

// Broadcast on every step of the batch: a hit, a change of stage or phase, a new batch, another seasoning. Not on the
// grind's progress, which moves every frame.
delegate void FMars_Delegate_Mortar_OnBatchChanged(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch);
event void FMars_Delegate_Mortar_OnBatchChanged_MC(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch);

// Broadcast as the pestle starts and stops circling.
delegate void FMars_Delegate_Mortar_OnPestleChanged(FCk_Handle_Mortar InMortar, EMars_Mortar_Pestle InPestle);
event void FMars_Delegate_Mortar_OnPestleChanged_MC(FCk_Handle_Mortar InMortar, EMars_Mortar_Pestle InPestle);

// Broadcast as a ground batch leaves the bowl (before OnBatchChanged for the new one).
delegate void FMars_Delegate_Mortar_OnCollected(FCk_Handle_Mortar InMortar, EMars_Mortar_Seasoning InSeasoning);
event void FMars_Delegate_Mortar_OnCollected_MC(FCk_Handle_Mortar InMortar, EMars_Mortar_Seasoning InSeasoning);

struct FMars_Fragment_Mortar_Signals
{
    FMars_Delegate_Mortar_OnStrikeStarted_MC OnStrikeStarted;
    FMars_Delegate_Mortar_OnStrikeLanded_MC OnStrikeLanded;
    FMars_Delegate_Mortar_OnBatchChanged_MC OnBatchChanged;
    FMars_Delegate_Mortar_OnPestleChanged_MC OnPestleChanged;
    FMars_Delegate_Mortar_OnCollected_MC OnCollected;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// An operator takes the mortar: the timing window starts a pass and the clocks run. Payload-less: one placeholder field
// (request doctrine), as every request here.
struct FMars_Request_Mortar_Engage
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_Engage() {}
}

// The operator leaves: the pestle is let go (a strike in flight is dropped, a grind stops) and the clocks stop. The batch
// stays as it is for the next operator.
struct FMars_Request_Mortar_Disengage
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_Disengage() {}
}

// The pestle is borne down: in the Crush phase a strike, judged against the timing window as it is pressed (ignored while
// a strike is in flight); in the Grind phase the grind, until Release.
struct FMars_Request_Mortar_Press
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_Press() {}
}

struct FMars_Request_Mortar_Release
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_Release() {}
}

// A Done batch leaves the bowl (the tally counts it) and a fresh one of the same seasoning takes its place. Ignored while
// the batch is not Done.
struct FMars_Request_Mortar_Collect
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_Collect() {}
}

// The other seasoning goes in the bowl. Ignored once the batch has taken a hit.
struct FMars_Request_Mortar_SwitchSeasoning
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_SwitchSeasoning() {}
}

// Applied Disengage -> Engage -> SwitchSeasoning -> Collect -> Release -> Press, so a leave and the next operator's take,
// or a release and a new press between two ticks, can share a drain.
struct FMars_Fragment_Mortar_Requests
{
    UPROPERTY()
    TArray<FMars_Request_Mortar_Disengage> DisengageRequests;

    UPROPERTY()
    TArray<FMars_Request_Mortar_Engage> EngageRequests;

    UPROPERTY()
    TArray<FMars_Request_Mortar_SwitchSeasoning> SwitchSeasoningRequests;

    UPROPERTY()
    TArray<FMars_Request_Mortar_Collect> CollectRequests;

    UPROPERTY()
    TArray<FMars_Request_Mortar_Release> ReleaseRequests;

    UPROPERTY()
    TArray<FMars_Request_Mortar_Press> PressRequests;
}
