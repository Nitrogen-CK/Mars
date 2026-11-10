// A world item spawned for an owner with no replication driver lives under the replicated spawn owner and is tethered to
// that owner: once the owner is destroyed the item is going within a few frames. A rock spawned beside it for nobody
// (ck::TransientEntity()) carries no tether and is still there several frames later. Isolated origin (53600, -12000,
// -30000).
class UMars_AutoTest_WorldItem_TetheredItemEndsWithItsOwner : UMars_AutoTestRig_Carrier
{
    private const FVector k_Origin = FVector(53600.0, -12000.0, -30000.0);
    private const int32 k_SlowPolls = 900;
    // The tether processor reads the destroyed owner on the next pass; the poll after it sees the item going.
    private const int32 k_MaxFramesToFollow = 3;
    private const int32 k_SurvivorFrames = 5;

    private FCk_Handle _Owner;
    private FCk_Handle _Tethered;
    private FCk_Handle _Untethered;
    private int64 _DestroyFrame = -1;
    private int64 _FollowedSeenFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_FloorSlab(InHandle, k_Origin);
        _Owner = utils_entity_lifetime::Request_CreateEntity(InHandle);

        const auto Rock = utils_held_item::Make_DefinitionSoft(mars_items::Rock());
        _Tethered = utils_world_item::Request_SpawnWorld(_Owner,
            FMars_WorldItem_WorldSpec(Rock, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, -100.0, 20.0))));

        auto Nobody = ck::TransientEntity();
        _Untethered = utils_world_item::Request_SpawnWorld(Nobody,
            FMars_WorldItem_WorldSpec(Rock, FTransform(FRotator::ZeroRotator, k_Origin + FVector(0.0, 100.0, 20.0))));
        Track_ForCleanup(_Untethered);

        Add_Step_WaitUntil("both rocks are constructed and hold their item", n"Check_Constructed", k_SlowPolls, 0);
        Add_Step("the tether names the owner; the rock for nobody has none", n"Step_AssertOwners");
        Add_Step("destroy the owner", n"Step_DestroyOwner");
        Add_Step_WaitUntil("the tethered rock is going", n"Check_TetheredGoing", 0, 0);
        Add_Step_WaitFrames("give the other rock the same frames and more", k_SurvivorFrames);
        Add_Step("the tethered rock followed its owner in time; the other one stays", n"Step_AssertEnded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Constructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Tethered = TryGet_ConstructedWorldItem(_Tethered);
        const auto Untethered = TryGet_ConstructedWorldItem(_Untethered);
        auto Res = OutResult;
        Res.Set(ck::IsValid(Tethered) && ck::IsValid(Tethered.Get_HeldItem())
            && ck::IsValid(Untethered) && ck::IsValid(Untethered.Get_HeldItem()));
    }

    UFUNCTION()
    private void Step_AssertOwners(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(utils_world_item::Get_SpawnOwner(_Tethered) == _Owner, "the tethered rock's spawn owner is the owner it was spawned for");
        Assert_False(utils_entity_lifetime::Get_LifetimeOwner(_Tethered) == _Owner, "the driverless owner is not the rock's lifetime owner");
        Assert_True(utils_entity_replication_driver::Has(_Tethered), "the tethered rock has a replication driver");
        Assert_False(_Untethered.Has_Fragment(FMars_Fragment_WorldItem_Tether), "a rock spawned for nobody carries no tether");
        Assert_True(utils_world_item::Get_SpawnOwner(_Untethered) == utils_entity_lifetime::Get_LifetimeOwner(_Untethered),
            "an untethered rock's spawn owner is its lifetime owner");
    }

    UFUNCTION()
    private void Step_DestroyOwner(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        utils_entity_lifetime::Request_DestroyEntity(_Owner);
        _DestroyFrame = utils_time::Get_FrameCounter();
    }

    UFUNCTION()
    private void Check_TetheredGoing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        if (Get_IsGoing(_Tethered) == false)
        {
            Res.Set(false);
            return;
        }

        _FollowedSeenFrame = utils_time::Get_FrameCounter();
        Res.Set(true);
    }

    UFUNCTION()
    private void Step_AssertEnded(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Frames = _FollowedSeenFrame - _DestroyFrame;
        Assert_True(Frames <= k_MaxFramesToFollow,
            f"the tethered rock was going within {k_MaxFramesToFollow} frames of its owner's destroy (took {Frames})");
        Assert_False(Get_IsGoing(_Untethered), "the rock spawned for nobody is still there");
    }

    private bool Get_IsGoing(FCk_Handle InEntity) const
    {
        return ck::Is_NOT_Valid(InEntity) || utils_entity_lifetime::Get_IsPendingDestroy(InEntity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }
}
