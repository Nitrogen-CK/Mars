// Transitions are evaluated in declaration order. Every state but Climb checks ->Climb first (Airborne included:
// catching a ladder mid-fall is allowed); the mount itself is UMars_SmTask_ClimberMountIntent on Locomotion.
// Crouch is a toggle on fresh presses, not holds, so crouching mid-sprint with sprint still held does not bounce
// straight back to Sprint. Landing goes straight to the moving state: a frame in Idle drops MaxWalkSpeed and input,
// braking the run.

class UMars_SmCondition_JumpPressed : UMars_SmCondition_IntentPressed
{
    default IntentTag = GameplayTags::Mars_Intent_Jump;
}

class UMars_SmCondition_JumpHeld : UMars_SmCondition_IntentActive
{
    default IntentTag = GameplayTags::Mars_Intent_Jump;
}

class UMars_SmCondition_JumpReleased : UMars_SmCondition_JumpHeld
{
    default _NegateResult = true;
}

class UMars_SmCondition_SprintHeld : UMars_SmCondition_IntentActive
{
    default IntentTag = GameplayTags::Mars_Intent_Sprint;
}

class UMars_SmCondition_SprintReleased : UMars_SmCondition_SprintHeld
{
    default _NegateResult = true;
}

class UMars_SmCondition_SprintPressed : UMars_SmCondition_IntentPressed
{
    default IntentTag = GameplayTags::Mars_Intent_Sprint;
}

class UMars_SmCondition_CrouchPressed : UMars_SmCondition_IntentPressed
{
    default IntentTag = GameplayTags::Mars_Intent_Crouch;
}

// Polled on the context entity's Climber; false without one.
class UMars_SmCondition_IsClimbing : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Climber = ck::Ctx(InHandle).As_Climber(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Climber))
        { return false; }

        return Climber.Get_IsClimbing();
    }
}

class UMars_SmCondition_IsNotClimbing : UMars_SmCondition_IsClimbing
{
    default _NegateResult = true;
}

enum EMars_LocomotionSpeed
{
    Walk,
    Sprint
}

class UMars_SmTask_LocomotionSpeed : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    protected EMars_LocomotionSpeed Speed = EMars_LocomotionSpeed::Walk;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = Cast<AMars_PlayerCharacter>(ck::ToActor(ck::Ctx(InHandle)));
        if (ck::EnsureIfNot(ck::IsValid(Player), "Context actor is not an AMars_PlayerCharacter"))
        { return; }

        const auto& Speeds = Player.Config.Movement.Speeds;
        Player.CharacterMovement.MaxWalkSpeed = Speed == EMars_LocomotionSpeed::Sprint ? Speeds.Sprint : Speeds.Walk;
    }
}

class UMars_SmTask_LocomotionSpeed_Walk : UMars_SmTask_LocomotionSpeed
{
    default Speed = EMars_LocomotionSpeed::Walk;
}

class UMars_SmTask_LocomotionSpeed_Sprint : UMars_SmTask_LocomotionSpeed
{
    default Speed = EMars_LocomotionSpeed::Sprint;
}

class UMars_SmState_Loco_Idle : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToClimb = AddTransition(InHandle, UMars_SmState_Loco_Climb);
        AddCondition(ToClimb, UMars_SmCondition_IsClimbing);

        auto ToAirborne = AddTransition(InHandle, UMars_SmState_Loco_Airborne);
        AddCondition(ToAirborne, UMars_SmCondition_IsFalling);

        auto ToJump = AddTransition(InHandle, UMars_SmState_Loco_Jump);
        AddCondition(ToJump, UMars_SmCondition_JumpPressed);

        auto ToCrouch = AddTransition(InHandle, UMars_SmState_Loco_Crouch);
        AddCondition(ToCrouch, UMars_SmCondition_CrouchPressed);

        auto ToWalk = AddTransition(InHandle, UMars_SmState_Loco_Walk);
        AddCondition(ToWalk, UMars_SmCondition_HasMoveIntent);

        AddTask(InHandle, UMars_SmTask_LocomotionSpeed_Walk);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Locomotion > Idle", n"PlayerSM", 2.0f, FLinearColor(0.3f, 0.6f, 1.0f, 1.0f));
    }
}

