// Drains Refresh, then Drop, then Throw, then Strike, then SetThrowArmed. Refresh, Drop and Throw carry no payload, so each
// kind is applied at most once per drain; a Drop and a Throw of one held item are one launch (LaunchedItem): the second is
// dropped.
//
// Strike is a blow another machine claims (Cue.Mars.HeldItemUse.Strike), applied only on the authority, each claim on its
// own in arrival order, and judged against what the authority holds: refused at the first of ItemMismatch (nothing held
// that strikes, or not the claimed item), TooSoon (the last applied blow is under k_StrikeMinIntervalFraction of the held
// item's swing ago), NoZone (no live zone with a hurtbox at the address) and OutOfReach (the contact is past Reach + Radius
// + k_StrikeReachSlack from the hand, or past k_StrikeZoneSlack from every hurtbox of the zone). Otherwise it is dealt
// through the player's dealer from the authority's copy of the item's Strike trait; friendly fire and a disabled zone stay
// the dealer's rejections. The tally records every verdict.
//
// Refresh owns the use interactable: a no-probe child of the player whose single Primary.UsableItem target runs the held
// item's UseAction state. Nothing traces it, so it is focused and offered to the player's resolver here, and torn down
// the same way the view-trace focus tears down a world interactable. It carries no prompt: a held item's key hint is an
// action-hint row, not a centre-screen prompt.
//
// Drop and Throw launch the held item as a World-mode world item that adopts it out of the selected slot. A Persistent
// item already has its world item: it is asked to Release (it takes the item back into its holder, then goes Dynamic and
// launches). Either way the hotbar's sync pass sees the slot empty and the held item follows. They launch only on the
// authority, from the aim the request carries (the launching machine's, through Cue.Mars.HeldItemUse.Launch) or, without
// one, from the player's view here; a non-authority drops them. Refresh and SetThrowArmed are owner-local and apply on
// every machine.
class UMars_Processor_HeldItemUse_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_HeldItemUse_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_HeldItemUse);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_HeldItemUse_Requests& InRequests,
                       FMars_Fragment_HeldItemUse& InState)
    {
        auto Self = InHandle.As_HeldItemUse();

        const auto Refresh = InRequests.RefreshFromHeldItemRequests.Num() > 0;
        const auto Drop = InRequests.DropRequests.Num() > 0;
        const auto Throw = InRequests.ThrowRequests.Num() > 0;
        auto DropLaunch = FMars_HeldItemUse_Launch();
        if (Drop)
        { DropLaunch.Aim = InRequests.DropRequests.Last().Aim; }

        auto ThrowLaunch = FMars_HeldItemUse_Launch();
        ThrowLaunch.Kind = EMars_LaunchKind::Throw;
        if (Throw)
        { ThrowLaunch.Aim = InRequests.ThrowRequests.Last().Aim; }

        TArray<FMars_Request_HeldItemUse_Strike> StrikeRequests = InRequests.StrikeRequests;
        TArray<FMars_Request_HeldItemUse_SetThrowArmed> SetThrowArmedRequests = InRequests.SetThrowArmedRequests;
        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);

        // InRequests is invalid past this line; removing before broadcasting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HeldItemUse_Requests);

        if (Refresh)
        { RebuildFromHeldItem(InHandle, InState); }

        if (Drop && HasAuthority)
        { LaunchHeldItem(InHandle, InState, DropLaunch); }

        if (Throw && HasAuthority)
        { LaunchHeldItem(InHandle, InState, ThrowLaunch); }

        if (HasAuthority)
        {
            for (const auto& Request : StrikeRequests)
            { JudgeStrike(InHandle, InState, Request.Strike); }
        }

        for (const auto& Request : SetThrowArmedRequests)
        { HandleSetThrowArmedRequest(Self, InState, Request); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Throw armed
    //--------------------------------------------------------------------------------------------------------------------------

    private void HandleSetThrowArmedRequest(
        FCk_Handle_HeldItemUse& InUse,
        FMars_Fragment_HeldItemUse& InState,
        const FMars_Request_HeldItemUse_SetThrowArmed& InRequest)
    {
        if (InState.ThrowArmed == InRequest.Armed)
        { return; }

        InState.ThrowArmed = InRequest.Armed;
        // Every arm starts uncharged; a disarm clears what a cancelled hold had charged.
        InState.ThrowCharge = 0.0f;

        if (InUse.Has_Fragment(FMars_Fragment_HeldItemUse_Signals))
        { InUse.Get_Fragment(FMars_Fragment_HeldItemUse_Signals).OnThrowArmedChanged.Broadcast(InUse, InRequest.Armed); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Use interactable
    //--------------------------------------------------------------------------------------------------------------------------

    private void RebuildFromHeldItem(FCk_Handle& InPlayer, FMars_Fragment_HeldItemUse& InState)
    {
        TearDown(InPlayer, InState);

        auto HeldItem = InPlayer.As_HeldItem();
        auto Item = HeldItem.Get_CurrentItem();

        // A new held item (or none) is a new launch candidate. A refresh while the launched item is still held keeps the
        // guard: its world item has not adopted it yet.
        if (Item != InState.LaunchedItem)
        { InState.LaunchedItem = FCk_Handle_Item(); }

        if (ck::Is_NOT_Valid(Item) || Item.Has_UseAction() == false)
        { return; }

        const UMars_ItemTrait_UseAction UseAction = Item.Get_UseAction();
        if (ck::EnsureIfNot(UseAction.UseStateClass.IsNull() == false,
            f"[HeldItemUse] UseAction trait on [{Item.ToString()}] has no UseStateClass"))
        { return; }

        BuildFor(InPlayer, InState, UseAction);
    }

    private void BuildFor(FCk_Handle& InPlayer, FMars_Fragment_HeldItemUse& InState, const UMars_ItemTrait_UseAction InUseAction)
    {
        auto TargetSpec = FCk_InteractTarget_Spec(GameplayTags::InteractionChannel_Mars_Primary_UsableItem);
        TargetSpec.Set_CompletionPolicy(InUseAction.CompletionPolicy);
        if (InUseAction.CompletionPolicy == ECk_Interaction_CompletionPolicy::Timed)
        { TargetSpec.Set_InteractionDuration(FCk_Time(InUseAction.HoldSeconds)); }

        auto Target = FMars_Interactable_TargetEntry();
        Target.InteractTargetSpec = TargetSpec;
        Target.InteractionStateClass = InUseAction.UseStateClass;

        auto Spec = FMars_Interactable_Spec();
        Spec.Targets.Add(Target);

        auto PlayerTransform = InPlayer.As_Transform();
        auto Interactable = utils_interactable::Create(PlayerTransform, Spec);
        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        Interactable.Request_Focus(FMars_Request_Interactable_Focus(InPlayer));

        auto Resolver = InPlayer.As_InteractionResolver(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Resolver), f"[HeldItemUse] [{InPlayer.ToString()}] has no InteractionResolver"))
        {
            utils_entity_lifetime::Request_DestroyEntity(Interactable);
            return;
        }

        for (auto InteractTarget : Interactable.Get_AllInteractTargets())
        { Resolver.Request_AddInteractTarget(FCk_Request_InteractionResolver_AddInteractTarget(InteractTarget)); }

        InState.CurrentInteractable = Interactable;
    }

    // Mirrors the view-trace unfocus: cancel any in-flight use, leave the resolver, unfocus, then destroy - nothing else
    // owns this interactable.
    private void TearDown(FCk_Handle& InPlayer, FMars_Fragment_HeldItemUse& InState)
    {
        auto Interactable = InState.CurrentInteractable;
        InState.CurrentInteractable = FCk_Handle_Interactable();

        if (ck::Is_NOT_Valid(Interactable))
        { return; }

        auto Resolver = InPlayer.As_InteractionResolver();
        auto Targets = Interactable.Get_AllInteractTargets();
        for (auto& InteractTarget : Targets)
        {
            InteractTarget.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(InPlayer));
            Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(InteractTarget));
        }

        Interactable.Request_Unfocus(FMars_Request_Interactable_Unfocus(InPlayer));
        utils_entity_lifetime::Request_DestroyEntity(Interactable);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Drop / Throw
    //--------------------------------------------------------------------------------------------------------------------------

    private void LaunchHeldItem(FCk_Handle& InPlayer, FMars_Fragment_HeldItemUse& InState, const FMars_HeldItemUse_Launch& InLaunch)
    {
        const auto InKind = InLaunch.Kind;
        auto HeldItem = InPlayer.As_HeldItem();
        auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item))
        { return; }

        if (Item == InState.LaunchedItem)
        { return; }

        auto WorldItem = Item.Get_PersistentWorldItem();
        if (Item.Has_PersistentWorldItem())
        {
            if (ck::EnsureIfNot(ck::IsValid(WorldItem), f"[HeldItemUse] Persistent item [{Item.ToString()}] has lost its world item"))
            { return; }
        }

        // Set from here on: the item is valid and a Persistent item still has its world item.
        const auto MaybeSolution = InPlayer.As_HeldItemUse().Get_LaunchSolutionFor(InLaunch);
        if (MaybeSolution.IsSet() == false)
        { return; }

        const auto Solution = MaybeSolution.GetValue();

        if (Item.Has_PersistentWorldItem())
        {
            WorldItem.Request_Release(FMars_Request_WorldItem_Release(Solution.LinearVelocity, Solution.AngularVelocityDeg));

            InState.LaunchedItem = Item;
            Broadcast_ItemLaunched(InPlayer, Item, InKind);
            return;
        }

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(Solution.Origin.Rotator(), Solution.Origin.GetLocation());
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(Item.Get_Definition());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SourceItem = Item;
        SpawnParams.SourceInventory = HeldItem.Get_CurrentInventory();
        SpawnParams.LaunchVelocity = Solution.LinearVelocity;
        SpawnParams.AngularVelocityDeg = Solution.AngularVelocityDeg;

        // The dropped item outlives the player (it follows nobody) and destroys itself once picked up; the funnel puts it
        // under the replicated spawn owner. SourceItem and SourceInventory are this authority's own handles, so the adopt
        // works here.
        auto Owner = ck::TransientEntity();
        utils_world_item::Request_SpawnWorldEntity(Owner, utils_world_item::Get_WorldItemScriptClass(Item), SpawnParams);

        InState.LaunchedItem = Item;
        Broadcast_ItemLaunched(InPlayer, Item, InKind);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Strike
    //--------------------------------------------------------------------------------------------------------------------------

    private void JudgeStrike(FCk_Handle& InPlayer, FMars_Fragment_HeldItemUse& InState, const FMars_HeldItemUse_Strike& InClaim)
    {
        auto HeldItem = InPlayer.As_HeldItem();
        const auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item.Has_Strike() == false || InClaim.Item.Get() != Item.Get_Definition())
        {
            RefuseStrike(InState, EMars_HeldItemUse_StrikeRefusal::ItemMismatch);
            return;
        }

        const UMars_ItemTrait_Strike Strike = Item.Get_Strike();
        const auto Now = utils_mars_net::Get_ServerWorldSeconds(InPlayer);
        const auto MinInterval = constants_held_item_use::k_StrikeMinIntervalFraction * (Strike.WindupSeconds + Strike.RecoverySeconds);
        if (InState.Strikes.LastAppliedAt.IsSet() && Now - InState.Strikes.LastAppliedAt.GetValue() < MinInterval)
        {
            RefuseStrike(InState, EMars_HeldItemUse_StrikeRefusal::TooSoon);
            return;
        }

        auto Zone = utils_hit_zone::TryGet_ZoneAt(FMars_HitZone_Address(InClaim.ZoneRoot, InClaim.ZoneIndex));
        if (ck::Is_NOT_Valid(Zone) || Zone.Get_Hurtboxes().Num() == 0)
        {
            RefuseStrike(InState, EMars_HeldItemUse_StrikeRefusal::NoZone);
            return;
        }

        const auto Hand = utils_transform::Get_EntityCurrentTransform(HeldItem.Get_HandAttachPoint()).GetLocation();
        const auto IsWithinReach = (InClaim.Location - Hand).Size() <= Strike.Reach + Strike.Radius + constants_held_item_use::k_StrikeReachSlack;
        if (IsWithinReach == false || Get_IsNearAHurtbox(Zone, InClaim.Location) == false)
        {
            RefuseStrike(InState, EMars_HeldItemUse_StrikeRefusal::OutOfReach);
            return;
        }

        auto Dealer = InPlayer.As_DamageDealer(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Dealer), f"[HeldItemUse] [{InPlayer.ToString()}] claimed a strike but has no DamageDealer"))
        {
            RefuseStrike(InState, EMars_HeldItemUse_StrikeRefusal::NoZone);
            return;
        }

        InState.Strikes.Applied += 1;
        InState.Strikes.LastAppliedAt = Now;

        auto Event = utils_damage_dealer::Make_Event(Dealer, Strike.Damage, Strike.DamageType);
        Event.Source.Causer = Item;
        Event.Hit.Location = InClaim.Location;
        Event.Hit.Normal = InClaim.Normal;
        Event.Hit.Impulse = InClaim.Impulse.GetSafeNormal() * Strike.ImpulseSpeed;
        Dealer.Request_DealDamage(FMars_Request_DamageDealer_DealDamage(Zone, Event));
    }

    private bool Get_IsNearAHurtbox(const FCk_Handle_HitZone& InZone, FVector InLocation)
    {
        for (auto Hurtbox : InZone.Get_Hurtboxes())
        {
            const auto Node = Hurtbox.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Node))
            { continue; }

            if ((utils_transform::Get_EntityCurrentTransform(Node).GetLocation() - InLocation).Size() <= constants_held_item_use::k_StrikeZoneSlack)
            { return true; }
        }

        return false;
    }

    private void RefuseStrike(FMars_Fragment_HeldItemUse& InState, EMars_HeldItemUse_StrikeRefusal InRefusal)
    {
        InState.Strikes.Refused += 1;
        InState.Strikes.LastRefusal = InRefusal;
    }

    private void Broadcast_ItemLaunched(FCk_Handle& InPlayer, FCk_Handle_Item InItem, EMars_LaunchKind InKind)
    {
        if (InPlayer.Has_Fragment(FMars_Fragment_HeldItemUse_Signals))
        { InPlayer.Get_Fragment(FMars_Fragment_HeldItemUse_Signals).OnItemLaunched.Broadcast(InPlayer.As_HeldItemUse(), InItem, InKind); }
    }
}
