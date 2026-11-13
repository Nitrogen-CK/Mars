// Local on every machine: nothing here replicates. Where the player's input profile runs, the matcher and the look feed
// it. The authority's copy of a remote operator is fed instead by the operator's remote samples (running totals and press
// serials, so a lost sample loses nothing), applied into FMars_Fragment_InputIntents_Remote; the getters read the matcher
// when it is valid and the remote state otherwise. A remote look also carries the seconds it took on the sender: samples
// bunch on the wire, so a look the authority drains in one frame may have taken several, and a reader judging its speed
// (a flick) reads those seconds instead of its own frame.

//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_InputIntentsHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_InputIntents";
    RequiredFragments.Add(FMars_Feature_InputIntents);
    Description = "An entity whose gameplay reads the CkIntent matcher of the input layer that drives it";
}
struct FMars_Feature_InputIntents {}

//--------------------------------------------------------------------------------------------------------------------------
// Fragments
//--------------------------------------------------------------------------------------------------------------------------

// Written only by UMars_Processor_InputIntents_HandleRequests, from the input profile's SetMatcher / SetMoveDirection /
// AddLookDelta requests, so the getters read one drain behind the write. The matcher arrives late (the input profile
// composes its layer on a retry tick), so readers resolve it on every read and treat an invalid matcher as "no input
// yet". Consumers of the matcher's own signals rebind on OnMatcherChanged.
struct FMars_Fragment_InputIntents
{
    UPROPERTY()
    FCk_Handle_IntentMatcher Matcher;

    // Move stays on Enhanced Input (an analog pair, not a button the matcher grades).
    UPROPERTY()
    FVector MoveDirection = FVector::ZeroVector;

    // Look stays on Enhanced Input (an analog pair). The last drained per-frame delta in the camera director's
    // intention units (X yaw right+, Y pitch DOWN+), and a counter that advances once per drain that carried one -
    // a reader applies a delta once per sequence value, whatever the processor order, and a still frame advances nothing.
    UPROPERTY()
    FVector LookDelta = FVector::ZeroVector;

    UPROPERTY()
    int32 LookDeltaSequence = 0;

    // Written with every look delta: the sender's seconds the delta took when it came from remote samples alone and they
    // cover some time; unset for a local look (it took this frame) or a drain that mixed both.
    UPROPERTY()
    TOptional<float32> LookDeltaSeconds;
}

//--------------------------------------------------------------------------------------------------------------------------
// Polled readers
//--------------------------------------------------------------------------------------------------------------------------

// What one intent row did between two polls of a reader.
enum EMars_IntentEdge
{
    None,
    Pressed,
    Released,
    // A release and a fresh press between two polls (a new activation frame while one was already seen).
    ReleasedAndPressed
}

// One intent row's edges, polled: the activation frame of the hold last seen (unset while it is not held).
struct FMars_IntentEdge
{
    TOptional<int32> Seen;
}

// One look-delta reader: the look sequence last seen.
struct FMars_LookCursor
{
    int32 Seen = 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Remote input
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_InputIntents_Hold
{
    Released,
    Held
}

// One intent row as the sending machine sees it: how many presses it has counted and whether it is held now.
struct FMars_InputIntents_RemoteIntent
{
    UPROPERTY()
    FGameplayTag Intent;

    UPROPERTY()
    int32 PressSerial = 0;

    UPROPERTY()
    EMars_InputIntents_Hold Hold = EMars_InputIntents_Hold::Released;

    FMars_InputIntents_RemoteIntent() {}

    FMars_InputIntents_RemoteIntent(FGameplayTag InIntent, int32 InPressSerial, EMars_InputIntents_Hold InHold)
    {
        Intent = InIntent;
        PressSerial = InPressSerial;
        Hold = InHold;
    }
}

// What an operating machine sends the authority: totals, never deltas, so any later sample carries what a lost one did.
// LookTotal is the running sum of every look delta the sampler has seen; LookSeconds the running sum of the sender's frame
// seconds over the frames in which LookTotal moved.
struct FMars_InputIntents_RemoteSample
{
    UPROPERTY()
    FVector LookTotal = FVector::ZeroVector;

    UPROPERTY()
    float32 LookSeconds = 0.0f;

    UPROPERTY()
    TArray<FMars_InputIntents_RemoteIntent> Intents;
}

// One sampled intent on the sending machine: the edge over its activation frame and the presses counted so far.
struct FMars_InputIntents_SamplerRow
{
    FGameplayTag Intent;
    FMars_IntentEdge Edge;
    int32 PressSerial = 0;
}

// The sending machine's running state (local to the sender, never replicated); empty Rows = not seeded yet.
struct FMars_InputIntents_Sampler
{
    FMars_LookCursor Look;
    FVector LookTotal = FVector::ZeroVector;
    float32 LookSeconds = 0.0f;
    TArray<FMars_InputIntents_SamplerRow> Rows;
}

// One intent row as the authority last applied it. ActivationFrame stamps the first press of the row's current run and
// Presses counts the run: presses that landed together (a late burst, a sample making up lost ones) are read one a frame,
// never merged (utils_input_intents::TryGet_RemoteActivationFrame). The run's last press reads while Held, and while
// Released through constants_input_intents::k_ReleasedPressFrames after the frame it first read on.
struct FMars_InputIntents_RemoteRow
{
    UPROPERTY()
    FGameplayTag Intent;

    UPROPERTY()
    int32 PressSerial = 0;

