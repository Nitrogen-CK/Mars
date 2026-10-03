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

// At least one input channel, each set and listed once.
mixin FMars_Validation Validate(const FMars_MechanismSink_Spec& Self)
{
    if (Self.InputChannels.Num() == 0)
    { return FMars_Validation("InputChannels must list at least one channel"); }

    for (int32 Index = 0; Index < Self.InputChannels.Num(); ++Index)
    {
        const auto Channel = Self.InputChannels[Index];
        if (Channel.IsValid() == false)
        { return FMars_Validation(f"InputChannels[{Index}] is not set"); }

        if (Self.InputChannels.FindIndex(Channel) != Index)
        { return FMars_Validation(f"InputChannels lists [{Channel.ToString()}] more than once"); }
    }

    return FMars_Validation();
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

enum EMars_MechanismSink_Power
{
    // Before the driver's first push; link setups wait for the first OnPoweredChanged instead of reading a default.
    Unevaluated,
    Unpowered,
    Powered
}

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
    EMars_MechanismSink_Power Power = EMars_MechanismSink_Power::Unevaluated;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

// Never broadcasts Unevaluated.
delegate void FMars_Delegate_MechanismSink_OnPoweredChanged(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower);
event void FMars_Delegate_MechanismSink_OnPoweredChanged_MC(FCk_Handle_MechanismSink InSink, EMars_MechanismSink_Power InPower);

// InOutput is the flipped source's new output.
delegate void FMars_Delegate_MechanismSink_OnInputEdge(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel, EMars_MechanismSource_Output InOutput);
event void FMars_Delegate_MechanismSink_OnInputEdge_MC(FCk_Handle_MechanismSink InSink, FGameplayTag InChannel, EMars_MechanismSource_Output InOutput);

struct FMars_Fragment_MechanismSink_Signals
{
    FMars_Delegate_MechanismSink_OnPoweredChanged_MC OnPoweredChanged;
    FMars_Delegate_MechanismSink_OnInputEdge_MC OnInputEdge;
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

// One source flip on an input channel, delivered by the driver in signal order; never coalesced.
struct FMars_Request_MechanismSink_NotifyInputEdge
{
    UPROPERTY()
    FGameplayTag Channel;

    UPROPERTY()
    EMars_MechanismSource_Output Output = EMars_MechanismSource_Output::Deasserted;

    FMars_Request_MechanismSink_NotifyInputEdge(FGameplayTag InChannel, EMars_MechanismSource_Output InOutput)
    {
        Channel = InChannel;
        Output = InOutput;
    }
}

struct FMars_Fragment_MechanismSink_Requests
{
    // At most one entry per channel; a later request for the same channel overwrites.
    UPROPERTY()
    TArray<FMars_Request_MechanismSink_SetChannelInput> SetChannelInputRequests;

    UPROPERTY()
    TArray<FMars_Request_MechanismSink_NotifyInputEdge> NotifyInputEdgeRequests;
}