class UMars_SmState_Loco_Walk : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToClimb = AddTransition(InHandle, UMars_SmState_Loco_Climb);
        AddCondition(ToClimb, UMars_SmCondition_IsClimbing);

        auto ToAirborne = AddTransition(InHandle, UMars_SmState_Loco_Airborne);
        AddCondition(ToAirborne, UMars_SmCondition_IsFalling);

        auto ToJump = AddTransition(InHandle, UMars_SmState_Loco_Jump);
        AddCondition(ToJump, UMars_SmCondition_JumpPressed);

        auto ToCrouch = AddTransition(InHandle, UMars_SmState_Loco_Crouch);
        AddCondition(ToCrouch, UMars_SmCondition_CrouchPressed);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Loco_Idle);
        AddCondition(ToIdle, UMars_SmCondition_NoMoveIntent);

        auto ToSprint = AddTransition(InHandle, UMars_SmState_Loco_Sprint);
        AddCondition(ToSprint, UMars_SmCondition_SprintHeld);

        AddTask(InHandle, UMars_SmTask_LocomotionSpeed_Walk);
        AddTask(InHandle, UMars_SmTask_Movement);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Locomotion > Walk", n"PlayerSM", 2.0f, FLinearColor(0.2f, 1.0f, 0.2f, 1.0f));
    }
}

class UMars_SmState_Loco_Sprint : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToClimb = AddTransition(InHandle, UMars_SmState_Loco_Climb);
        AddCondition(ToClimb, UMars_SmCondition_IsClimbing);

        auto ToAirborne = AddTransition(InHandle, UMars_SmState_Loco_Airborne);
        AddCondition(ToAirborne, UMars_SmCondition_IsFalling);

        auto ToJump = AddTransition(InHandle, UMars_SmState_Loco_Jump);
        AddCondition(ToJump, UMars_SmCondition_JumpPressed);

        auto ToCrouch = AddTransition(InHandle, UMars_SmState_Loco_Crouch);
        AddCondition(ToCrouch, UMars_SmCondition_CrouchPressed);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Loco_Idle);
        AddCondition(ToIdle, UMars_SmCondition_NoMoveIntent);

        auto ToWalk = AddTransition(InHandle, UMars_SmState_Loco_Walk);
        AddCondition(ToWalk, UMars_SmCondition_SprintReleased);

        AddTask(InHandle, UMars_SmTask_LocomotionSpeed_Sprint);
        AddTask(InHandle, UMars_SmTask_Movement);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Locomotion > Sprint", n"PlayerSM", 2.0f, FLinearColor(1.0f, 0.5f, 0.0f, 1.0f));
    }
}

// Crouched speed is MaxWalkSpeedCrouched, which CharacterMovement applies itself.
class UMars_SmState_Loco_Crouch : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToClimb = AddTransition(InHandle, UMars_SmState_Loco_Climb);
        AddCondition(ToClimb, UMars_SmCondition_IsClimbing);

        auto ToAirborne = AddTransition(InHandle, UMars_SmState_Loco_Airborne);
        AddCondition(ToAirborne, UMars_SmCondition_IsFalling);

        auto ToJump = AddTransition(InHandle, UMars_SmState_Loco_Jump);
        AddCondition(ToJump, UMars_SmCondition_JumpPressed);

        auto ToSprint = AddTransition(InHandle, UMars_SmState_Loco_Sprint);
        AddCondition(ToSprint, UMars_SmCondition_SprintPressed);
        AddCondition(ToSprint, UMars_SmCondition_HasMoveIntent);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Loco_Idle);
        AddCondition(ToIdle, UMars_SmCondition_CrouchPressed);

        AddTask(InHandle, UMars_SmTask_Crouch);
        AddTask(InHandle, UMars_SmTask_Movement);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Locomotion > Crouch", n"PlayerSM", 2.0f, FLinearColor(0.7f, 0.4f, 1.0f, 1.0f));
    }
}

// Left for Airborne the frame CharacterMovement starts falling (the frame after Jump()).
class UMars_SmState_Loco_Jump : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToClimb = AddTransition(InHandle, UMars_SmState_Loco_Climb);
        AddCondition(ToClimb, UMars_SmCondition_IsClimbing);

        auto ToAirborne = AddTransition(InHandle, UMars_SmState_Loco_Airborne);
        AddCondition(ToAirborne, UMars_SmCondition_IsFalling);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Loco_Idle);
        AddCondition(ToIdle, UMars_SmCondition_JumpReleased);
        AddCondition(ToIdle, UMars_SmCondition_IsGrounded);

        AddTask(InHandle, UMars_SmTask_Jump);
        AddTask(InHandle, UMars_SmTask_Movement);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Locomotion > Jump", n"PlayerSM", 2.0f, FLinearColor(1.0f, 0.8f, 0.0f, 1.0f));
    }
}

