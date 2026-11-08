// A one-slot holder accept policy the rat tests use as an unmarked inventory (no mounting, accepts anything).
class UMars_AutoTestHelper_PantryRaid_OpenHolder : UObject
{
    UFUNCTION()
    void OnCanAccept(FCk_Handle_Inventory InInventory, FCk_Handle_Item InItem, bool& OutCanAccept)
    { OutCanAccept = true; }
}

// The pantry-raid court, headless: a static Jolt floor (3000 x 3000, top at _Origin.Z) and the GroundNav field over it (+-600,
// built on request, UMars_AutoTestRig_GroundNavBuildOutcome), a PantryRaid entity at _Origin whose bounds cover the field
// (+-560), one RatDen at k_DenOffset facing +X (toward the pack), a World-mode backpack at k_PackOffset, a Monk's Rind (the
// cheese, Transient) and a Mushroom (Persistent Food) stowed into the two low pockets (cargo slots 1 and 2, 37.5 cm: Phase 1
// reach), and chef stand-ins (a root, a Hotbar, TAG_MarsCombatTarget) moved by setting their transforms. Each test sets its
// own _Origin band and may tune _Spec before Arrange_Court.
UCLASS(Abstract)
class UMars_AutoTestRig_PantryRaid : UMars_AutoTestRig_GroundNavBuildOutcome
{
    default _TimeoutSeconds = 60.0f;

    protected const FVector k_DenOffset = FVector(-400.0, 0.0, 0.0);
    protected const FVector k_PackOffset = FVector(250.0, 0.0, 0.0);
    protected const FVector k_FoodOffset = FVector(150.0, 350.0, 0.0);
    // Where a chef stand-in waits when it is not part of the scene (observed, far from everything).
    protected const FVector k_ChefAway = FVector(0.0, 1400.0, 0.0);
    // Long walks and the food's construction outrun the default poll budget.
    protected const int32 k_LongPolls = 4000;

    protected FMars_PantryRaid_Spec _Spec;
    protected bool _BuildField = true;
    // Mushroom into slot 1 and the cheese into slot 2 (default: cheese 1, Mushroom 2). A rat's first lease picks slot 1.
    protected bool _MushroomFirst = false;

    protected FCk_Handle _RaidEntity;
    protected FCk_Handle _DenEntity;
    protected FCk_Handle _PackEntity;
    protected FCk_Handle _FoodEntity;
    protected FCk_Handle_PantryRaid _Raid;
    protected FCk_Handle_RatDen _Den;
    protected FCk_Handle_WorldItem _Pack;
    protected FCk_Handle_WorldItem _Food;
    protected FCk_Handle_Item _FoodItem;
    protected FCk_Handle_Item _CheeseItem;
    protected FCk_Handle_Inventory_DataOnly _CheeseHolder;
    protected TArray<FCk_Handle> _Chefs;
    protected TArray<FCk_Handle> _OwnedExtra;
    // The cleaver a chef strikes with (Strike trait), seeded on first use.
    protected FCk_Handle_Inventory_DataOnly _WeaponHolder;

    // A default spec for the court: the shipped tuning with a short scent arm and emergence spacing so the tests reach the
    // part they verify sooner.
    protected FMars_PantryRaid_Spec Make_CourtSpec() const
    {
        auto Spec = FMars_PantryRaid_Spec();
        Spec.EncounterBounds = FBox(FVector(-560.0, -560.0, -100.0), FVector(560.0, 560.0, 200.0));
        Spec.Scent.GroundArmSeconds = 0.5f;
        Spec.Population.EmergeSpacingSeconds = 0.5f;
        return Spec;
    }

