// A crawler that stays put composes on both machines: the server's has authority, its surface motion, navigator, brain
// and state machine; the client's copy has none of them and is not armed, follows its root through an interpolation,
// stands on its own four legs (gait Ready and never Failed, body pose Ready, at least two trusted contacts), lists its
// four parts with the spec the server sent, a body Health of 120 and each leg's zone addressed through its root, and
// stands where the server spawned it.
// Surface: Ck.Crawler.Net.AS_Crawler_ACrawlerComposesOnBothMachines
class UCk_AutoTest_Net_Crawler_ACrawlerComposesOnBothMachines : UMars_AutoTestRig_NetCrawler
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Base = FVector(830000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 4.0f;
    private const float32 k_ClientStandSeconds = 3.0f;
    private const float64 k_RootDrift = 30.0;
    private const float64 k_RootLowest = 30.0;
    private const float64 k_RootHighest = 110.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_CrawlerRow(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_CrawlerFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerCrawler(Make_RowSpec(k_StaysPut));
        WaitUntil(n"Is_CrawlerSettled", n"OnServerSettled", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(utils_net::Get_HasAuthority(_CrawlerRoot), "the server has authority over its crawler's root");
        Assert_True(ck::IsValid(_Crawler.Get_Motion()), "the server's crawler has a surface motion");
        Assert_True(ck::IsValid(_Crawler.Get_Navigator()), "the server's crawler has a navigator");
        Assert_True(ck::IsValid(_CrawlerRoot.As_Brain(ECk_SanityCheck::UnChecked)), "the server's crawler has a brain");
        Assert_True(ck::IsValid(_CrawlerRoot.As_StateMachine(ECk_SanityCheck::UnChecked)), "the server's crawler has a state machine");
        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the server's gait reads Ready");
        Assert_True(Get_BodyPoseStatus() == ECk_ProceduralAnimation_Status::Ready, "the server's body pose reads Ready");
        Assert_Equals_Int(Get_AttachedLegs(), k_LegCount, "the server's four legs are attached");
        Assert_Equals_Int(_CrawlerMonster.Get_Parts().Num(), k_LegCount, "the server's monster lists four parts");
        Hold_CrawlerServerRow("ACrawlerComposesOnBothMachines", "");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ClientStandSeconds, n"OnClientStood");
    }

    UFUNCTION()
    private void OnClientStood(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_CrawlerRoot), "the client has no authority over its root");
        Assert_False(ck::IsValid(_Crawler.Get_Motion()), "the client's copy has no surface motion");
        Assert_False(ck::IsValid(_Crawler.Get_Navigator()), "the client's copy has no navigator");
        Assert_False(ck::IsValid(_CrawlerRoot.As_Brain(ECk_SanityCheck::UnChecked)), "the client's copy has no brain");
        Assert_False(ck::IsValid(_CrawlerRoot.As_StateMachine(ECk_SanityCheck::UnChecked)), "the client's copy has no state machine");
        Assert_False(_Crawler.Get_IsCombatArmed(), "the client's copy is not armed");
        Assert_True(utils_transform_interpolation::Has(_CrawlerRoot), "the client's root has a transform interpolation");
        Assert_True(Get_GaitStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's gait reads Ready");
        Assert_False(_CrawlerGaitEverFailed, "the client's gait never read Failed");
        Assert_True(Get_BodyPoseStatus() == ECk_ProceduralAnimation_Status::Ready, "the client's body pose reads Ready");
        Assert_True(Get_Trusted() >= 2, f"the client's gait trusts at least two contacts (reads {Get_Trusted()})");
        Assert_Equals_Int(Get_AttachedLegs(), k_LegCount, "the client's four legs are attached");
        Assert_Equals_Int(_CrawlerMonster.Get_Parts().Num(), k_LegCount, "the client's monster lists four parts");
        Assert_Equals_Int(_Crawler.Get_Spec().LegCount, k_LegCount, "the client's copy was spawned with the server's LegCount");
        Assert_True(Math::IsNearlyEqual(_Health.Get_Current(), 120.0f, 0.01f), "the client's body Health reads 120");

        for (int32 Index = 0; Index < _LegParts.Num(); ++Index)
        {
            const auto Zone = _LegParts[Index].Get_Zone();
            const auto Address = Zone.Get_Address();
            Assert_True(Address.Root == _CrawlerRoot && Address.Index == Index + 1,
                f"the client's leg {Index} zone's address is its root and {Index + 1} (reads {Address.Index})");
            Assert_True(utils_hit_zone::TryGet_ZoneAt(Address) == Zone, f"the client's leg {Index} zone's address resolves back to it");
        }

        const auto Root = Get_RootLocation();
        const auto OverFloor = Root.Z - _Base.Z;
        Assert_True(Math::Abs(Root.X - _CrawlerAt.X) <= k_RootDrift && Math::Abs(Root.Y - _CrawlerAt.Y) <= k_RootDrift,
            f"the client's root is within 30 of the base on X and Y ({Root.X - _CrawlerAt.X}, {Root.Y - _CrawlerAt.Y})");
        Assert_True(OverFloor >= k_RootLowest && OverFloor <= k_RootHighest,
            f"the client's root is between 30 and 110 over the floor ({OverFloor})");
        Finish_CrawlerRow("ACrawlerComposesOnBothMachines", "");
    }
}
