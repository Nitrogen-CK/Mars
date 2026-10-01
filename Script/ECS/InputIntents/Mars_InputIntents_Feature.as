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

// Written only by UMars_Processor_InputIntents_HandleRequests, from the input profile's SetMatcher /
// SetMoveDirection / AddLookDelta requests - so Get_Matcher / Get_MoveDirection / Get_LookDelta read one drain behind
// the write. The matcher arrives
// late (the input profile composes its layer on a retry tick), so readers resolve it on every read and treat an invalid
// matcher as "no input yet". Consumers of the matcher's own signals rebind on OnMatcherChanged.
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

struct FMars_Fragment_InputIntents_Requests
{
    UPROPERTY()
    TArray<FMars_Request_InputIntents_SetMatcher> SetMatcherRequests;

    UPROPERTY()
    TArray<FMars_Request_InputIntents_SetMoveDirection> SetMoveDirectionRequests;

    UPROPERTY()
    TArray<FMars_Request_InputIntents_AddLookDelta> AddLookDeltaRequests;
}
