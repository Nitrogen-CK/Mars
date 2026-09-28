// Applies the InputIntents move direction relative to control yaw.
class UMars_SmTask_Movement : UCk_SmTask_EntityScript
{
    default _TaskMode = ECk_SmTaskMode::Tick;

    private ACharacter CachedCharacter;
    private FCk_Handle_InputIntents CachedIntents;

    UFUNCTION(BlueprintOverride)
    void DoEnterTask(FCk_Handle_SmTask InHandle, ECk_Sm_NetContext InNetContext)
    {
        auto Player = ck::Ctx(InHandle);
        CachedCharacter = Cast<ACharacter>(ck::ToActor(Player));
        ck::EnsureIfNot(ck::IsValid(CachedCharacter), "Context actor is not an ACharacter");

        CachedIntents = Player.As_InputIntents();
    }

    UFUNCTION(BlueprintOverride)
    ECk_SmTaskResult DoTick(FCk_Handle_SmTask InHandle, FCk_Time InDeltaT, ECk_Sm_NetContext InNetContext)
    {
        if (ck::Is_NOT_Valid(CachedCharacter) || ck::Is_NOT_Valid(CachedIntents))
        { return ECk_SmTaskResult::Running; }

        const auto MoveDirection = CachedIntents.Get_MoveDirection();
        if (MoveDirection.SizeSquared() <= 0.0001)
        { return ECk_SmTaskResult::Running; }

        const auto YawRotation = FRotator(0.0, CachedCharacter.GetControlRotation().Yaw, 0.0);
        CachedCharacter.AddMovementInput(YawRotation.GetForwardVector(), float32(MoveDirection.X));
        CachedCharacter.AddMovementInput(YawRotation.GetRightVector(), float32(MoveDirection.Y));

        return ECk_SmTaskResult::Running;
    }
}
