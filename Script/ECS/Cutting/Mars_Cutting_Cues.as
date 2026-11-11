// Stance A, following its host: a remote operator's chop reaches the authority as an event carrying its aim.

// What a chop cue carries: who chops, and where that machine saw the hand (cm along the board). The cue's spawn params.
struct FMars_Cutting_ChopAim
{
    UPROPERTY()
    FCk_Handle Operator;

    UPROPERTY()
    float32 LateralCm = 0.0f;

    FMars_Cutting_ChopAim() {}

    FMars_Cutting_ChopAim(FCk_Handle InOperator, float32 InLateralCm)
    {
        Operator = InOperator;
        LateralCm = InLateralCm;
    }
}

// The client-to-authority bridge for a chop: fired at the station's replicated root by utils_cutting::Request_ChopFor on the
// operating machine, and applied only on the authority. A chop from anyone but the station's operator is refused without
// an ensure (an operator may leave while its chop is in flight); otherwise it becomes the Chop request with the aim, which
// sets the hand and starts the chop only from Idle. The operator is the player's entity (replicated with its pawn), so it
// resolves on the authority.
class UMars_Cue_Cutting_Chop : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Cutting_ChopAim's fields.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Operator;

    UPROPERTY(ExposeOnSpawn)
    float32 LateralCm = 0.0f;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Cutting_Chop;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Cutting = Owner.As_Cutting(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Cutting), f"[Cutting] a Chop cue reached [{Owner.ToString()}], which has no Cutting"))
        { return; }

        if (utils_cutting::Get_MayChopFor(Cutting, Operator) == false)
        { return; }

        Cutting.Request_Chop(FMars_Request_Cutting_Chop(LateralCm));
    }
}
