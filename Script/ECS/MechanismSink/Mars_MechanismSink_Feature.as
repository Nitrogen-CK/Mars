//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_MechanismSinkHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_MechanismSink";
    RequiredFragments.Add(FMars_Feature_MechanismSink);
    Description = "An entity powered by one or more mechanism input channels combined with a rule (gate)";
}
struct FMars_Feature_MechanismSink {}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

enum EMars_MechanismSink_Rule
{
    // At least one input channel has an asserted source.
    AnyChannel,
    // Every input channel has at least one asserted source.
    AllChannels,
    // Every source on every input channel is asserted, and there is at least one source.
    AllSources
}

struct FMars_MechanismSink_Spec
{
    UPROPERTY(meta = (Categories = "Mechanism.Channel"))
    TArray<FGameplayTag> InputChannels;

    UPROPERTY()
    EMars_MechanismSink_Rule Rule = EMars_MechanismSink_Rule::AllChannels;

    // Once powered, stays powered.
    UPROPERTY()
    bool Latch = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_MechanismSink_Params
{
    UPROPERTY()
    TArray<FGameplayTag> InputChannels;

    UPROPERTY()
    EMars_MechanismSink_Rule Rule = EMars_MechanismSink_Rule::AllChannels;

    UPROPERTY()
    bool Latch = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_MechanismSink_ChannelInput
{
    UPROPERTY()
    FGameplayTag Channel;

    UPROPERTY()
    int32 AssertedCount = 0;

    UPROPERTY()
    int32 TotalCount = 0;
}

struct FMars_Fragment_MechanismSink
{
    // One entry per input channel, in spec order; counts are pushed by the mechanism driver.
    UPROPERTY()
    TArray<FMars_MechanismSink_ChannelInput> Inputs;

    UPROPERTY()
    bool IsPowered = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_MechanismSink_OnPoweredChanged(FCk_Handle_MechanismSink InSink, bool InPowered);
event void FMars_Delegate_MechanismSink_OnPoweredChanged_MC(FCk_Handle_MechanismSink InSink, bool InPowered);

struct FMars_Fragment_MechanismSink_Signals
{
    FMars_Delegate_MechanismSink_OnPoweredChanged_MC OnPoweredChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_MechanismSink_SetChannelInput
{
    UPROPERTY()
    FGameplayTag Channel;

    UPROPERTY()
    int32 AssertedCount = 0;

    UPROPERTY()
    int32 TotalCount = 0;

    FMars_Request_MechanismSink_SetChannelInput(FGameplayTag InChannel, int32 InAssertedCount, int32 InTotalCount)
    {
        Channel = InChannel;
        AssertedCount = InAssertedCount;
        TotalCount = InTotalCount;
    }
}

struct FMars_Fragment_MechanismSink_Requests
{
    // At most one entry per channel; a later request for the same channel overwrites.
    UPROPERTY()
    TArray<FMars_Request_MechanismSink_SetChannelInput> SetChannelInputRequests;
}
