// The client-to-authority bridge for a flame: fired at the flame's replicated host (a carried flame's world item, a
// fixture) by utils_flame::Request_ActFor on the initiating machine, and applied only on the authority, which turns it into
// the Act request its drain resolves. The initiator is the player's entity (replicated with its pawn), so it resolves on
// the authority.
class UMars_Cue_Flame_Act : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_Flame_Act's fields: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Initiator;

    UPROPERTY(ExposeOnSpawn)
    EMars_Flame_Verb Verb = EMars_Flame_Verb::Toggle;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Flame_Act;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Flame = Owner.As_Flame(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Flame), f"[Flame] an Act cue reached [{Owner.ToString()}], which is no flame"))
        { return; }

        Flame.Request_Act(FMars_Request_Flame_Act(Initiator, Verb));
    }
}
