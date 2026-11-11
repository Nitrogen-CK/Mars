// The client-to-authority bridge for a lock: fired at the lock's replicated root by utils_key_lock::Request_ActFor on the
// initiating machine, at the gloves' grip, and applied only on the authority, which turns it into the Act request its
// drain resolves. The initiator is the player's entity (replicated with its pawn), so it resolves on the authority.
class UMars_Cue_KeyLock_Act : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_KeyLock_Act's fields: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Initiator;

    UPROPERTY(ExposeOnSpawn)
    EMars_KeyLock_Action Action = EMars_KeyLock_Action::Insert;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_KeyLock_Act;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Lock = Owner.As_KeyLock(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Lock), f"[KeyLock] an Act cue reached [{Owner.ToString()}], which is no lock"))
        { return; }

        Lock.Request_Act(FMars_Request_KeyLock_Act(Initiator, Action));
    }
}
