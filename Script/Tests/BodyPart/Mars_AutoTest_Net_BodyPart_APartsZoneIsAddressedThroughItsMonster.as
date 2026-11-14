// On each machine's copy of the monster, part N's zone is addressed as {the monster's root, N + 1} and the body zone as
// {the root, 0}, and every address resolves back to its zone.
// Surface: Ck.BodyPart.Net.AS_BodyPart_APartsZoneIsAddressedThroughItsMonster
class UCk_AutoTest_Net_BodyPart_APartsZoneIsAddressedThroughItsMonster : UMars_AutoTestRig_NetBodyPart
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Base = FVector(555000.0, 0.0, 5000.0);
    private const float32 k_WatchSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_BodyPart(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_MonsterFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerMonster(0.0f);
        WaitUntil(n"Is_MonsterFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_WatchSeconds, n"OnServerWatched");
    }

    UFUNCTION()
    private void OnServerWatched(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("APartsZoneIsAddressedThroughItsMonster", "");
        Assert_Addresses("server");
        FinishSuccess();
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_PartRow("APartsZoneIsAddressedThroughItsMonster", "");
        Assert_Addresses("client");
        FinishSuccess();
    }

    private void Assert_Addresses(FString InMachine)
    {
        const auto BodyZone = _Monster.Get_BodyZone();
        const auto BodyAddress = BodyZone.Get_Address();
        Assert_True(BodyAddress.Root == _MonsterRoot && BodyAddress.Index == 0, f"the {InMachine}'s body zone is addressed as the root's zone 0");
        Assert_True(utils_hit_zone::TryGet_ZoneAt(BodyAddress) == BodyZone, f"the {InMachine}'s body zone address resolves back");

        for (int32 Index = 0; Index < _Parts.Num(); ++Index)
        {
            const auto Zone = _Parts[Index].Get_Zone();
            const auto Address = Zone.Get_Address();
            Assert_True(Address.Root == _MonsterRoot, f"the {InMachine}'s part {Index} zone is addressed through the monster's root");
            Assert_Equals_Int(Address.Index, Index + 1, f"the {InMachine}'s part {Index} zone is the root's zone {Index + 1}");
            Assert_True(utils_hit_zone::TryGet_ZoneAt(Address) == Zone, f"the {InMachine}'s part {Index} zone address resolves back");
        }

        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {InMachine}");
    }
}
