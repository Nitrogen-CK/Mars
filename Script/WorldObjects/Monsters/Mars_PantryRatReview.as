// The Pantry Rat R01 court (Phase 4 review only: placed in /Game/ArtCandidates/PantryRat/R01/Review/PantryRat_R01_Court_MAP,
// never in a production map). One placed director at the map's origin composes the encounter exactly as the headless court
// rig does, in world space: the ground nav field over the court (auto-built), the PantryRaid (its bounds the court), one den
// at DenLocation facing +X, a World-mode backpack at PackLocation with the Mushroom (Persistent Food) in cargo slot 1 and a
// Monk's Rind in slot 2 (the two low, <= 48 cm pockets; a first rat's lease picks slot 1, so it snatches the Mushroom).
// The court's floor, walls and two obstacles are static meshes in the map (the CkJolt save hook bakes them).
//
// The chef is the real player character. The review driver (Review_* UFUNCTIONs, called from Python probes in PIE) runs a
// small chef bot on this director's tick that drives the player through the same requests its input handlers issue:
// movement = InputIntents SetMoveDirection (what the Move action's OnMove sends), view = utils_input_intents::Request_Look
// (what the Look action's OnLook sends), presses = the InteractionResolver's Primary / Use intents (what the
// IntentToResolver tasks and the Mars_Primary cheat send). The strike is therefore the player's real ItemUse Strike (windup,
// the viewpoint sphere sweep, recovery) with the real cleaver; the walk is CharacterMovement at its real MaxWalkSpeed.
// Every beat and press is logged ([PantryRatCourt]); the rat logs its own phases ([PantryRat]).

enum EMars_PantryRatCourt_BotMode
{
    Idle,
    WalkTo,
    Chase,
    PressUseAt
}

class UMars_PantryRatCourt_EntityScript : UCk_GenericEntityScript_UE
{
    default _ShowInPlaceActors = true;
    default _Replication = ECk_Replication::DoesNotReplicate;

    UPROPERTY()
    FBox CourtBounds = FBox(FVector(-1050.0, -750.0, -100.0), FVector(1050.0, 750.0, 300.0));

    UPROPERTY()
    FVector DenLocation = FVector(-950.0, 0.0, 0.0);

    // Phase 8: 50 cm nearer the den than Phase 4-7's (300, 0): the den's OutsideStand (-875, 0) is then 1125 cm away, inside the
    // 1200 cm scent range with the 30 cm arrival slack (at 300 it was 1175 + 30 = 1205: out of range, no emergence at all).
    UPROPERTY()
    FVector PackLocation = FVector(250.0, 0.0, 2.0);

    UPROPERTY()
    FVector SecondPackLocation = FVector(300.0, 450.0, 2.0);

    UPROPERTY()
    FVector FoodLocation = FVector(600.0, -450.0, 5.0);

    private FCk_Handle _Self;
    private FCk_Handle_GroundNavVolume _Volume;
    private FCk_Handle _RaidEntity;
    private FCk_Handle _DenEntity;
    private FCk_Handle _PackEntity;
    private FCk_Handle _FoodEntity;
    private FCk_Handle_Inventory_DataOnly _CheeseHolder;
    private FCk_Handle_Item _FoodItem;
    private FCk_Handle_Item _CheeseItem;
    private bool _Stowed = false;
    private bool _StowRequested = false;
    // The Monk's Rind's cargo slot: 2 (low, stealable) by default; Review_CheeseHigh puts it in slot 0 (above the rat's reach,
    // still arming the scent) so the Mushroom is the only eligible loot (Phase 7 carry proof).
    private int32 _CheeseSlot = 2;
    private float32 _Clock = 0.0f;

    // The chef bot.
    private EMars_PantryRatCourt_BotMode _Mode = EMars_PantryRatCourt_BotMode::Idle;
    private FVector _Goal = FVector::ZeroVector;
    private float32 _StopCm = 60.0f;
    private float32 _StrikeRangeCm = 95.0f;
    private float32 _LastPressAt = -10.0f;
    private bool _ReleasePrimary = false;
    private bool _ReleaseUse = false;
    private float32 _UsePressedAt = -10.0f;

    // How long a bot press holds its intent (a mouse click is ~0.1-0.2 s).
    UPROPERTY()
    float32 PressHoldSeconds = 0.2f;
    private int32 _Presses = 0;
    private TOptional<float32> _FirstOpportunityAt;
    private float32 _ChaseStartedAt = 0.0f;
    private float32 _YawGain = 1.0f;
    private float32 _PitchGain = -1.0f;
    private FVector _LastIntention = FVector::ZeroVector;
    private TOptional<FRotator> _LastView;
    private float32 _NextLogAt = 0.0f;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        InHandle.Request_OverrideToSelf();
        utils_handle::Set_DebugName(InHandle, n"PantryRatCourt");

