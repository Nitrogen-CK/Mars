// The client-to-authority bridge for a deposit: fired at the platter's replicated entity by utils_platter::Request_DepositFor
// on the initiating machine, at the gloves' grip, and applied only on the authority, which turns it into the Deposit request
// its drain takes on the books. The initiator is the player's entity (replicated with its pawn), so it resolves on the
// authority.
class UMars_Cue_Platter_Deposit : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_Platter_Deposit's field: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Initiator;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Platter_Deposit;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Platter = Owner.As_Platter(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Platter), f"[Platter] a Deposit cue reached [{Owner.ToString()}], which is no platter"))
        { return; }

        Platter.Request_Deposit(FMars_Request_Platter_Deposit(Initiator));
    }
}
