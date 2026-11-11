// A censer spawned on the listen host spills once on the server's request: the client's mirrored OnReleased runs the
// censer's own spill handler, so its swing is running there too, and both machines agree on the charges left and on
// whether the censer still holds peppercorns (what its cluster mesh shows). One handful lies under it on each machine.
// Surface: Ck.Forage.Net.AS_Forage_ACensersSpillSwingsOnTheClient
class UCk_AutoTest_Net_Forage_ACensersSpillSwingsOnTheClient : UMars_AutoTestRig_NetForage
{
    private const FVector k_Base = FVector(71000.0, 0.0, 5000.0);
    private const int32 k_Charges = 3;
    private const float32 k_RefillSeconds = 60.0f;
    // Long enough to still be swinging when the client checks.
    private const float32 k_SwingSeconds = 10.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_SpillSeen", n"OnClientSawSpill", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_ForageCenser_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.Charges = k_Charges;
        Params.RefillSeconds = k_RefillSeconds;
        Params.SwingSeconds = k_SwingSeconds;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()), UMars_ForageCenser_EntityScript, Params);
        WaitUntil(n"Is_CenserFound", n"OnServerCenserFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_CenserFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsForageCenser"));
    }

    UFUNCTION()
    private void OnServerCenserFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Forage.Request_Release(FMars_Request_Forage_Release(EMars_Forage_ReleaseReason::Hit));
        WaitUntil(n"Is_SpillSeen", n"OnServerSpilled", k_SlowPolls);
    }

    // This machine has its censer, has raised a spill and has a handful near it.
    UFUNCTION()
    private void Is_SpillSeen(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsSourceFound(n"TAG_MarsForageCenser") && _Released > 0 && Count_WorldItemsNear(mars_items::Peppercorns()) > 0);
    }

    UFUNCTION()
    private void OnServerSpilled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Spill("server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientSawSpill(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Check_Spill("client");
        FinishSuccess();
    }

    // Only the client logs: one line per test.
    private void Check_Spill(FString InMachine)
    {
        const auto Swing = Get_SourceOscillator();
        const auto Swinging = ck::IsValid(Swing) && Swing.Get_IsRunning();
        const auto Charges = _Forage.Get_ChargesLeft();
        const auto Holds = _Forage.Get_IsExhausted() == false;
        const auto Handfuls = Count_WorldItemsNear(mars_items::Peppercorns());
        Assert_True(ck::IsValid(Swing), f"the {InMachine}'s censer has its swing");
        Assert_True(Swinging, f"the {InMachine}'s censer swings after the spill");
        Assert_Equals_Int(_Released, 1, f"the {InMachine} raised OnReleased once");
        Assert_Equals_Int(Charges, k_Charges - 1, f"the {InMachine}'s censer spent one handful");
        Assert_True(Holds, f"the {InMachine}'s censer still holds peppercorns");
        Assert_Equals_Int(Handfuls, 1, f"one handful lies under the {InMachine}'s censer");
        if (Get_IsServer() == false)
        { Log(f"[ForageNetTest] ACensersSpillSwingsOnTheClient {InMachine} swinging={Swinging} signals={_Released} charges={Charges} holds={Holds} handfuls={Handfuls}"); }
    }
}
