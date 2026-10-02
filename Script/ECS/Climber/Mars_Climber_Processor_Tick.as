// While climbing: moves Alpha along the ladder by this frame's climb input at the climber's ClimbSpeed, ends the climb at
// the top (only once the climber has left the top since a Top mount), at the bottom, or when the ladder dies, and
// otherwise holds the character on the climb line with no velocity. Runs only while FMars_Tag_Climber_Climbing is present.
class UMars_Processor_Climber_Tick : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_Climber);
        Query.Require(FMars_Tag_Climber_Climbing);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_Climber& InState)
    {
        auto Self = InHandle.As_Climber();

        auto Ladder = InState.Ladder;
        if (ck::Is_NOT_Valid(Ladder))
        {
            FinishDismount(Self, InState, EMars_Climber_Dismount::Lost);
            return;
        }

        const auto Axis = Math::Clamp(InState.PendingAxis, -1.0f, 1.0f);
        InState.PendingAxis = 0.0f;

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        const auto AlphaPerSecond = Self.Get_ClimbSpeed() / Ladder.Get_Height();
        InState.Alpha = Math::Clamp(InState.Alpha + Axis * AlphaPerSecond * DeltaSeconds, 0.0f, 1.0f);

        if (InState.Alpha < 0.95f)
        { InState.HasLeftTop = true; }

        if (InState.Alpha >= 1.0f && Axis > 0.0f && InState.HasLeftTop)
        {
            FinishDismount(Self, InState, EMars_Climber_Dismount::Top);
            return;
        }

        if (InState.Alpha <= 0.0f && Axis < 0.0f)
        {
            FinishDismount(Self, InState, EMars_Climber_Dismount::Bottom);
            return;
        }

        auto Character = utils_climber::TryGet_Character(InHandle);
        if (ck::Is_NOT_Valid(Character))
        { return; }

        // Teleport onto the line (no sweep: the rails would stop a sweep), facing wherever the controller looks.
        const auto HalfHeight = Character.CapsuleComponent.GetScaledCapsuleHalfHeight();
        const auto OnLine = Ladder.Get_LineWorldLocation(InState.Alpha) + FVector(0.0, 0.0, HalfHeight);
        Character.SetActorLocationAndRotation(OnLine, Character.GetActorRotation(), true);
        Character.CharacterMovement.StopMovementImmediately();
    }

    private void FinishDismount(FCk_Handle_Climber& InClimber, FMars_Fragment_Climber& InState, EMars_Climber_Dismount InReason)
    {
        utils_climber::Apply_Dismount(InState, utils_climber::TryGet_Character(InClimber), InReason);
        InClimber.Request_TryRemove(FMars_Tag_Climber_Climbing);

        if (InClimber.Has_Fragment(FMars_Fragment_Climber_Signals))
        { InClimber.Get_Fragment(FMars_Fragment_Climber_Signals).OnClimbingChanged.Broadcast(InClimber, false); }
    }
}
