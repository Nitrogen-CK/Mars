// The client-to-authority bridge for a selection change: fired at the carrier's replicated entity on every machine by
// utils_hotbar::Fire_SelectCue, carrying the absolute target the change meant on that machine (a toggle or a cycle is
// resolved before it crosses, so the authority applies what the requesting chef saw). It runs where the multicast
// policy says and is applied only on the authority, as a SetSelection request. On the listen host and in standalone it
// runs the same frame.
class UMars_Cue_Hotbar_Select : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_Hotbar_SetSelection's field: that struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    TOptional<int32> Index;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_Hotbar_Select;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Hotbar = Owner.As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Hotbar), f"[Hotbar] a Select cue reached [{Owner.ToString()}], which has no Hotbar"))
        { return; }

        Hotbar.Request_SetSelection(FMars_Request_Hotbar_SetSelection(Index));
    }
}
