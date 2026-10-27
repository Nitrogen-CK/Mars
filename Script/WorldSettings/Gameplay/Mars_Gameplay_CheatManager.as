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
        auto Character = TryGet_LocalCharacter("Mars_Swing");
        if (ck::Is_NOT_Valid(Character))
        { return; }

        Character.Request_Strike(FMars_Request_HandSwing_Start(utils_hand_swing::Make_ChopArc(), InImpactSeconds, InRecoverySeconds));
    }

    // Puts one sandbox item (Rock, Ration, Cog, Backpack, Cleaver, Tenderizer, Pan, Lantern, Tallow, Torch) into the local player's selected
    // hotbar slot, so a held item can be tested without finding one in the level.
    UFUNCTION(Exec)
    void Mars_Give(FString InItemName)
    {
        auto Character = TryGet_LocalCharacter("Mars_Give");
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
        else if (InItemName == "Lantern") { Definition = mars_items::Lantern(); }
        else if (InItemName == "Torch") { Definition = mars_items::Torch(); }
        else if (InItemName == "Tallow") { Definition = mars_items::Tallow(); }
        // Foods: the bench takes whole meat (MeatSlab); the batter station takes the whole fryables.
        else if (InItemName == "MeatSlab") { Definition = mars_items::Food_MeatSlab(); }
        else if (InItemName == "MushroomSlice") { Definition = mars_items::Food_MushroomSlice(); }
        else if (InItemName == "Drumstick") { Definition = mars_items::Food_Drumstick(); }
        else if (InItemName == "Tentacle") { Definition = mars_items::Food_Tentacle(); }
        else if (InItemName == "Puffer") { Definition = mars_items::Food_Puffer(); }
        else if (InItemName == "SpikedBerry") { Definition = mars_items::Food_SpikedBerry(); }
        else if (InItemName == "Mushroom") { Definition = mars_items::Food_Mushroom(); }

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
        auto Character = TryGet_LocalCharacter("Mars_Primary");
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
        auto Character = TryGet_LocalCharacter("Mars_SwingState");
        if (ck::Is_NOT_Valid(Character))
        { return; }

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

    // The local player takes the labelled station whose stand is nearest to them (within InRangeCm), by the reserve the Use
    // interaction ends in: a station can be worked from the console without walking up to it and looking at it.
    UFUNCTION(Exec)
    void Mars_Operate(float32 InRangeCm = 300.0f)
    {
        auto Character = TryGet_LocalCharacter("Mars_Operate");
        if (ck::Is_NOT_Valid(Character))
        { return; }

        auto Player = Character.TryGet_ActorEntityHandle();
        const auto Here = Character.GetActorLocation();
        auto Nearest = FCk_Handle_Station();
        auto NearestDistance = float64(InRangeCm);
        for (auto Label : utils_entity_tag::ForEach_Entity(Player, n"TAG_MarsStationLabel"))
        {
            // Every feed station's label hangs under its station.
            auto Owner = utils_entity_lifetime::Get_LifetimeOwner(Label);
            while (ck::IsValid(Owner) && utils_entity_lifetime::Get_IsTransientEntity(Owner) == false)
            {
                const auto Station = Owner.As_Station(ECk_SanityCheck::UnChecked);
                if (ck::IsValid(Station))
                {
                    const auto Distance = Station.Get_StandWorld().GetLocation().Distance(Here);
                    if (Distance < NearestDistance)
                    {
                        Nearest = Station;
                        NearestDistance = Distance;
                    }

                    break;
                }

                Owner = utils_entity_lifetime::Get_LifetimeOwner(Owner);
            }
        }

        if (ck::Is_NOT_Valid(Nearest))
        {
            ck::Trace(f"[Mars_Operate] no labelled station within {InRangeCm} cm");
            return;
        }

        Nearest.Request_Reserve(FMars_Request_Station_Reserve(Player));
    }

    // The steward nearest the local player (within InRangeCm) devours them: the fail scene, from the console.
    UFUNCTION(Exec)
    void Mars_Devour(float32 InRangeCm = 3000.0f)
    {
        auto Character = TryGet_LocalCharacter("Mars_Devour");
        if (ck::Is_NOT_Valid(Character))
        { return; }

        auto Player = Character.TryGet_ActorEntityHandle();
        const auto Here = Character.GetActorLocation();
        auto Nearest = FCk_Handle_Devour();
        auto NearestDistance = float64(InRangeCm);
        for (auto Steward : utils_entity_tag::ForEach_Entity(Player, constants_steward::k_EntityTag))
        {
            const auto Devour = Steward.As_Devour(ECk_SanityCheck::UnChecked);
            const auto Transform = Steward.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Devour) || ck::Is_NOT_Valid(Transform))
            { continue; }

            const auto Distance = utils_transform::Get_EntityCurrentLocation(Transform).Distance(Here);
            if (Distance < NearestDistance)
            {
                Nearest = Devour;
                NearestDistance = Distance;
            }
        }

        if (ck::Is_NOT_Valid(Nearest))
        {
            ck::Trace(f"[Mars_Devour] no steward within {InRangeCm} cm");
            return;
        }

        if (Nearest.Get_CanSeize(Player) == false)
        {
            ck::Trace("[Mars_Devour] the steward cannot seize the player now (it holds a victim, or the player is held)");
            return;
        }

        Nearest.Request_Begin(FMars_Request_Devour_Begin(Player));
    }

    // Bears down on (1) or lets up (0) the pestle of the mortar station the local player operates, as the station's control
    // does for the Primary key.
    UFUNCTION(Exec)
    void Mars_MortarPress(bool InPressed)
    {
        auto Mortar = TryGet_OperatedMortar("Mars_MortarPress");
        if (ck::Is_NOT_Valid(Mortar))
        { return; }

        if (InPressed)
        { Mortar.Request_Press(FMars_Request_Mortar_Press()); }
        else
        { Mortar.Request_Release(FMars_Request_Mortar_Release()); }
    }

    // Logs the Mortar ledger of the station the local player operates: the batch, the pestle and the timing window.
    UFUNCTION(Exec)
    void Mars_MortarState()
    {
        const auto Mortar = TryGet_OperatedMortar("Mars_MortarState");
        if (ck::Is_NOT_Valid(Mortar))
        { return; }

        const auto Batch = Mortar.Get_Batch();
        const auto Window = Mortar.Get_Window();
        ck::Trace(f"[Mars_MortarState] engaged [{Mortar.Get_IsEngaged()}] seasoning [{Batch.Seasoning :n}] stage [{Batch.Stage :n}] phase [{Batch.Phase :n}] hits [{Batch.CrushHits}] grind [{Batch.GrindProgress}] strike [{Mortar.Get_StrikePhase() :n}] pestle [{Mortar.Get_Pestle() :n}] window centre [{Window.Centre}] half width [{Window.HalfWidth}] marker [{Window.Marker}] progress [{Mortar.Get_Progress()}]");
    }

    // The local player's Mars character; null (and said so, as InCheat) when there is none.
    private AMars_PlayerCharacter TryGet_LocalCharacter(FString InCheat) const
    {
        auto Character = Cast<AMars_PlayerCharacter>(Gameplay::GetPlayerController(0).GetControlledPawn());
        if (ck::Is_NOT_Valid(Character))
        { ck::Trace(f"[{InCheat}] no local Mars player character"); }

        return Character;
    }

    // The Mortar of the station the local player operates; invalid (and said so, as InCheat) when there is none.
    private FCk_Handle_Mortar TryGet_OperatedMortar(FString InCheat) const
    {
        auto Character = TryGet_LocalCharacter(InCheat);
        if (ck::Is_NOT_Valid(Character))
        { return FCk_Handle_Mortar(); }

        auto Operator = Character.TryGet_ActorEntityHandle().As_Operator(ECk_SanityCheck::UnChecked);
        FCk_Handle Station = ck::IsValid(Operator) ? Operator.Get_Station() : FCk_Handle_Station();
        if (ck::Is_NOT_Valid(Station))
        {
            ck::Trace(f"[{InCheat}] the player operates no station");
            return FCk_Handle_Mortar();
        }

        const auto Mortar = Station.As_Mortar(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Mortar))
        { ck::Trace(f"[{InCheat}] the operated station has no Mortar"); }

        return Mortar;
    }
}
