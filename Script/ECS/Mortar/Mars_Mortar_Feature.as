// Stance: the mortar is the authority's. Only the authority's copy engages, switches, collects, presses and releases the
// pestle, strikes, lands, grinds and tallies; a copy without authority drops every request. The authority publishes a
// replicated ledger (FMars_Fragment_Mortar_Net): the engagement, the batch, the pestle's motion, the tally, a serial for
// each strike started, each landing (with the last result) and each restart of the timing window's pass, and an anchor:
// the server's clock (utils_mars_net::Get_ServerWorldSeconds) at the publish with the sweep and the grind's progress then.
// A copy without authority shows its own state fragment, written by its mirror (UMars_Processor_Mortar_Mirror) from each
// ledger that arrives and carried on between them by its tick (the sweep, and the grind while the pestle circles), both
// measured from the anchor on the server's clock; there it raises OnStrikeStarted, OnStrikeLanded and OnBatchChanged
// from the ledger after the state its copy was born into. A remote operator's pestle reaches the authority as
// Cue.Mars.Mortar.Pestle, whose press carries the sweep that operator saw: the authority judges that strike on it.

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

namespace constants_mortar
{
    // One per EMars_Mortar_Seasoning value: the tally's size and the wrap of SwitchSeasoning.
    const int32 k_SeasoningCount = 2;
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
    if (Math::IsFinite(Self.Timing.SweepSeconds) == false || Self.Timing.SweepSeconds <= 0.0f)
    { return FMars_Validation(f"Mortar has a non-positive or non-finite Timing.SweepSeconds [{Self.Timing.SweepSeconds}]"); }

    if (Math::IsFinite(Self.Timing.WindowHalfWidth) == false || Self.Timing.WindowHalfWidth <= 0.0f || Self.Timing.WindowHalfWidth > 0.5f)
    { return FMars_Validation(f"Mortar has Timing.WindowHalfWidth [{Self.Timing.WindowHalfWidth}] outside (0, 0.5]"); }

    if (Math::IsFinite(Self.Timing.Marker) == false || Self.Timing.Marker < 0.0f || Self.Timing.Marker > 1.0f)
    { return FMars_Validation(f"Mortar has Timing.Marker [{Self.Timing.Marker}] outside [0, 1]"); }

    if (Self.CrushesNeeded <= 0)
    { return FMars_Validation(f"Mortar has a non-positive CrushesNeeded [{Self.CrushesNeeded}]"); }

    if (Math::IsFinite(Self.GrindSeconds) == false || Self.GrindSeconds <= 0.0f)
    { return FMars_Validation(f"Mortar has a non-positive or non-finite GrindSeconds [{Self.GrindSeconds}]"); }

    if (Math::IsFinite(Self.StrikeSeconds) == false || Self.StrikeSeconds <= 0.0f)
    { return FMars_Validation(f"Mortar has a non-positive or non-finite StrikeSeconds [{Self.StrikeSeconds}]"); }

    return FMars_Validation();
}

// On the Mortar entity while an operator works it: the sweep, the strike and the grind clocks run only then. A copy
// without authority takes it from the ledger's Engagement.
struct FMars_Tag_Mortar_Engaged {}

// Whether an operator works the mortar, as the ledger carries it.
enum EMars_Mortar_Engagement
{
    Idle,
    Engaged
}

// Which edge of the pestle a request or a cue carries.
enum EMars_Mortar_PestleVerb
{
    Press,
    Release
}

// Whether a publish's pass of the timing window carried on or started again at 0.
enum EMars_Mortar_Sweep
{
    Kept,
    Restarted
}

// What a pestle cue carries: who works the pestle, which edge, (for a press) the sweep that machine showed, and the
// sender's running count of its pestle acts, which orders acts that reach the authority together. The cue's spawn params.
struct FMars_Mortar_PestleAct
{
    UPROPERTY()
    FCk_Handle Operator;

    UPROPERTY()
    EMars_Mortar_PestleVerb Verb = EMars_Mortar_PestleVerb::Press;

    UPROPERTY()
    float32 SweepSeconds = 0.0f;

    UPROPERTY()
    int32 Sequence = 0;

    FMars_Mortar_PestleAct() {}

    FMars_Mortar_PestleAct(FCk_Handle InOperator, EMars_Mortar_PestleVerb InVerb, float32 InSweepSeconds, int32 InSequence)
    {
        Operator = InOperator;
        Verb = InVerb;
        SweepSeconds = InSweepSeconds;
        Sequence = InSequence;
    }
}

// What a processor tells utils_mortar::Publish beyond the state: the strikes it started, the landing it made, and whether
// it restarted the timing window's pass.
struct FMars_Mortar_Answers
{
    int32 StrikesStarted = 0;
    TOptional<EMars_Mortar_Strike> Landed;
    EMars_Mortar_Sweep Sweep = EMars_Mortar_Sweep::Kept;
}

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

