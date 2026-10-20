// The heat-station rigs' shared fixture (UMars_AutoTestRig_HeatStation, UMars_AutoTestRig_HeatOperator, and the tumbler's
// station test): the real searing, fry, batter, tumbler or cutting station spawned through its entity script as its own
// context, World-mode
// platters lying on static floors beside it, the FoodPiece rig's box fixture, docking, and the readiness both rigs wait
// for. What it spawns under the world's transient entity is returned for the rig to track for cleanup (Track_ForCleanup is
// the test's).
class UMars_AutoTestHelper_HeatStation : UObject
{
    private UMars_AutoTestHelper_FoodOnPlatter _FoodOnPlatter;
    private UMars_AutoTestHelper_CookingFixture _CookingFixture;

    // The real searing station at InOrigin with InTiming on its feed, under InOwner; constructed when the returned pending
    // entity script says so.
    FCk_Handle_PendingEntityScript Spawn_Searing(FCk_Handle InOwner, FVector InOrigin, FMars_CookingFeed_TimingSpec InTiming)
    {
        auto SpawnParams = UMars_SearingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Feed.Timing = InTiming;
        return Spawn_AsOwnContext(utils_entity_script::Request_SpawnEntity(InOwner, UMars_SearingStation_EntityScript, SpawnParams));
    }

    // The real fry station at InOrigin with InTiming on its feed, under InOwner; constructed when the returned pending entity
    // script says so.
    FCk_Handle_PendingEntityScript Spawn_Fry(FCk_Handle InOwner, FVector InOrigin, FMars_CookingFeed_TimingSpec InTiming)
    {
        auto SpawnParams = UMars_FryStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Feed.Timing = InTiming;
        return Spawn_AsOwnContext(utils_entity_script::Request_SpawnEntity(InOwner, UMars_FryStation_EntityScript, SpawnParams));
    }

    // The real tumbler station at InOrigin with InTumbler as its minigame's exposed spec and the feed's default timing, under
    // InOwner; constructed when the returned pending entity script says so.
    FCk_Handle_PendingEntityScript Spawn_Tumbler(FCk_Handle InOwner, FVector InOrigin, FMars_Tumbler_Spec InTumbler)
    {
        auto SpawnParams = UMars_TumblerStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Tumbler = InTumbler;
        return Spawn_AsOwnContext(utils_entity_script::Request_SpawnEntity(InOwner, UMars_TumblerStation_EntityScript, SpawnParams));
    }

    // The real batter station at InOrigin with InCoatSeconds per coat and the feed's default timing, under InOwner; constructed
    // when the returned pending entity script says so.
    FCk_Handle_PendingEntityScript Spawn_Batter(FCk_Handle InOwner, FVector InOrigin, float32 InCoatSeconds)
    {
        auto SpawnParams = UMars_BatterStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        SpawnParams.Batter.Coat.CoatSeconds = InCoatSeconds;
        return Spawn_AsOwnContext(utils_entity_script::Request_SpawnEntity(InOwner, UMars_BatterStation_EntityScript, SpawnParams));
    }

    // The real cutting station at InOrigin with its default board and the feed's default timing, under InOwner; constructed
    // when the returned pending entity script says so.
    FCk_Handle_PendingEntityScript Spawn_Cutting(FCk_Handle InOwner, FVector InOrigin)
    {
        auto SpawnParams = UMars_CuttingStation_EntityScript::Params();
        SpawnParams.SpawnTransform = FTransform(FRotator::ZeroRotator, InOrigin);
        return Spawn_AsOwnContext(utils_entity_script::Request_SpawnEntity(InOwner, UMars_CuttingStation_EntityScript, SpawnParams));
    }

