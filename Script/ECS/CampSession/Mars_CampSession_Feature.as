//--------------------------------------------------------------------------------------------------------------------------
// Dynamic Handle Definition
//--------------------------------------------------------------------------------------------------------------------------

asset Mars_CampSessionHandle of UCkDynamic_HandleDefinition
{
    TypeName = "FCk_Handle_CampSession";
    RequiredFragments.Add(FMars_Feature_CampSession);
    Description = "The camp's session phase - Lobby (menu up, viewer pawns) or Live (chefs spawned) - mirrored from a CkStateMachine";
}
struct FMars_Feature_CampSession {}

// Lobby: the menu is up and every player holds a viewer pawn. Live: the chefs are spawned and the camp is playable.
// Live never returns to Lobby in this package (a fresh map load is the reset).
enum EMars_CampPhase
{
    Lobby,
    Live
}

//--------------------------------------------------------------------------------------------------------------------------
// Spec
//--------------------------------------------------------------------------------------------------------------------------

// Consumed at Add; not retained (no Params fragment).
struct FMars_CampSession_Spec
{
    // Test hook: construct already Live (the state machine starts in the Live state). Gameplay leaves it false.
    UPROPERTY()
    bool StartLive = false;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Phase is a MIRROR of the state machine's current state, written only by Add and UMars_Processor_CampSession_Sync.
// Consumers read Phase / bind OnPhaseChanged; they never touch the state machine (design D1).
struct FMars_Fragment_CampSession
{
    UPROPERTY()
    EMars_CampPhase Phase = EMars_CampPhase::Lobby;

    // The phase machine: UMars_SmState_Camp_Lobby / UMars_SmState_Camp_Live, moved only by explicit transitions
    // issued by UMars_Processor_CampSession_HandleRequests.
    UPROPERTY()
    FCk_Handle_StateMachine StateMachine;
}

//--------------------------------------------------------------------------------------------------------------------------
// Signals
//--------------------------------------------------------------------------------------------------------------------------

delegate void FMars_Delegate_CampSession_OnPhaseChanged(FCk_Handle_CampSession InSession, EMars_CampPhase InPrevious, EMars_CampPhase InNew);
event void FMars_Delegate_CampSession_OnPhaseChanged_MC(FCk_Handle_CampSession InSession, EMars_CampPhase InPrevious, EMars_CampPhase InNew);

struct FMars_Fragment_CampSession_Signals
{
    FMars_Delegate_CampSession_OnPhaseChanged_MC OnPhaseChanged;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Lobby -> Live. Ignored while Live. AngelScript rejects a TArray of an empty struct, so it carries one placeholder field.
struct FMars_Request_CampSession_Play
{
    UPROPERTY()
    bool Requested = true;

    FMars_Request_CampSession_Play() {}
}

struct FMars_Fragment_CampSession_Requests
{
    UPROPERTY()
    TArray<FMars_Request_CampSession_Play> PlayRequests;
}
