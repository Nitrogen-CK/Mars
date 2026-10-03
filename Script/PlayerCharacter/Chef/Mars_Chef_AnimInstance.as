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

    // Held-item arm pose (component space), read by ABP_Chef's TwoBoneIK + Transform (Modify) Bone chain after the
    // DefaultSlot. Pulled each update from AMars_PlayerCharacter::Get_BodyHoldFrame (see Mars_HeldView.as). Locations
    // and rotations are the hand_l / hand_r bones' (already converted from the grip targets); the elbow targets are the
    // IK joint targets. Alpha 0 = the arm keeps the locomotion/montage pose; one-handed items only raise the right alpha.
    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    float32 HoldAlpha_L = 0.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    float32 HoldAlpha_R = 0.0f;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    FVector HandLocation_L = FVector::ZeroVector;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    FVector HandLocation_R = FVector::ZeroVector;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    FRotator HandRotation_L = FRotator::ZeroRotator;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    FRotator HandRotation_R = FRotator::ZeroRotator;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    FVector ElbowTarget_L = FVector::ZeroVector;

    UPROPERTY(BlueprintReadOnly, NotEditable, Category = "Chef|Hold")
    FVector ElbowTarget_R = FVector::ZeroVector;

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
            HoldAlpha_L = 0.0f;
            HoldAlpha_R = 0.0f;
            return;
        }

        UpdateHold(Cast<AMars_PlayerCharacter>(Character), float32(DeltaTimeX));

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

    // The character eases its arm targets here (AMars_PlayerCharacter::Update_BodyHold), once per pose update.
    private void UpdateHold(AMars_PlayerCharacter InCharacter, float32 InDeltaSeconds)
    {
        if (ck::Is_NOT_Valid(InCharacter))
        {
            HoldAlpha_L = 0.0f;
            HoldAlpha_R = 0.0f;
            return;
        }

        InCharacter.Update_BodyHold(InDeltaSeconds);
        const auto Frame = InCharacter.Get_BodyHoldFrame();
        HoldAlpha_L = Frame.Left.Alpha;
        HoldAlpha_R = Frame.Right.Alpha;
        HandLocation_L = Frame.Left.HandLocation;
        HandLocation_R = Frame.Right.HandLocation;
        HandRotation_L = Frame.Left.HandRotation;
        HandRotation_R = Frame.Right.HandRotation;
        ElbowTarget_L = Frame.Left.ElbowTarget;
        ElbowTarget_R = Frame.Right.ElbowTarget;
    }
}
