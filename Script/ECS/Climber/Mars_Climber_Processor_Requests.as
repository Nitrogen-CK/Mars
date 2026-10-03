// Drains RemoveCandidate, then AddCandidate, then Dismount, then Mount, then Climb (FMars_Fragment_Climber_Requests).
// Mount and Dismount are latest-wins; climb input is summed into the climb's PendingAxis for the tick, and dropped unless
// climbing. The only place a climb starts or ends: the tick asks for its dismounts here too.
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

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_Climber_Requests);

        auto CandidatesChanged = PruneDeadCandidates(InState);

        for (const auto& Request : RemoveCandidateRequests)
        { CandidatesChanged = RemoveCandidate(InState, Request) || CandidatesChanged; }

        for (const auto& Request : AddCandidateRequests)
        { CandidatesChanged = AddCandidate(InState, Request) || CandidatesChanged; }

        if (DismountRequests.Num() > 0 && InState.Climb.IsSet())
        { FinishDismount(Self, InState, DismountRequests[DismountRequests.Num() - 1].Reason); }

        if (MountRequests.Num() > 0)
        { HandleMount(Self, InState, MountRequests[MountRequests.Num() - 1]); }

        if (InState.Climb.IsSet() && ClimbRequests.Num() > 0)
        {
            auto Climb = InState.Climb.GetValue();
            for (const auto& Request : ClimbRequests)
            { Climb.PendingAxis += Request.Axis; }
            InState.Climb = Climb;
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

    private bool RemoveCandidate(FMars_Fragment_Climber& InState, const FMars_Request_Climber_RemoveCandidate& InRequest)
    {
        for (int32 Index = InState.Candidates.Num() - 1; Index >= 0; --Index)
        {
            const auto& Candidate = InState.Candidates[Index];
            if (Candidate.Ladder == InRequest.Ladder && Candidate.Zone == InRequest.Zone)
            {
                InState.Candidates.RemoveAt(Index);
                return true;
            }
        }
        return false;
    }

    // A ladder destroyed between its offer and this drain is skipped.
    private bool AddCandidate(FMars_Fragment_Climber& InState, const FMars_Request_Climber_AddCandidate& InRequest)
    {
        if (ck::Is_NOT_Valid(InRequest.Ladder))
        { return false; }

        for (const auto& Candidate : InState.Candidates)
        {
            if (Candidate.Ladder == InRequest.Ladder && Candidate.Zone == InRequest.Zone)
            { return false; }
        }

        InState.Candidates.Add(FMars_Climber_Candidate(InRequest.Ladder, InRequest.Zone));
        return true;
    }

    // Front seeds Alpha from where the character's feet are on the line (0 without a character); Top seeds 1 and arms
    // the leave-the-top guard. A ladder destroyed since the request is skipped.
    private void HandleMount(FCk_Handle_Climber& InClimber, FMars_Fragment_Climber& InState, FMars_Request_Climber_Mount InRequest)
    {
        if (InState.Climb.IsSet())
        { return; }

        auto Ladder = InRequest.Ladder;
        if (ck::Is_NOT_Valid(Ladder))
        { return; }

        auto Character = utils_climber::TryGet_Character(InClimber);

        auto Climb = FMars_Climber_Climb();
        Climb.Ladder = Ladder;
        Climb.HasLeftTop = InRequest.Zone != EMars_Ladder_Zone::Top;
        if (InRequest.Zone == EMars_Ladder_Zone::Top)
        { Climb.Alpha = 1.0f; }
        else if (ck::IsValid(Character))
        {
            const auto FeetZ = Character.GetActorLocation().Z - Character.CapsuleComponent.GetScaledCapsuleHalfHeight();
            const auto FootZ = Ladder.Get_FrameWorld().GetLocation().Z;
            Climb.Alpha = Math::Clamp(float32((FeetZ - FootZ) / Ladder.Get_Height()), 0.0f, 1.0f);
        }

        InState.Climb = Climb;

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
        { InClimber.Get_Fragment(FMars_Fragment_Climber_Signals).OnClimbingChanged.Broadcast(InClimber, EMars_Climber_ClimbState::Climbing); }
    }

    private void FinishDismount(FCk_Handle_Climber& InClimber, FMars_Fragment_Climber& InState, EMars_Climber_Dismount InReason)
    {
        const auto Ladder = InState.Climb.GetValue().Ladder;
        InState.Climb.Reset();
        InState.LastDismount = TOptional<EMars_Climber_Dismount>(InReason);
        InClimber.Request_TryRemove(FMars_Tag_Climber_Climbing);

        Apply_DismountToCharacter(utils_climber::TryGet_Character(InClimber), Ladder, InReason);

        if (InClimber.Has_Fragment(FMars_Fragment_Climber_Signals))
        { InClimber.Get_Fragment(FMars_Fragment_Climber_Signals).OnClimbingChanged.Broadcast(InClimber, EMars_Climber_ClimbState::NotClimbing); }
    }

    // Puts InCharacter (null headless) where InReason leaves it. Top: onto the platform at the ladder's top exit, walking.
    // Bottom / Lost: walking in place. Jump: falling, launched away from the plane.
    private void Apply_DismountToCharacter(ACharacter InCharacter, FCk_Handle_Ladder InLadder, EMars_Climber_Dismount InReason)
    {
        if (ck::Is_NOT_Valid(InCharacter))
        { return; }

        auto Movement = InCharacter.CharacterMovement;

        if (InReason == EMars_Climber_Dismount::Top && ck::IsValid(InLadder))
        {
            const auto HalfHeight = InCharacter.CapsuleComponent.GetScaledCapsuleHalfHeight();
            const auto Exit = InLadder.Get_TopExitWorld().GetLocation() + FVector(0.0, 0.0, HalfHeight + constants_climber::k_TopOutClearance);
            InCharacter.SetActorLocationAndRotation(Exit, InCharacter.GetActorRotation(), true);
            Movement.SetMovementMode(EMovementMode::MOVE_Walking);
            return;
        }

        if (InReason == EMars_Climber_Dismount::Jump)
        {
            Movement.SetMovementMode(EMovementMode::MOVE_Falling);
            const auto Away = ck::IsValid(InLadder)
                ? InLadder.Get_TowardPlaneWorld(EMars_Ladder_Zone::Front) * -constants_climber::k_JumpAwaySpeed
                : FVector::ZeroVector;
            // The launch replaces the velocity on both axes.
            const auto OverrideXY = true;
            const auto OverrideZ = true;
            InCharacter.LaunchCharacter(Away + FVector(0.0, 0.0, constants_climber::k_JumpUpSpeed), OverrideXY, OverrideZ);
            return;
        }

        Movement.SetMovementMode(EMovementMode::MOVE_Walking);
    }
}
