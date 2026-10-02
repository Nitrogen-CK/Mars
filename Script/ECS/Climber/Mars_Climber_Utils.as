namespace utils_climber
{
    // Composes the climber on InHandle. A rejected spec ensures and returns an invalid handle.
    FCk_Handle_Climber Add(FCk_Handle& InHandle, FMars_Climber_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Climber] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Climber(); }

        auto Params = FMars_Fragment_Climber_Params();
        Params.ClimbSpeed = InParams.ClimbSpeed;

        InHandle.Add_Fragment(FMars_Feature_Climber());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Climber());
        return InHandle.As_Climber();
    }

    // The character the climber moves; null without one (headless tests) or when it is not an ACharacter.
    ACharacter TryGet_Character(FCk_Handle InHandle)
    {
        return Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(InHandle));
    }

    // Shared by the Climber processors only (the request drain's Dismount, the tick's top-out / bottom / lost): ends the
    // climb in InState and puts InCharacter (may be null) where InReason leaves it. The caller removes the Climbing tag and
    // broadcasts. Top: onto the platform at the ladder's top exit, walking. Bottom / Lost: walking in place. Jump: falling,
    // launched away from the plane.
    void Apply_Dismount(FMars_Fragment_Climber& InState, ACharacter InCharacter, EMars_Climber_Dismount InReason)
    {
        auto Ladder = InState.Ladder;

        InState.Ladder = FCk_Handle_Ladder();
        InState.IsClimbing = false;
        InState.PendingAxis = 0.0f;
        InState.LastDismount = InReason;

        if (ck::Is_NOT_Valid(InCharacter))
        { return; }

        auto Movement = InCharacter.CharacterMovement;

        if (InReason == EMars_Climber_Dismount::Top && ck::IsValid(Ladder))
        {
            const auto HalfHeight = InCharacter.CapsuleComponent.GetScaledCapsuleHalfHeight();
            const auto Exit = Ladder.Get_TopExitWorld().GetLocation() + FVector(0.0, 0.0, HalfHeight + 2.0);
            InCharacter.SetActorLocationAndRotation(Exit, InCharacter.GetActorRotation(), true);
            Movement.SetMovementMode(EMovementMode::MOVE_Walking);
            return;
        }

        if (InReason == EMars_Climber_Dismount::Jump)
        {
            Movement.SetMovementMode(EMovementMode::MOVE_Falling);
            const auto Away = ck::IsValid(Ladder) ? Ladder.Get_TowardPlaneWorld(EMars_Ladder_Zone::Front) * -300.0 : FVector::ZeroVector;
            InCharacter.LaunchCharacter(Away + FVector(0.0, 0.0, 250.0), true, true);
            return;
        }

        Movement.SetMovementMode(EMovementMode::MOVE_Walking);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin float32 Get_ClimbSpeed(const FCk_Handle_Climber& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Climber_Params).ClimbSpeed;
}

mixin bool Get_IsClimbing(const FCk_Handle_Climber& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Climber).IsClimbing;
}

mixin float32 Get_Alpha(const FCk_Handle_Climber& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Climber).Alpha;
}

mixin FCk_Handle_Ladder Get_Ladder(const FCk_Handle_Climber& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Climber).Ladder;
}

mixin TArray<FMars_Climber_Candidate> Get_Candidates(const FCk_Handle_Climber& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Climber).Candidates;
}

mixin EMars_Climber_Dismount Get_LastDismount(const FCk_Handle_Climber& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Climber).LastDismount;
}

mixin bool Get_HasCandidate(const FCk_Handle_Climber& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Climber).Candidates.Num() > 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_AddCandidate(FCk_Handle_Climber& Self, const FMars_Request_Climber_AddCandidate& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Climber_Requests).AddCandidateRequests.Add(InRequest);
}

mixin void Request_RemoveCandidate(FCk_Handle_Climber& Self, const FMars_Request_Climber_RemoveCandidate& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Climber_Requests).RemoveCandidateRequests.Add(InRequest);
}

mixin void Request_Mount(FCk_Handle_Climber& Self, const FMars_Request_Climber_Mount& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Climber_Requests).MountRequests.Add(InRequest);
}

mixin void Request_Climb(FCk_Handle_Climber& Self, const FMars_Request_Climber_Climb& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Climber_Requests).ClimbRequests.Add(InRequest);
}

mixin void Request_Dismount(FCk_Handle_Climber& Self, const FMars_Request_Climber_Dismount& InRequest)
{
    Self.AddOrGet_Fragment(FMars_Fragment_Climber_Requests).DismountRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnClimbingChanged(FCk_Handle_Climber& Self, FMars_Delegate_Climber_OnClimbingChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Climber_Signals);
    Fragment.OnClimbingChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnClimbingChanged(FCk_Handle_Climber& Self, FMars_Delegate_Climber_OnClimbingChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Climber_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Climber_Signals).OnClimbingChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnCandidatesChanged(FCk_Handle_Climber& Self, FMars_Delegate_Climber_OnCandidatesChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Climber_Signals);
    Fragment.OnCandidatesChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCandidatesChanged(FCk_Handle_Climber& Self, FMars_Delegate_Climber_OnCandidatesChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Climber_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Climber_Signals).OnCandidatesChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
