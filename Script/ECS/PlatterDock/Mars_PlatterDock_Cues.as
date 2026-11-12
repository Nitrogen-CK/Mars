// The client-to-authority bridge for a dock: fired at the dock's replicated entity by utils_platter_dock::Request_ActFor
// on the initiating machine, at the gloves' grip, and applied only on the authority, which turns it into the Act request
// its drain resolves. The initiator is the player's entity (replicated with its pawn), so it resolves on the authority.
class UMars_Cue_PlatterDock_Act : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_PlatterDock_Act's fields: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Initiator;

    UPROPERTY(ExposeOnSpawn)
    EMars_PlatterDock_Action Action = EMars_PlatterDock_Action::Place;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_PlatterDock_Act;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Dock = Owner.As_PlatterDock(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Dock), f"[PlatterDock] an Act cue reached [{Owner.ToString()}], which is no dock"))
        { return; }

        Dock.Request_Act(FMars_Request_PlatterDock_Act(Initiator, Action));
    }
}
