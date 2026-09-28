// Transitions are evaluated in declaration order:
//   Idle     ->Airborne[IsFalling] ->Jump[JumpPressed] ->Crouch[CrouchPressed] ->Walk[HasMoveIntent]
//   Walk     ->Airborne ->Jump ->Crouch ->Idle[NoMoveIntent] ->Sprint[SprintHeld]
//   Sprint   ->Airborne ->Jump ->Crouch ->Idle[NoMoveIntent] ->Walk[SprintReleased]
//   Crouch   ->Airborne ->Jump[JumpPressed] ->Idle[CrouchPressed]   (toggle: a fresh press stands up)
//   Jump     ->Airborne[IsFalling] ->Idle[JumpReleased + IsGrounded]   (jump refused)
//   Airborne ->Sprint[IsGrounded + HasMoveIntent + SprintHeld] ->Walk[IsGrounded + HasMoveIntent] ->Idle[IsGrounded]
//            (landing goes straight to the moving state: a frame in Idle drops MaxWalkSpeed and input, braking the run)

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

class UMars_SmCondition_CrouchPressed : UMars_SmCondition_IntentPressed
{
    default IntentTag = GameplayTags::Mars_Intent_Crouch;
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

        Player.CharacterMovement.MaxWalkSpeed = Speed == EMars_LocomotionSpeed::Sprint
            ? Player.Config.SprintSpeed
            : Player.Config.WalkSpeed;
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
        auto ToAirborne = AddTransition(InHandle, UMars_SmState_Loco_Airborne);
        AddCondition(ToAirborne, UMars_SmCondition_IsFalling);

        auto ToJump = AddTransition(InHandle, UMars_SmState_Loco_Jump);
        AddCondition(ToJump, UMars_SmCondition_JumpPressed);

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
