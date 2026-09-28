// Polled: CharacterMovement.IsFalling() on the context actor. Polled conditions only run on the
// machine with transition authority (owning client / listen host for its own pawn).
class UMars_SmCondition_IsFalling : UCk_SmCondition_Polled
{
    private UCharacterMovementComponent CachedMovement;

    UFUNCTION(BlueprintOverride)
    void DoEnterCondition(FCk_Handle_SmCondition InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Character = Cast<ACharacter>(ck::ToActor(ck::Ctx(InHandle)));
        if (ck::EnsureIfNot(ck::IsValid(Character), "Context actor is not an ACharacter"))
        { return; }

        CachedMovement = Character.CharacterMovement;
    }

    UFUNCTION(BlueprintOverride)
    bool DoEvaluate(FCk_Handle_SmCondition InHandle, FCk_Time InDeltaT) const
    {
        if (ck::Is_NOT_Valid(CachedMovement))
        { return false; }

        return CachedMovement.IsFalling();
    }
}

class UMars_SmCondition_IsGrounded : UMars_SmCondition_IsFalling
{
    default _NegateResult = true;
}