// Batches collected since the mortar was made, one count per EMars_Mortar_Seasoning (indexed by the enum's value).
struct FMars_Mortar_Tally
{
    UPROPERTY()
    TArray<int32> Counts;

    FMars_Mortar_Tally()
    {
        for (int32 Index = 0; Index < constants_mortar::k_SeasoningCount; ++Index)
        { Counts.Add(0); }
    }

    int32 Get_Count(EMars_Mortar_Seasoning InSeasoning) const
    {
        return Counts[int32(InSeasoning)];
    }
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

// The replicated ledger: what a copy without authority shows the mortar from. Written only by utils_mortar::Publish, which
// the authority's two mortar processors call, each write followed by its dirty mark. Batch.GrindProgress and SweepAtAnchor
// are as of AnchorServerSeconds (the server's clock at the write); the sweep's wrap and the grind's progress alone never
// cause a write.
struct FMars_Fragment_Mortar_Net
{
    UPROPERTY()
    EMars_Mortar_Engagement Engagement = EMars_Mortar_Engagement::Idle;

    UPROPERTY()
    FMars_Mortar_Batch Batch;

    UPROPERTY()
    EMars_Mortar_Pestle Motion = EMars_Mortar_Pestle::Resting;

    UPROPERTY()
    FMars_Mortar_Tally Tally;

    // One more each time the timing window's pass restarts at 0 (an Engage, a Collect).
    UPROPERTY()
    int32 SweepSerial = 0;

    UPROPERTY()
    float64 AnchorServerSeconds = 0.0;

    UPROPERTY()
    float32 SweepAtAnchor = 0.0f;

    // One per strike the authority started.
    UPROPERTY()
    int32 StrikeSerial = 0;

    // One per strike the authority landed; LastLanded is the latest's timing.
    UPROPERTY()
    int32 LandedSerial = 0;

    UPROPERTY()
    EMars_Mortar_Strike LastLanded = EMars_Mortar_Strike::Miss;
}

// Each machine's own: the ledger the mirror last reconciled (unset with authority), and whether this copy has taken the
// state it was born into.
struct FMars_Fragment_Mortar_Local
{
    UPROPERTY()
    TOptional<FMars_Fragment_Mortar_Net> Last;

    UPROPERTY()
    EMars_Net_InitialState InitialState = EMars_Net_InitialState::Awaited;
}

// Added by utils_mortar::Add, dropped by UMars_Processor_Mortar_Mirror once it has bound the ledger's rep-notify.
struct FMars_Tag_Mortar_NeedsMirror {}

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

struct FMars_Fragment_Mortar_Signals
{
    FMars_Delegate_Mortar_OnStrikeStarted_MC OnStrikeStarted;
    FMars_Delegate_Mortar_OnStrikeLanded_MC OnStrikeLanded;
    FMars_Delegate_Mortar_OnBatchChanged_MC OnBatchChanged;
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

// One edge of the pestle. Press bears it down: in the Crush phase a strike (ignored while a strike is in flight), judged
// against the timing window at ObservedSweepSeconds when it is set and finite (the sweep the operator's own machine
// showed, wrapped into the pass), else at the kernel's own sweep; in the Grind phase the grind, until a Release. Sequence
// is a remote operator's count of its acts (unset for this machine's own reader).
struct FMars_Request_Mortar_Pestle
{
    UPROPERTY()
    EMars_Mortar_PestleVerb Verb = EMars_Mortar_PestleVerb::Press;

    UPROPERTY()
    TOptional<float32> ObservedSweepSeconds;

    UPROPERTY()
    TOptional<int32> Sequence;

    FMars_Request_Mortar_Pestle() {}

    FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb InVerb)
    {
        Verb = InVerb;
    }

    FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb InVerb, float32 InObservedSweepSeconds)
    {
        Verb = InVerb;
        ObservedSweepSeconds = InObservedSweepSeconds;
    }

    FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb InVerb, TOptional<float32> InObservedSweepSeconds, int32 InSequence)
    {
        Verb = InVerb;
        ObservedSweepSeconds = InObservedSweepSeconds;
        Sequence = InSequence;
    }
}

// A Done batch leaves the bowl (the tally counts it) and a fresh one of the same seasoning takes its place. Ignored while
// the batch is not Done.
struct FMars_Request_Mortar_Collect
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_Collect() {}
}

// The next seasoning goes in the bowl (wrapping round the enum). Ignored once the batch has taken a hit.
struct FMars_Request_Mortar_SwitchSeasoning
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_Mortar_SwitchSeasoning() {}
}

// Applied Disengage -> Engage -> SwitchSeasoning -> Collect, then each pestle edge in the order it was made (this
// machine's own, as issued, then a remote operator's by its sequence), so a leave and the next operator's take can share
// a drain, and a tap whose press and release arrive together ends released.
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
    TArray<FMars_Request_Mortar_Pestle> PestleRequests;
}
