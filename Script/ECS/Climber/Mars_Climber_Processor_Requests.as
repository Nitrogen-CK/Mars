// Drains RemoveCandidate, then AddCandidate, then Dismount, then Mount, then Climb (FMars_Fragment_Climber_Requests).
// Mount and Dismount are latest-wins; climb input is summed into PendingAxis for the tick, and dropped unless climbing.
class UMars_Processor_Climber_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_Climber_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Climber);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_Climber_Requests& InRequests,
                       FMars_Fragment_Climber& InState)
    {
        auto Self = InHandle.As_Climber();

        TArray<FMars_Request_Climber_RemoveCandidate> RemoveCandidateRequests = InRequests.RemoveCandidateRequests;
        TArray<FMars_Request_Climber_AddCandidate> AddCandidateRequests = InRequests.AddCandidateRequests;
        TArray<FMars_Request_Climber_Dismount> DismountRequests = InRequests.DismountRequests;
        TArray<FMars_Request_Climber_Mount> MountRequests = InRequests.MountRequests;
        TArray<FMars_Request_Climber_Climb> ClimbRequests = InRequests.ClimbRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Climber_Requests);

        auto CandidatesChanged = PruneDeadCandidates(InState);

        for (const auto& Request : RemoveCandidateRequests)
        { CandidatesChanged = RemoveCandidate(InState, Request.Ladder, Request.Zone) || CandidatesChanged; }

        for (const auto& Request : AddCandidateRequests)
        { CandidatesChanged = AddCandidate(InState, Request.Ladder, Request.Zone) || CandidatesChanged; }

        if (DismountRequests.Num() > 0 && InState.IsClimbing)
        { FinishDismount(Self, InState, DismountRequests[DismountRequests.Num() - 1].Reason); }

        if (MountRequests.Num() > 0)
        { HandleMount(Self, InState, MountRequests[MountRequests.Num() - 1]); }

        if (InState.IsClimbing)
        {
            for (const auto& Request : ClimbRequests)
            { InState.PendingAxis += Request.Axis; }
        }

        if (CandidatesChanged && Self.Has_Fragment(FMars_Fragment_Climber_Signals))
        { Self.Get_Fragment(FMars_Fragment_Climber_Signals).OnCandidatesChanged.Broadcast(Self); }
    }

    private bool PruneDeadCandidates(FMars_Fragment_Climber& InState)
    {
        auto Changed = false;
        for (int32 Index = InState.Candidates.Num() - 1; Index >= 0; --Index)
        {
            if (ck::Is_NOT_Valid(InState.Candidates[Index].Ladder))
            {
                InState.Candidates.RemoveAt(Index);
                Changed = true;
            }
        }
        return Changed;
    }

    private bool RemoveCandidate(FMars_Fragment_Climber& InState, FCk_Handle_Ladder InLadder, EMars_Ladder_Zone InZone)
    {
        for (int32 Index = InState.Candidates.Num() - 1; Index >= 0; --Index)
        {
            const auto& Candidate = InState.Candidates[Index];
            if (Candidate.Ladder == InLadder && Candidate.Zone == InZone)
            {
                InState.Candidates.RemoveAt(Index);
                return true;
            }
        }
        return false;
    }

    private bool AddCandidate(FMars_Fragment_Climber& InState, FCk_Handle_Ladder InLadder, EMars_Ladder_Zone InZone)
    {
        if (ck::Is_NOT_Valid(InLadder))
        { return false; }

        for (const auto& Candidate : InState.Candidates)
        {
            if (Candidate.Ladder == InLadder && Candidate.Zone == InZone)
            { return false; }
        }

        InState.Candidates.Add(FMars_Climber_Candidate(InLadder, InZone));
        return true;
    }

    // Front seeds Alpha from where the character's feet are on the line (0 without a character); Top seeds 1 and arms
    // the leave-the-top guard.
    private void HandleMount(FCk_Handle_Climber& InClimber, FMars_Fragment_Climber& InState, FMars_Request_Climber_Mount InRequest)
    {
        if (InState.IsClimbing)
        { return; }

        auto Ladder = InRequest.Ladder;
        if (ck::Is_NOT_Valid(Ladder))
        { return; }

        auto Character = utils_climber::TryGet_Character(InClimber);

        auto Alpha = 0.0f;
        if (InRequest.Zone == EMars_Ladder_Zone::Top)
        { Alpha = 1.0f; }
        else if (ck::IsValid(Character))
        {
            const auto FeetZ = Character.GetActorLocation().Z - Character.CapsuleComponent.GetScaledCapsuleHalfHeight();
            const auto FootZ = Ladder.Get_FrameWorld().GetLocation().Z;
            Alpha = Math::Clamp(float32((FeetZ - FootZ) / Ladder.Get_Height()), 0.0f, 1.0f);
        }

        InState.Ladder = Ladder;
        InState.MountZone = InRequest.Zone;
        InState.Alpha = Alpha;
        InState.HasLeftTop = InRequest.Zone != EMars_Ladder_Zone::Top;
        InState.PendingAxis = 0.0f;
        InState.IsClimbing = true;

        if (InClimber.Has_Fragment(FMars_Tag_Climber_Climbing) == false)
        { InClimber.Add_Fragment(FMars_Tag_Climber_Climbing()); }

        if (ck::IsValid(Character))
        {
            Character.UnCrouch();
            auto Movement = Character.CharacterMovement;
            Movement.StopMovementImmediately();
            Movement.SetMovementMode(EMovementMode::MOVE_Flying);
        }

        if (InClimber.Has_Fragment(FMars_Fragment_Climber_Signals))
        { InClimber.Get_Fragment(FMars_Fragment_Climber_Signals).OnClimbingChanged.Broadcast(InClimber, true); }
    }

    private void FinishDismount(FCk_Handle_Climber& InClimber, FMars_Fragment_Climber& InState, EMars_Climber_Dismount InReason)
    {
        utils_climber::Apply_Dismount(InState, utils_climber::TryGet_Character(InClimber), InReason);
        InClimber.Request_TryRemove(FMars_Tag_Climber_Climbing);

        if (InClimber.Has_Fragment(FMars_Fragment_Climber_Signals))
        { InClimber.Get_Fragment(FMars_Fragment_Climber_Signals).OnClimbingChanged.Broadcast(InClimber, false); }
    }
}
