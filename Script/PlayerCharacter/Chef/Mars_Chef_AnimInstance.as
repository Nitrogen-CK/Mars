// Parent class of ABP_Chef, the third-person chef body other players see. Reads the owning character's movement
// (velocity and falling state replicate, so this is valid on simulated proxies) and exposes what the anim graph
// needs: ground speed and travel direction for the locomotion blend space, and whether the character is airborne for
// the jump states. Emotes and the strike play as montages on the ABP's DefaultSlot (see AMars_PlayerCharacter).
class UMars_Chef_AnimInstance : UAnimInstance
{
    // Horizontal speed, uu/s (blend space Y).
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef")
    float32 Speed = 0.0f;

    // Travel direction relative to the actor's facing, degrees in [-180, 180] (blend space X). 0 = forward,
    // +90 = right, -90 = left, +-180 = backward. Holds its last value while stationary so the blend does not snap.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef")
    float32 Direction = 0.0f;

    // Character movement reports falling (jump or drop).
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef")
    bool IsInAir = false;

    // Speed above this counts as moving (hysteresis-free; the blend space handles the idle blend).
    UPROPERTY(EditDefaultsOnly, Category = "Chef")
    float32 MovingSpeedThreshold = 10.0f;

    UFUNCTION(BlueprintOverride)
    void BlueprintUpdateAnimation(float DeltaTimeX)
    {
        auto Character = Cast<ACharacter>(TryGetPawnOwner());
        if (ck::Is_NOT_Valid(Character))
        {
            Speed = 0.0f;
            IsInAir = false;
            return;
        }

        const auto Velocity = Character.GetVelocity();
        const auto Planar = FVector(Velocity.X, Velocity.Y, 0.0);
        Speed = float32(Planar.Size());
        IsInAir = Character.CharacterMovement.IsFalling();

        if (Speed > MovingSpeedThreshold)
        {
            const auto Local = Character.GetActorRotation().UnrotateVector(Planar);
            Direction = float32(Math::RadiansToDegrees(Math::Atan2(Local.Y, Local.X)));
        }
    }
}
