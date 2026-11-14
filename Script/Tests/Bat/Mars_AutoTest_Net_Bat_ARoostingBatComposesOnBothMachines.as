// The server spawns a Cellar Bat under the roost it is given and holds: its copy roosts with what decides and moves it
// (an enabled crowd agent, a voxel path, a dealer, a state machine and its three blackboards), a built volume, the
// claim Held, no transform interpolation and a ledger that reads Roosting at the roost's place. The client's copy
// roosts without any of those (no agent, path, dealer, volume, state machine or blackboard; the claim Unowned with no
// owner), hangs from the roost's place at the hang point, reads its spec as the server sent it, carries the monster
// (body Health 40) and one hurtbox on the body zone, whose address is {its root, 0} and resolves back, has no authority
// over its root and follows it through a transform interpolation. Each machine also spawns the real flight volume
// script under its own subject: the server's composes a volume, the client's composes its transform and nothing else,
// so no flight volume and no roost exist in the client's world. Surface:
// Ck.Bat.Net.AS_Bat_ARoostingBatComposesOnBothMachines
class UCk_AutoTest_Net_Bat_ARoostingBatComposesOnBothMachines : UMars_AutoTestRig_NetBat
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_Floor = FVector(660000.0, 0.0, 5000.0);
    private const FVector k_VolumeScriptOffset = FVector(0.0, 4000.0, 0.0);
    private const float32 k_HoldSeconds = 4.0f;

    private int32 _VolumeScriptsConstructed = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BatRow(k_Floor);

        if (Get_IsServer() == false)
        {
            Spawn_VolumeScript();
            WaitUntil(n"Is_BatFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        // A floor under the server's volume script: a bake over nothing ensures.
        Spawn_BatStatic(FTransform(FRotator::ZeroRotator, _Floor + k_VolumeScriptOffset - FVector(0.0, 0.0, k_BatFloorHalfExtents.Z)),
            k_BatFloorHalfExtents);
        Begin_ServerWorld(n"OnServerReady");
    }

    // The real flight volume script under this machine's own subject.
    private void Spawn_VolumeScript()
    {
        auto Params = UMars_BatFlightVolume_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Floor + k_VolumeScriptOffset);
        auto Pending = utils_entity_script::Request_SpawnEntity(Get_SubjectEntity(), UMars_BatFlightVolume_EntityScript, Params);
        utils_pending_entity_script::Promise_OnConstructed(Pending, FCk_Delegate_EntityScript_Constructed(this, n"OnVolumeScriptConstructed"));
    }

    UFUNCTION()
    private void OnVolumeScriptConstructed(FCk_Handle_EntityScript InEntityScriptHandle)
    {
        _VolumeScriptsConstructed += 1;
    }

    private int32 Count_Tagged(FName InTag)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            if (utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false)
            { Count += 1; }
        }

        return Count;
    }

    private FString Describe_World()
    {
        return f"volumeScripts={_VolumeScriptsConstructed} volumes={Count_Tagged(utils_bat::FlightVolumeTag)} roosts={Count_Tagged(utils_bat::RoostTag)}";
    }

    UFUNCTION()
    private void OnServerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_VolumeScript();
        WaitSampling(k_HoldSeconds, n"OnServerHeldRoosting");
    }

    UFUNCTION()
    private void OnServerHeldRoosting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Bat;
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the server's bat roosts");
        Assert_True(ck::IsValid(_Bat.Get_Agent()) && utils_crowd_agent::Get_IsEnabled(_Bat.Get_Agent()), "the server's bat has an enabled crowd agent");
        Assert_True(ck::IsValid(_Bat.Get_Path()), "the server's bat has a voxel path");
        Assert_True(ck::IsValid(_Bat.Get_Dealer()), "the server's bat has a dealer");
        Assert_True(ck::IsValid(Root.As_StateMachine(ECk_SanityCheck::UnChecked)), "the server's bat has a state machine");
        Assert_True(_Bat.Has_Fragment(FMars_Fragment_Bat_PatrolBlackboard) && _Bat.Has_Fragment(FMars_Fragment_Bat_SortieBlackboard)
            && _Bat.Has_Fragment(FMars_Fragment_Bat_SearchBlackboard), "the server's bat has its three blackboards");
        Assert_True(ck::IsValid(_Bat.Get_Volume()) && utils_voxel_nav_volume::Get_IsBuilt(_Bat.Get_Volume()), "the server's bat knows a built volume");
        Assert_True(_Bat.Get_RoostClaim() == EMars_Bat_RoostClaim::Held, "the server's bat holds its roost");
        Assert_False(utils_transform_interpolation::Has(Root), "the server's bat has no transform interpolation");
        Assert_True(Get_HasBatLedger(), "the server's bat has its ledger");
        const auto Ledger = Get_BatLedger();
        Assert_True(Ledger.Phase == EMars_Bat_Phase::Roosting, "the server's ledger reads Roosting");
        Assert_True(Ledger.PerchAnchor.Equals(Get_RoostAnchor(), 1.0), f"the server's ledger hangs from the roost's place (reads {Ledger.PerchAnchor.ToString()})");
        Assert_Equals_Int(Count_Tagged(utils_bat::FlightVolumeTag), 2, "the server's world has two flight volumes");
        Hold_BatServerRow("ARoostingBatComposesOnBothMachines", Describe_World());
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FCk_Handle Root = _Bat;
        const auto Perch = _Bat.Get_Fragment(FMars_Fragment_Bat).Perch;
        const auto Spec = _Bat.Get_Spec();
        Assert_True(_Bat.Get_Phase() == EMars_Bat_Phase::Roosting, "the client's bat roosts");
        Assert_False(ck::IsValid(_Bat.Get_Agent()), "the client's bat has no crowd agent");
        Assert_False(ck::IsValid(_Bat.Get_Path()), "the client's bat has no voxel path");
        Assert_False(ck::IsValid(_Bat.Get_Dealer()), "the client's bat has no dealer");
        Assert_False(ck::IsValid(_Bat.Get_Volume()), "the client's bat knows no volume");
        Assert_False(ck::IsValid(Root.As_StateMachine(ECk_SanityCheck::UnChecked)), "the client's bat has no state machine");
        Assert_False(_Bat.Has_Fragment(FMars_Fragment_Bat_PatrolBlackboard) || _Bat.Has_Fragment(FMars_Fragment_Bat_SortieBlackboard)
            || _Bat.Has_Fragment(FMars_Fragment_Bat_SearchBlackboard), "the client's bat has none of the three blackboards");
        Assert_True(Perch.Claim == EMars_Bat_RoostClaim::Unowned && ck::Is_NOT_Valid(Perch.Owner), "the client's claim is Unowned with no owner");
        const auto Anchor = _Bat.Get_PerchAnchor();
        Assert_True(Anchor.Equals(Get_RoostAnchor(), 1.0), f"the client's bat hangs from the roost's place (reads {Anchor.ToString()})");
        Assert_True(_Bat.Get_Location().Equals(_HangAt, 1.0), f"the client's root is at the hang point (reads {_Bat.Get_Location().ToString()})");
        Assert_False(_Bat.Get_IsNavReady(), "the client's bat reads not nav-ready");
        Assert_True(_Bat.Get_SwoopFrame().Alpha == 0.0f, "the client's swoop frame reads alpha 0");
        Assert_True(Math::IsNearlyEqual(Spec.Flight.CruiseSpeed, 380.0f, 0.001f), "the client's spec reads a cruise of 380");
        Assert_True(Spec.Sensing.SearchSeconds.IsSet() && Math::IsNearlyEqual(Spec.Sensing.SearchSeconds.GetValue(), 3.0f, 0.001f),
            "the client's spec reads SearchSeconds set to 3");
        Assert_False(Spec.Timing.RoostIdleSeconds.IsSet(), "the client's spec reads RoostIdleSeconds unset");
        Assert_True(Math::IsNearlyEqual(_Health.Get_Current(), 40.0f, 0.01f), "the client's body Health reads 40");
        Assert_Equals_Int(_Zone.Get_Hurtboxes().Num(), 1, "the client's body zone has one hurtbox");

        const auto Address = _Zone.Get_Address();
        Assert_True(Address.Root == Root && Address.Index == 0, "the client's body zone's address is {its root, 0}");
        Assert_True(utils_hit_zone::TryGet_ZoneAt(Address) == _Zone, "the client's body zone's address resolves back to it");
        Assert_False(utils_net::Get_HasAuthority(Root), "the client has no authority over its root");
        Assert_True(utils_transform_interpolation::Has(Root), "the client's root has a transform interpolation");
        Assert_True(_VolumeScriptsConstructed == 1, "the client's own volume script composed");
        Assert_Equals_Int(Count_Tagged(utils_bat::FlightVolumeTag), 0, "the client's world has no flight volume");
        Assert_Equals_Int(Count_Tagged(utils_bat::RoostTag), 0, "the client's world has no roost");
        Finish_BatRow("ARoostingBatComposesOnBothMachines", Describe_World());
    }
}
