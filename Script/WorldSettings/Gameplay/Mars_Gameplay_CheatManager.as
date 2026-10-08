class UMars_Gameplay_CheatManager : UCheatManager
{
    UFUNCTION(Exec)
    void Mars_Debugger()
    {
        utils_mars_debugger::Toggle();
    }

    // Swings the local player's hand along the cleaver's chop arc without an item or a strike: the blow lands after
    // InImpactSeconds and the hand is back at rest InRecoverySeconds later (the cleaver's own timings by default).
    UFUNCTION(Exec)
    void Mars_Swing(float32 InImpactSeconds = 0.15f, float32 InRecoverySeconds = 0.35f)
    {
        auto Character = Cast<AMars_PlayerCharacter>(Gameplay::GetPlayerController(0).GetControlledPawn());
        if (ck::Is_NOT_Valid(Character))
        { return; }

        Character.Request_Strike(FMars_Request_HandSwing_Start(utils_hand_swing::Make_ChopArc(), InImpactSeconds, InRecoverySeconds));
    }

    // Puts one sandbox item (Rock, Ration, Cog, Backpack, Cleaver, Tenderizer, Pan) into the local player's selected
    // hotbar slot, so a held item can be tested without finding one in the level.
    UFUNCTION(Exec)
    void Mars_Give(FString InItemName)
    {
        auto Character = Cast<AMars_PlayerCharacter>(Gameplay::GetPlayerController(0).GetControlledPawn());
        if (ck::Is_NOT_Valid(Character))
        { return; }

        UCk_InventoryItem_Definition Definition = nullptr;
        if (InItemName == "Rock") { Definition = mars_items::Rock(); }
        else if (InItemName == "Ration") { Definition = mars_items::Ration(); }
        else if (InItemName == "Cog") { Definition = mars_items::Cog(); }
        else if (InItemName == "Backpack") { Definition = mars_items::Backpack(); }
        else if (InItemName == "Cleaver") { Definition = mars_items::Cleaver(); }
        else if (InItemName == "Tenderizer") { Definition = mars_items::Tenderizer(); }
        else if (InItemName == "Pan") { Definition = mars_items::Pan(); }

        if (ck::Is_NOT_Valid(Definition))
        {
            ck::Trace(f"[Mars_Give] unknown item [{InItemName}]");
            return;
        }

        // The selected bag slot, or the first empty one (which is then selected): a fresh player selects nothing.
        auto Hotbar = Character.TryGet_ActorEntityHandle().As_Hotbar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hotbar))
        {
            ck::Trace("[Mars_Give] the player has no hotbar");
            return;
        }

        auto Index = Hotbar.Get_SelectedIndex();
        if (Index.IsSet() == false)
        { Index = Hotbar.TryGet_FirstEmptyBagSlot(); }

        if (Index.IsSet() == false)
        {
            ck::Trace("[Mars_Give] no selected or empty bag slot to put the item in");
            return;
        }

        auto Slot = Hotbar.Get_Slot(Index.GetValue());
        auto Request = FCk_Request_Inventory_AddItemByDefinition(Definition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Slot.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        Hotbar.Request_Select(FMars_Request_Hotbar_Select(Index.GetValue()));
    }

    // Presses (1) or releases (0) the Primary interaction intent on the local player's resolver, as the Primary key does.
    UFUNCTION(Exec)
    void Mars_Primary(bool InPressed)
    {
        auto Character = Cast<AMars_PlayerCharacter>(Gameplay::GetPlayerController(0).GetControlledPawn());
        if (ck::Is_NOT_Valid(Character))
        { return; }

        auto Resolver = Character.TryGet_ActorEntityHandle().As_InteractionResolver(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Resolver))
        { return; }

        if (InPressed)
        { Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(GameplayTags::InteractionIntent_Mars_Primary)); }
        else
        { Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(GameplayTags::InteractionIntent_Mars_Primary)); }
    }

    // Logs the local player's HandSwing ledger: phase, elapsed, pose and the swing node's offset.
    UFUNCTION(Exec)
    void Mars_SwingState()
    {
        auto Character = Cast<AMars_PlayerCharacter>(Gameplay::GetPlayerController(0).GetControlledPawn());
        if (ck::Is_NOT_Valid(Character))
        {
            ck::Trace("[Mars_SwingState] no local Mars player character");
            return;
        }

        auto Swing = Character.TryGet_ActorEntityHandle().As_HandSwing(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Swing))
        {
            ck::Trace("[Mars_SwingState] the player entity has no HandSwing");
            return;
        }

        auto Node = Swing.Get_Node();
        const auto NodeOffset = ck::IsValid(Node) ? utils_scene_node::Get_Offset(Node) : FTransform::Identity;
        const auto NodeWorld = ck::IsValid(Node) ? utils_transform::Get_EntityCurrentTransform(Node.As_Transform()).GetLocation() : FVector::ZeroVector;
        const auto ParentWorld = ck::IsValid(Node) ? utils_scene_node::Get_DriverWorldTransform(Node).GetLocation() : FVector::ZeroVector;
        auto GloveTarget = FVector::ZeroVector;
        auto HandsAnim = Cast<UMars_FPHands_AnimInstance>(Character.FPHands.GetAnimInstance());
        if (ck::IsValid(HandsAnim))
        { GloveTarget = HandsAnim.GripTarget_R.GetLocation(); }

        auto Player = Character.TryGet_ActorEntityHandle();
        auto Hotbar = Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        auto HeldItem = Player.As_HeldItem(ECk_SanityCheck::UnChecked);
        const auto SelectedIndex = ck::IsValid(Hotbar) && Hotbar.Get_SelectedIndex().IsSet() ? Hotbar.Get_SelectedIndex().GetValue() : -1;
        const auto SelectedItemValid = ck::IsValid(Hotbar) && ck::IsValid(Hotbar.Get_SelectedItem());
        const auto SlotItems = ck::IsValid(Hotbar) && ck::IsValid(Hotbar.Get_SelectedSlot()) ? Hotbar.Get_SelectedSlot().Get_NumItems() : -1;
        const auto HeldValid = ck::IsValid(HeldItem) && ck::IsValid(HeldItem.Get_CurrentItem());
        const auto UseInteractableValid = Player.Has_Fragment(FMars_Fragment_HeldItemUse) && ck::IsValid(Player.Get_Fragment(FMars_Fragment_HeldItemUse).CurrentInteractable);
        auto Resolver = Player.As_InteractionResolver(ECk_SanityCheck::UnChecked);
        const auto BestPrimary = ck::IsValid(Resolver) ? Resolver.Get_BestInteractTargets(GameplayTags::InteractionIntent_Mars_Primary).Num() : -1;

        ck::Trace(f"[Mars_SwingState] phase [{Swing.Get_Phase() :n}] elapsed [{Swing.Get_Elapsed()}] pose [{Swing.Get_Pose().GetLocation()}] node offset [{NodeOffset.GetLocation()}] glove target R [{GloveTarget}] hotbar selected [{SelectedIndex}] slot items [{SlotItems}] selected item [{SelectedItemValid}] held item [{HeldValid}] use interactable [{UseInteractableValid}] best primary targets [{BestPrimary}]");
    }
}
