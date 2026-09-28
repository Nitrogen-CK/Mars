// ACharacter refuses to jump while crouched, and UnCrouch only lands on the next movement tick, so a
// crouched jump stands up first and jumps on the first tick it is standing.
class UMars_SmTask_Jump : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ACharacter _Character;
    private bool _HasJumped = false;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        _Character = Cast<ACharacter>(ck::ToActor(ck::Ctx(InHandle)));
        _HasJumped = false;
        if (ck::EnsureIfNot(ck::IsValid(_Character), "Context actor is not an ACharacter"))
        { return; }

        if (_Character.bIsCrouched)
        { _Character.UnCrouch(); }

        TryJump();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        TryJump();
        return ECk_SmTaskResult::Running;
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        if (ck::IsValid(_Character))
        { _Character.StopJumping(); }

        _Character = nullptr;
    }

    private void TryJump()
    {
        if (_HasJumped || ck::Is_NOT_Valid(_Character) || _Character.bIsCrouched)
        { return; }

        _Character.Jump();
        _HasJumped = true;
    }
}

class UMars_SmTask_Crouch : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::EnterExitOnly;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Character = Cast<ACharacter>(ck::ToActor(ck::Ctx(InHandle)));
        if (ck::EnsureIfNot(ck::IsValid(Character), "Context actor is not an ACharacter"))
        { return; }

        Character.Crouch();
    }

    UFUNCTION(BlueprintOverride)
    void DoExitTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Character = Cast<ACharacter>(ck::ToActor(ck::Ctx(InHandle), ECk_SanityCheck::UnChecked));
        if (ck::IsValid(Character))
        { Character.UnCrouch(); }
    }
}
