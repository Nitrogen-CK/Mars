// A held item launched through Cue.Mars.HeldItemUse.Launch (fired on the server, where it runs at once) leaves the hands
// as one World-mode world item spawned under the spawn owner; its body simulates on the server alone and the client's
// copy, which has no body, follows it to within 5 cm of where the server's body is a second after it first reads still.
// The launch is a Drop so the item lands on the test's floor whatever the rock's Throwable speeds are.
// Surface: Ck.WorldItem.Net.AS_WorldItem_ThrownBodyLandsOnTheHost
class UCk_AutoTest_Net_WorldItem_ThrownBodyLandsOnTheHost : UMars_AutoTestRig_NetWorldItem
{
    default _TimeoutSeconds = 18.0f;

    private const FVector k_FloorTop = FVector(20000.0, 0.0, 5000.0);
    private const float64 k_RestToleranceCm = 5.0;
    // How long after its first still reading the server reports its body again.
    private const float32 k_SettleReportSeconds = 1.0f;

    private FMars_TESTONLY_NetCarrier _Carrier;
    private FCk_Handle_WorldItem _WorldItem;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Add_Report();
        _Carrier = Compose_Carrier(k_FloorTop + FVector(0.0, 0.0, 80.0), 1);

        if (utils_net::Get_HasAuthority(Subject) == false)
        {
            WaitUntil(n"Is_ClientAtTheServersRest", n"OnClientAtTheServersRest", k_SlowPolls);
            return;
        }

        Spawn_ServerFloor(InHandle, k_FloorTop);
        Seed_ServerSlot(_Carrier.Hotbar, 0);
        WaitUntil(n"Is_ServerReadyToLaunch", n"OnServerReadyToLaunch", k_SlowPolls);
    }

    // The spawn owner is published and the seeded rock is in slot 0.
    UFUNCTION()
    private void Is_ServerReadyToLaunch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && ck::IsValid(_Carrier.Hotbar.Get_ItemAt(0)));
    }

    UFUNCTION()
    private void OnServerReadyToLaunch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Carrier.Hotbar.Request_Select(FMars_Request_Hotbar_Select(0));
        WaitUntil(n"Is_ServerHolding", n"OnServerHolding", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHolding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Carrier.HeldItem.Get_CurrentItem()));
    }

    UFUNCTION()
    private void OnServerHolding(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Aim = FMars_HeldItemUse_Aim(FVector(1.0, 0.0, 0.0), FVector::ZeroVector);
        utils_cue_generic::Request_ExecuteCue(Get_SubjectEntity(), GameplayTags::Cue_Mars_HeldItemUse_Launch,
            FMars_HeldItemUse_Launch(EMars_LaunchKind::Drop, Aim), ECk_Cue_ReliabilityPolicy::Reliable, ECk_Cue_MulticastPolicy::ServerOnly);
        WaitUntil(n"Is_ServerLaunchedAndStill", n"OnServerLaunchedAndStill", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerLaunchedAndStill(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Rock))
        {
            _Rock = Find_WorldItemNear(k_FloorTop);
            Reset_RockStill();
            Result.Set(false);
            return;
        }

        Result.Set(Tick_RockStill());
    }

    UFUNCTION()
    private void OnServerLaunchedAndStill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Track_ForCleanup(_Rock);
        Assert_True(ck::IsValid(_Rock.As_WorldItem().Get_Body()), "the server's launched rock has its Jolt body");
        Assert_True(ck::Is_NOT_Valid(_Carrier.Hotbar.Get_ItemAt(0)), "the hands let it go");
        const auto Rest = Get_RootLocation(_Rock);
        Write_Report(Rest);
        Log(f"[WorldItemNet] the server's launched rock rests at {Rest}");
        WaitSeconds(k_SettleReportSeconds, n"OnServerSettleReported");
    }

    // A rolling rock can still creep under the still threshold: the server reports where its body is a second later, and
    // that is the pose the client must reach.
    UFUNCTION()
    private void OnServerSettleReported(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Settled = Get_RootLocation(_Rock);
        Write_Report(Settled);
        Log(f"[WorldItemNet] the server's launched rock is at {Settled} a second later");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // The server's second report, and the client's copy within the tolerance of it. Searched near the reported pose, not
    // the floor's origin: the drop carries the rock past the search radius.
    UFUNCTION()
    private void Is_ClientAtTheServersRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_Report().Serial < 2)
        {
            Result.Set(false);
            return;
        }

        _WorldItem = Find_WorldItemNear(Get_Report().RestLocation);
        if (ck::Is_NOT_Valid(_WorldItem))
        {
            Result.Set(false);
            return;
        }

        Result.Set(Get_RootLocation(_WorldItem).Equals(Get_Report().RestLocation, k_RestToleranceCm));
    }

    UFUNCTION()
    private void OnClientAtTheServersRest(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(utils_net::Get_HasAuthority(_WorldItem), "the client's copy has no authority");
        Assert_True(ck::Is_NOT_Valid(_WorldItem.Get_Body()), "the client's copy has no body");
        FinishSuccess();
    }
}
