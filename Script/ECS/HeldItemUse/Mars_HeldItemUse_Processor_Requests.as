// Drains Refresh, then Drop, then Throw, then SetThrowArmed. Refresh, Drop and Throw carry no payload, so each kind is
// applied at most once per drain however many were queued (a second Refresh would rebuild the use interactable again; a
// second Drop/Throw is already a no-op through LaunchedItem). SetThrowArmed applies in order and broadcasts
// OnThrowArmedChanged on every change.
//
// Refresh owns the use interactable: a no-probe child of the player whose single Primary.UsableItem target runs the held
// item's UseAction state. Nothing traces it, so it is focused and offered to the player's resolver here, and torn down
// the same way the view-trace focus tears down a world interactable. It carries no prompt: a held item's key hint is an
// action-hint row, not a centre-screen prompt.
//
// Drop and Throw launch the held item as a World-mode world item that adopts it out of the selected slot. The hotbar's
// sync pass sees the slot empty and the held item follows.
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
        TArray<FMars_Request_HeldItemUse_SetThrowArmed> SetThrowArmedRequests = InRequests.SetThrowArmedRequests;

        // Swap-and-pop - InRequests is dead past this line. Removing before acting lets re-entrant requests survive.
        Self.Request_TryRemove(FMars_Fragment_HeldItemUse_Requests);

        if (Refresh)
        { RebuildFromHeldItem(InHandle, InState); }

        if (Drop)
        { LaunchHeldItem(InHandle, InState, false); }

        if (Throw)
        { LaunchHeldItem(InHandle, InState, true); }

        for (const auto& Request : SetThrowArmedRequests)
        { HandleSetThrowArmedRequest(Self, InState, Request); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Throw armed (HUD-only)
    //--------------------------------------------------------------------------------------------------------------------------

    private void HandleSetThrowArmedRequest(
        FCk_Handle_HeldItemUse& InUse,
        FMars_Fragment_HeldItemUse& InState,
        const FMars_Request_HeldItemUse_SetThrowArmed& InRequest)
    {
        if (InState.ThrowArmed == InRequest.Armed)
        { return; }

        InState.ThrowArmed = InRequest.Armed;

        if (InUse.Has_Fragment(FMars_Fragment_HeldItemUse_Signals))
        { InUse.Get_Fragment(FMars_Fragment_HeldItemUse_Signals).OnThrowArmedChanged.Broadcast(InUse, InRequest.Armed); }
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Use interactable
    //--------------------------------------------------------------------------------------------------------------------------

    private void RebuildFromHeldItem(FCk_Handle& InPlayer, FMars_Fragment_HeldItemUse& InState)
    {
        TearDown(InPlayer, InState);

        // A new held item (or none) is a new launch candidate.
        InState.LaunchedItem = FCk_Handle_Item();

        auto HeldItem = InPlayer.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(HeldItem), f"[HeldItemUse] [{InPlayer.ToString()}] has no HeldItem feature"))
        { return; }

        auto Item = HeldItem.Get_CurrentItem();
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

        auto Resolver = InPlayer.As_InteractionResolver(ECk_SanityCheck::UnChecked);
        auto Targets = Interactable.Get_AllInteractTargets();
        for (auto& InteractTarget : Targets)
        {
            InteractTarget.Request_CancelInteraction(FCk_Request_InteractTarget_CancelInteraction(InPlayer));
            if (ck::IsValid(Resolver))
            { Resolver.Request_RemoveInteractTarget(FCk_Request_InteractionResolver_RemoveInteractTarget(InteractTarget)); }
        }

        Interactable.Request_Unfocus(FMars_Request_Interactable_Unfocus(InPlayer));
        utils_entity_lifetime::Request_DestroyEntity(Interactable);
    }

    //--------------------------------------------------------------------------------------------------------------------------
    // Drop / Throw
    //--------------------------------------------------------------------------------------------------------------------------

    private void LaunchHeldItem(FCk_Handle& InPlayer, FMars_Fragment_HeldItemUse& InState, bool InIsThrow)
    {
        auto HeldItem = InPlayer.As_HeldItem(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(HeldItem), f"[HeldItemUse] [{InPlayer.ToString()}] has no HeldItem feature"))
        { return; }

        auto Item = HeldItem.Get_CurrentItem();
        if (ck::Is_NOT_Valid(Item) || Item == InState.LaunchedItem)
        { return; }

        auto Speed = InIsThrow ? constants_held_item_use::k_DefaultThrowSpeed : constants_held_item_use::k_DefaultDropSpeed;
        auto AngularVelocityDeg = FVector::ZeroVector;
        if (Item.Has_Throwable())
        {
            const UMars_ItemTrait_Throwable Throwable = Item.Get_Throwable();
            Speed = InIsThrow ? Throwable.ThrowSpeed : Throwable.DropSpeed;
            AngularVelocityDeg = Throwable.AngularVelocityDeg;
        }

        const auto View = Get_ViewTransform(InPlayer);
        const auto Forward = View.GetRotation().GetForwardVector();

        auto SpawnTransform = FTransform(View.Rotator(), View.GetLocation() + Forward * constants_held_item_use::k_NoHandSpawnDistance);
        auto Hand = HeldItem.Get_HandAttachPoint();
        if (ck::IsValid(Hand))
        { SpawnTransform = utils_transform::Get_EntityCurrentTransform(Hand); }

        auto PawnVelocity = FVector::ZeroVector;
        auto Character = Cast<ACharacter>(ck::ToActor(InPlayer, ECk_SanityCheck::UnChecked));
        if (ck::IsValid(Character))
        { PawnVelocity = Character.GetVelocity(); }

        auto SpawnParams = UMars_WorldItem_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(SpawnTransform.Rotator(), SpawnTransform.GetLocation());
        SpawnParams.Definition = utils_held_item::Make_DefinitionSoft(Item.Get_Definition());
        SpawnParams.Mode = EMars_WorldItem_Mode::World;
        SpawnParams.SourceItem = Item;
        SpawnParams.SourceInventory = HeldItem.Get_CurrentInventory();
        SpawnParams.LaunchVelocity = Forward * Speed + PawnVelocity;
        SpawnParams.AngularVelocityDeg = AngularVelocityDeg;

        // The dropped item outlives the player; it destroys itself once picked up.
        utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), Get_WorldItemScriptClass(Item), SpawnParams);

        InState.LaunchedItem = Item;
    }

    private FTransform Get_ViewTransform(FCk_Handle& InPlayer) const
    {
        auto Viewpoint = InPlayer.As_PlayerViewpoint(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Viewpoint))
        { return utils_transform::Get_EntityCurrentTransform(Viewpoint.Get_Viewpoint()); }

        auto PlayerTransform = InPlayer.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(PlayerTransform))
        { return utils_transform::Get_EntityCurrentTransform(PlayerTransform); }

        return FTransform::Identity;
    }

    private TSubclassOf<UMars_WorldItem_EntityScript> Get_WorldItemScriptClass(FCk_Handle_Item& InItem) const
    {
        TSubclassOf<UMars_WorldItem_EntityScript> ScriptClass = UMars_WorldItem_EntityScript;
        if (InItem.Has_Presentation() == false)
        { return ScriptClass; }

        const UMars_ItemTrait_Presentation Presentation = InItem.Get_Presentation();
        if (ck::IsValid(Presentation.WorldItemScriptClass))
        { ScriptClass = Presentation.WorldItemScriptClass; }

        return ScriptClass;
    }
}
