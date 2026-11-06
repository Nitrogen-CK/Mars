// What the cellar bat's Animation Blueprint reads (CellarBat_R01_Mars_ABP reparents to this class). Written only by
// UMars_CellarBat_EntityScript's tick from the bat kernel's state and telemetry; the AnimBP decides nothing about movement
// or attacks, it only poses what it is told.
struct FMars_CellarBat_AnimFrame
{
    UPROPERTY()
    EMars_Bat_Phase Phase = EMars_Bat_Phase::Roosting;

    // cm/s, smoothed (utils_bat::SpeedSmoothRate).
    UPROPERTY()
    float32 Speed = 0.0f;

    // Degrees a second, positive turning right.
    UPROPERTY()
    float32 TurnRate = 0.0f;

    // -1 (banked hard left) .. 1 (hard right): the turn still to come (a heading trailing the root's yaw, see
    // utils_bat::BankFollowRate), clamped and smoothed.
    UPROPERTY()
    float32 BankAlpha = 0.0f;

    // Degrees, nose up positive.
    UPROPERTY()
    float32 Pitch = 0.0f;

    // How far through the swoop's stage (telegraph, swoop, recover) [0, 1]; 0 with none.
    UPROPERTY()
    float32 SwoopAlpha = 0.0f;
}

class UMars_CellarBat_AnimInstance : UAnimInstance
{
    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    EMars_Bat_Phase Phase = EMars_Bat_Phase::Roosting;

    // Phase as an integer, for blend-by-int nodes.
    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    int32 PhaseIndex = 0;

    // PhaseIndex as a float: the AnimBP's transition rules compare it (CellarBat_R01_Mars_ABP is built by
    // Tools/LevelDesign/cellar_bat_r01_review/cellar_bat_animbp_ue.py, whose rule authoring reads float members only).
    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 PhaseValue = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 Speed = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 TurnRate = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 BankAlpha = 0.0f;

    // BankAlpha split by side for the AnimBP's two apply-additive layers: max(BankAlpha, 0) and max(-BankAlpha, 0).
    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 BankRightAlpha = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 BankLeftAlpha = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 Pitch = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    float32 SwoopAlpha = 0.0f;

    // In the air under its own wings (not hanging, perching, falling, landed or dead).
    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    bool IsFlying = false;

    // Hanging inverted from its perch (Roosting, Alert, Perching).
    UPROPERTY(BlueprintReadOnly, Category = "CellarBat")
    bool IsHanging = true;

    void Apply(const FMars_CellarBat_AnimFrame& InFrame)
    {
        Phase = InFrame.Phase;
        PhaseIndex = int32(InFrame.Phase);
        PhaseValue = float32(PhaseIndex);
        Speed = InFrame.Speed;
        TurnRate = InFrame.TurnRate;
        BankAlpha = InFrame.BankAlpha;
        BankRightAlpha = Math::Max(InFrame.BankAlpha, 0.0f);
        BankLeftAlpha = Math::Max(-InFrame.BankAlpha, 0.0f);
        Pitch = InFrame.Pitch;
        SwoopAlpha = InFrame.SwoopAlpha;
        IsHanging = utils_bat::Get_IsHangingPhase(InFrame.Phase);
        IsFlying = IsHanging == false && InFrame.Phase != EMars_Bat_Phase::Falling && InFrame.Phase != EMars_Bat_Phase::Landed &&
            InFrame.Phase != EMars_Bat_Phase::Dead;
    }
}

namespace utils_bat
{
    // The phases in which it hangs from its perch, inverted.
    bool Get_IsHangingPhase(EMars_Bat_Phase InPhase)
    {
        return InPhase == EMars_Bat_Phase::Roosting || InPhase == EMars_Bat_Phase::Alert || InPhase == EMars_Bat_Phase::Perching;
    }
}
