// Downed, as the player's root state reads it (Mars_PlayerCharacter_Hfsm.as): entered while the debug Downed byte is set
// OR the composed local Health is depleted, left only once the byte is clear AND that Health is absent or not depleted -
// so clearing the byte on a player at zero Health does not revive them; healing does, together with the clear byte.
// While Downed, UMars_SmTask_Downed_Lockdown holds the character's movement.

namespace utils_player_sm
{
    // The debug Downed byte (ByteAttribute.Mars.Player.Downed) is set; false on an entity without it.
    bool Get_IsDownedFlagSet(FCk_Handle InPlayer)
    {
        auto Attribute = utils_byte_attribute::TryGet(InPlayer, GameplayTags::ByteAttribute_Mars_Player_Downed);
        return ck::IsValid(Attribute) && Attribute.Get_FinalValue(ECk_MinMaxCurrent::Current) > 0;
    }

    // The player's local Health is depleted; false without one (composed only on a locally controlled pawn in a local
    // combat world).
    bool Get_IsHealthDepleted(FCk_Handle InPlayer)
    {
        auto Health = InPlayer.As_Health(ECk_SanityCheck::UnChecked);
        return ck::IsValid(Health) && Health.Get_IsDepleted();
    }
}

// Polled: Health has no change signal of its own the condition could wait on, and the byte is read alongside it.
class UMars_SmCondition_IsDownedOrDepleted : UCk_SmCondition_Polled
{
    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        auto Player = ck::Ctx(InHandle);
        return utils_player_sm::Get_IsDownedFlagSet(Player) || utils_player_sm::Get_IsHealthDepleted(Player);
    }
}

// Byte clear AND Health absent or not depleted.
class UMars_SmCondition_IsAliveAndNotDepleted : UMars_SmCondition_IsDownedOrDepleted
{
    default _NegateResult = true;
}

//--------------------------------------------------------------------------------------------------------------------------
// Lockdown
//--------------------------------------------------------------------------------------------------------------------------

// Takes the character's movement for as long as Downed lasts, on the owning copy: move input ignored and velocity stopped
// on enter, then, once no climb remains, movement disabled (mode None) exactly once. A climb ends through the Climber's
// own request drain, which restores Walking, and the drain handles Dismount before Mount - so a Mount already queued
// when Downed began can leave the player climbing after the first Dismount. The task therefore only ever reads the
// Climber, from its own ticks (never from a Climber signal, which fires inside the drain): while requests are pending it
// waits; if a climb is active once they have drained it asks for another Dismount; only with neither does it disable
// movement. Exit gives back only what it took: its own move-input ignore, and Walking if it disabled movement. No actor
// (headless) = nothing to hold.
class UMars_SmTask_Downed_Lockdown : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ACharacter _Character;
    private AController _Controller;
    private FCk_Handle_Climber _Climber;
    private bool _IgnoreAcquired = false;
    private bool _Locked = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _IgnoreAcquired = false;
        _Locked = false;
        if (utils_player_sm::Get_IsOwningCopy(InHandle, InNetContext) == false)
        { return; }

        auto Player = ck::Ctx(InHandle);
        _Character = Cast<ACharacter>(utils_owning_actor::TryGet_EntityOwningActor_Recursive(Player));
        if (ck::Is_NOT_Valid(_Character))
        { return; }

        _Climber = Player.As_Climber(ECk_SanityCheck::UnChecked);
        _Controller = _Character.GetController();
        if (ck::IsValid(_Controller))
        {
            _Controller.SetIgnoreMoveInput(true);
            _IgnoreAcquired = true;
        }

        _Character.CharacterMovement.StopMovementImmediately();

        if (ck::IsValid(_Climber) && _Climber.Get_IsClimbing())
        { _Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Lost)); }
    }

    // Must return Running every frame: a Succeeded/Failed result would end the task while Downed is still active.
    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (_Locked || ck::Is_NOT_Valid(_Character))
        { return ECk_SmTaskResult::Running; }

        auto Movement = _Character.CharacterMovement;
        Movement.StopMovementImmediately();

        if (ck::IsValid(_Climber))
        {
            if (_Climber.Get_HasPendingRequests())
            { return ECk_SmTaskResult::Running; }

            if (_Climber.Get_IsClimbing())
            {
                _Climber.Request_Dismount(FMars_Request_Climber_Dismount(EMars_Climber_Dismount::Lost));
                return ECk_SmTaskResult::Running;
            }
        }

        Movement.DisableMovement();
        _Locked = true;
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (_IgnoreAcquired && ck::IsValid(_Controller))
        { _Controller.SetIgnoreMoveInput(false); }

        if (_Locked && ck::IsValid(_Character))
        { _Character.CharacterMovement.SetMovementMode(EMovementMode::MOVE_Walking); }

        _IgnoreAcquired = false;
        _Locked = false;
        _Character = nullptr;
        _Controller = nullptr;
        _Climber = FCk_Handle_Climber();
    }
}