// Keeps the MaxWalkSpeed it arrived with, so a sprint-jump carries sprint air speed.
class UMars_SmState_Loco_Airborne : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToClimb = AddTransition(InHandle, UMars_SmState_Loco_Climb);
        AddCondition(ToClimb, UMars_SmCondition_IsClimbing);

        auto ToSprint = AddTransition(InHandle, UMars_SmState_Loco_Sprint);
        AddCondition(ToSprint, UMars_SmCondition_IsGrounded);
        AddCondition(ToSprint, UMars_SmCondition_HasMoveIntent);
        AddCondition(ToSprint, UMars_SmCondition_SprintHeld);

        auto ToWalk = AddTransition(InHandle, UMars_SmState_Loco_Walk);
        AddCondition(ToWalk, UMars_SmCondition_IsGrounded);
        AddCondition(ToWalk, UMars_SmCondition_HasMoveIntent);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Loco_Idle);
        AddCondition(ToIdle, UMars_SmCondition_IsGrounded);

        AddTask(InHandle, UMars_SmTask_Movement);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Locomotion > Airborne", n"PlayerSM", 2.0f, FLinearColor(0.9f, 0.9f, 0.9f, 1.0f));
    }
}

// On a ladder: the Climber holds the character on the climb line in MOVE_Flying, so no movement or speed task runs here.
// Topping out or stepping off at the bottom ends the climb (->Idle); jumping off makes the character fall (->Airborne).
class UMars_SmState_Loco_Climb : UCk_SmState_EntityScript
{
    UFUNCTION(BlueprintOverride)
    void DoDefineState(FCk_Handle_SmState_UnderConstruction& InHandle)
    {
        auto ToAirborne = AddTransition(InHandle, UMars_SmState_Loco_Airborne);
        AddCondition(ToAirborne, UMars_SmCondition_IsFalling);

        auto ToIdle = AddTransition(InHandle, UMars_SmState_Loco_Idle);
        AddCondition(ToIdle, UMars_SmCondition_IsNotClimbing);

        AddTask(InHandle, UMars_SmTask_ClimbInput);
    }

    UFUNCTION(BlueprintOverride)
    void DoEnterState(FCk_Handle_SmState InHandle, ECk_Sm_NetContext InNetContext)
    {
        ck::Trace("Player SM: Locomotion > Climb", n"PlayerSM", 2.0f, FLinearColor(0.4f, 0.9f, 0.9f, 1.0f));
    }
}

// The Climb state's input: every tick the move intent is non-zero, its forward axis (W/S) climbs the ladder; a fresh Jump
// press jumps off. Ticks, unlike its EnterExitOnly base, whose enter/exit still run through Super; handles are cached
// BEFORE Super::DoEnterTask (the base's first OnMatcherRebound runs inside it).
class UMars_SmTask_ClimbInput : UMars_SmTask_IntentEdges
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private FCk_Handle_Climber _Climber;
    private FCk_Handle_InputIntents _MoveIntents;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Climber = Player.As_Climber(ECk_SanityCheck::UnChecked);
        _MoveIntents = Player.As_InputIntents(ECk_SanityCheck::UnChecked);

        auto Character = Cast<ACharacter>(ck::ToActor(Player, ECk_SanityCheck::UnChecked));
        if (ck::IsValid(Character) && Character.bIsCrouched)
        { Character.UnCrouch(); }

        Super::DoEnterTask(InHandle, InNetContext);
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        Super::DoExitTask(InHandle, InNetContext);

        _Climber = FCk_Handle_Climber();
        _MoveIntents = FCk_Handle_InputIntents();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Climber) || ck::Is_NOT_Valid(_MoveIntents))
        { return ECk_SmTaskResult::Running; }

        const auto MoveDirection = _MoveIntents.Get_MoveDirection();
        if (MoveDirection.SizeSquared() <= 0.0001)
        { return ECk_SmTaskResult::Running; }

        _Climber.Request_Climb(FMars_Request_Climber_Climb(float32(MoveDirection.X)));
        return ECk_SmTaskResult::Running;
    }

    protected void OnIntentPressed(FGameplayTag InIntent) override
    {
        if (InIntent != GameplayTags::Mars_Intent_Jump || ck::Is_NOT_Valid(_Climber))
        { return; }

        _Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Jump));
    }
}

