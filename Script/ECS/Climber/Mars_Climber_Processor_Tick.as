// While climbing: moves Alpha along the ladder by this frame's climb input at the climber's ClimbSpeed, asks the request
// drain to end the climb at the top (only once the climber has left the top since a Top mount), at the bottom, or when the
// ladder dies, and otherwise holds the character on the climb line with no velocity.
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

        // The tag is removed with the climb; a frame between the two still finds the tag.
        if (InState.Climb.IsSet() == false)
        { return; }

        auto Climb = InState.Climb.GetValue();
        auto Ladder = Climb.Ladder;
        if (ck::Is_NOT_Valid(Ladder))
        {
            Self.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Lost));
            return;
        }

        const auto Axis = Math::Clamp(Climb.PendingAxis, -1.0f, 1.0f);
        Climb.PendingAxis = 0.0f;

        const auto DeltaSeconds = float32(InDeltaT.Get_Seconds());
        const auto AlphaPerSecond = Self.Get_ClimbSpeed() / Ladder.Get_Height();
        Climb.Alpha = Math::Clamp(Climb.Alpha + Axis * AlphaPerSecond * DeltaSeconds, 0.0f, 1.0f);

        if (Climb.Alpha < constants_climber::k_LeftTopAlpha)
        { Climb.HasLeftTop = true; }

        InState.Climb = Climb;

        if (Climb.Alpha >= 1.0f && Axis > 0.0f && Climb.HasLeftTop)
        {
            Self.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Top));
            return;
        }

        if (Climb.Alpha <= 0.0f && Axis < 0.0f)
        {
            Self.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Bottom));
            return;
        }

        auto Character = utils_climber::TryGet_Character(InHandle);
        if (ck::Is_NOT_Valid(Character))
        { return; }

        // Teleport onto the line (no sweep: the rails would stop a sweep), facing wherever the controller looks.
        const auto HalfHeight = Character.CapsuleComponent.GetScaledCapsuleHalfHeight();
        const auto OnLine = Ladder.Get_LineWorldLocation(Climb.Alpha) + FVector(0.0, 0.0, HalfHeight);
        Character.SetActorLocationAndRotation(OnLine, Character.GetActorRotation(), true);
        Character.CharacterMovement.StopMovementImmediately();
    }
}