    // An empty InPlatterItem platter lying on a floor whose top is at InFloorTop (a platter drops what it is given only while
    // it lies still); under construction until Get_IsPlatterReady says otherwise.
    FCk_Handle Spawn_EmptyPlatter(FCk_Handle InOwner, FVector InFloorTop, UCk_InventoryItem_Definition InPlatterItem)
    {
        const auto Spec = FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, InFloorTop), InPlatterItem);
        return Get_CookingFixture().Spawn_PlatterOnFloor(InOwner, Spec, 60.0);
    }

    // InFoodItem's whole joint spawned at InWorld and loaded onto InPlatterEntity once both are constructed (the kernel path:
    // no hand). Returns the food entity, which lives under the world's transient entity.
    FCk_Handle Spawn_FoodOnto(FCk_Handle InPlatterEntity, UCk_InventoryItem_Definition InFoodItem, FVector InWorld)
    {
        if (ck::Is_NOT_Valid(_FoodOnPlatter))
        { _FoodOnPlatter = Cast<UMars_AutoTestHelper_FoodOnPlatter>(NewObject(this, UMars_AutoTestHelper_FoodOnPlatter)); }

        return _FoodOnPlatter.Spawn_Onto(InPlatterEntity, InFoodItem, FTransform(FRotator::ZeroRotator, InWorld));
    }

    // The cooking fixture's box (a CPU-readable 1000 cm3 cube) of InKind weighing 0.1 kg, with no definition, under the
    // world's transient entity.
    FCk_Handle_FoodPiece Build_Box(FTransform InWorld, FGameplayTag InKind)
    {
        return Get_CookingFixture().Build_Box(InWorld, InKind, 0.1);
    }

    private UMars_AutoTestHelper_CookingFixture Get_CookingFixture()
    {
        if (ck::Is_NOT_Valid(_CookingFixture))
        { _CookingFixture = Cast<UMars_AutoTestHelper_CookingFixture>(NewObject(this, UMars_AutoTestHelper_CookingFixture)); }

        return _CookingFixture;
    }

    // Constructed (a World-mode platter whose holder holds its item) with InHeld pieces landed on it.
    bool Get_IsPlatterReady(FCk_Handle InEntity, int32 InHeld) const
    {
        return ck::IsValid(InEntity) && InEntity.Is_WorldItem() && InEntity.Is_Platter()
            && ck::IsValid(InEntity.As_WorldItem().Get_HeldItem()) && InEntity.As_Platter().Get_HeldCount() == InHeld;
    }

    void Dock(FCk_Handle_PlatterDock InDock, FCk_Handle InPlatterEntity)
    {
        auto Target = InDock;
        Target.Request_Dock(FMars_Request_PlatterDock_Dock(InPlatterEntity.As_WorldItem().Get_HeldItem()));
    }

    // Docked on InDock and no longer lerping onto it: a station torn down under a platter still arriving leaves the arrival
    // writing an offset under a dead parent.
    bool Get_IsDocked(FCk_Handle_PlatterDock InDock, FCk_Handle InPlatterEntity) const
    {
        if (ck::Is_NOT_Valid(InPlatterEntity) || InPlatterEntity.Is_Platter() == false || InDock.Get_Platter() != InPlatterEntity.As_Platter())
        { return false; }

        return InPlatterEntity.As_WorldItem().Get_Mount() == EMars_WorldItem_Mount::Carried
            && InPlatterEntity.Has_Fragment(FMars_Fragment_WorldItem_Arrival) == false;
    }

    // The kernel, the feed and both docks are composed and the kernel's static furniture is in the simulation.
    bool Get_IsStationReady(FCk_Handle_Station InStation) const
    {
        if (ck::Is_NOT_Valid(InStation))
        { return false; }

        FCk_Handle Entity = InStation;
        const auto IsComposed = ck::IsValid(Entity.As_CookingFeed(ECk_SanityCheck::UnChecked))
            && ck::IsValid(utils_platter_dock::Find_OnStation(Entity, EMars_PlatterDock_Role::Input))
            && ck::IsValid(utils_platter_dock::Find_OnStation(Entity, EMars_PlatterDock_Role::Output));

        const auto Searing = Entity.As_Searing(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Searing))
        { return IsComposed && utils_jolt_body::Get_IsBodyAdded(Searing.Get_Spec().Nodes.PanBaseBody); }

        const auto Tumbler = Entity.As_Tumbler(ECk_SanityCheck::UnChecked);
        if (ck::IsValid(Tumbler))
        { return IsComposed && utils_jolt_body::Get_IsBodyAdded(Tumbler.Get_Spec().Nodes.DrumBody); }

        if (ck::IsValid(Entity.As_Cutting(ECk_SanityCheck::UnChecked)))
        { return IsComposed && ck::IsValid(Entity.As_FoodBoard(ECk_SanityCheck::UnChecked)); }

        return IsComposed && (ck::IsValid(Entity.As_Fry(ECk_SanityCheck::UnChecked)) || ck::IsValid(Entity.As_Batter(ECk_SanityCheck::UnChecked)));
    }

    // The station's own state machine is in InKind's Operated state.
    bool Get_IsOperated(FCk_Handle_Station InStation, EMars_AutoTest_HeatStation InKind) const
    {
        const auto StateClass = utils_state_machine::Get_CurrentStateClass(InStation.Get_MinigameSm());
        if (InKind == EMars_AutoTest_HeatStation::Searing)
        { return StateClass == UMars_SmState_Searing_Operated; }

        if (InKind == EMars_AutoTest_HeatStation::Fry)
        { return StateClass == UMars_SmState_Fry_Operated; }

        if (InKind == EMars_AutoTest_HeatStation::Batter)
        { return StateClass == UMars_SmState_Batter_Operated; }

        if (InKind == EMars_AutoTest_HeatStation::Tumbler)
        { return StateClass == UMars_SmState_Tumbler_Operated; }

        return StateClass == UMars_SmState_Cutting_Operated;
    }

    // The station's own state machine is in InKind's Idle state.
    bool Get_IsIdle(FCk_Handle_Station InStation, EMars_AutoTest_HeatStation InKind) const
    {
        const auto StateClass = utils_state_machine::Get_CurrentStateClass(InStation.Get_MinigameSm());
        if (InKind == EMars_AutoTest_HeatStation::Searing)
        { return StateClass == UMars_SmState_Searing_Idle; }

        if (InKind == EMars_AutoTest_HeatStation::Fry)
        { return StateClass == UMars_SmState_Fry_Idle; }

        if (InKind == EMars_AutoTest_HeatStation::Batter)
        { return StateClass == UMars_SmState_Batter_Idle; }

        if (InKind == EMars_AutoTest_HeatStation::Tumbler)
        { return StateClass == UMars_SmState_Tumbler_Idle; }

        return StateClass == UMars_SmState_Cutting_Idle;
    }

    // As the map's entity spawner does: the station is its own context, so its state machine's ck::Ctx is the station.
    private FCk_Handle_PendingEntityScript Spawn_AsOwnContext(FCk_Handle_PendingEntityScript InPending)
    {
        auto Pending = InPending;
        auto Station = Pending.Get_EntityUnderConstruction();
        Station.Request_OverrideToSelf();
        return Pending;
    }
}
