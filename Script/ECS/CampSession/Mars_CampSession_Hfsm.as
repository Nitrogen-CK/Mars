// Camp phase machine. Both states are sinks with no declared transitions or conditions: the only way between them is the
// explicit Request_Transition that UMars_Processor_CampSession_HandleRequests issues when a Play request drains, which
// validates only the target class.

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