    // Floor, field, raid, den, pack, food, cheese holder and InChefCount chef stand-ins (all at k_ChefAway, spread on X).
    protected void Arrange_Court(FCk_Handle InHandle, int32 InChefCount)
    {
        Arrange(InHandle);

        auto RaidParams = UMars_PantryRaid_EntityScript::Params();
        RaidParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin);
        RaidParams.Spec = _Spec;
        RaidParams.NavVolume = _Volume;
        _RaidEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_PantryRaid_EntityScript, RaidParams).Get_EntityUnderConstruction();

        auto DenParams = UMars_RatDen_EntityScript::Params();
        DenParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + k_DenOffset);
        DenParams.Spec = FMars_RatDen_Spec(_Spec.Population.ResidentsPerDen);
        _DenEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_RatDen_EntityScript, DenParams).Get_EntityUnderConstruction();

        auto PackParams = UMars_Backpack_EntityScript::Params();
        PackParams.Definition = mars_items::Backpack();
        PackParams.Mode = EMars_WorldItem_Mode::World;
        PackParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + k_PackOffset + FVector(0.0, 0.0, 2.0));
        _PackEntity = utils_entity_script::Request_SpawnEntity(InHandle, UMars_Backpack_EntityScript, PackParams).Get_EntityUnderConstruction();

        auto FoodParams = UMars_FoodItem_EntityScript::Params();
        FoodParams.SpawnTransform = FTransform(FRotator::ZeroRotator, _Origin + k_FoodOffset + FVector(0.0, 0.0, 5.0));
        FoodParams.Definition = utils_held_item::Make_DefinitionSoft(mars_items::Food_Mushroom());
        FoodParams.Mode = EMars_WorldItem_Mode::World;
        _FoodEntity = utils_entity_script::Request_SpawnEntity(ck::TransientEntity(), UMars_FoodItem_EntityScript, FoodParams)
            .Get_EntityUnderConstruction();
        Track_ForCleanup(_FoodEntity);

        _CheeseHolder = Make_SeededHolder(InHandle, mars_items::MonksRind());

        for (int32 Index = 0; Index < InChefCount; ++Index)
        { _Chefs.Add(Make_Chef(InHandle, _Origin + k_ChefAway + FVector(200.0 * Index, 0.0, 0.0))); }
    }

    // The court's opening steps: the floor joins Jolt, the field builds (unless _BuildField is off), everything is
    // constructed, then the cheese and the Mushroom are stowed and settled in slots 1 and 2.
    protected void Add_CourtSteps()
    {
        Add_Step_WaitUntil("the court floor joined Jolt", n"Check_FloorReady", k_SlowPolls, 0);
        Add_Step("request the court's nav field build", n"Step_BuildField");
        Add_Step_WaitUntil("raid, den, pack, Mushroom and cheese are constructed", n"Check_CourtConstructed", k_LongPolls, 0);
        Add_Step("stow the cheese and the Mushroom into the low pockets", n"Step_StowCourt");
        Add_Step_WaitUntil("both low pockets hold their items, the Mushroom settled on its slot", n"Check_CourtStowed", k_LongPolls, 0);
    }

    protected FCk_Handle Make_Chef(FCk_Handle InHandle, FVector InLocation)
    {
        auto Chef = utils_entity_lifetime::Request_CreateEntity(InHandle);
        utils_transform::Add(Chef, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 1;
        utils_hotbar::Add(Chef, Spec);
        utils_entity_tag::Add(Chef, n"TAG_MarsCombatTarget");
        utils_handle::Set_DebugName(Chef, n"PantryRaidTest.Chef");
        _OwnedExtra.Add(Chef);
        return Chef;
    }

    protected FCk_Handle_Inventory_DataOnly Make_SeededHolder(FCk_Handle InHandle, UCk_InventoryItem_Definition InDefinition)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _OwnedExtra.Add(HolderOwner);
        auto Params = utils_inventory_data_only::Make_Params_Bounded(GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(), FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        auto Holder = utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);

        auto Request = FCk_Request_Inventory_AddItemByDefinition(InDefinition, 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
        return Holder;
    }

    // An empty one-slot holder that accepts anything and mounts nothing.
    protected FCk_Handle_Inventory_DataOnly Make_OpenHolder(FCk_Handle InHandle)
    {
        auto HolderOwner = utils_entity_lifetime::Request_CreateEntity(InHandle);
        _OwnedExtra.Add(HolderOwner);
        TSubclassOf<UMars_AutoTestHelper_PantryRaid_OpenHolder> PolicyClass = UMars_AutoTestHelper_PantryRaid_OpenHolder;
        auto Params = utils_inventory_data_only::Make_Params_Bounded(GameplayTags::Inventory_Mars_WorldItemHolder, 1,
            FCk_Delegate_Inventory_CustomCanAcceptItem_Dynamic(PolicyClass.GetDefaultObject(), n"OnCanAccept"),
            FCk_Delegate_Inventory_CustomCanStackItems_Dynamic());
        return utils_inventory_data_only::Add(HolderOwner, Params, ECk_Replication::DoesNotReplicate);
    }

    protected void Move_Chef(int32 InIndex, FVector InLocation)
    {
        auto Chef = _Chefs[InIndex].As_Transform();
        utils_transform::Request_SetLocation(Chef, FCk_Request_Transform_SetLocation(InLocation));
    }

    protected FVector Get_ChefLocation(int32 InIndex) const
    {
        return utils_transform::Get_EntityCurrentLocation(_Chefs[InIndex].As_Transform());
    }

    // A point InDistance from the pack's root on the side away from the den (planar).
    protected FVector Get_PackSide(float64 InDistance) const
    {
        return _Origin + k_PackOffset + FVector(InDistance, 0.0, 0.0);
    }

    protected FCk_Handle_CargoSlot Get_Slot(int32 InIndex) const
    {
        return _PackEntity.As_Backpack().Get_CargoSlot(InIndex);
    }

    // Every rat the raid owns, constructed (as typed handles).
    protected TArray<FCk_Handle_PantryRat> Get_Rats() const
    {
        auto Rats = TArray<FCk_Handle_PantryRat>();
        if (ck::Is_NOT_Valid(_Raid))
        { return Rats; }

        for (const auto& Record : _Raid.Get_Rats())
        {
            auto Rat = Record.Rat.As_PantryRat(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Rat))
            { Rats.Add(Rat); }
        }

        return Rats;
    }

    protected FCk_Handle_PantryRat Get_FirstRat() const
    {
        const auto Rats = Get_Rats();
        return Rats.Num() > 0 ? Rats[0] : FCk_Handle_PantryRat();
    }

    // Items in the two low pockets plus every rat pocket (the court's ingredient count).
    protected int32 Count_CourtItems() const
    {
        auto Count = 0;
        for (int32 Index = 1; Index <= 2; ++Index)
        {
            if (ck::IsValid(Get_Slot(Index).Get_Item()))
            { ++Count; }
        }

        for (auto Rat : Get_Rats())
        { Count += Rat.Get_Pocket().Get_NumItems(); }

        return Count;
    }

    // A chef's positive weapon hit on InRat's body zone: the cleaver (a Strike item) as the causer, the chef as instigator.
    protected void Strike_Rat(FCk_Handle_PantryRat InRat, int32 InChefIndex)
    {
        auto Weapon = _WeaponHolder.Get_SoleItem();
        if (ck::Is_NOT_Valid(Weapon))
        {
            FinishFailure("strike precondition: the cleaver holder is seeded (Make_WeaponHolder in DoBeginPlay, then wait)");
            return;
        }

        auto Event = FMars_DamageEvent(10.0f, GameplayTags::DamageType_Mars_Sever);
        Event.Source.Instigator = _Chefs[InChefIndex];
        Event.Source.Causer = Weapon;
        auto Zone = InRat.Get_Monster().Get_BodyZone();
        Zone.Request_Hit(FMars_Request_HitZone_Hit(Event));
    }

    protected void Make_WeaponHolder(FCk_Handle InHandle)
    {
        _WeaponHolder = Make_SeededHolder(InHandle, mars_items::Cleaver());
    }

    // Gives chef InChefIndex the player's DamageDealer (Mars_PlayerCharacter.as composes one on the player entity, beside its
    // Hotbar and TAG_MarsCombatTarget), scaled by InDamageScale (a fractional weapon: 20 x 0.02 = 0.4 damage).
    protected FCk_Handle_DamageDealer Make_ChefDealer(int32 InChefIndex, float32 InDamageScale)
    {
        auto Chef = _Chefs[InChefIndex];
        return utils_damage_dealer::Add(Chef, FMars_DamageDealer_Spec(InDamageScale));
    }

    // The player's real strike, as UMars_SmTask_ItemUse_Strike::DoSwing issues it (Script/Items/Hfsm/Mars_ItemUse_Hfsm.as):
    // the event from utils_damage_dealer::Make_Event(dealer, Strike.Damage, Strike.DamageType) with the cleaver as Causer
    // and Forward * Strike.ImpulseSpeed as the impulse, through the dealer's Request_StrikeSweep (a Strike.Radius sphere,
    // Probe.Mars.HitZone, Blocking world, Silent) out to Strike.Reach. Only the view is the test's: a level sweep 10 cm over
    // the rat root from k_StrikeStandoffCm behind it along InDirection (the chef stand-in has no viewpoint). Returns whether
    // the sweep hit a hurtbox.
    protected const float64 k_StrikeStandoffCm = 120.0;

    protected bool Strike_RatAsTheChef(FCk_Handle_PantryRat InRat, int32 InChefIndex, FVector InDirection)
    {
        auto Weapon = _WeaponHolder.Get_SoleItem();
        auto Dealer = _Chefs[InChefIndex].As_DamageDealer(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Weapon) || ck::Is_NOT_Valid(Dealer))
        {
            FinishFailure("real strike precondition: a seeded cleaver (Make_WeaponHolder) and a chef dealer (Make_ChefDealer)");
            return false;
        }

        const UMars_ItemTrait_Strike Strike = Weapon.Get_Strike();
        const auto Forward = InDirection.GetSafeNormal2D();
        // 10 cm over the root (28 cm over the floor): the sphere clears the floor (a Blocking world hit) and crosses the
        // hurtbox (root +- 17 cm).
        const auto Start = InRat.Get_Location() + FVector(0.0, 0.0, 10.0) - Forward * k_StrikeStandoffCm;

        auto Template = utils_damage_dealer::Make_Event(Dealer, Strike.Damage, Strike.DamageType);
        Template.Source.Causer = Weapon;
        Template.Hit.Impulse = Forward * Strike.ImpulseSpeed;
        const auto Hit = Dealer.Request_StrikeSweep(FMars_DamageDealer_Sweep(Start, Start + Forward * Strike.Reach, Strike.Radius), Template);
        return ck::IsValid(Hit.Get_HitEntity()) && Hit.Get_HitKind() == ECk_ProbeTrace_HitKind::Probe;
    }

    // A rat spawned straight through its entity script (not by the raid, so the raid neither counts nor retires it), on the
    // court's raid and den, with its body built even headless so its real skeletal component's custom primitive data can be
    // read back. InDeathHoldSeconds tunes the corpse hold.
    protected FCk_Handle Spawn_LookRat(FCk_Handle InHandle, FVector InLocation, int32 InOperationId, float32 InDeathHoldSeconds)
    {
        auto Spec = FMars_PantryRat_Spec();
        Spec.Links.Raid = _RaidEntity;
        Spec.Links.Den = _DenEntity;
        Spec.Links.ResidentSlot = 0;
        Spec.Links.OperationId = InOperationId;
        Spec.Tuning = utils_pantry_raid::Make_RatTuning(_Spec);
        Spec.Tuning.DeathHoldSeconds = InDeathHoldSeconds;

        auto Params = UMars_PantryRat_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, InLocation);
        Params.Spec = Spec;
        Params.BuildBodyHeadless = true;
        auto Rat = utils_entity_script::Request_SpawnEntity(InHandle, UMars_PantryRat_EntityScript, Params).Get_EntityUnderConstruction();
        _OwnedExtra.Add(Rat);
        return Rat;
    }

    protected UMars_PantryRat_EntityScript Get_RatScript(FCk_Handle InRat) const
    {
        if (ck::Is_NOT_Valid(InRat) || InRat.Has_Fragment(FMars_Fragment_PantryRat_Assembly) == false)
        { return nullptr; }

        return InRat.Get_Fragment(FMars_Fragment_PantryRat_Assembly).Script.Get();
    }

    // The rat body's custom primitive data slot InIndex (the real skeletal component the assembly wrote).
    protected float32 Get_BodyCpd(UMars_PantryRat_EntityScript InScript, int32 InIndex) const
    {
        if (ck::Is_NOT_Valid(InScript) || ck::Is_NOT_Valid(InScript.Get_BodyPart()))
        { return -1.0f; }

        return utils_unreal_component::Get_CustomPrimitiveDataFloat(InScript.Get_BodyPart(), InIndex);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Court steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Step_BuildField(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        if (_BuildField)
        { RequestBuild(1); }
    }

    UFUNCTION()
    protected void Check_CourtConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Raid = _RaidEntity.As_PantryRaid(ECk_SanityCheck::UnChecked);
        _Den = _DenEntity.As_RatDen(ECk_SanityCheck::UnChecked);
        const auto PackReady = ck::IsValid(_PackEntity) && _PackEntity.Is_Backpack() && _PackEntity.Is_WorldItem()
            && ck::IsValid(_PackEntity.As_WorldItem().Get_HeldItem());
        const auto FoodReady = ck::IsValid(_FoodEntity) && _FoodEntity.Is_WorldItem() && ck::IsValid(_FoodEntity.As_WorldItem().Get_HeldItem());
        const auto Ready = ck::IsValid(_Raid) && ck::IsValid(_Den) && PackReady && FoodReady && _CheeseHolder.Get_NumItems() == 1
            && (ck::Is_NOT_Valid(_WeaponHolder) || _WeaponHolder.Get_NumItems() == 1);
        if (Ready)
        {
            _Pack = _PackEntity.As_WorldItem();
            _Food = _FoodEntity.As_WorldItem();
            _FoodItem = _Food.Get_HeldItem();
            _CheeseItem = _CheeseHolder.Get_SoleItem();
        }

        auto Result = OutResult;
        Result.Set(Ready);
    }

    UFUNCTION()
    protected void Step_StowCourt(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto CheeseSlot = Get_Slot(_MushroomFirst ? 2 : 1);
        auto FoodSlot = Get_Slot(_MushroomFirst ? 1 : 2);
        CheeseSlot.Request_Stow(FMars_Request_CargoSlot_Stow(_CheeseItem));
        FoodSlot.Request_Stow(FMars_Request_CargoSlot_Stow(_FoodItem));
    }

    UFUNCTION()
    protected void Check_CourtStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto FoodSlot = Get_Slot(_MushroomFirst ? 1 : 2);
        FCk_Handle FoodSlotEntity = FoodSlot;
        const auto Ready = Get_Slot(_MushroomFirst ? 2 : 1).Get_Item() == _CheeseItem && FoodSlot.Get_Item() == _FoodItem
            && _Food.Get_Mount() == EMars_WorldItem_Mount::Carried && _Food.Get_Carrier() == FoodSlotEntity && _Food.Get_IsSettled()
            && _Pack.Get_Mount() == EMars_WorldItem_Mount::World && _Pack.Get_IsSettled();
        auto Result = OutResult;
        Result.Set(Ready);
    }

    // The raid is ready and has spawned a constructed rat.
    UFUNCTION()
    protected void Check_FirstRatOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Raid) && _Raid.Get_IsReady() && ck::IsValid(Get_FirstRat()));
    }

    // The first rat holds its lease in ClaimTell (rummaging, before its claim).
    UFUNCTION()
    protected void Check_FirstRatClaiming(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        const auto Phase = ck::IsValid(Rat) ? Rat.Get_Phase() : EMars_PantryRat_Phase::Emerge;
        auto Result = OutResult;
        Result.Set(Phase == EMars_PantryRat_Phase::ClaimTell);
    }

    // The first rat stole and its carry receipt landed: FleeWithLoot or a later flee phase.
    UFUNCTION()
    protected void Check_FirstRatLoaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        auto Result = OutResult;
        Result.Set(ck::IsValid(Rat) && Rat.Get_HasCarryReceipt() && utils_pantry_rat::Get_IsLoadedPhase(Rat.Get_Phase()));
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        Super::DoEndPlay(InHandle);
        for (auto Owner : _OwnedExtra)
        { if (ck::IsValid(Owner)) { utils_entity_lifetime::Request_DestroyEntity(Owner); } }
    }
}
