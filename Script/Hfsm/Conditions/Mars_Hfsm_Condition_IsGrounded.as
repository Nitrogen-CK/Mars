enum EMars_Hfsm_GroundState
{
    Falling,
    Grounded
}

// Polled: CharacterMovement.IsFalling() on the context actor. Polled conditions only run on the
// machine with transition authority (owning client / listen host for its own pawn). IsGrounded is its own answer
// rather than a negated IsFalling, so a missing movement component fails both instead of passing IsGrounded.
class UMars_SmCondition_IsFalling : UCk_SmCondition_Polled
{
    protected EMars_Hfsm_GroundState PassesWhen = EMars_Hfsm_GroundState::Falling;

    private UCharacterMovementComponent CachedMovement;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Character = Cast<ACharacter>(ck::ToActor(ck::Ctx(InHandle)));
        if (ck::EnsureIfNot(ck::IsValid(Character), "Context actor is not an ACharacter"))
        { return; }

        CachedMovement = Character.CharacterMovement;
        ck::EnsureIfNot(ck::IsValid(CachedMovement), f"[{Character.GetName()}] has no CharacterMovement");
    }

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        if (ck::Is_NOT_Valid(CachedMovement))
        { return false; }

        const auto IsFalling = CachedMovement.IsFalling();
        return PassesWhen == EMars_Hfsm_GroundState::Falling ? IsFalling : IsFalling == false;
    }
}

class UMars_SmCondition_IsGrounded : UMars_SmCondition_IsFalling
{
    default PassesWhen = EMars_Hfsm_GroundState::Grounded;
}
