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

// Loose fragment - no processor. The matcher arrives late (the input profile composes its layer on
// a retry tick), so readers resolve it on every read and treat an invalid matcher as "no input yet".
struct FMars_Fragment_InputIntents
{
    UPROPERTY()
    FCk_Handle_IntentMatcher Matcher;

    // Move stays on Enhanced Input (an analog pair, not a button the matcher grades).
    UPROPERTY()
    FVector MoveDirection = FVector::ZeroVector;
}
