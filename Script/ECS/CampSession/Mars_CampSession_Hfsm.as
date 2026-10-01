// Camp phase machine (composed on the camp-session entity by utils_camp_session::Add).
//   Lobby : menu up, viewer pawns          (initial unless the spec says StartLive)
//   Live  : chefs spawned, camp playable
// Both states are sinks: no declared transitions and no conditions. The ONLY way between them is the explicit
// utils_state_machine::Request_Transition issued by UMars_Processor_CampSession_HandleRequests when a Play request
// drains (Request_Transition validates only the target class - CkStateMachine_Utils.cpp:152-170).

class UMars_SmState_Camp_Lobby : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Camp SM: Lobby", n"CampSM", 2.0f, FLinearColor(0.6f, 0.6f, 1.0f, 1.0f));
    }
}

class UMars_SmState_Camp_Live : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Camp SM: Live", n"CampSM", 2.0f, FLinearColor(0.3f, 1.0f, 0.3f, 1.0f));
    }
}