    UPROPERTY()
    EMars_InputIntents_Hold Hold = EMars_InputIntents_Hold::Released;

    UPROPERTY()
    TOptional<int32> ActivationFrame;

    UPROPERTY()
    int32 Presses = 0;
}

// Local, on the authority's copy of a remote operator: written only by UMars_Processor_InputIntents_HandleRequests from
// ApplyRemoteSample, emptied by ClearRemote. LookTotal unset = no sample since the last clear (the next one seeds);
// LookSeconds is seeded and cleared with it.
struct FMars_Fragment_InputIntents_Remote
{
    UPROPERTY()
    TOptional<FVector> LookTotal;

    UPROPERTY()
    TOptional<float32> LookSeconds;

    UPROPERTY()
    TArray<FMars_InputIntents_RemoteRow> Rows;
}

// One drain of remote samples, while it runs: the frame it stamps and the look total and look seconds it moves from
// (unset until a seed).
struct FMars_InputIntents_RemoteDrain
{
    FCk_Handle_InputIntents Intents;
    int32 Frame = 0;
    TOptional<FVector> LookStart;
    TOptional<float32> LookSecondsStart;
}

// How far one drain's remote samples moved the look total, and the sender's seconds that move took.
struct FMars_InputIntents_RemoteLookMove
{
    FVector Delta = FVector::ZeroVector;
    float32 Seconds = 0.0f;
}

namespace constants_input_intents
{
    // A sender repeats an unchanged sample this often (frames), so a lost last sample (a release) still lands.
    const int32 k_KeepAliveFrames = 6;

    // Frames after the one it first read on that a run's last press, already released, still reads active.
    const int32 k_ReleasedPressFrames = 1;

    // The most presses one run holds, so the most one sample makes up; a serial that jumps further is clamped to it.
    const int32 k_MaxRemoteRunPresses = 8;

    // Every intent a station's operator-input reader advances on: what a remote operator's samples carry.
    TArray<FGameplayTag> Get_OperatorIntents()
    {
        auto Intents = TArray<FGameplayTag>();
        Intents.Add(GameplayTags::Mars_Intent_Interact_Primary);
        Intents.Add(GameplayTags::Mars_Intent_Interact_Secondary);
        Intents.Add(GameplayTags::Mars_Intent_Interact_Use);
        Intents.Add(GameplayTags::Mars_Intent_StationAddFood);
        Intents.Add(GameplayTags::Mars_Intent_Drop);
        return Intents;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_InputIntents_OnMatcherChanged(FCk_Handle_InputIntents InIntents, FCk_Handle_IntentMatcher InPrev, FCk_Handle_IntentMatcher InNew);
event void FMars_Delegate_InputIntents_OnMatcherChanged_MC(FCk_Handle_InputIntents InIntents, FCk_Handle_IntentMatcher InPrev, FCk_Handle_IntentMatcher InNew);

struct FMars_Fragment_InputIntents_Signals
{
    FMars_Delegate_InputIntents_OnMatcherChanged_MC OnMatcherChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_InputIntents_SetMatcher
{
    UPROPERTY()
    FCk_Handle_IntentMatcher Matcher;

    FMars_Request_InputIntents_SetMatcher() {}

    FMars_Request_InputIntents_SetMatcher(const FCk_Handle_IntentMatcher& InMatcher)
    {
        Matcher = InMatcher;
    }
}

struct FMars_Request_InputIntents_SetMoveDirection
{
    UPROPERTY()
    FVector MoveDirection = FVector::ZeroVector;

    FMars_Request_InputIntents_SetMoveDirection() {}

    FMars_Request_InputIntents_SetMoveDirection(const FVector& InMoveDirection)
    {
        MoveDirection = InMoveDirection;
    }
}

// One frame's look delta; the drain sums every one it holds.
struct FMars_Request_InputIntents_AddLookDelta
{
    UPROPERTY()
    FVector LookDelta = FVector::ZeroVector;

    FMars_Request_InputIntents_AddLookDelta() {}

    FMars_Request_InputIntents_AddLookDelta(const FVector& InLookDelta)
    {
        LookDelta = InLookDelta;
    }
}

// One remote operator sample, applied on the authority's copy of that operator.
struct FMars_Request_InputIntents_ApplyRemoteSample
{
    UPROPERTY()
    FMars_InputIntents_RemoteSample Sample;

    FMars_Request_InputIntents_ApplyRemoteSample() {}

    FMars_Request_InputIntents_ApplyRemoteSample(const FMars_InputIntents_RemoteSample& InSample)
    {
        Sample = InSample;
    }
}

// Drops the remote state: no hold outlives the station it was for, and the next sample seeds.
struct FMars_Request_InputIntents_ClearRemote
{
    UPROPERTY()
    bool Requested = true;
}

struct FMars_Fragment_InputIntents_Requests
{
    UPROPERTY()
    TArray<FMars_Request_InputIntents_SetMatcher> SetMatcherRequests;

    UPROPERTY()
    TArray<FMars_Request_InputIntents_SetMoveDirection> SetMoveDirectionRequests;

    UPROPERTY()
    TArray<FMars_Request_InputIntents_AddLookDelta> AddLookDeltaRequests;

    UPROPERTY()
    TArray<FMars_Request_InputIntents_ClearRemote> ClearRemoteRequests;

    UPROPERTY()
    TArray<FMars_Request_InputIntents_ApplyRemoteSample> ApplyRemoteSampleRequests;
}
