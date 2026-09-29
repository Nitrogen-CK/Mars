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
    bool IsAsserted = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_MechanismSource_OnAssertedChanged(FCk_Handle_MechanismSource InSource, bool InAsserted);
event void FMars_Delegate_MechanismSource_OnAssertedChanged_MC(FCk_Handle_MechanismSource InSource, bool InAsserted);

struct FMars_Fragment_MechanismSource_Signals
{
    FMars_Delegate_MechanismSource_OnAssertedChanged_MC OnAssertedChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

struct FMars_Request_MechanismSource_SetAsserted
{
    UPROPERTY()
    bool Asserted = false;

    FMars_Request_MechanismSource_SetAsserted(bool InAsserted)
    {
        Asserted = InAsserted;
    }
}

// Absolute and latest-wins, so the fragment holds a single pending request; its presence means pending.
struct FMars_Fragment_MechanismSource_Requests
{
    UPROPERTY()
    FMars_Request_MechanismSource_SetAsserted SetAsserted;
}
