// The client-to-authority bridge for a drop or a throw: fired at the player's replicated entity on every machine by
// whatever decides to launch (the player's Inventory HFSM, the Throw use task), carrying the launch kind and the aim taken
// from that machine's view (the authority cannot know a client's view). It runs where the multicast policy says and is
// applied only on the authority, which turns it into the Drop or Throw request its drain launches from. On the listen host
// and in standalone it runs the same frame.
class UMars_Cue_HeldItemUse_Launch : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_HeldItemUse_Launch's fields: that struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    EMars_LaunchKind Kind = EMars_LaunchKind::Drop;

    UPROPERTY(ExposeOnSpawn)
    TOptional<FMars_HeldItemUse_Aim> Aim;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_HeldItemUse_Launch;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Use = Owner.As_HeldItemUse(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Use), f"[HeldItemUse] a Launch cue reached [{Owner.ToString()}], which has no HeldItemUse"))
        { return; }

        if (Kind == EMars_LaunchKind::Throw)
        {
            Use.Request_Throw(FMars_Request_HeldItemUse_Throw(Aim));
            return;
        }

        Use.Request_Drop(FMars_Request_HeldItemUse_Drop(Aim));
    }
}

namespace utils_held_item_use
{
    // Where InPlayer's launch goes, from this machine's view of it: the view's forward and the pawn's velocity.
    FMars_HeldItemUse_Aim Make_Aim(FCk_Handle InPlayer)
    {
        const auto View = Get_ViewTransform(InPlayer);

        // Optional: a test player has no actor.
        auto PawnVelocity = FVector::ZeroVector;
        auto Character = Cast<ACharacter>(ck::ToActor(InPlayer, ECk_SanityCheck::UnChecked));
        if (ck::IsValid(Character))
        { PawnVelocity = Character.GetVelocity(); }

        return FMars_HeldItemUse_Aim(View.GetRotation().GetForwardVector(), PawnVelocity);
    }

    // The player's view; a carrier without a PlayerViewpoint (a test rig) launches from its own transform.
    FTransform Get_ViewTransform(FCk_Handle InPlayer)
    {
        auto Viewpoint = InPlayer.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Viewpoint))
        { return utils_transform::Get_EntityCurrentTransform(Viewpoint.Get_Viewpoint()); }

        return utils_transform::Get_EntityCurrentTransform(InPlayer.As_Transform());
    }

    // The one way a drop or a throw is asked for outside a test: the cue at the player's entity, with this machine's aim.
    void Fire_LaunchCue(FCk_Handle InPlayer, EMars_LaunchKind InKind)
    {
        utils_cue_generic::Request_ExecuteCue(InPlayer, GameplayTags::Cue_Mars_HeldItemUse_Launch,
            FMars_HeldItemUse_Launch(InKind, Make_Aim(InPlayer)), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }
}
