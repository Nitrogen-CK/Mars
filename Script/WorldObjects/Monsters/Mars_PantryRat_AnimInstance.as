// What the assembly pushes into the rat's anim instance every frame (read from the kernel's getters).
struct FMars_PantryRat_AnimFrame
{
    UPROPERTY()
    EMars_PantryRat_Phase Phase = EMars_PantryRat_Phase::Emerge;

    // Planar root speed, cm/s.
    UPROPERTY()
    float32 Speed = 0.0f;

    UPROPERTY()
    bool Carrying = false;

    UPROPERTY()
    bool Dead = false;
}

// Telemetry for a future AnimBP (Phase 4 may build the blend graph): in Phase 3 the assembly drives the clips itself with
// USkeletalMeshComponent::PlayAnimation and still fills these fields, so an AnimBP deriving from this class reads the same
// state the clip table chose from.
class UMars_PantryRat_AnimInstance : UAnimInstance
{
    UPROPERTY(BlueprintReadOnly, Category = "PantryRat")
    EMars_PantryRat_Phase Phase = EMars_PantryRat_Phase::Emerge;

    // Phase as a float, for transition rules that compare float members.
    UPROPERTY(BlueprintReadOnly, Category = "PantryRat")
    float32 PhaseValue = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "PantryRat")
    float32 Speed = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "PantryRat")
    bool Carrying = false;

    UPROPERTY(BlueprintReadOnly, Category = "PantryRat")
    bool Dead = false;

    void Apply(const FMars_PantryRat_AnimFrame& InFrame)
    {
        Phase = InFrame.Phase;
        PhaseValue = float32(int32(InFrame.Phase));
        Speed = InFrame.Speed;
        Carrying = InFrame.Carrying;
        Dead = InFrame.Dead;
    }
}
