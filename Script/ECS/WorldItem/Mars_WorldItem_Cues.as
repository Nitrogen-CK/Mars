// The client-to-authority bridge for a pickup: fired at the world item's replicated root by the pickup task on the
// initiating machine, at the gloves' grip, run where the multicast policy says, and applied only on the authority, which
// turns it into the PickUp request its drain stows from. The initiator is the player's entity (replicated with its pawn),
// so it resolves on the authority.
class UMars_Cue_WorldItem_PickUp : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_Request_WorldItem_PickUp's field: the request struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle Initiator;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_WorldItem_PickUp;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto WorldItem = Owner.As_WorldItem(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(WorldItem), f"[WorldItem] a PickUp cue reached [{Owner.ToString()}], which is no world item"))
        { return; }

        WorldItem.Request_PickUp(FMars_Request_WorldItem_PickUp(Initiator));
    }
}