        // Only a game world (PIE) gets the court; the editor world's placed copy composes nothing.
        const UWorld World = utils_entity_lifetime::Get_WorldForEntity(InHandle);
        if (ck::Is_NOT_Valid(World) || World.IsGameWorld() == false)
        { return ECk_EntityScript_ConstructionFlow::Finished; }

        utils_transform::Add(InHandle, FTransform::Identity, ECk_Replication::DoesNotReplicate);
        _Self = InHandle;

        auto VolumeOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        VolumeOwner.Request_OverrideToSelf();
        _Volume = utils_ground_nav_volume::Add(VolumeOwner, Make_CourtNavSpec());

        auto Spec = FMars_PantryRaid_Spec();
        Spec.EncounterBounds = CourtBounds;
        auto RaidParams = UMars_PantryRaid_EntityScript::Params();
        RaidParams.Spec = Spec;
        RaidParams.NavVolume = _Volume;
        _RaidEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_PantryRaid_EntityScript, RaidParams).Get_EntityUnderConstruction();

        auto DenParams = UMars_RatDen_EntityScript::Params();
        DenParams.SpawnTransform = FTransform(FRotator::ZeroRotator, DenLocation);
        DenParams.Spec = FMars_RatDen_Spec(Spec.Population.ResidentsPerDen);
        // Phase 5: the den's default shell (BlockAll + Ck.Jolt.NoBake) - no NoCollision override (F4-3 fixed in the den script).
        _DenEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_RatDen_EntityScript, DenParams).Get_EntityUnderConstruction();

        _PackEntity = Spawn_Pack(PackLocation);

        auto FoodParams = UMars_FoodItem_EntityScript::Params();
        FoodParams.SpawnTransform = FTransform(FRotator::ZeroRotator, FoodLocation);
        FoodParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_Mushroom());
        FoodParams.Mode = EMars_WorldItem_Mode::World;
        _FoodEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, FoodParams)
            .Get_EntityUnderConstruction();

        _CheeseHolder = Make_CheeseHolder(InHandle);

        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnTick"));
        Log(f"[PantryRatCourt] composed: den [{DenLocation.ToString()}], pack [{PackLocation.ToString()}], bounds [{CourtBounds.ToString()}]");
        return ECk_EntityScript_ConstructionFlow::Finished;
    }

    // The monster rooms' field (utils_surface_navigator::Make_NavFieldSpec) baked for a RAT-sized capsule (radius 20, half
    // height 22): the den's shell joins the static world in a rendered court, and the rooms' 80 cm crawler capsule finds no
    // surface under its 60 cm arch, so the rat's own portal and stands would be off the field.
    private FCk_GroundNavVolume_Spec Make_CourtNavSpec() const
    {
        auto Config = FCk_GroundNav_BakeConfig(25.0f, 10.0f);
        Config.Set_TileSizeUu(500.0f);
        auto Profile = FCk_GroundNav_AgentProfile(utils_shapes::Make_Capsule(FCk_ShapeCapsule_Dimensions(22.0f, 20.0f)));
        Profile.Set_LedgeSensitivity(0.0f);
        return FCk_GroundNavVolume_Spec(CourtBounds, Config, Profile);
    }

    private FCk_Handle Spawn_Pack(FVector InLocation)
    {
        auto PackParams = UMars_Backpack_EntityScript::Params();
        PackParams.Definition = mars_items::Backpack();
        PackParams.Mode = EMars_WorldItem_Mode::World;
        PackParams.SpawnTransform = FTransform(FRotator(0.0, 180.0, 0.0), InLocation);
        return utils_entity_script::Request_SpawnEntity(_Self, UMars_Backpack_EntityScript, PackParams).Get_EntityUnderConstruction();
    }

    private FCk_Handle_Inventory_DataOnly Make_CheeseHolder(FCk_Handle InHandle)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(), FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);
        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::MonksRind(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Tick: the stow once everything exists, then the chef bot
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnTick(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Clock += float32(InDeltaT.Get_Seconds());
        Try_Stow();
        Tick_Bot(float32(InDeltaT.Get_Seconds()));
    }

    private void Try_Stow()
    {
        if (_Stowed)
        { return; }

        if (ck::Is_NOT_Valid(_PackEntity) || _PackEntity.Is_Backpack() == false)
        { return; }

        const auto PackReady = ck::IsValid(_PackEntity) && _PackEntity.Is_Backpack() && _PackEntity.Is_WorldItem()
            && ck::IsValid(_PackEntity.As_WorldItem().Get_HeldItem());
        const auto FoodReady = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem() && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem())
            && _FoodEntity.As_WorldItem().Get_IsSettled() && _PackEntity.As_WorldItem().Get_IsSettled() && _Clock > 1.0f;
        auto Pack = _PackEntity.As_Backpack();
        if (_StowRequested == false)
        {
            if (PackReady == false || FoodReady == false || _CheeseHolder.Get_NumItems() != 1)
            { return; }

            _StowRequested = true;
            _FoodItem = _FoodEntity.As_WorldItem().Get_HeldItem();
            _CheeseItem = _CheeseHolder.Get_SoleItem();
            auto FoodSlot = Pack.Get_CargoSlot(1);
            auto CheeseSlot = Pack.Get_CargoSlot(_CheeseSlot);
            FoodSlot.Request_Stow(FMars_Request_CargoSlot_Stow(_FoodItem));
            CheeseSlot.Request_Stow(FMars_Request_CargoSlot_Stow(_CheeseItem));
            Log(f"[PantryRatCourt] stowing the Mushroom [{_FoodItem.ToString()}] in slot 1 and the Monk's Rind [{_CheeseItem.ToString()}] in slot [{_CheeseSlot}]");
            return;
        }

        if (Pack.Get_CargoSlot(1).Get_Item() == _FoodItem && Pack.Get_CargoSlot(_CheeseSlot).Get_Item() == _CheeseItem)
        {
            _Stowed = true;
            Log(f"[PantryRatCourt] stowed at t [{_Clock}]: pack [{_PackEntity.ToString()}] grounded [{_PackEntity.As_WorldItem().Get_Mount() :n}]");
        }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The chef bot
    //----------------------------------------------------------------------------------------------------------------------

    private AMars_PlayerCharacter Get_Character() const
    {
        auto Controller = Gameplay::GetPlayerController(0);
        return ck::IsValid(Controller) ? Cast<AMars_PlayerCharacter>(Controller.GetControlledPawn()) : nullptr;
    }

    private FCk_Handle Get_Player() const
    {
        auto Character = Get_Character();
        return ck::IsValid(Character) ? Character.TryGet_ActorEntityHandle() : FCk_Handle();
    }

    private bool Get_View(FTransform& OutView) const
    {
        auto Player = Get_Player();
        if (ck::Is_NOT_Valid(Player) || Player.Is_PlayerViewpoint() == false)
        { return false; }

        OutView = utils_transform::Get_EntityCurrentTransform(Player.As_PlayerViewpoint().Get_Viewpoint());
        return true;
    }

    private void Set_Move(FVector InDirection)
    {
        auto Player = Get_Player();
        auto Intents = ck::IsValid(Player) ? Player.As_InputIntents(ECk_SanityCheck::UnChecked) : FCk_Handle_InputIntents();
        if (ck::IsValid(Intents))
        { Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(InDirection)); }
    }

    // The intent stays open until the press is released; meanwhile its best target is started the way the player's
    // IntentToResolver task does it (OnBestTargetsChanged -> Forward_To: InteractTarget.Request_StartInteraction(player,
    // player)). Opening the resolver intent alone starts nothing.
    private TOptional<FGameplayTag> _ForwardIntent;

    private void Tick_Forward()
    {
        if (_ForwardIntent.IsSet() == false)
        { return; }

        auto Player = Get_Player();
        auto Resolver = ck::IsValid(Player) ? Player.As_InteractionResolver(ECk_SanityCheck::UnChecked) : FCk_Handle_InteractionResolver();
        if (ck::Is_NOT_Valid(Resolver))
        { return; }

        auto Targets = Resolver.Get_BestInteractTargets(_ForwardIntent.GetValue());
        if (Targets.Num() == 0 || ck::Is_NOT_Valid(Targets[0]))
        { return; }

        auto Target = Targets[0];
        Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(Player, Player));
        Log(f"[PantryRatCourt] started the [{_ForwardIntent.GetValue().ToString()}] interaction on [{Target.ToString()}] t [{_Clock}]");
        _ForwardIntent.Reset();
    }

    private void Press(FGameplayTag InIntent, bool InPressed)
    {
        auto Player = Get_Player();
        auto Resolver = ck::IsValid(Player) ? Player.As_InteractionResolver(ECk_SanityCheck::UnChecked) : FCk_Handle_InteractionResolver();
        if (ck::Is_NOT_Valid(Resolver))
        { return; }

        if (InPressed)
        {
            Resolver.Request_StartIntent(FCk_Request_InteractionResolver_StartIntent(InIntent));
            _ForwardIntent = InIntent;
        }
        else
        {
            _ForwardIntent.Reset();
            Resolver.Request_StopIntent(FCk_Request_InteractionResolver_StopIntent(InIntent));
        }
    }

    // Turns the view toward InTarget through the Look intention (a closed loop: the gain per intention unit is measured from
    // the last frame's response, sign included). Returns the remaining yaw / pitch error in degrees.
    private FVector2D Steer_View(FVector InTarget)
    {
        auto View = FTransform::Identity;
        if (Get_View(View) == false)
        { return FVector2D(180.0, 90.0); }

        const auto Rotation = View.Rotator();
        if (_LastView.IsSet())
        {
            const auto DeltaYaw = Math::FindDeltaAngleDegrees(_LastView.GetValue().Yaw, Rotation.Yaw);
            const auto DeltaPitch = Rotation.Pitch - _LastView.GetValue().Pitch;
            if (Math::Abs(_LastIntention.X) > 0.05f && Math::Abs(DeltaYaw) > 0.01)
            { _YawGain = Math::Clamp(float32(Math::Lerp(_YawGain, float32(DeltaYaw / _LastIntention.X), 0.3f)), -60.0f, 60.0f); }
            if (Math::Abs(_LastIntention.Y) > 0.05f && Math::Abs(DeltaPitch) > 0.01)
            { _PitchGain = Math::Clamp(float32(Math::Lerp(_PitchGain, float32(DeltaPitch / _LastIntention.Y), 0.3f)), -60.0f, 60.0f); }
        }
        _LastView = Rotation;

        const auto ToTarget = InTarget - View.GetLocation();
        const auto WantYaw = Math::RadiansToDegrees(Math::Atan2(ToTarget.Y, ToTarget.X));
        const auto WantPitch = Math::RadiansToDegrees(Math::Atan2(ToTarget.Z, ToTarget.Size2D()));
        const auto YawError = float32(Math::FindDeltaAngleDegrees(Rotation.Yaw, WantYaw));
        const auto PitchError = float32(WantPitch - Rotation.Pitch);

        auto Intention = FVector::ZeroVector;
        if (Math::Abs(_YawGain) > 0.1f)
        { Intention.X = Math::Clamp(0.5f * YawError / _YawGain, -6.0f, 6.0f); }
        if (Math::Abs(_PitchGain) > 0.1f)
        { Intention.Y = Math::Clamp(0.5f * PitchError / _PitchGain, -6.0f, 6.0f); }

        auto Player = Get_Player();
        if (ck::IsValid(Player) && (Math::Abs(Intention.X) > 0.001 || Math::Abs(Intention.Y) > 0.001))
        { utils_input_intents::Request_Look(Player, Intention); }
        _LastIntention = Intention;
        return FVector2D(YawError, PitchError);
    }

    private void Tick_Bot(float32 InDeltaT)
    {
        Tick_Forward();

        // A press is held PressHoldSeconds (a click), then released.
        if (_ReleasePrimary && _Clock - _LastPressAt >= PressHoldSeconds)
        {
            _ReleasePrimary = false;
            Log_StrikeState();
            Press(GameplayTags::InteractionIntent_Mars_Primary, false);
        }

        if (_ReleaseUse && _Clock - _UsePressedAt >= PressHoldSeconds)
        {
            _ReleaseUse = false;
            Press(GameplayTags::InteractionIntent_Mars_Use, false);
        }

        auto Character = Get_Character();
        if (ck::Is_NOT_Valid(Character) || _Mode == EMars_PantryRatCourt_BotMode::Idle)
        { return; }

        const auto Here = Character.GetActorLocation();
        if (_Mode == EMars_PantryRatCourt_BotMode::WalkTo)
        {
            const auto Error = Steer_View(FVector(_Goal.X, _Goal.Y, Here.Z + 60.0));
            const auto Distance = (_Goal - Here).Size2D();
            if (Distance <= _StopCm)
            {
                Set_Move(FVector::ZeroVector);
                _Mode = EMars_PantryRatCourt_BotMode::Idle;
                Log(f"[PantryRatCourt] bot arrived at [{_Goal.ToString()}] t [{_Clock}] (distance [{Distance}])");
                return;
            }

            Set_Move(Math::Abs(Error.X) < 35.0 ? FVector(1.0, 0.0, 0.0) : FVector::ZeroVector);
            return;
        }

        if (_Mode == EMars_PantryRatCourt_BotMode::PressUseAt)
        {
            Set_Move(FVector::ZeroVector);
            const auto Error = Steer_View(_Goal);
            if (Math::Abs(Error.X) < 3.0 && Math::Abs(Error.Y) < 3.0)
            {
                Press(GameplayTags::InteractionIntent_Mars_Use, true);
                _ReleaseUse = true;
                _UsePressedAt = _Clock;
                _Mode = EMars_PantryRatCourt_BotMode::Idle;
                Log(f"[PantryRatCourt] bot pressed Use at [{_Goal.ToString()}] t [{_Clock}]");
            }
            return;
        }

        // Chase: walk at the first live rat, look at its body, strike when it is inside the swing.
        auto Rat = Get_LiveRat();
        if (ck::Is_NOT_Valid(Rat) || Rat.Get_IsDead())
        {
            Set_Move(FVector::ZeroVector);
            _Mode = EMars_PantryRatCourt_BotMode::Idle;
            const auto Last = ck::IsValid(Rat) ? Rat.Get_Phase() : EMars_PantryRat_Phase::Destroyed;
            Log(f"[PantryRatCourt] bot chase over t [{_Clock}]: presses [{_Presses}], rat [{Last :n}]");
            return;
        }

        const auto RatLocation = Rat.Get_Location();
        const auto Error = Steer_View(RatLocation);
        const auto Distance = (RatLocation - Here).Size2D();
        Set_Move(Distance > _StrikeRangeCm * 0.6 && Math::Abs(Error.X) < 50.0 ? FVector(1.0, 0.0, 0.0) : FVector::ZeroVector);

        const auto InSwing = Distance <= _StrikeRangeCm && Math::Abs(Error.X) < 12.0 && Math::Abs(Error.Y) < 12.0;
        if (InSwing && _FirstOpportunityAt.IsSet() == false)
        {
            _FirstOpportunityAt = _Clock - _ChaseStartedAt;
            Log(f"[PantryRatCourt] first strike opportunity [{_FirstOpportunityAt.GetValue()}] s into the chase, distance [{Distance}], rat [{Rat.Get_Phase() :n}]");
        }

        if (InSwing && _Clock - _LastPressAt >= 0.6f)
        {
            _LastPressAt = _Clock;
            ++_Presses;
            Press(GameplayTags::InteractionIntent_Mars_Primary, true);
            _ReleasePrimary = true;
            Log(f"[PantryRatCourt] strike press #{_Presses} t [{_Clock}] distance [{Distance}] yaw err [{Error.X}] pitch err [{Error.Y}] rat [{Rat.Get_Phase() :n}] at [{RatLocation.ToString()}]");
            Log_StrikeState();
        }

        if (_Clock >= _NextLogAt)
        {
            _NextLogAt = _Clock + 0.5f;
            Log(f"[PantryRatCourt] chase t [{_Clock - _ChaseStartedAt}] chef [{Here.ToString()}] rat [{RatLocation.ToString()}] distance [{Distance}] rat phase [{Rat.Get_Phase() :n}] speed [{Character.CharacterMovement.Velocity.Size2D()}]");
        }
    }

    private bool _DealerBound = false;

    // What the press reaches: the held item and its Strike, the use interactable, the swing and the dealer's tally.
    private void Log_StrikeState()
    {
        auto Player = Get_Player();
        if (ck::Is_NOT_Valid(Player))
        { return; }

        auto Held = Player.As_HeldItem(ECk_SanityCheck::UnChecked);
        auto Item = ck::IsValid(Held) ? Held.Get_CurrentItem() : FCk_Handle_Item();
        const auto HasStrike = ck::IsValid(Item) && Item.Has_Strike();
        const auto UseValid = Player.Has_Fragment(FMars_Fragment_HeldItemUse) && ck::IsValid(Player.Get_Fragment(FMars_Fragment_HeldItemUse).CurrentInteractable);
        auto Swing = Player.As_HandSwing(ECk_SanityCheck::UnChecked);
        auto Dealer = Player.As_DamageDealer(ECk_SanityCheck::UnChecked);
        const auto SwingPhase = ck::IsValid(Swing) ? f"{Swing.Get_Phase() :n}" : "none";
        const auto Dealt = ck::IsValid(Dealer) ? Dealer.Get_HitsDealt() : -1;
        const auto Rejected = ck::IsValid(Dealer) ? Dealer.Get_HitsRejected() : -1;
        auto View = FTransform::Identity;
        Get_View(View);
        auto Resolver = Player.As_InteractionResolver(ECk_SanityCheck::UnChecked);
        const auto BestPrimary = ck::IsValid(Resolver) ? Resolver.Get_BestInteractTargets(GameplayTags::InteractionIntent_Mars_Primary).Num() : -1;
        Log(f"[PantryRatCourt] strike state: best primary targets [{BestPrimary}] held [{Item.ToString()}] strike [{HasStrike}] use interactable [{UseValid}] swing [{SwingPhase}] "
            + f"dealt [{Dealt}] rejected [{Rejected}] view [{View.GetLocation().ToString()}] pitch [{View.Rotator().Pitch}]");

        if (_DealerBound == false && ck::IsValid(Dealer))
        {
            _DealerBound = true;
            Dealer.BindTo_OnDamageDealt(FMars_Delegate_DamageDealer_OnDamageDealt(this, n"OnDealt"));
            Dealer.BindTo_OnDamageRejected(FMars_Delegate_DamageDealer_OnDamageRejected(this, n"OnRejected"));
        }
    }

    UFUNCTION()
    private void OnDealt(FCk_Handle_DamageDealer InDealer, FCk_Handle_HitZone InZone, FMars_DamageEvent InEvent)
    {
        Log(f"[PantryRatCourt] the chef's strike was DEALT to zone [{InZone.ToString()}] amount [{InEvent.Amount}] causer [{InEvent.Source.Causer.ToString()}] t [{_Clock}]");
    }

    UFUNCTION()
    private void OnRejected(FCk_Handle_DamageDealer InDealer, FCk_Handle InHit, EMars_DamageDealer_RejectReason InReason)
    {
        Log(f"[PantryRatCourt] the chef's strike was REJECTED on [{InHit.ToString()}] reason [{InReason :n}] t [{_Clock}]");
    }

    // The story's rat: the one chased once a chase began (until it is gone), else the Mushroom's thief, else the first
    // loaded rat, else the first live one.
    private FCk_Handle _StoryRat;
    private bool _Pinned = false;

    private FCk_Handle_PantryRat Get_LiveRat() const
    {
        auto Pinned = _StoryRat.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Pinned) && Pinned.Get_Phase() != EMars_PantryRat_Phase::Destroyed)
        { return Pinned; }

        if (_Pinned)
        { return FCk_Handle_PantryRat(); }

        auto Raid = _RaidEntity.As_PantryRaid(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Raid))
        { return FCk_Handle_PantryRat(); }

        auto First = FCk_Handle_PantryRat();
        auto Loaded = FCk_Handle_PantryRat();
        for (const auto& Record : Raid.Get_Rats())
        {
            auto Rat = Record.Rat.As_PantryRat(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Rat) || Rat.Get_Phase() == EMars_PantryRat_Phase::Destroyed)
            { continue; }

            if (ck::IsValid(_FoodItem) && Rat.Get_Loot() == _FoodItem)
            { return Rat; }

            if (ck::Is_NOT_Valid(Loaded) && Rat.Get_IsLoaded())
            { Loaded = Rat; }

            if (ck::Is_NOT_Valid(First))
            { First = Rat; }
        }

        return ck::IsValid(Loaded) ? Loaded : First;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Review surface (Python, PIE)
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    void Review_GiveCleaver()
    {
        auto Player = Get_Player();
        auto Hotbar = ck::IsValid(Player) ? Player.As_Hotbar(ECk_SanityCheck::UnChecked) : FCk_Handle_Hotbar();
        if (ck::Is_NOT_Valid(Hotbar))
        {
            Log("[PantryRatCourt] no player hotbar for the cleaver");
            return;
        }

        auto Index = Hotbar.Get_SelectedIndex();
        if (Index.IsSet() == false)
        { Index = Hotbar.TryGet_FirstEmptyBagSlot(); }

        if (Index.IsSet() == false)
        { return; }

        auto Slot = Hotbar.Get_Slot(Index.GetValue());
        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Cleaver(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Slot.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        Hotbar.Request_Select(FMars_Request_Hotbar_Select(Index.GetValue()));
        Log(f"[PantryRatCourt] cleaver into hotbar slot [{Index.GetValue()}] (Mars_Give's path) t [{_Clock}]");
    }

    // The held weapon's real Strike values and the chef's real walk speed, as the game reads them now.
    UFUNCTION()
    FString Review_LogWeapon()
    {
        auto Character = Get_Character();
        auto Player = Get_Player();
        auto Held = ck::IsValid(Player) ? Player.As_HeldItem(ECk_SanityCheck::UnChecked) : FCk_Handle_HeldItem();
        auto Item = ck::IsValid(Held) ? Held.Get_CurrentItem() : FCk_Handle_Item();
        const auto WalkSpeed = ck::IsValid(Character) ? Character.CharacterMovement.MaxWalkSpeed : -1.0f;
        auto Text = f"chef MaxWalkSpeed [{WalkSpeed}]";
        if (ck::IsValid(Item) && Item.Has_Strike())
        {
            const UMars_ItemTrait_Strike Strike = Item.Get_Strike();
            Text += f" held [{Item.ToString()}] Strike damage [{Strike.Damage}] reach [{Strike.Reach}] radius [{Strike.Radius}] "
                + f"windup [{Strike.WindupSeconds}] recovery [{Strike.RecoverySeconds}] impulse [{Strike.ImpulseSpeed}]";
        }
        else
        { Text += " held item has no Strike"; }

        Log(f"[PantryRatCourt] weapon {Text}");
        return Text;
    }

    UFUNCTION()
    void Review_BotWalkTo(FVector InGoal, float32 InStopCm)
    {
        _Goal = InGoal;
        _StopCm = InStopCm;
        _Mode = EMars_PantryRatCourt_BotMode::WalkTo;
        Log(f"[PantryRatCourt] bot walk to [{InGoal.ToString()}] stop [{InStopCm}] t [{_Clock}]");
    }

    UFUNCTION()
    void Review_BotChase(float32 InStrikeRangeCm)
    {
        _StrikeRangeCm = InStrikeRangeCm;
        _Mode = EMars_PantryRatCourt_BotMode::Chase;
        _ChaseStartedAt = _Clock;
        _StoryRat = FCk_Handle();
        _Pinned = false;
        _StoryRat = Get_LiveRat();
        _Pinned = ck::IsValid(_StoryRat);
        auto Chased = _StoryRat.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Chased))
        { Log(f"[PantryRatCourt] chasing [{_StoryRat.ToString()}] op [{Chased.Get_Links().OperationId}] loot [{Chased.Get_Loot().ToString()}]"); }
        _FirstOpportunityAt.Reset();
        _Presses = 0;
        Log(f"[PantryRatCourt] bot chase starts t [{_Clock}] strike range [{InStrikeRangeCm}]");
    }

    UFUNCTION()
    void Review_BotPressUseAt(FVector InPoint)
    {
        _Goal = InPoint;
        _Mode = EMars_PantryRatCourt_BotMode::PressUseAt;
        Log(f"[PantryRatCourt] bot looks at [{InPoint.ToString()}] to press Use t [{_Clock}]");
    }

    UFUNCTION()
    void Review_BotStop()
    {
        _Mode = EMars_PantryRatCourt_BotMode::Idle;
        Set_Move(FVector::ZeroVector);
    }

    UFUNCTION()
    FString Review_BotMode() const
    {
        return f"{_Mode :n}";
    }

    // The composed director (PIE can also hold an entity-less copy of this class).
    UFUNCTION()
    bool Review_IsComposed() const
    {
        return ck::IsValid(_RaidEntity);
    }

    // The first live rat's phase name, "none" without one.
    UFUNCTION()
    FString Review_RatPhase() const
    {
        auto Rat = Get_LiveRat();
        return ck::IsValid(Rat) ? f"{Rat.Get_Phase() :n}" : "none";
    }

    // The story rat carries the court's Mushroom.
    UFUNCTION()
    bool Review_RatHasMushroom() const
    {
        auto Rat = Get_LiveRat();
        return ck::IsValid(Rat) && ck::IsValid(_FoodItem) && Rat.Get_Loot() == _FoodItem;
    }

    // The pack is stowed and the raid is ready.
    UFUNCTION()
    bool Review_IsReady() const
    {
        auto Raid = _RaidEntity.As_PantryRaid(ECk_SanityCheck::UnChecked);
        return _Stowed && ck::IsValid(Raid) && Raid.Get_IsReady();
    }

    UFUNCTION()
    FVector Review_RatLocation() const
    {
        auto Rat = Get_LiveRat();
        return ck::IsValid(Rat) ? Rat.Get_Location() : FVector::ZeroVector;
    }

    // The first live rat's root yaw (degrees) and FadeAlpha, for the Phase 5 rat-relative close-up framing.
    UFUNCTION()
    float32 Review_RatYaw() const
    {
        auto Rat = Get_LiveRat();
        return ck::IsValid(Rat) ? float32(utils_transform::Get_EntityCurrentTransform(Rat.As_Transform()).Rotator().Yaw) : 0.0f;
    }

    // Phase 7: before the stow (the first second), the Rind goes to the high slot 0 instead of slot 2.
    UFUNCTION()
    void Review_CheeseHigh()
    {
        if (_StowRequested == false)
        { _CheeseSlot = 0; }

        Log(f"[PantryRatCourt] cheese slot [{_CheeseSlot}] (stow requested [{_StowRequested}]) t [{_Clock}]");
    }

    // Phase 6 eye-strength sweep: every live rat's eyes at InStrength (the assembly's own style request).
    UFUNCTION()
    void Review_SetRatEyeStrength(float32 InStrength)
    {
        auto Raid = _RaidEntity.As_PantryRaid(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Raid))
        { return; }

        for (const auto& Record : Raid.Get_Rats())
        {
            FCk_Handle RatEntity = Record.Rat;
            if (ck::Is_NOT_Valid(RatEntity) || RatEntity.Has_Fragment(FMars_Fragment_PantryRat_Assembly) == false)
            { continue; }

            auto Script = RatEntity.Get_Fragment(FMars_Fragment_PantryRat_Assembly).Script.Get();
            if (ck::IsValid(Script))
            { Script.Review_SetEyeStrength(InStrength); }
        }

        Log(f"[PantryRatCourt] rat eye strength [{InStrength}] t [{_Clock}]");
    }

    UFUNCTION()
    float32 Review_RatFade() const
    {
        auto Rat = Get_LiveRat();
        return ck::IsValid(Rat) ? Rat.Get_FadeAlpha() : 1.0f;
    }

    UFUNCTION()
    FVector Review_FoodLocation() const
    {
        return ck::IsValid(_FoodEntity) ? utils_transform::Get_EntityCurrentLocation(_FoodEntity.As_Transform()) : FVector::ZeroVector;
    }

    UFUNCTION()
    FVector Review_PackLocation() const
    {
        return ck::IsValid(_PackEntity) ? utils_transform::Get_EntityCurrentLocation(_PackEntity.As_Transform()) : FVector::ZeroVector;
    }

    UFUNCTION()
    FVector Review_ChefLocation() const
    {
        auto Character = Get_Character();
        return ck::IsValid(Character) ? Character.GetActorLocation() : FVector::ZeroVector;
    }

    UFUNCTION()
    void Review_SpawnSecondPack()
    {
        _PackEntity = Spawn_Pack(SecondPackLocation);
        _CheeseHolder = Make_CheeseHolder(_Self);
        _Stowed = false;
        _StowRequested = false;
        _StoryRat = FCk_Handle();
        _Pinned = false;
        auto FoodParams = UMars_FoodItem_EntityScript::Params();
        FoodParams.SpawnTransform = FTransform(FRotator::ZeroRotator, SecondPackLocation + FVector(150.0, 0.0, 5.0));
        FoodParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_Mushroom());
        FoodParams.Mode = EMars_WorldItem_Mode::World;
        _FoodEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, FoodParams)
            .Get_EntityUnderConstruction();
        Log(f"[PantryRatCourt] a second cheese pack at [{SecondPackLocation.ToString()}] t [{_Clock}]");
    }

    // One line for the log and the probe: the raid, every rat, the den's eyes, the pack and the Mushroom.
    UFUNCTION()
    FString Review_Describe()
    {
        auto Text = f"t [{_Clock}] stowed [{_Stowed}] bot [{_Mode :n}] presses [{_Presses}]";
        auto Raid = _RaidEntity.As_PantryRaid(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Raid))
        {
            Text += f" raid ready [{Raid.Get_IsReady()}] leases [{Raid.Get_LeasesGranted()}]";
            for (const auto& Record : Raid.Get_Rats())
            {
                auto Rat = Record.Rat.As_PantryRat(ECk_SanityCheck::UnChecked);
                if (ck::Is_NOT_Valid(Rat))
                { continue; }

                Text += f" | rat [{Record.Rat.ToString()}] op [{Record.OperationId}] {Rat.Get_Phase() :n} loot [{Rat.Get_Loot().ToString()}] "
                    + f"fade [{Rat.Get_FadeAlpha()}] hidden [{Rat.Get_IsHidden()}] at [{Rat.Get_Location().ToString()}]";
            }
        }

        auto Den = _DenEntity.As_RatDen(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Den))
        { Text += f" | den eyes [{Den.Get_EyesShown()}] slot0 [{Den.Get_SlotState(0) :n}]"; }

        if (_PackEntity.Is_WorldItem())
        { Text += f" | pack [{_PackEntity.As_WorldItem().Get_Mount() :n}] at [{Review_PackLocation().ToString()}]"; }

        if (ck::IsValid(_FoodItem) && _FoodEntity.Is_WorldItem())
        {
            const auto Food = _FoodEntity.As_WorldItem();
            Text += f" | mushroom item [{_FoodItem.ToString()}] parent [{_FoodItem.Get_ParentInventory().ToString()}] mount [{Food.Get_Mount() :n}] "
                + f"carrier [{Food.Get_Carrier().ToString()}] at [{Review_FoodLocation().ToString()}]";
        }

        Log(f"[PantryRatCourt] describe {Text}");
        return Text;
    }
}
