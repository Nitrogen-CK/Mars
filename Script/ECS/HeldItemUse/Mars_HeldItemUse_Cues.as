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

// The client-to-authority bridge for a blow: fired at the player's replicated entity by the striking machine
// (utils_held_item_use::Fire_StrikeCueFor) when its swing lands on a zone that machine has no authority over, carrying the
// zone's address, the item swung and the contact. It is applied only on the authority, as a Strike request its drain
// judges. No order between claims matters: a claim is judged against what the authority holds, its clock and where things
// stand, never against another claim, so two that begin in one frame apply once whichever begins first.
class UMars_Cue_HeldItemUse_Strike : UCk_GenericCue_EntityScript
{
    default _LifetimeBehavior = ECk_Cue_LifetimeBehavior::AfterOneFrame;
    default _ConcurrencyPolicy = ECk_Cue_ConcurrencyPolicy::AllowMultiple;
    default _OwnerValidationPolicy = ECk_Cue_OwnerValidationPolicy::RequireValid;

    // FMars_HeldItemUse_Strike's fields: that struct is the cue's spawn params.
    UPROPERTY(ExposeOnSpawn)
    FCk_Handle ZoneRoot;

    UPROPERTY(ExposeOnSpawn)
    int32 ZoneIndex = 0;

    UPROPERTY(ExposeOnSpawn)
    TSoftObjectPtr<UCk_InventoryItem_Definition> Item;

    UPROPERTY(ExposeOnSpawn)
    FVector Location = FVector::ZeroVector;

    UPROPERTY(ExposeOnSpawn)
    FVector Normal = FVector::ZeroVector;

    UPROPERTY(ExposeOnSpawn)
    FVector Impulse = FVector::ZeroVector;

    UFUNCTION(BlueprintOverride)
    FGameplayTag Get_CueName() const
    {
        return GameplayTags::Cue_Mars_HeldItemUse_Strike;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        const auto Owner = ck::OwnerEntity(InHandle);
        if (utils_net::Get_HasAuthority(Owner) == false)
        { return; }

        auto Use = Owner.As_HeldItemUse(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Use), f"[HeldItemUse] a Strike cue reached [{Owner.ToString()}], which has no HeldItemUse"))
        { return; }

        auto Strike = FMars_HeldItemUse_Strike();
        Strike.ZoneRoot = ZoneRoot;
        Strike.ZoneIndex = ZoneIndex;
        Strike.Item = Item;
        Strike.Location = Location;
        Strike.Normal = Normal;
        Strike.Impulse = Impulse;
        Use.Request_Strike(FMars_Request_HeldItemUse_Strike(Strike));
    }
}

namespace utils_held_item_use
{
    // Claims InSwing's blow to the authority when it landed on a zone this machine has no authority over (there, the zone
    // drops the hit the swing's own dealer sent it). A miss, a world hit or a zone this machine owns sends nothing.
    void Fire_StrikeCueFor(FCk_Handle InPlayer, const FMars_HeldItemUse_Swing& InSwing)
    {
        const auto& Result = InSwing.Result;
        if (Result.Get_HitKind() != ECk_ProbeTrace_HitKind::Probe || ck::Is_NOT_Valid(Result.Get_HitEntity()))
        { return; }

        const auto Zone = utils_hit_zone::TryGet_Zone(Result.Get_HitEntity());
        if (ck::Is_NOT_Valid(Zone) || utils_net::Get_HasAuthority(Zone))
        { return; }

        const auto Address = Zone.Get_Address();
        if (ck::EnsureIfNot(ck::IsValid(Address.Root), f"[HeldItemUse] the zone [{Zone.ToString()}] a strike landed on has no address root"))
        { return; }

        auto Strike = FMars_HeldItemUse_Strike();
        Strike.ZoneRoot = Address.Root;
        Strike.ZoneIndex = Address.Index;
        Strike.Item = utils_held_item::Make_DefinitionSoft(InSwing.Item.Get_Definition());
        Strike.Location = Result.Get_HitLocation();
        Strike.Normal = Result.Get_SurfaceNormal();
        Strike.Impulse = InSwing.Impulse;
        utils_cue_generic::Request_ExecuteCue(InPlayer, GameplayTags::Cue_Mars_HeldItemUse_Strike, Strike,
            ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
    }

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
