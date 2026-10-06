// Drains Reset -> SetHeat -> Look. Reset destroys the live and the lingering steaks, resets the pan and chills it and
// zeroes the tally (the Tick spawns a fresh steak next frame); SetHeat is last-wins and drives the pan (Driven while hot);
// looks are forwarded to the pan while it is hot and the steak not done. The pan feature measures the looks in its Tick.
class UMars_Processor_Searing_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Searing_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Searing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Searing_Requests& InRequests,
                       FMars_Fragment_Searing& InState)
    {
        auto Self = InHandle.As_Searing();
        auto Pan = Self.Get_Pan();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Searing_SetHeat> SetHeatRequests = InRequests.SetHeatRequests;
        TArray<FMars_Request_Searing_Look> LookRequests = InRequests.LookRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Searing_Requests);

        const auto StartHeat = InState.Heat;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (SetHeatRequests.Num() > 0)
        { InState.Heat = SetHeatRequests.Last().Heat; }

        const auto NewHeat = InState.Heat;

        // The pan's reset idles it, so a reset re-sends the drive too (a reset and a heat can share a drain).
        if (HasReset || NewHeat != StartHeat)
        {
            const auto Drive = NewHeat == EMars_Searing_Heat::Hot ? EMars_Implement_Drive::Driven : EMars_Implement_Drive::Idle;
            Pan.Request_SetDrive(FMars_Request_Implement_SetDrive(Drive));
        }

        if (NewHeat == EMars_Searing_Heat::Hot && InState.Phase != EMars_Searing_Phase::Done)
        {
            for (const auto& Request : LookRequests)
            { Pan.Request_Look(FMars_Request_Implement_Look(Request.LookDelta)); }
        }

        if (NewHeat == StartHeat || Self.Has_Fragment(FMars_Fragment_Searing_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Searing_Signals).OnHeatChanged.Broadcast(Self, NewHeat);
    }

    // Every steak this kernel spawned is destroyed here (the lost ones too), never left to the station's teardown alone.
    private void Apply_Reset(FCk_Handle_Searing& InSearing, FMars_Fragment_Searing& InState)
    {
        if (ck::IsValid(InState.Steak.Entity))
        { utils_entity_lifetime::Request_DestroyEntity(InState.Steak.Entity); }

        for (const auto& Lost : InState.LostSteaks)
        {
            if (ck::IsValid(Lost.Entity))
            { utils_entity_lifetime::Request_DestroyEntity(Lost.Entity); }
        }

        InState.Steak = FMars_Searing_SteakState();
        InState.Steak.RespawnCountdown = 0.0f;
        InState.LostSteaks.Empty();
        InState.Tally = FMars_Searing_Tally();
        InState.Heat = EMars_Searing_Heat::Cold;
        InState.Phase = EMars_Searing_Phase::NoSteak;
        InState.LastProgressStep = -1;

        auto Pan = InSearing.Get_Pan();
        Pan.Request_Reset(FMars_Request_Implement_Reset());

        ck::Trace(f"[Searing] [{InSearing.ToString()}] reset: steaks destroyed, pan reset and cold");
    }
}
