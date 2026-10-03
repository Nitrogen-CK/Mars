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
// Live never returns to Lobby; a fresh map load is the reset.
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
    // The phase the state machine starts in. Gameplay starts in Lobby; tests may start Live.
    UPROPERTY()
    EMars_CampPhase StartPhase = EMars_CampPhase::Lobby;
}

//--------------------------------------------------------------------------------------------------------------------------
// State
//--------------------------------------------------------------------------------------------------------------------------

// Phase mirrors the state machine's current state, written only by Add and UMars_Processor_CampSession_Sync. Consumers
// read Phase or bind OnPhaseChanged; they never touch the state machine.
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
