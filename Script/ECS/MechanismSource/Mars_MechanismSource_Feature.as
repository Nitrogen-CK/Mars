//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_MechanismSourceHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_MechanismSource";
    RequiredFragments.Add(FMars_Feature_MechanismSource);
    Description = "An entity that asserts one mechanism output channel (lever, switch, gate-as-relay)";
}
struct FMars_Feature_MechanismSource {}

enum EMars_MechanismSource_Output
{
    Deasserted,
    Asserted
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_MechanismSource_Spec
{
    UPROPERTY(meta = (Categories = "Mechanism.Channel"))
    FGameplayTag OutputChannel;

    UPROPERTY()
    bool StartAsserted = false;
}

mixin FMars_Validation Validate(const FMars_MechanismSource_Spec& Self)
{
    if (Self.OutputChannel.IsValid() == false)
    { return FMars_Validation("OutputChannel must be set"); }

    return FMars_Validation();
}

//--------------------------------------------------------------------------------------------------------------------------
// Params
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_MechanismSource_Params
{
    UPROPERTY()
    FGameplayTag OutputChannel;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Fragment_MechanismSource
{
    UPROPERTY()
    EMars_MechanismSource_Output Output = EMars_MechanismSource_Output::Deasserted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_MechanismSource_OnAssertedChanged(FCk_Handle_MechanismSource InSource, EMars_MechanismSource_Output InOutput);
event void FMars_Delegate_MechanismSource_OnAssertedChanged_MC(FCk_Handle_MechanismSource InSource, EMars_MechanismSource_Output InOutput);

struct FMars_Fragment_MechanismSource_Signals
{
    FMars_Delegate_MechanismSource_OnAssertedChanged_MC OnAssertedChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_MechanismSource_SetOutput
{
    UPROPERTY()
    EMars_MechanismSource_Output Output = EMars_MechanismSource_Output::Deasserted;

    FMars_Request_MechanismSource_SetOutput() {}

    FMars_Request_MechanismSource_SetOutput(EMars_MechanismSource_Output InOutput)
    {
        Output = InOutput;
    }
}

// SetOutput is absolute: the latest one wins.
struct FMars_Fragment_MechanismSource_Requests
{
    UPROPERTY()
    TArray<FMars_Request_MechanismSource_SetOutput> SetOutputRequests;
}
