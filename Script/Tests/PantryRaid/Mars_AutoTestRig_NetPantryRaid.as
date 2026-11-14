// One eye change a machine's copy of the den raised, with its frame.
struct FMars_NetPantryTest_EyeChange
{
    UPROPERTY()
    EMars_RatDen_Eyes Eyes = EMars_RatDen_Eyes::Vacant;

    UPROPERTY()
    int32 Slot = 0;

    UPROPERTY()
    int32 Frame = -1;
}

// The pantry raid and rat den net tests' shared steps, on top of the pawn rig (its slab on every machine, the
// production pawn and the client's viewer for a row about players). The server lays a static Jolt box whose top face is
// the base's Z and a ground nav field over it (owned by the subject, auto-build off), spawns the raid at the base and
// the den 400 behind it, facing +X, through their real entity scripts under the replicated spawn owner, and for a court
// a pack and a Monk's Rind beside it as replicated world items, the Rind stowed into cargo slot 1 once both are ready.
// Chef stand-ins are plain entities of the server's (a root, a Hotbar with one bag slot, a tag) owned by the world, not
// the subject, so they inherit no replicated net params and their local slots follow them. Each machine finds its
// copies of the raid, the den and the pack by tag near their spots and records, with the frame, what its copies raise
// from then on: OnReady and OnRatSpawned on the raid, OnEmergeReady, OnReturnRefused and every OnEyesChanged on the
// den.
UCLASS(Abstract)
class UMars_AutoTestRig_NetPantryRaid : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 28.0f;

    protected const FVector k_DenFromBase = FVector(-400.0, 0.0, 0.0);
    protected const FVector k_PackFromBase = FVector(250.0, 0.0, 2.0);
    protected const FVector k_CheeseFromBase = FVector(150.0, 350.0, 5.0);
    protected const FVector k_RowFloorHalfExtents = FVector(1500.0, 1500.0, 10.0);
    // A copy is found within this of its spot.
    protected const float64 k_CopyNearCm = 150.0;
    // A scan for leftovers counts what stands within this of the base.
    protected const float64 k_LeftoverNearCm = 1000.0;

    protected FVector _DenSpot = FVector::ZeroVector;
    protected FVector _PackSpot = FVector::ZeroVector;

    // Server: what it spawned.
    protected FCk_Handle_GroundNavVolume _RowVolume;
    protected FCk_Handle_JoltBody _RowFloor;
    protected FCk_Handle _RowPackEntity;
    protected FCk_Handle _RowCheeseEntity;
    protected FCk_Handle_Item _RowCheeseItem;
    protected int32 _RowBuildResolvedFrame = -1;

    // Each machine: its copies.
    protected FCk_Handle_PantryRaid _RowRaid;
    protected FCk_Handle_RatDen _RowDen;
    protected FCk_Handle_Backpack _RowPack;
    protected FCk_Handle_WorldItem _RowPackItem;

    // Each machine: what its copies raised.
    protected int32 _RaidReadySignals = 0;
    protected int32 _RaidReadyFrame = -1;
    protected int32 _RatSpawnedSignals = 0;
    protected int32 _RatSpawnedFrame = -1;
    protected int32 _EmergeReadySignals = 0;
    protected int32 _ReturnRefusedSignals = 0;
    protected TArray<FMars_NetPantryTest_EyeChange> _EyeChanges;

    // The frames of the court's waits on the server; -1 before.
    protected int32 _FloorJoinedFrame = -1;
    protected int32 _BuildRequestedFrame = -1;
    protected int32 _PackReadyFrame = -1;
    protected int32 _StowedFrame = -1;
    protected int32 _RaidReadySeenFrame = -1;
    protected int32 _FirstRatFrame = -1;

    private float64 _RowSampleUntil = 0.0;

    // Both machines: the base, the den's and the pack's spots, and the pawn rig's slab.
    protected void Begin_PantryRow(FVector InBase)
    {
        Begin_Rig(InBase);
        _DenSpot = InBase + k_DenFromBase;
        _PackSpot = InBase + k_PackFromBase;
    }

    // The default spec with bounds that two rows 1000 apart never share, and a short scent arm and emergence spacing.
    protected FMars_PantryRaid_Spec Make_RowSpec() const
    {
        auto Spec = FMars_PantryRaid_Spec();
        Spec.EncounterBounds = FBox(FVector(-480.0, -480.0, -100.0), FVector(480.0, 480.0, 200.0));
        Spec.Scent.GroundArmSeconds = 0.5f;
        Spec.Population.EmergeSpacingSeconds = 0.5f;
        return Spec;
    }

    UFUNCTION()
    protected void Is_RowSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the floor, the field, the raid, the den, the pack, the cheese, the chefs
    //----------------------------------------------------------------------------------------------------------------------

    // A static Jolt box whose top face is the base's Z, owned by the subject.
    protected void Spawn_ServerFloor()
    {
        auto Subject = Get_SubjectEntity();
        auto FloorEntity = utils_entity_lifetime::Request_CreateEntity(Subject);
        Track_ForCleanup(FloorEntity);
        utils_transform::Add(FloorEntity, FTransform(FRotator::ZeroRotator, _Base - FVector(0.0, 0.0, k_RowFloorHalfExtents.Z)),
            ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_RowFloorHalfExtents);
        auto FloorSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        FloorSpec.Set_ShapeDimensions(Shape).Set_MotionType(ECk_MotionType::Static);
        _RowFloor = utils_jolt_body::Add(FloorEntity, FloorSpec);
    }

    // The court's ground nav field round the base, on a plain entity of the subject's that is its own context; built
    // only on request.
    protected void Spawn_ServerVolume()
    {
        auto Subject = Get_SubjectEntity();
        auto VolumeOwner = utils_entity_lifetime::Request_CreateEntity(Subject);
        VolumeOwner.Request_OverrideToSelf();
        Track_ForCleanup(VolumeOwner);
        auto Config = FCk_GroundNav_BakeConfig(25.0f, 10.0f);
        Config.Set_TileSizeUu(200.0f).Set_MaxColumnsPerTile(262144);
        auto Profile = FCk_GroundNav_AgentProfile(utils_shapes::Make_Capsule(FCk_ShapeCapsule_Dimensions(40.0f, 40.0f)));
        Profile.Set_LedgeSensitivity(0.0f);
        auto Spec = FCk_GroundNavVolume_Spec(
            FBox(_Base - FVector(600.0, 600.0, 50.0), _Base + FVector(600.0, 600.0, 200.0)), Config, Profile);
        Spec.Set_AutoBuildOnSetup(ECk_EnableDisable::Disable).Set_ProbeBudgetPerTick(1);
        _RowVolume = utils_ground_nav_volume::Add(VolumeOwner, Spec);
    }

    protected void Request_ServerFieldBuild()
    {
        auto Request = FCk_Request_GroundNavVolume_Build();
        Request.Set_RequestSequence(1);
        Request.Set_OnBuildResolved(FCk_Delegate_GroundNavVolume_OnBuildResolved(this, n"OnRowFieldResolved"));
        utils_ground_nav_volume::Request_Build(_RowVolume, Request, FCk_Delegate_Request_OnCompleted(this, n"OnRowFieldCompleted"));
        _BuildRequestedFrame = int32(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRowFieldResolved(FCk_Handle_GroundNavVolume InVolume, const FCk_GroundNavVolume_BuildOutcome&in InOutcome)
    {
        _RowBuildResolvedFrame = int32(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRowFieldCompleted(FCk_Handle InOwner, ECk_Request_OperationResult InResult)
    {
    }

    // The real raid under the replicated spawn owner at the base, with the field when the row composed one.
    protected void Spawn_ServerRaid(FMars_PantryRaid_Spec InSpec)
    {
        auto Params = UMars_PantryRaid_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.Spec = InSpec;
        Params.NavVolume = _RowVolume;
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        Track_ForCleanup(utils_entity_script::Request_SpawnEntity(Owner, UMars_PantryRaid_EntityScript, Params).Get_EntityUnderConstruction());
    }

    // The real den under the replicated spawn owner at its spot, facing +X, its other parameters at their defaults.
    protected void Spawn_ServerDen(int32 InResidents)
    {
        auto Params = UMars_RatDen_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _DenSpot);
        Params.Spec = FMars_RatDen_Spec(InResidents);
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        Track_ForCleanup(utils_entity_script::Request_SpawnEntity(Owner, UMars_RatDen_EntityScript, Params).Get_EntityUnderConstruction());
    }

    // The pack lying at its spot and a Monk's Rind beside it, both World-mode items under the replicated spawn owner.
    protected void Spawn_ServerPackAndCheese()
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        auto PackSpec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::Backpack()),
            FTransform(FRotator::ZeroRotator, _PackSpot));
        _RowPackEntity = utils_world_item::Request_SpawnWorld(Owner, PackSpec);
        Track_ForCleanup(_RowPackEntity);

        auto CheeseSpec = FMars_WorldItem_WorldSpec(utils_held_item::Make_DefinitionSoft(mars_items::MonksRind()),
            FTransform(FRotator::ZeroRotator, _Base + k_CheeseFromBase));
        _RowCheeseEntity = utils_world_item::Request_SpawnWorld(Owner, CheeseSpec);
        Track_ForCleanup(_RowCheeseEntity);
    }

    // A chef stand-in of the server's at InLocation: a root, a Hotbar with one bag slot, InTag last.
    protected FCk_Handle Make_ServerChef(FVector InLocation, FName InTag)
    {
        auto Chef = utils_entity_lifetime::Request_CreateEntity(utils_net_spawn_test::Get_TransientEntity(Get_SubjectEntity()));
        Track_ForCleanup(Chef);
        utils_transform::Add(Chef, FTransform(FRotator::ZeroRotator, InLocation), ECk_Replication::DoesNotReplicate);
        auto Spec = FMars_Hotbar_Spec();
        Spec.BagSlotCount = 1;
        utils_hotbar::Add(Chef, Spec);
        utils_handle::Set_DebugName(Chef, n"PantryNetTest.Chef");
        utils_entity_tag::Add(Chef, InTag);
        return Chef;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the court's waits, in order
    //----------------------------------------------------------------------------------------------------------------------

    // The floor, the field, the raid with it, the den, the pack and the cheese.
    protected void Spawn_ServerCourt(FMars_PantryRaid_Spec InSpec)
    {
        Spawn_ServerFloor();
        Spawn_ServerVolume();
        Spawn_ServerRaid(InSpec);
        Spawn_ServerDen(InSpec.Population.ResidentsPerDen);
        Spawn_ServerPackAndCheese();
    }

    UFUNCTION()
    protected void Is_RowFloorJoined(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Joined = ck::IsValid(_RowFloor) && utils_jolt_body::Get_IsBodyAdded(_RowFloor);
        if (Joined && _FloorJoinedFrame < 0)
        { _FloorJoinedFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(Joined);
    }

    UFUNCTION()
    protected void Is_RowPackAndCheeseReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowPackAndCheeseReady());
    }

    // The raid and the den are found first, so their signals are recorded before any emergence.
    private bool Get_IsRowPackAndCheeseReady()
    {
        if ((Get_IsRowRaidFound() && Get_IsRowDenFound()) == false)
        { return false; }

        if (ck::Is_NOT_Valid(_RowPackEntity) || ck::Is_NOT_Valid(_RowCheeseEntity))
        { return false; }

        const auto PackReady = _RowPackEntity.Is_Backpack() && _RowPackEntity.Is_WorldItem()
            && ck::IsValid(_RowPackEntity.As_WorldItem().Get_HeldItem()) && _RowPackEntity.As_Backpack().Get_IsReady();
        const auto CheeseReady = _RowCheeseEntity.Is_WorldItem() && ck::IsValid(_RowCheeseEntity.As_WorldItem().Get_HeldItem())
            && _RowCheeseEntity.As_WorldItem().Get_IsSettled();
        if ((PackReady && CheeseReady) == false)
        { return false; }

        _RowCheeseItem = _RowCheeseEntity.As_WorldItem().Get_HeldItem();
        if (_PackReadyFrame < 0)
        { _PackReadyFrame = int32(utils_time::Get_FrameCounter()); }

        return true;
    }

    protected void Request_ServerStowCheese()
    {
        auto Slot = _RowPackEntity.As_Backpack().Get_CargoSlot(1);
        Slot.Request_Stow(FMars_Request_CargoSlot_Stow(_RowCheeseItem));
    }

    UFUNCTION()
    protected void Is_RowCheeseStowed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Stowed = false;
        if (ck::IsValid(_RowPackEntity) && _RowPackEntity.Is_Backpack() && _RowPackEntity.Is_WorldItem())
        {
            const auto Pack = _RowPackEntity.As_WorldItem();
            Stowed = _RowPackEntity.As_Backpack().Get_CargoSlot(1).Get_Item() == _RowCheeseItem
                && Pack.Get_Mount() == EMars_WorldItem_Mount::World && Pack.Get_IsSettled();
        }

        if (Stowed && _StowedFrame < 0)
        { _StowedFrame = int32(utils_time::Get_FrameCounter()); }

        auto Result = OutResult;
        Result.Set(Stowed);
    }

    // The raid reads ready and its first record's entity is a pantry rat.
    UFUNCTION()
    protected void Is_RowFirstRatOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(Get_RowFirstRat()));
    }

    // The raid's first record's rat while the raid reads ready; invalid otherwise.
    protected FCk_Handle_PantryRat Get_RowFirstRat()
    {
        if (Get_IsRowRaidFound() == false || Get_IsRowEnding(_RowRaid))
        { return FCk_Handle_PantryRat(); }

        if (_RowRaid.Get_IsReady() && _RaidReadySeenFrame < 0)
        { _RaidReadySeenFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Rats = _RowRaid.Get_Rats();
        if (_RowRaid.Get_IsReady() == false || Rats.Num() == 0)
        { return FCk_Handle_PantryRat(); }

        const auto Rat = Rats[0].Rat.As_PantryRat(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Rat) && _FirstRatFrame < 0)
        { _FirstRatFrame = int32(utils_time::Get_FrameCounter()); }

        return Rat;
    }

    protected FString Describe_CourtFrames()
    {
        return f"court=[floor {_FloorJoinedFrame} build {_BuildRequestedFrame} built {_RowBuildResolvedFrame} pack {_PackReadyFrame} stowed {_StowedFrame} ready {_RaidReadySeenFrame} readySignal {_RaidReadyFrame} spawnSignal {_RatSpawnedFrame} ratOut {_FirstRatFrame}]";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copies
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_RowRaidAndDenFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowRaidFound() && Get_IsRowDenFound());
    }

    UFUNCTION()
    protected void Is_RowDenFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowDenFound());
    }

    UFUNCTION()
    protected void Is_RowCourtFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowRaidFound() && Get_IsRowDenFound() && Get_IsRowPackFound());
    }

    // This machine's copy of the raid nearest the base; the first time, its signals are recorded from here.
    protected bool Get_IsRowRaidFound()
    {
        if (ck::IsValid(_RowRaid))
        { return true; }

        const auto Candidate = DoFind_TaggedNear(utils_pantry_raid::RaidTag, _Base);
        auto Raid = Candidate.As_PantryRaid(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Raid))
        { return false; }

        _RowRaid = Raid;
        _RowRaid.BindTo_OnReady(FMars_Delegate_PantryRaid_OnReady(this, n"OnRowRaidReady"));
        _RowRaid.BindTo_OnRatSpawned(FMars_Delegate_PantryRaid_OnRatSpawned(this, n"OnRowRatSpawned"));
        return true;
    }

    // This machine's copy of the den nearest its spot; the first time, its signals are recorded from here.
    protected bool Get_IsRowDenFound()
    {
        if (ck::IsValid(_RowDen))
        { return true; }

        const auto Candidate = DoFind_TaggedNear(utils_rat_den::DenTag, _DenSpot);
        auto Den = Candidate.As_RatDen(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Den))
        { return false; }

        _RowDen = Den;
        _RowDen.BindTo_OnEmergeReady(FMars_Delegate_RatDen_OnEmergeReady(this, n"OnRowEmergeReady"));
        _RowDen.BindTo_OnReturnRefused(FMars_Delegate_RatDen_OnReturnRefused(this, n"OnRowReturnRefused"));
        _RowDen.BindTo_OnEyesChanged(FMars_Delegate_RatDen_OnEyesChanged(this, n"OnRowEyesChanged"));
        return true;
    }

    // This machine's copy of the pack near its spot.
    protected bool Get_IsRowPackFound()
    {
        if (ck::IsValid(_RowPack))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Candidate.Is_Backpack() == false || Candidate.Is_WorldItem() == false)
            { continue; }

            if (Get_PlanarDistance(Get_RowRootLocation(Candidate), _PackSpot) > k_CopyNearCm)
            { continue; }

            _RowPack = Candidate.As_Backpack();
            _RowPackItem = Candidate.As_WorldItem();
            return true;
        }

        return false;
    }

    // The entity tagged InTag in this machine's world nearest InSpot, within k_CopyNearCm; invalid without one.
    protected FCk_Handle DoFind_TaggedNear(FName InTag, FVector InSpot)
    {
        auto Found = FCk_Handle();
        auto Nearest = k_CopyNearCm;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            if (Get_IsRowEnding(Candidate) || ck::Is_NOT_Valid(Candidate.As_Transform(ECk_SanityCheck::UnChecked)))
            { continue; }

            const auto Distance = (Get_RowRootLocation(Candidate) - InSpot).Size();
            if (Distance >= Nearest)
            { continue; }

            Found = Candidate;
            Nearest = Distance;
        }

        return Found;
    }

    // Entities tagged InTag in this machine's world within k_LeftoverNearCm of the base, not ending.
    protected int32 Count_TaggedNearBase(FName InTag)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            if (Get_IsRowEnding(Candidate) || ck::Is_NOT_Valid(Candidate.As_Transform(ECk_SanityCheck::UnChecked)))
            { continue; }

            if ((Get_RowRootLocation(Candidate) - _Base).Size() <= k_LeftoverNearCm)
            { Count += 1; }
        }

        return Count;
    }

    // Every entity tagged as a pantry rat in this machine's world, not ending.
    protected int32 Count_RatsHere()
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), utils_pantry_rat::RatTag))
        {
            if (Get_IsRowEnding(Candidate) == false)
            { Count += 1; }
        }

        return Count;
    }

    // Gone, or on its way out: an expected absence for a copy the server may already have destroyed.
    protected bool Get_IsRowEnding(const FCk_Handle& InEntity)
    {
        return ck::Is_NOT_Valid(InEntity)
            || utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    protected FVector Get_RowRootLocation(const FCk_Handle& InEntity)
    {
        const auto Root = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Root))
        { return FVector::ZeroVector; }

        return utils_transform::Get_EntityCurrentLocation(Root);
    }

    protected float64 Get_PlanarDistance(FVector InA, FVector InB)
    {
        return (InA - InB).Size2D();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: the den's ledger and eyes
    //----------------------------------------------------------------------------------------------------------------------

    protected bool Get_HasRowDenLedger()
    {
        return ck::IsValid(_RowDen) && _RowDen.Has_Fragment(FMars_Fragment_RatDen_Net);
    }

    // This machine's den ledger; a default one before the den is found.
    protected FMars_Fragment_RatDen_Net Get_RowDenLedger()
    {
        if (Get_HasRowDenLedger() == false)
        { return FMars_Fragment_RatDen_Net(); }

        return _RowDen.Get_Fragment(FMars_Fragment_RatDen_Net);
    }

    protected bool Get_IsRowDenLedger(EMars_RatDen_Eyes InEyes, int32 InSlot)
    {
        const auto Ledger = Get_RowDenLedger();
        return Get_HasRowDenLedger() && Ledger.Eyes == InEyes && (InEyes == EMars_RatDen_Eyes::Vacant || Ledger.EyeSlot == InSlot);
    }

    // The mirror's state on this machine's den: set only without authority.
    protected bool Get_IsRowDenMirrorStateSet()
    {
        return ck::IsValid(_RowDen) && _RowDen.Has_Fragment(FMars_Fragment_RatDen_Local)
            && _RowDen.Get_Fragment(FMars_Fragment_RatDen_Local).Last.IsSet();
    }

    protected bool Get_IsRowEyeSlot(int32 InSlot)
    {
        return ck::IsValid(_RowDen) && Get_IsRowEnding(_RowDen) == false && _RowDen.Get_EyeSlot() == TOptional<int32>(InSlot);
    }

    UFUNCTION()
    protected void Is_RowEyeSlotOne(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsRowEyeSlot(1));
    }

    protected bool Get_IsEyeChange(int32 InIndex, EMars_RatDen_Eyes InEyes, int32 InSlot)
    {
        if (InIndex >= _EyeChanges.Num())
        { return false; }

        const auto Change = _EyeChanges[InIndex];
        return Change.Eyes == InEyes && (InEyes == EMars_RatDen_Eyes::Vacant || Change.Slot == InSlot);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: a wall-clock settle that samples the row every frame
    //----------------------------------------------------------------------------------------------------------------------

    protected void Wait_RowSampling(float32 InSeconds, FName InContinuation)
    {
        _RowSampleUntil = Get_RowWorldSeconds() + InSeconds;
        WaitUntil(n"Is_RowSampledLongEnough", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_RowSampledLongEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Row();
        auto Result = OutResult;
        Result.Set(Get_RowWorldSeconds() >= _RowSampleUntil);
    }

    // A row that samples something every frame overrides this.
    protected void Sample_Row()
    {
    }

    protected float64 Get_RowWorldSeconds()
    {
        const auto SubjectWorld = utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
        return float64(SubjectWorld.GetTimeSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The row's log line, its end
    //----------------------------------------------------------------------------------------------------------------------

    protected void Log_PantryRow(FString InRow, FString InExtra)
    {
        const auto Line = f"[PantryNetTest] {InRow} {Get_MachineName()} {Describe_Raid()} {Describe_Den()} ratsHere={Count_RatsHere()} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    protected FString Describe_Raid()
    {
        if (ck::Is_NOT_Valid(_RowRaid) || Get_IsRowEnding(_RowRaid))
        { return "raid=[none]"; }

        const auto Authority = utils_net::Get_HasAuthority(_RowRaid);
        const auto VolumeValid = ck::IsValid(_RowRaid.Get_NavVolume());
        return f"raid=[authority {Authority} clock {_RowRaid.Get_Clock()} ready {_RowRaid.Get_IsReady()} dens {_RowRaid.Get_Dens().Num()} chefs {_RowRaid.Get_Chefs().Num()} packs {_RowRaid.Get_Packs().Num()} rats {_RowRaid.Get_RatCount()} emergences {_RowRaid.Get_EmergencesRequested()} staleSpawns {_RowRaid.Get_StaleSpawns()} leases {_RowRaid.Get_LeasesGranted()} navVolume {VolumeValid} readySignals {_RaidReadySignals} spawnSignals {_RatSpawnedSignals}]";
    }

    protected FString Describe_Den()
    {
        if (ck::Is_NOT_Valid(_RowDen) || Get_IsRowEnding(_RowDen))
        { return "den=[none]"; }

        const auto Authority = utils_net::Get_HasAuthority(_RowDen);
        const auto EyeSlot = _RowDen.Get_EyeSlot();
        const auto EyeText = EyeSlot.IsSet() ? f"{EyeSlot.GetValue()}" : "unset";
        const auto Ledger = Get_RowDenLedger();
        FString Slots;
        for (int32 Index = 0; Index < _RowDen.Get_ResidentCount(); ++Index)
        { Slots += f"{_RowDen.Get_SlotState(Index) :n},"; }

        FString Changes;
        for (const auto& Change : _EyeChanges)
        { Changes += f"{Change.Eyes :n}/{Change.Slot}@{Change.Frame},"; }

        return f"den=[authority {Authority} eyeSlot {EyeText} ledger {Get_HasRowDenLedger()}:{Ledger.Eyes :n}/{Ledger.EyeSlot} mirrorState {Get_IsRowDenMirrorStateSet()} slots {Slots} stale {_RowDen.Get_StaleRequests()} refused {_RowDen.Get_RefusedReturns()} emergeReady {_EmergeReadySignals} returnRefused {_ReturnRefusedSignals} eyeChanges [{Changes}]]";
    }

    // The row's log line and no ensure on this machine, then success.
    protected void Finish_PantryRow(FString InRow, FString InExtra)
    {
        Log_PantryRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it tears down and finishes.
    protected void Hold_PantryServerRow(FString InRow, FString InExtra)
    {
        Log_PantryRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRowRaidReady(FCk_Handle_PantryRaid InRaid)
    {
        _RaidReadySignals += 1;
        if (_RaidReadyFrame < 0)
        { _RaidReadyFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnRowRatSpawned(FCk_Handle_PantryRaid InRaid, FCk_Handle InRat, int32 InOperationId)
    {
        _RatSpawnedSignals += 1;
        if (_RatSpawnedFrame < 0)
        { _RatSpawnedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnRowEmergeReady(FCk_Handle_RatDen InDen, int32 InSlot, int32 InOperationId)
    {
        _EmergeReadySignals += 1;
    }

    UFUNCTION()
    private void OnRowReturnRefused(FCk_Handle_RatDen InDen, int32 InSlot, FCk_Handle InRat, EMars_RatDen_ReturnRefusal InReason)
    {
        _ReturnRefusedSignals += 1;
    }

    UFUNCTION()
    private void OnRowEyesChanged(FCk_Handle_RatDen InDen, bool InShown, int32 InEyeSlot)
    {
        auto Change = FMars_NetPantryTest_EyeChange();
        Change.Eyes = InShown ? EMars_RatDen_Eyes::Shown : EMars_RatDen_Eyes::Vacant;
        Change.Slot = InEyeSlot;
        Change.Frame = int32(utils_time::Get_FrameCounter());
        _EyeChanges.Add(Change);
    }
}
