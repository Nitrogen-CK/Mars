// A target with a Body zone on its root and a Limb zone on a child known through the root: on each machine, the Body
// zone's address is {its copy, 0} and the Limb zone's {its copy, 1}, each resolving back to its zone; on the client the
// roster's entries carry those tags, and an address past the roster or with no root resolves to nothing without an ensure.
// Surface: Ck.HitZone.Net.AS_HitZone_AZonesAddressIsTheSameOnBothMachines
class UCk_AutoTest_Net_HitZone_AZonesAddressIsTheSameOnBothMachines : UMars_AutoTestRig_NetHitZone
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Base = FVector(513000.0, 0.0, 5000.0);
    private const float32 k_ReportHoldSeconds = 4.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ZoneTargetFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerTargetWithLimb();
        WaitUntil(n"Is_ZoneTargetFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Addresses();
        Log_ZoneRow("AZonesAddressIsTheSameOnBothMachines", f"roster={Get_RosterText()}");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ReportHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Addresses();

        auto AtZero = utils_hit_zone::TryGet_ZoneAt(FMars_HitZone_Address(_Target, 0));
        auto AtOne = utils_hit_zone::TryGet_ZoneAt(FMars_HitZone_Address(_Target, 1));
        Assert_True(ck::IsValid(AtZero) && AtZero.Get_ZoneTag() == GameplayTags::HitZone_Mars_Body, "the client's zone at index 0 is the Body zone");
        Assert_True(ck::IsValid(AtOne) && AtOne.Get_ZoneTag() == GameplayTags::HitZone_Mars_Limb, "the client's zone at index 1 is the Limb zone");

        auto PastTheRoster = utils_hit_zone::TryGet_ZoneAt(FMars_HitZone_Address(_Target, 2));
        auto NoRoot = utils_hit_zone::TryGet_ZoneAt(FMars_HitZone_Address(FCk_Handle(), 0));
        Assert_True(ck::Is_NOT_Valid(PastTheRoster), "an address past the roster resolves to nothing");
        Assert_True(ck::Is_NOT_Valid(NoRoot), "an address with no root resolves to nothing");

        Log_ZoneRow("AZonesAddressIsTheSameOnBothMachines", f"roster={Get_RosterText()}");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    // The same four facts on either machine: both zones' addresses name this copy and their index, and each resolves back.
    private void Assert_Addresses()
    {
        auto Limb = Get_LimbZone();
        Assert_True(ck::IsValid(Limb), "the target's copy lists a limb zone second");
        if (ck::Is_NOT_Valid(Limb))
        { return; }

        const auto BodyAddress = _Zone.Get_Address();
        const auto LimbAddress = Limb.Get_Address();
        Assert_True(BodyAddress.Root == _Target && BodyAddress.Index == 0,
            f"the Body zone's address is this copy at 0 (got {BodyAddress.Root.ToString()} at {BodyAddress.Index})");
        Assert_True(LimbAddress.Root == _Target && LimbAddress.Index == 1,
            f"the Limb zone's address is this copy at 1 (got {LimbAddress.Root.ToString()} at {LimbAddress.Index})");
        Assert_True(utils_hit_zone::TryGet_ZoneAt(BodyAddress) == _Zone, "the Body zone's address resolves back to it");
        Assert_True(utils_hit_zone::TryGet_ZoneAt(LimbAddress) == Limb, "the Limb zone's address resolves back to it");
    }

    // This copy's roster in order: each entry's tag and entity.
    private FString Get_RosterText()
    {
        if (ck::Is_NOT_Valid(_Target) || _Target.Has_Fragment(FMars_Fragment_HitZone_Roster) == false)
        { return "none"; }

        auto Text = FString();
        for (auto Zone : _Target.Get_Fragment(FMars_Fragment_HitZone_Roster).Zones)
        {
            const auto Tag = ck::IsValid(Zone) ? Zone.Get_ZoneTag().ToString() : "dead";
            Text += f"[{Tag} {Zone.ToString()}]";
        }

        return Text;
    }
}
