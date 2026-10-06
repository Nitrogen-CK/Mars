// Drains Reset -> SetDrive -> Look. Reset levels the implement, zeroes the lift and idles it; SetDrive is last-wins; looks
// only collect into the pending look while Driven. The drain collects and the Tick measures: a dirty-marked processor is
// also pumped with a zero DeltaT, so nothing here integrates over time.
class UMars_Processor_Implement_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Implement_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Implement);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Implement_Requests& InRequests,
                       FMars_Fragment_Implement& InState)
    {
        auto Self = InHandle.As_Implement();

        const auto HasReset = InRequests.ResetRequests.Num() > 0;
        TArray<FMars_Request_Implement_SetDrive> SetDriveRequests = InRequests.SetDriveRequests;
        TArray<FMars_Request_Implement_Look> LookRequests = InRequests.LookRequests;

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Implement_Requests);

        const auto StartDrive = InState.Drive;

        if (HasReset)
        { Apply_Reset(Self, InState); }

        if (SetDriveRequests.Num() > 0)
        { InState.Drive = SetDriveRequests.Last().Drive; }

        if (InState.Drive == EMars_Implement_Drive::Driven)
        {
            for (const auto& Request : LookRequests)
            { InState.PendingLook += FVector(Request.LookDelta.X, Request.LookDelta.Y, 0.0); }
        }

        const auto NewDrive = InState.Drive;
        if (NewDrive == StartDrive || Self.Has_Fragment(FMars_Fragment_Implement_Signals) == false)
        { return; }

        Self.Get_Fragment(FMars_Fragment_Implement_Signals).OnDriveChanged.Broadcast(Self, NewDrive);
    }

    private void Apply_Reset(FCk_Handle_Implement& InImplement, FMars_Fragment_Implement& InState)
    {
        InState.Drive = EMars_Implement_Drive::Idle;
        InState.Pitch = 0.0f;
        InState.Roll = 0.0f;
        InState.TargetPitch = 0.0f;
        InState.TargetRoll = 0.0f;
        InState.Lift = 0.0f;
        InState.LiftVelocity = 0.0f;
        InState.PendingLook = FVector::ZeroVector;

        utils_implement::Apply_Pose(InImplement.Get_Node(), InState);
        InState.WrittenPitch = 0.0f;
        InState.WrittenRoll = 0.0f;
        InState.WrittenLift = 0.0f;

        ck::Trace(f"[Implement] [{InImplement.ToString()}] reset: level, no lift, idle");
    }
}