// On Locomotion: steps the player onto a ladder whose zone they stand in when they walk toward it - the move direction
// rotated by control yaw (as UMars_SmTask_Movement applies it) points at the ladder (dot > 0.5 with the zone's toward-plane
// direction). A Top candidate also needs the feet on the platform (above Height - 20 over the ladder's foot), so reaching
// the top zone from the front does not mount at the top. Without a character the yaw is 0 and the feet check is skipped.
// After any dismount it waits RemountCooldownSeconds before mounting again: a top-out leaves the player in the TopZone and
// a jump-off leaves them in the FrontZone, often still holding a direction that points at the ladder, and the next tick
// would otherwise put them straight back on it.
class UMars_SmTask_ClimberMountIntent : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    protected float32 RemountCooldownSeconds = 0.4f;

    private ACharacter _Character;
    private FCk_Handle_Climber _Climber;
    private FCk_Handle_InputIntents _Intents;
    // Seconds since the last dismount; unset while no remount cooldown runs.
    private TOptional<float32> _SinceDismount;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        _Character = Cast<ACharacter>(ck::ToActor(Player, ECk_SanityCheck::UnChecked));
        _Climber = Player.As_Climber(ECk_SanityCheck::UnChecked);
        _Intents = Player.As_InputIntents(ECk_SanityCheck::UnChecked);
        _SinceDismount.Reset();

        if (ck::IsValid(_Climber))
        { _Climber.BindTo_OnClimbingChanged(FMars_Delegate_Climber_OnClimbingChanged(this, n"OnClimbingChanged")); }
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Climber))
        { _Climber.UnbindFrom_OnClimbingChanged(FMars_Delegate_Climber_OnClimbingChanged(this, n"OnClimbingChanged")); }

        _Character = nullptr;
        _Climber = FCk_Handle_Climber();
        _Intents = FCk_Handle_InputIntents();
    }

    UFUNCTION()
    private void OnClimbingChanged(FCk_Handle_Climber InClimber, EMars_Climber_ClimbState InClimbState)
    {
        if (InClimbState == EMars_Climber_ClimbState::NotClimbing)
        { _SinceDismount = TOptional<float32>(0.0f); }
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(_Climber) || ck::Is_NOT_Valid(_Intents))
        { return ECk_SmTaskResult::Running; }

        if (_SinceDismount.IsSet())
        {
            const auto SinceDismount = _SinceDismount.GetValue() + float32(InDeltaT.Get_Seconds());
            if (SinceDismount < RemountCooldownSeconds)
            {
                _SinceDismount = TOptional<float32>(SinceDismount);
                return ECk_SmTaskResult::Running;
            }

            _SinceDismount.Reset();
        }

        if (_Climber.Get_IsClimbing() || _Climber.Get_HasCandidate() == false)
        { return ECk_SmTaskResult::Running; }

        const auto Move = _Intents.Get_MoveDirection();
        if (Move.SizeSquared() <= 0.0001)
        { return ECk_SmTaskResult::Running; }

        const auto Yaw = ck::IsValid(_Character) ? _Character.GetControlRotation().Yaw : 0.0;
        const auto YawRotation = FRotator(0.0, Yaw, 0.0);
        const auto MoveWorld = (YawRotation.GetForwardVector() * Move.X + YawRotation.GetRightVector() * Move.Y).GetSafeNormal();

        for (auto Candidate : _Climber.Get_Candidates())
        {
            auto Ladder = Candidate.Ladder;
            if (ck::Is_NOT_Valid(Ladder))
            { continue; }

            if (MoveWorld.DotProduct(Ladder.Get_TowardPlaneWorld(Candidate.Zone)) <= 0.5)
            { continue; }

            if (Candidate.Zone == EMars_Ladder_Zone::Top && Get_IsOnPlatform(Ladder) == false)
            { continue; }

            _Climber.Request_Mount(FMars_Request_Climber_Mount(Ladder, Candidate.Zone));
            return ECk_SmTaskResult::Running;
        }

        return ECk_SmTaskResult::Running;
    }

    private bool Get_IsOnPlatform(const FCk_Handle_Ladder& InLadder)
    {
        if (ck::Is_NOT_Valid(_Character))
        { return true; }

        const auto FeetZ = _Character.GetActorLocation().Z - _Character.CapsuleComponent.GetScaledCapsuleHalfHeight();
        return FeetZ - InLadder.Get_FrameWorld().GetLocation().Z > float64(InLadder.Get_Height()) - 20.0;
    }
}
